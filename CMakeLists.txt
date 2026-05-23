# CMake equivalent of libfuse's meson.build
# Every attempt has been made to match all the functionality provided by meson
# Use at your own risk

cmake_minimum_required (VERSION 3.21.0)
set (CMAKE_VERBOSE_MAKEFILE FALSE)

# Parse version like meson does: split "3.19.0-rc0" into base + rc.
# CMake's project() rejects non-numeric suffixes, so we strip "-rc0" first,
# pass the numeric part to project(), then preserve the rc string separately
# for FUSE_RC_VERSION in the installed public header.
set(PROJECT_VERSION_FULL "3.19.0-rc0")
string(REGEX MATCH "^([0-9]+\\.[0-9]+\\.[0-9]+)(-(.+))?$"
       _ver_match "${PROJECT_VERSION_FULL}")
set(_ver_base "${CMAKE_MATCH_1}")
set(FUSE_RC_VERSION "${CMAKE_MATCH_3}")  # empty if no -rcN suffix

project (libfuse3
         VERSION ${_ver_base}
         DESCRIPTION "The CMake implementation of the Linux FUSE (Filesystem in Userspace) interface"
         HOMEPAGE_URL https://github.com/Smit-tay/libfuse-cmake
         LANGUAGES C CXX)

set(FUSE_MAJOR_VERSION  ${PROJECT_VERSION_MAJOR})
set(FUSE_MINOR_VERSION  ${PROJECT_VERSION_MINOR})
set(FUSE_HOTFIX_VERSION ${PROJECT_VERSION_PATCH})


if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
  message(FATAL_ERROR "libfuse does not support OS-X.\n"
                      "Take a look at http://osxfuse.github.io/ instead")
elseif(${CMAKE_SYSTEM_NAME} MATCHES "cygwin" OR ${CMAKE_SYSTEM_NAME} MATCHES "Windows")
  message(FATAL_ERROR "libfuse does not support Windows.\n"
                      "Take a look at http://www.secfs.net/winfsp/ instead")
endif()


# The meson build sets a few defaults
#       default_options: [
#            'buildtype=debugoptimized',
#            'c_std=gnu11',
#            'cpp_std=c++20',
#            'warning_level=2',
#            ]
# And, like most things in meson, the documentation for warning level is
# essentially non-existent - took 15 minutes of searching to find this:
# warning_level 1 adds -Wall,
# warning_level 2 adds warning_level 1 + -Wextra,
# warning_level 3 adds warning_level 2 + -Wpedantic
#
# we do our best to follow suite:

# libfuse uses assert() as load-bearing flow control. Patterns like
# `assert(fuse_session_new(...) != NULL)` rely on the function call AND
# the check happening. With -DNDEBUG, the entire expression is elided -
# the function never runs and the library breaks in mysterious ways.
#
# We default to Debug build (no -DNDEBUG) for that reason. If the user
# explicitly picks a build type that defines NDEBUG, we warn but let them
# proceed - they may have a reason, and they can deal with the fallout.
if(NOT CMAKE_BUILD_TYPE AND NOT EXISTS ${CMAKE_BINARY_DIR}/CMakeCache.txt)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
        "Build type (Debug recommended - libfuse asserts are load-bearing)"
        FORCE)
endif()

# Detect if NDEBUG will be defined for this build (any source.) The previous
# `if(DEFINED NDEBUG)` check was broken - DEFINED tests CMake variables, not
# preprocessor defines. We check the actual flags that will reach the
# compiler.
set(_ndebug_check "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE}}")
if(_ndebug_check MATCHES "(^| )-DNDEBUG( |$)")
    message(WARNING
        "NDEBUG is defined for this build (build type: ${CMAKE_BUILD_TYPE}). "
        "libfuse uses assert() as load-bearing flow control - this WILL "
        "produce a non-functional library. Use -DCMAKE_BUILD_TYPE=Debug, "
        "or expect mysterious runtime failures.")
endif()

