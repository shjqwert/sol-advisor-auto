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


STATE_SCHEMA_VERSION = 1
VALID_STATUSES = {"finding", "no_finding", "completed", "unresolved"}


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
    if status == "unresolved":
        required_text_list(result, "unknowns")
        return
    if status == "no_finding":
        return
    if kind in {"repo_search", "precision_search", "long_context", "cross_module"}:
        validate_locators(result)
    elif kind == "external_research":
        validate_sources(result)
    elif kind in {"adversarial_verification", "local_verification"}:
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


def load_state(path: Path) -> dict:
    if not path.is_file() or path.is_symlink():
        fail("state path must be a regular non-symlink file")
    state = json.loads(path.read_text(encoding="utf-8"))
    verify_state(state)
    return state


def write_state(path: Path, state: dict) -> None:
    parent = path.parent.resolve(strict=True)
    if not parent.is_dir() or parent.is_symlink() or path.is_symlink():
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


def validate_result(raw_text: str, state: dict) -> tuple[dict, dict]:
    verify_state(state)
    pending = state.get("pending_batch")
    if not isinstance(pending, dict):
        fail("there is no pending batch for this result")
    result = json.loads(raw_text)
    if not isinstance(result, dict):
        fail("child result must be one JSON object")
    token = required_text(result, "response_token", 100)
    routes = {route["response_token"]: route for route in pending.get("routes", [])}
    route = routes.get(token)
    if route is None:
        fail("response token does not belong to the pending batch")
    if token in pending.get("validated_results", {}):
        fail("response token was already validated")
    if len(raw_text) > route["output_limit_chars"]:
        fail("actual child output exceeds its validated character limit")
    status = result.get("status")
    if status not in VALID_STATUSES:
        fail("status must be finding, no_finding, completed, or unresolved")
    required_text(result, "summary", 1500)
    required_text_list(result, "scope")
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
            "deepseek": next_pending["deepseek"],
            "statuses": statuses,
        })
        if next_pending.get("fallback_verification") and all(value != "unresolved" for value in statuses.values()):
            next_state["fallback_verification_completed"] = True
        next_state["pending_batch"] = None
    next_state = with_receipt(next_state)
    return {
        "valid": True,
        "batch_id": pending["batch_id"],
        "response_token": token,
        "task_kind": route["task_kind"],
        "status": status,
        "batch_completed": batch_completed,
        "state_receipt": next_state["receipt"],
    }, next_state


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("result")
    parser.add_argument("--state-file", required=True)
    args = parser.parse_args()
    state_path = Path(args.state_file)
    try:
        raw_text = __import__("sys").stdin.read() if args.result == "-" else Path(args.result).read_text(encoding="utf-8")
        result, next_state = validate_result(raw_text, load_state(state_path))
        write_state(state_path, next_state)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"INVALID AGENT RESULT: {exc}", file=__import__("sys").stderr)
        return 1
    print(json.dumps(result, ensure_ascii=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
