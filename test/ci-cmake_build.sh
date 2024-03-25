#!/bin/bash -x

set -e

TEST_CMD="pytest -v --maxfail=1 --log-level=DEBUG --log-cli-level=DEBUG test/"


# not default
export UBSAN_OPTIONS=halt_on_error=1

# Make sure binaries can be accessed when invoked by root.
umask 0022

# There are tests that run as root but without CAP_DAC_OVERRIDE. To allow these
# to launch built binaries, the directory tree must be accessible to the root
# user. Since the source directory isn't necessarily accessible to root, we
# build and run tests in a temporary directory that we can set up to be world
# readable/executable.
SOURCE_DIR="$(readlink -f .)"
TEST_DIR="$(mktemp -dt libfuse-build-XXXXXX)"

PREFIX_DIR="$(mktemp -dt libfuse-install-XXXXXXX)"

chmod 0755 "${TEST_DIR}"
cd "${TEST_DIR}"
echo "Running in ${TEST_DIR}"

export CC


echo "CMake build (without sanitizers)"
for CC in gcc gcc-9 gcc-10 clang; do
    echo "=== Building with ${CC} ==="
    mkdir build-${CC}; pushd build-${CC}
    if [ "${CC}" == "clang" ]; then
        export CXX="clang++"
        export TEST_WITH_VALGRIND=false
    else
        unset CXX
        export TEST_WITH_VALGRIND=true
    fi
    if [ ${CC} == 'gcc-7' ]; then
        build_opts='-D b_lundef=false'
    else
        build_opts=''
    fi
    if [ ${CC} == 'gcc-10' ]; then
        build_opts='-Dc_args=-flto=auto'
    else
        build_opts=''
    fi

    cmake -G "Unix Makefiles" \
        -DOPTION_BUILD_UTILS=ON \
        -DOPTION_BUILD_EXAMPLES=ON \
        -DCMAKE_INSTALL_PREFIX=${PREFIX_DIR} \
        -DCMAKE_BUILD_TYPE=Debug \
        "${SOURCE_DIR}" 
    make
    make install

    # libfuse will first try the install path and then system defaults
    sudo chmod 4755 ${PREFIX_DIR}/bin/fusermount3

    # also needed for some of the tests
    sudo chown root:root util/fusermount3
    sudo chmod 4755 util/fusermount3

    ${TEST_CMD}
    popd
    rm -fr build-${CC}
    sudo rm -fr ${PREFIX_DIR}

done


# Documentation.
(cd "${SOURCE_DIR}"; doxygen doc/Doxyfile)

# Clean up.
rm -rf "${TEST_DIR}"


