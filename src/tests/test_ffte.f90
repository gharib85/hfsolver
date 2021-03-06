program test_ffte
use types, only: dp
use fourier, only: dft, idft, fft, fft_vectorized, fft_pass, fft_pass_inplace, &
        fft_vectorized_inplace, calculate_factors, ifft_pass, fft2_inplace, &
        fft3_inplace, ifft3_inplace
use utils, only: assert, init_random
use ffte, only: ffte_fft3_inplace => fft3_inplace, &
    ffte_ifft3_inplace => ifft3_inplace
use openmp, only: omp_get_wtime
implicit none

complex(dp), allocatable :: x3(:, :, :), x3d(:, :, :)
real(dp) :: tmp
real(dp) :: t1, t2
integer :: l, m, n, i, j, k

allocate(x3(3, 5, 8))
forall(i=1:size(x3, 1), j=1:size(x3, 2), k=1:size(x3, 3))
    x3(i, j, k) = i*j+3*i**2+k*j+k
end forall
call fft3_inplace(x3)
call assert(abs(sum(x3)-720) < 1e-9_dp)

forall(i=1:size(x3, 1), j=1:size(x3, 2), k=1:size(x3, 3))
    x3(i, j, k) = i*j+3*i**2+k*j+k
end forall
call ffte_fft3_inplace(x3)
call assert(abs(sum(x3)-720) < 1e-9_dp)
deallocate(x3)

print *, "fft3 l m n:"
l = 15
m = 16
n = 20
allocate(x3(l, m, n), x3d(l, m, n))
do i = 1, size(x3, 1)
do j = 1, size(x3, 2)
do k = 1, size(x3, 3)
    call random_number(tmp)
    x3(i, j, k) = tmp
end do
end do
end do
x3d = x3
call cpu_time(t1)
call ffte_fft3_inplace(x3d)
call cpu_time(t2)
print *, "time:", (t2-t1)*1000, "ms"
call cpu_time(t1)
call ifft3_inplace(x3d)
call cpu_time(t2)
print *, "time:", (t2-t1)*1000, "ms"
call assert(all(abs(x3 - x3d/(l*m*n)) < 5e-15_dp))
x3d = x3
call cpu_time(t1)
call fft3_inplace(x3d)
call cpu_time(t2)
print *, "time:", (t2-t1)*1000, "ms"
call cpu_time(t1)
call ffte_ifft3_inplace(x3d)
call cpu_time(t2)
print *, "time:", (t2-t1)*1000, "ms"
call assert(all(abs(x3 - x3d/(l*m*n)) < 5e-15_dp))
deallocate(x3, x3d)

print *, "fft3:"
n = 16
allocate(x3(n, n, n), x3d(n, n, n))
do k = 1, size(x3, 3)
do j = 1, size(x3, 2)
do i = 1, size(x3, 1)
    call random_number(tmp)
    x3(i, j, k) = tmp
end do
end do
end do
x3d = x3
t1 = omp_get_wtime()
call ffte_fft3_inplace(x3d)
t2 = omp_get_wtime()
print *, "time:", (t2-t1)*1000, "ms"
t1 = omp_get_wtime()
call ifft3_inplace(x3d)
t2 = omp_get_wtime()
print *, "time:", (t2-t1)*1000, "ms"
call assert(all(abs(x3 - x3d/n**3) < 5e-15_dp))
x3d = x3
t1 = omp_get_wtime()
call fft3_inplace(x3d)
t2 = omp_get_wtime()
print *, "time:", (t2-t1)*1000, "ms"
t1 = omp_get_wtime()
call ffte_ifft3_inplace(x3d)
t2 = omp_get_wtime()
print *, "time:", (t2-t1)*1000, "ms"
call assert(all(abs(x3 - x3d/n**3) < 5e-15_dp))
deallocate(x3, x3d)

end program
