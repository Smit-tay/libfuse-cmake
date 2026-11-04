# CMake equivalent of libfuse's meson.build.
#
# This file follows meson.build section by section; when upstream changes
# meson.build, the matching section here is the one to update. Options keep
# the fork's OPTION_* names; each one names the meson option it mirrors.

cmake_minimum_required(VERSION 3.21.0)

# meson: version: '3.19.0-rc0'
# project() rejects a non-numeric suffix, so split "-rcN" off first, the way
# meson.build splits it into base_version and FUSE_RC_VERSION.
set(PROJECT_VERSION_FULL "3.19.0-rc0")
string(REGEX MATCH "^([0-9]+\\.[0-9]+\\.[0-9]+)(-(.+))?$"
       _ver_match "${PROJECT_VERSION_FULL}")
set(_ver_base "${CMAKE_MATCH_1}")
set(FUSE_RC_VERSION "${CMAKE_MATCH_3}")  # empty if no -rcN suffix

# meson: project('libfuse3', ['c'], ...) - C only; C++ is added on demand by
# example/ (add_languages('cpp', required: false)).
project(libfuse3
        VERSION ${_ver_base}
        DESCRIPTION "The CMake implementation of the Linux FUSE (Filesystem in Userspace) interface"
        HOMEPAGE_URL https://github.com/Smit-tay/libfuse-cmake
        LANGUAGES C)

set(FUSE_MAJOR_VERSION  ${PROJECT_VERSION_MAJOR})
set(FUSE_MINOR_VERSION  ${PROJECT_VERSION_MINOR})
set(FUSE_HOTFIX_VERSION ${PROJECT_VERSION_PATCH})

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(FuseConfigData)
include(GNUInstallDirs)

# meson's host_machine.system() is lower case: 'linux', 'freebsd', 'netbsd',
# 'dragonfly', 'darwin', 'cygwin', 'windows'. Normalise CMAKE_SYSTEM_NAME the
# same way so the platform tests below read like meson's.
string(TOLOWER "${CMAKE_SYSTEM_NAME}" FUSE_PLATFORM)

if(FUSE_PLATFORM STREQUAL "darwin")
    message(FATAL_ERROR "libfuse does not support OS-X.\n"
                        "Take a look at http://osxfuse.github.io/ or the more recent\n"
                        "https://www.fuse-t.org/ instead")
elseif(FUSE_PLATFORM STREQUAL "cygwin" OR FUSE_PLATFORM STREQUAL "windows")
    message(FATAL_ERROR "libfuse does not support Windows.\n"
                        "Take a look at http://www.secfs.net/winfsp/ instead")
endif()

#
# Options (meson_options.txt)
#
option(OPTION_BUILD_UTILS    "Whether or not to build and install helper programs (meson: utils)" ON)
option(OPTION_BUILD_EXAMPLES "Whether or not to build example programs (meson: examples)"         ON)
option(OPTION_BUILD_TESTS    "Compile the test files (meson: tests)"                              ON)
option(OPTION_DISABLE_LIBC_SYMBOL_VERSION
       "Disable versioned symbols through libc (meson: disable-libc-symbol-version)" OFF)
option(OPTION_ENABLE_USDT
       "Enable user statically defined tracepoints for extra observability (meson: enable-usdt)" OFF)
option(OPTION_ENABLE_IO_URING "Enable fuse-over-io-uring support (meson: enable-io-uring)" ON)
option(OPTION_ENABLE_CUSTOM_IO
       "Enable fuse_session_custom_io(); see doc/README.custom-io (meson: enable-custom-io)" OFF)
set(OPTION_SYNC_INIT "auto" CACHE STRING
    "Synchronous FUSE_INIT: auto follows fuse_daemonize_early_start(), always and never override it (meson: sync-init)")
set_property(CACHE OPTION_SYNC_INIT PROPERTY STRINGS auto always never)
set(OPTION_SERVICE_SOCKET_DIR "" CACHE STRING
    "Where to install fuse server sockets (if empty, /run/fuse) (meson: service-socket-dir)")
