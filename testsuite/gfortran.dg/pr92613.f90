# 1 "<test>"
# 1 "<built-in>"
# 1 "<command-line>"
# 1 "<test>"
! PR fortran/92613
! Test that quotes in comments do not cause bogus warnings
! when compiling preprocessed Fortran with -cpp -fpreprocessed.
! { dg-do compile }
! { dg-options "-cpp -fpreprocessed" }
program test
  implicit none
  write(6,*) 'hello'
! it's good! { dg-bogus "missing terminating" }
! This comment has a "quote" too { dg-bogus "missing terminating" }
end program
