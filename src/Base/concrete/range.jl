"""
    pyrange([[start], [stop]], [step])

Construct a Python `range`. Unspecified arguments default to `None`.
"""
pyrange(x, y, z) = pybuiltins.range(x, y, z)
pyrange(x, y) = pybuiltins.range(x, y)
pyrange(y) = pybuiltins.range(y)
export pyrange

pyrange_fromrange(x::AbstractRange) = pyrange(first(x), last(x) + sign(step(x)), step(x))

pyisrange(x) = pytypecheck(x, pybuiltins.range)
