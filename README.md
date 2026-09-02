<h1 align="center">🔑 credential-guard</h1>

<p align="center">
  Keep credentials out of git — in the working tree, <em>and</em> in the history.
</p>

<p align="center">
  <img alt="Python" src="https://img.shields.io/badge/python-3.9%2B-3776ab">
  <img alt="Dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen">
  <img alt="Shell" src="https://img.shields.io/badge/shell-bash-4eaa25">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
</p>

---

Two commands you will use, and one you will be glad exists:

```bash
credential-guard scan .        # the working tree
credential-guard scan src/api  # or one subdirectory of it
credential-guard history .     # every blob ever committed
credential-guard install .     # vendor the hook into a repo and wire it up
```

**Exit 0 means every file was opened and none looked like a credential — nothing else.** A scan that found something, or that could not read a file, exits 1; one given a target that does not exist, or a file list it could open none of, exits 2. A security check whose silence can also mean *I did not look* is worse than no check, because it still prints a green tick.

**The history scan is the point.** A key you removed in a later commit is still in the repository, and is still published by a push. This is not hypothetical — one project here shipped a first commit holding ten environment fallbacks with real values in them, and nothing in a working-tree scan would ever have said so.

## Install

No dependencies, no packaging, nothing to build. Put it on your `PATH`:

```bash
git clone https://github.com/kingletas/credential-guard && cd credential-guard
```

```bash
install -m 755 bin/credential-guard ~/bin/ && install -m 755 bin/check_credentials.py ~/bin/credential-guard.d/check_credentials.py
```

It needs Python 3.9 or newer and `bash`. **There are no third-party imports and there will not be**: a pre-commit hook has to run on whatever interpreter a contributor already has, and a scanner that needs a specific environment is a scanner that gets skipped on the machine where it matters.

## Wiring it into a repository

```bash
credential-guard install /path/to/repo
```

That **copies** the scanner to `scripts/check_credentials.py` in the target repo and wires it up:

- If the repo uses [pre-commit](https://pre-commit.com), it prints the hook block to add — or updates the vendored copy in place if the hook is already there.
- If it does not, it writes a plain `.git/hooks/pre-commit` that needs no framework at all and works in a repository that has never seen Python.
- **An existing hook is never overwritten.** It prints the one line to add instead.

**Why it copies rather than referencing the tool on your `PATH`:** a pre-commit hook has to run for everyone who clones the repository, and a contributor does not have your `PATH`. One owner, and a copy for people who clone. Re-running `install` updates the vendored copy.

## What it refuses

| Kind | Examples |
|---|---|
| **Provider key formats** | AWS access keys, Stripe live keys, Slack tokens, GitHub tokens, Twilio SIDs, private-key blocks, JWTs |
| **Credential-named variables assigned a literal** | `api_key = "…"`, `PASSWORD: "…"`, `secret_token=…` |
| **Environment fallbacks with a real value** | `os.environ.get("API_KEY", "sk_live_…")` — the pattern that put ten real keys in a first commit |
| **Files that should never be committed at all** | `.env`, `*.pem`, `*.key`, `*.db`, `*.sqlite` |

**A match is reported redacted to its first four characters**, so the error message does not leak what the commit would have.

### It is biased toward letting placeholders through

`xxxxx`, `<your-key-here>`, `changeme`, `AKIAIOSFODNN7EXAMPLE` (AWS's own documented example) and friends are recognised and allowed. That bias is deliberate: **a scanner that cries wolf is a scanner people disable**, and a disabled scanner catches nothing at all.

For a genuine false positive, append a pragma to the line:

```python
api_key = "not-really-a-key"  # pragma: allowlist secret
```

Do that sparingly, and never to silence a real key you intend to rotate later.

## It is a tripwire, not a guarantee

**Nothing here replaces rotating a key you think you have leaked.** A determined mistake will get through, and the point is to catch the careless one.

If a key does reach a commit: **rotate it first, then clean the history.** Rewriting history does not recall a copy someone has already cloned, and it does not un-index a page a scraper already read. The rewrite is housekeeping; the rotation is the fix.

## Checking the scanner itself

```bash
credential-guard self-test    # 22 cases: what it must catch, and what it must not
tests/run.sh                  # end to end, over real temporary repositories
```

The self-test is worth running after any change to the patterns. **Half its cases assert what the scanner must _not_ flag** — that half is what keeps the false-positive rate low enough that people leave the hook installed.

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md) covers the toolchain and the rules that are not obvious from the code. [`docs/architecture.md`](docs/architecture.md) explains how the pieces fit together. [`SECURITY.md`](SECURITY.md) covers vulnerability reports.

## License

[MIT](LICENSE) © Luis Tineo
