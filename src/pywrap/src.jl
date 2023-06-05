module PythonCall_PyWrap

import ..PythonCall_Utils as Utils
import ..PythonCall_CPython as C
using ..PythonCall_Base
using ..PythonCall_Base: @autopy, unsafe_pynext, pyisnull, PyNULL, getptr
using ..PythonCall_Convert:
    pyconvert, pyconvert_tryconvert, pyconvert_isunconverted, pyconvert_result, pydel!,
    pyconvert_unconverted, pyconvert_return, pyconvert_add_rule, PYCONVERT_PRIORITY_ARRAY,
    PYCONVERT_PRIORITY_CANONICAL
using ..PythonCall_PyMacro: @py
import ..PythonCall_Base: ispy
using Base: @propagate_inbounds
import Tables

include("PyIterable.jl")
include("PyList.jl")
include("PySet.jl")
include("PyDict.jl")
include("PyArray.jl")
include("PyIO.jl")
include("PyTable.jl")
include("PyPandasDataFrame.jl")

function __init__()
    priority = PYCONVERT_PRIORITY_ARRAY
    pyconvert_add_rule("<arraystruct>", PyArray, pyconvert_rule_array_nocopy, priority)
    pyconvert_add_rule("<arrayinterface>", PyArray, pyconvert_rule_array_nocopy, priority)
    pyconvert_add_rule("<array>", PyArray, pyconvert_rule_array_nocopy, priority)
    pyconvert_add_rule("<buffer>", PyArray, pyconvert_rule_array_nocopy, priority)
    priority = PYCONVERT_PRIORITY_CANONICAL
    pyconvert_add_rule("collections.abc:Iterable", PyIterable, pyconvert_rule_iterable, priority)
    pyconvert_add_rule("collections.abc:Sequence", PyList, pyconvert_rule_sequence, priority)
    pyconvert_add_rule("collections.abc:Set", PySet, pyconvert_rule_set, priority)
    pyconvert_add_rule("collections.abc:Mapping", PyDict, pyconvert_rule_mapping, priority)
    pyconvert_add_rule("io:IOBase", PyIO, pyconvert_rule_io, priority)
    pyconvert_add_rule("_io:_IOBase", PyIO, pyconvert_rule_io, priority)
    pyconvert_add_rule("pandas.core.frame:DataFrame", PyPandasDataFrame, pyconvert_rule_pandasdataframe, priority)
    pyconvert_add_rule("pandas.core.arrays.base:ExtensionArray", PyList, pyconvert_rule_sequence, priority)
end

end
