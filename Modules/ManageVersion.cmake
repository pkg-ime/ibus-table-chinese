# - Targets and macros that related to versioning.
#
# Includes:
#   ManageVariable
#   DateTimeFormat
#
# Included by:
#   PackSource
#
# Defines following macros:
#   LOAD_RELEASE_FILE(releaseFile)
#   - Load release file information.
#     Arguments:
#     + releaseFile: release file to be read.
#       This file should contain following definition:
#       + PRJ_VER: Release version.
#       + SUMMARY: Summary of the release. Will be output as CHANGE_SUMMARY.
#          and a [Changes] section tag, below which listed the change in the
#          release.
#     This macro reads or define following variables:
#     + RELEASE_TARGETS: Sequence of release targets.
#     This macro outputs following files:
#     + ChangeLog: Log of changes.
#       Depends on ChangeLog.prev and releaseFile.
#     This macro defines following targets:
#     + version_check: Check whether the current PRJ_VER value match
#       the PRJ_VER declared in releaseFile.
#     This macro sets following variables:
#     + PRJ_VER: Release version.
#     + CHANGE_SUMMARY: Summary of changes.
#     + CHANGELOG_ITEMS: Lines below the [Changes] tag.
#     + RELEASE_FILE: The loaded release file.
#     + PRJ_DOC_DIR: Documentation for the project.
#       Default: ${DOC_DIR}/${PROJECT_NAME}-${PRJ_VER}
#

IF(NOT DEFINED _MANAGE_VERSION_CMAKE_)
    SET(_MANAGE_VERSION_CMAKE_ "DEFINED")
    INCLUDE(ManageMessage)
    M_MSG(${M_INFO1} "CMAKE_HOST_SYSTEM=${CMAKE_HOST_SYSTEM}")
    M_MSG(${M_INFO1} "CMAKE_HOST_SYSTEM_NAME=${CMAKE_HOST_SYSTEM_NAME}")
    M_MSG(${M_INFO1} "CMAKE_HOST_SYSTEM_PROCESSOR=${CMAKE_HOST_SYSTEM_PROCESSOR}")
    M_MSG(${M_INFO1} "CMAKE_HOST_SYSTEM_VERSION=${CMAKE_HOST_SYSTEM_VERSION}")
    INCLUDE(ManageVariable)

    MACRO(LOAD_RELEASE_FILE releaseFile)
	COMMAND_OUTPUT_TO_VARIABLE(_grep_line grep -F "[Changes]" -n -m 1 ${releaseFile})

	SET(RELEASE_FILE ${releaseFile})
	#MESSAGE("_grep_line=|${_grep_line}|")
	IF("${_grep_line}" STREQUAL "")
	    MESSAGE(FATAL_ERROR "${releaseFile} does not have a [Changes] tag!")
	ENDIF("${_grep_line}" STREQUAL "")
	STRING(REGEX REPLACE ":.*" "" _line_num "${_grep_line}")


	# Read header
	SET(_release_file_header "${CMAKE_FEDORA_TMP_DIR}/${releaseFile}_HEADER")
	MATH(EXPR _setting_line_num ${_line_num}-1)
	COMMAND_OUTPUT_TO_VARIABLE(_releaseFile_head head -n ${_setting_line_num} ${releaseFile})
	FILE(WRITE "${_release_file_header}" "${_releaseFile_head}")
	SETTING_FILE_GET_ALL_VARIABLES("${_release_file_header}")
	SET(CHANGE_SUMMARY "${SUMMARY}")

	ADD_DEFINITIONS(-DPRJ_VER="${PRJ_VER}")
	SET_COMPILE_ENV(PRJ_DOC_DIR "${DOC_DIR}/${PROJECT_NAME}-${PRJ_VER}"
	    DISPLAY PATH "Project docdir prefix")

	# Read [Changes] Section
	SET(_release_file_changes "${CMAKE_FEDORA_TMP_DIR}/${releaseFile}_CHANGES")
	MATH(EXPR _line_num ${_line_num}+1)
	COMMAND_OUTPUT_TO_VARIABLE(CHANGELOG_ITEMS tail -n +${_line_num} ${releaseFile})
	FILE(WRITE "${_release_file_changes}" "${CHANGELOG_ITEMS}")

	INCLUDE(DateTimeFormat)
	FILE(READ "ChangeLog.prev" CHANGELOG_PREV)

	SET(CMAKE_CACHE_TXT "CMakeCache.txt")
	# PRJ_VER won't be updated until the removal of CMAKE_CACHE_TXT
	# and execution of cmake .
	SET(_version_check_cmd grep -e 'PRJ_VER=' ${RELEASE_FILE} |  tr -d '\\r\\n' | sed -e s/PRJ_VER=//)
	ADD_CUSTOM_TARGET(version_check
	    COMMAND ${CMAKE_COMMAND} -E echo "PRJ_VER=${PRJ_VER}"
	    COMMAND ${CMAKE_COMMAND} -E echo "Release file="`eval \"${_version_check_cmd}\"`
	    COMMAND test \"`${_version_check_cmd}`\" = \"\" -o \"`${_version_check_cmd}`\" = "${PRJ_VER}"
	   || echo Inconsistent version detected. Fixing..
	   && ${CMAKE_COMMAND} -E remove -f ${CMAKE_CACHE_TXT}
	   && ${CMAKE_COMMAND} ${CMAKE_SOURCE_DIR}
	   )

	CONFIGURE_FILE(ChangeLog.in ChangeLog)
	ADD_CUSTOM_COMMAND(OUTPUT ChangeLog  ${CMAKE_CACHE_TXT}
	    COMMAND ${CMAKE_COMMAND} -E remove -f ${CMAKE_CACHE_TXT}
	    COMMAND ${CMAKE_COMMAND} ${CMAKE_SOURCE_DIR}
	    DEPENDS ${releaseFile} ChangeLog.prev
	    COMMENT "ChangeLog or ${CMAKE_CACHE_TXT} is older than ${releaseFile}. Rebuilding"
	    VERBATIM
	    )

	ADD_CUSTOM_TARGET(changelog ALL
	    DEPENDS ChangeLog ${CMAKE_CACHE_TXT}
	    )

	#ADD_CUSTOM_COMMAND(OUTPUT ChangeLog
	#    COMMAND ${CMAKE_COMMAND} -E echo "* ${TODAY_CHANGELOG} ${MAINTAINER} - ${PRJ_VER}" > ChangeLog
	#    COMMAND cat ${releaseFile}_NO_PACK_CHANGELOG_ITEM  >> ChangeLog
	#    COMMAND echo -e "\\n" >> ChangeLog
	#    COMMAND cat ChangeLog.prev >> ChangeLog
	#    DEPENDS ${CMAKE_SOURCE_DIR}/${releaseFile} ${CMAKE_SOURCE_DIR}/ChangeLog.prev
	#    COMMENT "Building ChangeLog"
	#    VERBATIM
	#    )

	# By this time,
    ENDMACRO(LOAD_RELEASE_FILE releaseFile)

ENDIF(NOT DEFINED _MANAGE_VERSION_CMAKE_)

