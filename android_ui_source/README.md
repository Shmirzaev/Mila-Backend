<img src="./.github/assets/app-icon.png" alt="Voice Assistant App Icon" width="100" height="100">

# MILA Android Project

This project is a MILA-flavored Android frontend built from LiveKit's current Android starter app. It connects to your running `mila-agent` through a bundled local token server that follows LiveKit's endpoint token format.

## What is included

- Native Android app built with Jetpack Compose and LiveKit Android components
- Local token server in `token-server/` for development
- MILA agent dispatch configured with `agentName = "mila-agent"`
- Emulator-ready token endpoint set to `http://10.0.2.2:8787/token`

## Getting started

### 1. Start your MILA agent

Run your existing LiveKit agent so `mila-agent` is available for dispatch.

### 2. Start the bundled token server

From this project root on Windows:

```powershell
.\run-token-server.bat
```

If your current Python does not already have the required packages, install them with:

```powershell
pip install -r .\token-server\requirements.txt
```

If your MILA agent already runs from a virtual environment, you can also activate that same environment first and run `python .\token-server\server.py`.

The local token server is already configured with your MILA LiveKit Cloud URL and key pair. Keep `token-server/.env.local` private.

### 3. Run the Android app

Open the folder in Android Studio and run the `app` configuration on an Android emulator.

The app is preconfigured for the Android emulator networking alias:

- `10.0.2.2` points back to your Windows host
- Port `8787` is used by the bundled token server

### Physical device note

If you want to use a real Android phone instead of the emulator, change `tokenEndpoint` in `app/src/main/java/io/livekit/android/example/voiceassistant/TokenExt.kt` from `10.0.2.2` to your PC's LAN IP address.

## References

- [LiveKit Android starter app](https://docs.livekit.io/frontends/start/starter-apps/android/)
- [LiveKit Android components](https://docs.livekit.io/reference/components/android/)
- [LiveKit endpoint token generation](https://docs.livekit.io/frontends/build/authentication/endpoint/)
