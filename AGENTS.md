# Updraft
Native SwiftUI iOS app (crypto, high-end financial feel: clean, minimal, luxury, Liquid Glass). Built on Windows/WSL with xtool, no Xcode.

- Code: `Sources/Updraft/`. Colors, fonts, glass helper: `Theme/Theme.swift` (always use `Theme`, never raw colors).
- Tabs: Home, Markets, Wallet, Profile (placeholders in `RootView.swift`).
- Pure Swift/SwiftPM only; no Xcode project, no CocoaPods.
- Build to phone (iTunes open, iPhone plugged in):
  `. ~/.local/share/swiftly/env.sh; export USBMUXD_SOCKET_ADDRESS="$(ip route list default | awk '{print $3}'):27015"; xtool dev`
