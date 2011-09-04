# - Software Translation support
# This module supports software translation by:
#   1) Creates gettext related targets.
#   2) Communicate to Zanata servers.
#
# The Gettext part of this module is from FindGettext.cmake of cmake,
# but it is included here because:
#  1. Bug of GETTEXT_CREATE_TRANSLATIONS make it unable to be include in 'All'
#  2. It does not support xgettext
#
# Defines following variables:
#   + XGETTEXT_OPTIONS_C: Usual xgettext options for C programs.
#
# Defines following macros:
#   GETTEXT_CREATE_POT([potFile]
#     [OPTIONS xgettext_options]
#     SRC list_of_source_files
#   )
#   - Generate .pot file.
#     Arguments:
#     + potFile: pot file to be generated.
#       Default: ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pot
#     + xgettext_options: (optional) xgettext_options.
#       Default: No options.
#     + list_of_source_files: List of source files that contains msgid.
#     Targets:
#     + pot_file: Generate a pot file with the file name specified in potFile.
#     Defines:
#
#   GETTEXT_CREATE_TRANSLATIONS ( [potFile] [ALL] locale1 ... localeN
#     [COMMENT comment] )
#   - This will create a target "translations" which converts given input po
#     files into the binary output mo files. If the ALL option is used, the
#     translations will also be created when building with "make all"
#     Arguments:
#     + potFile: pot file to be referred.
#       Default: ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pot
#     + ALL: (Optional) target "translations" is included when building with
#       "make all"
#     + locale1 ... localeN: locale to be built.
#     + comment: (Optional) Comment for target "translations".
#     Targets:
#     + translations: Converts input po files into the binary output mo files.
#
#   USE_GETTEXT [ALL] SRCS src1 [src2 [...]]
#	LOCALES locale1 [locale2 [...]]
#	[POTFILE potfile]
#	[XGETTEXT_OPTIONS xgettextOpt]]
#	)
#   - Provide Gettext support like generate .pot file and
#     a target "translations" which converts given input po
#     files into the binary output mo files. If the "ALL" option is used, the
#     translations will also be created when building with "make all"
#     Arguments:
#     + ALL: (Optional) target "translations" is included when building with
#       "make all"
#     + SRCS src1 [src2 [...]]: File list of source code that contains msgid.
#     + LOCALE locale1 [local2 [...]]: Locale list to be generated.
#       Currently, only the format: lang_Region (such as fr_FR) is supported.
#     + POTFILE potFile: (optional) pot file to be referred.
#       Default: ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pot
#     + XGETTEXT_OPTIONS xgettextOpt: (optional) xgettext_options.
#       Default: ${XGETTEXT_OPTIONS_C}
#     Defines following variables:
#     + GETTEXT_MSGMERGE_EXECUTABLE: the full path to the msgmerge tool.
#     + GETTEXT_MSGFMT_EXECUTABLE: the full path to the msgfmt tool.
#     + XGETTEXT_EXECUTABLE: the full path to the xgettext.
#     Targets:
#     + pot_file: Generate the pot_file.
#     + translations: Converts input po files into the binary output mo files.
#
#   USE_ZANATA(serverUrl [ALL] [SRCDIR srcdir] [TRANSDIR transdir] [DSTDIR dstdir])
#   - Use Zanata (was flies) as translation service.
#     Arguments:
#     + serverUrl: The URL of Zanata server
#     + ALL: (Optional) Do "zanata po pull" for "make all
#     + SRCDIR srcdir: (Optional) Directory that contain the source text file
#       to be translated. Usually the directory that contains
#       <ProjectName>.pot, message.pot or message.po
#       Passed as --srcDir of zanata command line option.
#     + TRANSDIR transdir: (Optional) Directory that contain the translated
#       text. Usually the directory that contains *.po,
#       message.pot or message.po
#       Passed as --transDir of zanata command line option.
#     + DSTDIR dstdir: (Optional) Directory that contain the translated
#       text. Usually the directory that contains *.po,
#       message.pot or message.po
#       Passed as --dstDir of zanata command line option.
#


