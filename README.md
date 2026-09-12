# ThatVRKidd Fangame

Version 0.2.0

Original Quest VR tag-game starter made with Godot and OpenXR.

## Current features

- Arm-powered locomotion prototype
- ThatVRKidd Client wrist menu
- Main and Settings pages
- Long Arms and adjustable arm multiplier
- Adjustable world scale
- Mosa-inspired movement preset
- Speed Boost, Fly, and Platforms
- Joystick walking, moon gravity, and grappling hook
- RGB hand trails and a built-in soundboard test tone
- Tag Gun targeting and Freeze Tag controls for authorized private game modes
- WebSocket room server, public-room connection controls, and remote head/hand syncing
- Right-hand menu pointer
- Original generated practice arena
- GitHub Actions Quest APK build

These abilities are intended for this original game and authorized private/sandbox rooms, not the official Gorilla Tag service.

## Test controls

- Right trigger: select menu button
- Right primary/A while Fly is enabled: fly where the controller points
- Either grip while Platforms is enabled: create a hand platform
- A/X while Grapple Hook is enabled: grapple toward the pointed surface
- Right grip aims Tag Gun; right trigger tags a valid private-room target

## Multiplayer setup

1. Deploy the `server` folder to any Node.js host that supports WebSockets.
2. Change `server_url` on `NetworkManager` in `Scenes/Main.tscn` to the host's secure `wss://` URL.
3. Build the APK and press **Network > Join Public Room** in the wrist menu.

The included room server only relays poses and validated game events. It does not connect to Gorilla Tag services.
