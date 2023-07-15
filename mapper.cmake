write_file(${MAPPER_FILE} "") # TODO: merge all libs files
FILE(GLOB children RELATIVE ${CMAKE_CURRENT_BINARY_DIR}/gcm.cache/ ${CMAKE_CURRENT_BINARY_DIR}/gcm.cache/*)
FOREACH(child ${children})
  IF(NOT (IS_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/gcm.cache/${child}))
    get_filename_component(inc ${child} NAME_WE)
    write_file(${MAPPER_FILE} ${inc} " " ${CMAKE_CURRENT_BINARY_DIR}/gcm.cache/${child} "\n" )
  ENDIF()
ENDFOREACH()
