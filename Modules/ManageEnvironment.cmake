# - Manage build environment such as environment variables and compile flags.
# This module predefine various environment variables, cmake policies, and
# compile flags.
#
# The setting can be viewed and modified by ccmake.
#
# List of frequently used variable and compile flags:
#    + CMAKE_INSTALL_PREFIX: Compile flag whose value is ${CMAKE_INSTALL_PREFIX}.
#    + BIN_DIR: Directory for executable.
#      Default:  ${CMAKE_INSTALL_PREFIX}/bin
#    + DATA_DIR: Directory for architecture independent data files.
#      Default: ${CMAKE_INSTALL_PREFIX}/share
#    + DOC_DIR: Directory for documentation
#      Default: ${DATA_DIR}/doc
#    + SYSCONF_DIR: System wide configuration files.
#      Default: /etc
#    + LIB_DIR: System wide library path.
#      Default: ${CMAKE_INSTALL_PREFIX}/lib for 32 bit,
#               ${CMAKE_INSTALL_PREFIX}/lib64 for 64 bit.
#    + LIBEXEC_DIR: Executables that are not meant to be executed by user directly.
#      Default: ${CMAKE_INSTALL_PREFIX}/libexec
#    + PROJECT_NAME: Project name
#
# Defines following macros:
#   SET_COMPILE_ENV(var default_value [ENV_NAME env_name]
#     [DISPLAY type docstring])
#     - Add compiler environment with a variable and its value.
#       If the variable is not defined in cmake, the value is obtained from
#       following priority:
#       1. Environment variable with the same name (or specified via ENV_NAME)
#       2. Parameter default_value
#       Parameters:
#       + var: Variable to be set
#       + default_value: Default value of the var
#       + env_name: (Optional)The name of environment variable.
#         Only need if different from var.
#       + type: is used by the CMake GUI to choose a widget with
#         which the user sets a value. Valid values are:
#           PATH     = Directory chooser dialog.
#           STRING   = Arbitrary string.
#           BOOL     = Boolean ON/OFF checkbox.
#           INTERNAL = No GUI entry (used for persistent variables).
#       + docstring: Label to show ing CMAKE GUI.
#
#  SET_USUAL_COMPILE_ENVS()
#  - Set the most often used variable and compile flags.
#    It defines compile flags according to the values of corresponding variables,
#    usually under the same or similar name.
#    If a corresponding variable is not defined yet, then a default value is assigned
#    to that variable, then define the flag.
#
#    Defines following flags according to the variable with same name.
#    + CMAKE_INSTALL_PREFIX: Compile flag whose value is ${CMAKE_INSTALL_PREFIX}.
#    + BIN_DIR: Directory for executable.
#      Default:  ${CMAKE_INSTALL_PREFIX}/bin
#    + DATA_DIR: Directory for architecture independent data files.
#      Default: ${CMAKE_INSTALL_PREFIX}/share
#    + DOC_DIR: Directory for documentation
#      Default: ${DATA_DIR}/doc
#    + SYSCONF_DIR: System wide configuration files.
#      Default: /etc
#    + LIB_DIR: System wide library path.
#      Default: ${CMAKE_INSTALL_PREFIX}/lib for 32 bit,
#               ${CMAKE_INSTALL_PREFIX}/lib64 for 64 bit.
#    + LIBEXEC_DIR: Executables that are not meant to be executed by user directly.
#      Default: ${CMAKE_INSTALL_PREFIX}/libexec
#    + PROJECT_NAME: Project name
#    + PRJ_VER: Project version
#    + PRJ_DATA_DIR: Data directory for the project.
#      Default: ${DATA_DIR}/${PROJECT_NAME}
#    + PRJ_DOC_DIR: DocuFILEPATH = File chooser dialog.
#      Default: ${DOC_DIR}/${PROJECT_NAME}-${PRJ_VER}

# This module

# This module supports software translation by:

