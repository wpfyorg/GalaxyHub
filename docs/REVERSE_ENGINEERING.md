# Reverse engineering notes

Everything below was validated against a live Galaxy Buds3 Pro
(`AA:BB:CC:DD:EE:FF`, firmware `R630XXU0AZG2`, SKU `SM-R630NZAAINU`) on macOS 27
unless marked otherwise.

## Discovery

IOBluetooth enumerates the paired buds and their SDP records. The control services
advertised by the Buds3 Pro are:

| Service name | RFCOMM channel | UUID |
|---|---|---|
| GEARMANAGER | 27 | `2e73a4ad-332d-41fc-90e2-16bef06523f2` |
| SPPSERVICE4 | 29 | `f8620674-a1ed-41ab-a8b9-de9ad655729d` (SMEP) |
| SAMSUNGDEVICE | 28 | vendor UUID |
| FACTORY | 20 | standard SPP `00001101-…` |
| BTIS | 21 | vendor UUID |

`GEARMANAGER` is the normal control channel. Opening RFCOMM on macOS often returns
`kIOReturnError` while the channel opens a moment later; poll `isOpen()` for about
six seconds (60 × 0.1 s), stopping early once data arrives, instead of treating the
status as fatal.

### Model detection

Samsung embeds the decimal product ID in the vendor SPP service UUID:

```
d908aab5-7a90-4cbe-8641-86a553db0154
                              ^^^^ product ID 0x0154 = 340 = Buds3 Pro
```

`DeviceCatalog.productID(fromServiceUUID:)` reads the last four bytes. This works
after the user renames the buds. Fallbacks, in order:

1. `DEBUG_SKU` reply (`SM-R630NZA…` → `R630`).
2. `VERSION_INFO_LONG` firmware string (`R630XXU0AZG2`).
3. Bluetooth name (`Buds3 Pro`, longest/most specific match first).
4. User override in Settings.

## Framing

Modern models (Buds+ and newer) use:

```
FD  <size lo> <size hi + flags>  <msg id>  <payload…>  <crc lo> <crc hi>  DD
```

* `size` occupies bits 0–9 and counts message ID + payload + CRC.
* bit 12 (`0x1000`) is set on every device-originated frame in our captures
  (status pushes and replies) and clear on host requests.
* bit 13 (`0x2000`) marks a fragment (firmware transfer only).
* bits 14–15 appear on some firmware pushes (`0x40`, `0x80`, `0xC0` high byte) and
  must be ignored when masking the size.
* CRC is CRC-16/XMODEM (poly `0x1021`, init `0x0000`) over message ID + payload,
  written little-endian.

Original Galaxy Buds (R170) use the legacy header:

```
FE  <type>  <size>  <id>  <payload…>  <crc lo> <crc hi>  EE
```

Requests from Samsung's own clients carry no direction bit; the buds accept that.
Message ID `0x42` is the universal acknowledgement: payload `[command id, value…]`.
The ACK is the authoritative response for settings that don't trigger a new status
push.

## Connection handshake

Opening GEARMANAGER is enough to make the buds push:

* `0x61` EXTENDED_STATUS_UPDATED
* `0x68` VERSION_INFO_LONG
* `0x8E` BUDS_LIGHTING_SYNC
* `0xC2` SPATIAL_AUDIO_DATA
* `0xCD` build string (`1307.1019RF2X80QJ8SE`)

The client then sends:

* `0x88` MANAGER_INFO `[01 01 22]`
* `0xA7` UPDATE_TIME `[8-byte ms timestamp][4-byte tz offset ms]`
* `0x22` DEBUG_SKU (model detection)
* `0x63` VERSION_INFO
* `0x76` MULTIPOINT_INFO
* `0x69` CUSTOM_EQUALIZE_RECV (models with custom EQ)

`0x88` is acknowledged with `0x42 [88 00]`. Do **not** request `0x60`
STATUS_UPDATED after this; on the tested firmware it closes the RFCOMM channel
after a few seconds.

## Buds3 Pro extended status layout

61-byte payload from message `0x61`. Offsets are zero-based and were verified by
changing one setting at a time, reconnecting, and diffing the pushed status.

