cmake_minimum_required(VERSION 3.11)
project(HELLO CXX)

# Include module library
include(modules.cmake)

# Display debug info
modules_get_latest_cxx_std(std_latest_ver)
modules_supported(cxx_modules)
message(STATUS "C++ standard targeted  = ${CMAKE_CXX_STANDARD}")
message(STATUS "C++ standard supported = ${std_latest_ver}")
message(STATUS "C++ modules supported  = ${cxx_modules}")

# Module library
add_module_library(hello hello.cc)
target_include_directories(hello PRIVATE include)

# Demo application
add_executable(main main.cc)
target_link_libraries(main hello)
