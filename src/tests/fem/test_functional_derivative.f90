program test_functional_derivative

! Test for 4 Gaussian charges (based off of test_free_energy4.f90) and a
! functional derivative propagation.

use types, only: dp
use ofdft_fe, only: free_energy2, fe_data, initialize_fe, &
    free_energy2_low_level, free_energy, free_energy_min_low_level
use constants, only: Ha2eV, pi, i_
use utils, only: loadtxt, assert, linspace, zeros
use splines, only: spline3pars, iixmin, poly3
use isolve, only: solve_cg
use interp3d, only: trilinear
use feutils, only: quad_lobatto
use md, only: positions_fcc
use converged_energies, only: one_gaussian, four_gaussians_min
use poisson3d_assembly, only: func2quad, integral, assemble_3d_coo_rhs, &
    assemble_3d_coo_rhs_spectral
use fe_mesh, only: c2fullc_3d, fe2quad_3d, fe2quad_3d_lobatto
implicit none
real(dp) :: Eee, Een, Ts, Exc, Etot, Etot_conv
integer :: p, DOF, Nq
real(dp) :: Rcut, L, T_eV, T_au
integer, parameter :: natom = 4  ! Set this to 1 or 4
real(dp) :: X(3, natom)
integer :: Nex, Ney, Nez

real(dp), allocatable, dimension(:, :, :, :) :: nenq_pos, nq_pos
type(fe_data) :: fed

real(dp), allocatable, dimension(:, :, :, :) :: Hn, &
    psi, Venq, &
    nenq_neutral
complex(dp), allocatable, dimension(:, :, :, :) :: cpsi, cpsi2, cpsi3
real(dp) :: dt
integer :: max_iter
real(dp) :: brent_eps, free_energy_
real(dp) :: psi_norm
real(dp) :: background
real(dp), allocatable :: rhs(:), sol(:), fullsol(:), fullsol2(:)
real(dp) :: Nelec
integer :: i
real(dp) :: conv_energies(4)
real(dp) :: mu

Rcut = 0.3_dp
p = 6
Nex = 4
Ney = 4
Nez = 4
L = 2
T_eV = 0.0862_dp
T_au = T_ev / Ha2eV
Nq = 7
if (natom == 1) then
    X(:, 1) = [L/2 + L/64, L/2, L/2]
    conv_energies = one_gaussian ! These are not minimized
else
    call positions_fcc(X, L)
    conv_energies = four_gaussians_min
end if
call initialize_fe(L, Nex, Ney, Nez, p, Nq, quad_lobatto, fed)

allocate(nenq_pos(fed%Nq, fed%Nq, fed%Nq, fed%Ne))
allocate(nq_pos(fed%Nq, fed%Nq, fed%Nq, fed%Ne))
nenq_pos = func2quad(fed%nodes, fed%elems, fed%xiq, nen)
nq_pos = func2quad(fed%nodes, fed%elems, fed%xiq, fne)

Nelec = real(natom, dp)

brent_eps = 1e-3_dp
max_iter = 200

allocate(nenq_neutral(fed%Nq, fed%Nq, fed%Nq, fed%Ne))
allocate(Venq(fed%Nq, fed%Nq, fed%Nq, fed%Ne))
allocate(Hn(fed%Nq, fed%Nq, fed%Nq, fed%Ne))
allocate(psi(fed%Nq, fed%Nq, fed%Nq, fed%Ne))
allocate(cpsi(fed%Nq, fed%Nq, fed%Nq, fed%Ne))
allocate(cpsi2(fed%Nq, fed%Nq, fed%Nq, fed%Ne))
allocate(cpsi3(fed%Nq, fed%Nq, fed%Nq, fed%Ne))


! Calculate Venq
allocate(rhs(fed%Nb), sol(fed%Nb), fullsol(maxval(fed%in)))
allocate(fullsol2(maxval(fed%in)))
background = integral(fed%nodes, fed%elems, fed%wtq3, nenq_pos) / &
    (fed%Lx*fed%Ly*fed%Lz)
print *, "Total (negative) ionic charge: ", background * (fed%Lx*fed%Ly*fed%Lz)
print *, "Subtracting constant background (Q/V): ", background
nenq_neutral = nenq_pos - background
print *, "Assembling RHS..."
if (fed%spectral) then
    call assemble_3d_coo_rhs_spectral(fed%Ne, fed%p, 4*pi*nenq_neutral, &
        fed%jac_det, fed%wtq3, fed%ib, rhs)
else
    call assemble_3d_coo_rhs(fed%Ne, fed%p, 4*pi*nenq_neutral, &
        fed%jac_det, fed%wtq3, fed%ib, fed%phi_v, rhs)
end if
print *, "sum(rhs):    ", sum(rhs)
print *, "integral rhs:", integral(fed%nodes, fed%elems, fed%wtq3, nenq_neutral)
print *, "Solving..."
sol = solve_cg(fed%Ap, fed%Aj, fed%Ax, rhs, zeros(size(rhs)), 1e-12_dp, 800)
print *, "Converting..."
call c2fullc_3d(fed%in, fed%ib, sol, fullsol)
if (fed%spectral) then
    call fe2quad_3d_lobatto(fed%elems, fed%xiq, fed%in, fullsol, Venq)
else
    call fe2quad_3d(fed%elems, fed%xin, fed%xiq, fed%phihq, fed%in, fullsol, Venq)
end if
print *, "Done"


