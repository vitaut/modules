cmake_minimum_required(VERSION 3.11)

# Adds an executable compiled with C++ module support.
# Usage:
#   add_module_executable(<name> [sources...] MODULES [modules...]
function(add_module_executable)
  cmake_parse_arguments(AME "" "" "MODULES" ${ARGN})
  foreach (mod ${AME_MODULES})
    get_filename_component(pcm ${mod} NAME_WE)
    set(pcm ${pcm}.pcm)
    set(pcms ${pcms} ${CMAKE_CURRENT_BINARY_DIR}/${pcm})
    add_custom_command(
      OUTPUT ${pcm}
      # Assume that the compiler is clang.
      COMMAND ${CMAKE_CXX_COMPILER} -fmodules-ts -x c++-module --precompile -c
              -o ${pcm}
              ${CMAKE_CURRENT_SOURCE_DIR}/${mod}
      DEPENDS ${mod})
  endforeach ()
  list(GET AME_UNPARSED_ARGUMENTS 0 name)
  add_executable(${AME_UNPARSED_ARGUMENTS} ${pcms})
  target_link_libraries(${name} ${pcms})
  foreach (pcm ${pcms})
    target_compile_options(${name} PRIVATE -fmodules-ts -fmodule-file=${pcm})
  endforeach ()
endfunction()

add_module_executable(test main.cc MODULES test.cc)
