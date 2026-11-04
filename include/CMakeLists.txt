# CMake equivalent of include/meson.build
#
# The headers are listed here so the list matches meson's; installing them is
# not wired up yet (install(FILES ...) of fuse_headers).
set(fuse_headers fuse.h fuse_common.h fuse_lowlevel.h
                 fuse_opt.h cuse_lowlevel.h fuse_log.h
                 fuse_daemonize.h)

if(HAVE_SERVICEMOUNT)
    list(APPEND fuse_headers fuse_service.h)
endif()
