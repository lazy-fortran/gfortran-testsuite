# GFortran Test Suite

A standalone extraction of the GNU Fortran (gfortran) test suite from GCC,
enabling testing of any gfortran-compatible compiler without building GCC.

## Contents

This repository contains:

- **testsuite/gfortran.dg/** - Main gfortran DejaGnu test suite (~9000+ tests)
- **testsuite/gfortran.fortran-torture/** - Fortran torture tests
- **testsuite/gfortran.target/** - Target-specific Fortran tests
- **testsuite/gcc.target/powerpc/ppc-fortran/** - PowerPC Fortran tests
- **libgomp/testsuite/libgomp.fortran/** - OpenMP Fortran tests
- **libgomp/testsuite/libgomp.oacc-fortran/** - OpenACC Fortran tests
- **testsuite/lib/** - DejaGnu support libraries

## Requirements

- DejaGnu (runtest command)
- A gfortran-compatible compiler
- Tcl/Expect (for DejaGnu)

On Arch Linux:
```bash
sudo pacman -S dejagnu tcl expect
```

On Ubuntu/Debian:
```bash
sudo apt install dejagnu tcl expect
```

## Running Tests

### Quick Start

To test an installed gfortran:

```bash
cd testsuite
runtest --tool gfortran
```

### Testing a Specific Compiler

Set the `GFORTRAN_UNDER_TEST` environment variable:

```bash
export GFORTRAN_UNDER_TEST=/path/to/custom/gfortran
cd testsuite
runtest --tool gfortran
```

### Running Specific Tests

Run a single test:
```bash
runtest --tool gfortran gfortran.dg/array_1.f90
```

Run tests matching a pattern:
```bash
runtest --tool gfortran gfortran.dg/allocate*.f90
```

### Running OpenMP Tests

For OpenMP tests, you need libgomp available:

```bash
cd libgomp/testsuite
runtest --tool libgomp libgomp.fortran/fortran.exp
```

## Syncing with GCC Upstream

This repository includes a sync script to update from GCC upstream:

```bash
# First time: clones GCC (may take a while)
./sync-from-gcc.sh

# With auto-commit
AUTO_COMMIT=1 ./sync-from-gcc.sh

# Use a specific branch
GCC_BRANCH=releases/gcc-14 ./sync-from-gcc.sh
```

The script:
1. Clones or updates a shallow GCC clone in `.gcc-upstream/`
2. Syncs all Fortran test files preserving directory structure
3. Optionally creates a commit with the GCC commit reference

## Test File Extensions

The test suite includes files with these extensions:
- `.f`, `.f77` - Fixed-form Fortran 77
- `.for` - Fixed-form Fortran
- `.f90` - Free-form Fortran 90
- `.f95` - Free-form Fortran 95
- `.f03` - Free-form Fortran 2003
- `.f08` - Free-form Fortran 2008
- `.f18` - Free-form Fortran 2018
- `.f23` - Free-form Fortran 2023
- `.F`, `.F90`, etc. - Preprocessed Fortran

## DejaGnu Directives

Tests use DejaGnu directives like:
- `! { dg-do compile }` - Compile-only test
- `! { dg-do run }` - Compile and run test
- `! { dg-error "message" }` - Expect an error
- `! { dg-warning "message" }` - Expect a warning
- `! { dg-options "-O2" }` - Additional compiler options

## License

This test suite is derived from GCC and is licensed under the
GNU General Public License v3.0 or later. See [LICENSE](LICENSE).

The original source is available at https://gcc.gnu.org/

## Contributing

To contribute test cases to GCC, please follow the GCC contribution
guidelines at https://gcc.gnu.org/contribute.html

## Related Projects

- [GCC](https://gcc.gnu.org/) - The GNU Compiler Collection
- [lazy-fortran](https://github.com/lazy-fortran) - Modern Fortran tools and libraries
