# - RPM generation, maintaining (remove old rpm) and verification (rpmlint).
# This module provides macros that provides various rpm building and
# verification targets.
#
# Includes:
#   ManageMessage
#   ManageVariable
#   PackSource
#
# Reads following variables:
#   RPM_DIST_TAG: (optional) Current distribution tag such as el5, fc10.
#     Default: Distribution tag from rpm --showrc
#
#   RPM_BUILD_TOPDIR: (optional) Directory of  the rpm topdir.
#     Default: ${CMAKE_BINARY_DIR}
#
#   RPM_BUILD_SPECS: (optional) Directory of generated spec files
#     and RPM-ChangeLog.
#     Note this variable is not for locating
#     SPEC template (project.spec.in), RPM-ChangeLog source files.
#     These are located through the path of spec_in.
#     Default: ${RPM_BUILD_TOPDIR}/SPECS
#
#   RPM_BUILD_SOURCES: (optional) Directory of source (tar.gz or zip) files.
#     Default: ${RPM_BUILD_TOPDIR}/SOURCES
#
#   RPM_BUILD_SRPMS: (optional) Directory of source rpm files.
#     Default: ${RPM_BUILD_TOPDIR}/SRPMS
#
#   RPM_BUILD_RPMS: (optional) Directory of generated rpm files.
#     Default: ${RPM_BUILD_TOPDIR}/RPMS
#
#   RPM_BUILD_BUILD: (optional) Directory for RPM build.
#     Default: ${RPM_BUILD_TOPDIR}/BUILD
#
#   RPM_BUILD_BUILDROOT: (optional) Directory for RPM build.
#     Default: ${RPM_BUILD_TOPDIR}/BUILDROOT
#
# Defines following variables after include:
#   RPM_IGNORE_FILES: A list of exclude file patterns for PackSource.
#     This value is appended to PACK_SOURCE_IGNORE_FILES after including
#     this module.
#
# Defines following Macros:
#   PACK_RPM(var spec_in sourcePackage [fileDependencies] )
#   - Generate spec and pack rpm  according to the spec file.
#     It needs variable from PackSource, so call P before cno need to call it manually,
#     note that environment variables for PackSource should be defined
#     before calling this macro.
#     Arguments:
#     + var: The filename of srpm is outputted to this var.
#            Path is excluded.
#     + spec_in: RPM spec file template.
#     + sourcePackage: Source package/tarball without path.
#       The sourcePackage should be in RPM_BUILD_SOURCES.
#     + fileDependencies: other files that rpm targets depends on.
#     Targets:
#     + srpm: Build srpm (rpmbuild -bs).
#     + rpm: Build rpm and srpm (rpmbuild -bb)
#     + rpmlint: Run rpmlint to generated rpms.
#     + clean_rpm": Clean all rpm and build files.
#     + clean_pkg": Clean all source packages, rpm and build files.
#     + clean_old_rpm: Remove old rpm and build files.
#     + clean_old_pkg: Remove old source packages and rpms.
#     This macro defines following variables:
#     + PRJ_RELEASE: Project release with distribution tags. (e.g. 1.fc13)
#     + PRJ_RELEASE_NO: Project release number, without distribution tags. (e.g. 1)
#     + PRJ_SRPM_PATH: Filename of generated SRPM file, including relative path.
#
#   USE_MOCK(spec_in)
#   - Add mock related targets.
#     Arguments:
#     + spec_in: RPM spec input template.
#     Targets:
#     + rpm_mock_i386: Make i386 rpm
#     + rpm_mock_x86_64: Make x86_64 rpm
#     This macor reads following variables?:
#     + MOCK_RPM_DIST_TAG: Prefix of mock configure file, such as "fedora-11", "fedora-rawhide", "epel-5".
#         Default: Convert from RPM_DIST_TAG
#

