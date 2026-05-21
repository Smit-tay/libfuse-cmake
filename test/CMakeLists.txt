# CMake equivalent of libfuse's meson.build
# Every attempt has been made to match all the functionality provided by meson
# Use at your own risk

cmake_minimum_required (VERSION 3.21.0)
set (CMAKE_VERBOSE_MAKEFILE FALSE)

if( DEFINED NDEBUG )
    message(WARNING "NDEBUG is defined, you will almost definitely experience problems")
endif()

## Suppress noise common in test scaffolding. FUSE callback signatures,
# unused thread-helper functions when a test only exercises some paths,
# and option_spec[] structures referenced only when arguments are parsed -
# all show up as unused-* warnings under -Wall -Wextra. They're not
# defects; they're shape-of-the-API. Uninitialized warnings are kept
# (they catch real bugs).
add_compile_options(
    -Wno-unused-parameter
    -Wno-unused-variable
    -Wno-unused-function
    -Wno-unused-but-set-variable
    -Wno-unused-const-variable)

# The example/ subdirectory also builds an executable named `hello` (the
# canonical libfuse example). CMake target names are global, so we use a
# distinct CMake target name here and rely on OUTPUT_NAME to keep the
# on-disk binary called `hello` - the pytest harness expects that filename
# in the test build directory.
add_executable(test_hello)
set_target_properties(test_hello PROPERTIES OUTPUT_NAME hello)
target_sources(test_hello PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/hello.c)
target_include_directories(test_hello PUBLIC ${INCLUDE_DIRS})
target_link_libraries(test_hello fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable( test_setattr)
target_sources( test_setattr PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_setattr.c )
target_include_directories(test_setattr PUBLIC ${INCLUDE_DIRS})
target_link_libraries(test_setattr fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable( test_write_cache)
target_sources( test_write_cache PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_write_cache.c )
target_include_directories(test_write_cache PUBLIC ${INCLUDE_DIRS})
target_link_libraries(test_write_cache fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable(test_syscalls)
target_sources(test_syscalls PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_syscalls.c)
target_include_directories(test_syscalls PUBLIC ${INCLUDE_DIRS})
# Intentionally NOT linked against fuse3 or pthreads: test_syscalls exercises
# kernel syscalls directly and must not pull in libfuse. Matches meson.build,
# which uses only include_directories for this target.
#target_link_libraries(test_syscalls fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable(readdir_inode)
target_sources(readdir_inode PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/readdir_inode.c)
target_include_directories(readdir_inode PUBLIC ${INCLUDE_DIRS})
target_link_libraries(readdir_inode fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable(release_unlink_race)
target_sources(release_unlink_race PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/release_unlink_race.c)
target_include_directories(release_unlink_race PUBLIC ${INCLUDE_DIRS})
target_link_libraries(release_unlink_race fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable(test_want_conversion)
target_sources(test_want_conversion PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_want_conversion.c)
target_include_directories(test_want_conversion PUBLIC ${INCLUDE_DIRS})
target_link_libraries(test_want_conversion fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable(test_signals)
target_sources(test_signals PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_signals.c)
target_include_directories(test_signals PUBLIC ${INCLUDE_DIRS})
target_link_libraries(test_signals fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable(test_teardown_watchdog)
target_sources(test_teardown_watchdog PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_teardown_watchdog.c)
target_include_directories(test_teardown_watchdog PUBLIC ${INCLUDE_DIRS})
target_link_libraries(test_teardown_watchdog fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable(test_abi)
target_sources(test_abi PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_abi.c)
target_include_directories(test_abi PUBLIC ${INCLUDE_DIRS})
target_link_libraries(test_abi fuse3 ${CMAKE_THREAD_LIBS_INIT})

add_executable(test_loop_config)
target_sources(test_loop_config PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_loop_config.c)
target_include_directories(test_loop_config PUBLIC ${INCLUDE_DIRS})
target_link_libraries(test_loop_config fuse3 ${CMAKE_THREAD_LIBS_INIT})

# Collect all test executables for the pytest dependency below.
# Note: test_hello is the CMake target name; OUTPUT_NAME makes the on-disk
# binary `hello` (see add_executable above).
set(TEST_EXECUTABLES
    test_hello test_setattr test_write_cache test_syscalls readdir_inode
    release_unlink_race test_want_conversion test_signals
    test_teardown_watchdog test_abi test_loop_config)

set(TEST_SCRIPTS conftest.py pytest.ini test_examples.py util.py
                 test_ctests.py test_custom_io.py test_mount_state.py)

add_custom_target(test_scripts ALL)
foreach(TEST_SCRIPT ${TEST_SCRIPTS})
  add_custom_command(TARGET test_scripts PRE_BUILD
                     COMMAND ${CMAKE_COMMAND} -E
                         copy ${CMAKE_CURRENT_SOURCE_DIR}/${TEST_SCRIPT} ${CMAKE_CURRENT_BINARY_DIR}/.)
endforeach()

if(NOT PROJECT_IS_TOP_LEVEL)
    # libfuse is being consumed as a subproject; skip the real test suite.
    # Mirrors meson.is_subproject() branch which builds wrong_command with
    # -DMESON_IS_SUBPROJECT and registers it as the only test.
    add_executable(wrong_command ${CMAKE_CURRENT_SOURCE_DIR}/wrong_command.c)
    target_compile_definitions(wrong_command PRIVATE MESON_IS_SUBPROJECT)
    add_test(NAME "libfuse is a subproject, skipping tests"
             COMMAND wrong_command)
else()
    find_program(PYTEST_EXECUTABLE pytest)
    if(PYTEST_EXECUTABLE)
        add_test(NAME pytest
                 COMMAND ${PYTEST_EXECUTABLE}
                         -vv --tb=short --maxfail=1
                         --log-level=INFO --log-cli-level=INFO
                         ${CMAKE_CURRENT_BINARY_DIR}
                 WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
        set_tests_properties(pytest PROPERTIES
                             TIMEOUT 600
                             RUN_SERIAL TRUE)
    else()
        # Match meson's fallback: build wrong_command and register it so the
        # test suite reports a clear failure when pytest is missing.
        add_executable(wrong_command ${CMAKE_CURRENT_SOURCE_DIR}/wrong_command.c)
        add_test(NAME "pytest not found" COMMAND wrong_command)
    endif()
endif()

# `make check` (or `ninja check`) — build everything, then run ctest.
# Closest ergonomic match to `meson test -C build`, which builds-then-tests.
add_custom_target(check
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
    DEPENDS ${TEST_EXECUTABLES} test_scripts)
