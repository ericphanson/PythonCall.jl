mutable struct PyConvertType
    py::Py
    # core types
    is_none::Bool
    is_bool::Bool
    is_int::Bool
    is_float::Bool
    is_complex::Bool
    is_str::Bool
    # abstract number types
    is_abstract_number::Bool
    is_abstract_complex::Bool
    is_abstract_real::Bool
    is_abstract_rational::Bool
    is_abstract_integral::Bool
    # abstract collection types
    # others
    is_jl::Bool
end

struct PyConvertTask{T}
    py::Py
    copy::Bool
    round::Bool
    PyConvertTask{T}(py; copy=false, round=false) where {T} = new{T}(py, copy, round)
end

PyConvertTask{T}(t::PyConvertTask, py=t.py; copy=t.copy, round=t.round) where {T} = PyConvertTask{T}(py; copy, round)

const _PYCONVERT_TYPE_LIST_LEN = 8
const _PYCONVERT_TYPE_LIST = Vector{PyConvertType}()
const _PYCONVERT_TYPE_DICT = Dict{C.PyPtr,PyConvertType}()

@inline function _pyconvert_type_list_push(t, n=nothing)
    n == 1 && return
    ts = _PYCONVERT_TYPE_LIST
    if n === nothing
        n = length(ts)
        nmax = _PYCONVERT_TYPE_LIST_LEN
        if n < nmax
            pushfirst!(ts, t)
            return
        end
    end
    for i in n:-1:2
        ts[i] = ts[i-1]
    end
    ts[1] = t
    return
end

function PyConvertType(x::Py)
    tptr = C.Py_Type(getptr(x))
    # look up in the list (for frequently-used types)
    for (i, t) in pairs(_PYCONVERT_TYPE_LIST)
        if getptr(t.py) == tptr
            _pyconvert_type_list_push(t, i)
            return t
        end
    end
    # look up in the dict
    t = get(_PYCONVERT_TYPE_DICT, tptr, nothing)
    if t !== nothing
        @assert getptr(t.py) === tptr
        _pyconvert_type_list_push(t)
        return t
    end
    # create new type info
    t = PyConvertType(
        pytype(x),
        # core types
        pyisnone(x),
        pyisbool(x),
        pyisint(x),
        pyisfloat(x),
        pyiscomplex(x),
        pyisstr(x),
        # abstract number types
        pyisinstance(x, pyimport("numbers").Number),
        pyisinstance(x, pyimport("numbers").Complex),
        pyisinstance(x, pyimport("numbers").Real),
        pyisinstance(x, pyimport("numbers").Rational),
        pyisinstance(x, pyimport("numbers").Integral),
        # abstract collection types
        # others
        pyisjl(x),
    )
    @assert getptr(t.py) === tptr
    _PYCONVERT_TYPE_DICT[tptr] = t
    _pyconvert_type_list_push(t)
    return t
end

struct PyConvertContinue end

macro _pyconvert2_rule(prop, type, func)
    esc(:(
        let ans = _pyconvert2_rule(t, tp, $(Val(prop)), $type, $func)
            ans === PyConvertContinue() || return ans::T
        end
    ))
end

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
function pyconvert2(::Type{T}, x; copy::Bool=false, round::Bool=false, onerror=error) where {T}
    return _pyconvert2(PyConvertTask{T}(Py(x); copy, round); onerror)
end

function _pyconvert2(t::PyConvertTask{T}; onerror=error) where {T}
    ### fast route
    let ans = _pyconvert2_fast(t)
        ans === PyConvertContinue() || return ans::T
    end

    ### get type info
    tp = PyConvertType(t.py)

    ### wrapped julia values
    if tp.is_jl
        let ans = pyjlvalue(t.py)
            if ans isa T
                return ans::T
            else
                return convert(T, ans)::T
            end
        end
    end

    ### arrays

    ### canonical conversions
    # @_pyconvert2_rule(is_none, Nothing, _pyconvert2_none)  # fast
    # @_pyconvert2_rule(is_bool, Bool, _pyconvert2_bool)  # fast
    @_pyconvert2_rule(is_abstract_integral, Integer, _pyconvert2_integral)
    @_pyconvert2_rule(is_abstract_rational, Rational, _pyconvert2_rational)
    # @_pyconvert2_rule(is_float, AbstractFloat, _pyconvert2_float)  # fast
    @_pyconvert2_rule(is_complex, Complex, _pyconvert2_complex)
    # @_pyconvert2_rule(is_str, AbstractString, _pyconvert2_str)  # fast

    ### other conversions
    # @_pyconvert2_rule(is_none, Missing, _pyconvert2_none)  # fast
    @_pyconvert2_rule(is_abstract_real, Real, _pyconvert2_float)
    @_pyconvert2_rule(is_abstract_complex, Complex, _pyconvert2_complex)
    @_pyconvert2_rule(is_abstract_complex, Number, _pyconvert2_complex)
    # @_pyconvert2_rule(is_str, Symbol, _pyconvert2_str)  # fast
    # @_pyconvert2_rule(is_str, AbstractChar, _pyconvert2_str)  # fast

    ### fallbacks
    # any -> Py
    if Py <: T
        return t.py::T
    end

    ### give up
    if onerror === error
        return error("cannot convert this Python '$(tp.py.__name__)' to a Julia '$T'")
    else
        return onerror()
    end
end
export pyconvert2

