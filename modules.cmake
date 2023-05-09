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

# needed flags for GCC
if (CMAKE_CXX_COMPILER_ID MATCHES "GNU")
	set(GENERIC_CXX_MODULE_FLAGS -std=c++20 -fcoroutines -fmodules-ts -xc++-system-header)
	set(GCM_CACHE gcm.cache/usr/include/c++/12.2.1)
endif()

# Clang requires the CXX_EXTENSIONS property to be set to false to use modules.
# If the user has not set it explicitly, do it here. Otherwise warn if it is not
# set to false.
if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  if (NOT DEFINED CMAKE_CXX_EXTENSIONS)
    set(CMAKE_CXX_EXTENSIONS OFF)
  elseif (NOT CMAKE_CXX_EXTENSIONS)
    message(
      WARNING
      "Clang requires CMAKE_CXX_EXTENSIONS to be set to false to use modules.")
  endif ()
endif ()

# Receives latest available C++ standard version
#
# Usage:
#   modules_get_latest_cxx_std(<variable_name>)
#   if (<variable_name> GREATER 17)
#     ...
#   endif ()

function(modules_get_latest_cxx_std result)
  # Assume that 98 will be supported even with a broken feature detection.
  set(std_version 98)

  # Iterate over features and use the latest one. CMake always sorts features
  # from the oldest to the newest.
  foreach (compiler_feature ${CMAKE_CXX_COMPILE_FEATURES})
    if (compiler_feature MATCHES "cxx_std_(.*)")
      set(std_version ${CMAKE_MATCH_1})
    endif ()
  endforeach ()

  set(${result} ${std_version} PARENT_SCOPE)
endfunction()


# wth regex checks if we used import syntax importing standard headers as modules and sets a var if gets any with a list of standard headers 
function(check_no_import_stdheaders result) 
	modules_get_latest_cxx_std(std_version)
	set(stdlib_list iostream string vector) # add the entire list of standard headers?
	cmake_parse_arguments(MOD "" "IF" "Else" ${ARGN})
	set(files ${MOD_UNPARSED_ARGUMENTS})
	set(modules)
	foreach(file ${files})
		file(READ ${file} contents)
		string(REGEX REPLACE "\n" ";" lines ${contents}) 
		foreach(line ${lines})
			string(REGEX MATCH "import.*" import ${line})
			if(NOT import STREQUAL "")
				string(REGEX REPLACE " " ";" conts ${import})
				list(GET conts 1 module)
				set(modules ${modules} ${module})
			endif()
		endforeach()
			
	endforeach()

	set(${result} FALSE PARENT_SCOPE)
	foreach(module ${modules})
		string(REGEX MATCH "\<.*\>" match ${module})
		if(NOT match STREQUAL "")
			set(${result} TRUE PARENT_SCOPE)
		endif()
		if(${module} IN_LIST stdlib_list)
			set(${result} TRUE PARENT_SCOPE)
		endif()
	endforeach()
	set(std_modules ${modules} PARENT_SCOPE)
endfunction()

