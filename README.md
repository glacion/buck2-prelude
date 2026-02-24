# Core Rules

A minimal Buck2 prelude providing general-purpose build rules. Rule and attribute documentation is available inline via `buck2 docs` or by reading the `doc` fields in `core/*.bzl`.

## Configuration

To use this prelude in your project, add the following to your `.buckconfig`:

```ini
[cells]
  root = .
  prelude = git@github.com:glacion/buck2-prelude.git
[external_cells]
  prelude = git
  git_origin = git@github.com:glacion/buck2-prelude.git
  # Replace with a specific commit hash for reproducibility
  commit_hash = <COMMIT_HASH>
```

## Available Rules

| Rule | Description |
|------|-------------|
| `alias` | Aggregates default outputs from dependencies |
| `default` | Runs an arbitrary command |
| `export` | Copies or symlinks source files |
| `http` | Downloads a file from a URL |
| `json` | Writes a JSON value to a file |
| `shell` | Runs a command via a shell interpreter |
| `test` | Defines an external runner test |
| `write` | Writes content to a file |

## Common Internal Mechanisms

Most core rules in this prelude share the same execution model so behavior is predictable across `default`, `shell`, `test`, `export`, `write`, and `json`.

- **Package-scoped output paths**: artifacts are declared with `path.join(context.label.package, ...)` so outputs remain stable and package-relative.
- **`context` output sandboxing** (`default`/`shell`/`test`): generated files and logs are grouped under `package/context/...` to avoid collisions between targets.
- **Source installation mode**: `mode = "copy"` materializes files for hermeticity, while `mode = "symlink"` favors faster local iteration.
- **Source layout preservation**: source files keep package-relative structure; generated source labels keep producer `short_path` layout.
- **Hidden input invalidation** (`default`/`shell`/`test`): installed sources are passed as hidden inputs so action keys track changes even when artifacts are not rendered on argv.
- **Explicit env + cwd command prefix** (`default`/`shell`/`test`): commands are built as `env` invocations with an explicit working directory and `key=value` env args for reproducible execution.
- **Command log artifacts** (`default`/`shell`/`test`): each rule writes the fully assembled command to a log output (`_log`, default `buck2.log`) for inspectability and replayability.
- **Provider conventions**:
  - `write`/`json` return a single `DefaultInfo.default_output`.
  - `export` and output-producing `default`/`shell` return `DefaultInfo.default_outputs`.
  - no-output `default`/`shell` and `test` expose the log as `DefaultInfo.default_output`.
  - `test` also returns `ExternalRunnerTestInfo(type = "command", ...)`.

## Produced File Structure

Rules that write files use deterministic package-relative paths. Example from the current workspace (`buck2 build --show-full-output ...`), shown as a tree relative to the repository root:

```text
.
`-- buck-out/v2/gen/prelude/1ef78538d8598cb2/
    `-- test/
        |-- __write__/test/out/write.txt
        |-- __json__/test/out/data.json
        |-- __default_env__/test/out/default_env/
        |   |-- buck2.log
        |   `-- ok.txt
        |-- __default_no_outputs__/test/out/default_no_outputs/buck2.log
        |-- __shell_env__/test/out/shell_env/
        |   |-- buck2.log
        |   `-- ok.txt
        |-- __shell_no_outputs__/test/out/shell_no_outputs/buck2.log
        |-- __export__/test/input.txt
        |-- __test_write_content__/test/out/
        |   |-- write.txt
        |   `-- tests/write_content/buck2.log
        `-- __test_mixed_sources__/test/
            |-- raw-extra.txt
            `-- out/
                |-- data.json
                |-- write.txt
                `-- tests/mixed_sources/buck2.log
```

The configuration hash segment (`1ef78538d8598cb2` above) changes with Buck configuration; the directory layout under each target remains stable.

- `write(path = "...")`: produces `<package>/<path>`.
- `json(path = "...")`: produces `<package>/<path>`.
- `default(context = C, outputs = [O1, ...])`: produces `<package>/<C>/<O1...>` and writes command log `<package>/<C>/_log`.
- `default(context = C, outputs = None)`: exposes only command log `<package>/<C>/_log` as the default output.
- `shell(context = C, outputs = [O1, ...])`: same produced structure as `default`.
- `shell(context = C, outputs = [])`: exposes only command log `<package>/<C>/_log` as the default output.
- `test(context = C)`: produces command log `<package>/<C>/_log` (default output); test execution metadata is returned via `ExternalRunnerTestInfo`.
- `export(sources = [...])`:
  - input/source file structure is persisted (package-relative): `<package>/<source.short_path>`
  - generated files preserve producer layout: `<producer short_path>`
