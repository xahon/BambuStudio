# Windows build

## Goal

Build on Windows with Visual Studio 2026, in Debug and Release, from an IDE or the command line, in one step. Nothing beyond Visual Studio (C++ workload), CMake and Git needs to be installed system-wide.

## Problem

Upstream's Windows build only works on a prepared machine. Its presets point to a deps folder on one developer's drive, and the build silently relies on tools that must be installed system-wide: `pkg-config`, a native Perl, and a VS Developer prompt that puts `msbuild`/`nmake` on PATH. The deps (about 30 libraries) must be built by hand in a separate step that takes hours. On top of that, OpenCV fails to configure with CMake 4 whenever any Python is on PATH.

## Comparison

| Aspect | master | fork |
| :- | :- | :- |
| Presets | `CMakePresets.json` hardcodes `D:/dep_win_new/usr/local`, mixes the VS 17 and VS 18 generators, and has no preset for the deps | Upstream `CMakePresets.json` is untouched. `CMakeUserPresets.json` adds `vs2026-debug` and `vs2026-release`, and `deps/CMakePresets.json` adds `vs2026` |
| Deps provisioning | Built by hand from `deps/` before configuring the app | The app's configure downloads a prebuilt archive for the current `deps/` tree, or builds `deps/` itself (`cmake/DepsPrefetch.cmake`). CI publishes the archives (`.github/workflows/fork_deps_windows.yml`, `cmake/DepsPackage.cmake`) |
| FFmpeg linking | `pkg_check_modules` (requires a system-wide `pkg-config`) | Under MSVC, `find_path`/`find_library` in `src/slic3r/CMakeLists.txt`, and `find_package(PkgConfig)` is skipped in `CMakeLists.txt` |
| OpenSSL | Built from source 3.1.2 with `perl Configure` + `nmake` (requires a native Perl; Git's MSYS Perl does not work) | Prebuilt static libraries from the NuGet `openssl-native` 3.5.9 package, SHA-256 pinned (`deps/OpenSSL/OpenSSL.cmake`) |
| Deps Debug install steps | Bare `msbuild` (requires a VS Developer prompt) | `cmake --build . --target install --config Debug -- /m` (`deps/deps-windows.cmake`, `deps/OpenVDB/OpenVDB.cmake`) |
| OpenCV Python detection | Fails with CMake 4 when any Python is on PATH (`find_package(Python3 "OFF")`) | Skipped with `-DOPENCV_PYTHON_SKIP_DETECTION=ON` (`deps/OpenCV/OpenCV.cmake`). The Python bindings are disabled anyway |
| Device page pnpm steps | The `pnpm install`/`pnpm run build` commands embed the whole configure-time PATH, so reconfiguring from another environment (a terminal, then an IDE) changes them and MSBuild reruns both | On CMake 3.25+, `cmake -E env --modify PATH=path_list_prepend:<node dir>` adds node at build time, so the commands stay the same. Older CMake keeps the upstream form (`src/slic3r/GUI/DeviceWeb/CMakeLists.txt`) |

## Deviations

- OpenSSL moves from 3.1.2 to 3.5.9 (LTS) on MSVC. Other platforms are unchanged.
- The prebuilt OpenSSL libraries are built with `/MT` and carry a `DEFAULTLIB:LIBCMT` directive, so `CMakeLists.txt` adds `/NODEFAULTLIB:LIBCMT` to `OpenSSL::Crypto`. The old source build produced `/MT /Zl` libraries (no directive), so the linked result is equivalent.
- The package headers are generated for x64. 32-bit targets stop with a FATAL_ERROR. ARM64 uses the package's `win-arm64` libraries with the same headers, which is untested.
- Only Visual Studio 2026 x64 has presets and prebuilt deps. VS 2022 is not targeted.
- Prebuilt deps are hosted as GitHub Releases of this fork. Another fork has to publish its own (the workflow does that once Actions are enabled) and set `BBL_DEPS_URL`, or its configure builds the deps locally.
- The presets need CMake 3.24+ for `CMAKE_PROJECT_TOP_LEVEL_INCLUDES`.

## Details

The build has two separate CMake projects:

1. **`deps/`** downloads and builds the third-party libraries (Boost, wxWidgets, OpenCV, CURL, ...) and installs them into `deps/build/vs2026/destdir/usr/local`.
   - Each library is an `ExternalProject` that downloads a pinned release or commit; fork-specific changes are `.patch` files next to its `deps/<Lib>/<Lib>.cmake`. CMake-based ones are added via `bambustudio_add_cmake_project` in `deps/CMakeLists.txt`.
   - `deps/deps-windows.cmake` maps `MSVC_VERSION` to the Visual Studio generator and Boost toolset: 1950-1969 maps to VS 18 / msvc-14.4, and anything newer is a FATAL_ERROR.
   - Every CMake-based library is built with that VS generator, Release first and then Debug (`add_debug_dep`, which uses the `d` postfix).
   - OpenSSL and FFmpeg come prebuilt and are release-only; both app configurations use them.
   - Patches are applied with `git apply`.
2. **The app** at the repository root finds the libraries through `CMAKE_PREFIX_PATH`, which the presets set.

```
cmake --preset vs2026-debug
cmake --build --preset vs2026-debug
```

Use `vs2026-release` the same way for Release builds. Each preset builds into `build/<preset>`.

### Deps provisioning

The presets set `CMAKE_PROJECT_TOP_LEVEL_INCLUDES` to `cmake/DepsPrefetch.cmake`, which runs on every configure before the app's first `project()` call:

- The key is the git tree hash of `deps/` (`git rev-parse HEAD:deps`), so it is the same on every clone of the same commit and ignores line endings.
- `deps/build/vs2026/deps-key.txt` records the key the installed deps were made for. When it matches, configure goes on immediately.
- Otherwise it downloads `deps-vs2026-x64.tar.zst` from the release `deps-<first 12 characters of the key>` under `BBL_DEPS_URL`, checks it against the `.sha256` asset, extracts it into `destdir`, and rewrites the build machine's install path in the files listed in the archive's `relocate.txt`.
- When there is no release for the key, or `deps/` has uncommitted changes (the key then gets a `-local-<hash>` suffix), it runs `cmake --preset vs2026` and `cmake --build --preset vs2026` in `deps/`, with the build log in the configure output.
- An interrupted download or build leaves `pending` in the stamp, so the next configure resumes it.
- A `destdir` without a stamp (deps built by hand) is used as is. Delete it to have it provided again. `-DBBL_DEPS_PREFETCH=OFF` turns the module off.

`.github/workflows/fork_deps_windows.yml` runs on pushes to `fork` that change `deps/`, and on demand. On `windows-2025-vs2026` it builds `deps/` with the same preset, packs it with `cmake/DepsPackage.cmake` (paxr + zstd, plus `relocate.txt`), and publishes the archive and its checksum as a prerelease. It skips the build when the release for the key already exists.

The deps can still be built by hand: from `deps/`, run `cmake --preset vs2026`, then `cmake --build --preset vs2026`.

Gotchas:
- Git Bash rewrites `/m` in `cmake --build ... -- /m` into `M:/`. Use `-m`, or set `MSYS_NO_PATHCONV=1`.
- Editing a CMake file during a VS build makes the next build regenerate the project. This is harmless.
