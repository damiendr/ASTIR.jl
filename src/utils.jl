
"""
Calls type inference on a function type.
"""
function Base.code_typed{T<:Function}(functype::Type{T}, argtypes...)
    # Extract a type-inferred AST:
    m = Base._methods_by_ftype(Tuple{functype, argtypes...}, -1)[1]
    codeinfo = Core.Inference.typeinf_uncached(m[3], m[1], m[2], true)[1]
    ast = Base.uncompressed_ast(m[3], codeinfo)
end


function sexpr(obj)
    io = IOBuffer()
    Base.Meta.show_sexpr(io, obj)
    takebuf_string(io)
end

""" Depth-first tree traversal and transformation. """
function depthfirst
end
function depthfirst(func::Function, e::Expr)
    new_args = [depthfirst(func, arg) for arg in e.args]
    new_expr = Expr(e.head, new_args...)
    func(new_expr)
end
function depthfirst(func::Function, code::CodeInfo)
    newcode = deepcopy(code)
    newcode.code = Any[depthfirst(func, stmt) for stmt in code.code]
    # must be Any[] otherwise the CodeInfo will show as <compressed>.
    func(newcode)
end
depthfirst(func::Function, o::Any) = func(o)

