#!/usr/bin/env python3
"""Validate one Sol Advisor dispatch batch and advance its run state."""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile


ROUTES = {
    "repo_search": {
        "role": "sol_advisor_investigator", "provider": "openai", "base_model": "gpt-5.6-luna",
        "models": {"gpt-5.6-luna": {"xhigh", "max"}},
    },
    "precision_search": {
        "role": "sol_advisor_investigator", "provider": "openai", "base_model": "gpt-5.6-luna",
        "models": {"gpt-5.6-luna": {"max"}},
    },
    "external_research": {
        "role": "sol_advisor_investigator", "provider": "openai", "base_model": "gpt-5.6-luna",
        "models": {"gpt-5.6-luna": {"xhigh", "max"}},
    },
    "mechanical_edit": {
        "role": "sol_advisor_mechanical_editor", "provider": "openai", "base_model": "gpt-5.6-luna",
        "models": {"gpt-5.6-luna": {"xhigh", "max"}, "gpt-5.6-terra": {"xhigh", "max"}},
    },
    "long_context": {
        "role": "sol_advisor_context_analyst", "provider": "openai", "base_model": "gpt-5.6-terra",
        "models": {"gpt-5.6-terra": {"xhigh"}},
    },
    "cross_module": {
        "role": "sol_advisor_context_analyst", "provider": "openai", "base_model": "gpt-5.6-terra",
        "models": {"gpt-5.6-terra": {"max"}},
    },
    "local_verification": {
        "role": "sol_advisor_local_code_verifier", "provider": "openai", "base_model": "gpt-5.6-luna",
        "models": {"gpt-5.6-luna": {"max"}},
    },
    "adjudicate_low": {
        "role": "sol_advisor_final_adjudicator", "provider": "openai", "base_model": "gpt-5.6-sol",
        "models": {"gpt-5.6-sol": {"medium"}},
    },
    "adjudicate_critical": {
        "role": "sol_advisor_final_adjudicator", "provider": "openai", "base_model": "gpt-5.6-sol",
        "models": {"gpt-5.6-sol": {"xhigh"}},
    },
    "adjudicate_max": {
        "role": "sol_advisor_final_adjudicator", "provider": "openai", "base_model": "gpt-5.6-sol",
        "models": {"gpt-5.6-sol": {"max"}},
    },
}

PHASE_KINDS = {
    "investigation": {"repo_search", "precision_search", "external_research", "long_context"},
    "editing": {"mechanical_edit"},
    "verification": {"local_verification", "cross_module"},
    "adjudication": {"adjudicate_low", "adjudicate_critical", "adjudicate_max"},
}
CONCURRENT_CAPS = {"ordinary": 1, "complex": 2, "critical": 2}
TOTAL_CAPS = {"ordinary": 1, "complex": 3, "critical": 5}
TIER_RANK = {"ordinary": 0, "complex": 1, "critical": 2}
COMPLEX_RISKS = {
    "ambiguity",
    "difficult_debugging",
    "novel_algorithm",
    "long_context",
    "multiple_modules",
    "behavior_change",
    "evidence_incomplete",
}
CRITICAL_RISKS = {
    "security",
    "authentication",
    "concurrency",
    "data_loss",
    "migration",
    "production",
    "public_api",
    "irreversible",
    "external_side_effect",
    "permission_boundary",
}
CRITICAL_TERMS = (
    "production",
    "security",
    "authentication",
    "concurrency",
    "data loss",
    "migration",
    "public api",
    "irreversible",
    "external side effect",
    "生产",
    "安全",
    "认证",
    "并发",
    "数据丢失",
    "迁移",
    "公共接口",
    "不可逆",
    "外部副作用",
    "权限",
)
TOKEN_RE = re.compile(r"^SOL_ADVISOR_[A-Z0-9_]{8,64}$")
ID_RE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_.-]{2,63}$")
TASK_NAME_RE = re.compile(r"^[a-z][a-z0-9_]{2,48}$")
STATE_SCHEMA_VERSION = 8
DIFFICULTY_KINDS = {"repo_search", "precision_search", "external_research", "mechanical_edit"}
INVESTIGATION_KINDS = {"repo_search", "precision_search", "external_research"}
LOCAL_SEARCH_INTENTS = {"symbol", "call_path", "architecture", "text", "document"}
EXTERNAL_SEARCH_INTENTS = {"library_docs", "web_fact", "known_page"}
INDEX_POLICIES = {"reuse", "create-if-missing", "refresh", "never"}
GENERATED_CONTENT_POLICIES = {"auto", "include", "exclude"}
DEEP_INVESTIGATION_RISKS = {"multiple_modules", "difficult_debugging", "evidence_incomplete"} | CRITICAL_RISKS
PLAN_FIELDS = {
    "run_id",
    "batch_id",
    "batch_index",
    "task_summary",
    "risk_flags",
    "tier",
    "phase",
    "mode",
    "fix_round",
    "spawn_interface",
    "fork_turns",
    "available_agent_types",
    "available_models",
    "available_model_overrides",
    "available_providers",
    "agent_base_models",
    "routes",
    "evidence_batch_ids",
    "conflict_summary",
}


