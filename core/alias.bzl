"""Provides the alias rule for aggregating default outputs from dependencies."""

def _alias_impl(context: AnalysisContext) -> list[Provider]:
    # Collect all default outputs from each dependency into a single flat list.
    outputs = [output for dependency in context.attrs.actual for output in dependency[DefaultInfo].default_outputs]
    # Return aggregated outputs and propagate RunInfo from any dependency that supports `buck2 run`.
    return [DefaultInfo(default_outputs = outputs)] + [dependency[RunInfo] for dependency in context.attrs.actual if RunInfo in dependency]

alias = rule(
    impl = _alias_impl,
    doc = "Creates a target that aggregates the default outputs of its dependencies.",
    attrs = {
        "actual": attrs.named_set(attrs.dep(), doc = "The dependencies whose default outputs to aggregate."),
    },
)
