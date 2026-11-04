# CMake equivalent of lib/meson.build

add_library(fuse3 SHARED
    fuse.c fuse_loop.c fuse_loop_mt.c fuse_lowlevel.c fuse_opt.c
    fuse_signals.c buffer.c cuse_lowlevel.c helper.c modules/subdir.c
    mount_util.c fuse_log.c compat.c util.c fuse_daemonize.c)

if(FUSE_PLATFORM MATCHES "^linux")
    target_sources(fuse3 PRIVATE mount.c)
    if(HAVE_NEW_MOUNT_API)
        target_sources(fuse3 PRIVATE mount_fsmount.c)
    endif()
else()
    target_sources(fuse3 PRIVATE mount_bsd.c)
endif()

if(HAVE_SERVICEMOUNT)
    target_sources(fuse3 PRIVATE fuse_service.c)
else()
    target_sources(fuse3 PRIVATE fuse_service_stub.c)
endif()

# meson: libfuse_dep = declare_dependency(dependencies: deps) passes thread_dep
# on to everything built against libfuse.
target_link_libraries(fuse3 PUBLIC Threads::Threads)

if(HAVE_ICONV)
    target_sources(fuse3 PRIVATE modules/iconv.c)
    find_library(ICONV_LIBRARY iconv)
    if(ICONV_LIBRARY)
        target_link_libraries(fuse3 PRIVATE ${ICONV_LIBRARY})
    endif()
endif()

if(HAVE_URING)
    target_sources(fuse3 PRIVATE fuse_uring.c)
    target_link_libraries(fuse3 PRIVATE PkgConfig::LIBURING)
endif()

target_link_libraries(fuse3 PRIVATE ${CMAKE_DL_LIBS})

if(FUSE_PLATFORM MATCHES "^netbsd")
    find_library(PERFUSE_LIBRARY perfuse REQUIRED)
    find_library(PUFFS_LIBRARY puffs REQUIRED)
    target_link_libraries(fuse3 PRIVATE ${PERFUSE_LIBRARY} ${PUFFS_LIBRARY})
else()
    # Required for clock_gettime before glibc 2.17
    find_library(RT_LIBRARY rt)
    if(RT_LIBRARY)
        target_link_libraries(fuse3 PRIVATE ${RT_LIBRARY})
    endif()
endif()

# meson: fusermount_path = join_paths(get_option('prefix'), get_option('bindir'))
set(fusermount_path "${CMAKE_INSTALL_FULL_BINDIR}")

target_include_directories(fuse3 PUBLIC ${INCLUDE_DIRS})
target_compile_definitions(fuse3 PRIVATE
    FUSE_USE_VERSION=319
    FUSERMOUNT_DIR="${fusermount_path}")

# meson: version: base_version, soversion: '4'
set_target_properties(fuse3 PROPERTIES
    VERSION   ${PROJECT_VERSION}
    SOVERSION 4
    LINK_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/fuse_versionscript")

# meson: link_args, plus its b_lundef=true default for shared libraries
target_link_options(fuse3 PRIVATE
    "-Wl,--version-script,${CMAKE_CURRENT_SOURCE_DIR}/fuse_versionscript"
    -Wl,--no-undefined)
