
using DataStructures

const kernel_cache = Dict{Symbol,Nullable{Function}}()
const translate_queue = Tuple[]

"""
Function to be implemented by the various targets:
translate_kernel(target, kernel_id, signature)
"""
function translate_kernel
end

"""
Dispatch point for kernels.
"""
function kernel_call(kernel_id::Symbol, target, f::Function, args)
    # Keep me as fast as possible!
    nf = get(kernel_cache, kernel_id, Nullable{Function}())
    if isnull(nf)
        # Got a new kernel!
        signature = (typeof(f), map(typeof, args))
        nf = translate_cached(target, kernel_id, signature)
    end
    nf.value(f,args)
end

function translate_cached(target, kernel_id, signature)
    info("Compiling new kernel $kernel_id $signature for target $target")
    kernel_func = translate_kernel(target, kernel_id, signature)

    # Cache it:
    nf = Nullable{Function}(kernel_func)
    kernel_cache[kernel_id] = nf
    nf
end

"""
Main entry point (kernel-per-kernel translation).
"""
@generated function translated(f::Function, target, args...)
    kernel_id = gensym("kernel")
    quote
        ASTIR.kernel_call($(QuoteNode(kernel_id)), target, f, args)
    end
end

"""
Main entry point with batch compilation.
(may be problematic, see https://github.com/JuliaLang/julia/issues/18568)
"""
@generated function batch_translated{target}(f::Function, t::Type{target}, args...)
    kernel_id = gensym("kernel")
    signature = (f, args)
    push!(translate_queue, (target, kernel_id, signature))
    quote
        ASTIR.translate_all()
        ASTIR.kernel_call($(QuoteNode(kernel_id)), t, f, args)
    end
end

function translate_all()
    if isempty(translate_queue)
        return
    end

    # Group by target
    by_target = DefaultDict(DataType,Vector,[])
    while !isempty(translate_queue)
        target, kernel_id, signature = pop!(translate_queue)
        push!(by_target[target], (kernel_id, signature))
    end
    
    for (target, kernels) in by_target
        funcs = translate_batch(target, kernels)
        for (kernel_func, (kernel_id, signature)) in zip(funcs, kernels)
            # Cache it:
            nf = Nullable{Function}(kernel_func)
            kernel_cache[kernel_id] = nf
        end
    end
end

""" Default batch translate implementation """
function translate_batch(target::Any, kernels)
    [translate_kernel(target, args...) for args in kernels]
end

