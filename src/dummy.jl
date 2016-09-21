

abstract DummyTarget

kernel_queue = []


dummy_call(f, args) = f(args...)


function translate_kernel(target::Type{DummyTarget}, kernel_id, signature)
    info("Translating $kernel_id $signature")

    # Get the typed AST to translate:
    functype, argtypes = signature
    ast = code_typed(functype, argtypes...)

    info("Unboxing variables...")
    ast = unbox(ast)
    
    info("Recovering structured control flow...")
    flow = FlowGraph(ast)
    showgraph(flow)

    statements, _ = raise_flow(1, flow)
    for s in statements
        println(s)
    end

    info("Done translating.")

    dummy_call
end


