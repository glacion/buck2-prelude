"""Provides the alias rule for aggregating default outputs from dependencies."""

def _alias_impl(context: AnalysisContext) -> list[Provider]:
    # Collect all default outputs from each dependency into a single flat list.
    outputs = [
        output
        for dependency in context.attrs.actual
        for output in dependency[DefaultInfo].default_outputs
    ]
    return [DefaultInfo(default_outputs = outputs)]

alias = rule(
    impl = _alias_impl,
    doc = "Creates a target that aggregates the default outputs of its dependencies.",
    attrs = {
        "actual": attrs.named_set(attrs.dep(), doc = "The dependencies whose default outputs to aggregate."),
    },
)
