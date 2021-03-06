
using LightGraphs
using Base.Meta
import TikzGraphs
using DataStructures



type FlowGraph
    ast::CodeInfo
    statements::Vector{Any}
    in_edges::Vector{Vector{Int}}
end

function FlowGraph(ast::CodeInfo)

    # Build a list of statements and goto labels:
    statements = []
    targets = Dict{Int,Int}()
    for (i, stmt) in enumerate(ast.code)
        if isa(stmt, LineNumberNode) || isexpr(stmt, :inbounds)
            # skip these, they complicate flow analysis
            # (they may prevent detecting some jumps as break, return or continue)
            continue
        end
        if isexpr(stmt, :meta) && stmt.args[1] in (:pop_loc, :push_loc)
            # ditto
            continue
        end
        if isa(stmt, LabelNode)
            targets[stmt.label] = length(statements)+1
            continue
        end
        push!(statements, stmt)
    end

    in_edges = [Int[] for _ in eachindex(statements)]
    for (i, stmt) in enumerate(statements)
        if isa(stmt, GotoNode)
            target = targets[stmt.label]
            statements[i] = GotoNode(target)
            push!(in_edges[target], i)
            continue
        end
        if isexpr(stmt, :return)
            continue
        end
        if isexpr(stmt, :gotoifnot)
            test, label = stmt.args
            target = targets[label]
            statements[i] = Expr(:gotoifnot, test, target)
            push!(in_edges[target], i)
        end
        if i < length(statements)
            push!(in_edges[i+1], i)
        end
    end

    for (i, stmt) in enumerate(statements)
        println("$i $stmt")
    end

    FlowGraph(ast, statements, in_edges)
end



function showgraph(flow::FlowGraph)
    g = DiGraph(length(flow.statements))
    for i in eachindex(flow.statements)
        for j in flow.in_edges[i]
            add_edge!(g, j, i)
        end
    end
    display(TikzGraphs.plotHelper(g, "layered", "layered layout", ""))
end

"""
Note: this function does not handle the general case of converting
arbitrary programs with gotos to structured programs. It only knows
how to handle gotos generated by Julia from what was once a structured
program!
"""
function raise_flow(istart, flow::FlowGraph, seen=Set(Int[]), while_start=-1, while_end=-1)
    dest = []

    i = istart
    while 0 < i <= length(flow.statements)
        stmt = flow.statements[i]

        # Don't overrun the end of while loops:
        # ======================================
        if i == while_end+1
            break
        end

        # Check for flow interruptions:
        # ===================================
        if isexpr(stmt, :return)
            push!(seen, i)
            push!(dest, stmt)
            return dest, -1
        end
        if isa(stmt, GotoNode)
            target = stmt.label
            if target-1 == while_end
                push!(seen, i)
                push!(dest, Expr(:break))
                return dest, -1
            elseif target == while_start
                push!(seen, i)
                push!(dest, Expr(:continue))
                return dest, -1
            end
        end

        # Stop at reconvergence points until
        # all branches have been followed:
        # =======================================
        for j in flow.in_edges[i]
            if j < i
#                print("$istart-$i: checking $j...")
                if !(j in seen)
#                    println("WAIT")
                    return dest, i
#                else
#                    println("OK")
                end
            end
        end

        # OK, we're processing that node
#        println("$istart-$i: proceed")
        push!(seen, i)


        # Follow forward goto nodes:
        # ===============================
        if isa(stmt, GotoNode)
            target = stmt.label
            if target > i
                i = target
                continue
            end
            error("Unhandled backwards goto at $i")
        end

        # Detect while loops
        # ======================
        backwards = [j for j in flow.in_edges[i] if j > i]
        if length(backwards) > 1
            error("Too many backwards jump to $i")
        end

        # Handle gotoifnot nodes:
        # ============================
        if isexpr(stmt, :gotoifnot)
            test, else_target = stmt.args
#            println("$i: 'if' $test $else_target")

            if !isempty(backwards) && else_target == backwards[1] + 1
                # 'while $test' loop.
#                println("While loop from $i to $backwards "
#                        "$while_start $while_end")
                while_body, tail = raise_flow(i+1, flow, seen, i, backwards[1])
                if tail != -1 && tail != i
                    error("Bad 'while' reconvergence $i:$tail")
                end
                while_stmt = Expr(:while, test, Expr(:block, while_body...))
                push!(dest, while_stmt)
                i = backwards[1] + 1
                continue
            else
                # 'if then else' branch.
                # Visit both branches without letting each branch know
                # the nodes seen by the other branch:
                seen_if = Set(seen)
                if_branch, if_tail = raise_flow(i+1, flow, seen_if, while_start, while_end)

                seen_else = Set(seen)
                else_branch, else_tail = raise_flow(else_target, flow, seen_else, while_start, while_end)

#                println("$i: 'if' branches reached $if_tail/$else_tail")

                # Check for proper reconvergence:
                if else_tail == if_tail || else_tail == -1 || if_tail == -1
                    # Good reconvergence, mark the branches as seen:
                    push!(seen, seen_if...)
                    push!(seen, seen_else...)

                    # Build the if statement:
                    if_stmt = if length(else_branch) > 0
                        Expr(:if, test, Expr(:block, if_branch...),
                                        Expr(:block, else_branch...))
                    else
                        Expr(:if, test, Expr(:block, if_branch...))
                    end
                    push!(dest, if_stmt)

                    # Decide where to go next!
                    i = max(if_tail, else_tail)
                    continue
                else
                    error("Bad 'if' reconvergence $i:$if_tail/$else_tail")
                end
            end
        elseif !isempty(backwards)
            # 'while true' statement
            if i != while_start # otherwise we're already there
#                println("While loop from $i to $backwards "
#                        "$while_start $while_end")
                while_body, tail = raise_flow(i, flow, seen, i, backwards[1])
                if tail != -1 && tail != i
                    error("Bad 'while' reconvergence $i:$tail")
                end
                while_stmt = Expr(:while, :true, Expr(:block, while_body...))
                push!(dest, while_stmt)
                i = backwards[1] + 1
                continue
            end
        end

        # Just a regular statement:
#        push!(dest, LineNumberNode(i))
        push!(dest, stmt)
        i += 1
    end

    dest, -1
end