set(OPTION_SERVICE_SOCKET_PERMS "" CACHE STRING
    "Default fuse server socket permissions (if empty, 0220) (meson: service-socket-perms)")
set(OPTION_SYSTEMD_SYSTEM_UNIT_DIR "" CACHE STRING
    "Where to install systemd unit files (if empty, query pkg-config(1)) (meson: systemd-system-unit-dir)")
set(OPTION_UDEVRULESDIR "" CACHE STRING
    "Where to install udev rules (if empty, query pkg-config(1)) (meson: udevrulesdir)")
set(OPTION_INITSCRIPTDIR "/etc/init.d/" CACHE STRING
    "Init script installation location (if empty, disable init script installation) (meson: initscriptdir)")
option(OPTION_USEROOT "Set owner and setuid bits on installed files (meson: useroot)" ON)

#
# Build type and NDEBUG (meson: buildtype=debugoptimized, b_ndebug=false)
#
# meson defaults to -O2 -g, and never defines NDEBUG unless asked (b_ndebug
# defaults to false for every buildtype). The tests and examples rely on that:
# they put calls with side effects inside assert(). RelWithDebInfo is CMake's
# -O2 -g; NDEBUG is stripped from every configuration unless OPTION_NDEBUG is
# set, which is the b_ndebug=true equivalent.
get_property(_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT _multi_config AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING
        "Build type (default RelWithDebInfo = meson's debugoptimized)" FORCE)
endif()
option(OPTION_NDEBUG "Define NDEBUG, disabling assert() (meson: b_ndebug)" OFF)
if(NOT OPTION_NDEBUG)
    foreach(_lang C CXX)
        foreach(_cfg RELEASE RELWITHDEBINFO MINSIZEREL)
            string(REGEX REPLACE "(^| )[-/]DNDEBUG( |$)" " "
                   CMAKE_${_lang}_FLAGS_${_cfg} "${CMAKE_${_lang}_FLAGS_${_cfg}}")
        endforeach()
    endforeach()
    # meson (>= 1.4) also turns on libstdc++'s cheap precondition checks
    # whenever NDEBUG is off.
    add_compile_definitions($<$<COMPILE_LANGUAGE:CXX>:_GLIBCXX_ASSERTIONS=1>)
else()
    add_compile_definitions(NDEBUG)
    if(OPTION_BUILD_TESTS OR OPTION_BUILD_EXAMPLES)
        message(WARNING
            "OPTION_NDEBUG is set: the tests and examples call functions "
            "inside assert(), so with NDEBUG those calls are compiled out and "
            "the programs do not work (the compiler reports variables used "
            "uninitialized). Build the library alone with "
            "-DOPTION_BUILD_TESTS=OFF -DOPTION_BUILD_EXAMPLES=OFF.")
    endif()
endif()

# meson: c_std=gnu11, cpp_std=c++20
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(CheckCSourceCompiles)
include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckStructHasMember)
include(CheckSymbolExists)
include(FindPkgConfig)

#
# Feature detection, the resulting config file is installed with the package.
# Symbols need to be carefully named, to avoid conflicts with applications
# linking to libfuse and including this config.
#
fuse_cfg_set(public FUSE_MAJOR_VERSION  ${FUSE_MAJOR_VERSION})
fuse_cfg_set(public FUSE_MINOR_VERSION  ${FUSE_MINOR_VERSION})
fuse_cfg_set(public FUSE_HOTFIX_VERSION ${FUSE_HOTFIX_VERSION})
fuse_cfg_set(public FUSE_RC_VERSION     "${FUSE_RC_VERSION}")

# meson: include_default / args_default
set(include_default stdio.h stdlib.h stddef.h unistd.h sys/types.h sys/stat.h fcntl.h pthread.h)
set(CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)

#
# Feature detection, only available at libfuse compilation time, but not for
# application linking to libfuse.
#
fuse_cfg_set_quoted(private PACKAGE_VERSION "${PROJECT_VERSION_FULL}")

