"""provides the alias rule for aggregating default outputs from dependencies"""

def _alias_impl(context: AnalysisContext) -> list[Provider]:
    # collect dependency outputs from defaultinfo into one flat list
    # `default_outputs` is the supported aggregation surface in this buck2 api
    # using only this field avoids analysis errors from unsupported attributes
    outputs = [
        output
        for dependency in context.attrs.actual
        for output in dependency[DefaultInfo].default_outputs
    ]

    # return defaultinfo with the aggregated outputs
    # alias intentionally forwards only default artifacts and does not add run
    # providers, which avoids ambiguous run semantics for multi-dependency aliases
    return [DefaultInfo(default_outputs = outputs)]

alias = rule(
    impl = _alias_impl,
    doc = "creates a target that aggregates the default outputs of its dependencies",
    attrs = {
        "actual": attrs.named_set(attrs.dep(), doc = "the dependencies whose default outputs to aggregate"),
    },
)
