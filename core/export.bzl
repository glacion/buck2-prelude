"""Provides the export rule for copying or symlinking source files."""

load("//core:path.bzl", "path")

def _export_impl(context: AnalysisContext) -> list[Provider]:
    # Select the file installation strategy based on the mode attribute.
    install = context.actions.copy_file if context.attrs.mode == "copy" else context.actions.symlink_file
    # Install source files into the build output, preserving package-relative paths.
    sources = [
        install(path.join(context.label.package, source.short_path), source) if source.is_source else install(source.short_path, source)
        for source in context.attrs.sources
    ]
    return [DefaultInfo(default_outputs = sources)]

export = rule(
    impl = _export_impl,
    doc = "Copies or symlinks source files into the build output.",
    attrs = {
        "mode": attrs.enum(["copy", "symlink"], default = "copy", doc = "Whether to copy or symlink the source files."),
        "sources": attrs.named_set(attrs.source(), doc = "The source files to export."),
    },
)
