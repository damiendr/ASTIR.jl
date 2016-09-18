

function Base.code_typed{T<:Function}(functype::Type{T}, argtypes...)
    # Extract a type-inferred AST:
    method = Base._methods_by_ftype(Tuple{functype, argtypes...}, -1)[1]
    dump(method)
    codeinfo = Core.Inference.typeinf(method[3], method[1], method[2], true)[1]
    ast = Base.uncompressed_ast(method[3], codeinfo)
end

