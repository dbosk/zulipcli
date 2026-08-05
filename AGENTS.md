# ZulipCLI Agent Guide

## Project Shape

This repository is a literate-programming project built with noweb.
The real source files are the `.nw` documents in `src/zulipcli/`.
Generated `.py`, `.tex`, and extracted test files may exist in the
workspace, but they are derived artifacts, not the source of truth.

Important source files:

- `src/zulipcli/init.nw`: package setup and `get_client()`.
- `src/zulipcli/cli.nw`: the CLI implementation and its embedded tests.
- `pyproject.toml`: packaging, dependencies, and the console entry point.
- `Makefile`: top-level build/test orchestration.
- `tests/Makefile`: extracts tests from the literate sources.

## Edit Rules

When changing code, edit the `.nw` file that owns it.
Do not hand-edit generated files such as:

- `src/zulipcli/__init__.py`
- `src/zulipcli/init.tex`
- `src/zulipcli/cli.py`
- `src/zulipcli/cli.tex`
- `tests/unit/test_*.py`

After editing a `.nw` file, regenerate derived artifacts before testing.

## Build And Test

Common commands:

- `make -C src/zulipcli all`: tangle/weave the package sources.
- `make -C tests all`: extract tests from the literate sources.
- `make compile`: regenerate sources and build the Poetry package.
- `make test`: regenerate sources, extract tests, and run pytest.
- `poetry run pytest tests/`: run the extracted tests directly.

## Testing Model

Tests live in the same `.nw` files as the implementation.
For example, `src/zulipcli/cli.nw` contains a
`<<test [[cli.py]]>>` root chunk and many `<<test functions>>` buckets.
`tests/Makefile` extracts those chunks into `tests/unit/test_*.py`.

That means a CLI change normally requires three steps:

1. Update `src/zulipcli/cli.nw`.
2. Regenerate `src/zulipcli/cli.py` and `tests/unit/test_cli.py`.
3. Run the relevant test command.

## CLI Notes

The console script is defined in `pyproject.toml`:

- `zulipcli = "zulipcli.cli:main"`

The CLI is implemented with Typer and Rich in `src/zulipcli/cli.nw`.
Current user-facing commands are:

- `users list`: list users, filterable by one or more regexes over
  name/Zulip email/delivery email.
- `users invited`: list pending (unaccepted) invitations (admin-only),
  filterable by one or more invite-email regexes.
- `users invite`: invite one or more users by email (admin-only).
- `send`: send a stream message or a direct message; `--to` may be
  repeated, each regex is matched against name/Zulip email/delivery
  email, overlapping matches are deduplicated, and >1 match prompts
  unless `--yes` is given.
- `dm`: read direct-message history; with no arguments reads all DMs,
  with one or more user regexes narrows to the exact DM/group-DM
  conversation with that participant set; supports `-U/--unread` and
  `--mark-as-read`.
- `streams`: list streams, filterable by one or more name regexes;
  `-U/--unread` shows unread counts.
- `topics`: list the topics inside a stream.
- `read`: read stream/topic history; supports `-U/--unread` and
  `--mark-as-read`.
- `search`: full-text search over message history. Repeatable
  `--stream`/`--topic` fan out into *separate* Zulip queries whose
  results are merged, because a Zulip narrow is a conjunction and two
  stream terms in one narrow match nothing. `--sender` takes a single
  regex for the same reason. `--scope all|streams|dms` limits the
  conversation kind, `--has` requires a link/image/attachment,
  `-P/--public` widens to public channels you do not follow,
  `-U/--unread`, `-n/--limit N` keeps the N most recent hits (0 for
  all), and `--full` switches from one-line hits to `read` rendering.
  It deliberately has no `--mark-as-read`.
- `terms`: look up the realm's vocabulary in the local index, showing
  similar terms and terms that co-occur with the best match; with no
  argument it lists the most frequent terms.
- `bot`: run an external worker command, given after `--`, whenever
  unread messages exist, feeding those messages to it on stdin.

Shell completion is part of the CLI implementation.
Completion for streams, topics, users, and indexed terms is generated
by helper functions in `src/zulipcli/cli.nw`, so changes to command
parameters and completion behavior should usually be kept together in
that file.

## Term Index

Every message-reading path feeds a local SQLite term index, so `read`,
`dm`, `search`, and `bot` all populate it as a side effect. The hook
is a single chokepoint, `_fetch_history_page()`, which every pagination
loop goes through.

- Location: `$XDG_DATA_HOME/zulipcli/terms-<site>.db`, defaulting to
  `~/.local/share/zulipcli/`. Keyed per Zulip site so realms never
  blend vocabularies.
- Contents: casefolded words, co-occurrence counts, and the set of
  message IDs already counted. No message bodies, no senders.
- Idempotent: re-reading a topic must not inflate counts. The guard is
  `INSERT OR IGNORE` into `messages` using `rowcount` as the
  "was this new?" signal, in the same transaction as the counting.
- Writes are best-effort; any failure is swallowed so indexing can
  never break a read.
- Disable with `ZULIPCLI_NO_TERM_INDEX=1`; reset by deleting the file.

## Practical Workflow

Before making changes, read the owning `.nw` file instead of the tangled
`.py` file whenever possible.
The prose explains the intended design, chunk structure, and why the code
is arranged the way it is.

After making a change:

1. Regenerate with `make -C src/zulipcli all` and, if tests changed,
   `make -C tests all`.
2. Run `make test` or at least `poetry run pytest tests/`.
3. If you touched packaging or dependencies, also run `make compile`.

## Dependency Notes

`rich` and `typer` are required runtime dependencies.
The `read` command expects Rich to be present for TTY Markdown
rendering, and the CLI surface depends on Typer for subcommands and
completion.

The term index adds no packaging change: `sqlite3` (storage), `difflib`
(similarity), and `os` (the `XDG_DATA_HOME` lookup) are all standard
library. Keep it that way — a vocabulary cache is not worth a fourth
runtime dependency.
