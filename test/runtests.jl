using MultivariateMeasures
using Test

@testset "MultivariateMeasures.jl" begin

    @testset "LKJCholesky" begin
        D = LKJCholesky{(:k,:η)}
        par = transform(asparams(D, (k=4,)), randn(1))
        d = D(merge((k=4,),par))
        # @test params(d) == par

        η  = par.η
        logη = log(η)

        y = rand(d)
        η = par.η
        ℓ = logdensity(LKJCholesky(4,η), y)
        @test ℓ ≈ logdensity(LKJCholesky(k=4,logη=logη), y)
    end
end
