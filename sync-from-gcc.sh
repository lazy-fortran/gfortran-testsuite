#!/bin/bash
# sync-from-gcc.sh - Sync gfortran test suite from GCC upstream
#
# Copyright (C) 2025 The lazy-fortran Contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This script clones/updates the GCC repository and syncs all Fortran
# test files to this repository, preserving the directory structure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GCC_CLONE_DIR="${SCRIPT_DIR}/.gcc-upstream"
GCC_REPO_URL="git://gcc.gnu.org/git/gcc.git"
GCC_BRANCH="${GCC_BRANCH:-master}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

clone_or_update_gcc() {
    if [[ -d "${GCC_CLONE_DIR}" ]]; then
        log "Updating existing GCC clone..."
        git -C "${GCC_CLONE_DIR}" fetch origin "${GCC_BRANCH}"
        git -C "${GCC_CLONE_DIR}" checkout "${GCC_BRANCH}"
        git -C "${GCC_CLONE_DIR}" reset --hard "origin/${GCC_BRANCH}"
    else
        log "Cloning GCC repository (this may take a while)..."
        git clone --depth 1 --branch "${GCC_BRANCH}" \
            "${GCC_REPO_URL}" "${GCC_CLONE_DIR}"
    fi
}

get_gcc_commit() {
    git -C "${GCC_CLONE_DIR}" rev-parse HEAD
}

get_gcc_commit_date() {
    git -C "${GCC_CLONE_DIR}" log -1 --format='%ci' HEAD
}

sync_directory() {
    local src="$1"
    local dst="$2"

    if [[ ! -d "${src}" ]]; then
        log "Source directory does not exist: ${src}"
        return 0
    fi

    log "Syncing ${src} -> ${dst}"
    mkdir -p "${dst}"
    rsync -av --delete \
        --include='*/' \
        --include='*.f' \
        --include='*.f77' \
        --include='*.for' \
        --include='*.f90' \
        --include='*.f95' \
        --include='*.f03' \
        --include='*.f08' \
        --include='*.f18' \
        --include='*.f23' \
        --include='*.F' \
        --include='*.F90' \
        --include='*.F95' \
        --include='*.F03' \
        --include='*.F08' \
        --include='*.inc' \
        --include='*.exp' \
        --include='*.tcl' \
        --include='Makefile*' \
        --include='README*' \
        --include='COPYING*' \
        --include='*.py' \
        --include='*.json' \
        --exclude='*' \
        "${src}/" "${dst}/"
}

sync_lib_files() {
    local src="${GCC_CLONE_DIR}/gcc/testsuite/lib"
    local dst="${SCRIPT_DIR}/testsuite/lib"

    log "Syncing DejaGnu library files..."
    mkdir -p "${dst}"

    # Sync Fortran-related DejaGnu support files
    local lib_files=(
        "gfortran.exp"
        "gfortran-dg.exp"
        "fortran-modules.exp"
        "fortran-torture.exp"
        "gcc-defs.exp"
        "gcc-dg.exp"
        "prune.exp"
        "timeout.exp"
        "target-libpath.exp"
        "target-supports.exp"
        "target-supports-dg.exp"
        "torture-options.exp"
        "atomic-dg.exp"
        "scanasm.exp"
        "scandump.exp"
        "scantree.exp"
        "scanrtl.exp"
        "scanipa.exp"
        "scanoffload.exp"
        "scanoffloadtree.exp"
        "scanoffloadrtl.exp"
        "scanoffloadipa.exp"
        "target-utils.exp"
        "wrapper.exp"
        "copy-file.exp"
        "dg-test-cleanup.exp"
        "profopt.exp"
        "asan-dg.exp"
        "tsan-dg.exp"
        "ubsan-dg.exp"
        "hwasan-dg.exp"
        "lto.exp"
        "multiline.exp"
        "options.exp"
        "valgrind.exp"
    )

    for f in "${lib_files[@]}"; do
        if [[ -f "${src}/${f}" ]]; then
            cp -v "${src}/${f}" "${dst}/"
        fi
    done
}

sync_config_files() {
    local src="${GCC_CLONE_DIR}/gcc/testsuite/config"
    local dst="${SCRIPT_DIR}/testsuite/config"

    if [[ -d "${src}" ]]; then
        log "Syncing testsuite config..."
        mkdir -p "${dst}"
        rsync -av "${src}/" "${dst}/"
    fi
}

sync_libgomp_lib() {
    local src="${GCC_CLONE_DIR}/libgomp/testsuite/lib"
    local dst="${SCRIPT_DIR}/libgomp/testsuite/lib"

    if [[ -d "${src}" ]]; then
        log "Syncing libgomp testsuite lib..."
        mkdir -p "${dst}"
        rsync -av "${src}/" "${dst}/"
    fi
}

