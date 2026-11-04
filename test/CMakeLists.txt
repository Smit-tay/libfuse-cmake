# CMake equivalent of test/meson.build

# Compile helper programs.
#
# CMake target names are global, and example/ already has `hello` and
# `hello_ll`, so test programs are given a test_* target name where needed
# and OUTPUT_NAME restores the file name run-tests.py looks for in
# <build>/test.
set(test_targets)

# meson: include_directories + link_with: [ libfuse ] + thread_dep
foreach(prog test_write_cache test_setattr test_api_30 hello hello_ll)
    if(prog MATCHES "^test_")
        set(tgt ${prog})
    else()
        set(tgt test_${prog})
    endif()
    add_executable(${tgt} ${prog}.c)
    set_target_properties(${tgt} PROPERTIES OUTPUT_NAME ${prog})
    target_include_directories(${tgt} PRIVATE ${INCLUDE_DIRS})
    target_link_libraries(${tgt} PRIVATE fuse3 Threads::Threads)
    list(APPEND test_targets ${tgt})
endforeach()

# meson: include_directories only, not linked with libfuse
foreach(prog test_syscalls readdir_inode)
    add_executable(${prog} ${prog}.c)
    target_include_directories(${prog} PRIVATE ${INCLUDE_DIRS})
    list(APPEND test_targets ${prog})
endforeach()

# meson: dependencies: [ libfuse_dep ] (and thread_dep, which fuse3 carries)
foreach(prog release_unlink_race passthrough-hl test_want_conversion
             test_signals test_teardown_watchdog test_deferred_reply_teardown
             test_abi test_secctx_splice test_stream test_loop_config)
    add_executable(${prog} ${prog}.c)
    target_include_directories(${prog} PRIVATE ${INCLUDE_DIRS})
    target_link_libraries(${prog} PRIVATE fuse3)
    list(APPEND test_targets ${prog})
endforeach()

add_executable(test_mount_flags
               test_mount_flags.c ../lib/mount_util.c ../lib/fuse_log.c)
target_include_directories(test_mount_flags PRIVATE ${INCLUDE_DIRS})
list(APPEND test_targets test_mount_flags)

# fuser_conf.h needs <sys/vfs.h>, so this follows util/ rather than being built
# everywhere.
# FUSE_CONF is relative here so the test can chdir to a directory of its own
# and have read_conf() pick up the file it just wrote there.
if(build_utils)
    add_executable(test_fuser_conf
                   test_fuser_conf.c ../util/fuser_conf.c
                   ../lib/mount_util.c ../lib/fuse_log.c ../lib/util.c)
    target_include_directories(test_fuser_conf PRIVATE
                               ${INCLUDE_DIRS} ${PROJECT_SOURCE_DIR}/util)
    target_compile_definitions(test_fuser_conf PRIVATE FUSE_CONF="fuse.conf")
    list(APPEND test_targets test_fuser_conf)
endif()

if(HAVE_SERVICEMOUNT)
    add_executable(test_service test_service.c)
    target_include_directories(test_service PRIVATE ${INCLUDE_DIRS})
    target_link_libraries(test_service PRIVATE fuse3)
    list(APPEND test_targets test_service)
endif()

if(NOT PROJECT_IS_TOP_LEVEL)
    # Skipped rather than run: the tests mount filesystems, which is not
    # something a parent project's ctest should do. Exit 77 is SKIP.
    find_package(Python3 COMPONENTS Interpreter)
    if(Python3_FOUND)
        add_test(NAME "libfuse is a subproject, skipping tests"
                 COMMAND ${Python3_EXECUTABLE} -c
                         "import sys; print('run them with test/run-tests.py --build-dir <builddir>', file=sys.stderr); sys.exit(77)")
        set_tests_properties("libfuse is a subproject, skipping tests"
                             PROPERTIES SKIP_RETURN_CODE 77)
    endif()
else()
    # The same definition works both as a regular user and under sudo:
    # `ctest` for the unprivileged subset, or `sudo -E ctest` to also exercise
    # the tests that require root (they pick the uid up at runtime).
    #
    # Nothing is copied into the build tree: the runner, its library and the
    # test scripts are read from the source dir, and the only build artefacts
    # a test needs are the binaries, which it reaches through --build-dir.
    #
    # No --run-dir: it defaults under /var/tmp/fuse-tests, and CI redirects
    # it with $FUSE_TEST_RUN_DIR so the logs outlive the build tree.
    set(runner ${CMAKE_CURRENT_SOURCE_DIR}/run-tests.py)
    add_test(NAME fuse-tests
             COMMAND ${runner} --build-dir ${PROJECT_BINARY_DIR})

    # The same tests over the other transport, labelled so a caller can ask
    # for exactly one of the two: `ctest -L io-uring` and `ctest -LE io-uring`.
    # It exits 77 -- ctest reports it as skipped -- where the fuse module has
    # io-uring disabled.
    add_test(NAME fuse-tests-io-uring
             COMMAND ${runner} --build-dir ${PROJECT_BINARY_DIR} --io-uring)

    # RUN_SERIAL: the runner does its own -j
    set_tests_properties(fuse-tests fuse-tests-io-uring PROPERTIES
                         TIMEOUT 1800
                         RUN_SERIAL TRUE
                         SKIP_RETURN_CODE 77)
    set_tests_properties(fuse-tests-io-uring PROPERTIES LABELS io-uring)
endif()

# `make check` / `ninja check`: build what the tests need, then run ctest.
# Closest match to `meson test`, which builds the test's `depends:` first.
add_custom_target(check
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    USES_TERMINAL)
add_dependencies(check ${test_targets})
