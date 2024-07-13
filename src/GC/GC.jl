"""
    module PythonCall.GC

Garbage collection of Python objects.

See `disable` and `enable`.
"""
module GC

using ..C: C

const ENABLED = Ref(true)
const QUEUE = C.PyPtr[]

# This is used for basic profiling
const SECONDS_SPENT_IN_GC = Threads.Atomic{Float64}()


"""
    PythonCall.GC.disable()

Disable the PythonCall garbage collector.

This means that whenever a Python object owned by Julia is finalized, it is not immediately
freed but is instead added to a queue of objects to free later when `enable()` is called.

Like most PythonCall functions, you must only call this from the main thread.
"""
function disable()
    ENABLED[] = false
    return
end

"""
    PythonCall.GC.enable()

Re-enable the PythonCall garbage collector.

This frees any Python objects which were finalized while the GC was disabled, and allows
objects finalized in the future to be freed immediately.

Like most PythonCall functions, you must only call this from the main thread.
"""
function enable()
    ENABLED[] = true
    if !isempty(QUEUE)
        C.with_gil(false) do
            for ptr in QUEUE
                if ptr != C.PyNULL
                    C.Py_DecRef(ptr)
                end
            end
        end
    end
    empty!(QUEUE)
    return
end

function enqueue(ptr::C.PyPtr)
    if ptr != C.PyNULL && C.CTX.is_initialized
        if ENABLED[]
            t = @elapsed C.with_gil(false) do
                C.Py_DecRef(ptr)
            end
            Threads.atomic_add!(SECONDS_SPENT_IN_GC, t)
        else
            push!(QUEUE, ptr)
        end
    end
    return
end

function enqueue_all(ptrs)
    if C.CTX.is_initialized
        if ENABLED[]
            t = @elapsed C.with_gil(false) do
                for ptr in ptrs
                    if ptr != C.PyNULL
                        C.Py_DecRef(ptr)
                    end
                end
            end
            Threads.atomic_add!(SECONDS_SPENT_IN_GC, t)
        else
            append!(QUEUE, ptrs)
        end
    end
    return
end

end # module GC
