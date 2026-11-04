# CMake equivalent of include/meson.build

set(fuse_headers fuse.h fuse_common.h fuse_lowlevel.h
                 fuse_opt.h cuse_lowlevel.h fuse_log.h
                 fuse_daemonize.h)

if(HAVE_SERVICEMOUNT)
    list(APPEND fuse_headers fuse_service.h)
endif()

install(FILES ${fuse_headers}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/fuse3)
