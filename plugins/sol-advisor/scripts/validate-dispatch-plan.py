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
    "repo_search": ("sol_advisor_repo_scout", "openai", "gpt-5.6-luna", {"xhigh"}, "read-only"),
    "precision_search": ("sol_advisor_precision_scout", "openai", "gpt-5.6-luna", {"max"}, "read-only"),
    "external_research": ("sol_advisor_external_researcher", "openai", "gpt-5.6-luna", {"xhigh", "max"}, "read-only"),
    "mechanical_edit": ("sol_advisor_mechanical_editor", "openai", "gpt-5.6-luna", {"max"}, "workspace-write"),
    "long_context": ("sol_advisor_context_analyst", "openai", "gpt-5.6-terra", {"xhigh"}, "read-only"),
    "cross_module": ("sol_advisor_context_analyst", "openai", "gpt-5.6-terra", {"max"}, "read-only"),
    "adversarial_verification": ("sol_advisor_deepseek_adversarial_verifier", "deepseek", "deepseek-v4-flash", {"xhigh"}, "read-only"),
    "local_verification": ("sol_advisor_local_code_verifier", "openai", "gpt-5.6-luna", {"max"}, "read-only"),
    "adjudicate_low": ("sol_advisor_final_adjudicator", "openai", "gpt-5.6-sol", {"medium"}, "read-only"),
    "adjudicate_standard": ("sol_advisor_final_adjudicator", "openai", "gpt-5.6-sol", {"high"}, "read-only"),
    "adjudicate_critical": ("sol_advisor_final_adjudicator", "openai", "gpt-5.6-sol", {"xhigh"}, "read-only"),
    "adjudicate_max": ("sol_advisor_final_adjudicator", "openai", "gpt-5.6-sol", {"max"}, "read-only"),
}

PHASE_KINDS = {
    "investigation": {"repo_search", "precision_search", "external_research", "long_context", "cross_module"},
    "editing": {"mechanical_edit"},
    "verification": {"adversarial_verification", "local_verification", "cross_module"},
    "adjudication": {"adjudicate_low", "adjudicate_standard", "adjudicate_critical", "adjudicate_max"},
}
CONCURRENT_CAPS = {"ordinary": 1, "complex": 2, "critical": 3}
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
TASK_NAME_RE = re.compile(r"^[a-z][a-z0-9_-]{2,48}$")
STATE_SCHEMA_VERSION = 1


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
    parent = path.parent.resolve(strict=True)
    if not parent.is_dir() or parent.is_symlink() or path.exists() and path.is_symlink():
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


