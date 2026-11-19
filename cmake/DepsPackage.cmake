# Packs the installed deps into a relocatable archive for cmake/DepsPrefetch.cmake.
# Usage: cmake -DDEPS_DIR=<deps binary dir> -DOUTPUT=<archive.tar.zst> -P cmake/DepsPackage.cmake
# Writes <archive> and <archive>.sha256.

cmake_minimum_required(VERSION 4.3)

if (NOT DEPS_DIR OR NOT OUTPUT)
    message(FATAL_ERROR "Usage: cmake -DDEPS_DIR=<deps binary dir> -DOUTPUT=<archive.tar.zst> -P DepsPackage.cmake")
endif ()
get_filename_component(_destdir "${DEPS_DIR}/destdir" ABSOLUTE)
get_filename_component(_output "${OUTPUT}" ABSOLUTE)
if (NOT IS_DIRECTORY "${_destdir}/usr/local")
    message(FATAL_ERROR "No installed deps in ${_destdir}/usr/local")
endif ()

# Installed config files (CMake packages, pkg-config files, curl-config, wxWidgets' setup.h) embed the absolute install path.
# List them in relocate.txt so that DepsPrefetch.cmake can rewrite the path after extracting.
file(TO_CMAKE_PATH "${_destdir}" _prefix)
file(TO_NATIVE_PATH "${_destdir}" _prefix_native)
file(GLOB_RECURSE _files RELATIVE "${_destdir}" LIST_DIRECTORIES false "${_destdir}/usr/local/*")
set(_relocate "${_prefix}\n")
foreach (_file IN LISTS _files)
    get_filename_component(_ext "${_file}" LAST_EXT)
    string(TOLOWER "${_ext}" _ext)
    if (NOT _ext MATCHES "^\\.(cmake|pc|txt|json|prl)$" AND NOT (_ext STREQUAL "" AND _file MATCHES "^usr/local/bin/") AND NOT _file MATCHES "/setup\\.h$")
        continue()
    endif ()
    file(READ "${_destdir}/${_file}" _content)
    string(FIND "${_content}" "${_prefix}" _pos)
    string(FIND "${_content}" "${_prefix_native}" _pos_native)
    if (_pos GREATER -1 OR _pos_native GREATER -1)
        string(APPEND _relocate "${_file}\n")
    endif ()
endforeach ()
file(WRITE "${_destdir}/relocate.txt" "${_relocate}")

file(REMOVE "${_output}" "${_output}.sha256")
file(ARCHIVE_CREATE OUTPUT "${_output}" PATHS usr relocate.txt FORMAT paxr COMPRESSION Zstd COMPRESSION_LEVEL 9 THREADS 0 WORKING_DIRECTORY "${_destdir}")
file(REMOVE "${_destdir}/relocate.txt")

file(SHA256 "${_output}" _hash)
get_filename_component(_name "${_output}" NAME)
file(WRITE "${_output}.sha256" "${_hash}  ${_name}\n")
file(SIZE "${_output}" _size)
math(EXPR _size_mb "${_size} / 1048576")
message(STATUS "Packed ${_destdir} into ${_output} (${_size_mb} MB)")