set(service_socket_dir   "${OPTION_SERVICE_SOCKET_DIR}")
set(service_socket_perms "${OPTION_SERVICE_SOCKET_PERMS}")
if(service_socket_dir STREQUAL "")
    set(service_socket_dir "/run/fuse")
endif()
if(service_socket_perms STREQUAL "")
    set(service_socket_perms "0220")
endif()
fuse_cfg_set(private        FUSE_SERVICE_SOCKET_DIR_RAW "${service_socket_dir}")
fuse_cfg_set_quoted(private FUSE_SERVICE_SOCKET_DIR     "${service_socket_dir}")
fuse_cfg_set(private        FUSE_SERVICE_SOCKET_PERMS   "${service_socket_perms}")
# For configure_file(@ONLY) of example/*.socket.in, which meson fills from
# private_cfg.
set(FUSE_SERVICE_SOCKET_DIR_RAW "${service_socket_dir}")
set(FUSE_SERVICE_SOCKET_PERMS   "${service_socket_perms}")

# Test for presence of some functions
foreach(func fork fstatat openat readlinkat pipe2
             splice vmsplice posix_fallocate fdatasync
             utimensat copy_file_range fallocate fspacectl
             faccessat)
    string(TOUPPER "HAVE_${func}" _var)
    check_symbol_exists(${func} "${include_default}" ${_var})
    fuse_cfg_set_bool(private ${_var} ${_var})
endforeach()

# Special case checks that need custom code (meson: special_funcs, cc.links)
check_c_source_compiles([=[
        #include <pthread.h>
        int main(void) {
            pthread_t thread = pthread_self();
            pthread_setname_np(thread, "test");
            return 0;
        }
]=] HAVE_PTHREAD_SETNAME_NP)
check_c_source_compiles([=[
        #include <unistd.h>
        #include <fcntl.h>
        #ifdef linux
        #include <linux/close_range.h>
        #endif
        int main(void) {
            unsigned int flags = CLOSE_RANGE_UNSHARE;
            return close_range(3, ~0U, flags);
        }
]=] HAVE_CLOSE_RANGE)
check_c_source_compiles([=[
	#include <syscall.h>
	#include <linux/mount.h>
	#include <unistd.h>
	#include <stdint.h>

	int main(int argc, char *argv[]) {
	  struct mnt_id_req req = {
	    .size = sizeof(struct mnt_id_req),
		  .mnt_id = LSMT_ROOT,
	  };
	  uint64_t mnt_ids[1];

	  int n = syscall(SYS_listmount, &req, &mnt_ids, 1, 0);
	  if (n == -1) {
	    return -1;
	  }
	}
]=] HAVE_LISTMOUNT)
foreach(_var HAVE_PTHREAD_SETNAME_NP HAVE_CLOSE_RANGE HAVE_LISTMOUNT)
    fuse_cfg_set_bool(private ${_var} ${_var})
endforeach()

# New Linux mount API (fsopen/fsconfig/fsmount/move_mount): the kernel
# syscalls landed in 5.2, but libc wrapper functions can lag behind (e.g.
# glibc added them only in 2.36). Test kernel header support and libc
# wrapper support separately, so the direct syscall() fallback wrappers
# in mount_i_linux.h are used whenever libc lacks them.
#
# -Werror=implicit-function-declaration: without it, a missing declaration
# only warns on some compilers, and the link can still silently succeed
# against a same-named symbol the libc happens to export.
set(_saved_flags "${CMAKE_REQUIRED_FLAGS}")
string(APPEND CMAKE_REQUIRED_FLAGS " -Werror=implicit-function-declaration")
check_c_source_compiles([=[
    #include <linux/mount.h>
    int main(void) {
        int x = FSOPEN_CLOEXEC | FSMOUNT_CLOEXEC | MOVE_MOUNT_F_EMPTY_PATH;
        int y = FSCONFIG_SET_STRING | FSCONFIG_CMD_CREATE;
        int z = MOUNT_ATTR_RDONLY | MOUNT_ATTR_NOSUID | MOUNT_ATTR_NODEV |
                MOUNT_ATTR_NOEXEC | MOUNT_ATTR_NOATIME;
        return x + y + z;
    }
]=] HAVE_NEW_MOUNT_API_HEADERS)
check_c_source_compiles([=[
	#define _GNU_SOURCE
	#include <sys/mount.h>
	#include <linux/mount.h>
	#include <unistd.h>
	#include <fcntl.h>

	int main(void) {
	    int fsfd = fsopen("fuse", FSOPEN_CLOEXEC);
	    int res = fsconfig(fsfd, FSCONFIG_SET_STRING, "source", "test", 0);
	    int mntfd = fsmount(fsfd, FSMOUNT_CLOEXEC, 0);
	    res = move_mount(mntfd, "", AT_FDCWD, "/mnt", MOVE_MOUNT_F_EMPTY_PATH);
	    return 0;
	}
]=] HAVE_NEW_MOUNT_API_LIBC_FUNCS)
set(CMAKE_REQUIRED_FLAGS "${_saved_flags}")

