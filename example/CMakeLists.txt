# CMake equivalent of example/meson.build

set(examples passthrough passthrough_fh
             hello hello_ll
             printcap ioctl_client ioctl_ll_client poll_client
             ioctl ioctl_ll cuse cuse_client)

if(NOT FUSE_PLATFORM MATCHES "bsd$" AND NOT FUSE_PLATFORM STREQUAL "dragonfly")
    list(APPEND examples passthrough_ll)

    if(HAVE_CUSTOM_IO)
        list(APPEND examples hello_ll_uds)
    endif()

    # According to Conrad Meyer <cem@freebsd.org>, FreeBSD doesn't
    # support mounting files, This is enforced in vfs_domount_first()
    # with the v_type != VDIR check.
    list(APPEND examples null)

    if(FUSE_PLATFORM MATCHES "linux$")
        configure_file(null.socket.in null.socket @ONLY)
    endif()
endif()

set(single_file_examples)

if(FUSE_PLATFORM MATCHES "linux$")
    list(APPEND single_file_examples service_ll)
    configure_file(service_ll.socket.in service_ll.socket @ONLY)

    list(APPEND single_file_examples service_hl)
    configure_file(service_hl.socket.in service_hl.socket @ONLY)
endif()

set(threaded_examples notify_inval_inode
                      invalidate_path
                      notify_store_retrieve
                      notify_inval_entry
                      poll
                      notify_prune)

# meson: dependencies: [ libfuse_dep ] - fuse3 carries Threads::Threads, so
# the threaded examples get thread_dep through it as well.
foreach(ex IN LISTS examples threaded_examples)
    add_executable(${ex} ${ex}.c)
    target_link_libraries(${ex} PRIVATE fuse3)
endforeach()

foreach(ex IN LISTS single_file_examples)
    add_executable(${ex} ${ex}.c single_file.c)
    target_link_libraries(${ex} PRIVATE fuse3)
endforeach()

# meson: if platform != 'dragonfly' and add_languages('cpp', required: false)
include(CheckLanguage)
check_language(CXX)
if(NOT FUSE_PLATFORM STREQUAL "dragonfly" AND CMAKE_CXX_COMPILER)
    enable_language(CXX)
    fuse_strip_ndebug(CXX)
    add_executable(passthrough_hp passthrough_hp.cc)
    target_link_libraries(passthrough_hp PRIVATE fuse3)
    # meson passes cpp_args: '-std=c++20'; CMAKE_CXX_STANDARD is already 20.
    add_executable(memfs_ll memfs_ll.cc)
    target_link_libraries(memfs_ll PRIVATE fuse3)
endif()

# TODO: Link passthrough_fh with ulockmgr if available
