cmake_minimum_required(VERSION 3.11)
project(HELLO CXX)

include(modules.cmake)

modules_get_latest_cxx_std(std_latest_ver)
message("std_latest_ver=${std_latest_ver}")

modules_supported(cxx_modules)
message("cxx_modules=${cxx_modules}")

add_module_library(hello hello.cc)
target_include_directories(hello PRIVATE include)

add_executable(main main.cc)
target_link_libraries(main hello)
