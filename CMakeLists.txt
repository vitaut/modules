cmake_minimum_required(VERSION 3.11)
project(HELLO)

# Clang 16 requires extensions to be disabled for modules.
set(CMAKE_CXX_EXTENSIONS OFF)

include(modules.cmake)

add_module_library(hello MODULES hello.cc IF USE_MODULES)
target_include_directories(hello PRIVATE include)

add_executable(main main.cc)
target_link_libraries(main hello)