function _pyconvert2_fast(t::PyConvertTask{T}) where {T}
    if T == Union{}
        return PyConvertContinue()
    elseif T isa Union
        let ans = _pyconvert2_fast(PyConvertTask{T.a}(t))
            ans === PyConvertContinue() || return ans::T
        end
        let ans = _pyconvert2_fast(PyConvertTask{T.b}(t))
            ans === PyConvertContinue() || return ans::T
        end
    elseif (T == Nothing) && pyisnone(t.py)
        return nothing
    elseif (T == Missing) && pyisnone(t.py)
        return missing
    elseif (T == Bool) && pyisFalse(t.py)
        return false
    elseif (T == Bool) && pyisTrue(t.py)
        return true
    elseif (T <: Integer) && pyisint(t.py)
        return _pyconvert2_integral(t)
    elseif (T <: AbstractFloat) && pyisfloat(t.py)
        return _pyconvert2_float(t)
    elseif (T <: Union{AbstractString,Symbol,AbstractChar}) && pyisstr(t.py)
        return _pyconvert2_str(t)
    end
    return PyConvertContinue()
end

function _pyconvert2_rule(t::PyConvertTask{T1}, tp::PyConvertType, vprop::Val{prop}, ::Type{T2}, func::Function) where {T1,T2,prop}
    T = Utils._typeintersect(T1, T2)
    if T == Union{}
        return PyConvertContinue()
    elseif T isa Union
        let ans = _pyconvert2_rule(t, tp, vprop, T.a, func)
            ans === PyConvertContinue() || return ans::T
        end
        let ans = _pyconvert2_rule(t, tp, vprop, T.b, func)
            ans === PyConvertContinue() || return ans::T
        end
        return PyConvertContinue()
    elseif getfield(tp, prop)
        return func(PyConvertTask{T}(t))::Union{T,PyConvertContinue}
    else
        return PyConvertContinue()
    end
end

function _pyconvert2_convert(::Type{T}, x, ::Type{T1}=Utils._type_ub(T)) where {T,T1}
    return (x isa T ? x : convert(T1, x))::T
end

function _pyconvert2_round(::Type{T}, x, ::Type{T1}=Utils._type_ub(T)) where {T,T1}
    return round(T1, x)::T
end

function _pyconvert2_none(::PyConvertTask{Nothing})
    return nothing
end

function _pyconvert2_none(::PyConvertTask{Missing})
    return missing
end

function _pyconvert2_bool(t::PyConvertTask{Bool})
    pyisFalse(t.py) && return false
    pyisTrue(t.py) && return true
    error("Python bool value is neither True nor False!")
end

function _pyconvert2_integral(t::PyConvertTask{T}) where {T<:Number}
    v = pyint_asinteger(T <: Integer ? T : Integer, t.py)
    return _pyconvert2_convert(T, v)::T
end

function _pyconvert2_rational(t::PyConvertTask{T}, ::Type{Rational{N0}}=Utils._type_lb(T), ::Type{Rational{N1}}=Utils._type_ub(T)) where {T<:Rational,N0,N1}
    # numerator
    num = _pyconvert2(PyConvertTask{Utils._typeintersect(Integer, N1)}(t, t.py.numerator), onerror=PyConvertContinue)
    num === PyConvertContinue() && return num
    # denominator
    den = _pyconvert2(PyConvertTask{Utils._typeintersect(Integer, N1)}(t, t.py.denominator), onerror=PyConvertContinue)
    den === PyConvertContinue() && return den
    # done
    return Rational{Utils._promote_type_bounded(N0, typeof(num), typeof(den), N1)}(num, den)::T
end

function _pyconvert2_rational(t::PyConvertTask{T}) where {T<:Number}
    ans = _pyconvert2_rational(PyConvertTask{Rational}(t))
    ans === PyConvertContinue() && return ans
    return _pyconvert2_convert(T, ans)::T
end

function _pyconvert2_float(t::PyConvertTask{T}) where {T<:Number}
    v = pyfloat_asdouble(t.py)
    if t.round && T <: Integer
        return _pyconvert2_round(T, v)::T
    else
        return _pyconvert2_convert(T, v)::T
    end
end

function _pyconvert2_complex(t::PyConvertTask{T}, ::Type{Complex{N0}}=Utils._type_lb(T), ::Type{Complex{N1}}=Utils._type_ub(T)) where {T<:Complex,N0,N1}
    v = pycomplex_ascomplex(t.py)
    v isa T && return v::T
    re = convert(Utils._typeintersect(Real,N1), real(v))::N1
    im = convert(Utils._typeintersect(Real,N1), imag(v))::N1
    return Complex{Utils._promote_type_bounded(N0, typeof(re), typeof(im), N1)}(re, im)::T
end

function _pyconvert2_complex(t::PyConvertTask{T}) where {T<:Number}
    ans = _pyconvert2_complex(PyConvertTask{Complex}(t))
    ans === PyConvertContinue() && return ans
    return _pyconvert2_convert(T, ans)::T
end

function _pyconvert2_str(t::PyConvertTask{T}) where {T<:AbstractString}
    v = pystr_asstring(t.py)
    return _pyconvert2_convert(T, v)::T
end

function _pyconvert2_str(t::PyConvertTask{Symbol})
    v = pystr_asstring(t.py)
    return Symbol(v)
end

function _pyconvert2_str(t::PyConvertTask{T}) where {T<:AbstractChar}
    v = pystr_asstring(t.py)
    length(v) == 1 || error("only length-1 strings can be converted to char")
    v = first(v)
    return _pyconvert2_convert(T, v)::T
end