| Offset | Field | Notes |
|---|---|---|
| 0 | revision | 4 on the tested firmware |
| 1 | ear type | |
| 2 | left battery % | |
| 3 | right battery % | |
| 4 | coupled | |
| 5 | main connection | 0 right, 1 left |
| 6 | placement | high nibble left, low nibble right (1 = in ear) |
| 7 | case battery % | |
| 8 | adjust sound sync | |
| 9 | equalizer mode | 0 off, 1–5 preset, 6/7 custom |
| 10 | touch enable bitfield | single/double/triple/hold/call/swipe/lock |
| 11 | touch-and-hold actions | high nibble left, low nibble right |
| 12 | noise mode | 0 off, 1 ANC, 2 ambient |
| 13 | voice wake-up | |
| 14–15 | left colour product ID | little-endian (340 = Buds3 Pro silver) |
| 16–17 | right colour product ID | |
| 18 | voice wake-up language | |
| 19 | seamless connection | 0 = enabled |
| 20 | find-my-gear revision | |
| 21 | noise-control cycle mask | ambient 1, adaptive 2, off 4, ANC 8 |
| 22 | speak seamlessly | |
| 23 | ambient volume | 0–2 |
| 24 | ANC level | 0 low, 1 high |
| 25 | hearing enhancement | |
| 26 | detect conversations | |
| 27 | detect-conversation timeout | 0 = 5 s, 1 = 10 s, 2 = 15 s |
| 28 | ANC with one earbud | |
| 29 | custom ambient enabled | |
| 30 | custom ambient volume | high nibble left, low nibble right |
| 31 | ambient tone | |
| 32 | double-tap side volume | |
| 33 | sidetone | |
| 34 | call path control | inverted |
| 35 | spatial audio | |
| 36–39 | custom conversation boost / neck / Bixby / hearing test prefix | not exposed |
| 40 | hearing test value / amplify | |
| 41 | head tracking | |
| 42 | charging status | bit 4 left, bit 2 right, bit 0 case |
| 43 | extra clear call | |
| 44 | extra-high ambient | |
| 45 | auto pause | |
| 46 | hot-command (voice wake-up) enabled | |
| 47 | hot-command language | |
| 48 | PEQ mode | |
| 49 | adaptive volume | |
| 50 | blade lighting style | |
| 51 | double-pinch-and-hold (quick launch) | |
| 52 | siren detect | |
| 53 | adapt sound | |
| 54–56 | hot-command version | major/minor/patch |

Buds3 generation tails start at offset 41 after the seven common bytes at 34–40.
Buds2 Pro and the FE family use the older fixed offsets up to 36; see
`StatusParser` for each model.

## Commands verified with acknowledgement

| ID | Command | Payload | Verified effect |
|---|---|---|---|
| `0x78` | NOISE_CONTROLS | `[mode]` | noise mode changed in next status |
| `0x83` | NOISE_REDUCTION_LEVEL | `[0/1]` | ANC level changed |
| `0x84` | AMBIENT_VOLUME | `[0–2]` | ambient volume changed |
| `0x86` | EQUALIZER | `[0=off, preset+1]` | EQ mode changed |
| `0x89` | CUSTOM_EQUALIZE_SEND | `[9][band × 9, signed]` | custom curve |
| `0x92` | SET_TOUCHPAD_OPTION | `[left, right]` | touch actions changed |
| `0xA0` / `0xA1` | FIND_MY_EARBUDS START/STOP | none | find sound started/stopped |
| `0x90` | LOCK_TOUCHPAD | lock/gesture bytes | touchpad lock |
| `0xD9` | ADAPTIVE_EQ_VOLUME_CONTROL | `[0/1]` | adaptive volume changed |
| `0xDE` | UASC_SIREN_DETECT | `[0/1]` | siren detect changed |
| `0x6C` | PAUSE_MEDIA_WHEN_ONE_BUD_REMOVED | `[0/1]` | auto pause changed |
| `0x22` | DEBUG_SKU | none | returns two 14-byte SKUs |

`CUSTOM_EQUALIZE_RECV` (`0x69`) returns
`[preset count=6][band count=9][5 × 9 preset table][9 custom bands]`. The first
preset is omitted from the wire table, so the custom bands start at
`2 + (presetCount-1) × bandCount`.

### Adaptive mode

The Buds3 Pro advertises adaptive bits in its touch cycle mask but rejected
`NOISE_CONTROLS [3]`: the ACK/next status kept the previous mode. Adaptive mode is
therefore gated to the Buds4 generation, where the profile declares it.

## Multi-device compatibility

`DeviceCatalog` stores per-model:

* frame style (legacy vs 16-bit header)
* service UUID (`SppNew`, standard SPP, legacy SPP)
* supported features
* maximum ambient volume
* equalizer/custom-EQ capability
* touch action raw-value map
* product ID set and SKU/firmware prefix

The parser and command builder take the model into account, so the same UI drives
the 2019 Buds and the Buds4 Pro without exposing invalid controls. Unknown models
fall back to a safe modern profile and prompt for an override.

## Known limits

* Firmware flashing/OTA is intentionally not implemented.
* Spatial-audio and head-tracking writes are exposed only where the profile says
  they exist; the exact two-byte payload needs per-generation verification.
* Buds4 blade-light and quick-launch writes are experimental.
* `0x60` STATUS_UPDATED is not requested because the tested firmware drops the
  link; the extended status push is used instead.
* Bluetooth permission must be approved once per signed build.
