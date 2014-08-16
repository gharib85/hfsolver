module md
use types, only: dp
use utils, only: stop_error, assert
implicit none
private
public velocity_verlet, minimize_energy, unfold_positions, &
    calc_min_distance, positions_random, positions_fcc

interface
    subroutine forces_func(X, f)
    ! Calculate forces for particles at positions X
    import :: dp
    implicit none
    ! (i, j) is the i-th particle, j-component (j=1, 2, 3)
    real(dp), intent(in) :: X(:, :) ! positions
    real(dp), intent(out) :: f(:, :) ! forces
    end subroutine

    real(dp) function energy_func(X)
    ! Calculate the energy for particles at positions X
    import :: dp
    implicit none
    ! (i, j) is the i-th particle, j-component (j=1, 2, 3)
    real(dp), intent(in) :: X(:, :) ! positions
    end function
end interface

contains

subroutine velocity_verlet(dt, m, forces, f, V, X)
! Propagates f, V, X: t -> t+dt
! On input, f, V, X are given at time t, on output they are given at time t+dt.
! X(i, j) is i-th particle, j comp. (j=1, 2, 3)
real(dp), intent(in) :: dt ! time step
real(dp), intent(in) :: m(:) ! m(i) the mass of i-th particle
! Callback that calculates forces from positions
procedure(forces_func) :: forces
real(dp), intent(inout) :: f(:, :) ! f(t) -> f(t+dt)
real(dp), intent(inout) :: V(:, :) ! V(t) -> V(t+dt)
real(dp), intent(inout) :: X(:, :) ! X(t) -> X(t+dt)
real(dp) :: f_next(3, size(f, 2))
X = X + V*dt + f*dt**2/(2*spread(m, 1, 3))
call forces(X, f_next)
V = V + (f + f_next)*dt/(2*spread(m, 1, 3))
f = f_next
end subroutine

subroutine minimize_energy(forces, energy, X, f, h0, max_iter)
! Callback that calculates forces from positions
procedure(forces_func) :: forces
procedure(energy_func) :: energy
real(dp), intent(inout) :: X(:, :)
real(dp), intent(out) :: f(:, :) ! The final force 'f'
real(dp), intent(in) :: h0
integer, intent(in) :: max_iter
real(dp) :: h, E, Enew, Xnew(3, size(X, 2))
integer :: i
call forces(X, f)
h = h0
E = energy(X)
call forces(X, f)
do i = 1, max_iter
    print *, i, E, h
    Xnew = X + f/maxval(sqrt(sum(f**2, dim=1))) * h
    Enew = energy(Xnew)
    if (Enew < E) then
        ! new positions are accepted
        X = Xnew
        E = Enew
        call forces(X, f)
        h = 1.2_dp * h
    else
        ! new positions are rejected
        h = 0.2_dp * h
    end if
end do
end subroutine

subroutine unfold_positions(L, X, Xu)
! Unwinds periodic positions. It is using the positions of particles from the
! first time step as a reference and then tracks them as they evolve possibly
! outside of this box. The X and Xu arrays are of the type X(:, j, i), which
! are the (x,y,z) coordinates of the j-th particle in the i-th time step.
real(dp), intent(in) :: L ! Box length
! Positions in [0, L]^3 with possible jumps:
real(dp), intent(in) :: X(:, :, :)
! Unwinded positions in (-oo, oo)^3 with no jumps (continuous):
real(dp), intent(out) :: Xu(:, :, :)
real(dp) :: d(3), Xj(3)
integer :: i, j
Xu(:, :, 1) = X(:, :, 1)
do i = 2, size(X, 3)
    do j = 1, size(X, 2)
        Xj = X(:, j, i-1) - X(:, j, i) + [L/2, L/2, L/2]
        Xj = Xj - L*floor(Xj/L)
        d = [L/2, L/2, L/2] - Xj
        Xu(:, j, i) = Xu(:, j, i-1) + d
    end do
end do
end subroutine

real(dp) function calc_min_distance(X, L, X0) result(dmin)
! Calculates the minimum distance between X0 and all the points in X
real(dp), intent(in) :: X(:, :) ! positions
real(dp), intent(in) :: L ! length of the box
real(dp), intent(in) :: X0(:) ! position to calculate the nearest distance
real(dp) :: r, d(3), Xi(3)
integer :: N, i
N = size(X, 2)
! Just something larger than any length in the box:
dmin = L * sqrt(3._dp) + 1
do i = 1, N
    Xi = X(:, i)-X0+[L/2, L/2, L/2]
    Xi = Xi - L*floor(Xi/L)
    d = [L/2, L/2, L/2] - Xi
    r = sqrt(sum(d**2))
    if (r < dmin) dmin = r
end do
end function

subroutine positions_random(X, L, min_distance, max_iter)
! Initializes X with random positions of nuclei, such that the minimum distance
! between any two is at least 'min_distance'. If the random position fails to
! satisfy this criteria 'max_iter' times, it stops with an error.
real(dp), intent(out) :: X(:, :)
real(dp), intent(in) :: L, min_distance
integer, intent(in) :: max_iter
integer :: N, i, j
N = size(X, 2)
do i = 1, N
    call random_number(X(:, i))
    X(:, i) = L*X(:, i)
    if (i > 1) then
        j = 0
        do while (calc_min_distance(X(:, :i-1), L, X(:, i)) < min_distance)
            j = j + 1
            if (j > max_iter) then
                call stop_error("Cannot find position for new nucleus.")
            end if
            call random_number(X(:, i))
            X(:, i) = L*X(:, i)
        end do
    end if
end do
end subroutine

subroutine positions_fcc(X, L)
! Initializes X with FCC positions of nuclei. If the number of atoms does not
! fit the FCC lattice, it stops with an error.
real(dp), intent(out) :: X(:, :)
real(dp), intent(in) :: L
real(dp) :: atoms(3, 4), a
integer :: N, i, j, k, m, idx
N = nint(L / (4*L**3/size(X, 2))**(1._dp/3))
if (4*N**3 /= size(X, 2)) call stop_error("Lattice does not match atom count")
a = L / N
atoms(:, 1) = 0
atoms(:, 2) = [0._dp, 0.5_dp, 0.5_dp]
atoms(:, 3) = [0.5_dp, 0._dp, 0.5_dp]
atoms(:, 4) = [0.5_dp, 0.5_dp, 0._dp]
idx = 0
do i = 1, N
do j = 1, N
do k = 1, N
    do m = 1, 4
        idx = idx + 1
        print *, i, j, k, m, idx
        X(:, idx) = a * (atoms(:, m)+[i, j, k]-0.75_dp)
    end do
end do
end do
end do
call assert(idx == size(X, 2))
end subroutine

end module