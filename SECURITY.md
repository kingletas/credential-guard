# Security Policy

## Reporting a vulnerability

**Please do not open a public issue.** Use GitHub's private vulnerability reporting on this repository (*Security* → *Report a vulnerability*), or email **code@kingletas.com**.

Include what you did, what happened, and what you expected. A proof of concept is welcome but not required — a clear description of the flaw is more useful than a working exploit. **Do not include a real credential in a report**; a redacted shape is enough.

This is a personal project maintained by one person, so please expect a first response in days rather than hours. You will get an acknowledgement, an assessment, and credit in the changelog unless you would rather not be named.

## Supported versions

The latest release on `main` is the supported version. There are no long-term support branches; fixes ship forward.

## Read this first: it is a tripwire, not a guarantee

**This tool does not make it safe to commit a credential, and it does not make a repository free of them.** It catches the careless mistake. A determined one — a key split across two lines, base64'd, or in a format nobody has written a pattern for — will get through, and that is not a vulnerability in the sense this policy is about. It is the documented limit of what a regex over a diff can do.

**A missed credential is a bug worth reporting. It is not a reason to trust the tool less than it asks you to.**

### If a key reaches a commit

**Rotate it. Then clean the history.** In that order, and the second half is optional.

Rewriting history does not recall a copy someone has already cloned, does not un-index a page a scraper already read, and does not expire a token. The rewrite is housekeeping; the rotation is the fix. The tool's own error message says this, deliberately.

## What it touches

| Surface | What it means |
|---|---|
| **Your files** | Read-only. It reads the paths it is given and reports on them |
| **Your git history** | `history` extracts every blob into a temporary directory, scans it, and deletes it |
| **Repositories you install into** | `install` writes `scripts/check_credentials.py` and, where there is no pre-commit framework, `.git/hooks/pre-commit` |
| **The network** | Nothing. It has no network code and no third-party imports |

Four properties exist deliberately and should not be quietly removed:

- **Matches are reported redacted to four characters.** The error message must never leak what the commit would have — a hook whose output you cannot paste into a bug report is a hook that gets bypassed instead.
- **No third-party imports, and Python 3.9 support.** A pre-commit hook has to run on whatever interpreter a contributor already has. A dependency here is a dependency in every repository this is vendored into.
- **`install` never overwrites an existing hook.** It prints the one line to add. Clobbering somebody's pre-commit hook to install a security check is a poor trade.
- **The history scan's temporary directory is removed on exit, by a trap.** It contains every blob in the repository, credentials included; leaving it behind would create the exposure the tool exists to prevent.

## In scope

- **A credential format it fails to catch** — say which provider and give the *shape*, not a live key
- A false positive common enough to make people disable the hook
- The redaction leaking more than four characters, by any path including the self-test output
- The history scan leaving extracted blobs on disk after it exits, or writing them somewhere predictable
- `install` overwriting an existing hook, or writing outside the target repository
- Path traversal through a filename, a blob path reconstructed from history, or a repository path argument
- Command injection through any of the above reaching a shell
- The scanner exiting zero on a file it could not read — **failing open is the failure that matters here**

## Out of scope

- The tool not making it safe to commit secrets. See the top of this file
- A determined evasion: a key split across lines, encoded, or in a novel format. Report the format; the evasion is expected
- Findings that require an attacker who already has your filesystem or your git history
- Vulnerabilities in git, or in pre-commit

## If you are running it

- **Run `history` before a first push, not after.** That is the only moment the fix is still cheap.
- **The vendored copy in a repository can go stale.** Re-run `install` to refresh it; the canonical copy is the one in this repository.
- **Do not add it to a repository and consider the job done.** It runs on staged files. A key that arrives by any other route — a merge, a `--no-verify`, a file added by a tool — is not something it sees.
