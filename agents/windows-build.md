# Windows build

## Goal

Build on Windows with Visual Studio 2026, in Debug and Release, from an IDE or the command line. Nothing beyond Visual Studio (C++ workload), CMake and Git needs to be installed system-wide.

## Problem

Upstream's Windows build only works on a prepared machine. Its presets point to a deps folder on one developer's drive, and the build silently relies on tools that must be installed system-wide: `pkg-config`, a native Perl, and a VS Developer prompt that puts `msbuild`/`nmake` on PATH. On top of that, OpenCV fails to configure with CMake 4 whenever any Python is on PATH.

## Comparison

| Aspect | master | fork |
| :- | :- | :- |
| Presets | `CMakePresets.json` hardcodes `D:/dep_win_new/usr/local`, mixes the VS 17 and VS 18 generators, and has no preset for the deps | Upstream `CMakePresets.json` is untouched. `CMakeUserPresets.json` adds `vs2026-debug` and `vs2026-release`, and `deps/CMakePresets.json` adds `vs2026` |
| FFmpeg linking | `pkg_check_modules` (requires a system-wide `pkg-config`) | Under MSVC, `find_path`/`find_library` in `src/slic3r/CMakeLists.txt`, and `find_package(PkgConfig)` is skipped in `CMakeLists.txt` |
| OpenSSL | Built from source 3.1.2 with `perl Configure` + `nmake` (requires a native Perl; Git's MSYS Perl does not work) | Prebuilt static libraries from the NuGet `openssl-native` 3.5.9 package, SHA-256 pinned (`deps/OpenSSL/OpenSSL.cmake`) |
| Deps Debug install steps | Bare `msbuild` (requires a VS Developer prompt) | `cmake --build . --target install --config Debug -- /m` (`deps/deps-windows.cmake`, `deps/OpenVDB/OpenVDB.cmake`) |
| OpenCV Python detection | Fails with CMake 4 when any Python is on PATH (`find_package(Python3 "OFF")`) | Skipped with `-DOPENCV_PYTHON_SKIP_DETECTION=ON` (`deps/OpenCV/OpenCV.cmake`). The Python bindings are disabled anyway |

## Deviations

- OpenSSL moves from 3.1.2 to 3.5.9 (LTS) on MSVC. Other platforms are unchanged.
- The prebuilt OpenSSL libraries are built with `/MT` and carry a `DEFAULTLIB:LIBCMT` directive, so `CMakeLists.txt` adds `/NODEFAULTLIB:LIBCMT` to `OpenSSL::Crypto`. The old source build produced `/MT /Zl` libraries (no directive), so the linked result is equivalent.
- The package headers are generated for x64. 32-bit targets stop with a FATAL_ERROR. ARM64 uses the package's `win-arm64` libraries with the same headers, which is untested.
- Only Visual Studio 2026 has presets. VS 2022 is not targeted.

## Details

The build has two separate CMake projects:

1. **`deps/`** downloads and builds the third-party libraries (Boost, wxWidgets, OpenCV, CURL, ...) and installs them into `deps/build/vs2026/destdir/usr/local`.
   - Each library is an `ExternalProject`. CMake-based ones are added via `bambustudio_add_cmake_project` in `deps/CMakeLists.txt`.
   - `deps/deps-windows.cmake` maps `MSVC_VERSION` to the Visual Studio generator and Boost toolset: 1950-1969 maps to VS 18 / msvc-14.4, and anything newer is a FATAL_ERROR.
   - Every CMake-based library is built with that VS generator, Release first and then Debug (`add_debug_dep`, which uses the `d` postfix).
   - OpenSSL and FFmpeg come prebuilt and are release-only; both app configurations use them.
   - Patches are applied with `git apply`.
2. **The app** at the repository root finds the libraries through `CMAKE_PREFIX_PATH`, which the presets set.

```
cd deps
cmake --preset vs2026
cmake --build --preset vs2026
cd ..
cmake --preset vs2026-debug
cmake --build --preset vs2026-debug
```

Use `vs2026-release` the same way for Release builds. Each preset builds into `build/<preset>`.

Gotchas:
- Git Bash rewrites `/m` in `cmake --build ... -- /m` into `M:/`. Use `-m`, or set `MSYS_NO_PATHCONV=1`.
- Editing a CMake file during a VS build makes the next build regenerate the project. This is harmless.