IF(NOT DEFINED _MANAGE_TRANSLATION_CMAKE_)
    SET(_MANAGE_TRANSLATION_CMAKE_ "DEFINED")
    SET(XGETTEXT_OPTIONS_C
	--language=C --keyword=_ --keyword=N_ --keyword=C_:1c,2 --keyword=NC_:1c,2 -s
	--package-name=${PROJECT_NAME} --package-version=${PRJ_VER})
    INCLUDE(ManageMessage)


    #========================================
    # GETTEXT support

    MACRO(USE_GETTEXT_INIT)
	FIND_PROGRAM(XGETTEXT_EXECUTABLE xgettext)
	IF(XGETTEXT_EXECUTABLE STREQUAL "XGETTEXT_EXECUTABLE-NOTFOUND")
	    SET(_gettext_dependency_missing 1)
	    M_MSG(${M_OFF} "xgettext not found! gettext support disabled.")
	ENDIF(XGETTEXT_EXECUTABLE STREQUAL "XGETTEXT_EXECUTABLE-NOTFOUND")

	FIND_PROGRAM(GETTEXT_MSGMERGE_EXECUTABLE msgmerge)
	IF(GETTEXT_MSGMERGE_EXECUTABLE STREQUAL "GETTEXT_MSGMERGE_EXECUTABLE-NOTFOUND")
	    SET(_gettext_dependency_missing 1)
	    M_MSG(${M_OFF} "msgmerge not found! gettext support disabled.")
	ENDIF(GETTEXT_MSGMERGE_EXECUTABLE STREQUAL "GETTEXT_MSGMERGE_EXECUTABLE-NOTFOUND")

	FIND_PROGRAM(GETTEXT_MSGFMT_EXECUTABLE msgfmt)
	IF(GETTEXT_MSGFMT_EXECUTABLE STREQUAL "GETTEXT_MSGFMT_EXECUTABLE-NOTFOUND")
	    SET(_gettext_dependency_missing 1)
	    M_MSG(${M_OFF} "msgfmt not found! gettext support disabled.")
	ENDIF(GETTEXT_MSGFMT_EXECUTABLE STREQUAL "GETTEXT_MSGFMT_EXECUTABLE-NOTFOUND")

    ENDMACRO(USE_GETTEXT_INIT)

    MACRO(USE_GETTEXT)
	SET(_gettext_dependency_missing 0)
	USE_GETTEXT_INIT()
	IF(${_gettext_dependency_missing} EQUAL 0)
	    SET(_stage)
	    SET(_all)
	    SET(_src_list)
	    SET(_src_list_abs)
	    SET(_locale_list)
	    SET(_potFile)
	    SET(_xgettext_option_list)
	    FOREACH(_arg ${ARGN})
		IF(_arg STREQUAL "ALL")
		    SET(_all "ALL")
		ELSEIF(_arg STREQUAL "SRCS")
		    SET(_stage "SRCS")
		ELSEIF(_arg STREQUAL "LOCALES")
		    SET(_stage "LOCALES")
		ELSEIF(_arg STREQUAL "XGETTEXT_OPTIONS")
		    SET(_stage "XGETTEXT_OPTIONS")
		ELSEIF(_arg STREQUAL "POTFILE")
		    SET(_stage "POTFILE")
		ELSE(_arg STREQUAL "ALL")
		    IF(_stage STREQUAL "SRCS")
			FILE(RELATIVE_PATH _relFile ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/${_arg})
			LIST(APPEND _src_list ${_relFile})
			GET_FILENAME_COMPONENT(_absFile ${_arg} ABSOLUTE)
			LIST(APPEND _src_list_abs ${_absFile})
		    ELSEIF(_stage STREQUAL "LOCALES")
			LIST(APPEND _locale_list ${_arg})
		    ELSEIF(_stage STREQUAL "XGETTEXT_OPTIONS")
			LIST(APPEND _xgettext_option_list ${_arg})
		    ELSEIF(_stage STREQUAL "POTFILE")
			SET(_potFile "${_arg}")
		    ELSE(_stage STREQUAL "SRCS")
			M_MSG(${M_WARN} "USE_GETTEXT: not recognizing arg ${_arg}")
		    ENDIF(_stage STREQUAL "SRCS")
		ENDIF(_arg STREQUAL "ALL")
	    ENDFOREACH(_arg ${_args} ${ARGN})

	    # Default values
	    IF(_xgettext_option_list STREQUAL "")
		SET(_xgettext_option_list ${XGETTEXT_OPTIONS_C})
	    ENDIF(_xgettext_option_list STREQUAL "")

	    IF("${_potFile}" STREQUAL "")
		SET(_potFile "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pot")
	    ENDIF("${_potFile}" STREQUAL "")

	    M_MSG(${M_INFO2} "XGETTEXT=${XGETTEXT_EXECUTABLE} ${_xgettext_option_list} -o ${_potFile} ${_src_list}")
	    ADD_CUSTOM_COMMAND(OUTPUT ${_potFile}
		COMMAND ${XGETTEXT_EXECUTABLE} ${_xgettext_option_list} -o ${_potFile} ${_src_list}
		DEPENDS ${_src_list_abs}
		WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
		COMMENT "Extract translatable messages to ${_potFile}"
		)

	    ADD_CUSTOM_TARGET(pot_file ${_all}
		DEPENDS ${_potFile}
		)

	    ### Generating translation
	    SET(_gmoFile_list)
	    GET_FILENAME_COMPONENT(_potBasename ${_potFile} NAME_WE)
	    GET_FILENAME_COMPONENT(_potDir ${_potFile} PATH)
	    GET_FILENAME_COMPONENT(_absPotFile ${_potFile} ABSOLUTE)
	    GET_FILENAME_COMPONENT(_absPotDir ${_absPotFile} PATH)
	    FOREACH(_locale ${_locale_list})
		SET(_gmoFile ${_absPotDir}/${_locale}.gmo)
		SET(_absFile ${_absPotDir}/${_locale}.po)
		ADD_CUSTOM_COMMAND(	OUTPUT ${_gmoFile}
		    COMMAND ${GETTEXT_MSGMERGE_EXECUTABLE} --quiet --update --backup=none
		    -s ${_absFile} ${_potFile}
		    COMMAND ${GETTEXT_MSGFMT_EXECUTABLE} -o ${_gmoFile} ${_absFile}
		    DEPENDS ${_potFile} ${_absFile}
		    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
		    COMMENT "Generating ${_locale} translation"
		    )

		#MESSAGE("_absFile=${_absFile} _absPotDir=${_absPotDir} _lang=${_lang} curr_bin=${CMAKE_CURRENT_BINARY_DIR}")
		INSTALL(FILES ${_gmoFile} DESTINATION share/locale/${_locale}/LC_MESSAGES RENAME ${_potBasename}.mo)
		LIST(APPEND _gmoFile_list ${_gmoFile})
	    ENDFOREACH(_locale ${_locale_list})
	    MESSAGE("_gmoFile_list=${_gmoFile_list}")

	    ADD_CUSTOM_TARGET(translations ${_all}
		DEPENDS ${_gmoFile_list}
		COMMENT "Generate translation"
		)
	ENDIF(${_gettext_dependency_missing} EQUAL 0)
    ENDMACRO(USE_GETTEXT)


    #========================================
    # ZANATA support
    MACRO(USE_ZANATA serverUrl)
	SET(ZANATA_SERVER "${serverUrl}")
	SET(ZANATA_XML_SEARCH_PATH ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_SOURCE_DIR})
	FIND_PROGRAM(ZANATA_CMD zanata)
	SET(_failed 0)
	IF(ZANATA_CMD STREQUAL "ZANATA_CMD-NOTFOUND")
	    SET(_failed 1)
	    M_MSG(${M_OFF} "zanata (python client) not found! zanata support disabled.")
	ENDIF(ZANATA_CMD STREQUAL "ZANATA_CMD-NOTFOUND")

	IF(NOT EXISTS $ENV{HOME}/.config/zanata.ini)
	    SET(_failed 1)
	    M_MSG(${M_OFF} "~/.config/zanata.ini is not found! Zanata support disabled.")
	ENDIF(NOT EXISTS $ENV{HOME}/.config/zanata.ini)

	SET(_zanata_xml "")
	FIND_PATH(_zanata_xml_in_dir "zanata.xml.in" PATHS ${ZANATA_XML_SEARCH_PATH})
	IF(NOT "${_zanata_xml_in_dir}" MATCHES "NOTFOUND")
	    SET(_zanata_xml_in ${_zanata_xml_in_dir}/zanata.xml.in)
	    M_MSG(${M_INFO1} "USE_ZANATA:_zanata_xml_in=${_zanata_xml_in}")
	    SET(_zanata_xml ${_zanata_xml_in_dir}/zanata.xml)
	    CONFIGURE_FILE(${_zanata_xml_in} ${_zanata_xml} @ONLY)
	ENDIF(NOT "${_zanata_xml_in_dir}" MATCHES "NOTFOUND")

	IF(NOT "${_zanata_xml}" STREQUAL "")
	    FIND_PATH(_zanata_xml_dir "zanata.xml" PATHS ${ZANATA_XML_SEARCH_PATH})
	    IF(NOT "${_zanata_xml_dir}" MATCHES "NOTFOUND")
		SET(_zanata_xml "${_zanata_xml_dir}/zanata.xml")
	    ELSE(NOT "${_zanata_xml_dir}" MATCHES "NOTFOUND")
		SET(_failed 1)
		M_MSG(${M_OFF} "zanata.xml not found in ${ZANATA_XML_SEARCH_PATH}! zanata support disabled.")
	    ENDIF(NOT "${_zanata_xml_dir}" MATCHES "NOTFOUND")
	ENDIF(NOT "${_zanata_xml}" STREQUAL "")

	IF(_failed EQUAL 0)
	    M_MSG(${M_INFO1} "USE_ZANATA:_zanata_xml=${_zanata_xml}")
	    # Parsing arguments
	    SET(_srcDir)
	    SET(_transDir)
	    SET(_dstDir)
	    SET(_all)
	    FOREACH(_arg ${ARGN})
		IF(_arg STREQUAL "SRCDIR")
		    SET(_stage "SRCDIR")
		ELSEIF(_arg STREQUAL "TRANSDIR")
		    SET(_stage "TRANSDIR")
		ELSEIF(_arg STREQUAL "DSTDIR")
		    SET(_stage "DSTDIR")
		ELSEIF(_arg STREQUAL "ALL")
		    SET(_stage "ALL")
		    SET(_all "ALL")
		ELSE(_arg STREQUAL "SRCDIR")
		    IF(_stage STREQUAL "SRCDIR")
			SET(_srcDir "--srcdir=${_arg}")
		    ELSEIF(_stage STREQUAL "TRANSDIR")
			SET(_transDir "--transdir=${_arg}")
		    ELSEIF(_stage STREQUAL "DSTDIR")
			SET(_dstDir "--dstdir=${_arg}")
		    ENDIF(_stage STREQUAL "SRCDIR")
		ENDIF(_arg STREQUAL "SRCDIR")
	    ENDFOREACH(_arg ${ARGN})

	    SET(_zanata_args --url=${ZANATA_SERVER} --project-id=${PROJECT_NAME}
		--project-config=${_zanata_xml})
	    ADD_CUSTOM_TARGET(zanata_project_create
		COMMAND ${ZANATA_CMD} project create ${PROJECT_NAME} ${_zanata_args}
		"--project-name=${PROJECT_NAME}" "--project-desc=${PRJ_SUMMARY}"
		COMMENT "Create project translation on Zanata server ${serverUrl}"
		VERBATIM
		)
	    ADD_CUSTOM_TARGET(zanata_version_create ${_all}
		COMMAND ${ZANATA_CMD} version create ${PRJ_VER} ${_zanata_args}
		COMMENT "Create version ${PRJ_VER} on Zanata server ${serverUrl}"
		VERBATIM
		)
	    ADD_CUSTOM_TARGET(zanata_po_push ${_all}
		COMMAND ${ZANATA_CMD} po push ${_zanata_args} --project-version=${PRJ_VER}
		${_srcDir} ${_transDir}
		COMMENT "Push the pot files for version ${PRJ_VER}"
		VERBATIM
		)
	    ADD_DEPENDENCIES(zanata_po_push pot_file)
	    ADD_CUSTOM_TARGET(zanata_po_push_import_po ${_all}
		COMMAND yes |
	       	${ZANATA_CMD} po push ${_zanata_args} --project-version=${PRJ_VER}
		${_srcDir} ${_transDir} --import-po
		COMMENT "Push the pot and po files for version ${PRJ_VER}"
		VERBATIM
		)
	    ADD_DEPENDENCIES(zanata_po_push pot_file)

	    ADD_CUSTOM_TARGET(zanata_po_pull
		COMMAND ${ZANATA_CMD} po pull ${_zanata_args} --project-version=${PRJ_VER}
		${_dstDir}
		COMMENT "Pull the pot files for version ${PRJ_VER}"
		VERBATIM
		)
	ENDIF(_failed EQUAL 0)
    ENDMACRO(USE_ZANATA serverUrl)

ENDIF(NOT DEFINED _MANAGE_TRANSLATION_CMAKE_)

