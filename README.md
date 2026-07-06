# WhisperServer Dictation System

## What is included

- `WhisperServer/WhisperServer.xcodeproj` — iOS app project shell with SwiftUI, local HTTP server, and WhisperKit/Swifter integration.
- `.github/workflows/build-ipa.yml` — GitHub Actions workflow to build an unsigned IPA artifact on macOS.
- `client.py` — PC-side recorder and hotkey client.
- `requirements.txt` — Python dependencies for the client.
- `config.example.json` — template for iPhone address, port, hotkey, and timeouts.

## iOS App: WhisperServer

1. Open `WhisperServer/WhisperServer.xcodeproj` in Xcode.
2. Add the Swift package dependency manually if Xcode does not resolve it automatically:
   - `https://github.com/argmaxinc/argmax-oss-swift.git` (select `WhisperKit`)
   - `https://github.com/httpswift/swifter.git`
3. Build and run on your iPhone.
4. The app shows server status, local IP, port, model selector, and last transcription.

> Note: The GitHub Actions build will produce an unsigned IPA artifact, but sideloading with a free Apple ID in Sideloadly still requires manual local signing in the Sideloadly UI.

## GitHub Actions IPA build

The workflow runs on push to `main` and manual `workflow_dispatch`:
- checks out the repo
- installs Xcode toolchain
- resolves Swift package dependencies
- builds the app with signing disabled
- packages an IPA artifact

The artifact will be available in the workflow run summary once complete.

## PC Client

1. Copy `config.example.json` to `config.json`.
2. Set your iPhone IP address and port.
3. Install the Python requirements.
4. Run `python client.py`.
5. Hold the configured hotkey to record audio, then release to send WAV audio to the iPhone and auto-type the returned text.

## Manual setup notes

- You must manually sign/install the IPA in Sideloadly or your local Apple device provisioning flow.
- The app requires local network permission on the iPhone; approve when prompted.
- To find the iPhone IP address: Settings → Wi-Fi → (info icon) → IP Address.
- After pushing, the GitHub Actions artifact can be downloaded from the workflow run summary.
