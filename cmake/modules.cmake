# A CMake module that provides functions for using C++20 modules in Clang.
# Latest version: https://github.com/vitaut/modules
#
# Defines:
#  * Macroses
#    * vitaut_newest_cxx_version
#    * vitaut_support_modules
#  * Functions
#    * vitaut_add_module_library
#    * vitaut_add_module_sources
#  * Properties
#    * AML_MODULES_ENABLED



#
# Hacks
#

# Clang requires to set CXX_EXTENSIONS property to false
# Switch it to off in case user does not set it explicitly
if(NOT DEFINED CMAKE_CXX_EXTENSIONS AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(CMAKE_CXX_EXTENSIONS OFF)
endif()



#
# Macroses
#

# Checks the latest supported C++ version
# sets `AML_CXX_VERSION` variable
macro(vitaut_newest_cxx_version)
  if(NOT DEFINED AML_CXX_VERSION)
      foreach(ver 26 23 2b 20 17 14 11)
        if(CMAKE_CXX_COMPILE_FEATURES MATCHES "cxx_std_${ver}")
          set(AML_CXX_VERSION ${std_ver})
          break()
        endif()
      endforeach()
  endif()
endmacro()


# Checks that compiler has support for C++ modules
# sets `AML_MODULES_AVAILABLE` variable
macro(vitaut_support_modules)
    if(NOT DEFINED AML_MODULES_AVAILABLE)
        vitaut_newest_cxx_version()

        # Common: selected standard version must be >= C++20
        if(DEFINED CMAKE_CXX_STANDARD AND CMAKE_CXX_STANDARD LESS 20)
            set(AML_MODULES_AVAILABLE FALSE)
        # Common: standard version must be >= C++20
        elseif(AML_CXX_VERSION LESS 20)
            set(AML_MODULES_AVAILABLE FALSE)
        # Clang: version must be >=15
        elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 15)
            set(AML_MODULES_AVAILABLE FALSE)
        # Clang: extensions must be disabled
        elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND CMAKE_CXX_EXTENSIONS)
            set(AML_MODULES_AVAILABLE FALSE)
        # GCC: version must be >= 11
        elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 11)
            set(AML_MODULES_AVAILABLE FALSE)
        # MSVC: version must be >= 19.28
        elseif(CMAKE_CXX_COMPILER_ID MATCHES "MSVC" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 19.28)
            set(AML_MODULES_AVAILABLE FALSE)
        else()
            set(AML_MODULES_AVAILABLE TRUE)
        endif()
    endif()
endmacro()


#
# Properties
#

define_property(TARGET PROPERTY AML_MODULES_ENABLED
    BRIEF_DOCS "Checks that target has modules enabled")

# Adds a library compiled with C++20 module support.
#
# Usage:
#   add_module_library(<name>)
function(vitaut_add_module_library AML_NAME)
  # parse
  set(AML_ARGS_OPTIONS)
  set(AML_ARGS_ONEVAL)
  set(AML_ARGS_MULTIVAL )
  cmake_parse_arguments(AML "${AML_ARGS_OPTIONS}" "${AML_ARGS_ONEVAL}" "${AML_ARGS_MULTIVAL}" ${ARGN})
  set(AML_SOURCES ${AML_UNPARSED_ARGUMENTS})

  add_library(${AML_NAME})

  # Common: check for modules support
  vitaut_support_modules()
  set_target_properties(${AML_NAME} PROPERTIES AML_MODULES_ENABLED ${AML_MODULES_AVAILABLE})
  if(NOT AML_MODULES_AVAILABLE)
    return()
  endif()

  # Common: set linker language
  set_target_properties(${AML_NAME} PROPERTIES LINKER_LANGUAGE CXX)

  # Common: require C++20
  target_compile_features(${AML_NAME} PUBLIC cxx_std_20)

  # Clang: requires extensions to be disabled for modules.
  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
      set_target_properties(${AML_NAME} PROPERTIES CXX_EXTENSIONS OFF)
  endif()

  # GCC: enable modules support
  if (CMAKE_COMPILER_IS_GNUCXX)
    target_compile_options(${AML_NAME} PUBLIC -fmodules-ts)
  endif ()

