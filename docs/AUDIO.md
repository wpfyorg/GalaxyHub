# Audio quality and multipoint on macOS

## What the phone can do

Verified with `adb` on a Samsung SM-A156E (Android 16) paired to the same
Galaxy Buds3 Pro:

```
mCodecConfig: {codecName:SSC, mSampleRate:48000, mBitsPerSample:24,
               mChannelMode:STEREO}
mA2dpOffloadEnabled: false
selectable: SSC (priority 8001), AAC 44100/16, SBC 44100/16
LE UUIDs: BATTERY VolumeControl CoordinatedSet LE_AUDIO BASS
```

So a Samsung phone negotiates **Samsung Seamless Codec (SSC), 48 kHz, 24-bit,
stereo**. The buds also advertise **LE Audio** and **LC3** capabilities to LE
sources.

## What the Mac can do

macOS uses the standard A2DP codec set. There is no SSC encoder in macOS and no
public API for an app to add one. The realistic maximum on the Mac is **AAC-LC**
(at roughly 256 kbps, with SBC as fallback); the Buds3 Pro do not expose aptX or
LDAC. The Bluetooth HAL (`BTAudioHALPlugin`) and `bluetoothd` contain only
SBC/AAC/AAC-ELD and LC3 strings, no Samsung SSC.

LE Audio on macOS depends on the OS build and the Bluetooth controller. The Buds3
Pro advertise LE Audio/LC3 UUIDs, but this Mac negotiates classic A2DP, not LE
Audio, and there is no public API to request it. Buds Hub cannot force it.

A Mac app therefore cannot reproduce the 24-bit SSC quality of a Samsung phone.
Using the phone as the source, or accepting AAC on the Mac, are the two supported
paths. Never opening the buds' microphone keeps them on A2DP; opening the mic
switches them to HFP (mSBC/AAC-ELD) and lowers quality.

## Multipoint and automatic switching

The buds are the multipoint controller. Android logs show the phone's **A2DP
active device** becoming the buds when phone audio starts and becoming `null`
when the Mac has audio. No Samsung SPP command is involved; the firmware follows
A2DP/HFP activity. This is why the same behavior works with a OnePlus, a Mac and
any other standard Bluetooth source — the phone does not need a Samsung app.

Buds Hub adds the missing Mac-side action:

- **Audio focus → Use this Mac** (or `⌃⌥M`) selects the buds as the Mac's default
  output and holds a silent IO stream for 15 seconds. Setting the default alone
  does not open A2DP; the held stream does, and a real media app keeps it alive
  after the bridge releases. If no Mac audio starts, the bridge releases so the
  phone can take focus again.
- **Claim when Mac media plays** watches the system Now Playing state and performs
  the same claim when playback starts. Direct MediaRemote calls are blocked for
  third-party apps on macOS 15.4+, so this uses the Apple-signed `/usr/bin/osascript`
  `MRNowPlayingRequest` path; it needs no Accessibility or Automation permission.
  It polls only while the toggle is on.

Limitations:

- A phone call uses HFP and has priority. Buds Hub does not interrupt a call.
- If the buds are connected to the phone only, the Mac must first have a baseband
  connection to them; the app's auto-reconnect handles this when the buds are
  nearby.
- macOS may show the buds as an output device even when the phone currently has
  audio focus; selecting it and starting audio is what moves focus.
- The silent bridge uses a short-lived AVAudioEngine stream pinned to the buds.
  If CoreAudio tears the device down on a multipoint handoff, claim again.
- MediaRemote/osascript is private API; it fails gracefully. The manual button
  always works.
