# Architecture

Two files. A bash front end that knows about git, and a Python scanner that knows about credentials.

```text
credential-guard          check_credentials.py
  scan     ─── file list ────▶  patterns ──▶ redacted findings
  history  ─── every blob ──▶
  install  ─── copies ──────▶  (into a repo's scripts/)
  self-test ──────────────────▶ 22 cases
```

The split is not decoration. **The scanner has to be usable on its own**, because that is the half that gets vendored into other repositories — where there is no bash wrapper, no `PATH` entry, and possibly no interest in either.

## Five decisions worth knowing

### No third-party imports, and Python 3.9

This is vendored into other people's repositories and runs as a pre-commit hook. **A dependency here is a dependency in every repository it is copied into**, and a hook that fails to import is a hook somebody removes rather than fixes.

3.9 is in the CI matrix for the same reason: the hook has to run on whatever interpreter a contributor already has, not on the one the author prefers.

### Matches are redacted to four characters

An error message has to be safe to paste into a bug report, a CI log, or a screenshot. **A hook whose output you cannot share is a hook people bypass instead of reading.**

Four characters is enough to recognise the shape — `sk_l…`, `AKIA…` — and not enough to be the key.

### The scanner excludes itself, twice

It contains every pattern it looks for and a self-test full of specimen keys, so any copy of it would flag itself.

- **By filename**, because the canonical copy and a vendored copy are different files at different paths. Matching on the resolved path of the running file would not recognise the copy being scanned.
- **By a content marker**, because a copy read out of git history arrives under its blob hash with no meaningful filename at all.

Two mechanisms for one problem, because the two entry points see different things.

### `scan` behaves differently for a directory and for a file list

One directory argument walks the whole tree. That is right for a repository sweep.

Several arguments — or one that is a file — scan exactly those. That is right for a pre-commit hook, which is handed the staged files. **Re-scanning twelve thousand files on every commit is how a hook gets uninstalled.**

Inside a git repository the directory walk uses `git ls-files` rather than `find`: an untracked build directory is not going anywhere, and scanning `node_modules` teaches people to ignore the output.

### The history scan reconstructs filenames

Every blob is written into a temporary tree **under a path it was once committed at**, so a finding says `config/services.py` rather than a hash nobody can act on. A blob reachable under several names gets whichever git lists first; a blob that was never named — reachable only from a dangling object — keeps its hash.

Two consequences follow, and the second is the useful one:

- The tree holds **every blob in the repository**, credentials included. It is removed by a `trap` rather than by a line at the end, so a scan that exits early — a failed `cat-file`, a Ctrl-C — does not leave that on disk.
- **The filename rules fire on history too.** A `.env` committed once and deleted later is still in the repository, and a working-tree scan would never say so.

It walks `cat-file --batch-all-objects`, not `rev-list HEAD`: an object on a deleted branch, or in a commit that was amended away, is still an object in the repository until it is garbage collected.

## `install` vendors rather than references

A pre-commit hook has to run for **everyone who clones the repository**, and a contributor does not have your `PATH`. So `install` copies the scanner to `scripts/check_credentials.py` in the target repo.

One owner, and a copy for people who clone. Re-running `install` updates the vendored copy in place.

It adapts to what is already there:

- **pre-commit present and already wired** — update the scanner, say so, change nothing else.
- **pre-commit present, not wired** — print the hook block to add. It does not edit somebody's config file for them.
- **No pre-commit** — write a plain `.git/hooks/pre-commit`, which needs no framework at all and works in a repository that has never seen Python.
- **A hook already exists** — never overwrite it. Print the one line to add. *Clobbering somebody's pre-commit hook to install a security check is a poor trade.*

## The bias toward false negatives

The placeholder list is the most important design decision in the scanner, and it points the opposite way from what a security tool usually does.

`xxxxx`, `<your-key-here>`, `changeme` and the providers' own documented example keys are recognised and allowed. `AKIAIOSFODNN7EXAMPLE` is AWS's published example and appears in real documentation — flagging it would fail every commit that mentions AWS.

**A scanner that cries wolf is a scanner people disable, and a disabled scanner catches nothing at all.** Letting a placeholder through costs nothing; making the hook annoying costs everything it was installed to do.

This is also why half the self-test asserts what the scanner must *not* flag. A new pattern that gains one true positive and three false ones is a net loss, and that half of the suite is what says so.

## The limit, stated plainly

**A regex over a diff cannot make a repository free of credentials.** A key split across two lines, base64'd, or in a format nobody has written a pattern for will get through.

The tool's error message says the important half: **rotate first, clean the history second.** Rewriting history does not recall a copy someone has already cloned, does not un-index a page a scraper already read, and does not expire a token. The rewrite is housekeeping; the rotation is the fix.