set(HAVE_NEW_MOUNT_API ${HAVE_NEW_MOUNT_API_HEADERS})
fuse_cfg_set_bool(private HAVE_NEW_MOUNT_API HAVE_NEW_MOUNT_API)
if(HAVE_NEW_MOUNT_API_HEADERS AND NOT HAVE_NEW_MOUNT_API_LIBC_FUNCS)
    fuse_cfg_set_bool(private NEED_NEW_MOUNT_API_SYSCALL_WRAPPERS TRUE)
    message(STATUS "libc lacks new mount API wrapper functions, using direct syscalls")
endif()

# Headers checks
check_include_file(sys/xattr.h    HAVE_SYS_XATTR_H)
check_include_file(linux/limits.h HAVE_LINUX_LIMITS_H)
fuse_cfg_set_bool(private HAVE_SYS_XATTR_H    HAVE_SYS_XATTR_H)
fuse_cfg_set_bool(private HAVE_LINUX_LIMITS_H HAVE_LINUX_LIMITS_H)

# Regular function checks
check_symbol_exists(setxattr  sys/xattr.h HAVE_SETXATTR)
check_symbol_exists(iconv     iconv.h     HAVE_ICONV)
check_symbol_exists(backtrace execinfo.h  HAVE_BACKTRACE)
check_symbol_exists(statx     sys/stat.h  HAVE_STATX)
foreach(_var HAVE_SETXATTR HAVE_ICONV HAVE_BACKTRACE HAVE_STATX)
    fuse_cfg_set_bool(private ${_var} ${_var})
endforeach()

# Struct member checks
check_struct_has_member("struct stat" st_atim      "${include_default}" HAVE_STRUCT_STAT_ST_ATIM)
check_struct_has_member("struct stat" st_atimespec "${include_default}" HAVE_STRUCT_STAT_ST_ATIMESPEC)
fuse_cfg_set_bool(private HAVE_STRUCT_STAT_ST_ATIM      HAVE_STRUCT_STAT_ST_ATIM)
fuse_cfg_set_bool(private HAVE_STRUCT_STAT_ST_ATIMESPEC HAVE_STRUCT_STAT_ST_ATIMESPEC)

# Variable declaration checks
check_symbol_exists(environ unistd.h HAVE_ENVIRON_DECL)
fuse_cfg_set_bool(private HAVE_ENVIRON_DECL HAVE_ENVIRON_DECL)

fuse_cfg_set_bool(private USDT_ENABLED OPTION_ENABLE_USDT)

# What a session starts with; fuse_session_set_sync_init() still overrides it.
if(OPTION_SYNC_INIT STREQUAL "auto")
    fuse_cfg_set(private FUSE_SYNC_INIT_DEFAULT FUSE_SYNC_INIT_AUTO)
elseif(OPTION_SYNC_INIT STREQUAL "always")
    fuse_cfg_set(private FUSE_SYNC_INIT_DEFAULT FUSE_SYNC_INIT_ENABLED)
elseif(OPTION_SYNC_INIT STREQUAL "never")
    fuse_cfg_set(private FUSE_SYNC_INIT_DEFAULT FUSE_SYNC_INIT_DISABLED)
