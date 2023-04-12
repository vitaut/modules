cmake_minimum_required(VERSION 3.11)
project(HELLO)

set(USE_MODULES ON)
include(${CMAKE_SOURCE_DIR}/modules.cmake)

add_module_library(hello MODULES hello.cc)
target_include_directories(hello PRIVATE include)

add_module_executable(main main.cc)
target_link_libraries(main hello)
