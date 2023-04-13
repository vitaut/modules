cmake_minimum_required(VERSION 3.11)
project(HELLO CXX)

include(../cmake/modules.cmake)

# library
vitaut_add_module_library(hello)
vitaut_add_module_sources(hello hello_module.cc FALLBACK hello_fallback.cc)
target_include_directories(hello PUBLIC include)
get_target_property(modules_enabled hello AML_MODULES_ENABLED)

# consumer
add_executable(main)
if(modules_enabled)
    target_sources(main PRIVATE main_module.cc)
else()
    target_sources(main PRIVATE main_fallback.cc)
endif()

target_link_libraries(main hello)
