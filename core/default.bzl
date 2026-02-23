"""Provides the default rule for running arbitrary commands."""

load("@prelude//core/path.bzl", "path")

def _default_impl(context: AnalysisContext) -> list[Provider]:
    # Declare the log file used to persist the command and as a fallback default output.
    log = context.actions.declare_output(path.join(context.label.package, context.attrs.context, context.attrs._log))
    # Select the file installation strategy based on the mode attribute.
    install = context.actions.copy_file if context.attrs.mode == "copy" else context.actions.symlink_file
    # Gather the default outputs of all declared dependencies.
    dependencies = [
        output
        for dependency in context.attrs.dependencies
        for output in dependency[DefaultInfo].default_outputs
    ]

    # Declare output artifacts for each expected output file.
    outputs = [
        context.actions.declare_output(path.join(context.label.package, context.attrs.context, output))
        for output in context.attrs.outputs
    ]

    # Install source files into the build context, preserving package-relative paths.
    sources = [
        install(path.join(context.label.package, source.short_path), source) if source.is_source else install(source.short_path, source)
        for source in context.attrs.sources
    ]

    # Bundle dependencies, sources, and output declarations for the build action.
    hidden = dependencies + sources + [output.as_output() for output in outputs]
    # Format environment variables as KEY=VALUE pairs for the env command.
    env_args = [cmd_args(key, value, delimiter = "=") for key, value in context.attrs.environment.items()]
    # Compute the log path and its depth to resolve the project root via parent traversal.
    log_path = path.join(context.label.package, context.attrs.context, context.attrs._log)
    depth = path.depth(log_path)
    # Build the env prefix that sets environment variables and changes to the project root.
    env = cmd_args("env", env_args, "-C", log, parent = depth)
    # Wrap the user-provided command arguments.
    args = cmd_args(context.attrs.command)
    # Combine args with the hidden artifact references so Buck2 tracks all inputs.
    hidden = cmd_args("--", args, hidden = hidden)
    # Render the full build command with paths relative to the project root.
    command = cmd_args(hidden, relative_to = (log, depth))
    # Persist the command to the log file for reproducibility.
    context.actions.write(log, command, allow_args = True)
    # Execute the command as a build action.
    context.actions.run(command, category = "command", no_outputs_cleanup = True)
    # Return build outputs (falling back to log) and a RunInfo for `buck2 run` from project root.
    return [DefaultInfo(default_outputs = outputs or [log]), RunInfo(args = cmd_args(env, "--", args))]

default = rule(
    impl = _default_impl,
    doc = "Runs an arbitrary command with optional sources, outputs, dependencies, and environment variables.",
    attrs = {
        "_log": attrs.string(default = "buck2.log"),
        "command": attrs.list(attrs.arg(), doc = "The command to execute."),
        "context": attrs.string(default = "./", doc = "The working directory for declared outputs, relative to the package."),
        "dependencies": attrs.named_set(attrs.dep(), default = [], doc = "Targets whose default outputs are made available to the command."),
        "environment": attrs.dict(key = attrs.string(), value = attrs.arg(), default = {}, doc = "Environment variables to set when running the command."),
        "mode": attrs.enum(["copy", "symlink"], default = "copy", doc = "Whether to copy or symlink source files into the build context."),
        "outputs": attrs.named_set(attrs.string(), default = [], doc = "Output files the command is expected to produce."),
        "sources": attrs.named_set(attrs.source(), doc = "Source files made available to the command."),
    },
)
