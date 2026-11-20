# AMS RFID

## Goal
Know where filament RFID tags are read and judged, so that any work on third-party spool tags targets the right layer.

## Problem
Upstream identifies a spool automatically only when it has a Bambu RFID tag. Spools with other vendors' tags show up as unidentified, and the user sets the type and color by hand. Studio cannot change this by itself: tags are read and judged in the AMS and printer firmware, and Studio receives only the decoded result.

## Comparison
| Aspect | master | fork |
| :- | :- | :- |
| Tag data in the status report | Per slot, decoded fields only: `tag_uid`, `tray_uuid`, `tray_info_idx`, `tray_type`, color, weight, diameter, temperatures, `remain`. No raw tag memory and no tag type | Same as master (`src/slic3r/GUI/DeviceCore/DevFilaSystem.cpp`, `DevFilaSystemParser::ParseAmsTrayInfo`) |
| Bambu or not, firmware side | Per AMS bit masks `tray_is_bbl_bits`, `tray_reading_bits`, `tray_read_done_bits` | Same as master (`src/slic3r/GUI/DeviceCore/DevFilaSystem.cpp`) |
| Bambu or not, Studio side | `DevFilaSystem::IsBBL_Filament()`: Bambu when `tag_uid` contains any non-`0` character | Same as master (`src/slic3r/GUI/DeviceCore/DevFilaSystem.cpp`) |
| Re-reading tags | `ams_get_slots_rfid` command; the reply is only `success` or `fail` | Same as master (`src/slic3r/GUI/DeviceCore/DevAmsRfidRefreshCtrl.cpp`) |

## Details
- The printer publishes its state over MQTT (`push_status`). The AMS part is under `print.ams`: the bit masks per AMS, and the slots in `print.ams.ams[].tray[]`. Studio parses it in `DevFilaSystemParser`. A missing `tag_uid` or `tray_uuid` defaults to `"0"`.
- Every field Studio receives is already decoded from the Bambu tag data layout, so the firmware has parsed the tag (or failed to) before Studio is involved. Studio has no path that sees or rejects a foreign tag.
- `IsBBL_Filament()` treats any non-zero `tag_uid` as Bambu. If the firmware passed on the real UID of a foreign tag, Studio would mislabel that spool as Bambu. Upstream relies on the firmware zeroing `tag_uid` for tags it could not verify.
- `AMSMaterialsSetting.cpp` takes `tag_uid` as the spool serial number when it is 16 characters long and characters 12–13 are `01`. `AMSMaterialsSetting` and the calibration pages switch to third-party filament handling when `IsBBL_Filament()` is false.
- Not verified in this codebase, from community reverse engineering: Bambu tags are MIFARE Classic 1K, with sector keys derived from the chip UID and signed data. The AMS cannot read tags that don't follow that scheme (for example NTAG215 OpenSpool tags, other vendors' MIFARE tags, blank cards), and reports the slot as unidentified.
- To see what the firmware sends, put the printer in LAN mode and subscribe to `device/<serial>/report` on the printer's MQTT server (port 8883, TLS, user `bblp`, the printer's access code as password). Load the spool and compare its slot in `print.ams.ams[].tray[]` with a Bambu spool: an all-zero `tag_uid` and a cleared `tray_is_bbl_bits` bit mean the firmware rejected the tag.
