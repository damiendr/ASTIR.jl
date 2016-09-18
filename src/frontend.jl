


function register_kernel
end


@generated function translated{target}(f::Function, ::Type{target}, args...)
    kernel_id = register_kernel(target, f, args)
    quote
        ASTIR.call_kernel($target, $(Val{kernel_id}), f, args)
    end
end

