"""Provides the shell rule for executing commands via a shell interpreter."""

load("//core:path.bzl", "path")

def _shell_impl(context: AnalysisContext) -> list[Provider]:
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
    # Join the command arguments into a single string for shell evaluation.
    args = cmd_args(context.attrs.command, delimiter = " ")
    # Wrap the shell invocation with hidden artifact references so Buck2 tracks all inputs.
    hidden = cmd_args(context.attrs.shell, "-c", args, hidden = hidden)
    # Render the full build command with paths relative to the project root.
    command = cmd_args(hidden, relative_to = (log, depth))
    # Persist the command to the log file for reproducibility.
    context.actions.write(log, command, allow_args = True)
    # Execute the command as a build action.
    context.actions.run(command, category = "shell", no_outputs_cleanup = True)
    # Return build outputs (falling back to log) and a RunInfo for `buck2 run` from project root.
    return [DefaultInfo(default_outputs = outputs or [log]), RunInfo(args = cmd_args(env, context.attrs.shell, "-c", args))]

shell = rule(
    impl = _shell_impl,
    doc = "Executes a command via a shell interpreter with optional sources, outputs, dependencies, and environment variables.",
    attrs = {
        "_log": attrs.string(default = "buck2.log"),
        "command": attrs.list(attrs.arg(), doc = "The command to execute, joined and passed to the shell as a single string."),
        "context": attrs.string(default = "./", doc = "The working directory for declared outputs, relative to the package."),
        "dependencies": attrs.named_set(attrs.dep(), default = [], doc = "Targets whose default outputs are made available to the command."),
        "environment": attrs.dict(key = attrs.string(), value = attrs.arg(), default = {}, doc = "Environment variables to set when running the command."),
        "mode": attrs.enum(["copy", "symlink"], default = "copy", doc = "Whether to copy or symlink source files into the build context."),
        "outputs": attrs.named_set(attrs.string(), default = [], doc = "Output files the command is expected to produce."),
        "shell": attrs.arg(default = "/bin/sh", doc = "The shell interpreter to use."),
        "sources": attrs.named_set(attrs.source(), default = [], doc = "Source files made available to the command."),
    },
)
