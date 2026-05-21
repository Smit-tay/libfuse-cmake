# CMake equivalent of libfuse's meson.build
# Every attempt has been made to match all the functionality provided by meson
# Use at your own risk

cmake_minimum_required (VERSION 3.12.0)
set (CMAKE_VERBOSE_MAKEFILE FALSE)

add_library(fuse3 SHARED)

# Source files are PRIVATE: they are libfuse's implementation, not part of
# its interface. With PUBLIC, every executable linking fuse3 would inherit
# these source files and recompile the entire library into itself.
# Header files (fuse_i.h, fuse_misc.h, util.h) are not listed here because
# target_sources is for files to be compiled - CMake ignores .h files in
# this list anyway.
target_sources(fuse3 PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/fuse.c
    ${CMAKE_CURRENT_SOURCE_DIR}/fuse_daemonize.c
    ${CMAKE_CURRENT_SOURCE_DIR}/fuse_loop.c
    ${CMAKE_CURRENT_SOURCE_DIR}/fuse_loop_mt.c
    ${CMAKE_CURRENT_SOURCE_DIR}/fuse_lowlevel.c
    ${CMAKE_CURRENT_SOURCE_DIR}/fuse_opt.c
    ${CMAKE_CURRENT_SOURCE_DIR}/fuse_signals.c
    ${CMAKE_CURRENT_SOURCE_DIR}/buffer.c
    ${CMAKE_CURRENT_SOURCE_DIR}/cuse_lowlevel.c
    ${CMAKE_CURRENT_SOURCE_DIR}/helper.c
    ${CMAKE_CURRENT_SOURCE_DIR}/modules/subdir.c
    ${CMAKE_CURRENT_SOURCE_DIR}/mount_util.c
    ${CMAKE_CURRENT_SOURCE_DIR}/fuse_log.c
    ${CMAKE_CURRENT_SOURCE_DIR}/compat.c
    ${CMAKE_CURRENT_SOURCE_DIR}/util.c)


if(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    target_sources(fuse3 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/mount.c)
    if(HAVE_NEW_MOUNT_API)
        target_sources(fuse3 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/mount_fsmount.c)
    endif()
else()
    target_sources(fuse3 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/mount_bsd.c)

endif()

if(HAVE_ICONV)
  target_sources(fuse3 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/modules/iconv.c)
endif()

# Include dirs are PUBLIC: consumers of libfuse need <fuse.h> on their
# include path. This is the one case where PUBLIC is genuinely correct.
target_include_directories(fuse3 PUBLIC ${INCLUDE_DIRS})

target_link_libraries(fuse3 PRIVATE ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})

if(${CMAKE_SYSTEM_NAME} MATCHES "netbsd")
   # Totally unsure about netbsd, included for consistency - but commented
   # find_package(perfuse)
   # if (PERFUSE_FOUND)
   #    target_link_libraries(fuse3 PRIVATE PERFUSE_LIBS)
   # endif()
   # find_package(puffs)
   # if (PUFFS_FOUND)
   #    target_link_libraries(fuse3 PRIVATE PUFFS_LIBS)
   # endif()
else()
   # Required for clock_gettime before glibc 2.17
   find_library (RT_LIBRARIES rt
      PATHS /usr/local/lib /usr/lib /lib ${CMAKE_EXTRA_LIBRARIES}
   )
   if(RT_LIBRARIES)
      target_link_libraries(fuse3 PRIVATE ${RT_LIBRARIES})
   endif()
endif()

set(BINDIR "bindir" CACHE STRING "mount path subdirectory default: [bindir]")
set(FUSERMOUNT_DIR "${CMAKE_INSTALL_PREFIX}/${BINDIR}" CACHE STRING "The mount path (not exactly sure what this is)" )

# PACKAGE_VERSION removed - now provided by fuse_config.h (mirrors meson,
# which sets PACKAGE_VERSION via private_cfg, not via compile flags).
# Both definitions are PRIVATE: FUSE_USE_VERSION must NOT leak to consumers
# (applications set their own via #define before #include <fuse.h>), and
# FUSERMOUNT_DIR is a libfuse-internal build detail.
target_compile_definitions(fuse3 PRIVATE FUSE_USE_VERSION=317
                                         FUSERMOUNT_DIR=\"${FUSERMOUNT_DIR}\")

# Should be changed to target_link_options (requires 3.13.X)
set (CMAKE_SHARED_LINKER_FLAGS "-Wl,--version-script,${CMAKE_CURRENT_SOURCE_DIR}/fuse_versionscript")
#target_compile_options(fuse3 PUBLIC -Wl,--version-script,${CMAKE_CURRENT_SOURCE_DIR}/fuse_versionscript)
