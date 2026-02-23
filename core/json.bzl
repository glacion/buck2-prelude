"""provides the json rule for writing json files"""

load("@prelude//core/path.bzl", "path")

def _json_impl(context: AnalysisContext) -> list[Provider]:
    # declare the output artifact at the package-relative path
    # using package-scoped paths keeps generated files stable and predictable
    output = context.actions.declare_output(path.join(context.label.package, context.attrs.path))

    # serialize the content as json and write it to the output file
    # `pretty` toggles readability vs compactness without changing rule shape
    context.actions.write_json(output, context.attrs.content, pretty = context.attrs.pretty)

    # return defaultinfo with the written json file as the default output
    # this makes the generated json directly consumable by downstream rules
    return [DefaultInfo(default_output = output)]

json = rule(
    impl = _json_impl,
    doc = "writes a json value to a file",
    attrs = {
        "content": attrs.any(doc = "the content to serialize as json"),
        "path": attrs.string(doc = "the output path"),
        "pretty": attrs.bool(default = False, doc = "whether to pretty-print the json output"),
    },
)
