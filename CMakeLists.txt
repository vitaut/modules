cmake_minimum_required(VERSION 3.11)

include(${CMAKE_SOURCE_DIR}/modules.cmake)
add_module_library(test MODULES test.cc)
add_module_executable(main main.cc)
target_link_libraries(main test)