endfunction()


# Adds sources for library compiled with C++20 module support.
#
# Usage:
#   add_module_library(<name> <sources> FALLBACK <sources>)
function(vitaut_add_module_sources AML_NAME)
  # parse
  set(AML_ARGS_OPTIONS )
  set(AML_ARGS_ONEVAL )
  set(AML_ARGS_MULTIVAL FALLBACK )
  cmake_parse_arguments(AML "${AML_ARGS_OPTIONS}" "${AML_ARGS_ONEVAL}" "${AML_ARGS_MULTIVAL}" ${ARGN})
  set(AML_SOURCES ${AML_UNPARSED_ARGUMENTS})

  # Common: check for module support
  vitaut_support_modules()
  if(NOT AML_MODULES_AVAILABLE)
    target_sources(${AML_NAME} PRIVATE ${AML_FALLBACK})
    return()
  endif()

  # GCC
  if (CMAKE_CXX_COMPILER_ID MATCHES "GNU")
    target_sources(${AML_NAME} PRIVATE ${AML_SOURCES})
  endif()

  # Clang
  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")

    # get current target standard version because it may be higher than C++20.
    get_target_property(std ${AML_NAME} CXX_STANDARD)
    # Clang does not support c++23/c++26 names
    if(std GREATER 20)
        set(std 2b)
    endif()

    foreach (SRC ${AML_SOURCES})
      # extract names
      get_filename_component(NAME_SRC ${SRC} NAME_WE)
      set(NAME_PCM ${NAME_SRC}.pcm)
      set(NAME_OBJ ${NAME_SRC}.o)
      set(PATH_PCM ${CMAKE_CURRENT_BINARY_DIR}/${NAME_SRC}.pcm)
      set(PATH_OBJ ${CMAKE_CURRENT_BINARY_DIR}/${NAME_SRC}.o)

      # compile .pcm file
      # Use an absolute path to prevent target_link_libraries prepending -l to it.
      add_custom_command(
        OUTPUT "${PATH_PCM}"
        COMMAND ${CMAKE_CXX_COMPILER}
                -std=c++${std} -x c++-module --precompile -c
                -o ${NAME_PCM} "${CMAKE_CURRENT_SOURCE_DIR}/${SRC}"
                "-I$<JOIN:$<TARGET_PROPERTY:${AML_NAME},INCLUDE_DIRECTORIES>,;-I>"
        # Required by the -I generator expression above.
        COMMAND_EXPAND_LISTS
        DEPENDS ${SRC}
      )

      # compile .o file
      # Use an absolute path to prevent target_link_libraries prepending -l.
      add_custom_command(
          OUTPUT "${PATH_OBJ}"
          COMMAND ${CMAKE_CXX_COMPILER} $<TARGET_PROPERTY:${AML_NAME},COMPILE_OPTIONS>
          -c -o ${PATH_OBJ} ${PATH_PCM}
          DEPENDS ${PATH_PCM})
      target_sources(${AML_NAME} PRIVATE "${PATH_OBJ}")

      # Propagate -fmodule-file=*.pcm to targets that link with this library.
      target_compile_options(${AML_NAME} INTERFACE -fmodule-file=${CMAKE_CURRENT_BINARY_DIR}/${NAME_PCM})
    endforeach ()
  endif ()

  # MSVC
  if (MSVC)
    target_sources(${AML_NAME} PRIVATE ${AML_SOURCES})
    foreach (src ${AML_SOURCES})
        # compile file as interface
        set_source_files_properties(${src} PROPERTIES COMPILE_FLAGS /interface)

        get_filename_component(ifc ${src} NAME_WE)
        set(ifc ${ifc}.ifc)

        target_compile_options(${AML_NAME} PUBLIC /reference "${CMAKE_CURRENT_BINARY_DIR}/${ifc}")
    endforeach()
  endif()

endfunction()
