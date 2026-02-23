"""Provides the test rule for defining test targets."""

load("@prelude//core/path.bzl", "path")

def _test_impl(context: AnalysisContext) -> list[Provider]:
    # Select the file installation strategy based on the mode attribute.
    install = context.actions.symlink_file if context.attrs.mode == "symlink" else context.actions.copy_file
    # Gather the default outputs of all declared dependencies.
    dependencies = [output for dependency in context.attrs.dependencies for output in dependency[DefaultInfo].default_outputs]
    # Install source files into the test context, preserving package-relative paths.
    sources = [install(path.join(context.label.package, source.short_path), source) if source.is_source else install(source.short_path, source) for source in context.attrs.sources]
    # Bundle dependencies and sources as hidden inputs for the test action.
    hidden = dependencies + sources
    # Declare the log file used to persist the command.
    log = context.actions.declare_output(path.join(context.label.package, context.attrs.context, context.attrs._log))
    # Build the test command with env -C to run from the log's parent directory.
    command = cmd_args(
        cmd_args("env", "-C", log, "--", hidden = hidden, parent = 1),
        cmd_args(context.attrs.command, relative_to = (log, 1)),
    )

    # Persist the command to the log file for reproducibility.
    context.actions.write(log, command, allow_args = True)
    # Return the log as the default output and an ExternalRunnerTestInfo for the test runner.
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
    doc = "Defines a test target that runs a command and reports results via the external test runner.",
    attrs = {
        "_log": attrs.string(default = "test.log"),
        "command": attrs.list(attrs.arg(), doc = "The test command to execute."),
        "context": attrs.string(default = "./", doc = "The working directory for the test, relative to the package."),
        "dependencies": attrs.named_set(attrs.dep(), default = [], doc = "Targets whose default outputs are made available to the test."),
        "environment": attrs.dict(key = attrs.string(), value = attrs.arg(), default = {}, doc = "Environment variables to set when running the test."),
        "mode": attrs.enum(["copy", "symlink"], default = "copy", doc = "Whether to copy or symlink source files into the test context."),
        "sources": attrs.named_set(attrs.source(), doc = "Source files made available to the test."),
    },
)
