"""Provides the write rule for writing content to a file."""

load("//core:path.bzl", "path")

def _write_impl(context: AnalysisContext) -> list[Provider]:
    # Declare the output artifact at the package-relative path.
    output = context.actions.declare_output(path.join(context.label.package, context.attrs.path))
    # Write the content to the output file, optionally making it executable.
    context.actions.write(output, context.attrs.content, is_executable = context.attrs.executable, allow_args = True)

write = rule(
    impl = _write_impl,
    doc = "Writes content to a file.",
    attrs = {
        "content": attrs.arg(doc = "The content to write."),
        "executable": attrs.bool(default = False, doc = "Whether the output file should be executable."),
        "path": attrs.arg(doc = "The output path."),
    },
)
