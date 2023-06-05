module PythonCall

const VERSION = v"0.9.13"
const ROOT_DIR = dirname(@__DIR__)

import Reexport: @reexport

include("Utils/src.jl")
include("CPython/src.jl")
include("GC/src.jl")
include("Base/src.jl")
include("Convert/src.jl")
include("Exec/src.jl")
include("PyMacro/src.jl")
include("PyWrap/src.jl")
include("JlWrap/src.jl")

import .PythonCall_GC as GC
@reexport using .PythonCall_Base
@reexport using .PythonCall_Convert
@reexport using .PythonCall_Exec
@reexport using .PythonCall_PyMacro
@reexport using .PythonCall_PyWrap
@reexport using .PythonCall_JlWrap

using .PythonCall_Base: unsafe_pynext, pynew, pydel!, pycopy!, pyisnull

end