# meson uses c_std=gnu11 (GNU extensions enabled). CMake's CMAKE_C_EXTENSIONS
# defaults to ON which gives -std=gnu11, but set it explicitly so the choice
# survives a future change of CMake defaults.
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Flags shared by C and C++
add_compile_options("-D_REENTRANT" "-DHAVE_LIBFUSE_PRIVATE_CONFIG_H"
                    "-D_FILE_OFFSET_BITS=64"
                    "-Wall" "-Wextra"
                    "-Wmissing-declarations" "-Wno-sign-compare" "-Wwrite-strings"
                    "-fno-strict-aliasing")
# -Wstrict-prototypes is C-only; g++ warns about it as a non-C++ option.
add_compile_options($<$<COMPILE_LANGUAGE:C>:-Wstrict-prototypes>)

# C++ only: meson defines _GNU_SOURCE for C++ but not for C (see meson.build
# line 204). C source files #define _GNU_SOURCE themselves where needed;
# C++ files don't, so we add it on the command line for C++ to match.
add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-D_GNU_SOURCE>)

include(CheckIncludeFile)
include(CheckIncludeFiles)
include(CheckFunctionExists)
include(CheckSymbolExists)
include(CheckStructHasMember)
include(CheckCSourceCompiles)
include(CheckCSourceRuns)
include(FindPkgConfig)

# meson.build does this:
#    args_default = [ '-D_GNU_SOURCE' ]
# then passes that to every has_function/has_member call.
# In CMake the equivalent is to set CMAKE_REQUIRED_DEFINITIONS before each
# check_* macro. Setting it here applies it to all subsequent checks.
set(CMAKE_REQUIRED_DEFINITIONS "-D_GNU_SOURCE")

check_include_file("stdio.h"        HAVE_STDIO_H)
check_include_file("stdlib.h"       HAVE_STDLIB_H)
check_include_file("stddef.h"       HAVE_STDDEF_H)
check_include_file("unistd.h"       HAVE_UNISTD_H)
check_include_file("sys/types.h"    HAVE_SYS_TYPES_H)
check_include_file("sys/stat.h"     HAVE_SYS_STAT_H)
check_include_file("fcntl.h"        HAVE_FCNTL_H)

set(include_default "stdio.h;stdlib.h;stddef.h;unistd.h;sys/types.h;sys/stat.h;fcntl.h;pthread.h")

# Check for sys/xattr.h
check_include_file(sys/xattr.h HAVE_SYS_XATTR_H)
# Check for linux/limits.h
check_include_file(linux/limits.h HAVE_LINUX_LIMITS_H)

# Fork is actually implemented in the kernel.
# It is declared as an external in "unistd.h"
# Possibly because of that, testing with check_symbol_exists
# fails, so we use check_function_exists instead
check_function_exists("fork"      HAVE_FORK)
check_function_exists("backtrace" HAVE_BACKTRACE)

check_symbol_exists("fstatat"         "${include_default}"    HAVE_FSTATAT)
check_symbol_exists("openat"          "${include_default}"    HAVE_OPENAT)
check_symbol_exists("readlinkat"      "${include_default}"    HAVE_READLINKAT)
check_symbol_exists("pipe2"           "${include_default}"    HAVE_PIPE2)
check_symbol_exists("splice"          "${include_default}"    HAVE_SPLICE)
check_symbol_exists("vmsplice"        "${include_default}"    HAVE_VMSPLICE)
check_symbol_exists("posix_fallocate" "${include_default}"    HAVE_POSIX_FALLOCATE)
check_symbol_exists("fdatasync"       "${include_default}"    HAVE_FDATASYNC)
check_symbol_exists("utimensat"       "${include_default}"    HAVE_UTIMENSAT)
check_symbol_exists("copy_file_range" "${include_default}"    HAVE_COPY_FILE_RANGE)
check_symbol_exists("fallocate"       "${include_default}"    HAVE_FALLOCATE)
check_symbol_exists("fspacectl"       "${include_default}"    HAVE_FSPACECTL)
check_symbol_exists("pthread_setname_np" "${include_default}" HAVE_PTHREAD_SETNAME_NP)
# For some reason the meson build checks these separately
check_symbol_exists("setxattr" "sys/xattr.h" HAVE_SETXATTR)
check_symbol_exists("iconv"    "iconv.h"     HAVE_ICONV)
check_symbol_exists("statx"    "sys/stat.h"  HAVE_STATX)

