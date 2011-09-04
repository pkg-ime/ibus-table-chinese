# - Read setting files and provides developer only targets.
# This module has macros that generate variables such as
# upload to a hosting services, which are valid to only the developers.
# This is normally done by checking the existence of a developer
# setting file.
#
# Includes:
#    ManageSourceVersionControl
#
# Included by:
#    ManageRelease
#
# Defines following Macros:
#   MANAGE_MAINTAINER_TARGETS_UPLOAD(fileLocalPath [file2LocalPath ..]
#   [DEST_PATH destPath] [FILE_ALIAS fileAlias])
#   - Upload a file to hosting services
#       By default, it will sent to all hosting services defined in
#       HOST_SERVICES
#     Arguments:
#     + fileLocalPath: Local path of the file to be uploaded.
#     + file2LocalPath: (Optional) Local path of 2nd (3rd and so on) file to be uploaded.
#     + DEST_PATH destPath: (Optional) Destination path.
#       Default is "." if DEST_PATH is not used.
#     + HOST_SERVICE hostService: Only sent files to this hosting service.
#       Some properties will get preset if hostSevice is recognized.
#     + FILE_ALIAS fileAlias: (Optional) Alias to be appeared as part of make target.
#       Default: file name is used.
#     Reads following variables:
#     + HOST_SERVICES: list of hosting services to for uploading project
#       files.
#
#   MAINTAINER_SETTING_READ_FILE([filename])
#   - Read the maintainer setting file.
#     It checks the existence of setting file.
#     If it does not exist, this macro acts as a no-op;
#     if it exists, then it reads variables defined in the setting file,
#     and set relevant targets.
#     See the "Setting File Format" section for description of file format.
#     Arguments:
#     + filename: (Optional) Filename of the setting file.
#     Reads following variables:
#     + PRJ_VER: Project version.
#     + CHANGE_SUMMARY: Change summary.
#     Defines following targets:
#     + upload: Upload files to all hosting services.
#     + upload_<hostService>: Upload files to <hostService>.
#
#
# Setting File Format
#
# It is basically the "variable=value" format.
# For variables which accept list, use ';' to separate each element.
# A line start with '#' is deemed as comment.
#
# Recognized Variable:
# Although it does no harm to define other variables in the setting file,
# but this module only recognizes following variables:
#
#   HOSTING_SERVICES
# A list of hosting services that packages are hosted. It allows multiple elements.
#
#   SOURCE_VERSION_CONTROL
# Version control system for the source code. Accepted values: git, hg, svn, cvs.
#
# The services can be defined by following format:
#   <ServiceName>_<PropertyName>=<value>
#
# ServiceName is the name of the hosting service.
# If using a known service name, you may be able to omit some definition such
# like protocol, as they have build in value.
# Do not worry that your hosting service is
# not in the known list, you can still benefit from this module, providing
# your hosting service use supported protocols.
#
# Known service name is: SourceForge, FedoraHosted.
#
#
# PropertyName is a property that is needed to preform the upload.
#    USER: the user name for the hosting service.
#    SITE: the host name of the hosting service.
#    PROTOCOL:  (Optional if service is known) Protocol for upload.
#          Supported: sftp, scp.
#    BATCH: (Optional) File that stores the batch commands.
#    BATCH_TEMPATE: (Optional) File that provides template to for generating
#                   batch commands.
#                   If BATCH is also given: Generated batch file is named
#                   as defined with BATCH;
#                   if BATCH is not given: Generated batch file is named
#                   as ${CMAKE_BINARY_DIR}/BatchUpload-${ServiceName}
#    OPTIONS: (Optional) Other options to be passed.
#
# Example:
#
# For a hosting service "Host1" with git,
# while uploading the source package to "Host2" with sftp.
# The setting file might looks as follows:
#
# SOURCE_VERSION_CONTROL=git
# # No, Host1 is not needed here.
# HOSTING_SERVICES=Host2
#
# Host2_USER=host2account
# Host2_PROTOCOL=sftp
# Host2_SITE=host2hostname
# Host2_BATCH_TEMPLATE=BatchUpload-Host2.in
#

