

function Base.code_typed{T<:Function}(functype::Type{T}, argtypes...)
    # Extract a type-inferred AST:
    m = Base._methods_by_ftype(Tuple{functype, argtypes...}, -1)[1]
    codeinfo = Core.Inference.typeinf_uncached(m[3], m[1], m[2], true)[1]
    ast = Base.uncompressed_ast(m[3], codeinfo)
end

