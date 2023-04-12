# A CMake module that provides functions for using C++20 modules in Clang.

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
    target_sources(${name} PUBLIC ${AML_FALLBACK})
    return()
  endif ()

  # Check if modules are supported.
  set(have_modules FALSE)
  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND
      CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 16.0)
    set(have_modules TRUE)
  endif ()
  if (NOT have_modules)
    message(FATAL_ERROR "Modules not supported.")
  endif ()

  # Modules require C++20.
  target_compile_features(${name} PUBLIC cxx_std_20)

  # `std` is affected by CMake options and may be higher than C++20.
  get_target_property(std ${name} CXX_STANDARD)

  set(pcms)
  foreach (src ${sources})
    get_filename_component(pcm ${src} NAME_WE)
    set(pcm ${pcm}.pcm)

    # Propagate -fmodule-file=*.pcm to targets that link with this library.
    target_compile_options(${name} PUBLIC -fmodule-file=${pcm})

    # Use an absolute path to prevent target_link_libraries prepending -l to it.
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

  # Add .pcm files as sources to compile them to .o files.
  target_sources(${name} PUBLIC ${pcms})
  target_compile_options(${name} PUBLIC -Wno-unused-command-line-argument)
  set_source_files_properties(${pcms} PROPERTIES LANGUAGE CXX)
endfunction()