else()
    message(FATAL_ERROR "OPTION_SYNC_INIT must be auto, always or never, not '${OPTION_SYNC_INIT}'")
endif()

# Check for liburing with SQE128 and fixed-buffer uring_cmd support.
# IORING_URING_CMD_FIXED and sqe->uring_cmd_flags landed a release after
# IORING_SETUP_SQE128, so testing only the latter leaves headers that pass the
# probe and then fail to build lib/fuse_uring.c.
set(HAVE_URING FALSE)
if(OPTION_ENABLE_IO_URING)
    pkg_check_modules(LIBURING IMPORTED_TARGET liburing)
    if(LIBURING_FOUND)
        set(CMAKE_REQUIRED_LIBRARIES PkgConfig::LIBURING)
        check_c_source_compiles([=[
#include <liburing.h>
#include <stdio.h>
int main(void) {
    struct io_uring ring;
    struct io_uring_sqe sqe;
    int ret = io_uring_queue_init(1, &ring, 0);
#ifndef IORING_SETUP_SQE128
#error "No SQE128 support"
#endif
#ifndef IORING_URING_CMD_FIXED
#error "No uring_cmd fixed buffer support"
#endif
    sqe.uring_cmd_flags = 0;
    return ret + sqe.uring_cmd_flags;
}
]=] LIBURING_SQE128_CMD_FIXED)
        unset(CMAKE_REQUIRED_LIBRARIES)
        if(LIBURING_SQE128_CMD_FIXED)
            set(HAVE_URING TRUE)
            fuse_cfg_set_bool(private HAVE_URING TRUE)
        endif()
    endif()
endif()

# A custom io peer might not be a kernel and can forge requests libfuse parses
# without bounds checks. Off unless a build asks for it.
set(HAVE_CUSTOM_IO ${OPTION_ENABLE_CUSTOM_IO})
fuse_cfg_set_bool(private HAVE_CUSTOM_IO HAVE_CUSTOM_IO)
if(HAVE_CUSTOM_IO)
    message(WARNING "OPTION_ENABLE_CUSTOM_IO lets a peer that might not be a kernel send "
                    "requests that libfuse parses without bounds checks, so a "
                    "forged request can crash or corrupt the filesystem process - "
                    "see doc/README.custom-io.")
endif()

# Check for systemd support
#
# Only the SD_LISTEN_FDS_START macro is used, so the header alone decides
# this - a link test would additionally demand libsystemd, which nothing
# here links against.
check_include_file(systemd/sd-daemon.h HAVE_SYSTEMD_HEADERS)
fuse_cfg_set_bool(private HAVE_SYSTEMD_HEADERS HAVE_SYSTEMD_HEADERS)

# Only systemd.pc names the unit directory, and it might ship in a package of
# its own (Debian: systemd-dev); the libsystemd.pc installed with the headers
# does not carry it. So fall back to looking for the directory itself.
set(systemd_system_unit_dir "${OPTION_SYSTEMD_SYSTEM_UNIT_DIR}")
if(systemd_system_unit_dir STREQUAL "")
    pkg_get_variable(systemd_system_unit_dir systemd systemd_system_unit_dir)
    if(systemd_system_unit_dir STREQUAL "")
        # second path for distros without a merged /usr
        foreach(_dir /usr/lib/systemd/system /lib/systemd/system)
            if(IS_DIRECTORY "${_dir}")
                set(systemd_system_unit_dir "${_dir}")
                break()
            endif()
        endforeach()
    endif()
endif()

set(HAVE_SYSTEMD FALSE)
set(HAVE_SERVICEMOUNT FALSE)
if(systemd_system_unit_dir STREQUAL "")
    message(WARNING "systemd service support will not be built: systemd unit directory not found")
elseif(NOT HAVE_SYSTEMD_HEADERS)
    message(WARNING "systemd service support will not be built: systemd headers (libsystemd-dev) not found")
