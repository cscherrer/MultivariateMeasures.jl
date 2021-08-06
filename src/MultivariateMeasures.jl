module MultivariateMeasures


using Static
using ArrayInterface

struct KnownSize{S, T}
    value::T
end

KnownSize(x::T) where {T} = KnownSize{Tuple{ArrayInterface.known_size(T)...}, T}(x)

using MeasureTheory
using KeywordCalls
include("utils.jl")
include("mvnormal.jl")

end
