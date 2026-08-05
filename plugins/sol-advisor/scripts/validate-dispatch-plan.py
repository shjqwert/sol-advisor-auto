#!/usr/bin/env python3
"""Validate one Sol Advisor native-agent dispatch batch."""

from __future__ import annotations

import json
from pathlib import Path
import re
import sys


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

CONCURRENT_CAPS = {"ordinary": 1, "complex": 2, "critical": 3}
TOTAL_CAPS = {"ordinary": 1, "complex": 3, "critical": 5}
TOKEN_RE = re.compile(r"^SOL_ADVISOR_[A-Z0-9_]{8,64}$")


def fail(message: str) -> None:
    raise ValueError(message)


def required_text(obj: dict, key: str, limit: int = 2000) -> str:
    value = obj.get(key)
    if not isinstance(value, str) or not value.strip() or len(value) > limit:
        fail(f"{key} must be non-empty text no longer than {limit} characters")
    return value.strip()


def load_plan(path_arg: str) -> dict:
    if path_arg == "-":
        return json.load(sys.stdin)
    return json.loads(Path(path_arg).read_text(encoding="utf-8"))


def validate(plan: dict) -> dict:
    if not isinstance(plan, dict):
        fail("plan must be a JSON object")

    tier = plan.get("tier")
    phase = plan.get("phase")
    mode = plan.get("mode")
    deepseek = plan.get("deepseek")
    if tier not in CONCURRENT_CAPS:
        fail("tier must be ordinary, complex, or critical")
    if phase not in {"investigation", "editing", "verification", "adjudication"}:
        fail("invalid phase")
    if mode not in {"serial", "parallel"}:
        fail("mode must be serial or parallel")
    if deepseek not in {"available", "unavailable", "not-required"}:
        fail("invalid deepseek state")

    fix_round = plan.get("fix_round")
    max_fix_rounds = plan.get("max_fix_rounds")
    spawned_so_far = plan.get("spawned_so_far")
    max_total_children = plan.get("max_total_children")
    for name, value in {
        "fix_round": fix_round,
        "max_fix_rounds": max_fix_rounds,
        "spawned_so_far": spawned_so_far,
        "max_total_children": max_total_children,
    }.items():
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            fail(f"{name} must be a non-negative integer")
    if max_fix_rounds > 2 or fix_round > max_fix_rounds:
        fail("fix-round budget exceeded")
    if max_total_children != TOTAL_CAPS[tier]:
        fail(f"max_total_children must be {TOTAL_CAPS[tier]} for tier {tier}")

    routes = plan.get("routes")
    if not isinstance(routes, list) or not routes:
        fail("routes must be a non-empty array")
    if len(routes) > CONCURRENT_CAPS[tier]:
        fail(f"concurrent route cap exceeded for tier {tier}")
    if spawned_so_far + len(routes) > max_total_children:
        fail("total child budget exceeded")
    if mode == "serial" and len(routes) != 1:
        fail("serial batches must contain exactly one route")
    if mode == "parallel" and len(routes) < 2:
        fail("parallel batches must contain at least two routes")

    tokens: set[str] = set()
    angles: set[str] = set()
    kinds: list[str] = []
    normalized_routes = []
    for index, route in enumerate(routes):
        if not isinstance(route, dict):
            fail(f"route {index} must be an object")
        kind = route.get("task_kind")
        if kind not in ROUTES:
            fail(f"route {index} has invalid task_kind")
        expected_role, expected_provider, expected_model, efforts, expected_access = ROUTES[kind]
        observed = (route.get("role"), route.get("provider"), route.get("model"), route.get("access"))
        expected = (expected_role, expected_provider, expected_model, expected_access)
        if observed != expected or route.get("effort") not in efforts:
            fail(f"route {index} does not match the allowed task-role-model-effort-access mapping")

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
        kinds.append(kind)
        normalized_routes.append({
            "task_kind": kind,
            "role": expected_role,
            "provider": expected_provider,
            "model": expected_model,
            "effort": route["effort"],
            "access": expected_access,
            "question": question,
            "expected_evidence": expected_evidence,
            "response_token": response_token,
            "output_limit_chars": output_limit,
            "attack_angle": attack_angle.strip() if isinstance(attack_angle, str) else None,
        })

    if phase == "editing" and (mode != "serial" or kinds != ["mechanical_edit"]):
        fail("editing must be one serial mechanical_edit route")
    if "mechanical_edit" in kinds and (phase != "editing" or len(routes) != 1):
        fail("mechanical_edit cannot share a batch")

    if tier == "critical" and phase == "verification":
        kind_set = set(kinds)
        if deepseek == "available":
            required = {"adversarial_verification", "local_verification"}
            if not required.issubset(kind_set):
                fail("critical verification requires independent DeepSeek and Luna routes")
            if kind_set - required - {"cross_module"}:
                fail("critical verification permits only DeepSeek, Luna, and optional Terra")
        elif deepseek == "unavailable":
            if not plan.get("degraded_independence"):
                fail("DeepSeek-unavailable verification must disclose degraded independence")
            if kind_set != {"local_verification", "cross_module"}:
                fail("DeepSeek-unavailable critical verification requires Luna and Terra")
        else:
            fail("critical verification requires an explicit DeepSeek availability state")

    if phase == "adjudication" and deepseek == "unavailable":
        if not plan.get("degraded_independence") or kinds != ["adjudicate_max"]:
            fail("DeepSeek-unavailable adjudication requires disclosed Sol/Max")

    return {
        "valid": True,
        "tier": tier,
        "phase": phase,
        "mode": mode,
        "concurrent_cap": CONCURRENT_CAPS[tier],
        "remaining_child_budget": max_total_children - spawned_so_far - len(routes),
        "routes": normalized_routes,
    }


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate-dispatch-plan.py <plan.json|->", file=sys.stderr)
        return 2
    try:
        result = validate(load_plan(sys.argv[1]))
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"INVALID DISPATCH PLAN: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
