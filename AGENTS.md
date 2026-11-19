# Agent instructions

This repository is a fork of [bambulab/BambuStudio](https://github.com/bambulab/BambuStudio).

## Branches

- `master` mirrors upstream only. Never commit fork work to it.
- All fork work goes to the `fork` branch. Base work branches on `fork`, and merge them into `fork` through pull requests, not locally.
- Land each feature as a single commit on top of `fork`: squash the work branch before merging, or squash-merge the pull request. Split a feature into several commits only when it is clearer that way.
- Keep diffs against upstream files minimal, so that merging upstream into `fork` stays easy. Don't trade away code quality, performance or architecture for it.
  - Prefer new files and narrow, self-contained edits.
  - Don't reindent or reorder upstream lines.
  - An isolated feature (mostly new files or code) is not limited in diff size, within reason.

## Commit messages

```
<Domain>: <Short imperative summary>

<Optional description: why the change was made>
```

- `<Domain>` comes from the fixed list in [agents/overview.md](agents/overview.md). Use `Generic` for generic tasks that don't belong to a single domain. To add a domain, add it to that list in the same commit that first uses it.
- Keep the subject line short (about 72 characters at most), in the imperative mood, with no trailing period. Example: `Build: Use prebuilt OpenSSL on MSVC`.
- The description is optional. When present, separate it from the subject with a blank line.

## Windows build (Visual Studio 2026)

The build needs only Visual Studio 2026 with the C++ workload, CMake 3.24+ and Git.

From the repository root, run `cmake --preset vs2026-release`, then `cmake --build --preset vs2026-release`. It is an optimized build that the Visual Studio debugger deoptimizes on demand (C++ Dynamic Debugging), so there is no Debug preset. Configure provides the deps by itself: it downloads the prebuilt archive for the current `deps/`, or builds `deps/` locally when there is none.

Details are in [agents/windows-build.md](agents/windows-build.md).

## Notes in `agents/`

`agents/` holds what earlier investigations found, so it doesn't have to be re-derived. Read the relevant note before investigating, and update it when you learn something new.

- Use one file per feature or domain, named for what it covers (for example `windows-build.md`). Add to an existing file before creating a new one. Group files in a subfolder per domain once a domain has several files. List each note next to its domain in [agents/overview.md](agents/overview.md).
- Write plain Markdown that any agent or person can read. No tool-specific metadata.
- Use American English spelling and wording, in this file and in all notes.
- These notes are public. Leave out machine-specific paths, usernames and other private details.
- Describe the current state only. Git keeps the history, so add no changelogs, dates or "Update:" sections; rewrite what changed instead.
- When merging upstream into `fork`, review every note whose Comparison names a file upstream touched. Update the rows that changed; delete the rows, or the whole note, for problems upstream has fixed.

### Note structure

Every note except `agents/overview.md` follows this structure. Use exactly these `##` headings, in this order, and no other `##` headings. Leave out an optional section entirely if it would be empty. Use `###` subsections only inside Details.

```markdown
# <Feature or domain>

## Goal
Optional. One or two sentences: what the fork wants to achieve here.

## Problem
What is wrong or missing in upstream (`master`), and why it matters.

## Comparison
| Aspect | master | fork |
| :- | :- | :- |
One row per aspect. In the fork column, name the files that implement the change.

## Deviations
Optional. Where the fork intentionally behaves differently or falls short beyond fixing the problem: trade-offs, version changes, unsupported or untested cases.

## Details
How it works: steps, commands, file pointers, gotchas.
```
