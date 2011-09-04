# - Cmake version detection.
# This module is mainly for provide an unified environment for CMake 2.4
# and up. You can use this module even you are normally with higher version
# such like 2.6.
#
IF(NOT DEFINED _CMAKE_VERSION_CMAKE_)
    SET(_CMAKE_VERSION_CMAKE_ "DEFINED")
    INCLUDE(ManageMessage)
    M_MSG(${M_INFO2} "CMAKE_MAJOR_VERSION=${CMAKE_MAJOR_VERSION}")
    M_MSG(${M_INFO2} "CMAKE_MINOR_VERSION=${CMAKE_MINOR_VERSION}")
    M_MSG(${M_INFO2} "CMAKE_PATCH_VERSION=${CMAKE_PATCH_VERSION}")

    IF(NOT CMAKE_VERSION)
	SET(CMAKE_VERSION "${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION}.${CMAKE_PATCH_VERSION}")
    ENDIF(NOT CMAKE_VERSION)
ENDIF(NOT DEFINED _CMAKE_VERSION_CMAKE_)

