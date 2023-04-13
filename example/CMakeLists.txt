cmake_minimum_required(VERSION 3.11)
project(HELLO CXX)

include(modules.cmake)

add_module_library(hello hello.cc)
target_include_directories(hello PRIVATE include)

add_executable(main main.cc)
target_link_libraries(main hello)
