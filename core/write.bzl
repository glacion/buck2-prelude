"""provides the write rule for writing content to a file"""

# import normalized path helpers used to scope outputs under package-relative locations
load("@prelude//core/path.bzl", "path")

def _write_impl(context: AnalysisContext) -> list[Provider]:
    # declare the output artifact at the package-relative path
    # package scoping keeps generated file locations deterministic per target
    output = context.actions.declare_output(path.join(context.label.package, context.attrs.path))

    # write the content to the output file, optionally making it executable
    # `allow_args = True` permits cmd_args/artifact expansion in generated content
    context.actions.write(output, context.attrs.content, is_executable = context.attrs.executable, allow_args = True)

    # return defaultinfo with the written file as the default output
    # downstream rules can consume this artifact via normal default output wiring
    return [DefaultInfo(default_output = output)]

# define the public `write` rule wrapper around `_write_impl`
write = rule(
    impl = _write_impl,
    doc = "writes content to a file",
    attrs = {
        "content": attrs.arg(doc = "the content to write"),
        "executable": attrs.bool(default = False, doc = "whether the output file should be executable"),
        "path": attrs.string(doc = "the output path"),
    },
)