sync_libgomp_config() {
    local src="${GCC_CLONE_DIR}/libgomp/testsuite/config"
    local dst="${SCRIPT_DIR}/libgomp/testsuite/config"

    if [[ -d "${src}" ]]; then
        log "Syncing libgomp testsuite config..."
        mkdir -p "${dst}"
        rsync -av "${src}/" "${dst}/"
    fi
}

count_files() {
    find "$1" -type f \( \
        -name '*.f' -o -name '*.f77' -o -name '*.for' -o \
        -name '*.f90' -o -name '*.f95' -o -name '*.f03' -o \
        -name '*.f08' -o -name '*.f18' -o -name '*.f23' -o \
        -name '*.F' -o -name '*.F90' -o -name '*.F95' -o \
        -name '*.F03' -o -name '*.F08' \
    \) 2>/dev/null | wc -l
}

generate_stats() {
    log "Generating statistics..."

    local total=0
    local stats=""

    for dir in testsuite/gfortran.dg testsuite/gfortran.fortran-torture \
               testsuite/gfortran.target testsuite/gcc.target/powerpc/ppc-fortran \
               libgomp/testsuite/libgomp.fortran libgomp/testsuite/libgomp.oacc-fortran; do
        if [[ -d "${SCRIPT_DIR}/${dir}" ]]; then
            local count
            count=$(count_files "${SCRIPT_DIR}/${dir}")
            total=$((total + count))
            stats="${stats}  ${dir}: ${count} files\n"
        fi
    done

    echo -e "\nStatistics:\n${stats}  Total: ${total} Fortran test files"
}

create_commit() {
    local gcc_commit="$1"
    local gcc_date="$2"

    cd "${SCRIPT_DIR}"

    # Stage all changes
    git add -A testsuite/ libgomp/

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi

    # Get list of changed files for commit message
    local changes
    changes=$(git diff --cached --stat | tail -1)

    # Create commit message
    local commit_msg
    commit_msg=$(cat <<EOF
Sync with GCC upstream

GCC commit: ${gcc_commit}
GCC commit date: ${gcc_date}

Changes: ${changes}

Synced directories:
- gcc/testsuite/gfortran.dg/
- gcc/testsuite/gfortran.fortran-torture/
- gcc/testsuite/gfortran.target/
- gcc/testsuite/gcc.target/powerpc/ppc-fortran/
- gcc/testsuite/lib/ (Fortran-related)
- libgomp/testsuite/libgomp.fortran/
- libgomp/testsuite/libgomp.oacc-fortran/
EOF
)

    git commit -m "${commit_msg}"
    log "Created commit for sync"
}

main() {
    log "Starting GCC Fortran test suite sync..."

    clone_or_update_gcc

    local gcc_commit
    local gcc_date
    gcc_commit=$(get_gcc_commit)
    gcc_date=$(get_gcc_commit_date)
    log "GCC commit: ${gcc_commit}"
    log "GCC date: ${gcc_date}"

    # Sync main gfortran test directories
    sync_directory \
        "${GCC_CLONE_DIR}/gcc/testsuite/gfortran.dg" \
        "${SCRIPT_DIR}/testsuite/gfortran.dg"

    sync_directory \
        "${GCC_CLONE_DIR}/gcc/testsuite/gfortran.fortran-torture" \
        "${SCRIPT_DIR}/testsuite/gfortran.fortran-torture"

    sync_directory \
        "${GCC_CLONE_DIR}/gcc/testsuite/gfortran.target" \
        "${SCRIPT_DIR}/testsuite/gfortran.target"

    # Sync PowerPC Fortran tests
    sync_directory \
        "${GCC_CLONE_DIR}/gcc/testsuite/gcc.target/powerpc/ppc-fortran" \
        "${SCRIPT_DIR}/testsuite/gcc.target/powerpc/ppc-fortran"

    # Sync libgomp Fortran tests
    sync_directory \
        "${GCC_CLONE_DIR}/libgomp/testsuite/libgomp.fortran" \
        "${SCRIPT_DIR}/libgomp/testsuite/libgomp.fortran"

    sync_directory \
        "${GCC_CLONE_DIR}/libgomp/testsuite/libgomp.oacc-fortran" \
        "${SCRIPT_DIR}/libgomp/testsuite/libgomp.oacc-fortran"

    # Sync DejaGnu infrastructure
    sync_lib_files
    sync_config_files
    sync_libgomp_lib
    sync_libgomp_config

    generate_stats

    # Create commit if requested
    if [[ "${AUTO_COMMIT:-0}" == "1" ]]; then
        create_commit "${gcc_commit}" "${gcc_date}"
    else
        log "Skipping auto-commit (set AUTO_COMMIT=1 to enable)"
    fi

    log "Sync complete!"
}

main "$@"
