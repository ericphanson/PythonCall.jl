module PythonCall_JlWrap

using ..PythonCall: ROOT_DIR, VERSION
using ..PythonCall_Base
using ..PythonCall_Base: pynew, @autopy, getptr, incref, setptr!, pycopy!, pystr_asstring, pybool_asbool, errcheck, errset, PyNULL, pyistuple, pyisnull, pytypecheck, pydel!
using ..PythonCall_Convert: @pyconvert, pyconvert, PYCONVERT_PRIORITY_WRAP, pyconvert_add_rule, pyconvert_tryconvert
using Base: @propagate_inbounds
import Pkg
import ..PythonCall

include("C.jl")
include("juliacall.jl")
include("base.jl")
include("raw.jl")
include("callback.jl")
include("any.jl")
include("module.jl")
include("type.jl")
include("iter.jl")
include("objectarray.jl")
include("array.jl")
include("vector.jl")
include("dict.jl")
include("set.jl")
include("number.jl")
include("io.jl")

PythonCall_Base.Py(x) = ispy(x) ? throw(MethodError(Py, (x,))) : pyjl(x)

function PythonCall_Base._showerror_julia(io::IO, e::PyException; backtrace::Bool=false)
    if !pyisnull(pyJuliaError) && pyissubclass(e.t, pyJuliaError)
        try
            je, jb = pyconvert(Tuple{Any,Any}, e.v.args)
            print(io, "Julia: ")
            if je isa Exception
                showerror(io, je, jb, backtrace=backtrace && jb !== nothing)
            else
                print(io, je)
                backtrace && jb !== nothing && Base.show_backtrace(io, jb)
            end
        catch err
            println("<error while printing Julia exception inside Python exception: $err>")
        end
        true
    else
        false
    end
end

function __init__()
    init_juliacall()
    init_jlwrap_base()
    init_jlwrap_raw()
    init_jlwrap_callback()
    init_jlwrap_any()
    init_jlwrap_module()
    init_jlwrap_type()
    init_jlwrap_iter()
    init_jlwrap_array()
    init_jlwrap_vector()
    init_jlwrap_dict()
    init_jlwrap_set()
    init_jlwrap_number()
    init_jlwrap_io()
    init_juliacall_2()
    pyconvert_add_rule("juliacall:ValueBase", Any, pyconvert_rule_jlvalue, PYCONVERT_PRIORITY_WRAP)
end

end
