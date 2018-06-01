cmake_minimum_required(VERSION 3.11)

set(pcms foo)

# Adds an executable compiled with C++ module support.
# Usage:
#   add_module_executable(<name> [sources...] MODULES [modules...]
function(add_module_executable)
  cmake_parse_arguments(AME "" "" "MODULES" ${ARGN})
  set(modules_compile_option -fmodules-ts)
  set(compile_options ${modules_compile_option})
  set(pcms)
  foreach (mod ${AME_MODULES})
    get_filename_component(pcm ${mod} NAME_WE)
    set(pcm ${pcm}.pcm)
    set(compile_options ${compile_options} -fmodule-file=${pcm})
    # Use an absolute path to prevent target_link_libraries prepending -l to it.
    set(pcms ${pcms} ${CMAKE_CURRENT_BINARY_DIR}/${pcm})
    add_custom_command(
      OUTPUT ${pcm}
      # Assume that the compiler is clang.
      COMMAND ${CMAKE_CXX_COMPILER} ${modules_compile_option} -x c++-module
              --precompile -c -o ${pcm} ${CMAKE_CURRENT_SOURCE_DIR}/${mod}
      DEPENDS ${mod})
  endforeach ()
  # Get the target name.
  list(GET AME_UNPARSED_ARGUMENTS 0 name)
  # Add pcm files as sources to make sure they are built before the executable.
  add_executable(${AME_UNPARSED_ARGUMENTS} ${pcms})
  target_link_libraries(${name} ${pcms})
  target_compile_options(${name} PRIVATE ${compile_options})
endfunction()

add_module_executable(test main.cc MODULES test.cc)
