"""provides the test rule for defining test targets"""

load("@prelude//core/path.bzl", "path")

def _test_impl(context: AnalysisContext) -> list[Provider]:
    # declare the log artifact for cwd resolution by `env -C`, scoping it under
    # `package/context/_log` via `path.join` to normalize separators and collapse
    # redundant components (e.g. `./`); also serves as the default output of the test
    log = context.actions.declare_output(path.join(context.label.package, context.attrs.context, context.attrs._log))
    # copy favors hermetic materialization, symlink favors faster local iteration
    install = context.actions.copy_file if context.attrs.mode == "copy" else context.actions.symlink_file
    # gather dependency outputs from defaultinfo for hidden input tracking
    # `default_outputs` is the supported aggregation surface in this buck2 api
    # including these artifacts keeps action keys sensitive to dependency changes
    dependencies = [
        output
        for dependency in context.attrs.dependencies
        for output in dependency[DefaultInfo].default_outputs
    ]
    # install source files into the test context while preserving layout semantics:
    # - for source files (`is_source = True`), prefix with `context.label.package` so files
    #   keep their package-relative directory structure
    # - for dependency outputs (`is_source = False`), keep the producer-provided short_path
    #   so generated artifacts preserve their declared output structure
    sources = [
        install(path.join(context.label.package, source.short_path), source) if source.is_source else install(source.short_path, source)
        for source in context.attrs.sources
    ]
    # bundle dependencies and sources as hidden inputs for the test action
    # these must be present in the action key even when not rendered on argv,
    # otherwise buck2 can miss invalidation when dependencies or sources
    # change and incorrectly reuse stale results
    hidden = dependencies + sources

    # format environment variables as key=value pairs for the env command
    # we intentionally do not use ExternalRunnerTestInfo(env = ...) alone: that only
    # affects the test runner process, while embedding env in the command ensures the
    # persisted log file contains the full runnable invocation for reproducibility
    env = [cmd_args(key, value, delimiter = "=") for key, value in context.attrs.environment.items()]

    # build an `env -C <dir>` prefix that executes from the test context directory
    # `parent = 1` resolves the cwd to the log's parent path
    cwd = cmd_args("env", "-C", log, parent = 1)

    # compose the final command with cwd prefix, environment assignments, user
    # command argv, and hidden artifacts for action-key tracking
    command = cmd_args(cwd, env, cmd_args(context.attrs.command, relative_to = (log, 1)), hidden = hidden)

    # persist the fully-rendered command to the log artifact so `buck2 test`
    # can replay it; `allow_args = True` expands cmd_args references inline
    context.actions.write(log, command, allow_args = True)

    # return the log as default output and configure external test runner execution
    # ExternalRunnerTestInfo carries env separately for test-framework-level env injection
    # while the command itself embeds env via the `env` cli for self-contained reproducibility
    return [
        DefaultInfo(default_output = log),
        ExternalRunnerTestInfo(
            type = "command",
            command = [command],
            env = context.attrs.environment,
        ),
    ]

test = rule(
    impl = _test_impl,
    doc = "defines a test target that runs a command and reports results via the external test runner",
    attrs = {
        "_log": attrs.string(default = "buck2.log"),
        "command": attrs.list(attrs.arg(), doc = "the test command to execute"),
        "context": attrs.string(default = "./", doc = "the working directory for the test, relative to the package"),
        "dependencies": attrs.named_set(attrs.dep(), default = [], doc = "targets whose default outputs are made available to the test"),
        "environment": attrs.dict(key = attrs.string(), value = attrs.arg(), default = {}, doc = "environment variables to set when running the test"),
        "mode": attrs.enum(["copy", "symlink"], default = "copy", doc = "whether to copy or symlink source files into the test context"),
        "sources": attrs.named_set(attrs.source(), default = [], doc = "source files made available to the test"),
    },
)
