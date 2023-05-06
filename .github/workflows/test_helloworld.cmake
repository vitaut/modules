if (CMAKE_CXX_STANDARD GREATER_EQUAL 20)
  set(test_reference "Hello, modules!\n")
else ()
  set(test_reference "Modules are late to the party :(\n")
endif ()

execute_process(
  COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/main"
  OUTPUT_VARIABLE test_result
)

if (NOT test_result STREQUAL test_reference)
  message(FATAL_ERROR "Test output does not match:\n"
    "expected: ${test_reference}\n"
    "actual: ${test_result}")
endif ()
