# CMake equivalent of libfuse's meson.build
# Every attempt has been made to match all the functionality provided by meson
# Use at your own risk

cmake_minimum_required (VERSION 3.12.0)
set (CMAKE_VERBOSE_MAKEFILE FALSE)

if( DEFINED NDEBUG )
	message(WARNING "NDEBUG is defined, you will almost definitely experience problems")
endif()

# Duplicate target - and not really a meaningful test
#add_executable( hello)
#target_sources( hello PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/hello.c )
#target_include_directories(hello PUBLIC ${INCLUDE_DIRS})
#target_link_libraries(hello fuse3 ${CMAKE_THREAD_LIBS_INIT})

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

set(TEST_SCRIPTS conftest.py pytest.ini test_examples.py util.py test_ctests.py)

add_custom_target(test_scripts)
foreach(TEST_SCRIPT ${TEST_SCRIPTS})
  add_custom_command(TARGET test_scripts PRE_BUILD
                     COMMAND ${CMAKE_COMMAND} -E
                         copy ${CMAKE_CURRENT_SOURCE_DIR}/${TEST_SCRIPT} ${CMAKE_CURRENT_BINARY_DIR}/.)
endforeach()
add_dependencies(fuse3 test_scripts)
