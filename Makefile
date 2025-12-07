# Makefile for gfortran test suite
#
# Usage:
#   make test                     # Run full test suite (auto-parallel)
#   make test JOBS=32             # Run with 32 parallel workers
#   make test-quick               # Run quick subset
#   make summary                  # Show test summary
#   make clean                    # Clean artifacts
#
# This uses GCC's native parallelization via GCC_RUNTEST_PARALLELIZE_DIR.
# Multiple runtest instances coordinate through a shared directory to
# dynamically distribute tests.

SHELL := /bin/bash

# Compiler to test (default: system gfortran)
FC ?= gfortran
GCC ?= gcc

# Number of parallel jobs (default: number of CPU cores)
JOBS ?= $(shell nproc)

# Test directories
TESTSUITE_DIR := testsuite
LIBGOMP_DIR := libgomp/testsuite

# Results directory
RESULTS_DIR := results

.PHONY: all test test-quick test-torture test-gomp test-all \
        summary clean help

all: help

help:
	@echo "GFortran Test Suite"
	@echo ""
	@echo "Usage:"
	@echo "  make test                  Run full test suite (parallel)"
	@echo "  make test JOBS=32          Run with 32 parallel workers"
	@echo "  make test FC=/path/to/gfortran  Test specific compiler"
	@echo "  make test-quick            Run quick subset"
	@echo "  make test-torture          Run torture tests"
	@echo "  make test-gomp             Run OpenMP tests"
	@echo "  make summary               Show test summary"
	@echo "  make clean                 Clean artifacts"
	@echo ""
	@echo "Environment variables:"
	@echo "  FC     Fortran compiler (default: gfortran)"
	@echo "  GCC    C compiler for mixed tests (default: gcc)"
	@echo "  JOBS   Number of parallel workers (default: nproc = $(JOBS))"

# Main test target using GCC's native parallelization
test:
	@echo "=== Running gfortran.dg tests with $(FC) using $(JOBS) parallel workers ==="
	@rm -rf $(RESULTS_DIR)
	@mkdir -p $(RESULTS_DIR)/parallel
	@# Launch JOBS parallel runtest instances
	@# They coordinate via GCC_RUNTEST_PARALLELIZE_DIR
	@for i in $$(seq 1 $(JOBS)); do \
		( \
			mkdir -p $(RESULTS_DIR)/worker-$$i && \
			cd $(TESTSUITE_DIR) && \
			GCC_RUNTEST_PARALLELIZE_DIR="$(CURDIR)/$(RESULTS_DIR)/parallel" \
			GFORTRAN_UNDER_TEST="$(FC)" \
			GCC_UNDER_TEST="$(GCC)" \
			runtest --tool gfortran gfortran.dg/dg.exp \
				--outdir $(CURDIR)/$(RESULTS_DIR)/worker-$$i \
				2>&1 | tee $(CURDIR)/$(RESULTS_DIR)/worker-$$i/test.log \
		) & \
	done; \
	wait
	@echo "=== Merging results ==="
	@./contrib/dg-extract-results.sh \
		$$(find $(RESULTS_DIR) -name 'gfortran.sum' | sort) \
		> $(RESULTS_DIR)/gfortran.sum
	@./contrib/dg-extract-results.sh -L \
		$$(find $(RESULTS_DIR) -name 'gfortran.log' | sort) \
		> $(RESULTS_DIR)/gfortran.log
	@echo "=== Test run complete ==="
	@$(MAKE) --no-print-directory summary

test-quick:
	@echo "Running quick test subset with $(FC)..."
	@mkdir -p $(RESULTS_DIR)
	@cd $(TESTSUITE_DIR) && \
	GFORTRAN_UNDER_TEST="$(FC)" GCC_UNDER_TEST="$(GCC)" \
	runtest --tool gfortran gfortran.dg/dg.exp='array_[0-9]*' \
		--outdir $(CURDIR)/$(RESULTS_DIR) 2>&1 | tee $(CURDIR)/$(RESULTS_DIR)/test.log

test-torture:
	@echo "Running torture tests with $(FC) using $(JOBS) parallel workers..."
	@mkdir -p $(RESULTS_DIR)-torture/parallel
	@for i in $$(seq 1 $(JOBS)); do \
		( \
			mkdir -p $(RESULTS_DIR)-torture/worker-$$i && \
			cd $(TESTSUITE_DIR) && \
			GCC_RUNTEST_PARALLELIZE_DIR="$(CURDIR)/$(RESULTS_DIR)-torture/parallel" \
			GFORTRAN_UNDER_TEST="$(FC)" \
			GCC_UNDER_TEST="$(GCC)" \
			runtest --tool gfortran gfortran.fortran-torture/torture.exp \
				--outdir $(CURDIR)/$(RESULTS_DIR)-torture/worker-$$i \
				2>&1 | tee $(CURDIR)/$(RESULTS_DIR)-torture/worker-$$i/test.log \
		) & \
	done; \
	wait
	@./contrib/dg-extract-results.sh \
		$$(find $(RESULTS_DIR)-torture -name 'gfortran.sum' | sort) \
		> $(RESULTS_DIR)-torture/gfortran.sum 2>/dev/null || true

test-gomp:
	@echo "Running OpenMP Fortran tests with $(FC) using $(JOBS) parallel workers..."
	@mkdir -p $(RESULTS_DIR)-gomp/parallel
	@for i in $$(seq 1 $(JOBS)); do \
		( \
			mkdir -p $(RESULTS_DIR)-gomp/worker-$$i && \
			cd $(LIBGOMP_DIR) && \
			GCC_RUNTEST_PARALLELIZE_DIR="$(CURDIR)/$(RESULTS_DIR)-gomp/parallel" \
			GFORTRAN_UNDER_TEST="$(FC)" \
			GCC_UNDER_TEST="$(GCC)" \
			runtest --tool libgomp libgomp.fortran/fortran.exp \
				--outdir $(CURDIR)/$(RESULTS_DIR)-gomp/worker-$$i \
				2>&1 | tee $(CURDIR)/$(RESULTS_DIR)-gomp/worker-$$i/test.log \
		) & \
	done; \
	wait
	@./contrib/dg-extract-results.sh \
		$$(find $(RESULTS_DIR)-gomp -name '*.sum' | sort) \
		> $(RESULTS_DIR)-gomp/libgomp.sum 2>/dev/null || true

test-all: test test-torture test-gomp
	@echo "All test suites completed."

summary:
	@echo ""
	@echo "=== Test Summary ==="
	@total_pass=0; total_fail=0; total_xpass=0; total_xfail=0; total_unsup=0; \
	for sum in $(RESULTS_DIR)/gfortran.sum $(RESULTS_DIR)-*/gfortran.sum $(RESULTS_DIR)-*/libgomp.sum; do \
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
		grep "^FAIL:" $(RESULTS_DIR)/gfortran.sum $(RESULTS_DIR)-*/gfortran.sum 2>/dev/null | head -20; \
	fi

clean:
	rm -rf $(RESULTS_DIR) $(RESULTS_DIR)-*
	rm -f $(TESTSUITE_DIR)/*.sum $(TESTSUITE_DIR)/*.log
	rm -f $(TESTSUITE_DIR)/gfortran.sum $(TESTSUITE_DIR)/gfortran.log
	rm -f $(LIBGOMP_DIR)/*.sum $(LIBGOMP_DIR)/*.log
	find . -name "*.mod" -delete
	find . -name "*.o" -delete
	find . -name "*.x" -delete
	find . -name "a.out" -delete
	find . -name "*.exe" -delete
	@echo "Cleaned test artifacts."
