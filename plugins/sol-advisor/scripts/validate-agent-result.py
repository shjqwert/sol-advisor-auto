#!/usr/bin/env python3
"""Validate one task-adaptive child result and advance Sol Advisor run state."""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import tempfile
from urllib.parse import urlparse


STATE_SCHEMA_VERSION = 8
VALID_STATUSES = {"finding", "no_finding", "completed", "unresolved"}
RESULT_JSON_START = "<!-- SOL_ADVISOR_RESULT_JSON_START\n"
RESULT_JSON_END = "\nSOL_ADVISOR_RESULT_JSON_END -->"
VISIBLE_OUTPUT_LIMIT_CHARS = 2000


def fail(message: str) -> None:
    raise ValueError(message)


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
    if state.get("receipt") != with_receipt(state)["receipt"]:
        fail("state file receipt mismatch")
    if not isinstance(state.get("completed_batches"), list):
        fail("state completed_batches must be an array")


def required_text(obj: dict, key: str, limit: int = 2000) -> str:
    value = obj.get(key)
    if not isinstance(value, str) or not value.strip() or len(value) > limit:
        fail(f"{key} must be non-empty text no longer than {limit} characters")
    return value.strip()


def required_text_list(obj: dict, key: str) -> list[str]:
    value = obj.get(key)
    if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item.strip() for item in value):
        fail(f"{key} must be a non-empty array of non-empty strings")
    return [item.strip() for item in value]


def required_object_list(obj: dict, key: str) -> list[dict]:
    value = obj.get(key)
    if not isinstance(value, list) or not value or any(not isinstance(item, dict) for item in value):
        fail(f"{key} must be a non-empty array of objects")
    return value


def extract_result(raw_text: str) -> tuple[str, str, dict]:
    if not isinstance(raw_text, str) or not raw_text.strip():
        fail("child result must be non-empty text")
    normalized = raw_text.replace("\r\n", "\n").strip()
    if normalized.count(RESULT_JSON_START) != 1 or normalized.count(RESULT_JSON_END) != 1:
        fail("child result must contain exactly one hidden machine-result envelope")
    start = normalized.index(RESULT_JSON_START)
    payload_start = start + len(RESULT_JSON_START)
    end = normalized.index(RESULT_JSON_END, payload_start)
    if normalized[end + len(RESULT_JSON_END):].strip():
        fail("child result must not contain text after the hidden machine-result envelope")
    visible = normalized[:start].strip()
    payload_text = normalized[payload_start:end].strip()
    if not visible.startswith("## 结论 / Result"):
        fail("visible child result must start with the readable result heading")
    if len(visible) > VISIBLE_OUTPUT_LIMIT_CHARS:
        fail("visible child result exceeds its 2000-character limit")
    if not payload_text:
        fail("hidden machine-result payload must not be empty")
    result = json.loads(payload_text)
    if not isinstance(result, dict):
        fail("hidden machine-result payload must be one JSON object")
    return visible, payload_text, result


def validate_locators(result: dict) -> None:
    for locator in required_object_list(result, "locators"):
        required_text(locator, "path", 1000)
        required_text(locator, "relevance", 1000)
        if "line" in locator and (not isinstance(locator["line"], int) or isinstance(locator["line"], bool) or locator["line"] < 1):
            fail("locator line must be a positive integer")


def validate_sources(result: dict) -> None:
    for source in required_object_list(result, "sources"):
        url = required_text(source, "url", 2000)
        if urlparse(url).scheme not in {"http", "https"}:
            fail("source url must be an http(s) link")
        if source.get("source_class") not in {"primary", "secondary"}:
            fail("source_class must be primary or secondary")
        required_text(source, "retrieved_date", 32)
        required_text(source, "applicability", 1000)
        required_text(source, "claim", 1500)
        if source.get("fact_or_inference") not in {"fact", "inference"}:
            fail("fact_or_inference must be fact or inference")


def validate_findings(result: dict) -> None:
    for finding in required_object_list(result, "findings"):
        required_text(finding, "trigger", 1500)
        required_text(finding, "impact", 1500)
        required_text(finding, "locator", 1500)


def validate_nucleus(kind: str, status: str, result: dict) -> None:
    if kind in {"repo_search", "precision_search"} and "sources" in result:
        fail("local investigation results must not include external sources")
    if kind == "external_research" and "locators" in result:
        fail("external research results must not include repository locators")
    if status == "unresolved":
        required_text_list(result, "unknowns")
        return
    if status == "no_finding":
        return
    if kind in {"repo_search", "precision_search", "long_context", "cross_module"}:
        validate_locators(result)
    elif kind == "external_research":
        validate_sources(result)
    elif kind == "local_verification":
        if status != "finding":
            fail("verification results must be finding, no_finding, or unresolved")
        validate_findings(result)
    elif kind == "mechanical_edit":
        required_text_list(result, "changed_files")
        for check in required_object_list(result, "verification"):
            required_text(check, "command", 2000)
            required_text(check, "result", 2000)
    elif kind.startswith("adjudicate_"):
        if result.get("decision") not in {"ship", "fix-first", "rethink"}:
            fail("adjudication decision must be ship, fix-first, or rethink")
        required_text(result, "rationale", 2000)
    else:
        fail("state contains an unknown task kind")


