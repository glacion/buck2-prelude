"""provides the default rule for running arbitrary commands"""

load("@prelude//core/path.bzl", "path")

def _default_impl(context: AnalysisContext) -> list[Provider]:
    # select the file installation strategy based on the mode attribute
    install = context.actions.copy_file if context.attrs.mode == "copy" else context.actions.symlink_file

    # declare the log artifact for cwd resolution by `env -C`, scoping it under
    # `package/context/_log` via `path.join` to normalize separators and collapse
    # redundant components (e.g. `./`); inlined since default does not reuse the path
    log = context.actions.declare_output(path.join(context.label.package, context.attrs.context, context.attrs._log)).as_output()

    # gather dependency outputs from defaultinfo for hidden input tracking
    # `default_outputs` is the supported aggregation surface in this buck2 api
    # including these artifacts keeps action keys sensitive to dependency changes
    dependencies = [
        output
        for dependency in context.attrs.dependencies
        for output in dependency[DefaultInfo].default_outputs
    ]

    # declare output artifacts for each expected output file
    # `path.join(package, context, output)` keeps outputs scoped under the
    # target's package/context directory and normalizes separators/components
    # (for example removing redundant `./`) before declaration
    outputs = [
        context.actions.declare_output(path.join(context.label.package, context.attrs.context, output))
        for output in (context.attrs.outputs or [])
    ]

    # install source files into the build context while preserving layout semantics:
    # - for source files (`is_source = True`), prefix with `context.label.package` so files
    #   keep their package-relative directory structure
    # - for dependency outputs (`is_source = False`), keep the producer-provided short_path
    #   so generated artifacts preserve their declared output structure
    sources = [
        install(path.join(context.label.package, source.short_path), source) if source.is_source else install(source.short_path, source)
        for source in context.attrs.sources
    ]

    # bundle dependencies, sources, and output declarations as hidden inputs
    # these must be present in the action key even when not rendered on argv,
    # otherwise buck2 can miss invalidation when dependencies, sources, or
    # declared outputs change and incorrectly reuse stale results
    hidden = dependencies + sources + [output.as_output() for output in outputs]

    # format environment variables as key=value pairs for the env command
    # we intentionally do not use actions.run(env = ...): that only affects the build action,
    # while this rule must apply identical environment behavior to both the build action and
    # runinfo (`buck2 run`) and keep cwd handling in one explicit command path
    env = [cmd_args(key, value, delimiter = "=") for key, value in context.attrs.environment.items()]

    # build an `env -C <dir>` prefix that executes from the action directory
    # `parent = 1` resolves the cwd to the log's parent path
    cwd = cmd_args("env", "-C", log, parent = 1)

    # compose the final command with cwd prefix, environment assignments, user
    # command argv, and hidden artifacts for action-key tracking
    command = cmd_args(cwd, env, context.attrs.command, hidden = hidden)

    # execute the command as a build action, `no_outputs_cleanup` prevents buck2
    # from deleting undeclared outputs that downstream targets may depend on
    context.actions.run(command, category = "command", no_outputs_cleanup = True)

    # expose declared outputs for the rule target
    # reusing `command` for runinfo guarantees `buck2 run` executes the exact
    # same argv/cwd/env semantics as the build action, avoiding drift where run
    # succeeds/fails differently than build due to command construction mismatch
    return [DefaultInfo(default_outputs = outputs), RunInfo(args = command)]

default = rule(
    impl = _default_impl,
    doc = "runs an arbitrary command with optional sources, outputs, dependencies, and environment variables",
    attrs = {
        "_log": attrs.string(default = "buck2.log"),
        "command": attrs.list(attrs.arg(), doc = "the command to execute"),
        "context": attrs.string(default = "./", doc = "the working directory for declared outputs, relative to the package"),
        "dependencies": attrs.named_set(attrs.dep(), default = [], doc = "targets whose default outputs are made available to the command"),
        "environment": attrs.dict(key = attrs.string(), value = attrs.arg(), default = {}, doc = "environment variables to set when running the command"),
        "mode": attrs.enum(["copy", "symlink"], default = "copy", doc = "whether to copy or symlink source files into the build context"),
        "outputs": attrs.option(attrs.named_set(attrs.string()), default = None, doc = "optional output files the command is expected to produce"),
        "sources": attrs.named_set(attrs.source(), default = [], doc = "source files made available to the command"),
    },
)
