# CMake equivalent of doc/meson.build
#
# meson's install_man() picks the man<section> directory from the file
# extension; CMake has to be told.

if(NOT FUSE_PLATFORM MATCHES "bsd$" AND NOT FUSE_PLATFORM STREQUAL "dragonfly")
    install(FILES fusermount3.1 DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)
    install(FILES mount.fuse3.8 DESTINATION ${CMAKE_INSTALL_MANDIR}/man8)
endif()

if(HAVE_SERVICEMOUNT)
    install(FILES fuservicemount3.8 DESTINATION ${CMAKE_INSTALL_MANDIR}/man8)
endif()
