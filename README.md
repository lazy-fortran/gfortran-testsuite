# GFortran Test Suite

[![CI](https://github.com/lazy-fortran/gfortran-testsuite/actions/workflows/ci.yml/badge.svg)](https://github.com/lazy-fortran/gfortran-testsuite/actions/workflows/ci.yml)

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
- **contrib/** - GCC test utilities (test_summary, dg-extract-results)

## Requirements

- DejaGnu (runtest command)
- A gfortran-compatible compiler
- Tcl/Expect (for DejaGnu)
- GNU Make

On Arch Linux:
```bash
sudo pacman -S dejagnu tcl expect
```

On Ubuntu/Debian:
```bash
sudo apt install dejagnu tcl expect
```

## Running Tests

### Parallel Test Execution

Run the full test suite using all CPU cores (uses GCC's native parallelization):

```bash
make test
```

Specify number of parallel workers:

```bash
make test JOBS=32
```

### Testing a GCC Build Tree

When testing a locally built GCC (not installed), use the `GCC_BUILD` variable
which automatically adds the required `-B` flag:

```bash
make test GCC_BUILD=/path/to/gcc-build JOBS=32
```

### Testing a Specific Installed Compiler

```bash
make test FC=/usr/bin/gfortran-14
```

### Quick Tests

Run a small subset of tests for quick verification:

```bash
make test-quick
```

### Other Test Targets

```bash
make test-torture   # Run torture tests
make test-gomp      # Run OpenMP tests
make test-all       # Run all test suites
make summary        # Show test results summary
make clean          # Clean test artifacts
```

## Parallelization

This test suite uses GCC's native `GCC_RUNTEST_PARALLELIZE_DIR` mechanism for
parallel test execution. Multiple runtest instances coordinate through a shared
directory to dynamically distribute tests, ensuring optimal load balancing
regardless of the number of workers.

Results from parallel workers are merged using GCC's `dg-extract-results.sh`
script.

## CI/CD

This repository includes GitHub Actions CI that:

1. **Tests with system gfortran** - Quick validation on every push
2. **Builds GCC and tests** - Weekly builds GCC from tracked commit and runs the full test suite

See [.github/workflows/ci.yml](.github/workflows/ci.yml) for details.

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
3. Syncs DejaGnu infrastructure and contrib scripts
4. Updates `.gcc-commit` tracking file
5. Optionally creates a commit with the GCC commit reference

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
