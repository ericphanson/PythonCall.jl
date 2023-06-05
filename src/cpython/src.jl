"""
    module CPython

This module provides a direct interface to the Python C API.
"""
module PythonCall_CPython

import Base: @kwdef
import CondaPkg
import Pkg
import ..PythonCall_Utils as Utils
import Libdl: RTLD_LAZY, RTLD_DEEPBIND, RTLD_GLOBAL, dlopen, dlopen_e, dlsym, dlsym_e, dlclose
import Requires: @require
import UnsafePointers: UnsafePtr

include("consts.jl")
include("pointers.jl")
include("extras.jl")
include("init.jl")
include("gil.jl")

end
