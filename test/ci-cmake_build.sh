#!/bin/bash -x
#
# Configure, build and test this fork with CMake.
#
# Run from an (empty) build directory, with SOURCE_DIR pointing at the source
# tree and PREFIX_DIR at the install prefix. --setuid-helpers makes
# util/fusermount3 setuid root through sudo, so the mounting tests run as the
# calling user instead of being skipped.

set -e

cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${PREFIX_DIR}" "${SOURCE_DIR}"
make -j"$(nproc)"

"${SOURCE_DIR}/test/run-tests.py" --build-dir . --setuid-helpers
