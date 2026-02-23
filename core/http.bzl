"""Provides the http rule for downloading files."""

def _http_impl(context: AnalysisContext) -> list[Provider]:
    # Declare the output artifact for the downloaded file.
    out = context.actions.declare_output(context.attrs.out)
    # Download the file from the URL and verify its SHA-256 integrity.
    context.actions.download_file(out, context.attrs.url, sha256 = context.attrs.sha256)

http = rule(
    impl = _http_impl,
    doc = "Downloads a file from a URL with integrity verification.",
    attrs = {
        "out": attrs.string(doc = "The output filename."),
        "sha256": attrs.string(doc = "The expected SHA-256 hash of the downloaded file."),
        "url": attrs.string(doc = "The URL to download from."),
    },
)
