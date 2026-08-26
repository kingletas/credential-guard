# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **This repository.** The tool previously lived in a personal `~/bin` directory, which meant the one thing that was supposed to be vendored into every project could not itself be cloned.
- **An end-to-end suite** over real temporary repositories, covering what the self-test cannot: that history refuses a blob the working tree no longer contains, that `install` vendors a scanner which runs standalone, and that an existing pre-commit hook is left alone.
- **CI on Python 3.9, 3.11 and 3.13**, on Linux and macOS. 3.9 is in the matrix deliberately — a pre-commit hook has to run on whatever interpreter a contributor already has.

### Changed

- **The tool finds its scanner in either layout.** Installed on `PATH` it keeps its parts in a sibling `<name>.d/` directory; checked out of this repository the scanner sits beside it in `bin/`. It probes rather than assuming, so `./bin/credential-guard` works straight out of a clone — and a tool you cannot run from a fresh clone is a tool nobody evaluates.

## [1.0.0]

### Added

- **`scan`** — the working tree, or an explicit file list. One directory argument walks the tree, which is right for a repository sweep; several arguments or one file scan exactly those, which is right for a pre-commit hook.
- **`history`** — every blob ever committed, not just the ones reachable from the tip. **A key removed in a later commit is still in the repository and is still published by a push.** Blobs are reconstructed under a path they were once committed at, so a finding names a file rather than a hash — which also means the filename rules fire on history, catching a `.env` committed once and deleted later.
- **`install`** — vendors the scanner into a repository and wires it up, either as a pre-commit hook block or as a plain `.git/hooks/pre-commit` that needs no framework. **An existing hook is never overwritten.**
- **`self-test`** — 22 cases, half of which assert what the scanner must *not* flag.
- Provider key formats, credential-named variables assigned a literal, environment fallbacks carrying a real value, and files that should never be committed at all.
- **Matches reported redacted to four characters**, so the error does not leak what the commit would have.
- A placeholder allowlist and a `pragma: allowlist secret` escape hatch, because a scanner that cries wolf is a scanner people disable.
