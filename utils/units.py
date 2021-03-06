# Basic constants in SI units:
e = 1.602176565e-19     # C, 2010 CODATA value
kB = 1.3806488e-23      # J/K, 2010 CODATA value
NA = 6.02214129e23      # mol^-1, 2010 CODATA value
a0 = 5.2917721092e-11   # m, 2010 CODATA value

# Derived conversions:
eV = 1 * e                  # V * C = J/C * C = J
# For temperature, 1 eV/kB in K:
eV2K = eV / kB    # J / (J/K) = K

print "1 eV/kB =", eV2K, "K"
print "1e5 K =", 1e5 / eV2K, "eV"
print "15 keV =", 15e3 * eV2K / 1e6, "MK"

hydrogen_mass = 1.00794 / NA   # 1g/mol
print "Density of 1 hydrogen in 3x3x3 Bohr radius box:", \
        hydrogen_mass / (3*a0)**3  * 1e-6, "g/cm^3"
