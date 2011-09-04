# - Fedora release tasks related to koji, fedpkg and bodhi
#
# This module provides convenient targets and macroes for scratch build,
# submit, and build on koji, using the GIT infrastructure,
# as well as bodhi update.
# Since this module is mainly for Fedora developers/maintainers,
# This module checks ~/.fedora-upload-ca.cert
#
# Includes:
#   ManageMessage
#   ManageSourceVersionControl
#
# Reads following variables:
#   FEDORA_CANDIDATE_PREFERRED:
#     Set to "True" to build against updates-candidate if possible.
#   EPEL_CANDIDATE_PREFERRED:
#     Set to "True" to build against testing-candidate if possible.
# Defines following variable:
#   FEDORA_RAWHIDE_TAG: Koji tag for rawhide.
#   FEDORA_NEXT_RELEASE: Number of Fedora upcoming release, e.g. 16
#   FEDORA_NEXT_RELEASE_TAG: Fedora's upcoming release. e.g. f16
#   FEDORA_LATEST_RELEASE: Number of Fedora latest release, e.g. 15
#   FEDORA_PREVIOUS_RELEASE: Number of Fedora latest release, e.g. 14
#   FEDORA_SUPPORTED_RELEASE_TAGS: Releases that are currently supported.
#   FEDORA_CURRENT_RELEASE_TAGS: Releases that are recommend to build against.
#     It is essentially FEDORA_RAWHIDE_TAG + FEDORA_NEXT_RELEASE_TAG
#                       + FEDORA_SUPPORTED_RELEASE_TAGS.
# Defines following macros:
#   RELEASE_ON_FEDORA(srpm [TAGS [tag1 [tag2 ...]])
#   - This call USE_FEDPKG and USE_BODHI and set the corresponding
#     dependencies. This macro is recommended than calling USE_FEDPKG and
#     USE_BODHI directly.
#     Defines following targets:
#     + release_on_fedora: Make necessary steps for releasing on fedora,
#       such as making source file tarballs, source rpms, build with fedpkg
#       and upload to bodhi.
#
#   USE_FEDPKG(srpm [NOKOJI_SCRATCH_BUILD] [TAGS [tag1 [tag2 ...]])
#   - Use fedpkg targets if ~/.fedora-upload-ca.cert exists.
#     If ~/.fedora-upload-ca.cert does not exists, this marcos run as an empty
#     macro.
#     Argument:
#     + srpm: srpm file with path.
#     + NOKOJI_SCRATCH_BUILD: Don't use koji_scratch_build before commit with
#       fedpkg.
#     + tag1, tag2...: Dist tags such as f14, f13, el5.
#       if no defined, then tags in FEDORA_CURRENT_RELEASE_TAGS are used.
#     Reads following variables:
#     + FEDORA_RELEASE_TAGS: (optional) Release to be built.
#       Note this override the setting from [tag1 [tag2 ...].
#       Thus, this variable can be defined in RELEASE.txt to specify the
#       dist tags to be built.
#     + FEDPKG_DIR: Directory for fedpkg checkout.
#       Default: FedPkg.
#     Defines following targets:
#     + fedpkg_scratch_build: Perform scratch build with fedpkg.
#     + fedpkg_submit: Submit build with fedpkg.
#     + fedpkg_build: Perform build with fedpkg.
#     + fedpkg_update: Update with fedpkg.
#     + koji_scratch_build: Sent srpm to Koji for scratch build
#
#   USE_BODHI([KARMA karmaValue] [TAGS [tag1 [tag2 ...]]  )
#   - Use bodhi targets with bodhi command line client.
#     Argument:
#     + KARMA karmaValue: Set the karma threshold. Default is 3.
#     + TAGS tag1, ....: Dist Tags for submission. Accepts formats like f14,
#        fc14, el6.
#     Reads following variables:
#     + BODHI_UPDATE_TYPE: Type of update. Default is "bugfix".
#     + BODHI_USER: Login username for bodhi (for -u).
#     + FEDORA_CURRENT_RELEASE_TAGS: If TAGS is not defined, then it will be
#       use as default tags.
#     + SUGGEST_REBOOT: Whether this update require reboot to take effect.
#       Default is "False".
#     Defines following targets:
#     + bodhi_new: Send a new release to bodhi.
#