IF(NOT DEFINED _MANAGE_ENVIRONMENT_CMAKE_)
    SET(_MANAGE_ENVIRONMENT_CMAKE_ "DEFINED")
    SET(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS ON)
    CMAKE_POLICY(VERSION 2.6)

    MACRO(SET_COMPILE_ENV var default_value)
	SET(_stage "")
	SET(_type "INTERNAL")
	SET(_docstring "${var}")
	SET(_env "${var}")
	FOREACH(_arg ${ARGN})
	    IF(_arg STREQUAL "ENV_NAME")
	    ELSEIF(_arg STREQUAL "DISPLAY")
		SET(_stage TYPE)
	    ELSE(_arg STREQUAL "ENV_NAME")
		IF(_stage STREQUAL "ENV_NAME")
		    SET(_env "${_arg}")
		ELSEIF(_stage STREQUAL "TYPE")
		    SET(_type "${_arg}")
		    SET(_stage DOCSTRING)
		ELSEIF(_stage STREQUAL "DOCSTRING")
		    SET(_docstring "${_arg}")
		ENDIF(_stage STREQUAL "ENV_NAME")
	    ENDIF(_arg STREQUAL "ENV_NAME")
	ENDFOREACH(_arg ${ARGN})

	# Set the variable
	IF(DEFINED ${var})
	    SET(${var} "${${var}}" CACHE ${_type} "${_docstring}")
	ELSEIF(NOT "$ENV{${_env}}" STREQUAL "")
	    SET(${var} "$ENV{${_env}}" CACHE ${_type} "${_docstring}")
	ELSE(DEFINED ${var})
	    # Default value
	    SET(${var} "${default_value}" CACHE ${_type} "${_docstring}")
	ENDIF(DEFINED ${var})
	ADD_DEFINITIONS(-D${_env}='"${${var}}"')
    ENDMACRO(SET_COMPILE_ENV var default_value)

    MACRO(MANAGE_CMAKE_POLICY policyName defaultValue)
	IF(POLICY ${policyName})
	    CMAKE_POLICY(SET "${policyName}" "${defaultValue}")
	ENDIF(POLICY ${policyName})
    ENDMACRO(MANAGE_CMAKE_POLICY policyName defaultValue)

    ####################################################################
    # Recommended policy setting
    #
    # CMP0005: Preprocessor definition values are now escaped automatically.
    # OLD:Preprocessor definition values are not escaped.
    MANAGE_CMAKE_POLICY(CMP0005 NEW)

    # CMP0009: FILE GLOB_RECURSE calls should not follow symlinks by default.
    # OLD: FILE GLOB_RECURSE calls follow symlinks
    MANAGE_CMAKE_POLICY(CMP0009 NEW)

    # CMP0017: Prefer files from the CMake module directory when including from there.
    # OLD: Prefer files from CMAKE_MODULE_PATH regardless
    MANAGE_CMAKE_POLICY(CMP0017 OLD)

    ####################################################################
    # CMake Variables
    #
    SET(CMAKE_INSTALL_PREFIX "/usr")
    SET_COMPILE_ENV(CMAKE_INSTALL_PREFIX "/usr"
	DISPLAY PATH "Install dir prefix")
    SET_COMPILE_ENV(BIN_DIR  "${CMAKE_INSTALL_PREFIX}/bin"
	DISPLAY  PATH "Binary dir")
    SET_COMPILE_ENV(DATA_DIR "${CMAKE_INSTALL_PREFIX}/share"
	DISPLAY PATH "Data dir")
    SET_COMPILE_ENV(DOC_DIR  "${DATA_DIR}/doc"
	DISPLAY PATH "Documentation dir")
    SET_COMPILE_ENV(SYSCONF_DIR "/etc"
	DISPLAY PATH "System configuration dir")
    SET_COMPILE_ENV(LIBEXEC_DIR "${CMAKE_INSTALL_PREFIX}/libexec"
	DISPLAY	PATH "LIBEXEC dir")

    SET(IS64 "")
    IF( $ENV{MACHTYPE} MATCHES "64")
	SET(IS64 "64")
    ENDIF( $ENV{MACHTYPE} MATCHES "64")
    ADD_DEFINITIONS(-DIS_64='"${IS64}"')

    IF(NOT DEFINED LIB_DIR)
	SET_COMPILE_ENV(LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib${IS64}")
    ENDIF(NOT DEFINED LIB_DIR)

    IF(DEFINED PROJECT_NAME)
	ADD_DEFINITIONS(-DPROJECT_NAME='"${PROJECT_NAME}"')
	SET_COMPILE_ENV(PRJ_DATA_DIR "${DATA_DIR}/${PROJECT_NAME}")

	IF(DEFINED PRJ_VER)
	ENDIF(DEFINED PRJ_VER)
    ENDIF(DEFINED PROJECT_NAME)

    # Directory to store cmake-fedora specific temporary files.
    IF(NOT CMAKE_FEDORA_TMP_DIR)
	SET(CMAKE_FEDORA_TMP_DIR "${CMAKE_BINARY_DIR}/NO_PACK")
    ENDIF(NOT CMAKE_FEDORA_TMP_DIR)

    ADD_CUSTOM_COMMAND(OUTPUT ${CMAKE_FEDORA_TMP_DIR}
	COMMAND cmake -E make_directory ${CMAKE_FEDORA_TMP_DIR}
	COMMENT "Create CMAKE_FEDORA_TMP_DIR"
	)
ENDIF(NOT DEFINED _MANAGE_ENVIRONMENT_CMAKE_)