IF(NOT DEFINED _PACK_RPM_CMAKE_)
    SET (_PACK_RPM_CMAKE_ "DEFINED")

    INCLUDE(ManageMessage)
    INCLUDE(ManageVariable)
    INCLUDE(PackSource)
    SET (SPEC_FILE_WARNING "This file is generated, please modified the .spec.in file instead!")

    IF(NOT DEFINED RPM_DIST_TAG)
	EXECUTE_PROCESS(COMMAND rpm --showrc
	    COMMAND grep -E "dist[[:space:]]*\\."
	    COMMAND sed -e "s/^.*dist\\s*\\.//"
	    COMMAND tr \\n \\t
	    COMMAND sed  -e s/\\t//
	    OUTPUT_VARIABLE RPM_DIST_TAG)
    ENDIF(NOT DEFINED RPM_DIST_TAG)

    IF(NOT DEFINED RPM_BUILD_TOPDIR)
	SET(RPM_BUILD_TOPDIR ${CMAKE_BINARY_DIR})
    ENDIF(NOT DEFINED RPM_BUILD_TOPDIR)

    IF(NOT DEFINED RPM_BUILD_SPECS)
	SET(RPM_BUILD_SPECS "${RPM_BUILD_TOPDIR}/SPECS")
    ENDIF(NOT DEFINED RPM_BUILD_SPECS)

    IF(NOT DEFINED RPM_BUILD_SOURCES)
	SET(RPM_BUILD_SOURCES "${RPM_BUILD_TOPDIR}/SOURCES")
    ENDIF(NOT DEFINED RPM_BUILD_SOURCES)

    IF(NOT DEFINED RPM_BUILD_SRPMS)
	SET(RPM_BUILD_SRPMS "${RPM_BUILD_TOPDIR}/SRPMS")
    ENDIF(NOT DEFINED RPM_BUILD_SRPMS)

    IF(NOT DEFINED RPM_BUILD_RPMS)
	SET(RPM_BUILD_RPMS "${RPM_BUILD_TOPDIR}/RPMS")
    ENDIF(NOT DEFINED RPM_BUILD_RPMS)

    IF(NOT DEFINED RPM_BUILD_BUILD)
	SET(RPM_BUILD_BUILD "${RPM_BUILD_TOPDIR}/BUILD")
    ENDIF(NOT DEFINED RPM_BUILD_BUILD)

    IF(NOT DEFINED RPM_BUILD_BUILDROOT)
	SET(RPM_BUILD_BUILDROOT "${RPM_BUILD_TOPDIR}/BUILDROOT")
    ENDIF(NOT DEFINED RPM_BUILD_BUILDROOT)

    # Add RPM build directories in ignore file list.
    GET_FILENAME_COMPONENT(_rpm_build_sources_basename ${RPM_BUILD_SOURCES} NAME)
    GET_FILENAME_COMPONENT(_rpm_build_srpms_basename ${RPM_BUILD_SRPMS} NAME)
    GET_FILENAME_COMPONENT(_rpm_build_rpms_basename ${RPM_BUILD_RPMS} NAME)
    GET_FILENAME_COMPONENT(_rpm_build_build_basename ${RPM_BUILD_BUILD} NAME)
    GET_FILENAME_COMPONENT(_rpm_build_buildroot_basename ${RPM_BUILD_BUILDROOT} NAME)
    SET(RPM_IGNORE_FILES
	"/${_rpm_build_sources_basename}/" "/${_rpm_build_srpms_basename}/" "/${_rpm_build_rpms_basename}/"
	"/${_rpm_build_build_basename}/" "/${_rpm_build_buildroot_basename}/" "debug.*s.list")

    SET(PACK_SOURCE_IGNORE_FILES ${PACK_SOURCE_IGNORE_FILES}
	${RPM_IGNORE_FILES})

    MACRO(PACK_RPM_GET_ARCH var spec_in)
	SETTING_FILE_GET_VARIABLE(_archStr BuildArch ${spec_in} ":")
	IF(NOT _archStr STREQUAL "noarch")
	    SET(_archStr ${CMAKE_HOST_SYSTEM_PROCESSOR})
	ENDIF(NOT _archStr STREQUAL "noarch")
	SET(${var} ${_archStr})
    ENDMACRO(PACK_RPM_GET_ARCH var spec_in)


    MACRO(PACK_RPM var spec_in sourcePackage)
	IF(NOT EXISTS ${spec_in})
	    M_MSG(${M_FATAL} "File ${spec_in} not found!")
	ENDIF(NOT EXISTS ${spec_in})

	FIND_PROGRAM(RPMBUILD NAMES "rpmbuild")
	IF(${RPMBUILD} STREQUAL "RPMBUILD-NOTFOUND")
	    M_MSG(${M_OFF} "rpmbuild is not found in PATH, rpm build support is disabled.")
	ELSE(${RPMBUILD} STREQUAL "RPMBUILD-NOTFOUND")
	    GET_FILENAME_COMPONENT(_specInDir "${spec_in}" PATH)
	    # Get release number from spec_in
	    SET(fileDependencies ${ARGN})
	    SETTING_FILE_GET_VARIABLE(_releaseStr Release ${spec_in} ":")
	    STRING(REPLACE "%{?dist}" ".${RPM_DIST_TAG}" PRJ_RELEASE ${_releaseStr})
	    STRING(REPLACE "%{?dist}" "" PRJ_RELEASE_NO ${_releaseStr})
	    #MESSAGE("_releaseTag=${_releaseTag} _releaseStr=${_releaseStr}")

	    # Update RPM_ChangeLog
	    # Use this instead of FILE(READ is to avoid error when reading '\'
	    # character.
	    EXECUTE_PROCESS(COMMAND cat "${_specInDir}/RPM-ChangeLog.prev"
		OUTPUT_VARIABLE RPM_CHANGELOG_PREV
		OUTPUT_STRIP_TRAILING_WHITESPACE)

	    CONFIGURE_FILE(${_specInDir}/RPM-ChangeLog.in ${RPM_BUILD_SPECS}/RPM-ChangeLog)

	    # Generate spec
	    CONFIGURE_FILE(${spec_in} ${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec)

	    SET(${var} "${PROJECT_NAME}-${PRJ_VER}-${PRJ_RELEASE}.src.rpm")
	    SET(_prj_srpm_path "${RPM_BUILD_SRPMS}/${${var}}")
	    PACK_RPM_GET_ARCH(_archStr "${spec_in}")
	    SET(_prj_rpm_path "${RPM_BUILD_RPMS}/${_archStr}/${PROJECT_NAME}-${PRJ_VER}-${PRJ_RELEASE}.${_archStr}.rpm")

	    #-------------------------------------------------------------------
	    # RPM build commands and targets

	    ADD_CUSTOM_COMMAND(OUTPUT ${RPM_BUILD_BUILD}
		COMMAND ${CMAKE_COMMAND} -E make_directory ${RPM_BUILD_BUILD}
		)

	    # Don't worry about SRPMS, RPMS and BUILDROOT, it will be created by rpmbuild
	    ADD_CUSTOM_COMMAND(OUTPUT ${_prj_srpm_path} ${RPM_BUILD_SRPMS} ${RPM_BUILD_RPMS}
		COMMAND ${RPMBUILD}-md5 -bs ${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec
		--define '_sourcedir ${RPM_BUILD_SOURCES}'
		--define '_builddir ${RPM_BUILD_BUILD}'
		--define '_srcrpmdir ${RPM_BUILD_SRPMS}'
		--define '_rpmdir ${RPM_BUILD_RPMS}'
		--define '_specdir ${RPM_BUILD_SPECS}'
		DEPENDS ${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec
		${RPM_BUILD_SOURCES}/${sourcePackage} ${fileDependencies}
		COMMENT "Building srpm"
		)

	    ADD_CUSTOM_TARGET(srpm
		DEPENDS ${_prj_srpm_path}
		)

	    ADD_DEPENDENCIES(srpm pack_src)
	    # RPMs (except SRPM)

	    ADD_CUSTOM_COMMAND(OUTPUT ${_prj_rpm_path} ${RPM_BUILD_BUILD} ${RPM_BUILD_BUILDROOT}
		COMMAND ${RPMBUILD} -bb  ${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec
		--define '_sourcedir ${RPM_BUILD_SOURCES}'
		--define '_builddir ${RPM_BUILD_BUILD}'
		--define '_buildrootdir ${RPM_BUILD_BUILDROOT}'
		--define '_srcrpmdir ${RPM_BUILD_SRPMS}'
		--define '_rpmdir ${RPM_BUILD_RPMS}'
		--define '_specdir ${RPM_BUILD_SPECS}'
		DEPENDS ${_prj_srpm_path} ${RPM_BUILD_RPMS}
		COMMENT "Building rpm"
		)

	    ADD_CUSTOM_TARGET(rpm
		DEPENDS ${_prj_rpm_path}
		)

	    ADD_DEPENDENCIES(rpm srpm)

	    ADD_CUSTOM_TARGET(install_rpms
		find ${RPM_BUILD_RPMS}/${_archStr}
		-name '${PROJECT_NAME}*-${PRJ_VER}-${PRJ_RELEASE_NO}.*.${_archStr}.rpm' !
		-name '${PROJECT_NAME}-debuginfo-${PRJ_RELEASE_NO}.*.${_archStr}.rpm'
		-print -exec sudo rpm --upgrade --hash --verbose '{}' '\\;'
		COMMENT "Install all rpms except debuginfo"
		)

	    ADD_DEPENDENCIES(install_rpms rpm)

	    ADD_CUSTOM_TARGET(rpmlint find .
		-name '${PROJECT_NAME}*-${PRJ_VER}-${PRJ_RELEASE_NO}.*.rpm'
		-print -exec rpmlint '{}' '\\;'
		DEPENDS ${_prj_srpm_path} ${_prj_rpm_path}
		)

	    ADD_DEPENDENCIES(rpmlint version_check)

	    ADD_CUSTOM_TARGET(clean_old_rpm
		COMMAND find .
		-name '${PROJECT_NAME}*.rpm' ! -name '${PROJECT_NAME}*-${PRJ_VER}-${PRJ_RELEASE_NO}.*.rpm'
		-print -delete
		COMMAND find ${RPM_BUILD_BUILD}
		-path '${PROJECT_NAME}*' ! -path '${RPM_BUILD_BUILD}/${PROJECT_NAME}-${PRJ_VER}-*'
		-print -delete
		COMMENT "Cleaning old rpms and build."
		)

	    ADD_CUSTOM_TARGET(clean_old_pkg
		)

	    ADD_DEPENDENCIES(clean_old_pkg clean_old_rpm clean_old_pack_src)

	    ADD_CUSTOM_TARGET(clean_rpm
		COMMAND find . -name '${PROJECT_NAME}*.rpm' -print -delete
		COMMENT "Cleaning rpms.."
		)
	    ADD_CUSTOM_TARGET(clean_pkg
		)

	    ADD_DEPENDENCIES(clean_rpm clean_old_rpm)
	    ADD_DEPENDENCIES(clean_pkg clean_rpm clean_pack_src)

	ENDIF(${RPMBUILD} STREQUAL "RPMBUILD-NOTFOUND")
    ENDMACRO(PACK_RPM var spec_in sourcePackage)

    MACRO(USE_MOCK spec_in)
	FIND_PROGRAM(MOCK mock)
	IF(MOCK STREQUAL "MOCK-NOTFOUND")
	    M_MSG(${M_WARN} "mock is not found in PATH, mock support disabled.")
	ELSE(MOCK STREQUAL "MOCK-NOTFOUND")
	    PACK_RPM_GET_ARCH(_archStr ${spec_in})
	    IF(NOT _archStr STREQUAL "noarch")
		IF(NOT DEFINED MOCK_RPM_DIST_TAG)
		    STRING(REGEX MATCH "^fc([1-9][0-9]*)"  _fedora_mock_dist "${RPM_DIST_TAG}")
		    STRING(REGEX MATCH "^el([1-9][0-9]*)"  _el_mock_dist "${RPM_DIST_TAG}")

		    IF (_fedora_mock_dist)
			STRING(REGEX REPLACE "^fc([1-9][0-9]*)" "fedora-\\1" MOCK_RPM_DIST_TAG "${RPM_DIST_TAG}")
		    ELSEIF (_el_mock_dist)
			STRING(REGEX REPLACE "^el([1-9][0-9]*)" "epel-\\1" MOCK_RPM_DIST_TAG "${RPM_DIST_TAG}")
		    ELSE (_fedora_mock_dist)
			SET(MOCK_RPM_DIST_TAG "fedora-devel")
		    ENDIF(_fedora_mock_dist)
		ENDIF(NOT DEFINED MOCK_RPM_DIST_TAG)

		#MESSAGE ("MOCK_RPM_DIST_TAG=${MOCK_RPM_DIST_TAG}")
		SET(_prj_srpm_path "${RPM_BUILD_SRPMS}/${PROJECT_NAME}-${PRJ_VER}-${PRJ_RELEASE}.src.rpm")
		ADD_CUSTOM_TARGET(rpm_mock_i386
		    COMMAND ${CMAKE_COMMAND} -E make_directory ${RPM_BUILD_RPMS}/i386
		    COMMAND ${MOCK} -r  "${MOCK_RPM_DIST_TAG}-i386" --resultdir="${RPM_BUILD_RPMS}/i386" ${_prj_srpm_path}
		    DEPENDS ${_prj_srpm_path}
		    )

		ADD_CUSTOM_TARGET(rpm_mock_x86_64
		    COMMAND ${CMAKE_COMMAND} -E make_directory ${RPM_BUILD_RPMS}/x86_64
		    COMMAND ${MOCK} -r  "${MOCK_RPM_DIST_TAG}-x86_64" --resultdir="${RPM_BUILD_RPMS}/x86_64" ${_prj_srpm_path}
		    DEPENDS ${_prj_srpm_path}
		    )
	    ENDIF(NOT _archStr STREQUAL "noarch")
	ENDIF(MOCK STREQUAL "MOCK-NOTFOUND")

    ENDMACRO(USE_MOCK)

ENDIF(NOT DEFINED _PACK_RPM_CMAKE_)

