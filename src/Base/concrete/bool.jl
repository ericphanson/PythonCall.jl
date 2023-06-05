"""
    pybool(x)

Convert `x` to a Python `bool`.
"""
pybool(x::Bool=false) = pynew(x ? pybuiltins.True : pybuiltins.False)
pybool(x::Number) = pybool(!iszero(x))
pybool(x) = pybuiltins.bool(x)
export pybool

pyisTrue(x) = pyis(x, pybuiltins.True)
pyisFalse(x) = pyis(x, pybuiltins.False)
pyisbool(x) = pyisTrue(x) || pyisFalse(x)

pybool_asbool(x) =
    @autopy x if pyisTrue(x_)
        true
    elseif pyisFalse(x_)
        false
    else
        error("not a bool")
    end
