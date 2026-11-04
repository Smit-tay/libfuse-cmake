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

# meson's cc.find_library() tries to link -l<name>, so it also finds a static
# stub such as glibc's librt.a; check_library_exists() does the same, where
# find_library() would only look for a shared object.
include(CheckLibraryExists)

# fuse3.pc's Libs.private, in meson's order: libraries_private first, then
# the library's dependencies.
set(pc_libs_private -ldl -pthread)
set(pc_requires_private "")

if(HAVE_ICONV)
    target_sources(fuse3 PRIVATE modules/iconv.c)
    check_library_exists(iconv iconv "" HAVE_LIBICONV)
    if(HAVE_LIBICONV)
        target_link_libraries(fuse3 PRIVATE iconv)
        list(APPEND pc_libs_private -liconv)
    endif()
endif()

if(HAVE_URING)
    target_sources(fuse3 PRIVATE fuse_uring.c)
    target_link_libraries(fuse3 PRIVATE PkgConfig::LIBURING)
    set(pc_requires_private "Requires.private: liburing\n")
endif()

target_link_libraries(fuse3 PRIVATE ${CMAKE_DL_LIBS})

if(FUSE_PLATFORM MATCHES "^netbsd")
    find_library(PERFUSE_LIBRARY perfuse REQUIRED)
    find_library(PUFFS_LIBRARY puffs REQUIRED)
    target_link_libraries(fuse3 PRIVATE ${PERFUSE_LIBRARY} ${PUFFS_LIBRARY})
    list(APPEND pc_libs_private -lperfuse -lpuffs)
else()
    # Required for clock_gettime before glibc 2.17
    check_library_exists(rt clock_gettime "" HAVE_LIBRT)
    if(NOT HAVE_LIBRT)
        message(FATAL_ERROR "librt not found (meson: cc.find_library('rt') is required)")
    endif()
    target_link_libraries(fuse3 PRIVATE rt)
    list(APPEND pc_libs_private -lrt)
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

#
# Installation
#
install(TARGETS fuse3
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})

# meson: pkg.generate(...) - fuse3.pc. Directories are written relative to
# ${prefix} when they lie inside it, as meson does.
foreach(_dir LIBDIR INCLUDEDIR)
    string(TOLOWER "${_dir}" _name)
    if(IS_ABSOLUTE "${CMAKE_INSTALL_${_dir}}")
        set(pc_${_name} "${CMAKE_INSTALL_${_dir}}")
    else()
        set(pc_${_name} "\${prefix}/${CMAKE_INSTALL_${_dir}}")
    endif()
endforeach()
set(pc_variables "")
if(HAVE_SERVICEMOUNT)
    set(pc_variables "\nservice_socket_dir=${service_socket_dir}\nservice_socket_perms=${service_socket_perms}\n")
endif()
list(JOIN pc_libs_private " " pc_libs_private)
configure_file(${PROJECT_SOURCE_DIR}/cmake/fuse3.pc.in
               ${CMAKE_CURRENT_BINARY_DIR}/fuse3.pc @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/fuse3.pc
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