CHECK_STRUCT_HAS_MEMBER("struct stat" st_atim       sys/stat.h HAVE_STRUCT_STAT_ST_ATIM       LANGUAGE C)
CHECK_STRUCT_HAS_MEMBER("struct stat" st_atimespec  sys/stat.h HAVE_STRUCT_STAT_ST_ATIMESPEC  LANGUAGE C)

# close_range needs a compile test, not just a symbol check: meson's test
# references CLOSE_RANGE_UNSHARE which lives in <linux/close_range.h>. An
# older kernel-headers package can declare the syscall in <unistd.h> while
# lacking the flag - a symbol-only check would falsely report success.
check_c_source_compiles("
    #include <unistd.h>
    #include <fcntl.h>
    #ifdef __linux__
    #include <linux/close_range.h>
    #endif
    int main(void) {
        unsigned int flags = CLOSE_RANGE_UNSHARE;
        return close_range(3, ~0U, flags);
    }
" HAVE_CLOSE_RANGE)

# listmount: tests the full syscall surface (struct mnt_id_req, LSMT_ROOT,
# SYS_listmount). Symbol presence alone is not enough.
check_c_source_compiles("
    #include <syscall.h>
    #include <linux/mount.h>
    #include <unistd.h>
    #include <stdint.h>
    int main(void) {
        struct mnt_id_req req = {
            .size = sizeof(struct mnt_id_req),
            .mnt_id = LSMT_ROOT,
        };
        uint64_t mnt_ids[1];
        int n = syscall(SYS_listmount, &req, &mnt_ids, 1, 0);
        if (n == -1) return -1;
        return 0;
    }
" HAVE_LISTMOUNT)

# new_mount_api: fsopen/fsconfig/fsmount/move_mount - same reasoning, the
# whole surface needs to compile, not just one symbol.
check_c_source_compiles("
    #include <sys/mount.h>
    #include <linux/mount.h>
    #include <unistd.h>
    #include <fcntl.h>
    int main(void) {
        int fsfd = fsopen(\"fuse\", FSOPEN_CLOEXEC);
        int res = fsconfig(fsfd, FSCONFIG_SET_STRING, \"source\", \"test\", 0);
        int mntfd = fsmount(fsfd, FSMOUNT_CLOEXEC, 0);
        res = move_mount(mntfd, \"\", AT_FDCWD, \"/mnt\", MOVE_MOUNT_F_EMPTY_PATH);
        (void)res;
        return 0;
    }
" HAVE_NEW_MOUNT_API)

# This comment appears in meson.build - not sure why the author thinks it's
# stupid to warn about an unused return values. Seems like the right thing
# to do is fix the code, instead of cast to void.
## Some (stupid) GCC versions warn about unused return values even when they are
## casted to void. This makes -Wunused-result pretty useless, since there is no
## way to suppress the warning when we really *want* to ignore the value.
set(CHECK_UNUSED_RESULT_WARNING "
__attribute__((warn_unused_result)) int get_4() {
    return 4;
}
int main(void) {
    (void) get_4();
    return 0;
}")

# meson uses -Werror=unused-result for this check; we do the same so the
# warning becomes a compile failure, which is what cc.compiles() detects.
set(_saved_flags ${CMAKE_REQUIRED_FLAGS})
set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} -O0 -Werror=unused-result")
CHECK_C_SOURCE_COMPILES("${CHECK_UNUSED_RESULT_WARNING}" CHECK_UNUSED_RESULT)
set(CMAKE_REQUIRED_FLAGS ${_saved_flags})
if(NOT CHECK_UNUSED_RESULT)
  message(STATUS "Compiler warns about unused result even when casting to void")
  add_compile_options("-Wno-unused-result")
endif()

# Versioned-symbols logic, mirroring meson lines 224-276.
# Default on (glibc is the main target); turn off if we detect uclibc/Apple,
# or if the user explicitly disables it.
option(OPTION_DISABLE_LIBC_SYMBOL_VERSION "Disable versioned libc symbols" OFF)

set(versioned_symbols 1)

# meson's libc detection: a tiny program that #errors on uclibc/Apple.
# If it compiles, we're on a libc that supports versioned symbols.
check_c_source_compiles("
int main(void) {
#if (defined(__UCLIBC__) || defined(__APPLE__))
#error /* libc does not have versioned symbols */
#endif
    return 0;
}" LIBC_SUPPORTS_VERSIONED_SYMBOLS)
if(NOT LIBC_SUPPORTS_VERSIONED_SYMBOLS)
    set(versioned_symbols 0)
endif()

if(OPTION_DISABLE_LIBC_SYMBOL_VERSION)
    set(versioned_symbols 0)
endif()

if(versioned_symbols)
    message(STATUS "Enabling versioned libc symbols")
    set(LIBFUSE_BUILT_WITH_VERSIONED_SYMBOLS ON)

    # gcc-10+ and recent clang support __attribute__((symver)). Older
    # toolchains fall back to the inline-asm .symver method. Test it
    # by actually compiling with -Werror.
    set(CHECK_SYMVER_SUPPORT_WARNING "
    __attribute__ ((__symver__ (\"foo@VERS_1\"))) int foo_v1 (void) {
        return 0;
    }
    int main(void) {
        (void) foo_v1();
        return 0;
    }")
    set(_saved_flags ${CMAKE_REQUIRED_FLAGS})
    set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} -O0 -Werror")
    CHECK_C_SOURCE_COMPILES("${CHECK_SYMVER_SUPPORT_WARNING}" CHECK_SYMVER_SUPPORT)
    set(CMAKE_REQUIRED_FLAGS ${_saved_flags})
    if(CHECK_SYMVER_SUPPORT)
        message(STATUS "Compiler supports symver attribute")
        add_compile_options($<$<COMPILE_LANGUAGE:C>:-DHAVE_SYMVER_ATTRIBUTE>)
    else()
        message(STATUS "Compiler does not support symver attribute")
    endif()
else()
    message(STATUS "Disabling versioned libc symbols")
endif()

# Build options that mirror meson's meson_options.txt entries.
option(OPTION_ENABLE_USDT     "Enable USDT/SystemTap probes" OFF)
option(OPTION_ENABLE_IO_URING "Enable io_uring backend"      OFF)
option(OPTION_BUILD_UTILS     "Also build utils and docs"    ON)
option(OPTION_BUILD_EXAMPLES  "Also build examples"          ON)
option(OPTION_BUILD_TESTS     "Build the test suite"         ON)

if(OPTION_ENABLE_USDT)
    set(USDT_ENABLED ON)
endif()

# io_uring + libnuma detection, mirroring meson lines 175-196.
# Only set HAVE_URING if both libs are present AND the SQE128 feature
# is available in the installed liburing headers.
if(OPTION_ENABLE_IO_URING)
    pkg_check_modules(LIBURING liburing)
    pkg_check_modules(LIBNUMA  numa)
    if(LIBURING_FOUND AND LIBNUMA_FOUND)
        set(_saved_libs ${CMAKE_REQUIRED_LIBRARIES})
        set(_saved_incs ${CMAKE_REQUIRED_INCLUDES})
        set(CMAKE_REQUIRED_LIBRARIES ${LIBURING_LIBRARIES})
        set(CMAKE_REQUIRED_INCLUDES  ${LIBURING_INCLUDE_DIRS})
        check_c_source_compiles("
            #include <liburing.h>
            #include <stdio.h>
            int main(void) {
                struct io_uring ring;
                int ret = io_uring_queue_init(1, &ring, 0);
            #ifndef IORING_SETUP_SQE128
            #error \"No SQE128 support\"
            #endif
                return ret;
            }
        " HAVE_URING)
        set(CMAKE_REQUIRED_LIBRARIES ${_saved_libs})
        set(CMAKE_REQUIRED_INCLUDES  ${_saved_incs})
    endif()
endif()

# Older versions of musl libc don't unescape entries in /etc/mtab
# Try to detect this behaviour, and work around, if necessary.
set(COMPILE_ME [=[
    #include <mntent.h>
    #include <stdio.h>
    #include <string.h>
    #include <stdlib.h>

    #define dir_space_tab "dir/040space/011tab"

    int main(void)
    {
        const char *fake_mtab = "name " dir_space_tab " type opts 0 0\\n";
        FILE *f = fmemopen((void *)fake_mtab, strlen(fake_mtab) + 1, "r");
        struct mntent *entp = getmntent(f);
        fclose(f);
        if(NULL == entp)
            exit(EXIT_FAILURE);
        if (0 == strcmp(entp->mnt_dir, dir_space_tab))
            return 99; // printf("needs escaping\n");
        else
            return 100; //printf("no need to escape\n");
    }
]=])

set(TEST_FILE "${CMAKE_BINARY_DIR}/compile_me.c")

# Write the C code to the file
file(WRITE ${TEST_FILE} "${COMPILE_ME}")

message(STATUS "Performing Test GETMNTENT_ESCAPING")
try_run(
    RUN_RESULT
    COMPILE_RESULT
    ${CMAKE_BINARY_DIR}  # Binary Directory
    ${TEST_FILE}         # Source File
    LINK_OPTIONS -lmount
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMPILE_OUTPUT_VARIABLE COMPILE_OUT_TXT
    RUN_OUTPUT_VARIABLE RUN_OUT_TXT
)

if(NOT COMPILE_RESULT)
    message(WARNING  "Compiling test for getmntent failed with output: ${COMPILE_OUT_TXT}")
else()
    message(STATUS "Performing Test GETMNTENT_ESCAPING - Success")
    # Check the result of try_run using regex
    if(RUN_RESULT EQUAL 100)
        message(STATUS "getmntent does NOT require escaping")
    elseif(RUN_RESULT EQUAL 99)
        set(GETMNTENT_NEEDS_UNESCAPING TRUE CACHE BOOL "getmntent requires escaping")
        message(STATUS "getmntent REQUIRES escaping")
    else()
        message(WARNING "Unknown error returned from testing for getmntent. Value: ${RUN_RESULT}.\nOutput ${RUN_OUT_TXT}")
    endif()
endif()

set(INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/lib"
        "${PROJECT_BINARY_DIR}/.")

include(FindThreads)
find_package( Threads REQUIRED )
# Trying to reproduce meson.build - but, some of what that does seems a little sloppy
# Including this:  globally add threading to everything !
# Prefer add_link_options - but my version of cmake doesn't support
# Besides, it's not clear that it would be better to use target_link_libraries
link_libraries(Threads::Threads)
add_compile_options(${CMAKE_THREAD_LIBS_INIT})

# Generate the two config headers. fuse_config.h is private (build-tree only,
# contains feature-detection results); libfuse_config.h is public (installed
# under fuse3/, contains only version and ABI flags). Mirrors meson's split
# between private_cfg and public_cfg.
configure_file (
    "${PROJECT_SOURCE_DIR}/fuse_config.h.in"
    "${PROJECT_BINARY_DIR}/fuse_config.h"
    @ONLY
)
configure_file (
    "${PROJECT_SOURCE_DIR}/libfuse_config.h.in"
    "${PROJECT_BINARY_DIR}/libfuse_config.h"
    @ONLY
)

include(GNUInstallDirs)
install(FILES "${PROJECT_BINARY_DIR}/libfuse_config.h"
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/fuse3")

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/lib)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/include)

if(OPTION_BUILD_TESTS)
  enable_testing()
  add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/test)
endif()

if(OPTION_BUILD_UTILS)
  if(NOT ${CMAKE_SYSTEM_NAME} MATCHES "BSD" AND NOT  ${CMAKE_SYSTEM_NAME} MATCHES "DRAGONFLY" )
    message("Also building utils and docs")
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/util)
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/doc)
  endif()
else()
  message("NOT building utils and docs")
endif()

if(OPTION_BUILD_EXAMPLES)
  message("Also building examples")
  add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/example)
else()
  message("NOT building examples")
endif()
