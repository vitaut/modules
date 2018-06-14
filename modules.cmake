# A CMake module that provides functions for using C++ modules in Clang.

option(USE_MODULES "Use C++ modules" OFF)
set(MODULES_COMPILE_OPTION -fmodules-ts)

# Adds a custom command for building a .pcm file ${pcm} from module file ${mod}
# using ${target} include directories.
function(add_pcm_build_command target mod pcm)
  add_custom_command(
    OUTPUT ${pcm}
    COMMAND ${CMAKE_CXX_COMPILER} ${MODULES_COMPILE_OPTION} -x c++-module
            --precompile -c -o ${pcm} ${CMAKE_CURRENT_SOURCE_DIR}/${mod}
            "-I$<JOIN:$<TARGET_PROPERTY:${target},INCLUDE_DIRECTORIES>,;-I>"
    # Required by the -I generator expression above.
    COMMAND_EXPAND_LISTS
    DEPENDS ${mod})
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
  set(compile_options ${MODULES_COMPILE_OPTION}
      # Clang incorrectly warns about -fprebuilt-module-path being unused.
      -fprebuilt-module-path=. -Wno-unused-command-line-argument)
  set(pcms)
  # Get the target name.
  list(GET AME_UNPARSED_ARGUMENTS 0 name)
  foreach (mod ${AME_MODULES})
    get_filename_component(pcm ${mod} NAME_WE)
    set(pcm ${pcm}.pcm)
    set(compile_options ${compile_options} -fmodule-file=${pcm})
    # Use an absolute path to prevent target_link_libraries prepending -l to it.
    set(pcms ${pcms} ${CMAKE_CURRENT_BINARY_DIR}/${pcm})
    add_pcm_build_command(${name} ${mod} ${pcm})
  endforeach ()
  # Add pcm files as sources to make sure they are built before the executable.
  add_executable(${AME_UNPARSED_ARGUMENTS} ${pcms})
  target_link_libraries(${name} ${pcms})
  target_compile_options(${name} PRIVATE ${compile_options})
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
  set(compile_options ${MODULES_COMPILE_OPTION})
  set(files)
  # Get the target name.
  list(GET AME_UNPARSED_ARGUMENTS 0 name)
  foreach (mod ${AME_MODULES})
    get_filename_component(mod_we ${mod} NAME_WE)
    set(pcm ${mod_we}.pcm)
    set(obj ${mod_we}.o)
    set(compile_options ${compile_options} -fmodule-file=${pcm})
    # Use an absolute path to prevent target_link_libraries prepending -l to it.
    set(files ${files} ${CMAKE_CURRENT_BINARY_DIR}/${pcm} ${obj})
    add_pcm_build_command(${name} ${mod} ${pcm})
    add_custom_command(
      OUTPUT ${obj}
      COMMAND ${CMAKE_CXX_COMPILER} ${MODULES_COMPILE_OPTION} -c -o ${obj} ${pcm}
      DEPENDS ${pcm})
  endforeach ()
  # Add pcm files as sources to make sure they are built before the library.
  add_library(${AME_UNPARSED_ARGUMENTS} ${files})
  set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
  target_link_libraries(${name} ${pcms})
  target_compile_options(${name} PRIVATE ${compile_options})
endfunction()
