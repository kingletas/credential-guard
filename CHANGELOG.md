# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **A secret-named key in a PHP array entry or an XML element is now caught.** That covers `'api_key' => '…'` in `app/etc/env.php` or module code, and `<api_key>…</api_key>` in a module's `etc/config.xml`, the two shapes Magento code uses most. Both used to pass. The value is judged by the same rules as an assignment, so an empty value, `${VAR}`, `%env(...)%` or an example value still passes, and `pragma: allowlist secret` still works on either line. `access_key` has joined the names that count as secret-shaped. **Test fixtures written as array entries now fail** the way `$password = '…'` always has: use a placeholder-shaped value or add the pragma.

- **`watch` scans the files that live in no repository.** `scan` covers a working tree, which is where a commit can carry a credential away; nothing covered a shell profile, a git config or an alias file, and that's where two credentials survived for years here. Reads a list from `GUARD_WATCHLIST`, silent when clean, `--notify` raises a critical desktop notification because do-not-disturb is a normal state and an alert that respects it is an alert nobody receives.
- **A watchlist entry that isn't on disk is reported rather than skipped**, so the list can't quietly stop describing anything.
- **`watch` batches the scanner rather than passing every path in one call.** A watchlist naming a large directory blew past ARG_MAX at 35,541 files, and the wrapper reported "Argument list too long" **as a credential finding**. A scanner that couldn't run now exits 2 and says nothing was checked, which is a different thing from a scanner that looked and found something.
- **A glob contributes the files it matches and doesn't walk the directories it also matches**, so a pattern like `~/.[!.]*` covers a directory's own files without descending into every cache below it.

- **This repository.** The tool previously lived in a personal `~/bin` directory, which meant the one thing that was supposed to be vendored into every project couldn't itself be cloned.
- **An end-to-end suite** over real temporary repositories, covering what the self-test can't: that history refuses a blob the working tree no longer contains, that `install` vendors a scanner which runs standalone, and that an existing pre-commit hook is left alone.
- **CI runs `make check` on Python 3.9, 3.11 and 3.13**, on Linux. 3.9 is in the matrix deliberately — a pre-commit hook has to run on whatever interpreter a contributor already has. A macOS run is available on request from the Actions tab and never starts on a push.
- **A release workflow.** Pushing a tag such as `v1.0.0` runs `make check`, proves `make install` works, and publishes a GitHub Release whose body is that version's section of this file. A tag with no section here fails before anything is published.

### Fixed

- **A JSON or dict key such as `"api_key": "…"` is caught.** The quote closing the key stopped the match, so this shape passed even though the scanner's own comment listed it as covered.
- **Values that name something rather than hold a secret no longer fail the scan.** That covers config paths (`payment/gateway/api_key`), absolute paths, PHP class names, `Vendor_Module/…` asset paths, CSS selector lists, timestamps, and lowercase identifiers built around the credential word (`customer_password_reset_template`). Across Magento's own code, that removes 61 findings the scanner used to make on constants such as `XML_PATH_API_KEY`.
- **The README no longer lists JWTs among the formats it refuses.** The scanner has no JWT pattern and never had one.
- **`scan` on a subdirectory read no files at all.** Paths came out of `git ls-files --full-name`, which prints them relative to the repository root, and were then joined onto the path argument — so scanning `module-cache-vary` handed the scanner `module-cache-vary/module-cache-vary/…` and every one of the 62 files came back *No such file or directory*. They are resolved against the repository root now, and a subdirectory scan reads the files it lists. The pre-commit hook was never affected: it passes staged files as arguments and never takes the directory path.

### Changed

- **A scan that opened no file now fails.** It used to print `nothing to scan` and exit 0, which is a green tick over an unexamined tree — the one thing a credential scanner must never produce. A target that doesn't exist, or a file list none of which could be opened, exits 2; a directory holding nothing to scan exits 1. **Exit 0 means every file given was opened and none looked like a credential**, and nothing else.
- **A file that couldn't be read is no longer reported as a credential.** It was printed under *Refusing to commit: this looks like a credential*, which described the wrong problem. Unreadable files are counted and listed on their own, and still fail the run — a file the scanner can't open is a file it can't clear.

- **The tool finds its scanner in either layout.** Installed on `PATH` it keeps its parts in a sibling `<name>.d/` directory; checked out of this repository the scanner sits beside it in `bin/`. It probes rather than assuming, so `./bin/credential-guard` works straight out of a clone — and a tool you can't run from a fresh clone is a tool nobody evaluates.

## [1.0.0]

### Added

- **`scan`** — the working tree, or an explicit file list. One directory argument walks the tree, which is right for a repository sweep; several arguments or one file scan exactly those, which is right for a pre-commit hook.
- **`history`** — every blob ever committed, not just the ones reachable from the tip. **A key removed in a later commit is still in the repository and is still published by a push.** Blobs are reconstructed under a path they were once committed at, so a finding names a file rather than a hash — which also means the filename rules fire on history, catching a `.env` committed once and deleted later.
- **`install`** — vendors the scanner into a repository and wires it up, either as a pre-commit hook block or as a plain `.git/hooks/pre-commit` that needs no framework. **An existing hook is never overwritten.**
- **`self-test`** — 22 cases, half of which assert what the scanner must *not* flag.
- Provider key formats, credential-named variables assigned a literal, environment fallbacks carrying a real value, and files that should never be committed at all.
- **Matches reported redacted to four characters**, so the error doesn't leak what the commit would have.
- A placeholder allowlist and a `pragma: allowlist secret` escape hatch, because a scanner that cries wolf is a scanner people disable.
