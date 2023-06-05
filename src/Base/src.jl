module PythonCall_Base

import ..PythonCall_Utils as Utils
import ..PythonCall_CPython as C
import ..PythonCall_GC as GC

import Dates: Date, Time, DateTime, year, month, day, hour, minute, second, millisecond, microsecond, nanosecond
import Markdown

include("Py.jl")
include("err.jl")
include("import.jl")
include("builtins.jl")

include("abstract/object.jl")
include("abstract/iter.jl")
include("abstract/builtins.jl")
include("abstract/number.jl")

include("concrete/str.jl")
include("concrete/bytes.jl")
include("concrete/tuple.jl")
include("concrete/list.jl")
include("concrete/dict.jl")
include("concrete/bool.jl")
include("concrete/int.jl")
include("concrete/float.jl")
include("concrete/complex.jl")
include("concrete/set.jl")
include("concrete/slice.jl")
include("concrete/range.jl")
include("concrete/none.jl")
include("concrete/type.jl")
include("concrete/datetime.jl")
include("concrete/fraction.jl")

include("with.jl")
include("pyconst_macro.jl")

function __init__()
    init_pybuiltins()
    init_datetime()
    init_fraction()
end

end
