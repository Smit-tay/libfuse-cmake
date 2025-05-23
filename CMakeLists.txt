# CMake equivalent of libfuse's meson.build
# Every attempt has been made to match all the functionality provided by meson
# Use at your own risk

cmake_minimum_required (VERSION 3.12.0)
set (CMAKE_VERBOSE_MAKEFILE FALSE)

project (libfuse3
         VERSION 3.17.0
         DESCRIPTION "The CMake implementation of the Linux FUSE (Filesystem in Userspace) interface"
         HOMEPAGE_URL https://github.com/Smit-tay/libfuse-cmake
         LANGUAGES C CXX)

string(REPLACE "." ";" VERSION_LIST ${PROJECT_VERSION})
list(GET VERSION_LIST 0 FUSE_MAJOR_VERSION)
list(GET VERSION_LIST 1 FUSE_MINOR_VERSION)
list(GET VERSION_LIST 2 FUSE_HOTFIX_VERSION)


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
#            'cpp_std=c++11',
#            'warning_level=2',
#            ]
# And, like most things in meson, the documentation for warning level is
# essentially non-existent - took 15 minutes of searching to find this:
# warning_level 1 adds -Wall,
# warning_level 2 adds warning_level 1 + -Wextra,
# warning_level 3 adds warning_level 2 + -Wpedantic
#
# we do our best to follow suite:

if (NOT EXISTS ${CMAKE_BINARY_DIR}/CMakeCache.txt)
  if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "" FORCE)
  endif()
endif()

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# This needs to be looked at - is linux=1 necessary ?
add_compile_options("-Dlinux=1"
                    "-D_REENTRANT" "-DHAVE_CONFIG_H" "-D_GNU_SOURCE"
                    "-Wall" "-Wextra"
                    "-Wmissing-declarations" "-Wno-sign-compare" "-Wwrite-strings"
                    "-fno-strict-aliasing")
# C-specific compile options
# Apply these only to C targets or files
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wstrict-prototypes")                 

include(CheckIncludeFile)
include(CheckIncludeFiles)
include(CheckFunctionExists)
include(CheckSymbolExists)
include(CheckStructHasMember)

check_include_file("stdio.h"        HAVE_STDIO_H)
check_include_file("stdlib.h"       HAVE_STDLIB_H)
check_include_file("stddef.h"       HAVE_STDDEF_H)
check_include_file("unistd.h"       HAVE_UNISTD_H)
check_include_file("sys/types.h"    HAVE_SYS_TYPES_H)
check_include_file("sys/stat.h"     HAVE_SYS_STAT_H)
check_include_file("fcntl.h"        HAVE_FCNTL_H)

# meson.build does this:
#    args_default = [ '-D_GNU_SOURCE' ]
# then passes that to every "has_member()" call
# The equivalent in CMake is to set this variable
# before calling check_function_exists()
set(CMAKE_REQUIRED_DEFINITIONS "-D_GNU_SOURCE")

set(include_default "stdio.h;stdlib.h;stddef.h;unistd.h;sys/types.h;sys/stat.h;fcntl.h")

# Fork is actually implemented in the kernel.
# It is declared as an external in "unistd.h"
# Possibly because of that, testing with check_symbol_exists
# fails, so we use check_function_exists instead
check_function_exists("fork"                                HAVE_FORK)
check_function_exists("backtrace"                      HAVE_BACKTRACE)

check_symbol_exists("fstatat"         ${include_default}    HAVE_FSTATAT)
check_symbol_exists("openat"          ${include_default}    HAVE_OPENAT)
check_symbol_exists("readlinkat"      ${include_default}    HAVE_READLINKAT)
check_symbol_exists("pipe2"           ${include_default}    HAVE_PIPE2)
check_symbol_exists("splice"          ${include_default}    HAVE_SPLICE)
check_symbol_exists("vmsplice"        ${include_default}    HAVE_VMSPLICE)
check_symbol_exists("posix_fallocate" ${include_default}    HAVE_POSIX_FALLOCATE)
check_symbol_exists("fdatasync"       ${include_default}    HAVE_FDATASYNC)
check_symbol_exists("utimensat"       ${include_default}    HAVE_UTIMENSAT)
check_symbol_exists("copy_file_range" ${include_default}    HAVE_COPY_FILE_RANGE)
check_symbol_exists("fallocate"       ${include_default}    HAVE_FALLOCATE)
check_symbol_exists("close_range"     ${include_default}    HAVE_CLOSE_RANGE)
# For some reason the meson build checks these separately
check_symbol_exists("setxattr" "sys/xattr.h" HAVE_SETXATTR)
check_symbol_exists("iconv" "iconv.h" HAVE_ICONV)

CHECK_STRUCT_HAS_MEMBER("struct stat" st_atim sys/stat.h HAVE_STRUCT_STAT_ST_ATIM LANGUAGE C)
CHECK_STRUCT_HAS_MEMBER("struct stat" st_atimespec sys/stat.h HAVE_STRUCT_STAT_ST_ATIMESPEC LANGUAGE C)

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

CHECK_C_SOURCE_COMPILES("${CHECK_UNUSED_RESULT_WARNING}" CHECK_UNUSED_RESULT)
if(CHECK_UNUSED_RESULT)
  message(STATUS "Compiler warns about unused result even when casting to void")
  add_compile_options("-Wno-unused-result")
endif()

# meson build claims to check for symver support
# But, its check does not appear to actually check for support
# We do !
set(CHECK_SYMVER_SUPPORT_WARNING "
__attribute__ ((__symver__ (\"foo@VERS_1\"))) int foo_v1 (void) {
}
int main(void) {
    (void) foo_v1();
    return 0;
}")
CHECK_C_SOURCE_COMPILES("${CHECK_SYMVER_SUPPORT_WARNING}" CHECK_SYMVER_SUPPORT)
if(CHECK_SYMVER_SUPPORT)
    set(HAVE_SYMVER_ATTRIBUTE ON)
else()
    message(STATUS "Compiler does not support symver attribute")
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

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/lib)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/include)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/test)

option(OPTION_BUILD_UTILS "Also build utils and docs" ON)

if(OPTION_BUILD_UTILS)
  if(NOT ${CMAKE_SYSTEM_NAME} MATCHES "BSD" AND NOT  ${CMAKE_SYSTEM_NAME} MATCHES "DRAGONFLY" )
    message("Also building utils and docs")
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/util)
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/doc)
  endif()
else()
  message("NOT building utils and docs")
endif()

option(OPTION_BUILD_EXAMPLES "Also build examples" ON)
if(OPTION_BUILD_EXAMPLES)
  message("Also building examples")
  add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/example)
else()
  message("NOT building examples")
endif()

# For reasons - libfuse defines a public and a private config.
# I don't understand the purpose of differentiating
# So, I make them the same
configure_file (
    "${PROJECT_SOURCE_DIR}/config.h.in"
    "${PROJECT_BINARY_DIR}/fuse_config.h"
)
configure_file (
    "${PROJECT_SOURCE_DIR}/config.h.in"
    "${PROJECT_BINARY_DIR}/libfuse_config.h"
)