IF(NOT DEFINED _MANAGE_RELEASE_ON_FEDORA_)
    SET(_MANAGE_RELEASE_ON_FEDORA_ "DEFINED")
    SET(FEDORA_EPEL_RELEASE_TAGS el6 el5)
    SET(FEDORA_RAWHIDE_TAG rawhide)
    SET(FEDORA_NEXT_RELEASE 16)
    SET(FEDORA_NEXT_RELEASE_TAGS f${FEDORA_NEXT_RELEASE})
    MATH(EXPR FEDORA_LATEST_RELEASE ${FEDORA_NEXT_RELEASE}-1)
    MATH(EXPR FEDORA_PREVIOUS_RELEASE ${FEDORA_LATEST_RELEASE}-1)
    SET(FEDORA_SUPPORTED_RELEASE_TAGS "f${FEDORA_LATEST_RELEASE};f${FEDORA_PREVIOUS_RELEASE}")
    SET(FEDORA_CURRENT_RELEASE_TAGS ${FEDORA_RAWHIDE_TAG}
	${FEDORA_NEXT_RELEASE_TAGS} ${FEDORA_SUPPORTED_RELEASE_TAGS})
    IF("${FEDPKG_DIR}" STREQUAL "")
	SET(FEDPKG_DIR "FedPkg")
    ENDIF("${FEDPKG_DIR}" STREQUAL "")

    IF(NOT DEFINED FEDORA_KOJI_TAG_POSTFIX)
	SET(FEDORA_KOJI_TAG_POSTFIX "")
    ENDIF(NOT DEFINED FEDORA_KOJI_TAG_POSTFIX)

    IF(NOT DEFINED EPEL_KOJI_TAG_POSTFIX)
	SET(EPEL_KOJI_TAG_POSTFIX "-testing-candidate")
    ENDIF(NOT DEFINED EPEL_KOJI_TAG_POSTFIX)

    SET(_bodhi_template_file "bodhi.NO_PACK.template")
    SET(PACK_SOURCE_IGNORE_FILES ${PACK_SOURCE_IGNORE_FILES} "/${FEDPKG_DIR}/")

    # Need the definition of source version control first, as we need to check tag file.
    INCLUDE(ManageSourceVersionControl)
    INCLUDE(ManageMessage)

    SET(_FEDORA_DIST_TAGS "")

    MACRO(_manange_release_on_fedora_dist_convert_to_koji_target
	    var dist)
	SET(_dist_prefix "dist-")
	SET(_dist_postfix "")
	IF("${dist}" MATCHES "^el")
	    # EPEL dists
	    STRING(REGEX REPLACE "el\([0-9]+\)" "\\1" _relver  "${dist}")
	    IF(EPEL_CANDIDATE_PREFERRED)
		SET(_dist_postfix "-testing-candidate")
	    ENDIF(EPEL_CANDIDATE_PREFERRED)
	    SET(${var} "${_dist_prefix}${_relver}E-epel${_dist_postfix}")
	ELSEIF("${dist}" MATCHES "^f")
	    # Fedora dists
	    STRING(REGEX REPLACE "f\([0-9]+\)" "\\1" _relver  "${dist}")
	    IF(_relver GREATER 15)
		SET(_dist_prefix "")
	    ENDIF(_relver GREATER 15)
	    IF(FEDORA_CANDIDATE_PREFERRED)
		LIST(FIND FEDORA_SUPPORTED_RELEASE_TAGS "${dist}" _index)
		IF(_index GREATER -1)
		    SET(_dist_postfix "-updates-candidate")
		ENDIF(_index GREATER -1)
	    ENDIF(FEDORA_CANDIDATE_PREFERRED)
	    SET(${var} "${_dist_prefix}${dist}${_dist_postfix}")
	ELSE("${dist}" MATCHES "^el")
	    # Perhaps rawhide, or other custom targets
	    SET(${var} "${_dist_prefix}${dist}")
	ENDIF("${dist}" MATCHES "^el")
    ENDMACRO(_manange_release_on_fedora_dist_convert_to_koji_target
	kojiTarget dist)

    MACRO(_manange_release_on_fedora_parse_args)
	SET(_FEDORA_DIST_TAGS "")
	SET(_FEDORA_KARMA "3")
	SET(_FEDORA_AUTO_KARMA "True")
	SET(_FEDORA_KOJI_SCRATCH 1)
	SET(_FEDORA_DIST_TAGS "")

	SET(_stage "")
	FOREACH(_arg ${ARGN})
	    IF(_arg STREQUAL "NOKOJI_SCRATCH_BUILD")
		SET(_FEDORA_KOJI_SCRATCH 0)
	    ELSEIF(_arg STREQUAL "KARMA")
		SET(_stage "KARMA")
	    ELSEIF(_arg STREQUAL "TAGS")
		# No need to further parsing TAGS, as FEDORA_RELEASE_TAGS
		# override whatever specified after TAGS
		IF(NOT "${FEDORA_RELEASE_TAGS}" STREQUAL "")
		    BREAK()
		ENDIF(NOT "${FEDORA_RELEASE_TAGS}" STREQUAL "")
		SET(_stage "TAGS")
	    ELSE(_arg STREQUAL "NOKOJI_SCRATCH_BUILD")
		IF(_stage STREQUAL "KARMA")
		    IF(_arg STREQUAL "0")
			SET(_FEDORA_AUTO_KARMA "False")
		    ENDIF(_arg STREQUAL "0")
		    SET(_FEDORA_KARMA ${_arg})
		ELSEIF(_stage STREQUAL "TAGS")
		    LIST(APPEND _FEDORA_DIST_TAGS "${_arg}")
		ELSE(_stage STREQUAL "TAGS")
		    SET(_FEDORA_SRPM ${_arg})
		ENDIF(_stage STREQUAL "KARMA")
	    ENDIF(_arg STREQUAL "NOKOJI_SCRATCH_BUILD")
	ENDFOREACH(_arg ${ARGN})
	IF(NOT "${FEDORA_RELEASE_TAGS}" STREQUAL "")
	    SET(_FEDORA_DIST_TAGS ${FEDORA_RELEASE_TAGS})
	ELSEIF(_FEDORA_DIST_TAGS STREQUAL "")
	    LIST(APPEND _FEDORA_DIST_TAGS ${FEDORA_CURRENT_RELEASE_TAGS})
	ENDIF(NOT "${FEDORA_RELEASE_TAGS}" STREQUAL "")

	SET(_FEDORA_STABLE_KARMA "${_FEDORA_KARMA}")
	SET(_FEDORA_UNSTABLE_KARMA "-${_FEDORA_KARMA}")

    ENDMACRO(_manange_release_on_fedora_parse_args)

    MACRO(USE_KOJI srpm)
	SET(_dependencies_missing 0)
	FIND_PROGRAM(KOJI_CMD koji)
	IF(KOJI_CMD STREQUAL "KOJI_CMD-NOTFOUND")
	    M_MSG(${M_OFF} "Program koji is not found! Koji support disabled.")
	    SET(_dependencies_missing 1)
	ENDIF(KOJI_CMD STREQUAL "KOJI_CMD-NOTFOUND")

	IF(_dependencies_missing EQUAL 0)
	    IF(_FEDORA_DIST_TAGS STREQUAL "")
		_manange_release_on_fedora_parse_args(${ARGN})
	    ENDIF(_FEDORA_DIST_TAGS STREQUAL "")

	    IF(_FEDORA_KOJI_SCRATCH EQUAL 1)
		ADD_CUSTOM_TARGET(koji_scratch_build
		    COMMENT "koji scratch builds"
		    )

		# Ensure package build in koji before tag
		ADD_DEPENDENCIES(tag koji_scratch_build)
	    ENDIF(_FEDORA_KOJI_SCRATCH EQUAL 1)

	    FOREACH(_tag ${_FEDORA_DIST_TAGS})
		_manange_release_on_fedora_dist_convert_to_koji_target(_branch ${_tag})
		IF(_FEDORA_KOJI_SCRATCH EQUAL 1)
		    SET(_scratch_build_stamp
			"${CMAKE_FEDORA_TMP_DIR}/${PRJ_VER}_koji_scratch_build_${_tag}")
		    ADD_CUSTOM_TARGET(koji_scratch_build_${_tag}
			DEPENDS ${_scratch_build_stamp}
			)

		    ADD_CUSTOM_COMMAND(OUTPUT ${_scratch_build_stamp}
			COMMAND ${KOJI_CMD} build --scratch ${_branch} ${srpm}
			COMMAND ${CMAKE_COMMAND} -E touch ${_scratch_build_stamp}
			DEPENDS ${CMAKE_FEDORA_TMP_DIR} ${srpm}
			COMMENT "koji scratch build on ${_branch} with ${srpm}"
			)
		    ADD_DEPENDENCIES(koji_scratch_build_${_tag} rpmlint)
		    ADD_DEPENDENCIES(koji_scratch_build koji_scratch_build_${_tag})
		ENDIF(_FEDORA_KOJI_SCRATCH EQUAL 1)
	    ENDFOREACH(_tag ${_FEDORA_DIST_TAGS})
	ENDIF(_dependencies_missing EQUAL 0)
    ENDMACRO(USE_KOJI srpm)

    MACRO(_use_fedpkg_make_targets srpm)
	#MESSAGE("_FEDORA_DIST_TAGS=${_FEDORA_DIST_TAGS}")
	#Commit summary
	IF (DEFINED CHANGE_SUMMARY)
	    SET (COMMIT_MSG  "-m \"${CHANGE_SUMMARY}\"")
	ELSE(DEFINED CHANGE_SUMMARY)
	    SET (COMMIT_MSG  "-m \"On releasing ${PRJ_VER}-${PRJ_RELEASE_NO}\"")
	ENDIF(DEFINED CHANGE_SUMMARY)

	SET(_fedpkg_tag_path_abs_prefix
	    "${FEDPKG_WORKDIR}/.git/refs/tags")
	FOREACH(_tag ${_FEDORA_DIST_TAGS})
	    IF(_tag STREQUAL FEDORA_RAWHIDE_TAG)
		SET(_branch "")
	    ELSEIF(_tag STREQUAL FEDORA_NEXT_RELEASE_TAG)
		SET(_branch "master")
	    ELSE(_tag STREQUAL FEDORA_RAWHIDE_TAG)
		SET(_branch "${_tag}")
	    ENDIF(_tag STREQUAL FEDORA_RAWHIDE_TAG)

	    IF(NOT _branch STREQUAL "")
		_use_bodhi_convert_tag(_bodhi_tag "${_tag}")
		SET(_fedpkg_tag_name_prefix "${PRJ_VER}-${PRJ_RELEASE_NO}.${_bodhi_tag}")
		#MESSAGE("_fedpkg_tag_name_prefix=${_fedpkg_tag_name_prefix}")
		SET(_scratch_build_stamp
		    "${CMAKE_FEDORA_TMP_DIR}/${PRJ_VER}_scratch_build_${_tag}")


		ADD_CUSTOM_TARGET(fedpkg_scratch_build_${_tag}
		    DEPENDS ${_scratch_build_stamp}
		    )

		ADD_CUSTOM_COMMAND(OUTPUT ${_scratch_build_stamp}
		    COMMAND ${FEDPKG_CMD} switch-branch ${_branch}
		    COMMAND ${FEDPKG_CMD} scratch-build --srpm ${srpm}
		    COMMAND ${CMAKE_COMMAND} -E touch ${_scratch_build_stamp}
	    	    DEPENDS ${CMAKE_FEDORA_TMP_DIR} ${srpm}
		    WORKING_DIRECTORY ${FEDPKG_WORKDIR}
		    COMMENT "fedpkg scratch build on ${_branch} with ${srpm}"
		    )
		ADD_DEPENDENCIES(fedpkg_scratch_build_${_tag} rpmlint)
		ADD_DEPENDENCIES(fedpkg_scratch_build fedpkg_scratch_build_${_tag})

		# koji_scratch_build is preferred before tag,
		# otherwise, use fedpkg_scratch_build instead
		IF(NOT TARGET koji_scratch_build)
		    ADD_DEPENDENCIES(tag fedpkg_scratch_build)
		ENDIF(NOT TARGET koji_scratch_build)

		## fedpkg import
		SET(_import_opt "")
		IF(NOT _tag STREQUAL FEDORA_RAWHIDE_TAG)
		    SET(_import_opt "-b ${_tag}")
		ENDIF(NOT _tag STREQUAL FEDORA_RAWHIDE_TAG)


		## fedpkg commit and push
		# Depends on tag file instead of target "tag"
		# To avoid excessive scratch build and rpmlint
		SET(_commit_opt --push --tag "${COMMIT_MSG}")
		SET(_fedpkg_tag_name_committed
		    "${_fedpkg_tag_name_prefix}.committed")
		ADD_CUSTOM_COMMAND(OUTPUT
		    ${_fedpkg_tag_path_abs_prefix}/${_fedpkg_tag_name_committed}
		    COMMAND ${FEDPKG_CMD} switch-branch ${_branch}
		    COMMAND ${FEDPKG_CMD} pull
		    COMMAND ${FEDPKG_CMD} import ${_import_opt} ${srpm}
		    COMMAND ${FEDPKG_CMD} commit ${_commit_opt}
		    COMMAND git push --tags
		    DEPENDS ${FEDPKG_WORKDIR} ${MANAGE_SOURCE_VERSION_CONTROL_TAG_FILE} ${srpm}
		    WORKING_DIRECTORY ${FEDPKG_WORKDIR}
		    COMMENT "fedpkg commit on ${_branch} with ${srpm}"
		    VERBATIM
		    )

		ADD_CUSTOM_TARGET(fedpkg_commit_${_tag}
		    DEPENDS ${_fedpkg_tag_path_abs_prefix}/${_fedpkg_tag_name_committed}
		    )
		ADD_DEPENDENCIES(fedpkg_commit fedpkg_commit_${_tag})

		## fedpkg build
		SET(_fedpkg_tag_name_built
		    "${_fedpkg_tag_name_prefix}.built")
		ADD_CUSTOM_COMMAND(OUTPUT
		    ${_fedpkg_tag_path_abs_prefix}/${_fedpkg_tag_name_built}
		    COMMAND ${FEDPKG_CMD} switch-branch ${_branch}
		    COMMAND ${FEDPKG_CMD} build
		    COMMAND git tag -a -m "${_fedpkg_tag_name_prefix} built"
		    ${_fedpkg_tag_name_built}
		    COMMAND git push --tags
		    WORKING_DIRECTORY ${FEDPKG_WORKDIR}
		    COMMENT "fedpkg build on ${_branch}"
		    VERBATIM
		    )

		ADD_CUSTOM_TARGET(fedpkg_build_${_tag}
		    DEPENDS ${_fedpkg_tag_path_abs_prefix}/${_fedpkg_tag_name_built}
		    )

		ADD_DEPENDENCIES(fedpkg_build_${_tag} fedpkg_commit_${_tag})
		ADD_DEPENDENCIES(fedpkg_build fedpkg_build_${_tag})

		ADD_CUSTOM_TARGET(fedpkg_update_${_tag}
		    COMMAND ${FEDPKG_CMD} update
		    WORKING_DIRECTORY ${FEDPKG_WORKDIR}/${PROJECT_NAME}
		    DEPENDS ${_first_tag_path}
		    COMMENT "fedpkg update on ${_branch} with ${srpm}"
		    )
		ADD_DEPENDENCIES(fedpkg_update_${_tag} fedpkg_build_${_tag})
		ADD_DEPENDENCIES(fedpkg_update fedpkg_update_${_tag})
	    ENDIF(NOT _branch STREQUAL "")
	ENDFOREACH(_tag ${_FEDORA_DIST_TAGS})
    ENDMACRO(_use_fedpkg_make_targets srpm)

    MACRO(USE_FEDPKG srpm)
	SET(_dependencies_missing 0)

	IF(NOT EXISTS $ENV{HOME}/.fedora-upload-ca.cert)
	    M_MSG(${M_OFF}
		"\$HOME/.fedora-upload-ca.cert not found, fedpkg support disabled")
	    SET(_dependencies_missing 1)
	ENDIF(NOT EXISTS $ENV{HOME}/.fedora-upload-ca.cert)

	FIND_PROGRAM(FEDPKG_CMD fedpkg)
	IF(FEDPKG_CMD STREQUAL "FEDPKG_CMD-NOTFOUND")
	    M_MSG(${M_OFF} "Program fedpkg is not found! fedpkg support disabled.")
	    SET(_dependencies_missing 1)
	ENDIF(FEDPKG_CMD STREQUAL "FEDPKG_CMD-NOTFOUND")

	IF(_dependencies_missing EQUAL 0)
	    IF(_FEDORA_DIST_TAGS STREQUAL "")
		_manange_release_on_fedora_parse_args(${ARGN})
	    ENDIF(_FEDORA_DIST_TAGS STREQUAL "")

	    SET(FEDPKG_DIR_ABS ${CMAKE_BINARY_DIR}/${FEDPKG_DIR})
	    SET(FEDPKG_WORKDIR ${FEDPKG_DIR_ABS}/${PROJECT_NAME})
	    ADD_CUSTOM_COMMAND(OUTPUT ${FEDPKG_DIR_ABS}
		COMMAND mkdir -p ${FEDPKG_DIR_ABS}
		)

	    ADD_CUSTOM_COMMAND(OUTPUT ${FEDPKG_WORKDIR}
		COMMAND ${FEDPKG_CMD} clone ${PROJECT_NAME}
		DEPENDS ${FEDPKG_DIR_ABS}
		WORKING_DIRECTORY ${FEDPKG_DIR_ABS}
		)

	    ADD_CUSTOM_TARGET(fedpkg_clone
		DEPENDS ${FEDPKG_WORKDIR}
		)

	    ADD_CUSTOM_TARGET(fedpkg_scratch_build
		COMMENT "fedpkg scratch build"
		)
	    ADD_CUSTOM_TARGET(fedpkg_import
		COMMENT "fedpkg import"
		)
	    ADD_CUSTOM_TARGET(fedpkg_commit
		COMMENT "fedpkg commit and push"
		)
	    ADD_CUSTOM_TARGET(fedpkg_build
		COMMENT "fedpkg build"
		)

	    ADD_CUSTOM_TARGET(fedpkg_update
		COMMENT "fedpkg update"
		)
	    ## Make target commands for the released dist
	    _use_fedpkg_make_targets("${srpm}")
	ENDIF(_dependencies_missing EQUAL 0)
    ENDMACRO(USE_FEDPKG srpm)

    MACRO(_use_bodhi_convert_tag tag_out tag_in)
	STRING(REGEX REPLACE "f([0-9]+)" "fc\\1" _tag_replace "${tag_in}")
	IF(_tag_replace STREQUAL "")
	    SET(${tag_out} ${tag_in})
	ELSE(_tag_replace STREQUAL "")
	    SET(${tag_out} ${_tag_replace})
	ENDIF(_tag_replace STREQUAL "")
    ENDMACRO(_use_bodhi_convert_tag tag_out tag_in)

    MACRO(_append_notes _file)
	STRING(REGEX REPLACE "\n" "\n " _notes "${CHANGELOG_ITEMS}")
	FILE(APPEND ${_file} "notes=${_notes}\n\n")
    ENDMACRO(_append_notes _file)

    MACRO(USE_BODHI)
	# Bodhi does not really require .fedora-upload-ca.cert
	# But since this macro is meant for package maintainers,
	# so..
	SET(_dependencies_missing 0)
	IF(NOT EXISTS $ENV{HOME}/.fedora-upload-ca.cert)
	    M_MSG(${M_OFF}
		"\$HOME/.fedora-upload-ca.cert not found, bodhi support disabled")
	    SET(_dependencies_missing 1)
	ENDIF(NOT EXISTS $ENV{HOME}/.fedora-upload-ca.cert)
	FIND_PROGRAM(BODHI_CMD bodhi)
	IF(BODHI_CMD STREQUAL "BODHI_CMD-NOTFOUND")
	    M_MSG(${M_OFF} "Program bodhi is not found! bodhi support disabled.")
	    SET(_dependencies_missing 1)
	ENDIF(BODHI_CMD STREQUAL "BODHI_CMD-NOTFOUND")

	IF(_dependencies_missing EQUAL 0)
	    IF(_FEDORA_STABLE_KARMA STREQUAL "")
		_manange_release_on_fedora_parse_args(${ARGN})
	    ENDIF(_FEDORA_STABLE_KARMA STREQUAL "")

	    FILE(REMOVE ${_bodhi_template_file})
	    FOREACH(_tag ${_FEDORA_DIST_TAGS})
		IF(NOT _tag STREQUAL ${FEDORA_RAWHIDE_TAG})
		    _use_bodhi_convert_tag(_bodhi_tag ${_tag})

		    FILE(APPEND ${_bodhi_template_file} "[${PROJECT_NAME}-${PRJ_VER}-${PRJ_RELEASE_NO}.${_bodhi_tag}]\n\n")

		    IF(BODHI_UPDATE_TYPE)
			FILE(APPEND ${_bodhi_template_file} "type=${BODHI_UPDATE_TYPE}\n\n")
		    ELSE(BODHI_UPDATE_TYPE)
			FILE(APPEND ${_bodhi_template_file} "type=bugfix\n\n")
		    ENDIF(BODHI_UPDATE_TYPE)

		    FILE(APPEND ${_bodhi_template_file} "request=testing\n")
		    FILE(APPEND ${_bodhi_template_file} "bugs=${REDHAT_BUGZILLA}\n")

		    _append_notes(${_bodhi_template_file})

		    FILE(APPEND ${_bodhi_template_file} "autokarma=${_FEDORA_AUTO_KARMA}\n")
		    FILE(APPEND ${_bodhi_template_file} "stable_karma=${_FEDORA_STABLE_KARMA}\n")
		    FILE(APPEND ${_bodhi_template_file} "unstable_karma=${_FEDORA_UNSTABLE_KARMA}\n")
		    FILE(APPEND ${_bodhi_template_file} "close_bugs=True\n")

		    IF(SUGGEST_REBOOT)
			FILE(APPEND ${_bodhi_template_file} "suggest_reboot=True\n")
		    ELSE(SUGGEST_REBOOT)
			FILE(APPEND ${_bodhi_template_file} "suggest_reboot=False\n\n")
		    ENDIF(SUGGEST_REBOOT)
		ENDIF(NOT _tag STREQUAL ${FEDORA_RAWHIDE_TAG})
	    ENDFOREACH(_tag ${_FEDORA_DIST_TAGS})

	    IF(BODHI_USER)
		SET(_bodhi_login "-u ${BODHI_USER}")
	    ENDIF(BODHI_USER)

	    ADD_CUSTOM_TARGET(bodhi_new
		COMMAND ${BODHI_CMD} --new ${_bodhi_login} --file ${_bodhi_template_file}
		COMMENT "Send new package to bodhi"
		VERBATIM
		)

	    IF(TARGET fedpkg_build)
		ADD_DEPENDENCIES(bodhi_new fedpkg_build)
	    ENDIF(TARGET fedpkg_build)
	ENDIF(_dependencies_missing EQUAL 0)
    ENDMACRO(USE_BODHI)

    MACRO(RELEASE_ON_FEDORA srpm)
	IF(TARGET release)
	    USE_KOJI(${srpm} ${ARGN})
	    USE_FEDPKG(${srpm} ${ARGN})
	    USE_BODHI(${ARGN})
	    ADD_CUSTOM_TARGET(release_on_fedora)
	    ADD_DEPENDENCIES(release release_on_fedora)
	    ADD_DEPENDENCIES(release_on_fedora bodhi_new)
	ELSE(TARGET release)
	    M_MSG(${M_OFF} "ManageReleaseOnFedora: maintainer file is invalid, disable release targets" )
	ENDIF(TARGET release)
    ENDMACRO(RELEASE_ON_FEDORA srpm)

ENDIF(NOT DEFINED _MANAGE_RELEASE_ON_FEDORA_)

