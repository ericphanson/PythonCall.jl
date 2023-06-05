function pyconvert_rule_bool(::Type{T}, x::Py) where {T<:Number}
    val = pybool_asbool(x)
    if T in (Bool, Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128, BigInt)
        pyconvert_return(T(val))
    else
        pyconvert_tryconvert(T, val)
    end
end

pyconvert_rule_bytes(::Type{Vector{UInt8}}, x::Py) = pyconvert_return(copy(pybytes_asvector(x)))
pyconvert_rule_bytes(::Type{Base.CodeUnits{UInt8,String}}, x::Py) = pyconvert_return(codeunits(pybytes_asUTF8string(x)))

function pyconvert_rule_complex(::Type{T}, x::Py) where {T<:Number}
    val = pycomplex_ascomplex(x)
    if T in (Complex{Float64}, Complex{Float32}, Complex{Float16}, Complex{BigFloat})
        pyconvert_return(T(val))
    else
        pyconvert_tryconvert(T, val)
    end
end

function pyconvert_rule_float(::Type{T}, x::Py) where {T<:Number}
    val = pyfloat_asdouble(x)
    if T in (Float16, Float32, Float64, BigFloat)
        pyconvert_return(T(val))
    else
        pyconvert_tryconvert(T, val)
    end
end

# NaN is sometimes used to represent missing data of other types
# so we allow converting it to Nothing or Missing
function pyconvert_rule_float(::Type{Nothing}, x::Py)
    val = pyfloat_asdouble(x)
    if isnan(val)
        pyconvert_return(nothing)
    else
        pyconvert_unconverted()
    end
end

function pyconvert_rule_float(::Type{Missing}, x::Py)
    val = pyfloat_asdouble(x)
    if isnan(val)
        pyconvert_return(missing)
    else
        pyconvert_unconverted()
    end
end

pyconvert_rule_int(::Type{T}, x::Py) where {T<:Number} = begin
    # first try to convert to Clonglong (or Culonglong if unsigned)
    v = T <: Unsigned ? C.PyLong_AsUnsignedLongLong(getptr(x)) : C.PyLong_AsLongLong(getptr(x))
    if !iserrset_ambig(v)
        # success
        return pyconvert_tryconvert(T, v)
    elseif errmatches(pybuiltins.OverflowError)
        # overflows Clonglong or Culonglong
        errclear()
        if T in (
               Bool,
               Int8,
               Int16,
               Int32,
               Int64,
               Int128,
               UInt8,
               UInt16,
               UInt32,
               UInt64,
               UInt128,
           ) &&
           typemin(typeof(v)) ≤ typemin(T) &&
           typemax(T) ≤ typemax(typeof(v))
            # definitely overflows S, give up now
            return pyconvert_unconverted()
        else
            # try converting -> int -> str -> BigInt -> T
            x_int = pyint(x)
            x_str = pystr(String, x_int)
            pydel!(x_int)
            v = parse(BigInt, x_str)
            return pyconvert_tryconvert(T, v)
        end
    else
        # other error
        pythrow()
    end
end

pyconvert_rule_none(::Type{Nothing}, x::Py) = pyconvert_return(nothing)
pyconvert_rule_none(::Type{Missing}, x::Py) = pyconvert_return(missing)

function pyconvert_rule_range(::Type{R}, x::Py, ::Type{StepRange{T0,S0}}=Utils._type_lb(R), ::Type{StepRange{T1,S1}}=Utils._type_ub(R)) where {R<:StepRange,T0,S0,T1,S1}
    a = @pyconvert(Utils._typeintersect(Integer, T1), x.start)
    b = @pyconvert(Utils._typeintersect(Integer, S1), x.step)
    c = @pyconvert(Utils._typeintersect(Integer, T1), x.stop)
    a′, c′ = promote(a, c - oftype(c, sign(b)))
    T2 = Utils._promote_type_bounded(T0, typeof(a′), typeof(c′), T1)
    S2 = Utils._promote_type_bounded(S0, typeof(c′), S1)
    pyconvert_return(StepRange{T2, S2}(a′, b, c′))
