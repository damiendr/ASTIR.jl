

abstract DummyTarget


kernels = Dict{Tuple,Symbol}()
kernel_queue = []

function register_kernel{F<:Function}(::Type{DummyTarget}, f::Type{F}, args)
    signature = (f, args...)
    kernel_id = get(kernels, signature, :nothing)
    if kernel_id == :nothing
        kernel_id = gensym("DummyKernel")
        kernels[signature] = kernel_id
        push!(kernel_queue, (kernel_id, f, args))
        info("Registered new kernel $kernel_id for call signature $signature")
    end
    kernel_id
end

function call_kernel{kernel_id}(::Type{DummyTarget}, ::Type{Val{kernel_id}},
                                f::Function, args::Tuple)
    # Ensure all kernels encountered so far have been translated:
    compile_all()

    # In this dummy implementation we just call the original function:
    info("Calling kernel $kernel_id")
    f(args...)
end

function compile_all()
    if length(kernel_queue) > 1
        info("Batch translation of $(length(kernel_queue)) kernels")
    end
    while !isempty(kernel_queue)
        kernel_id, functype, argtypes = pop!(kernel_queue)
        info("Translating $kernel_id $functype$argtypes")

        # Get the typed AST to translate:
        ast = code_typed(functype, argtypes...)
        info(ast)
        
        # <here is where the actual translation would occur>.
    end
end
