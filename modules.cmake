# A CMake module that provides functions for using C++20 modules in Clang.

#[[
  Copyright (c) 2018 - present, Victor Zverovich
  
  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:
  
  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  
  --- Optional exception to the license ---
  
  As an exception, if, as a result of your compiling your source code, portions
  of this Software are embedded into a machine-executable object form of such
  source code, you may redistribute such embedded portions in such object form
  without including the above copyright and permission notices.
]]


# Clang requires the CXX_EXTENSIONS property to be set to false to use modules.
# If the user has not set it explicitly, do it here. Otherwise warn if it is not
# set to false.
if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  if (NOT DEFINED CMAKE_CXX_EXTENSIONS)
    set(CMAKE_CXX_EXTENSIONS OFF)
  elseif (NOT CMAKE_CXX_EXTENSIONS)
    message(WARNING "Clang requires CMAKE_CXX_EXTENSIONS to be set to false to use modules.")
  endif ()
endif ()


# Adds a library compiled with C++20 module support.
# `enabled` is a CMake variables that specifies if modules are enabled.
# If modules are disabled `add_module_library` falls back to creating a
# non-modular library.
#
# Usage:
#   add_module_library(<name> [sources...] FALLBACK [sources...] [IF enabled])
function(add_module_library name)
  cmake_parse_arguments(AML "" "IF" "FALLBACK" ${ARGN})
  set(sources ${AML_UNPARSED_ARGUMENTS})

  add_library(${name})
  set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)

  if (NOT ${${AML_IF}})
    # Create a non-modular library.
    target_sources(${name} PRIVATE ${AML_FALLBACK})
    return()
  endif ()

  # Modules require C++20.
  target_compile_features(${name} PUBLIC cxx_std_20)
  if (CMAKE_COMPILER_IS_GNUCXX)
    target_compile_options(${name} PUBLIC -fmodules-ts)
  endif ()

  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # `std` is affected by CMake options and may be higher than C++20.
    # Clang does not support c++23/c++26 names, so replace it with 2b.
    get_target_property(std ${name} CXX_STANDARD)
    if (std GREATER 20)
      set(std 2b)
    endif ()

    set(pcms)
    foreach (src ${sources})
      get_filename_component(pcm ${src} NAME_WE)
      set(pcm ${pcm}.pcm)

      # Propagate -fmodule-file=*.pcm to targets that link with this library.
      target_compile_options(
        ${name} PUBLIC -fmodule-file=${CMAKE_CURRENT_BINARY_DIR}/${pcm})

      # Use an absolute path to prevent target_link_libraries prepending -l
      # to it.
      set(pcms ${pcms} ${CMAKE_CURRENT_BINARY_DIR}/${pcm})
      add_custom_command(
        OUTPUT ${pcm}
        COMMAND ${CMAKE_CXX_COMPILER}
                -std=c++${std} -x c++-module --precompile -c
                -o ${pcm} ${CMAKE_CURRENT_SOURCE_DIR}/${src}
                "-I$<JOIN:$<TARGET_PROPERTY:${name},INCLUDE_DIRECTORIES>,;-I>"
        # Required by the -I generator expression above.
        COMMAND_EXPAND_LISTS
        DEPENDS ${src})
    endforeach ()

    # Add .pcm files as sources to make sure they are built before the library.
    set(sources)
    foreach (pcm ${pcms})
      get_filename_component(pcm_we ${pcm} NAME_WE)
      set(obj ${pcm_we}.o)
      # Use an absolute path to prevent target_link_libraries prepending -l.
      set(sources ${sources} ${pcm} ${CMAKE_CURRENT_BINARY_DIR}/${obj})
      add_custom_command(
        OUTPUT ${obj}
        COMMAND ${CMAKE_CXX_COMPILER} $<TARGET_PROPERTY:${name},COMPILE_OPTIONS>
                -c -o ${obj} ${pcm}
        DEPENDS ${pcm})
    endforeach ()
  endif ()

  # Common: add sources
  target_sources(${name} PRIVATE ${sources})

  # MSVC
  if (MSVC)
    foreach (src ${sources})
      # compile file as interface
      set_source_files_properties(${src} PROPERTIES COMPILE_FLAGS /interface)

      # set .ifc file as reference for dependant project
      get_filename_component(ifc ${src} NAME_WE)
      set(ifc "${CMAKE_CURRENT_BINARY_DIR}/${ifc}.ifc")
      target_compile_options(${name} INTERFACE /reference "${ifc}")

      # track generated .ifc file
      set_target_properties(${name} PROPERTIES ADDITIONAL_CLEAN_FILES ${ifc})
      set_source_files_properties(${ifc} PROPERTIES GENERATED ON)
    endforeach()
  endif()
endfunction()
