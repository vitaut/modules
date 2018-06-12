cmake_minimum_required(VERSION 3.11)

set(MODULES_COMPILE_OPTION -fmodules-ts)

# Adds an executable compiled with C++ module support.
# Usage:
#   add_module_executable(<name> [sources...] MODULES [modules...]
function(add_module_executable)
  cmake_parse_arguments(AME "" "" "MODULES" ${ARGN})
  set(compile_options ${MODULES_COMPILE_OPTION}
      # Clang incorrectly warns abut -fprebuilt-module-path being unused.
      -fprebuilt-module-path=. -Wno-unused-command-line-argument)
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
      COMMAND ${CMAKE_CXX_COMPILER} ${MODULES_COMPILE_OPTION} -x c++-module
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

# Adds a library compiled with C++ module support.
# Usage:
#   add_module_library(<name> [sources...] MODULES [modules...]
function(add_module_library)
  cmake_parse_arguments(AME "" "" "MODULES" ${ARGN})
  set(compile_options ${MODULES_COMPILE_OPTION})
  set(files)
  foreach (mod ${AME_MODULES})
    get_filename_component(mod_we ${mod} NAME_WE)
    set(pcm ${mod_we}.pcm)
    set(obj ${mod_we}.o)
    set(compile_options ${compile_options} -fmodule-file=${pcm})
    # Use an absolute path to prevent target_link_libraries prepending -l to it.
    set(files ${files} ${CMAKE_CURRENT_BINARY_DIR}/${pcm} ${obj})
    add_custom_command(
      OUTPUT ${pcm}
      # Assume that the compiler is clang.
      COMMAND ${CMAKE_CXX_COMPILER} ${MODULES_COMPILE_OPTION} -x c++-module
              --precompile -c -o ${pcm} ${CMAKE_CURRENT_SOURCE_DIR}/${mod}
      DEPENDS ${mod})
    add_custom_command(
      OUTPUT ${obj}
      COMMAND ${CMAKE_CXX_COMPILER} ${MODULES_COMPILE_OPTION} -c -o ${obj} ${pcm}
      DEPENDS ${pcm})
  endforeach ()
  # Get the target name.
  list(GET AME_UNPARSED_ARGUMENTS 0 name)
  # Add pcm files as sources to make sure they are built before the library.
  add_library(${AME_UNPARSED_ARGUMENTS} ${files})
  set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
  target_link_libraries(${name} ${pcms})
  target_compile_options(${name} PRIVATE ${compile_options})
endfunction()

add_module_library(test MODULES test.cc)
add_module_executable(main main.cc)
target_link_libraries(main test)
