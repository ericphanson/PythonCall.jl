mutable struct PyConvertType
    py::Py
    is_none::Bool
    is_bool::Bool
    is_int::Bool
    is_float::Bool
    is_complex::Bool
    is_jl::Bool
end

struct PyConvertTask
    py::Py
    type::PyConvertType
    copy::Bool
    round::Bool
end

const _PYCONVERT_TYPES = Dict{C.PyPtr,PyConvertType}()

function _pyconvert_type(x::Py)
    # look up existing type info
    tptr = C.Py_Type(getptr(x))
    t = get(_PYCONVERT_TYPES, tptr, nothing)
    if t !== nothing
        @assert getptr(t.py) === tptr
        return t
    end
    # create new type info
    t = PyConvertType(
        pytype(x),
        pyisnone(x),
        pyisbool(x),
        pyisint(x),
        pyisfloat(x),
        pyiscomplex(x),
        pyisjl(x),
    )
    @assert getptr(t.py) === tptr
    _PYCONVERT_TYPES[tptr] = t
    return t
end

struct PyConvertContinue end

"""
    pyconvert2(T, x; copy=false, round=false)

Convert the Python object `x` to a Julia value of type `T`.

## Keyword Args

- `copy`: If true, prefer to copy container types instead of wrapping them. This will
  typically yield native Julia types. For example, this will convert a Python `list` to a
  Julia `Vector` instead of a `PyList`.

- `round`: If true, allow values to be rounded on conversion. For example, this allows a
  non-integer Python `float` to be converted to a Julia `Int`. It also allows a Python
  `datetime.datetime` at microsecond precision to be converted to a Julia `Dates.DateTime`,
  which only supports millisecond precision.
"""
function pyconvert2(::Type{T}, x; copy::Bool=false, round::Bool=false) where {T}
    x = Py(x)::Py
    t = PyConvertTask(x, _pyconvert_type(x), copy, round)

    ### wrapped julia values
    if t.type.is_jl
        return convert(T, pyjlvalue(x))::T
    end

    ### arrays

    ### canonical conversions
    # None -> nothing
    let ans = _pyconvert2(Nothing, T, t, _pyconvert2_none)
        ans === PyConvertContinue() || return ans::T
    end
    # bool -> Bool
    let ans = _pyconvert2(Bool, T, t, _pyconvert2_bool)
        ans === PyConvertContinue() || return ans::T
    end
    # int -> Integer
    let ans = _pyconvert2(Integer, T, t, _pyconvert2_int)
        ans === PyConvertContinue() || return ans::T
    end
    # float -> AbstractFloat
    let ans = _pyconvert2(AbstractFloat, T, t, _pyconvert2_float)
        ans === PyConvertContinue() || return ans::T
    end
    # complex -> Complex
    let ans = _pyconvert2(Complex, T, t, _pyconvert2_complex)
        ans === PyConvertContinue() || return ans::T
    end

    ### other conversions
    # None -> Missing
    let ans = _pyconvert2(Missing, T, t, _pyconvert2_none)
        ans === PyConvertContinue() || return ans::T
    end
    # number -> Number
    let ans = _pyconvert2(Number, T, t, _pyconvert2_int)
        ans === PyConvertContinue() || return ans::T
    end
    let ans = _pyconvert2(Number, T, t, _pyconvert2_float)
        ans === PyConvertContinue() || return ans::T
    end

    ### fallbacks
    # any -> Py
    if Py <: T
        return x::T
    end

    # give up
    error("cannot convert this Python '$(t.type.py.__name__)' to a Julia '$T'")
end
export pyconvert2

function _pyconvert2(::Type{T1}, ::Type{T2}, t::PyConvertTask, func::Function) where {T1,T2}
    T = Utils._typeintersect(T1, T2)
    if T == Union{}
        return PyConvertContinue()
    elseif T isa Union
        let ans = _pyconvert2(T.a, T2, t, func)
            ans === PyConvertContinue() || return ans::T
        end
        let ans = _pyconvert2(T.b, T2, t, func)
            ans === PyConvertContinue() || return ans::T
        end
        return PyConvertContinue()
    else
        return func(T, t)::Union{T,PyConvertContinue}
    end
end

function _pyconvert2_none(::Type{Nothing}, t::PyConvertTask)
    t.type.is_none || return PyConvertContinue()
    return nothing
end

function _pyconvert2_none(::Type{Missing}, t::PyConvertTask)
    t.type.is_none || return PyConvertContinue()
    return missing
end

function _pyconvert2_bool(::Type{Bool}, t::PyConvertTask)
    pyisFalse(t.py) && return false
    pyisTrue(t.py) && return true
    return PyConvertContinue()
end

function _pyconvert2_int(::Type{T}, t::PyConvertTask) where {T<:Number}
    # TODO
    return PyConvertContinue()
end

function _pyconvert2_float(::Type{T}, t::PyConvertTask) where {T<:Number}
    t.type.is_float || return PyConvertContinue()
    v = pyfloat_asdouble(t.py)
    if t.round && T <: Integer
        return round(T, v)::T
    else
        return convert(T, v)::T
    end
end

function _pyconvert2_complex(::Type{T}, t::PyConvertTask) where {T<:Number}
    t.type.is_complex || return PyConvertContinue()
    v = pycomplex_ascomplex(t.py)
    return convert(T, v)::T
end
