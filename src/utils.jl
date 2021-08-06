
abstract type MayUnroll end

struct Unroll <: MayUnroll end

struct NoUnroll <: MayUnroll end
