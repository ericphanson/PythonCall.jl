# :PyFloat_FromDouble => (Cdouble,) => PyPtr,
# :PyFloat_AsDouble => (PyPtr,) => Cdouble,

"""
    pyfloat(x=0.0)

Convert `x` to a Python `float`.
"""
pyfloat(x::Real=0.0) = pynew(errcheck(C.PyFloat_FromDouble(x)))
pyfloat(x) = @autopy x pynew(errcheck(C.PyNumber_Float(getptr(x_))))
export pyfloat

pyisfloat(x) = pytypecheck(x, pybuiltins.float)

pyfloat_asdouble(x) = errcheck_ambig(@autopy x C.PyFloat_AsDouble(getptr(x_)))
