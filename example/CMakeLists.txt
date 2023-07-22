cmake_minimum_required(VERSION 3.11)
project(HELLO CXX)

# Include module library
include(../modules.cmake)

# Display debug info
modules_get_latest_cxx_std(std_latest_ver)
modules_supported(cxx_modules)
modules_supported(cxx_modules_latest STANDARD ${std_latest_ver})
message(STATUS "C++ target standard  = ${CMAKE_CXX_STANDARD}")
message(STATUS "    modules support  = ${cxx_modules}")
message(STATUS "")
message(STATUS "C++ latest standard  = ${std_latest_ver}")
message(STATUS "    modules support  = ${cxx_modules_latest}")

set(MAPPER_FILE ${CMAKE_BINARY_DIR}/mapper.txt)

# Module library
add_module_library(hello hello.cc FALLBACK hello_fallback.cc MAPPER_FILE ${MAPPER_FILE})
target_include_directories(hello PUBLIC include)

# Demo application
if(cxx_modules)
  set(app_src main.cc)
else()
  set(app_src main_fallback.cc)
endif()
add_executable(main ${app_src})
target_link_libraries(main hello)