IF(NOT DEFINED _MANAGE_MAINTAINER_TARGETS_CMAKE_)
    SET(_MANAGE_MAINTAINER_TARGETS_CMAKE_ "DEFINED")
    INCLUDE(ManageMessage)

    MACRO(MANAGE_MAINTAINER_TARGETS_SFTP
	    hostService remoteBasePath destPath fileAlias fileLocalPath )
	FIND_PROGRAM(_developer_upload_cmd sftp)
	IF(_developer_upload_cmd STREQUAL "_developer_upload_cmd-NOTFOUND")
	    MESSAGE(FATAL_ERROR "Program sftp is not found!")
	ENDIF(_developer_upload_cmd STREQUAL "_developer_upload_cmd-NOTFOUND")

	IF(NOT "${${hostService}_BATCH_TEMPLATE}" STREQUAL "")
	    IF(NOT "${hostService}_BATCH" STREQUAL "")
		SET(${hostService}_BATCH
		    ${CMAKE_BINARY_DIR}/BatchUpload-${hostService}_NO_PACK)
	    ENDIF(NOT "${hostService}_BATCH" STREQUAL "")
	    CONFIGURE_FILE(${hostService}_BATCH_TEMPLATE ${hostService}_BATCH)
	    SET(PACK_SOURCE_IGNORE_FILES ${PACK_SOURCE_IGNORE_FILES} ${hostService}_BATCH)
	ENDIF(NOT "${${hostService}_BATCH_TEMPLATE}" STREQUAL "")

	IF(NOT "${hostService}_BATCH" STREQUAL "")
	    SET(_developer_upload_cmd "${_developer_upload_cmd} -b ${hostService}_BATCH" )
	ENDIF(NOT "${hostService}_BATCH" STREQUAL "")

	IF(NOT "${hostService}_OPTIONS" STREQUAL "")
	    SET(_developer_upload_cmd "${_developer_upload_cmd} -F ${hostService}_OPTIONS" )
	ENDIF(NOT "${hostService}_OPTIONS" STREQUAL "")

	SET(_developer_upload_cmd "${_developer_upload_cmd} ${${hostService}_USER}@${${hostService}_SITE}")

	ADD_CUSTOM_TARGET(upload_${hostService}_${fileAlias}
	    COMMAND ${_developer_upload_cmd}
	    DEPENDS ${fileLocalPath} ${DEVELOPER_DEPENDS}
	    COMMENT "Uploading the ${fileLocalPath} to ${hostService}..."
	    VERBATIM
	    )
    ENDMACRO(MANAGE_MAINTAINER_TARGETS_SFTP
        hostService remoteBasePath destPath fileAlias fileLocalPath )

    MACRO(MANAGE_MAINTAINER_TARGETS_SCP
	    hostService remoteBasePath destPath fileAlias fileLocalPath)
	FIND_PROGRAM(_developer_upload_cmd scp)
	IF(_developer_upload_cmd STREQUAL "_developer_upload_cmd-NOTFOUND")
	    MESSAGE(FATAL_ERROR "Program scp is not found!")
	ENDIF(_developer_upload_cmd STREQUAL "_developer_upload_cmd-NOTFOUND")

	IF("${remoteBasePath}" STREQUAL ".")
	    IF("${destPath}" STREQUAL ".")
		SET(_dest "")
	    ELSE("${destPath}" STREQUAL ".")
		SET(_dest ":${destPath}")
	    ENDIF("${destPath}" STREQUAL ".")
	ELSE("${remoteBasePath}" STREQUAL ".")
	    IF("${destPath}" STREQUAL ".")
		SET(_dest ":${remoteBasePath}")
	    ELSE("${destPath}" STREQUAL ".")
		SET(_dest ":${remoteBasePath}/${destPath}")
	    ENDIF("${destPath}" STREQUAL ".")
	ENDIF("${remoteBasePath}" STREQUAL ".")

	ADD_CUSTOM_TARGET(upload_${hostService}_${fileAlias}
	    COMMAND ${_developer_upload_cmd} ${${hostService}_OPTIONS} ${fileLocalPath}
	      ${${hostService}_USER}@${${hostService}_SITE}${_dest}
	    DEPENDS ${fileLocalPath} ${DEVELOPER_DEPENDS}
	    COMMENT "Uploading the ${fileLocalPath} to ${hostService}..."
	    VERBATIM
	    )
    ENDMACRO(MANAGE_MAINTAINER_TARGETS_SCP
	hostService fileLocalPath remoteBasePath destPath fileAlias)

    MACRO(MANAGE_MAINTAINER_TARGETS_GOOGLE_UPLOAD)
	FIND_PROGRAM(CURL_CMD curl)
	IF(CURL_CMD STREQUAL "CURL_CMD-NOTFOUND")
	    MESSAGE(FATAL_ERROR "Need curl to perform google upload")
	ENDIF(CURL_CMD STREQUAL "CURL_CMD-NOTFOUND")
    ENDMACRO(MANAGE_MAINTAINER_TARGETS_GOOGLE_UPLOAD)

    MACRO(MANAGE_MAINTAINER_TARGETS_UPLOAD fileLocalPath)
	SET(_destPath ".")
	SET(_remoteBasePath ".")
	GET_FILENAME_COMPONENT(_fileAlias "${fileLocalPath}" NAME)
	SET(_fileLocalPathList ${fileLocalPath})
	SET(_stage "")
	FOREACH(_arg ${ARGN})
	    IF ("${_arg}" STREQUAL "FILE_ALIAS")
		SET(_stage "FILE_ALIAS")
	    ELSEIF("${_arg}" STREQUAL "DEST_PATH")
		SET(_stage "DEST_PATH")
	    ELSE("${_arg}" STREQUAL "FILE_ALIAS")
		IF(_stage STREQUAL "FILE_ALIAS")
		    SET(_fileAlias "${_arg}")
		ELSEIF(_stage STREQUAL "DEST_PATH")
		    SET(_destPath "${_arg}")
		ELSE(_stage STREQUAL "FILE_ALIAS")
		    LIST(APPEND _fileLocalPathList "${_arg}")
		ENDIF(_stage STREQUAL "FILE_ALIAS")
	    ENDIF("${_arg}" STREQUAL "FILE_ALIAS")
	ENDFOREACH(_arg ${ARGN})

	FOREACH(_hostService ${HOSTING_SERVICES})
	    IF("${_hostService}" MATCHES "[Ss][Oo][Uu][Rr][Cc][Ee][Ff][Oo][Rr][Gg][Ee]")
		SET(${_hostService}_PROTOCOL sftp)
		SET(${_hostService}_SITE frs.sourceforge.net)
	    ELSEIF("${_hostService}" MATCHES "[Ff][Ee][Dd][Oo][Rr][Aa][Hh][Oo][Ss][Tt][Ee][Dd]")
		SET(${_hostService}_PROTOCOL scp)
		SET(${_hostService}_SITE fedorahosted.org)
		SET(_remoteBasePath "${PROJECT_NAME}")
	    ELSE("${_hostService}" MATCHES "[Ss][Oo][Uu][Rr][Cc][Ee][Ff][Oo][Rr][Gg][Ee]")
	    ENDIF("${_hostService}" MATCHES "[Ss][Oo][Uu][Rr][Cc][Ee][Ff][Oo][Rr][Gg][Ee]")

	    IF(${_hostService}_PROTOCOL STREQUAL "sftp")
		MANAGE_MAINTAINER_TARGETS_SFTP(${_hostService} "${_remoteBasePath}"
		    "${_destPath}" "${_fileAlias}" "${_fileLocalPathList}")
	    ELSEIF(${_hostService}_PROTOCOL STREQUAL "scp")
		MANAGE_MAINTAINER_TARGETS_SCP(${_hostService} "${_remoteBasePath}"
		    "${_destPath}" "${_fileAlias}" "${_fileLocalPathList}")
	    ENDIF(${_hostService}_PROTOCOL STREQUAL "sftp")
	    ADD_DEPENDENCIES(upload_${_hostService} upload_${_hostService}_${_fileAlias})

	ENDFOREACH(_hostService ${HOSTING_SERVICES})
    ENDMACRO(MANAGE_MAINTAINER_TARGETS_UPLOAD hostService fileLocalPath)

    MACRO(MAINTAINER_SETTING_READ_FILE)
	SET(_disabled 0)
	IF(ARGV0 STREQUAL "")
	    SET(_file ${MAINTAINER_SETTING})
	ELSE(ARGV0 STREQUAL "")
	    SET(_file ${ARGV0})
	ENDIF(ARGV0 STREQUAL "")

	IF(_file STREQUAL "")
	    M_MSG(${M_OFF} "Maintain setting file is not given,  disable maintainer targets")
	    SET(_disabled 1)
	ELSEIF(NOT EXISTS ${_file})
	    M_MSG(${M_OFF} "Maintain setting file ${_file} is not found,  disable maintainer targets")
	    SET(_disabled 1)
	ENDIF(_file STREQUAL "")

	GET_TARGET_PROPERTY(_target_exists upload EXISTS)
	IF(_target_exists EQUAL 1)
	    M_MSG(${M_INFO1} "Maintain setting file ${_file} has been loaded before")
	    SET(_disabled 1)
	ENDIF(_target_exists EQUAL 1)

	IF(_disabled EQUAL 0)
	    INCLUDE(ManageVariable)
	    INCLUDE(ManageVersion)
	    INCLUDE(ManageSourceVersionControl)
	    SETTING_FILE_GET_ALL_VARIABLES("${_file}" UNQUOTED)

	    #===================================================================
	    # Targets:
	    ADD_CUSTOM_TARGET(upload
		COMMENT "Uploading source to hosting services"
		)

	    SET_TARGET_PROPERTIES(upload PROPERTIES EXISTS 1)

	    IF(SOURCE_VERSION_CONTROL STREQUAL "git")
		MANAGE_SOURCE_VERSION_CONTROL_GIT()
	    ELSEIF(SOURCE_VERSION_CONTROL STREQUAL "hg")
		MANAGE_SOURCE_VERSION_CONTROL_HG()
	    ELSEIF(SOURCE_VERSION_CONTROL STREQUAL "svn")
		MANAGE_SOURCE_VERSION_CONTROL_SVN()
	    ELSEIF(SOURCE_VERSION_CONTROL STREQUAL "cvs")
		MANAGE_SOURCE_VERSION_CONTROL_CVS()
	    ELSE(SOURCE_VERSION_CONTROL STREQUAL "cvs")
		M_MSG(${M_OFF} "SOURCE_VERSION_CONTROL is not valid, Source verion control support disabled.")
	    ENDIF(SOURCE_VERSION_CONTROL STREQUAL "git")

	    #
	    ADD_DEPENDENCIES(upload tag)

	    # Setting for each hosting service
	    FOREACH(_hostService ${HOSTING_SERVICES})
		ADD_CUSTOM_TARGET(upload_${_hostService})
		ADD_DEPENDENCIES(upload upload_${_hostService})
	    ENDFOREACH(_hostService ${HOSTING_SERVICES})
	ENDIF(_disabled EQUAL 0)
    ENDMACRO(MAINTAINER_SETTING_READ_FILE filename)

ENDIF(NOT DEFINED _MANAGE_MAINTAINER_TARGETS_CMAKE_)

