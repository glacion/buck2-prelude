"""Provides the json rule for writing JSON files."""

load("//core:path.bzl", "path")

def _json_impl(context: AnalysisContext) -> list[Provider]:
    # Declare the output artifact at the package-relative path.
    output = context.actions.declare_output(path.join(context.label.package, context.attrs.path))
    # Serialize the content as JSON and write it to the output file.
    context.actions.write_json(output, context.attrs.content, pretty = context.attrs.pretty)

json = rule(
    impl = _json_impl,
    doc = "Writes a JSON value to a file.",
    attrs = {
        "content": attrs.any(doc = "The content to serialize as JSON."),
        "path": attrs.arg(doc = "The output path."),
        "pretty": attrs.bool(default = False, doc = "Whether to pretty-print the JSON output."),
    },
)
