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
  commit_hash = 61fcb1b
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
