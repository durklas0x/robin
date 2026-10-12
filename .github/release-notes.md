Robin now refreshes the Finder extension bundled with the running app on launch and rechecks stale registration after updates. Setup distinguishes disabled extensions, pending registration, and another selected app copy while preserving your enabled/disabled choice.

Registration checks run off the main thread with bounded retries. This fixes misleading disabled-extension reports caused by stale registrations; it does not bypass macOS approval requirements.

Universal build for Apple Silicon and Intel, macOS 14 or newer. This build remains ad-hoc signed and **not notarized**.

Install:

```sh
brew install --cask durklas0x/tap/robin
```

Upgrade:

```sh
brew update
brew upgrade --cask durklas0x/tap/robin
```

See the [README](https://github.com/durklas0x/robin#readme) for first-launch approval and setup.
