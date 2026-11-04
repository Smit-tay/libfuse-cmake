# CMake equivalent of doc/meson.build

install(FILES fusermount3.1 mount.fuse3.8
        DESTINATION ${CMAKE_INSTALL_MANDIR})

if(HAVE_SERVICEMOUNT)
    install(FILES fuservicemount3.8
            DESTINATION ${CMAKE_INSTALL_MANDIR})
endif()
