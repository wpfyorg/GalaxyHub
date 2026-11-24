# Third-party notices

Buds Hub is licensed under the GNU General Public License v3 (see `LICENSE`).
It is an independent macOS client; it does not include or link the code of the
projects below.

## GalaxyBudsClient

Protocol research, message IDs, SPP framing details and per-model capability
specifications were derived from and cross-checked against:

- https://github.com/timschneeb/GalaxyBudsClient
- Copyright (C) Tim Schneeberger and contributors
- License: GNU General Public License v3

Live packet captures from a Galaxy Buds3 Pro and the command experiments in
`docs/REVERSE_ENGINEERING.md` were produced for this project. The protocol layer
is an independent Swift implementation.

## BudsControl

Interaction and visual patterns (battery ring, liquid segmented control, glass
fallbacks, HUD, shortcut recorder) are adapted from:

- https://github.com/amarsakore/BudsControl
- Copyright (c) 2026 amarsakore
- License: MIT

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Apple frameworks

IOBluetooth, SwiftUI, AppKit, Carbon and ServiceManagement are Apple system
frameworks used under the macOS SDK license. Buds Hub is not affiliated with,
endorsed by, or sponsored by Samsung Electronics.