def fail(message: str) -> None:
    raise ValueError(message)


def required_text(obj: dict, key: str, limit: int = 2000) -> str:
    value = obj.get(key)
    if not isinstance(value, str) or not value.strip() or len(value) > limit:
        fail(f"{key} must be non-empty text no longer than {limit} characters")
    return value.strip()


def required_text_list(obj: dict, key: str) -> list[str]:
    value = obj.get(key)
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        fail(f"{key} must be an array of non-empty strings")
    return [item.strip() for item in value]


def canonical_json(value: dict) -> bytes:
    return json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode("utf-8")


def with_receipt(state: dict) -> dict:
    value = deepcopy(state)
    value.pop("receipt", None)
    value["receipt"] = hashlib.sha256(canonical_json(value)).hexdigest()
    return value


def verify_state(state: dict) -> None:
    if not isinstance(state, dict) or state.get("schema_version") != STATE_SCHEMA_VERSION:
        fail("state file has an unsupported schema")
    receipt = state.get("receipt")
    if not isinstance(receipt, str):
        fail("state file is missing its receipt")
    expected = with_receipt(state)["receipt"]
    if receipt != expected:
        fail("state file receipt mismatch")


def load_state(path: Path) -> dict | None:
    if not path.exists():
        return None
    if path.is_symlink() or not path.is_file():
        fail("state path must be a regular non-symlink file")
    state = json.loads(path.read_text(encoding="utf-8"))
    verify_state(state)
    return state


