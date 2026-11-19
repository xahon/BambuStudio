# Home page

## Goal
Keep the home page free of online and promotional content unless the user opts in. By default the home page opens on Recently Opened.

## Problem
Upstream opens the home page on Library, and shows MakerWorld staff picks, the print history, MakerLab and the Maker's Supply store link by default. Library, MakerLab and Maker's Supply have no preference at all; only the minors-decision account restrictions can hide them.

## Comparison
| Aspect | master | fork |
| :- | :- | :- |
| Library (`home` menu) | Always shown unless the account is restricted; the home page opens on it | Opt-in `show_library`, off by default; the home page opens on Recently Opened (`src/libslic3r/AppConfig.cpp`, `src/slic3r/GUI/Preferences.cpp`, `src/slic3r/GUI/WebViewDialog.cpp`) |
| Staff picks (`staff_pick_switch`) | On by default | Off by default (`src/libslic3r/AppConfig.cpp`) |
| Print history (`show_print_history`) | On by default | Off by default (`src/libslic3r/AppConfig.cpp`) |
| MakerLab | Always shown unless the account is restricted | Opt-in `show_makerlab`, off by default (same files as Library) |
| Maker's Supply | Always shown unless the account is restricted | Opt-in `show_maker_supply`, off by default (same files as Library) |
| Preferences section | "Online Models" (staff picks, history), hidden without model mall | "Promotion", always visible: Library, staff picks, history, MakerLab, Maker's Supply (`src/slic3r/GUI/Preferences.cpp`) |

## Deviations
- Defaults apply only to keys missing from the config. Users who already have `BambuStudio.conf` keep their stored values until they use "reset to defaults" in Preferences.
- The left page shows Maker's Supply by default in `left.html` and hides it once the host answers `homepage_leftmenu_access_get`, so it can flash briefly while the page loads.
- Staff picks, the print history and the MakerLab list are shown inside Library, so on the home page they appear only when Library is on too. Staff picks and MakerLab also have their own left-menu tabs.

## Details
- `WebViewPanel::IsMenuAccessDisabled()` treats a `false` `show_library` / `show_makerlab` / `show_maker_supply` like an account restriction for the `home` / `makerlab` / `makersupply` menu. That reuses the whole restriction path: the left-menu entry is hidden (`SetLeftMenuShow`), the MakerLab list is neither fetched nor retried (`SendMakerlabList`, the retry timer), `homepage_access_restrict` hides `#MakerlabArea` in `home.js`, and an open tab that gets disabled falls back to the home tab.
- With Library disabled, `SwitchWebContent("home")` and `SwitchLeftMenu("home")` land on `recent`. The left page calls `GotoMenu('home')` on load, which reaches the host and is redirected the same way, so Recently Opened ends up selected.
- Toggling any of the three checkboxes calls `GUI_App::refresh_homepage_access_ui()` → `WebViewPanel::RefreshMenuAccess()`, which applies the change right away. Turning MakerLab back on fetches the list again.
- In the Promotion section, the staff-pick and history rows stay hidden when `has_model_mall()` is false, as upstream does; the title and the other rows are always visible.
- `tests/app_config/app_config_tests.cpp` (its own target, like `nozzle_inventory`, because the `libslic3r` suite does not build) checks the defaults.
- Run `app_config_tests.exe` with `build/<preset>/src/Release` on `PATH`: the OCCT and GMP DLLs are copied only next to the app, so the test exits with `0xC0000135` otherwise. The libslic3r tests link with `/FORCE:UNRESOLVED`, so the target links `bcrypt` explicitly for the Boost UUID generator that `AppConfig` uses.
