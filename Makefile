# Makefile for gfortran test suite
#
# Usage:
#   make -j$(nproc) test           # Run full test suite in parallel
#   make -j$(nproc) test-quick     # Run quick subset
#   make summary                   # Show test summary
#   make clean                     # Clean artifacts
#
# Parallel execution works by splitting tests into shards that run concurrently.

SHELL := /bin/bash

# Compiler to test (default: system gfortran)
FC ?= gfortran
GCC ?= gcc

# Test directories
TESTSUITE_DIR := testsuite
LIBGOMP_DIR := libgomp/testsuite

# Get list of test files for sharding
DG_TESTS := $(wildcard $(TESTSUITE_DIR)/gfortran.dg/*.f90 $(TESTSUITE_DIR)/gfortran.dg/*.f)
DG_TESTS += $(wildcard $(TESTSUITE_DIR)/gfortran.dg/*.f03 $(TESTSUITE_DIR)/gfortran.dg/*.f08)
DG_TESTS += $(wildcard $(TESTSUITE_DIR)/gfortran.dg/*.f95 $(TESTSUITE_DIR)/gfortran.dg/*.F90)

# Create shard targets (split alphabetically into groups)
SHARD_A := $(filter $(TESTSUITE_DIR)/gfortran.dg/[a-d]%, $(DG_TESTS))
SHARD_B := $(filter $(TESTSUITE_DIR)/gfortran.dg/[e-h]%, $(DG_TESTS))
SHARD_C := $(filter $(TESTSUITE_DIR)/gfortran.dg/[i-l]%, $(DG_TESTS))
SHARD_D := $(filter $(TESTSUITE_DIR)/gfortran.dg/[m-p]%, $(DG_TESTS))
SHARD_E := $(filter $(TESTSUITE_DIR)/gfortran.dg/[q-t]%, $(DG_TESTS))
SHARD_F := $(filter $(TESTSUITE_DIR)/gfortran.dg/[u-z]%, $(DG_TESTS))
SHARD_G := $(filter $(TESTSUITE_DIR)/gfortran.dg/[A-Z0-9]%, $(DG_TESTS))

.PHONY: all test test-shard-a test-shard-b test-shard-c test-shard-d \
        test-shard-e test-shard-f test-shard-g \
        test-quick test-torture test-gomp test-all summary clean help

all: help

help:
	@echo "GFortran Test Suite"
	@echo ""
	@echo "Usage:"
	@echo "  make -j\$$(nproc) test        Run full test suite (parallel shards)"
	@echo "  make test FC=/path/to/gfortran  Test specific compiler"
	@echo "  make -j\$$(nproc) test-quick  Run quick subset"
	@echo "  make test-torture            Run torture tests"
	@echo "  make test-gomp               Run OpenMP tests"
	@echo "  make summary                 Show test summary"
	@echo "  make clean                   Clean artifacts"
	@echo ""
	@echo "Environment variables:"
	@echo "  FC     Fortran compiler (default: gfortran)"
	@echo "  GCC    C compiler for mixed tests (default: gcc)"

# Main test target - runs all shards (use make -j for parallelism)
test: test-shard-a test-shard-b test-shard-c test-shard-d test-shard-e test-shard-f test-shard-g
	@echo "All test shards completed."
	@$(MAKE) --no-print-directory summary

# Individual shard targets
test-shard-a:
	@echo "=== Running shard A (a-d) with $(FC) ==="
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.dg/dg.exp='[a-d]*' \
		--outdir $(CURDIR)/results-a 2>&1 | tee $(CURDIR)/results-a/test.log || true

test-shard-b:
	@echo "=== Running shard B (e-h) with $(FC) ==="
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.dg/dg.exp='[e-h]*' \
		--outdir $(CURDIR)/results-b 2>&1 | tee $(CURDIR)/results-b/test.log || true

test-shard-c:
	@echo "=== Running shard C (i-l) with $(FC) ==="
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.dg/dg.exp='[i-l]*' \
		--outdir $(CURDIR)/results-c 2>&1 | tee $(CURDIR)/results-c/test.log || true

test-shard-d:
	@echo "=== Running shard D (m-p) with $(FC) ==="
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.dg/dg.exp='[m-p]*' \
		--outdir $(CURDIR)/results-d 2>&1 | tee $(CURDIR)/results-d/test.log || true

test-shard-e:
	@echo "=== Running shard E (q-t) with $(FC) ==="
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.dg/dg.exp='[q-t]*' \
		--outdir $(CURDIR)/results-e 2>&1 | tee $(CURDIR)/results-e/test.log || true

test-shard-f:
	@echo "=== Running shard F (u-z) with $(FC) ==="
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.dg/dg.exp='[u-z]*' \
		--outdir $(CURDIR)/results-f 2>&1 | tee $(CURDIR)/results-f/test.log || true

test-shard-g:
	@echo "=== Running shard G (A-Z, 0-9) with $(FC) ==="
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.dg/dg.exp='[A-Z0-9]*' \
		--outdir $(CURDIR)/results-g 2>&1 | tee $(CURDIR)/results-g/test.log || true

test-quick:
	@echo "Running quick test subset with $(FC)..."
	@mkdir -p results-quick
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.dg/dg.exp='array_[0-9]*' \
		--outdir $(CURDIR)/results-quick 2>&1 | tee $(CURDIR)/results-quick/test.log

test-torture:
	@echo "Running torture tests with $(FC)..."
	@mkdir -p results-torture
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.fortran-torture/torture.exp \
		--outdir $(CURDIR)/results-torture 2>&1 | tee $(CURDIR)/results-torture/test.log

test-gomp:
	@echo "Running OpenMP Fortran tests with $(FC)..."
	@mkdir -p results-gomp
	@cd $(LIBGOMP_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool libgomp libgomp.fortran/fortran.exp \
		--outdir $(CURDIR)/results-gomp 2>&1 | tee $(CURDIR)/results-gomp/test.log

test-all: test test-torture test-gomp
	@echo "All test suites completed."

summary:
	@echo ""
	@echo "=== Test Summary ==="
	@total_pass=0; total_fail=0; total_xpass=0; total_xfail=0; total_unsup=0; \
	for sum in results-*/gfortran.sum $(TESTSUITE_DIR)/gfortran.sum; do \
		if [ -f "$$sum" ]; then \
			pass=$$(grep -c "^PASS:" "$$sum" 2>/dev/null || echo 0); \
			fail=$$(grep -c "^FAIL:" "$$sum" 2>/dev/null || echo 0); \
			xpass=$$(grep -c "^XPASS:" "$$sum" 2>/dev/null || echo 0); \
			xfail=$$(grep -c "^XFAIL:" "$$sum" 2>/dev/null || echo 0); \
			unsup=$$(grep -c "^UNSUPPORTED:" "$$sum" 2>/dev/null || echo 0); \
			total_pass=$$((total_pass + pass)); \
			total_fail=$$((total_fail + fail)); \
			total_xpass=$$((total_xpass + xpass)); \
			total_xfail=$$((total_xfail + xfail)); \
			total_unsup=$$((total_unsup + unsup)); \
		fi; \
	done; \
	echo "PASS:        $$total_pass"; \
	echo "FAIL:        $$total_fail"; \
	echo "XPASS:       $$total_xpass"; \
	echo "XFAIL:       $$total_xfail"; \
	echo "UNSUPPORTED: $$total_unsup"; \
	if [ $$total_fail -gt 0 ]; then \
		echo ""; \
		echo "Failures:"; \
		grep "^FAIL:" results-*/gfortran.sum $(TESTSUITE_DIR)/gfortran.sum 2>/dev/null | head -20; \
	fi

clean:
	rm -rf results-*
	rm -f $(TESTSUITE_DIR)/*.sum $(TESTSUITE_DIR)/*.log
	rm -f $(TESTSUITE_DIR)/gfortran.sum $(TESTSUITE_DIR)/gfortran.log
	rm -f $(LIBGOMP_DIR)/*.sum $(LIBGOMP_DIR)/*.log
	find . -name "*.mod" -delete
	find . -name "*.o" -delete
	find . -name "*.x" -delete
	find . -name "a.out" -delete
	find . -name "*.exe" -delete
	@echo "Cleaned test artifacts."
