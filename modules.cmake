# A CMake module that provides functions for using C++ modules in Clang.

option(USE_MODULES "Use C++ modules" OFF)

# Adds a custom command for building .pcm files from module files <module>...
# using <target>'s include directories. The list of .pcm files is returned in the
# <pcms_var> variable and compile options are returned in <compile_options_var>.
# Usage:
#   add_pcm_build_commands(<target> <pcms_var> <compile_options_var> <module>...)
function(add_pcm_build_commands target pcms_var compile_options_var)
  get_target_property(std ${target} CXX_STANDARD)

  set(pcms)
  foreach (mod ${ARGN})
    get_filename_component(pcm ${mod} NAME_WE)
    set(pcm ${pcm}.pcm)
    set(compile_options ${compile_options} -fmodule-file=${pcm})
    # Use an absolute path to prevent target_link_libraries prepending -l to it.
    set(pcms ${pcms} ${CMAKE_CURRENT_BINARY_DIR}/${pcm})
    add_custom_command(
      OUTPUT ${pcm}
      COMMAND ${CMAKE_CXX_COMPILER}
              -std=c++${std} -x c++-module --precompile -c
              -o ${pcm} ${CMAKE_CURRENT_SOURCE_DIR}/${mod}
              "-I$<JOIN:$<TARGET_PROPERTY:${target},INCLUDE_DIRECTORIES>,;-I>"
      # Required by the -I generator expression above.
      COMMAND_EXPAND_LISTS
      DEPENDS ${mod})
  endforeach ()
  set(${pcms_var} ${pcms} PARENT_SCOPE)
  set(${compile_options_var} ${compile_options} PARENT_SCOPE)
endfunction()

# Adds an executable compiled with C++ module support.
# Usage:
#   add_module_executable(<name> [sources...] MODULES [modules...]
function(add_module_executable)
  cmake_parse_arguments(AME "" "" "MODULES" ${ARGN})
  if (NOT USE_MODULES)
    add_executable(${AME_UNPARSED_ARGUMENTS})
    return()
  endif ()

  # Get the target name.
  list(GET AME_UNPARSED_ARGUMENTS 0 name)
  add_executable(${AME_UNPARSED_ARGUMENTS})

  # Get the target name.
  list(GET AME_UNPARSED_ARGUMENTS 0 name)
  add_pcm_build_commands(${name} pcms compile_options ${AME_MODULES})
  # Add pcm files as sources to make sure they are built before the executable.
  target_sources(${name} PUBLIC ${pcms})
  target_link_libraries(${name} ${pcms})
  target_compile_options(${name} PRIVATE ${compile_options}
      # Clang incorrectly warns about -fprebuilt-module-path being unused.
      -fprebuilt-module-path=. -Wno-unused-command-line-argument)
endfunction()

# Adds a library compiled with C++ module support.
# Usage:
#   add_module_library(<name> [sources...] MODULES [modules...]
function(add_module_library)
  cmake_parse_arguments(AME "" "" "MODULES" ${ARGN})
  if (NOT USE_MODULES)
    add_library(${AME_UNPARSED_ARGUMENTS})
    return()
  endif ()

  # Get the target name.
  list(GET AME_UNPARSED_ARGUMENTS 0 name)

  add_library(${AME_UNPARSED_ARGUMENTS})
  set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
  target_compile_features(${name} PUBLIC cxx_std_20)

  add_pcm_build_commands(${name} pcms compile_options ${AME_MODULES})

  # Add pcm files as sources to make sure they are built before the library.
  set(files)
  foreach (pcm ${pcms})
    get_filename_component(pcm_we ${pcm} NAME_WE)
    set(obj ${pcm_we}.o)
    # Use an absolute path to prevent target_link_libraries prepending -l to it.
    set(files ${files} ${pcm} ${CMAKE_CURRENT_BINARY_DIR}/${obj})
    add_custom_command(
      OUTPUT ${obj}
      COMMAND ${CMAKE_CXX_COMPILER} $<TARGET_PROPERTY:${name},COMPILE_OPTIONS> -c -o ${obj} ${pcm}
      DEPENDS ${pcm})
  endforeach ()
  target_sources(${name} PUBLIC ${files})

  target_link_libraries(${name} ${pcms})
  target_compile_options(${name} PRIVATE ${compile_options})
endfunction()
