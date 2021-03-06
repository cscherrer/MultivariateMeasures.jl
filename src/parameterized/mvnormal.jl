
# Multivariate Normal distribution

using StatsFuns
using LinearAlgebra
using Random
import Base
using LoopVectorization

import MeasureTheory: logdensity
import MeasureTheory: MvNormal

using StrideArrays
using StaticArrays

const LowerCholesky{T} = Cholesky{T, <:LowerTriangular} 
const UpperCholesky{T} = Cholesky{T, <:UpperTriangular} 

@inline function logdet_pos(C::Cholesky)
    logdet_pos(getfield(C, :factors))
end


@inline function logdet_pos(A::Union{UpperTriangular{T},LowerTriangular{T}}) where {T}
    # ∑ᵢ log(aᵢ * 2^bᵢ) = log(∏ᵢ aᵢ) + log2 * ∑ᵢ bᵢ

    prod_ai = one(real(T))
    sum_bi = zero(real(T))

    @turbo for i = 1:ArrayInterface.size(A,1)
        diag_i = A.data[i, i]
        ai = significand(diag_i)
        bi = exponent(diag_i)
        prod_ai *= ai
        sum_bi += bi
    end

    return log(prod_ai) + logtwo * sum_bi      
end


###############################################################################
# MvNormal(σ)

function logdensity(UnrollQ::MayUnroll, d::MvNormal{(:σ,), <:Tuple{<:Cholesky}}, y)
    logdensity_mvnormal_σ(UnrollQ, KnownSize(getfield(d.σ, :factors)), y)
end

logdensity(d::MvNormal{(:σ,), <:Tuple{<:Cholesky}}, y) = logdensity_mvnormal_σ(getfield(d.σ, :factors), y)

logdensity_mvnormal_σ(UL::Union{UpperTriangular, LowerTriangular}, y::AbstractVector) = logdensity_mvnormal_σ(KnownSize(UL), y)

# TODO: Can we do this statically without a generated function?
@generated function logdensity_mvnormal_σ(U::KnownSize{Tuple{k,k}, <:UpperTriangular}, y::AbstractVector) where {k}
    UnrollQ = k < 20 ? Unroll() : NoUnroll()

    quote
        $(Expr(:meta,:inline))
        logdensity_mvnormal_σ($UnrollQ, U, y)
    end
end


@generated function logdensity_mvnormal_σ(::UnrollQ, U::KnownSize{Tuple{k,k}, <:UpperTriangular}, y::AbstractVector{T}) where {k,T, UnrollQ<:MayUnroll}
    log2π = log(big(2) * π)

    # Solve `y = σz` for `z`. We need this only as a way to calculate `z ⋅ z`

    header = quote
        $(Expr(:meta,:inline))
        U = U.value
        Udata = U.data
        z_dot_z = zero($T)
    end

    body = if UnrollQ <: Unroll
        quote
            z = StrideArray{$T}(undef, ($(StaticInt(k)),))

            @inbounds @fastmath for j ∈ 1:$k
                tmp = zero($T)
                for i = 1:(j-1)
                    tmp += Udata[i, j] * z[i]
                end
                zj = (y[j] - tmp) / Udata[j, j]
                z_dot_z += zj^2
                z[j] = zj
            end
        end
    else
        quote
            @inbounds begin # `@fastmath` needs to be moved inside the `@nexprs`          
                Base.Cartesian.@nexprs $k j -> begin
                    tmp = zero($T)
                    z_j = zero($T)
                    Base.Cartesian.@nexprs j - 1 i -> begin
                        @fastmath tmp += Udata[i, j] * z_i
                    end
                    @fastmath z_j = (y[j] - tmp) / Udata[j, j]
                    @fastmath z_dot_z += z_j^2
                end
            end
        end
    end

    footer = quote
        $(T(-k / 2 * log2π)) - logdet_pos(U) - z_dot_z / 2
    end

    return quote
        $(header.args...)
        $(body.args...)
        $(footer.args...)
    end

end

###############################################################################
# MvNormal(ω)

function logdensity(UnrollQ::MayUnroll, d::MvNormal{(:ω,), <:Tuple{<:Cholesky}}, y)
    logdensity_mvnormal_ω(UnrollQ, KnownSize(getfield(d.ω, :factors)), y)
end

logdensity(d::MvNormal{(:ω,), <:Tuple{<:Cholesky}}, y) = logdensity_mvnormal_ω(getfield(d.ω, :factors), y)

logdensity_mvnormal_ω(UL::Union{UpperTriangular, LowerTriangular}, y::AbstractVector) = logdensity_mvnormal_ω(KnownSize(UL), y)

# TODO: Can we do this statically without a generated function?
@generated function logdensity_mvnormal_ω(U::KnownSize{Tuple{k,k}, <:UpperTriangular}, y::AbstractVector) where {k}
    UnrollQ = k < 20 ? Unroll() : NoUnroll()

    quote
        $(Expr(:meta,:inline))
        logdensity_mvnormal_ω($UnrollQ, U, y)
    end
end

@generated function logdensity_mvnormal_ω(::UnrollQ, U::KnownSize{Tuple{k,k}, <:UpperTriangular}, y::AbstractVector{T}) where {k,T, UnrollQ<:MayUnroll}
    log2π = log(big(2) * π)

    header = quote
        $(Expr(:meta,:inline))
        U = U.value
        Udata = U.data
        # if z = Lᵗy, the logdensity depends on `det(U)` and `z ⋅ z`. So we find `z`
        z_dot_z = zero(T)
    end

    body = if UnrollQ <: Unroll
        quote
            @inbounds begin
                Base.Cartesian.@nexprs $k j -> begin
                    zj = zero(T)
                    Base.Cartesian.@nexprs j i -> begin
                        zj += Udata[i, j] * y[i]
                    end
                    z_dot_z += zj^2
                end
            end
        end
    else
        quote
            @fastmath for j ∈ 1:$k
                zj = zero(T)
                for i ∈ 1:j
                    @inbounds zj += Udata[i, j] * y[i]
                end
                z_dot_z += zj^2
            end
        end
    end

    footer = quote
        $(T(-k / 2 * log2π)) + logdet_pos(U) - z_dot_z / 2
    end

    return quote
        $(header.args...)
        $(body.args...)
        $(footer.args...)
    end
end

@inline function logdensity_mvnormal_ω(U::KnownSize{Tuple{nothing, nothing}, <:UpperTriangular}, y::AbstractVector{T}) where {T}
    k = first(size(U))
    @assert length(y) == k

    # if z = Lᵗy, the logdensity depends on `det(U)` and `z ⋅ z`. So we find `z`
    z_dot_z = zero(T)
    for j ∈ 1:k
        zj = zero(T)
        for i ∈ 1:j
            @inbounds zj += U[i, j] * y[i]
        end
        z_dot_z += zj^2
    end

    -k / 2 * log2π + logdet_pos(U) - z_dot_z / 2
end

function logdensity(d::MvNormal{(:μ, :σ)}, y::AbstractArray{T}) where {T}
    x = StrideArray{T}(undef, ArrayInterface.size(y))
    @inbounds for j in eachindex(y)
        x[j] = y[j] - d.μ[j]
    end
    GC.@preserve x logdensity(MvNormal(σ = d.σ), x)
end
using StrideArrays, StaticArrays, LoopVectorization, LinearAlgebra
