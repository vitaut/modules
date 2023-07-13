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
add_module_library(NAME hello
  MAPPER_FILE ${MAPPER_FILE}
  SOURCES ${CMAKE_CURRENT_LIST_DIR}/hello.cc
  SOURCES_FALLBACK ${CMAKE_CURRENT_LIST_DIR/}hello_fallback.cc)
target_include_directories(hello PUBLIC include)

# Demo application
if(cxx_modules)
  set(app_src main.cc)
else()
  set(app_src main_fallback.cc)
endif()
add_executable(main ${app_src})
target_link_libraries(main hello)

if(CMAKE_COMPILER_IS_GNUCXX)
  target_compile_options(main PUBLIC
    -fmodule-mapper=${MAPPER_FILE})
endif ()
