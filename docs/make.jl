using MultivariateMeasures
using Documenter

DocMeta.setdocmeta!(MultivariateMeasures, :DocTestSetup, :(using MultivariateMeasures); recursive=true)

makedocs(;
    modules=[MultivariateMeasures],
    authors="Chad Scherrer <chad.scherrer@gmail.com> and contributors",
    repo="https://github.com/cscherrer/MultivariateMeasures.jl/blob/{commit}{path}#{line}",
    sitename="MultivariateMeasures.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://cscherrer.github.io/MultivariateMeasures.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/cscherrer/MultivariateMeasures.jl",
)
