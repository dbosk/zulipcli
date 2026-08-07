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

### Top-level chunk buckets in `cli.nw`

The root chunk names four buckets, and the order is load-bearing. Every
bucket may rely on the ones before it and none may rely on the ones
after:

1. `<<constants>>` — module-level bindings.
2. `<<applications>>` — the Typer objects (`app`, `users_app`), and
   only those.
3. `<<functions>>` — definitions only: `def` and `class`, decorated or
   not. **Never** a standalone assignment or a bare call.
4. `<<command registration>>` — statements that need the definitions to
   exist. Currently just `_register_commands(app)`.

Put a new command's handler in `<<functions>>` and its `\section`
wherever it reads best. Because the applications are created before the
definitions, a `@users_app.command(...)` decorator is fine in
`<<functions>>` — it depends on an object that already exists. A bare
call is not, because it depends on other definitions, and that is what
makes a chunk's position silently constrain every section after it.

The rule is module level only: decorators inside a function body (see
`build_embedded_app()`) and `@pytest.fixture` in the test chunks are
unaffected.

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
- `users invited`: list pending (unaccepted) invitations, both emailed
  ones and reusable links, filterable by one or more regexes. Output is
  four tab-separated columns; column 1 is the invitee email for an
  emailed invitation and the join URL for a link, and the regexes match
  that column.
- `users invite`: invite one or more users by email.
- `users invite-link`: create a reusable invitation link and print the
  URL, so a cohort can be onboarded without knowing addresses in
  advance.
- `users revoke`: withdraw pending invitations of either kind, selected
  by regex over the same column 1 that `users invited` prints.
- `users resend`: send a pending email invitation again. Links cannot
  be resent, so they are skipped with a note, and a match consisting
  only of links is an error rather than a silent no-op.
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

`users invite` and `users invite-link` share their `--as`,
`--expires-in`, `--stream`, and `--add-default-streams` options through
the `<<invitation options>>` and `<<invitation arguments>>` chunks.
Add a shared option once and both commands get it; adding it to only
one signature is the mistake those chunks exist to prevent.

`--stream` alone *adds* to the organisation's default streams;
`--stream` together with `--no-add-default-streams` specifies the
subscription set exactly, which is how one link per cohort gets its own
streams. `--add-default-streams` defaults to on because the Zulip API's
own defaults (`include_realm_default_subscriptions` false, `stream_ids`
empty) subscribe an invitee to *nothing at all*.

`users revoke` and `users resend` take a **required** pattern argument.
That is a safety property, not a style choice: `_matches_patterns`
returns true for an empty pattern list, so an argument-less `revoke`
would destroy every pending invitation. Both prompt when more than one
invitation matches, refuse rather than prompt on a non-TTY stdin, and
accept `-y/--yes`.

Shell completion is part of the CLI implementation.
Completion for streams, topics, users, and indexed terms is generated
by helper functions in `src/zulipcli/cli.nw`, so changes to command
parameters and completion behavior should usually be kept together in
that file.

Two tests reach into framework internals and so are sensitive to
dependency upgrades (see issue #13):

- `test_click_completion_path_uses_context_for_zuliprc_and_stream`
  imports `BashComplete` from `typer._completion_classes`. It must be
  **Typer's** resolver, not `click.shell_completion`: Typer vendored
  Click, and `TyperGroup` no longer subclasses `click.Group`, so
  Click's `_resolve_context` takes its "not a group" branch, stops at
  the root command, and silently returns no candidates for every
  option.
- `test_cli_shows_help_without_command` asserts exit code **2**, not 0.
  Typer treats `no_args_is_help` as a usage error.

## Credential Personas

The Zulip invitation API rejects **every** bot API key, on all six
invite endpoints, with HTTP 400 and
`"This endpoint does not accept bot requests."`. The check is on the
account kind and runs *before* any role check, so promoting a bot to
organisation administrator does not help, and a bot cannot even *list*
invitations. All five invitation commands therefore need a human
account's key.

Two personas, `user` and `bot`, each resolve independently:

- File: `~/.zuliprc.<persona>` — used when it exists.
- Key: `ZULIP_USER_API_KEY` / `ZULIP_BOT_API_KEY`.
- Address: `ZULIP_USER_EMAIL` / `ZULIP_BOT_EMAIL`.
- Server: `ZULIP_SITE`, shared (the library reads it directly).

Precedence for the file is `--zuliprc` > `~/.zuliprc.<persona>` >
`~/.zuliprc`. The environment variables override *individual fields* of
whichever file was chosen, because `zulip.Client` merges per field
rather than per source — so a zuliprc holding only a non-secret email
and site, plus a key in the environment, keeps secrets off disk
entirely. Empty values count as unset.

`_get_user_client_from_context()` is for the invitation commands;
`_get_client_from_context()` is for everything else and picks
`_default_persona()`, which prefers `user` over `bot` and returns
`None` when neither is configured. That `None` is the backward
compatibility guarantee: with no persona files and no persona
variables, resolution is exactly what it was before personas existed.

Three consequences worth knowing:

- Once user credentials exist, `send` and `dm` post as *you*, not as
  the bot. To act as the bot anyway, pass
  `--zuliprc ~/.zuliprc.bot`.
- The `bot` command is the exception to user-first: it uses
  `_get_bot_client_from_context()`, which takes the bot persona when
  configured and otherwise plain `~/.zuliprc` — never the human. A
  worker that consumed the owner's unreads and marked them read would
  be the worst possible default.
- There is deliberately no `--user-zuliprc` root option; root options
  belong to the embedding host, which is why `build_embedded_app()`
  declares none. A test asserts the absence.

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

Environment variables the CLI reads, in one place:
`ZULIPCLI_NO_TERM_INDEX`, `XDG_DATA_HOME`, `ZULIP_USER_API_KEY`,
`ZULIP_USER_EMAIL`, `ZULIP_BOT_API_KEY`, `ZULIP_BOT_EMAIL`. `ZULIP_SITE`
is read by the `zulip` library, not by this code. Note `ZULIP_CONFIG` is
*not* honoured: `get_client()` always passes an explicit `config_file`,
so the library never falls back to it.

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

The invitation lifecycle adds no dependency either. The `zulip` library
exposes no invitation methods, so `invites`, `invites/multiuse`,
`invites/{id}` and `invites/{id}/resend` all go through
`client.call_endpoint()`. Pass native Python ints, bools, and lists in
the request: `do_api_query` applies
`val if isinstance(val, str) else json.dumps(val)` to every field, so
`True` becomes JSON `true` — formatting it yourself with `str()` would
produce `"True"` and fail the server's validator.
