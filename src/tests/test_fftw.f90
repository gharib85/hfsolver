program test_fftw
use iso_c_binding, only: c_ptr, c_f_pointer, c_size_t, c_loc
use types, only: dp
use constants, only: i_
use fftw, only: fftw_plan_dft_1d, fftw_plan_dft_3d, FFTW_FORWARD, &
    FFTW_ESTIMATE, fftw_execute_dft, fftw_destroy_plan, fftw_alloc_complex, &
    fftw_free, FFTW_MEASURE
implicit none

type(c_ptr) :: plan
complex(dp), dimension(4, 8, 16) :: y3, ydft3
integer :: n
complex(dp), pointer :: px(:), pxdft(:), px3(:, :, :), pxdft3(:, :, :)
real(dp) :: t1, t2, t3

! This works, but is slow due to y,ydft not being aligned to exploit SIMD
! The dimensions (4, 8, 16) must be reversed:
plan = fftw_plan_dft_3d(16, 8, 4, y3, ydft3, FFTW_FORWARD, FFTW_ESTIMATE)
call fftw_execute_dft(plan, y3, ydft3)
call fftw_destroy_plan(plan)

n = 1024**2

! This is fast
print *, "1D FFT of size n=", n, "with FFTW allocation"
px => alloc1d(n)
pxdft => alloc1d(n)
call cpu_time(t1)
!plan = fftw_plan_dft_1d(n, px, pxdft, FFTW_FORWARD, FFTW_ESTIMATE)
plan = fftw_plan_dft_1d(n, px, pxdft, FFTW_FORWARD, FFTW_MEASURE)
call cpu_time(t2)
call fftw_execute_dft(plan, px, pxdft)
call cpu_time(t3)
print *, "Total time:", (t3-t1)*1000, "ms"
print *, "init:      ", (t2-t1)*1000, "ms"
print *, "calc:      ", (t3-t2)*1000, "ms"
call fftw_destroy_plan(plan)
call free(px)
call free(pxdft)

n = 256

! This is fast
print *, "1D FFT of size n=", n, "^3  with FFTW allocation"
px3 => alloc3d(n, n, n)
pxdft3 => alloc3d(n, n, n)
call cpu_time(t1)
plan = fftw_plan_dft_3d(n, n, n, px3, pxdft3, FFTW_FORWARD, FFTW_MEASURE)
call cpu_time(t2)
call fftw_execute_dft(plan, px3, pxdft3)
call cpu_time(t3)
print *, "Total time:", (t3-t1)*1000, "ms"
print *, "init:      ", (t2-t1)*1000, "ms"
print *, "calc:      ", (t3-t2)*1000, "ms"
call fftw_destroy_plan(plan)
call free(px3)
call free(pxdft3)

contains

    function alloc1d(n1) result(x)
    integer, intent(in) :: n1
    complex(dp), pointer :: x(:)
    type(c_ptr) :: p
    p = fftw_alloc_complex(int(n1, c_size_t))
    call c_f_pointer(p, x, [n1])
    end function

    function alloc3d(n1, n2, n3) result(x)
    integer, intent(in) :: n1, n2, n3
    complex(dp), pointer :: x(:, :, :)
    type(c_ptr) :: p
    p = fftw_alloc_complex(int(n1*n2*n3, c_size_t))
    call c_f_pointer(p, x, [n1, n2, n3])
    end function

    subroutine free(x)
    complex(dp), intent(in), target :: x(*)
    call fftw_free(c_loc(x))
    end subroutine

end program