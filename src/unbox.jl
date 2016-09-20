
using Base.Meta

"""
Removes boxing of native types:
    (:call, :(Base.box), Type, val)
    (:call, :(Base.Math.box), Type, val)
    (:call, :(Base.FastMath.box), Type, val)
    => val
"""
function unbox(tree)
    depthfirst(tree) do e
        if isexpr(e, :call)
            if e.args[1] in (GlobalRef(Base,:box),
                             GlobalRef(Base.Math,:box), 
                             GlobalRef(Base.FastMath,:box))
                return e.args[3]
            end
        end
        return e
    end
end