# generate the std gcm files required for using standard as modules
function(add_stdheader_gcm)
	cmake_parse_arguments(MOD "" "" "" ${ARGN})
	set(source ${MOD_UNPARSED_ARGUMENTS})
	check_no_import_stdheaders(has_stdimport ${source})
	string(REGEX REPLACE "[^0-9]" ";"  TMP ${CMAKE_CXX_COMPILER_VERSION})
	list(GET TMP 0 CXX_COMPILER_VERSION_MAJOR)
	set(STD_HEADERS_BUILT FALSE PARENT_SCOPE)
	set(std_headers_built FALSE)
	if(has_stdimport AND ${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU" AND ${CXX_COMPILER_VERSION_MAJOR} LESS 12)
		message(WARNING "Compiler(${CMAKE_CXX_COMPILER_ID}) version seems to be ${CXX_COMPILER_VERSION_MAJOR}, you seem to have std imports\nC++23 features won't work")
	endif()
	set(CMAKE_CXX_EXTENSIONS OFF PARENT_SCOPE)
	list(LENGTH std_modules len_std_modules)	
	if(len_std_modules GREATER 0)
		set(modules)
		foreach(std_module ${std_modules})
			string(REGEX MATCH "\<.*\>" match ${std_module})
			if(NOT match STREQUAL "")
				string(REGEX MATCH "[a-z]+" module ${std_module})
				add_custom_target(${module} ALL)
				add_custom_command(
					TARGET ${module}
					COMMAND ${CMAKE_CXX_COMPILER} ${GENERIC_CXX_MODULE_FLAGS} ${module}
				)
				set(STD_HEADERS_BUILT TRUE PARENT_SCOPE)
				set(std_headers_built TRUE)
				set(modules ${modules} ${module})
			endif()
		endforeach()
	endif()
	
	set(STD_MODULES ${modules} PARENT_SCOPE)
endfunction()

function(add_module_executable name)
	cmake_parse_arguments(MOD ""  "FORCE_NO_MODULE_STD" "CATCH_ERRORS" ${ARGN})
	if(NOT DEFINED MOD_CATCH_ERRORS)
		set(MOD_CATCH_ERRORS FALSE)
	endif()
	set(source ${MOD_UNPARSED_ARGUMENTS})
	if(NOT DEFINED MOD_FORCE_NO_MODULE_STD)
		set(MOD_FORCE_NO_MODULE_STD FALSE)
	endif()
	if(NOT MOD_FORCE_NO_MODULE_STD)
		add_stdheader_gcm(${source})	
	endif()
	if(${CMAKE_CXX_COMPILER_ID} MATCHES "GNU")
		set(COROUTINES -fcoroutines)
	endif()
	add_executable(${name} ${source})
	target_compile_features(${name} PUBLIC cxx_std_20)
	target_compile_options(${name} PUBLIC -std=c++20 ${COROUTINES} -fmodules-ts)
	# add dependencies so the gcms are built before getting to the main targets(?)
	if(STD_HEADERS_BUILT)
		if(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
			if(MOD_CATCH_ERRORS)
				message(FATAL_ERROR "standard modules is not supported with Clang yet")
			else()
				message(WARNING "standard modules is not supported with Clang yet")
			endif()
		endif()
		foreach(module ${STD_MODULES})
			add_dependencies(${name} ${module})
		endforeach()
	endif()
endfunction()

# Checks that the compiler supports C++20 modules.
#
# Usage:
#   modules_supported(<variable_name> [STANDARD standard_ver])
#   if (<variable_name>)
#     ...
#   endif ()
function(modules_supported result)
  cmake_parse_arguments(MS "" "STANDARD" "" ${ARGN})

  set(${result} FALSE PARENT_SCOPE)

  # Check the standard version.
  if (NOT DEFINED MS_STANDARD)
    if (DEFINED CMAKE_CXX_STANDARD)
      set(MS_STANDARD ${CMAKE_CXX_STANDARD})
    else ()
      modules_get_latest_cxx_std(MS_STANDARD)
    endif ()
  endif ()

  if (MS_STANDARD GREATER_EQUAL 20)

    # Create a simple module file.
    set(temp_filepath "${CMAKE_BINARY_DIR}/module_test.cc")
    file(WRITE "${temp_filepath}"
         "module;\nexport module module_test;\nexport void module_test_fun(){}")

    # Set compiler flags.
    set(compiler_flags "")
    if (MSVC)
      set(compiler_flags "/interface")
    elseif (CMAKE_COMPILER_IS_GNUCXX)
      set(compiler_flags "-fmodules-ts")
    endif ()

    # Try to build it.
    set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
    try_compile(
      compilation_result "${CMAKE_BINARY_DIR}"
      SOURCES "${temp_filepath}"
      COMPILE_DEFINITIONS "${compiler_flags}"
      CXX_STANDARD ${MS_STANDARD}
      CXX_STANDARD_REQUIRED ON
      OUTPUT_VARIABLE output)

    # Remove the test file.
    file(REMOVE ${temp_filepath})

    # Return the result.
    set(${result} ${compilation_result} PARENT_SCOPE)
  endif ()
endfunction()


# Adds a library compiled with C++20 module support.
# `enabled` is a CMake variables that specifies if modules are enabled.
# If modules are disabled `add_module_library` falls back to creating a
# non-modular library.
#
# Usage:
#   add_module_library(<name> [sources...] FALLBACK [sources...] [IF enabled])


function(add_module_library name)
  cmake_parse_arguments(AML "" "IF" "FALLBACK" ${ARGN})
  cmake_parse_arguments(FLG "" "FORCE_NO_MODULE_STD" "CATCH_ERRORS" ${ARGN}) # don't understand why adding the flags to AML goes down to catastropic spiral of errors 
  set(sources ${AML_UNPARSED_ARGUMENTS})

  if(NOT DEFINED FLG_CATCH_ERRORS)
	  set(FLG_CATCH_ERRORS FALSE)
  endif()
  if(NOT DEFINED FLG_FORCE_NO_MODULE_STD)
	  set(FLG_FORCE_NO_MODULE_STD FALSE)
  endif()

  if(NOT FLG_FORCE_NO_MODULE_STD)
  	add_stdheader_gcm(${sources})	
  endif()
  
  if(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang" AND STD_HEADERS_BUILT)
  	if(FLG_CATCH_ERRORS)
  		message(FATAL_ERROR "Sorry! Clang is not supported yet")
	else()
		message(WARNING "Clang is not supported yet, things might not work")
	endif()
  endif()

  add_library(${name})
  set_target_properties(${name} PROPERTIES LINKER_LANGUAGE CXX)
  if(STD_HEADERS_BUILT)
		foreach(module ${STD_MODULES})
			add_dependencies(${name} ${module})
		endforeach()
  endif()


  # Detect module support in case it was not explicitly defined
  if(NOT DEFINED AML_IF)
    modules_supported(AML_IF)
  endif()

  # Add fallback sources to the target in case modules are not supported or
  # fallback was explicitly selected.
  if (NOT ${AML_IF})
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
      set(prop "$<TARGET_PROPERTY:${name},INCLUDE_DIRECTORIES>")
      add_custom_command(
        OUTPUT ${pcm}
        COMMAND ${CMAKE_CXX_COMPILER}
                -std=c++${std} -x c++-module --precompile -c
                -o ${pcm} ${CMAKE_CURRENT_SOURCE_DIR}/${src}
                "$<$<BOOL:${prop}>:-I$<JOIN:${prop},;-I>>"
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

  target_sources(${name} PRIVATE ${sources})

  if (MSVC)
    foreach (src ${sources})
      # Compile file as a module interface.
      set_source_files_properties(${src} PROPERTIES COMPILE_FLAGS /interface)

      # Propagate `/reference *.ifc` to targets that link with this library.
      get_filename_component(ifc ${src} NAME_WE)
      set(ifc "${CMAKE_CURRENT_BINARY_DIR}/${ifc}.ifc")
      target_compile_options(${name} INTERFACE /reference "${ifc}")

      # Track the generated .ifc file.
      set_target_properties(${name} PROPERTIES ADDITIONAL_CLEAN_FILES ${ifc})
      set_source_files_properties(${ifc} PROPERTIES GENERATED ON)
    endforeach ()
  endif ()
endfunction()
