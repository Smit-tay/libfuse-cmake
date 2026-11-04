# CMake equivalent of util/meson.build

# meson: join_paths(get_option('prefix'), get_option('sysconfdir'), 'fuse.conf')
set(fuseconf_path "${CMAKE_INSTALL_FULL_SYSCONFDIR}/fuse.conf")

add_executable(fusermount3
    fusermount.c ../lib/mount_util.c ../lib/mount_fsmount.c
    ../lib/fuse_log.c ../lib/util.c fuser_conf.c)
target_include_directories(fusermount3 PRIVATE ${INCLUDE_DIRS})
target_compile_definitions(fusermount3 PRIVATE FUSE_CONF="${fuseconf_path}")

set(mount_service_sources)
set(mount_service_cflags)
if(HAVE_SERVICEMOUNT)
    list(APPEND mount_service_sources mount_service.c ../lib/mount_util.c fuser_conf.c)
    if(HAVE_NEW_MOUNT_API)
        list(APPEND mount_service_sources ../lib/mount_fsmount.c)
    endif()
    list(APPEND mount_service_cflags
         FUSE_CONF="${fuseconf_path}"
         FUSERVICEMOUNT_DIR="${CMAKE_INSTALL_FULL_SBINDIR}")

    add_executable(fuservicemount3 fuservicemount.c ${mount_service_sources})
    target_include_directories(fuservicemount3 PRIVATE ${INCLUDE_DIRS})
    target_link_libraries(fuservicemount3 PRIVATE fuse3)
    target_compile_definitions(fuservicemount3 PRIVATE
                               FUSE_USE_VERSION=319 ${mount_service_cflags})
    # A setuid run ignores $ORIGIN; CMake's build RPATH is already absolute.
endif()

add_executable(mount.fuse3 mount.fuse.c ${mount_service_sources})
target_include_directories(mount.fuse3 PRIVATE ${INCLUDE_DIRS})
target_link_libraries(mount.fuse3 PRIVATE fuse3)
target_compile_definitions(mount.fuse3 PRIVATE
                           FUSE_USE_VERSION=319 ${mount_service_cflags})

#
# Installation
#
# Installed 0755 like meson; install_helper.sh then makes fusermount3 (and
# fuservicemount3) setuid root when OPTION_USEROOT is on.
install(TARGETS fusermount3 RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(TARGETS mount.fuse3 RUNTIME DESTINATION ${CMAKE_INSTALL_SBINDIR})
if(HAVE_SERVICEMOUNT)
    install(TARGETS fuservicemount3 RUNTIME DESTINATION ${CMAKE_INSTALL_SBINDIR})
endif()

set(udevrulesdir "${OPTION_UDEVRULESDIR}")
if(udevrulesdir STREQUAL "")
    pkg_get_variable(_udevdir udev udevdir)
    if(NOT _udevdir STREQUAL "")
        set(udevrulesdir "${_udevdir}/rules.d")
    endif()
endif()

if(udevrulesdir STREQUAL "")
    message(WARNING "could not determine udevdir, udev.rules will not be installed")
endif()

if(OPTION_USEROOT)
    set(useroot true)
else()
    set(useroot false)
endif()

# meson: meson.add_install_script('install_helper.sh', ...)
# The script reads $DESTDIR itself; `cmake --install` and `make install`
# pass the caller's environment through.
install(CODE "
    message(STATUS \"Running custom install script '${CMAKE_CURRENT_SOURCE_DIR}/install_helper.sh'\")
    execute_process(
        COMMAND \"${CMAKE_COMMAND}\" -E env \"MESON_SOURCE_ROOT=${PROJECT_SOURCE_DIR}\"
                \"${CMAKE_CURRENT_SOURCE_DIR}/install_helper.sh\"
                \"${CMAKE_INSTALL_FULL_SYSCONFDIR}\"
                \"${CMAKE_INSTALL_FULL_BINDIR}\"
                \"${udevrulesdir}\"
                \"${useroot}\"
                \"${OPTION_INITSCRIPTDIR}\"
                \"${CMAKE_INSTALL_FULL_SBINDIR}\"
        RESULT_VARIABLE _fuse_install_helper_rc)
    if(NOT _fuse_install_helper_rc EQUAL 0)
        message(FATAL_ERROR \"util/install_helper.sh failed (\${_fuse_install_helper_rc})\")
    endif()
")