else()
    fuse_cfg_set_quoted(private SYSTEMD_SYSTEM_UNIT_DIR "${systemd_system_unit_dir}")
    set(HAVE_SYSTEMD TRUE)
    set(HAVE_SERVICEMOUNT TRUE)
    fuse_cfg_set_bool(private HAVE_SYSTEMD TRUE)
    fuse_cfg_set_bool(private HAVE_SERVICEMOUNT TRUE)
endif()

#
# Compiler configuration
#
# meson: warning_level=2 adds -Wall -Wextra for every language.
#
# Deliberate divergence: meson.build also passes -Wno-sign-compare, and
# -Wno-unused-result on compilers that warn about a (void) cast of a
# warn_unused_result call. This build suppresses neither; the code is kept
# free of those warnings instead.
add_compile_options(-Wall -Wextra)
add_compile_options(-D_REENTRANT -DHAVE_LIBFUSE_PRIVATE_CONFIG_H
                    -D_FILE_OFFSET_BITS=64
                    -Wmissing-declarations -Wwrite-strings
                    -fno-strict-aliasing)
add_compile_options($<$<COMPILE_LANGUAGE:C>:-Wstrict-prototypes>
                    $<$<COMPILE_LANGUAGE:CXX>:-D_GNU_SOURCE>)

# meson: b_asneeded=true is the default for every link
add_link_options(-Wl,--as-needed)

# Checks below compile only, never link (meson: cc.compiles); CMake's
# check_c_source_compiles links unless the try_compile target is a library.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# It is hard to detect if the libc supports versioned symbols. Only gnu-libc
# seems to provide that, but then glibc is the main target for libfuse, so
# enable it by default
set(versioned_symbols 1)

# This is an attempt to detect if another libc is used.
set(CMAKE_REQUIRED_FLAGS "-O0")
check_c_source_compiles([=[
int main(void) {
#if (defined(__UCLIBC__) || defined(__APPLE__))
#error /* libc does not have versioned symbols */
#endif
    return 0;
}
]=] LIBC_HAS_VERSIONED_SYMBOLS)
if(NOT LIBC_HAS_VERSIONED_SYMBOLS)
    set(versioned_symbols 0)
endif()

# The detection can be overridden, which is useful for other (above unhandled)
# libcs and also especially useful for testing
if(OPTION_DISABLE_LIBC_SYMBOL_VERSION)
    set(versioned_symbols 0)
endif()

if(versioned_symbols)
    message(STATUS "Enabling versioned libc symbols")
    fuse_cfg_set(public LIBFUSE_BUILT_WITH_VERSIONED_SYMBOLS 1)

    # gcc-10 and newer support the symver attribute which we need to use if we
    # want to support LTO. Attributes that __has_attribute() does not know
    # return true, giving a false positive, so try to build with it instead.
    set(CMAKE_REQUIRED_FLAGS "-O0 -Werror")
    check_c_source_compiles([=[
     __attribute__ ((symver ("test@TEST")))
     void foo(void) {
     }

     int main(void) {
         return 0;
     }
]=] HAVE_SYMVER_ATTRIBUTE)
    if(HAVE_SYMVER_ATTRIBUTE)
        message(STATUS "Compiler supports symver attribute")
        add_compile_options($<$<COMPILE_LANGUAGE:C>:-DHAVE_SYMVER_ATTRIBUTE>)
    else()
        message(STATUS "Compiler does not support symver attribute")
    endif()
else()
    message(STATUS "Disabling versioned libc symbols")
endif()
unset(CMAKE_REQUIRED_FLAGS)
unset(CMAKE_TRY_COMPILE_TARGET_TYPE)

