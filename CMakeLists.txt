cmake_minimum_required(VERSION 3.11)

set(USE_MODULES ON)
include(${CMAKE_SOURCE_DIR}/modules.cmake)
add_module_library(test MODULES test.cc)
target_include_directories(test PRIVATE include)
add_module_executable(main main.cc)
target_link_libraries(main test)
