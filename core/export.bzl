"""provides the export rule for copying or symlinking source files"""

load("@prelude//core/path.bzl", "path")

def _export_impl(context: AnalysisContext) -> list[Provider]:
    # select the file installation strategy based on the mode attribute
    # `copy` materializes standalone files while `symlink` preserves references
    # to source or generated artifacts for faster incremental workflows
    install = context.actions.copy_file if context.attrs.mode == "copy" else context.actions.symlink_file

    # install source files into the build output, preserving package-relative paths
    # - for source files (`is_source = True`), prefix with `context.label.package`
    # - for generated artifacts (`is_source = False`), keep producer short_path
    # this keeps repository layout stable for checked-in files while preserving
    # producer-defined paths for dependency outputs
    sources = [install(path.join(context.label.package, source.short_path), source) if source.is_source else install(source.short_path, source) for source in context.attrs.sources]

    # return defaultinfo exposing exported artifacts as default outputs
    return [DefaultInfo(default_outputs = sources)]

export = rule(
    impl = _export_impl,
    doc = "copies or symlinks source files into the build output",
    attrs = {
        "mode": attrs.enum(["copy", "symlink"], default = "symlink", doc = "whether to copy or symlink the source files"),
        "sources": attrs.named_set(attrs.source(), doc = "the source files to export"),
    },
)
