"""Fetch a ptr727/ProjectTemplate script fresh from `main` and run it in-process.

Never pinned or vendored: a pin nothing keeps current goes stale by construction, and CI
(this repo's own, and the hub's) is the backstop for a change that lands broken on `main`.
A fetch failure fails the caller loudly rather than silently skipping the gate it guards.
Usage: hub_fetch_run.py <hub-relative-path> [script-args...]
Example: hub_fetch_run.py .github/actions/prose-gate/prose_lint.py . --diff HEAD
"""

import os
import re
import runpy
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

HUB_REPO = "ptr727/ProjectTemplate"
HUB_RAW_BASE = f"https://raw.githubusercontent.com/{HUB_REPO}"
HUB_MAIN_SHA_URL = f"https://api.github.com/repos/{HUB_REPO}/commits/main"
PROVENANCE_VAR = "PROSE_GATE_PROVENANCE"
PROSE_GATE_PATH = ".github/actions/prose-gate/prose_lint.py"
PROBE_TIMEOUT = 30
LOOKUP_TIMEOUT = 5
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"


def resolve_main_commit() -> str | None:
    """Return the full commit hash `main` points at now, or None when it cannot be resolved.

    Any failure prints one line naming the cause and returns None, so the gate still runs.
    """
    token = (os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or "").strip()
    request = urllib.request.Request(
        HUB_MAIN_SHA_URL, headers={"Accept": "application/vnd.github.sha"}
    )
    if token:
        request.add_unredirected_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request, timeout=LOOKUP_TIMEOUT) as response:
            sha = response.read().decode(errors="replace").strip()
    except urllib.error.HTTPError as exc:
        reason = f"HTTP {exc.code}"
    except Exception as exc:  # noqa: BLE001
        reason = type(exc).__name__
    else:
        if re.fullmatch(r"[0-9a-f]{40}", sha):
            return sha
        reason = "unexpected response body"
    print(
        f"hub_fetch_run: could not resolve the main commit ({reason}), using main.",
        file=sys.stderr,
    )
    return None


def head_is_unborn() -> bool:
    """Whether HEAD is confirmed unborn (a real branch, no commits yet), never guessed.

    `git rev-parse --verify -q HEAD` exits 1 with empty stderr for a confirmed unborn HEAD,
    verified directly: a fresh `git init` with no commits gives exactly that signature. Any
    other shape, a non-git directory (exit 128, a `fatal:` message even with `-q`), a missing
    or broken git executable (raised as OSError), a hung probe (a timeout), a permission error,
    or any other failure, is a probe failure to propagate, never a reason to guess at the scope.
    """
    try:
        probe = subprocess.run(
            ["git", "rev-parse", "--verify", "-q", "HEAD"],
            capture_output=True,
            check=False,
            timeout=PROBE_TIMEOUT,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(f"hub_fetch_run: could not run git to probe HEAD: {exc}", file=sys.stderr)
        sys.exit(1)
    if probe.returncode == 1 and not probe.stderr:
        return True
    if probe.returncode == 0:
        return False
    print(
        f"hub_fetch_run: git rev-parse --verify -q HEAD failed unexpectedly "
        f"(exit {probe.returncode}): {probe.stderr.decode(errors='replace').strip()}",
        file=sys.stderr,
    )
    sys.exit(1)


def resolve_unborn_head(argv: list[str]) -> list[str]:
    """Replace a `--diff HEAD` pair with git's empty-tree hash when HEAD does not exist yet.

    A brand-new repository's first commit has no HEAD to diff against, and the fetched gate
    scripts refuse to widen to a whole-tree scan rather than report the backlog as new. The
    empty tree diffs cleanly against everything staged, which is the correct scope for a first
    commit. Any other `--diff` value passes through unchanged.
    """
    out = list(argv)
    for i, token in enumerate(out[:-1]):
        if token == "--diff" and out[i + 1] == "HEAD" and head_is_unborn():
            out[i + 1] = EMPTY_TREE
    return out


USAGE = "usage: hub_fetch_run.py <hub-relative-path> [script-args...]"


def main(argv: list[str]) -> int:
    if argv[:1] in (["-h"], ["--help"]):
        print(USAGE)
        return 0
    if not argv or argv[0].startswith("-"):
        problem = f"unknown option {argv[0]!r}, " if argv else ""
        print(f"hub_fetch_run: {problem}{USAGE}", file=sys.stderr)
        return 2
    hub_path, script_args = argv[0], resolve_unborn_head(argv[1:])
    is_prose_gate = hub_path == PROSE_GATE_PATH
    commit = resolve_main_commit() if is_prose_gate else None
    ref = commit or "main"
    url = f"{HUB_RAW_BASE}/{ref}/{hub_path}"
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            content = response.read()
    except (urllib.error.URLError, OSError) as exc:
        print(f"hub_fetch_run: could not fetch {url}: {exc}", file=sys.stderr)
        print("hub_fetch_run: the gate did not run.", file=sys.stderr)
        return 1
    with tempfile.NamedTemporaryFile(suffix=".py", delete=False) as handle:
        handle.write(content)
        tmp_path = Path(handle.name)
    old_argv = sys.argv
    old_provenance = os.environ.get(PROVENANCE_VAR)
    if is_prose_gate and not (old_provenance or "").strip():
        if commit:
            os.environ[PROVENANCE_VAR] = f"{HUB_REPO}@{commit} (hub-fetch-run main)"
        else:
            os.environ[PROVENANCE_VAR] = f"{HUB_REPO}@main (hub-fetch-run, commit unresolved)"
    try:
        sys.argv = [str(tmp_path), *script_args]
        try:
            runpy.run_path(str(tmp_path), run_name="__main__")
        except SystemExit as exc:
            if exc.code is None:
                return 0
            return exc.code if isinstance(exc.code, int) else 1
        return 0
    finally:
        sys.argv = old_argv
        if old_provenance is None:
            os.environ.pop(PROVENANCE_VAR, None)
        else:
            os.environ[PROVENANCE_VAR] = old_provenance
        tmp_path.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