def validate(plan: dict, state: dict | None = None) -> tuple[dict, dict]:
    if not isinstance(plan, dict):
        fail("plan must be a JSON object")
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
    deepseek = plan.get("deepseek")
    if tier not in CONCURRENT_CAPS:
        fail("tier must be ordinary, complex, or critical")
    minimum_tier = derived_tier(task_summary, risk_flags)
    if TIER_RANK[tier] < TIER_RANK[minimum_tier]:
        fail(f"tier {tier} under-reports the derived minimum tier {minimum_tier}")
    if phase not in PHASE_KINDS:
        fail("invalid phase")
    if mode not in {"serial", "parallel"}:
        fail("mode must be serial or parallel")
    if deepseek not in {"available", "unavailable", "not-required"}:
        fail("invalid deepseek state")

    spawn_interface = plan.get("spawn_interface")
    if spawn_interface == "multi_agent_v1":
        if plan.get("fork_context") is not False or "fork_turns" in plan:
            fail("multi_agent_v1 requires fork_context=false and forbids fork_turns")
    elif spawn_interface == "native_cli":
        if plan.get("fork_turns") != "none" or "fork_context" in plan:
            fail("native_cli requires fork_turns='none' and forbids fork_context")
    else:
        fail("spawn_interface must be multi_agent_v1 or native_cli")

    parent_sandbox = plan.get("parent_sandbox")
    parent_permission = required_text(plan, "parent_permission_profile_type", 100)
    if parent_sandbox not in {"read-only", "workspace-write", "danger-full-access"}:
        fail("parent_sandbox must be an observed Codex sandbox type")
    available_agents = set(required_text_list(plan, "available_agent_types"))
    available_models = set(required_text_list(plan, "available_models"))
    available_providers = set(required_text_list(plan, "available_providers"))

    if state is None:
        if batch_index != 0 or fix_round != 0:
            fail("a new run must begin at batch_index=0 and fix_round=0")
        prior_spawned = 0
        completed_batches: list[dict] = []
        prior_tier = tier
        prior_deepseek = "not-required"
        fallback_completed = False
    else:
        if run_id != state.get("run_id"):
            fail("run_id does not match the state file")
        if batch_index != len(state.get("completed_batches", [])):
            fail("batch_index must advance monotonically from completed state")
        if fix_round < state.get("fix_round", 0) or fix_round > state.get("fix_round", 0) + 1:
            fail("fix_round cannot decrease or advance by more than one")
        if TIER_RANK[tier] < TIER_RANK[state.get("tier")]:
            fail("tier cannot decrease during a run")
        if state.get("deepseek") == "unavailable" and deepseek != "unavailable":
            fail("DeepSeek unavailable state cannot recover within the same run")
        prior_spawned = state.get("spawned_total", 0)
        completed_batches = deepcopy(state.get("completed_batches", []))
        prior_tier = state.get("tier")
        prior_deepseek = state.get("deepseek")
        fallback_completed = bool(state.get("fallback_verification_completed"))

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
    access_modes: set[str] = set()
    for index, route in enumerate(routes):
        if not isinstance(route, dict):
            fail(f"route {index} must be an object")
        kind = route.get("task_kind")
        if kind not in ROUTES or kind not in PHASE_KINDS[phase]:
            fail(f"route {index} is not allowed in phase {phase}")
        expected_role, expected_provider, expected_model, efforts, expected_access = ROUTES[kind]
        observed = (route.get("role"), route.get("provider"), route.get("model"), route.get("access"))
        expected = (expected_role, expected_provider, expected_model, expected_access)
        if observed != expected or route.get("effort") not in efforts:
            fail(f"route {index} does not match the allowed task-role-model-effort-access mapping")
        if expected_role not in available_agents:
            fail(f"route {index} agent type is not exposed by the current runtime")
        if expected_provider not in available_providers:
            fail(f"route {index} provider is not available in the current runtime")
        if expected_provider == "openai" and expected_model not in available_models:
            fail(f"route {index} model is not available in the current runtime")

        task_name = route.get("task_name")
        if spawn_interface == "native_cli":
            if not isinstance(task_name, str) or not TASK_NAME_RE.fullmatch(task_name):
                fail(f"route {index} requires a valid native_cli task_name")
            if task_name in task_names:
                fail("native_cli task_name values must be unique")
            task_names.add(task_name)
        elif task_name is not None:
            fail("multi_agent_v1 routes must not include native_cli task_name")

        question = required_text(route, "question")
        expected_evidence = required_text(route, "expected_evidence")
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
        if mode == "parallel" and expected_access != "read-only":
            fail("parallel routes must be read-only")

        access_modes.add(expected_access)
        kinds.append(kind)
        normalized_routes.append({
            "task_kind": kind,
            "role": expected_role,
            "provider": expected_provider,
            "model": expected_model,
            "effort": route["effort"],
            "access": expected_access,
            "task_name": task_name if spawn_interface == "native_cli" else None,
            "question": question,
            "expected_evidence": expected_evidence,
            "response_token": response_token,
            "output_limit_chars": output_limit,
            "attack_angle": attack_angle.strip() if isinstance(attack_angle, str) else None,
        })

    if len(access_modes) != 1 or parent_sandbox != next(iter(access_modes)):
        fail("effective parent sandbox must exactly match every route before spawn")
    if parent_permission.lower() in {"unknown", "unobservable"}:
        fail("parent permission profile must be observable before spawn")
    if phase == "editing" and (mode != "serial" or kinds != ["mechanical_edit"]):
        fail("editing must be one serial mechanical_edit route")
    if phase == "adjudication" and (mode != "serial" or len(kinds) != 1):
        fail("adjudication must be one serial Sol route")

    if "adversarial_verification" in kinds and deepseek != "available":
        fail("DeepSeek route requires deepseek=available")
    if deepseek == "unavailable" and "adversarial_verification" in kinds:
        fail("DeepSeek-unavailable batches cannot include DeepSeek")
    if tier == "critical" and phase == "verification":
        if deepseek == "available":
            expected_counts = {"adversarial_verification": 1, "local_verification": 1}
            if "cross_module" in kinds:
                expected_counts["cross_module"] = 1
            if not count_exact(kinds, expected_counts):
                fail("critical verification requires exactly one DeepSeek, one Luna, and optional one Terra route")
        elif deepseek == "unavailable":
            if not plan.get("degraded_independence") or not count_exact(kinds, {"local_verification": 1, "cross_module": 1}):
                fail("DeepSeek-unavailable critical verification requires exactly Luna and Terra with disclosure")
        else:
            fail("critical verification requires an explicit DeepSeek availability state")
    if phase == "adjudication" and deepseek == "unavailable":
        if not plan.get("degraded_independence") or kinds != ["adjudicate_max"]:
            fail("DeepSeek-unavailable adjudication requires disclosed Sol/Max")
        if not fallback_completed:
            fail("DeepSeek-unavailable adjudication requires validated Luna+Terra results from a prior batch")

    next_deepseek = "unavailable" if deepseek == "unavailable" or prior_deepseek == "unavailable" else deepseek
    pending = {
        "batch_id": batch_id,
        "phase": phase,
        "deepseek": deepseek,
        "degraded_independence": bool(plan.get("degraded_independence")),
        "fallback_verification": tier == "critical" and phase == "verification" and deepseek == "unavailable",
        "routes": [
            {
                "task_kind": route["task_kind"],
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
        "deepseek": next_deepseek,
        "spawned_total": prior_spawned + len(routes),
        "fallback_verification_completed": fallback_completed,
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
