# - Common macros targets for release chores.
# This module provides common targets for release or post-release chores.
#
#  Defines following macros:
#  MANAGE_RELEASE(maintainerSetting [UPLOAD [[[alias1 file1] alias2 file2] ...]])
#  - Manage release by setting release, after release targets and
#    files to be upload to hosting services and their alias.
#    Arguments:
#    + maintainerSetting: Maintainer setting file
#    + alias, file: file to be upload and its alias.
#      i.e. "make upload_<hostingService>_<alias>"
#      will upload the file to hostingService.
#    Defines following targets:
#    + release: Do the release chores.
#      Depends: upload, and any targets defined in RELEASE_TARGETS.
#      Reads or define following variables:
#      + RELEASE_TARGETS: Depended targets for release.
#        Note that the sequence of the target does not guarantee the
#        sequence of execution.
#    + changelog_update: Update changelog by copying ChangeLog to ChangeLog.prev
#      and RPM-ChangeLog to RPM-ChangeLog. This target should be execute before
#      starting a new version.
#    + after_release: Chores after release.
#      This depends on changelog_update, after_release_commit, and
#      after_release_push.
#

IF(NOT DEFINED _MANAGE_RELEASE_CMAKE_)
    SET(_MANAGE_RELEASE_CMAKE_ "DEFINED")
    INCLUDE(ManageMaintainerTargets)
    MACRO(MANAGE_RELEASE maintainerSetting)
	SET(_disabled 0)
	GET_TARGET_PROPERTY(_target_exists upload EXISTS)
	IF(NOT _target_exists EQUAL 1)
	    MAINTAINER_SETTING_READ_FILE(${maintainerSetting})
	    # What if maintainer file is invalid...
	    GET_TARGET_PROPERTY(_target_exists upload EXISTS)
	    IF(NOT _target_exists EQUAL 1)
		M_MSG(${M_OFF} "ManageRelease: maintainer file is invalid,
		    disable release targets" )
		MAINTAINER_SETTING_READ_FILE()
		SET(_disabled 1)
	    ENDIF(NOT _target_exists EQUAL 1)
	ENDIF(NOT _target_exists EQUAL 1)

	IF(_disabled EQUAL 0)
	    ## Target: release
	    ADD_CUSTOM_TARGET(release
		COMMENT "Release a new version"
		)
	    SET_TARGET_PROPERTIES(release PROPERTIES EXISTS 1)

	    ADD_DEPENDENCIES(release upload)

	    IF(RELEASE_TARGETS)
		ADD_DEPENDENCIES(release ${RELEASE_TARGETS})
	    ENDIF(RELEASE_TARGETS)

	    SET(_stage "NONE")
	    FOREACH(_arg ${ARGN})
		IF(_stage STREQUAL "NONE")
		    IF(_arg STREQUAL "UPLOAD")
			SET(_stage "NAME")
		    ENDIF(_arg STREQUAL "UPLOAD")
		ELSEIF(_stage STREQUAL "NAME")
		    SET(_name ${_arg})
		    SET(_stage "FILE")
		ELSE(_stage STREQUAL "NONE")
		    SET(_file ${_arg})
		    MANAGE_MAINTAINER_TARGETS_UPLOAD(${_file}
			FILE_ALIAS ${_name})
		    SET(_stage "NAME")
		ENDIF(_stage STREQUAL "NONE")
	    ENDFOREACH(_arg ${ARGN})

	    ## After release targets

	    ADD_CUSTOM_TARGET(changelog_update
		COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/ChangeLog ${CMAKE_SOURCE_DIR}/ChangeLog.prev
		COMMAND ${CMAKE_COMMAND} -E copy ${RPM_BUILD_SPECS}/RPM-ChangeLog ${RPM_BUILD_SPECS}/RPM-ChangeLog.prev
		DEPENDS ${CMAKE_SOURCE_DIR}/ChangeLog ${RPM_BUILD_SPECS}/RPM-ChangeLog
		COMMENT "Changelogs are updated for next version."
		)
	    ADD_CUSTOM_TARGET(after_release)
	    ADD_DEPENDENCIES(after_release after_release_push)
	    ADD_DEPENDENCIES(after_release_push after_release_commit)
	    ADD_DEPENDENCIES(after_release_commit changelog_update)
	ENDIF(_disabled EQUAL 0)


    ENDMACRO(MANAGE_RELEASE)



ENDIF(NOT DEFINED _MANAGE_RELEASE_CMAKE_)