def write_state(path: Path, state: dict) -> None:
    declared_parent = path.parent
    if declared_parent.is_symlink():
        fail("state parent must be a real directory and state must not be a symlink")
    parent = declared_parent.resolve(strict=True)
    if not parent.is_dir() or path.exists() and path.is_symlink():
        fail("state parent must be a real directory and state must not be a symlink")
    payload = canonical_json(with_receipt(state)) + b"\n"
    descriptor, temporary = tempfile.mkstemp(prefix=".sol-advisor-state-", dir=parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def derived_tier(task_summary: str, risk_flags: list[str]) -> str:
    unknown = set(risk_flags) - COMPLEX_RISKS - CRITICAL_RISKS
    if unknown:
        fail(f"unknown risk_flags: {sorted(unknown)}")
    normalized = task_summary.lower()
    if set(risk_flags) & CRITICAL_RISKS or any(term in normalized for term in CRITICAL_TERMS):
        return "critical"
    if set(risk_flags) & COMPLEX_RISKS:
        return "complex"
    return "ordinary"


def count_exact(kinds: list[str], expected: dict[str, int]) -> bool:
    return all(kinds.count(kind) == count for kind, count in expected.items()) and len(kinds) == sum(expected.values())


def validate_search_config(route: dict, kind: str, index: int) -> dict | None:
    search = route.get("search")
    if kind not in INVESTIGATION_KINDS:
        if search is not None:
            fail(f"route {index} does not accept search configuration")
        return None
    if not isinstance(search, dict):
        fail(f"route {index} requires a search configuration object")

    intent = search.get("intent")
    allowed_intents = EXTERNAL_SEARCH_INTENTS if kind == "external_research" else LOCAL_SEARCH_INTENTS
    if intent not in allowed_intents:
        fail(f"route {index} has an invalid search intent for {kind}")
    roots = search.get("roots")
    include = search.get("include")
    exclude = search.get("exclude")
    fallback_order = search.get("fallback_order")
    for name, value in (("roots", roots), ("include", include), ("exclude", exclude), ("fallback_order", fallback_order)):
        if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
            fail(f"route {index} search {name} must be a list of non-empty strings")
    if kind != "external_research" and not roots:
        fail(f"route {index} local search requires at least one exact root")
    if kind == "external_research" and roots:
        fail(f"route {index} external search must not declare repository roots")
    if len(set(fallback_order)) != len(fallback_order):
        fail(f"route {index} search fallback_order must not contain duplicates")

    generated_content = search.get("generated_content")
    indexing = search.get("indexing")
    tool_policy = search.get("tool_policy")
    if generated_content not in GENERATED_CONTENT_POLICIES:
        fail(f"route {index} has an invalid generated_content policy")
    if indexing not in INDEX_POLICIES:
        fail(f"route {index} has an invalid indexing policy")
    if kind == "external_research" and indexing != "never":
        fail(f"route {index} external search requires indexing=never")
    if tool_policy != "auto":
        fail(f"route {index} search tool_policy must be auto")

    return {
        "intent": intent,
        "roots": roots,
        "include": include,
        "exclude": exclude,
        "generated_content": generated_content,
        "indexing": indexing,
        "tool_policy": tool_policy,
        "fallback_order": fallback_order,
    }


def validate(plan: dict, state: dict | None = None) -> tuple[dict, dict]:
    if not isinstance(plan, dict):
        fail("plan must be a JSON object")
    unknown_fields = set(plan) - PLAN_FIELDS
    if unknown_fields:
        fail(f"unsupported plan fields: {sorted(unknown_fields)}")
    if state is not None:
        verify_state(state)
        if state.get("pending_batch") is not None:
            fail("the previous batch still has unvalidated child results")

    run_id = required_text(plan, "run_id", 64)
    batch_id = required_text(plan, "batch_id", 64)
    if not ID_RE.fullmatch(run_id) or not ID_RE.fullmatch(batch_id):
        fail("run_id and batch_id must use stable alphanumeric identifiers")
    batch_index = plan.get("batch_index")
    fix_round = plan.get("fix_round")
    if not isinstance(batch_index, int) or isinstance(batch_index, bool) or batch_index < 0:
        fail("batch_index must be a non-negative integer")
    if not isinstance(fix_round, int) or isinstance(fix_round, bool) or not 0 <= fix_round <= 2:
        fail("fix_round must be an integer from 0 through 2")

    task_summary = required_text(plan, "task_summary")
    risk_flags = required_text_list(plan, "risk_flags")
    tier = plan.get("tier")
    phase = plan.get("phase")
    mode = plan.get("mode")
    if tier not in CONCURRENT_CAPS:
        fail("tier must be ordinary, complex, or critical")
    minimum_tier = derived_tier(task_summary, risk_flags)
    if TIER_RANK[tier] < TIER_RANK[minimum_tier]:
        fail(f"tier {tier} under-reports the derived minimum tier {minimum_tier}")
    if phase not in PHASE_KINDS:
        fail("invalid phase")
    if mode not in {"serial", "parallel"}:
        fail("mode must be serial or parallel")

    spawn_interface = plan.get("spawn_interface")
    if spawn_interface != "desktop_collaboration_v2":
        fail("spawn_interface must be desktop_collaboration_v2")
    if plan.get("fork_turns") != "none" or "fork_context" in plan:
        fail("desktop_collaboration_v2 requires fork_turns='none' and forbids fork_context")

    available_agents = set(required_text_list(plan, "available_agent_types"))
    available_models = set(required_text_list(plan, "available_models"))
    available_model_overrides = set(required_text_list(plan, "available_model_overrides"))
    available_providers = set(required_text_list(plan, "available_providers"))
    agent_base_models = plan.get("agent_base_models")
    if not isinstance(agent_base_models, dict) or any(
        not isinstance(role, str) or not role.strip() or not isinstance(model, str) or not model.strip()
        for role, model in agent_base_models.items()
    ):
        fail("agent_base_models must map agent roles to non-empty model names")

    if state is None:
        if batch_index != 0 or fix_round != 0:
            fail("a new run must begin at batch_index=0 and fix_round=0")
        prior_spawned = 0
        completed_batches: list[dict] = []
        prior_tier = tier
    else:
        if run_id != state.get("run_id"):
            fail("run_id does not match the state file")
        if batch_index != len(state.get("completed_batches", [])):
            fail("batch_index must advance monotonically from completed state")
        if fix_round < state.get("fix_round", 0) or fix_round > state.get("fix_round", 0) + 1:
            fail("fix_round cannot decrease or advance by more than one")
        if TIER_RANK[tier] < TIER_RANK[state.get("tier")]:
            fail("tier cannot decrease during a run")
        prior_spawned = state.get("spawned_total", 0)
        completed_batches = deepcopy(state.get("completed_batches", []))
        prior_tier = state.get("tier")

    completed_ids = {item.get("batch_id") for item in completed_batches if isinstance(item, dict)}
    if batch_id in completed_ids:
        fail("batch_id must be unique within a run")
    if phase == "adjudication":
        if state is None or not completed_ids:
            fail("adjudication requires a prior validated evidence batch")
        evidence_batch_ids = required_text_list(plan, "evidence_batch_ids")
        if not evidence_batch_ids or len(evidence_batch_ids) != len(set(evidence_batch_ids)):
            fail("adjudication requires unique evidence_batch_ids")
        if not set(evidence_batch_ids).issubset(completed_ids):
            fail("adjudication evidence_batch_ids must reference completed batches in this run")
        required_text(plan, "conflict_summary", 2000)
    elif "evidence_batch_ids" in plan or "conflict_summary" in plan:
        fail("evidence_batch_ids and conflict_summary are reserved for adjudication")

    routes = plan.get("routes")
    if not isinstance(routes, list) or not routes:
        fail("routes must be a non-empty array")
    if len(routes) > CONCURRENT_CAPS[tier]:
        fail(f"concurrent route cap exceeded for tier {tier}")
    if prior_spawned + len(routes) > TOTAL_CAPS[tier]:
        fail("total child budget exceeded by persisted run state")
    if mode == "serial" and len(routes) != 1:
        fail("serial batches must contain exactly one route")
    if mode == "parallel" and len(routes) < 2:
        fail("parallel batches must contain at least two routes")

    tokens: set[str] = set()
    task_names: set[str] = set()
    angles: set[str] = set()
    kinds: list[str] = []
    normalized_routes = []
    for index, route in enumerate(routes):
        if not isinstance(route, dict):
            fail(f"route {index} must be an object")
        kind = route.get("task_kind")
        if kind not in ROUTES or kind not in PHASE_KINDS[phase]:
            fail(f"route {index} is not allowed in phase {phase}")
        policy = ROUTES[kind]
        expected_role = policy["role"]
        expected_provider = policy["provider"]
        expected_base_model = policy["base_model"]
        model = route.get("model")
        effort = route.get("effort")
        if "access" in route:
            fail(f"route {index} must not declare access; child permissions inherit from the parent task")
        observed = (route.get("role"), route.get("provider"))
        expected = (expected_role, expected_provider)
        if observed != expected or effort not in policy["models"].get(model, set()):
            fail(f"route {index} does not match the allowed task-role-model-effort mapping")
        if agent_base_models.get(expected_role) != expected_base_model:
            fail(f"route {index} installed agent base model does not match the route policy")
        if model not in available_models:
            fail(f"route {index} model is not present in the current model catalog")
        model_override = None if model == expected_base_model else model
        if model_override is not None and model_override not in available_model_overrides:
            fail(f"route {index} model override is not exposed by Desktop collaboration")

        difficulty = route.get("difficulty")
        selection_reason = route.get("selection_reason")
        if kind in DIFFICULTY_KINDS:
            if difficulty not in {"standard", "deep"}:
                fail(f"route {index} requires difficulty standard or deep")
        elif difficulty is not None:
            fail(f"route {index} does not accept difficulty")

        if kind in INVESTIGATION_KINDS:
            required_effort = "xhigh" if difficulty == "standard" else "max"
            if model != "gpt-5.6-luna" or effort != required_effort:
                fail(f"route {index} investigation difficulty does not match the Luna effort")
            if kind == "precision_search" and difficulty != "deep":
                fail(f"route {index} precision_search requires deep difficulty")
            if difficulty == "standard" and set(risk_flags) & DEEP_INVESTIGATION_RISKS:
                fail(f"route {index} under-reports investigation difficulty")
            if selection_reason is not None:
                fail(f"route {index} investigation does not accept selection_reason")
        elif kind == "mechanical_edit":
            if model == "gpt-5.6-luna":
                required_effort = "xhigh" if difficulty == "standard" else "max"
                if effort != required_effort or selection_reason is not None:
                    fail(f"route {index} Luna mechanical edit does not match difficulty")
            else:
                if selection_reason != "long_context" or "long_context" not in risk_flags:
                    fail(f"route {index} Terra mechanical edit requires explicit long_context selection")
                required_effort = "max" if "multiple_modules" in risk_flags else "xhigh"
                if difficulty != "deep" or effort != required_effort:
                    fail(f"route {index} Terra mechanical edit does not match long-context scope")
        elif selection_reason is not None:
            fail(f"route {index} does not accept selection_reason")
        if expected_role not in available_agents:
            fail(f"route {index} agent type is not exposed by the current runtime")
        if expected_provider not in available_providers:
            fail(f"route {index} provider is not available in the current runtime")
        task_name = route.get("task_name")
        if not isinstance(task_name, str) or not TASK_NAME_RE.fullmatch(task_name):
            fail(f"route {index} requires a valid Desktop task_name")
        if task_name in task_names:
            fail("Desktop task_name values must be unique")
        task_names.add(task_name)

        question = required_text(route, "question")
        expected_evidence = required_text(route, "expected_evidence")
        search = validate_search_config(route, kind, index)
        response_token = route.get("response_token")
        if not isinstance(response_token, str) or not TOKEN_RE.fullmatch(response_token):
            fail(f"route {index} has invalid response_token")
        if response_token in tokens:
            fail("response tokens must be unique")
        tokens.add(response_token)
        output_limit = route.get("output_limit_chars")
        if not isinstance(output_limit, int) or isinstance(output_limit, bool) or not 256 <= output_limit <= 8000:
            fail(f"route {index} output_limit_chars must be between 256 and 8000")

        attack_angle = route.get("attack_angle")
        if mode == "parallel" or phase == "verification":
            if not isinstance(attack_angle, str) or not attack_angle.strip():
                fail(f"route {index} requires a distinct attack_angle")
            normalized_angle = " ".join(attack_angle.lower().split())
            if normalized_angle in angles:
                fail("parallel or verification attack angles must be distinct")
            angles.add(normalized_angle)
        kinds.append(kind)
        normalized_routes.append({
            "task_kind": kind,
            "role": expected_role,
            "provider": expected_provider,
            "model": model,
            "model_override": model_override,
            "effort": effort,
            "difficulty": difficulty if kind in DIFFICULTY_KINDS else None,
            "selection_reason": selection_reason,
            "task_name": task_name,
            "question": question,
            "expected_evidence": expected_evidence,
            "response_token": response_token,
            "output_limit_chars": output_limit,
            "attack_angle": attack_angle.strip() if isinstance(attack_angle, str) else None,
            "search": search,
        })

    if phase == "editing" and (mode != "serial" or kinds != ["mechanical_edit"]):
        fail("editing must be one serial mechanical_edit route")
    if phase == "adjudication" and (mode != "serial" or len(kinds) != 1):
        fail("adjudication must be one serial Sol route")

    if tier == "critical" and phase == "verification":
        if not count_exact(kinds, {"local_verification": 1, "cross_module": 1}):
            fail("critical verification requires exactly one Luna and one Terra route")

    pending = {
        "batch_id": batch_id,
        "phase": phase,
        "routes": [
            {
                "task_kind": route["task_kind"],
                "role": route["role"],
                "provider": route["provider"],
                "model": route["model"],
                "effort": route["effort"],
                "task_name": route["task_name"],
                "response_token": route["response_token"],
                "output_limit_chars": route["output_limit_chars"],
            }
            for route in normalized_routes
        ],
        "validated_results": {},
    }
    next_state = with_receipt({
        "schema_version": STATE_SCHEMA_VERSION,
        "run_id": run_id,
        "tier": tier if TIER_RANK[tier] >= TIER_RANK[prior_tier] else prior_tier,
        "fix_round": fix_round,
        "spawned_total": prior_spawned + len(routes),
        "completed_batches": completed_batches,
        "pending_batch": pending,
    })
    result = {
        "valid": True,
        "run_id": run_id,
        "batch_id": batch_id,
        "batch_index": batch_index,
        "tier": tier,
        "derived_minimum_tier": minimum_tier,
        "phase": phase,
        "mode": mode,
        "spawn_interface": spawn_interface,
        "concurrent_cap": CONCURRENT_CAPS[tier],
        "remaining_child_budget": TOTAL_CAPS[tier] - next_state["spawned_total"],
        "routes": normalized_routes,
        "state_receipt": next_state["receipt"],
    }
    return result, next_state


def load_plan(path_arg: str) -> dict:
    if path_arg == "-":
        return json.load(__import__("sys").stdin)
    return json.loads(Path(path_arg).read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("plan")
    parser.add_argument("--state-file", required=True)
    args = parser.parse_args()
    state_path = Path(args.state_file)
    try:
        state = load_state(state_path)
        result, next_state = validate(load_plan(args.plan), state)
        write_state(state_path, next_state)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"INVALID DISPATCH PLAN: {exc}", file=__import__("sys").stderr)
        return 1
    print(json.dumps(result, ensure_ascii=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