psi = sqrt(nq_pos)
psi_norm = integral(fed%nodes, fed%elems, fed%wtq3, psi**2)
print *, "Initial norm of psi:", psi_norm
psi = sqrt(Nelec / psi_norm) * psi
psi_norm = integral(fed%nodes, fed%elems, fed%wtq3, psi**2)
print *, "norm of psi:", psi_norm

call free_energy_min_low_level(Nelec, T_au, nenq_pos, nq_pos, 1e-12_dp, &
        fed, Eee, Een, Ts, Exc)

psi = sqrt(nq_pos)
psi_norm = integral(fed%nodes, fed%elems, fed%wtq3, psi**2)
print *, "Initial norm of psi:", psi_norm

call free_energy(fed%nodes, fed%elems, fed%in, fed%ib, fed%Nb, fed%Lx, fed%Ly, fed%Lz, fed%xin, fed%xiq, fed%wtq3, T_au, &
    Venq, psi**2, fed%phihq, fed%Ap, fed%Aj, fed%Ax, fed%matd, fed%spectral, &
    fed%phi_v, fed%jac_det, &
    Eee, Een, Ts, Exc, free_energy_, Hn=Hn)

DOF = fed%Nb

Etot = Ts + Een + Eee + Exc
Etot_conv = sum(conv_energies)
print *, "p =", p
print *, "DOF =", DOF
print *, "Rcut =", Rcut
print *, "T_au =", T_au
print *, "Summary of energies [a.u.]:"
print "('    Ts   = ', f14.8)", Ts
print "('    Een  = ', f14.8)", Een
print "('    Eee  = ', f14.8)", Eee
print "('    Exc  = ', f14.8)", Exc
print *, "   ---------------------"
print "('    Etot = ', f14.8, ' a.u. = ', f14.8, ' eV')", Etot, Etot*Ha2eV

print *, "Errors:"
print *, abs(Ts - conv_energies(1))
print *, abs(Een - conv_energies(2))
print *, abs(Eee - conv_energies(3))
print *, abs(Exc - conv_energies(4))
print *, abs(Etot - Etot_conv)
call assert(abs(Ts - conv_energies(1)) < 1e-4_dp)
call assert(abs(Een - conv_energies(2)) < 5e-4_dp)
call assert(abs(Eee - conv_energies(3)) < 5e-5_dp)
call assert(abs(Exc - conv_energies(4)) < 5e-5_dp)
call assert(abs(Etot - Etot_conv) < 1e-4_dp)

mu = sum(Hn)/size(Hn)
print *, "mu = ", mu
print *, "max(abs(H-mu)) = ", maxval(abs(Hn - mu))

print *
print *, "------------------------------------------------------------------"
print *, "Propagation"

! Propagate

cpsi = psi
print *, "E_max =", maxval(abs(Hn)), "; dt <", 1/maxval(abs(Hn))
dt = 1/maxval(abs(Hn)) / 10 ! set dt 10x smaller than the limit
print *, "dt =", dt

! Do first step by hand:
print *, "First step"
cpsi2 = cpsi
cpsi = cpsi2 - i_*dt*Hn*cpsi2

psi = abs(cpsi)
psi_norm = integral(fed%nodes, fed%elems, fed%wtq3, psi**2)
print *, "Initial norm of psi:", psi_norm
cpsi = sqrt(Nelec / psi_norm) * cpsi
psi = abs(cpsi)
psi_norm = integral(fed%nodes, fed%elems, fed%wtq3, psi**2)
print *, "norm of psi:", psi_norm

do i = 1, 10
    print *, "iter =", i
    cpsi3 = cpsi2; cpsi2 = cpsi
    cpsi = cpsi3 - 2*i_*dt*Hn*cpsi2
    psi = abs(cpsi)
    psi_norm = integral(fed%nodes, fed%elems, fed%wtq3, psi**2)
    print *, "norm of psi:", psi_norm

    call free_energy(fed%nodes, fed%elems, fed%in, fed%ib, fed%Nb, fed%Lx, fed%Ly, fed%Lz, fed%xin, fed%xiq, fed%wtq3, T_au, &
        Venq, psi**2, fed%phihq, fed%Ap, fed%Aj, fed%Ax, fed%matd, fed%spectral, &
        fed%phi_v, fed%jac_det, &
        Eee, Een, Ts, Exc, free_energy_, Hn=Hn)
    Etot = Ts + Een + Eee + Exc
    print *, "Summary of energies [a.u.]:"
    print "('    Ts   = ', f14.8)", Ts
    print "('    Een  = ', f14.8)", Een
    print "('    Eee  = ', f14.8)", Eee
    print "('    Exc  = ', f14.8)", Exc
    print *, "   ---------------------"
    print "('    Etot = ', f14.8, ' a.u. = ', f14.8, ' eV')", Etot, Etot*Ha2eV

end do
print *, "Done"

contains

real(dp) function nen(x_, y_, z_) result(n)
real(dp), intent(in) :: x_, y_, z_
real(dp), parameter :: alpha = 6, Z = 1
real(dp) :: r2
integer :: i, a, b, c
n = 0
do i = 1, natom
    do a = -1, 1
    do b = -1, 1
    do c = -1, 1
        r2 = sum(([x_, y_, z_]-X(:, i)+[a, b, c]*L)**2)
        n = n - Z*alpha**3/pi**(3._dp/2)*exp(-alpha**2*r2)
    end do
    end do
    end do
end do
end function

real(dp) function fne(x, y, z) result(n)
real(dp), intent(in) :: x, y, z
n = x+y+z ! Silence a compiler "unused dummy argument" warning
n = natom / L**3
end function

end program
