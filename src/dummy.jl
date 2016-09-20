

abstract DummyTarget

kernel_queue = []

function register_kernel{F<:Function}(::Type{DummyTarget}, f::Type{F}, args)
    signature = (f, args...)
    kernel_id = gensym("DummyKernel")
    push!(kernel_queue, (kernel_id, f, args))
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
        # Our lazy translation scheme allows for batch translation of several
        # kernels. This is much more efficient, eg. when translating with a
        # command-line tool that has a significant startup overhead.
    end
    while !isempty(kernel_queue)
        kernel = pop!(kernel_queue)
        compile(kernel...)
    end
end



function compile(kernel_id, functype, argtypes)
    info("Translating $kernel_id $functype$argtypes")

    # Get the typed AST to translate:
    ast = code_typed(functype, argtypes...)
    ast = unbox(ast)

    flow = FlowGraph(ast)
    println(flow)
    showgraph(flow)
    statements, _ = raise_flow(1, flow)
    for s in statements
        println(s)
    end

    # <here is where the actual translation would occur>.
end