# Older versions of musl libc don't unescape entries in /etc/mtab
# Try to detect this behaviour, and work around, if necessary.
# The program is meson's, verbatim: a bracket argument keeps the backslashes,
# so the C string holds the escaped "\040" and "\011" that /etc/mtab would.
if(NOT CMAKE_CROSSCOMPILING)
    set(_getmntent_src "${PROJECT_BINARY_DIR}/CMakeFiles/detect_getmntent_needs_unescape.c")
    file(WRITE "${_getmntent_src}" [=[
#define _GNU_SOURCE
#include <mntent.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define dir_space_tab "dir\\040space\\011tab"

int main()
{
    const char *fake_mtab = "name " dir_space_tab " type opts 0 0\n";
    FILE *f = fmemopen((void *)fake_mtab, strlen(fake_mtab) + 1, "r");
    struct mntent *entp = getmntent(f);
    fclose(f);
    if(NULL == entp)
        exit(EXIT_FAILURE);
    if (0 == strcmp(entp->mnt_dir, dir_space_tab))
        printf("needs escaping\n");
    else
        printf("no need to escape\n");
}
]=])
    try_run(_getmntent_run _getmntent_compiled
            "${PROJECT_BINARY_DIR}/CMakeFiles/detect_getmntent"
            "${_getmntent_src}"
            RUN_OUTPUT_VARIABLE _getmntent_out)
    string(STRIP "${_getmntent_out}" _getmntent_out)
    if(_getmntent_compiled AND _getmntent_run EQUAL 0
       AND _getmntent_out STREQUAL "needs escaping")
        message(STATUS "getmntent does not unescape")
        add_compile_options($<$<COMPILE_LANGUAGE:C>:-DGETMNTENT_NEEDS_UNESCAPING>)
    endif()
endif()

# Write private test results into fuse_config.h (stored in build directory)
fuse_cfg_write(private "${PROJECT_BINARY_DIR}/fuse_config.h")

# Write the test results, installed with the package, symbols need to be
# properly prefixed to avoid symbol (define) conflicts
fuse_cfg_write(public "${PROJECT_BINARY_DIR}/libfuse_config.h")
install(FILES "${PROJECT_BINARY_DIR}/libfuse_config.h"
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/fuse3")

# '.' will refer to current build directory, which contains config.h
set(INCLUDE_DIRS "${PROJECT_SOURCE_DIR}/include"
                 "${PROJECT_SOURCE_DIR}/lib"
                 "${PROJECT_BINARY_DIR}")

# Common dependencies (meson: thread_dep = dependency('threads'), which
# compiles and links with -pthread)
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

#
# Read build files from sub-directories
#
set(build_utils FALSE)
if(OPTION_BUILD_UTILS AND NOT FUSE_PLATFORM MATCHES "bsd$"
   AND NOT FUSE_PLATFORM STREQUAL "dragonfly")
    set(build_utils TRUE)
endif()

add_subdirectory(lib)
add_subdirectory(include)
if(build_utils)
    add_subdirectory(util)
    add_subdirectory(doc)
endif()
if(OPTION_BUILD_EXAMPLES)
    add_subdirectory(example)
endif()
if(OPTION_BUILD_TESTS)
    enable_testing()
    add_subdirectory(test)
endif()

#
# Configuration summary
#
function(fuse_summary_line label value)
    if(value)
        set(value "true")
    else()
        set(value "false")
    endif()
    string(LENGTH "${label}" _len)
    math(EXPR _pad "26 - ${_len}")
    string(REPEAT " " ${_pad} _spaces)
    message(STATUS "    ${label}${_spaces}: ${value}")
endfunction()
if(systemd_system_unit_dir STREQUAL "")
    set(_unit_dir_summary "(not found)")
else()
    set(_unit_dir_summary "${systemd_system_unit_dir}")
endif()
message(STATUS "")
message(STATUS "  Build Options")
fuse_summary_line("Examples" "${OPTION_BUILD_EXAMPLES}")
fuse_summary_line("Tests"    "${OPTION_BUILD_TESTS}")
fuse_summary_line("Utils"    "${OPTION_BUILD_UTILS}")
message(STATUS "  Features")
fuse_summary_line("io_uring support"        "${HAVE_URING}")
fuse_summary_line("custom io support"       "${HAVE_CUSTOM_IO}")
fuse_summary_line("USDT tracing"            "${OPTION_ENABLE_USDT}")
fuse_summary_line("systemd service support" "${HAVE_SYSTEMD}")
fuse_summary_line("systemd headers"         "${HAVE_SYSTEMD_HEADERS}")
message(STATUS "    systemd unit directory    : ${_unit_dir_summary}")
message(STATUS "")
