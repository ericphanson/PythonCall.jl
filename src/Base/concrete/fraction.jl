const pyfractiontype = pynew()

function init_fraction()
    m = pyimport("fractions")
    pycopy!(pyfractiontype, m.Fraction)
end

pyfraction(x::Rational) = pyfraction(numerator(x), denominator(x))
pyfraction(x, y) = pyfractiontype(x, y)
pyfraction(x) = pyfractiontype(x)
pyfraction() = pyfractiontype()
export pyfraction