end

function pyconvert_rule_range(::Type{R}, x::Py, ::Type{UnitRange{T0}}=Utils._type_lb(R), ::Type{UnitRange{T1}}=Utils._type_ub(R)) where {R<:UnitRange,T0,T1}
    b = @pyconvert(Int, x.step)
    b == 1 || return pyconvert_unconverted()
    a = @pyconvert(Utils._typeintersect(Integer, T1), x.start)
    c = @pyconvert(Utils._typeintersect(Integer, T1), x.stop)
    a′, c′ = promote(a, c - oftype(c, 1))
    T2 = Utils._promote_type_bounded(T0, typeof(a′), typeof(c′), T1)
    pyconvert_return(UnitRange{T2}(a′, c′))
end

pyconvert_rule_str(::Type{String}, x::Py) = pyconvert_return(pystr_asstring(x))
pyconvert_rule_str(::Type{Symbol}, x::Py) = pyconvert_return(Symbol(pystr_asstring(x)))
pyconvert_rule_str(::Type{Char}, x::Py) = begin
    s = pystr_asstring(x)
    if length(s) == 1
        pyconvert_return(first(s))
    else
        pyconvert_unconverted()
    end
end

function pyconvert_rule_date(::Type{Date}, x::Py)
    # datetime is a subtype of date, but we shouldn't convert datetime to Date since it's lossy
    pyisinstance(x, pydatetimetype) && return pyconvert_unconverted()
    year = pyconvert(Int, x.year)
    month = pyconvert(Int, x.month)
    day = pyconvert(Int, x.day)
    pyconvert_return(Date(year, month, day))
end

function pyconvert_rule_time(::Type{Time}, x::Py)
    pytime_isaware(x) && return pyconvert_unconverted()
    hour = pyconvert(Int, x.hour)
    minute = pyconvert(Int, x.minute)
    second = pyconvert(Int, x.second)
    microsecond = pyconvert(Int, x.microsecond)
    return pyconvert_return(Time(hour, minute, second, div(microsecond, 1000), mod(microsecond, 1000)))
end

function pyconvert_rule_datetime(::Type{DateTime}, x::Py)
    pydatetime_isaware(x) && return pyconvert_unconverted()
    # compute the time since _base_datetime
    # this accounts for fold
    d = x - _base_pydatetime
    days = pyconvert(Int, d.days)
    seconds = pyconvert(Int, d.seconds)
    microseconds = pyconvert(Int, d.microseconds)
    pydel!(d)
    iszero(mod(microseconds, 1000)) || return pyconvert_unconverted()
    return pyconvert_return(_base_datetime + Millisecond(div(microseconds, 1000) + 1000 * (seconds + 60 * 60 * 24 * days)))
end

# works for any collections.abc.Rational
function pyconvert_rule_fraction(::Type{R}, x::Py, ::Type{Rational{T0}}=Utils._type_lb(R), ::Type{Rational{T1}}=Utils._type_ub(R)) where {R<:Rational,T0,T1}
    a = @pyconvert(Utils._typeintersect(Integer, T1), x.numerator)
    b = @pyconvert(Utils._typeintersect(Integer, T1), x.denominator)
    a, b = promote(a, b)
    T2 = Utils._promote_type_bounded(T0, typeof(a), typeof(b), T1)
    pyconvert_return(Rational{T2}(a, b))
end

# works for any collections.abc.Rational
function pyconvert_rule_fraction(::Type{T}, x::Py) where {T<:Number}
    pyconvert_tryconvert(T, @pyconvert(Rational{<:Integer}, x))
end

pyconvert_rule_exception(::Type{R}, x::Py) where {R<:PyException} = pyconvert_return(PyException(x))

pyconvert_rule_object(::Type{Py}, x::Py) = pyconvert_return(x)
