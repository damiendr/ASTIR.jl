

abstract DummyTarget

kernel_queue = []


dummy_call(f, args) = f(args...)


function translate_kernel(target::Type{DummyTarget}, kernel_id, signature)
    info("Translating $kernel_id $signature")

    # Get the typed AST to translate:
    functype, argtypes = signature
    ast = code_typed(functype, argtypes...)
    println(ast)
    ast = unbox(ast)

    flow = FlowGraph(ast)
    println(flow)
    showgraph(flow)
    statements, _ = raise_flow(1, flow)
    for s in statements
        println(s)
    end

    dummy_call
end