def validate_runtime_metadata(metadata: dict, route: dict) -> str:
    if not isinstance(metadata, dict):
        fail("runtime metadata must be one JSON object")
    for key in (
        "thread_id",
        "agent_role",
        "model_provider",
        "model",
        "effort",
        "cwd",
    ):
        required_text(metadata, key, 2000)
    observed = (
        metadata["agent_role"],
        metadata["model_provider"],
        metadata["model"],
        metadata["effort"],
    )
    expected = (
        route["role"],
        route["provider"],
        route["model"],
        route["effort"],
    )
    if observed != expected:
        fail("runtime role, model, or effort does not match the pending route")
    return metadata["thread_id"]


def load_state(path: Path) -> dict:
    if not path.is_file() or path.is_symlink():
        fail("state path must be a regular non-symlink file")
    state = json.loads(path.read_text(encoding="utf-8"))
    verify_state(state)
    return state


def write_state(path: Path, state: dict) -> None:
    declared_parent = path.parent
    if declared_parent.is_symlink():
        fail("state path is not safe to replace")
    parent = declared_parent.resolve(strict=True)
    if not parent.is_dir() or path.is_symlink():
        fail("state path is not safe to replace")
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


def validate_result(raw_text: str, state: dict, runtime_metadata: dict) -> tuple[dict, dict]:
    verify_state(state)
    pending = state.get("pending_batch")
    if not isinstance(pending, dict):
        fail("there is no pending batch for this result")
    visible, payload_text, result = extract_result(raw_text)
    token = required_text(result, "response_token", 100)
    pending_routes = pending.get("routes")
    validated_results = pending.get("validated_results")
    if not isinstance(pending_routes, list) or not pending_routes or not isinstance(validated_results, dict):
        fail("pending batch routes or validated results are malformed")
    routes = {}
    for index, pending_route in enumerate(pending_routes):
        if not isinstance(pending_route, dict):
            fail(f"pending route {index} must be an object")
        for key in ("task_kind", "role", "provider", "model", "effort", "response_token"):
            required_text(pending_route, key, 2000)
        output_limit = pending_route.get("output_limit_chars")
        if not isinstance(output_limit, int) or isinstance(output_limit, bool) or not 256 <= output_limit <= 8000:
            fail(f"pending route {index} has an invalid output limit")
        route_token = pending_route["response_token"]
        if route_token in routes:
            fail("pending route response tokens must be unique")
        routes[route_token] = pending_route
    route = routes.get(token)
    if route is None:
        fail("response token does not belong to the pending batch")
    if token in pending.get("validated_results", {}):
        fail("response token was already validated")
    runtime_thread_id = validate_runtime_metadata(runtime_metadata, route)
    if len(payload_text) > route["output_limit_chars"]:
        fail("hidden machine-result payload exceeds its validated character limit")
    status = result.get("status")
    if status not in VALID_STATUSES:
        fail("status must be finding, no_finding, completed, or unresolved")
    summary = required_text(result, "summary", 1500)
    required_text_list(result, "scope")
    if summary not in visible:
        fail("visible child result must include the exact machine summary")
    if f"- 状态 / Status: `{status}`" not in visible:
        fail("visible child result must include the exact machine status")
    if "- 范围 / Scope:" not in visible or "- 详情 / Details:" not in visible:
        fail("visible child result must include readable scope and details")
    validate_nucleus(route["task_kind"], status, result)

    next_state = deepcopy(state)
    next_pending = next_state["pending_batch"]
    next_pending["validated_results"][token] = status
    expected_tokens = {item["response_token"] for item in next_pending["routes"]}
    validated_tokens = set(next_pending["validated_results"])
    batch_completed = validated_tokens == expected_tokens
    if batch_completed:
        statuses = dict(next_pending["validated_results"])
        next_state["completed_batches"].append({
            "batch_id": next_pending["batch_id"],
            "phase": next_pending["phase"],
            "statuses": statuses,
        })
        next_state["pending_batch"] = None
    next_state = with_receipt(next_state)
    return {
        "valid": True,
        "batch_id": pending["batch_id"],
        "response_token": token,
        "task_kind": route["task_kind"],
        "status": status,
        "batch_completed": batch_completed,
        "runtime_thread_id": runtime_thread_id,
        "visible_chars": len(visible),
        "machine_payload_chars": len(payload_text),
        "state_receipt": next_state["receipt"],
    }, next_state


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("result")
    parser.add_argument("--state-file", required=True)
    parser.add_argument("--runtime-metadata", required=True)
    args = parser.parse_args()
    state_path = Path(args.state_file)
    try:
        raw_text = __import__("sys").stdin.read() if args.result == "-" else Path(args.result).read_text(encoding="utf-8")
        runtime_metadata = json.loads(Path(args.runtime_metadata).read_text(encoding="utf-8"))
        result, next_state = validate_result(raw_text, load_state(state_path), runtime_metadata)
        write_state(state_path, next_state)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"INVALID AGENT RESULT: {exc}", file=__import__("sys").stderr)
        return 1
    print(json.dumps(result, ensure_ascii=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
