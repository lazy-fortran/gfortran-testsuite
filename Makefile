# Makefile for gfortran test suite
#
# Usage:
#   make test                    # Run full test suite with system gfortran
#   make test-custom FC=/path/to/gfortran  # Test specific compiler
#   make test-quick              # Run subset of tests
#   make summary                 # Show test summary
#   make clean                   # Clean test artifacts

SHELL := /bin/bash

# Parallelism: use all available cores by default
NPROC := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
RUNTESTFLAGS ?=

# Compiler to test (default: system gfortran)
FC ?= gfortran
GCC ?= gcc

# Test directories
TESTSUITE_DIR := testsuite
LIBGOMP_DIR := libgomp/testsuite

# DejaGnu settings
DEJAGNU_OPTS := --tool gfortran
DEJAGNU_PARALLEL := -j$(NPROC)

.PHONY: all test test-custom test-quick test-torture test-gomp summary clean help

all: help

help:
	@echo "GFortran Test Suite"
	@echo ""
	@echo "Usage:"
	@echo "  make test                     Run full test suite (parallel, $(NPROC) cores)"
	@echo "  make test FC=/path/to/gfortran   Test specific compiler"
	@echo "  make test-quick               Run quick subset of tests"
	@echo "  make test-torture             Run torture tests only"
	@echo "  make test-gomp                Run OpenMP tests only"
	@echo "  make summary                  Show test summary after run"
	@echo "  make clean                    Clean test artifacts"
	@echo ""
	@echo "Environment variables:"
	@echo "  FC                Fortran compiler to test (default: gfortran)"
	@echo "  GCC               C compiler for mixed tests (default: gcc)"
	@echo "  NPROC             Number of parallel jobs (default: $(NPROC))"
	@echo "  RUNTESTFLAGS      Additional runtest flags"
	@echo ""
	@echo "Examples:"
	@echo "  make test"
	@echo "  make test FC=/usr/local/bin/gfortran-14"
	@echo "  make test RUNTESTFLAGS='dg.exp=finalize*.f90'"

test: test-dg

test-dg:
	@echo "Running gfortran.dg tests with $(FC) ($(NPROC) parallel jobs)..."
	cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" \
	GCC_UNDER_TEST="$(GCC)" \
	runtest $(DEJAGNU_OPTS) $(DEJAGNU_PARALLEL) \
		gfortran.dg/dg.exp $(RUNTESTFLAGS)

test-quick:
	@echo "Running quick test subset with $(FC)..."
	cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" \
	GCC_UNDER_TEST="$(GCC)" \
	runtest $(DEJAGNU_OPTS) $(DEJAGNU_PARALLEL) \
		gfortran.dg/dg.exp=array_*.f90 $(RUNTESTFLAGS)

test-torture:
	@echo "Running torture tests with $(FC)..."
	cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" \
	GCC_UNDER_TEST="$(GCC)" \
	runtest $(DEJAGNU_OPTS) $(DEJAGNU_PARALLEL) \
		gfortran.fortran-torture/torture.exp $(RUNTESTFLAGS)

test-gomp:
	@echo "Running OpenMP Fortran tests with $(FC)..."
	cd $(LIBGOMP_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" \
	GCC_UNDER_TEST="$(GCC)" \
	runtest --tool libgomp $(DEJAGNU_PARALLEL) \
		libgomp.fortran/fortran.exp $(RUNTESTFLAGS)

test-all: test-dg test-torture test-gomp
	@echo "All test suites completed."

summary:
	@echo ""
	@echo "=== Test Summary ==="
	@if [ -f $(TESTSUITE_DIR)/gfortran.sum ]; then \
		grep -E "^(PASS|FAIL|XPASS|XFAIL|UNSUPPORTED|UNTESTED|ERROR):" \
			$(TESTSUITE_DIR)/gfortran.sum | \
			sed 's/:.*/:/' | sort | uniq -c | sort -rn; \
		echo ""; \
		grep "^# of" $(TESTSUITE_DIR)/gfortran.sum; \
	else \
		echo "No test results found. Run 'make test' first."; \
	fi

clean:
	rm -f $(TESTSUITE_DIR)/*.sum $(TESTSUITE_DIR)/*.log
	rm -f $(TESTSUITE_DIR)/gfortran.sum $(TESTSUITE_DIR)/gfortran.log
	rm -f $(LIBGOMP_DIR)/*.sum $(LIBGOMP_DIR)/*.log
	rm -rf $(TESTSUITE_DIR)/tmp* $(LIBGOMP_DIR)/tmp*
	find . -name "*.mod" -delete
	find . -name "*.o" -delete
	find . -name "*.x" -delete
	@echo "Cleaned test artifacts."
