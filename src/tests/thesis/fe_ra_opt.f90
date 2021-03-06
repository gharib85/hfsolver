program fe_ra_opt

use types, only: dp
use sto, only: stoints2, get_basis2
use utils, only: assert
use radialscf, only: doscf, kinetic_energy
use hfprint, only: printall, printlam
use mesh, only: meshexp
use feutils, only: define_connect, get_quad_pts, get_parent_quad_pts_wts, &
        get_parent_nodes
use fe, only: feints
implicit none

integer, allocatable :: nbfl(:)
real(dp), allocatable :: focc(:, :)

real(dp), allocatable :: S(:, :, :), T(:, :, :), V(:, :, :), slater(:, :)
integer :: n, Z, m, Nscf, Lmax, ndof
real(dp) :: alpha, Etot, tolE, tolP, Ekin
real(dp), allocatable :: H(:, :, :), P_(:, :, :), C(:, :, :), lam(:, :)

real(dp), allocatable :: xin(:)       ! parent basis nodes
real(dp), allocatable :: xe(:)        ! element coordinates
integer, allocatable :: ib(:, :)       ! basis connectivity: ib(i,j) = index of
   ! basis function associated with local basis function i of element j. 0 = no
   ! associated basis fn.
integer, allocatable :: in(:, :)
real(dp), allocatable :: xiq(:)       ! quadrature points
real(dp), allocatable :: wtq(:)       ! quadrature weights
real(dp), allocatable :: xq(:, :)
integer :: p, Ne, Nb, Nq
real(dp) :: rmin, rmax, a
integer :: l, u, i

Lmax = 3
allocate(nbfl(0:Lmax), focc(7, 0:Lmax))
nbfl = 0
focc = 0
focc(:7, 0) = [2, 2, 2, 2, 2, 2, 2]
focc(:5, 1) = [6, 6, 6, 6, 6]
focc(:3, 2) = [10, 10, 10]
focc(:1, 3) = [14]

Z = 88
tolE = 1e-9_dp
tolP = 1e-4_dp
alpha = 0.6_dp
Nscf = 100


rmin = 0
rmax = 30
a = 200
Ne = 4
Nq = 53
p = 13

allocate(xe(Ne+1))

open(newunit=u, file="Etot.txt", status="replace")
close(u)

do i = 1, 10
    a = 200 + i*(400-200)/10._dp
    xe = meshexp(rmin, rmax, a, Ne)

    allocate(xin(p+1))
    call get_parent_nodes(2, p, xin)
    allocate(in(p+1, Ne), ib(p+1, Ne))
    call define_connect(1, 1, Ne, p, in, ib)
    Nb = maxval(ib)
    do l = 0, Lmax
        nbfl(l) = Nb
    end do
    print *, "radial DOFs =", Nb
    allocate(xiq(Nq), wtq(Nq), xq(Nq, Ne))
    call get_parent_quad_pts_wts(1, Nq, xiq, wtq)
    call get_quad_pts(xe, xiq, xq)


    n = maxval(nbfl)
    ndof = sum(nbfl)
    print *, "total  DOFs =", ndof
    allocate(S(n, n, 0:Lmax), T(n, n, 0:Lmax), V(n, n, 0:Lmax))
    m = n*(n+1)/2
    allocate(slater(m*(m+1)/2, 0:2*Lmax))
    call feints(Z, xin, xe, ib, xiq, wtq, S, T, V, slater)

    allocate(P_(n, n, 0:Lmax), C(n, n, 0:Lmax), lam(n, 0:Lmax))


    H = T + V

    print *, "SCF cycle:"
    call doscf(nbfl, H, slater, S, focc, Nscf, tolE, tolP, alpha, C, P_, lam, &
        Etot, slater_l_indep=.true., precalcTT=.true.)
    Ekin = kinetic_energy(nbfl, P_, T)
    call printlam(nbfl, lam, Ekin, Etot)

    open(newunit=u, file="Etot.txt", position="append", status="old")
    write(u, "(i4, ' ', i5, ' ', f7.1, ' ', es23.16, ' ', es10.2)") p, ndof, &
        a, Etot, abs(Etot - (-23094.30366642482_dp))
    close(u)

    deallocate(xin, in, ib, xiq, wtq, xq, S, T, V, slater, P_, C, lam)
end do

end program
