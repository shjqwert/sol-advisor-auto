#!/bin/sh
# Run Sol Advisor Python utilities with a compatible interpreter on Windows or POSIX.

set -eu

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

# An explicit path wins. Keep it to one executable path; interpreter arguments belong
# in the normal platform fallback below.
if [ -n "${SOL_ADVISOR_PYTHON-}" ]; then
  command -v "$SOL_ADVISOR_PYTHON" >/dev/null 2>&1 || fail "SOL_ADVISOR_PYTHON is not executable: $SOL_ADVISOR_PYTHON"
  exec "$SOL_ADVISOR_PYTHON" "$@"
fi

platform=$(uname -s 2>/dev/null || printf '%s' unknown)
case "$platform" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v python >/dev/null 2>&1; then
      exec python "$@"
    fi
    if command -v py >/dev/null 2>&1; then
      exec py -3 "$@"
    fi
    if command -v python3 >/dev/null 2>&1; then
      exec python3 "$@"
    fi
    ;;
  *)
    if command -v python3 >/dev/null 2>&1; then
      exec python3 "$@"
    fi
    if command -v python >/dev/null 2>&1; then
      exec python "$@"
    fi
    ;;
esac

fail "no Python interpreter found; install Python 3.11+ or set SOL_ADVISOR_PYTHON to an executable path"
