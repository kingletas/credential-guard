#!/usr/bin/env bash
#
# The end-to-end tests. `credential-guard self-test` covers the scanner's own
# patterns; this covers the parts that only exist once there is a git repository
# in the picture -- history scanning, and the two install paths.
#
# Usage:
#   tests/run.sh

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$HERE/bin/credential-guard"
passed=0
failed=0

ok()   { passed=$((passed + 1)); echo "  ok   $1"; }
bad()  { failed=$((failed + 1)); echo "  FAIL $1"; }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (got '$2', wanted '$3')"; fi; }
# Helpers rather than `test && ok || bad`: in that form `bad` also runs when
# `ok` itself fails, which is the classic way a test harness lies about itself.
# They take the thing to check as arguments rather than as a string to eval,
# so nothing here goes through a second round of word splitting.
want_file() { if [[ -f "$1" ]]; then ok "$2"; else bad "$2"; fi; }
want_exec() { if [[ -x "$1" ]]; then ok "$2"; else bad "$2"; fi; }
want_grep() { if grep -q "$1" "$2"; then ok "$3"; else bad "$3"; fi; }
saw()     { if grep -q "$1" <<<"$2"; then ok "$3"; else bad "$3"; fi; }
saw_not() { if grep -q "$1" <<<"$2"; then bad "$3"; else ok "$3"; fi; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A repository with a real-looking key in a commit that is later "fixed" by
# deleting the line. This is the shape the history scan exists for.
repo="$work/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name Test

echo "credential-guard tests"

# --- the scanner, through the wrapper ------------------------------------
printf 'name = "hello"\n' > "$repo/clean.py"
git -C "$repo" add -A && git -C "$repo" commit -qm "clean"
"$GUARD" scan "$repo" >/dev/null 2>&1
check "a clean tree passes" "$?" "0"

# --- history: a key added and later removed is STILL in the repository ----
# Not AKIAIOSFODNN7EXAMPLE: that is AWS's own documented example key and the
# scanner treats it as a placeholder, correctly. This is a shape it refuses.
printf 'api_key = "sk_live_9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c"  \n' > "$repo/leak.py"  # pragma: allowlist secret
git -C "$repo" add -A && git -C "$repo" commit -qm "oops"
printf 'api_key = ""\n' > "$repo/leak.py"
git -C "$repo" add -A && git -C "$repo" commit -qm "removed it"

"$GUARD" scan "$repo" >/dev/null 2>&1
check "the working tree is clean again after the removal" "$?" "0"

"$GUARD" history "$repo" >/dev/null 2>&1
check "but history still refuses -- the blob is still in the repository" "$?" "1"

# --- install: no pre-commit framework, no existing hook -------------------
"$GUARD" install "$repo" >/dev/null 2>&1
want_file "$repo/scripts/check_credentials.py" "install vendors the scanner"
want_exec "$repo/.git/hooks/pre-commit" "install writes an executable git hook"

# The vendored copy must be usable on its own -- that is its entire purpose.
python3 "$repo/scripts/check_credentials.py" "$repo/clean.py" >/dev/null 2>&1
check "the vendored scanner runs standalone" "$?" "0"

# --- install: an existing hook is never clobbered -------------------------
repo2="$work/repo2"
mkdir -p "$repo2/.git/hooks"
git -C "$repo2" init -q
printf '#!/bin/sh\necho mine\n' > "$repo2/.git/hooks/pre-commit"
chmod +x "$repo2/.git/hooks/pre-commit"
"$GUARD" install "$repo2" >/dev/null 2>&1
want_grep "echo mine" "$repo2/.git/hooks/pre-commit" "an existing pre-commit hook is left alone"

# --- a subdirectory scan resolves paths against the repository root -------
# `git ls-files --full-name` prints repo-root-relative paths. Joining those onto
# the path argument doubles the prefix, so every file is handed to the scanner
# under a path that is not there -- and the tree is reported without being read.
repo3="$work/repo3"
mkdir -p "$repo3/module/Api" "$repo3/module/empty-untracked"
git -C "$repo3" init -q
git -C "$repo3" config user.email t@example.com
git -C "$repo3" config user.name Test
printf 'name = "hello"\n' > "$repo3/module/Api/Clean.php"
printf 'name = "hello"\n' > "$repo3/top.php"
git -C "$repo3" add -A && git -C "$repo3" commit -qm "clean"

out="$("$GUARD" scan "$repo3/module" 2>&1)"; rc=$?
check   "a clean subdirectory scan passes" "$rc" "0"
saw     "scanning 1 file" "$out" "a subdirectory scan lists only that subdirectory"
saw_not "not scanned"     "$out" "a subdirectory scan opens every file it listed"

out="$(cd "$repo3/module" && "$GUARD" scan . 2>&1)"; rc=$?
check   "scanning . from inside a subdirectory passes" "$rc" "0"
saw_not "not scanned" "$out" "and opens every file it listed"

# The scan has to be reading, not merely failing to error.
printf 'api_key = "sk_live_9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c"\n' > "$repo3/module/Api/Leak.php"  # pragma: allowlist secret
git -C "$repo3" add -A && git -C "$repo3" commit -qm "a leak in a subdirectory"
out="$("$GUARD" scan "$repo3/module" 2>&1)"; rc=$?
check   "a leak inside a subdirectory is caught" "$rc" "1"
saw     "module/Api/Leak.php" "$out" "the finding names the file"
saw_not "module/module"       "$out" "the repository-relative prefix is not doubled"

# --- nothing scanned is a failure, never a pass ---------------------------
"$GUARD" scan "$repo3/module/empty-untracked" >/dev/null 2>&1
check "a directory holding no tracked file fails rather than passing" "$?" "1"

"$GUARD" scan "$repo3/no-such-directory" >/dev/null 2>&1
check "a target that does not exist fails" "$?" "2"

SCANNER="$HERE/bin/check_credentials.py"
python3 "$SCANNER" >/dev/null 2>&1
check "the scanner given no file at all fails" "$?" "2"

out="$(python3 "$SCANNER" "$work/gone-a.php" "$work/gone-b.php" 2>&1)"; rc=$?
check   "the scanner that could open none of its files fails" "$rc" "2"
saw     "nothing was scanned"     "$out" "and says so plainly"
saw_not "looks like a credential" "$out" "and does not report an unreadable file as a credential"

out="$(python3 "$SCANNER" "$repo3/top.php" "$work/gone-a.php" 2>&1)"; rc=$?
check "one unreadable file among readable ones still fails" "$rc" "1"
saw   "1 of 2 file(s) could not be scanned" "$out" "and says how many it could not open"

# --- the scanner's own patterns -------------------------------------------
"$GUARD" self-test >/dev/null 2>&1
check "the scanner's self-test passes" "$?" "0"

echo "credential-guard tests: $passed passed$([[ $failed -gt 0 ]] && echo ", $failed FAILED")"
[[ $failed -eq 0 ]]
