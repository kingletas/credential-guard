# Contributing to credential-guard

Thanks for taking an interest. This is MIT-licensed and reuse is the point — fork it, strip it for parts, or send a patch back.

This file covers the mechanics. [`README.md`](README.md) explains what it does, [`docs/architecture.md`](docs/architecture.md) explains how the pieces fit together, and [`SECURITY.md`](SECURITY.md) covers vulnerability reports — **please do not open a public issue for a security problem, and never include a live credential in one.**

## Getting set up

```bash
git clone https://github.com/kingletas/credential-guard && cd credential-guard
bin/check_credentials.py --self-test
tests/run.sh
```

There is nothing to install. `bash`, `python3` and `git` are all it needs, and `shellcheck` if you are touching the shell half.

Before you send a change, run the same gate CI runs:

```bash
make check
```

## Two rules that outrank everything else

**No third-party imports. Ever.** This scanner is vendored into other people's repositories and runs as a pre-commit hook, so it has to work on whatever interpreter a contributor already has. **A dependency here is a dependency in every repository this is copied into**, and a hook that fails to import is a hook somebody removes rather than fixes. CI runs the matrix down to Python 3.9 to keep this honest.

**Never widen the redaction.** A match is reported as its first four characters and no more. The error message has to be safe to paste into a bug report, a CI log, or a screenshot — a hook whose output you cannot share is a hook people bypass instead of reading. This applies to the self-test output too.

## Adding a pattern

1. **Add the case to the self-test first**, in both halves: what it must catch, and a near-miss it must *not*.
2. Add the pattern.
3. Run `bin/check_credentials.py --self-test` and `tests/run.sh`.

**Half the self-test asserts what the scanner must not flag, and that half is the important one.** A scanner that cries wolf is a scanner people disable, and a disabled scanner catches nothing at all. A new pattern that gains one true positive and three false ones is a net loss.

When you add a pattern, check it against the placeholder list. `xxxxx`, `<your-key-here>`, `changeme` and the providers' own documented example keys must keep passing — `AKIAIOSFODNN7EXAMPLE` is AWS's published example and appears in real documentation, so flagging it would fail every commit that mentions AWS.

## Four things that are not obvious from the code

**The scanner excludes itself, twice.** It contains every pattern it looks for and a self-test full of specimen keys, so a copy of it would flag itself. It matches on the **filename** — because the canonical copy and a vendored copy are different files — and on a **content marker**, because a copy read out of git history arrives under its blob hash with no filename at all.

**The history scan reconstructs filenames on purpose.** Every blob is written into a temporary tree under a path it was once committed at, so a finding says `config/services.py` rather than a hash nobody can act on. It also means the **filename rules fire on history too** — a `.env` committed once and deleted later is still in the repository, and that is exactly what this command is for.

**The temporary tree is removed by a trap, not by a line at the end.** It holds every blob in the repository. A scan that exits early — a failed `cat-file`, a Ctrl-C — must not leave that on disk.

**`scan` behaves differently for one directory than for a file list.** One directory argument walks a whole tree, which is right for a repository sweep. Several arguments, or one file, scan exactly those — which is right for a pre-commit hook. Re-scanning twelve thousand files on every commit is how a hook gets uninstalled.

## Pull requests

- **One concern per pull request.** A new pattern and a refactor in one diff is two reviews wearing a trenchcoat.
- **Say what breaks.** If behaviour changes, name it in the description and add a `CHANGELOG.md` entry under `Unreleased`.
- **`shellcheck` must be clean** on `bin/credential-guard` and `tests/run.sh`. Prefer restructuring over a disable directive; where one is genuinely needed, say why in a comment above it.
- **Never commit a live credential, including in a test.** The self-test uses synthetic values that match the shapes. If you need a new one, invent it.
