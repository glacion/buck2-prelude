"""provides the http rule for downloading files"""

def _http_impl(context: AnalysisContext) -> list[Provider]:
    # declare the output artifact for the downloaded file
    # the artifact path is target-scoped, so downstream rules can depend on it
    # as a normal build output without special handling
    output = context.actions.declare_output(context.attrs.output)

    # download the file from the url and verify its sha-256 integrity
    # sha validation makes downloads deterministic and fails fast on drift or
    # supply-chain tampering
    context.actions.download_file(output, context.attrs.url, sha256 = context.attrs.sha256)

    # return defaultinfo with the downloaded artifact as the default output
    # exposing a default output allows direct dependency and alias aggregation
    return [DefaultInfo(default_output = output)]

# define the public `http` rule wrapper around `_http_impl`
http = rule(
    impl = _http_impl,
    doc = "downloads a file from a url with integrity verification",
    attrs = {
        "output": attrs.string(doc = "the output filename"),
        "sha256": attrs.string(doc = "the expected sha-256 hash of the downloaded file"),
        "url": attrs.string(doc = "the url to download from"),
    },
)
