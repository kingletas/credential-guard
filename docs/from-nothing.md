# From nothing to a working credential-guard

By the end of this page you'll have credential-guard installed, you'll have watched it find a key hidden in a repository's history, and you'll have seen it stop a commit that carries one. It takes about five minutes.

## Contents

- [What this is](#what-this-is)
- [What you need](#what-you-need)
- [Step 1: install it](#step-1-install-it)
- [Step 2: make a practice repository with a mistake in its past](#step-2-make-a-practice-repository-with-a-mistake-in-its-past)
- [Step 3: scan the working tree, then the history](#step-3-scan-the-working-tree-then-the-history)
- [Step 4: stop the next one at commit time](#step-4-stop-the-next-one-at-commit-time)
- [Where to go next](#where-to-go-next)

## What this is

credential-guard looks for API keys, tokens and passwords in a git repository before you publish it.

Deleting a key in a later commit doesn't remove it. The old commit still holds it, and a push publishes that commit too. So credential-guard checks two things: the files you have now, and every version of every file git has ever stored.

## What you need

- `git`, `bash`, `make`, and Python 3.9 or newer. Nothing else: the scanner has no third-party dependencies.
- A `~/bin` directory on your `PATH`. If you don't have one yet, the first step creates it. If `make install` prints `note: ... is not on your PATH`, add `export PATH="$HOME/bin:$PATH"` to your shell profile and open a new terminal.

Every command below was run on a clean home directory. In the output, `/home/you` stands for your own home directory.

## Step 1: install it

```bash
cd ~
git clone https://github.com/kingletas/credential-guard && cd credential-guard
mkdir -p ~/bin
make install
```

The clone was run from a local copy of this repository rather than from GitHub, so that one line isn't verified; the rest ran as shown. `make install` copies the command into `~/bin` and then checks that the installed copy can find its scanner:

```text
installed credential-guard -> /home/you/bin
scanner reachable from the installed copy
```

Check the scanner works on this machine:

```bash
credential-guard self-test | tail -1
```

```text
self-test: 22/22 passed
```

## Step 2: make a practice repository with a mistake in its past

This builds a small repository where somebody committed a token and then deleted it. The token is invented. It's written with `printf` in two halves so this page doesn't trip the scanner itself.

```bash
mkdir ~/practice && cd ~/practice
git init -q
git config user.name "You"
git config user.email you@example.com
echo "# Practice" > README.md
printf 'API_TOKEN = "%s%s"\n' k3v9Qx7m Lp2Zt8Rw > settings.py
git add README.md settings.py && git commit -q -m "Add settings"
git rm -q settings.py && git commit -q -m "Remove settings"
```

## Step 3: scan the working tree, then the history

First, the files as they are now:

```bash
credential-guard scan .
```

```text
credential-guard: scanning 1 file(s) in .
```

It prints nothing else and exits 0. **That silence is the good result**: every tracked file was opened and none looked like a credential. Only tracked files are scanned, because an untracked file isn't going anywhere.

Now every version of every file git has stored:

```bash
credential-guard history .
```

```text
credential-guard: scanning every blob in /home/you/practice
credential-guard: 2 blob(s)
Refusing to commit: this looks like a credential.

  settings.py:1: credential assigned a literal (k3v9…)

If the key is real: remove it, then rotate it — a commit is not the
only place it has been. If it is a false positive, append
`# pragma: allowlist secret` to that line.
```

It exits 1. The file is gone from the working tree, but the token is still in the first commit, and a push would publish it. The match is cut to four characters so the report doesn't leak the rest.

If this were a real key, the fix is to **rotate it first**: revoke it with whoever issued it and make a new one. Rewriting history comes after, and it can't recall a copy someone else already cloned.

## Step 4: stop the next one at commit time

Wire the scanner into the repository as a pre-commit hook:

```bash
credential-guard install .
```

```text
credential-guard: vendored scripts/check_credentials.py into /home/you/practice
credential-guard: installed .git/hooks/pre-commit
```

"Vendored" means it copied the scanner into the repository, at `scripts/check_credentials.py`. Commit that file, so everyone who clones the repository has the same scanner.

Now try to commit a token again:

```bash
printf 'API_TOKEN = "%s%s"\n' k3v9Qx7m Lp2Zt8Rw > settings.py
git add settings.py && git commit -m "Add settings again"
```

```text
Refusing to commit: this looks like a credential.

  settings.py:1: credential assigned a literal (k3v9…)

If the key is real: remove it, then rotate it — a commit is not the
only place it has been. If it is a false positive, append
`# pragma: allowlist secret` to that line.
```

The commit didn't happen. To check, run `git log --oneline`: you'll still see only the two earlier commits.

When you're done, delete the practice repository with `rm -rf ~/practice`.

## Where to go next

- [README](../README.md): what it refuses, how placeholders are let through, and `watch`, which scans files that live in no repository at all, such as a shell profile.
- [docs/architecture.md](architecture.md): how the pieces fit together.
- [CONTRIBUTING.md](../CONTRIBUTING.md): how to change the patterns and run the tests.
