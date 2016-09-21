
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
    # Keep me as fast as possible! Currently the overhead
    # is about 2-3x that of regular dispatch.
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
    # We use the @generated mechanism to associate a kernel ID
    # to each new call signature. The mechanism is robust to
    # methods being redefined, ie. it will correctly generate
    # a new kernel ID in that case. EDIT: NOT! need to wait
    # for fix to #265.
    # This is much faster (2-3x) than looking up the method in
    # Julia's dispatch table and then looking up the kernel ID
    # for that method at runtime.
    kernel_id = gensym("kernel")
    quote
        ASTIR.kernel_call($(QuoteNode(kernel_id)), target, f, args)
    end
end

"""
Main entry point with batch translation.

Batch translation is very advantageous when the translation involves a command-
line tool with high startup overhead, eg. compilers.

This entry point (ab)uses type inference to get a peek at kernels that *may*
be about to be executed, *before* they're actually executed. It builds a list
of candidates that can be batch-translated the first time the code is run.

Note: this technique may be in fact be proscribed, see:
https://github.com/JuliaLang/julia/issues/18568
"""
@generated function batch_translated{target}(f::Function, t::Type{target}, args...)
    kernel_id = gensym("kernel")
    signature = (f, args)
    push!(translate_queue, (target, kernel_id, signature))
    # This function is typically called only once per new type
    # signature, but may occasionally be called a handful of times,
    # which may lead to some redundant translations being triggered
    # in batch mode. The overhead is usually small enough to be ignored.
    quote
        ASTIR.translate_all()
        ASTIR.kernel_call($(QuoteNode(kernel_id)), t, f, args)
    end
end

function translate_all()
    if isempty(translate_queue)
        return # fast trivial path
    end

    # Group queued kernels by target:
    by_target = DefaultDict(DataType,Vector,[])
    while !isempty(translate_queue)
        target, kernel_id, signature = pop!(translate_queue)
        push!(by_target[target], (kernel_id, signature))
    end
    
    # Translate each target group:
    for (target, kernels) in by_target
        funcs = translate_batch(target, kernels)
        for (kernel_func, (kernel_id, signature)) in zip(funcs, kernels)
            # Cache it:
            nf = Nullable{Function}(kernel_func)
            kernel_cache[kernel_id] = nf
        end
    end
end

"""
Default batch translate implementation.
Targets can override this for better efficiency when translating many kernels at once.
"""
function translate_batch(target::Any, kernels)
    [translate_kernel(target, args...) for args in kernels]
end

