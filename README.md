# lightsout-cli

A pure Swift CLI adapted from the display disconnect and reconnect implementation in [AlonX2/LightsOut](https://github.com/AlonX2/LightsOut). No menu bar app, background process, or third-party dependencies are required.

```sh
make
./lightsout list
./lightsout off 2
./lightsout on 2
./lightsout --version
```

`lightsout --version` (or `lightsout version`) prints the executable's version,
which matches the release tag and stable Homebrew formula version.

Replace `2` with the actual display ID reported by `list`. The CLI refuses to disable the last active display.

The CLI uses the private macOS API `CGSConfigureDisplayEnabled`, so compatibility may change with macOS updates. Changes use `forSession`: they remain effective after the command exits but are not guaranteed to survive logout. Before disconnecting a display, the CLI saves its UUID and display ID to `~/Library/Application Support/lightsout-cli/displays.json` so subsequent commands can locate and reconnect it. Disabled displays may disappear from macOS's public UUID lookup APIs; `on` then attempts reconnection using the saved display ID, unless that ID is known to belong to another display. Saved IDs are not guaranteed to remain valid across login sessions or cable changes. The `off/unavailable` state means a display is disabled or physically unavailable; it does not confirm that the display is still connected.

If a display cannot be restored, reconnect its cable or log out and back in. LightsOut.app does not need to be running. Avoid changing the same display with multiple display management tools at once.

The implementation is based on LightsOut's `DisplaysViewModel.swift` and retains the upstream MIT license.

Run `make test` to check display resolution without changing any display configuration.
