Robin adds folder autocomplete to the editable path bar. Press **Tab** to see matching folders beneath the text cursor, then choose with the mouse or arrow keys and Return. Absolute paths, relative paths, `~/`, spaces, and Unicode folder names are supported.

This release also fixes automatic path selection, preserves selection while Finder refreshes, and correctly recognizes existing folders reached through symlinks, including `/private/tmp` and `/tmp`.

Universal build for Apple Silicon and Intel, macOS 14 or newer. This build is ad-hoc signed and **not notarized**.

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
