# Motherload for macOS

Native macOS application bundle for the Flash game Motherload (XGen Studios, 2004).

The original SWF is not modified. It runs on [Ruffle](https://ruffle.rs) 0.7.1, a Flash Player
implementation written in Rust that renders through Metal and ships as a universal
(x86_64 + arm64) binary. No browser or Adobe Flash Player is involved.

| Property            | Value                                                              |
| ------------------- | ------------------------------------------------------------------ |
| SWF                 | `game/game.swf`, Flash 7, ActionScript 2 (AVM1), zlib-compressed   |
| SWF SHA-256         | `a6991ceb049155275cb650ab3fcd8a1dabbc907c2c6a549c64173dfa6967adec` |
| Stage               | 550 x 400 px, 42 fps                                               |
| Player              | Ruffle 0.7.1 `macos-universal` release, checksum-pinned            |
| Minimum macOS       | 10.12 (Intel), 11.0 (Apple silicon)                                |

## Build

Requires macOS and network access to github.com. No Xcode or other tooling is needed.

```bash
./macos/build.sh
```

Output: `dist/Motherload.app`. Add `--dmg` to also produce `dist/Motherload.dmg`.

Install:

```bash
cp -R dist/Motherload.app /Applications/
```

The script downloads the Ruffle release archive into `build/`, verifies its SHA-256, and
assembles the bundle:

```
Motherload.app/Contents/
  Info.plist
  MacOS/Motherload             launcher script (macos/launcher.sh)
  MacOS/ruffle                 Ruffle player binary
  Resources/game.swf           game/game.swf
  Resources/AppIcon.icns       macos/AppIcon.icns
  Resources/Ruffle-LICENSE.md  Ruffle license and third-party notices
```

The Ruffle release binary is signed with Ruffle.app's App Sandbox entitlements. The build
re-signs it ad hoc without entitlements so it can read the bundled SWF, then signs the bundle
ad hoc.

## Prebuilt download

The `macOS build` GitHub Actions workflow builds the app on a macOS runner, launches it as a
smoke test, and publishes `Motherload.dmg` as the `Motherload-macOS` artifact.

The app is ad-hoc signed, not notarized. A copy downloaded through a browser is quarantined
and Gatekeeper refuses to open it. Either remove the quarantine attribute:

```bash
xattr -dr com.apple.quarantine /Applications/Motherload.app
```

or open it once and allow it under System Settings > Privacy & Security > Open Anyway.
A bundle built locally with `build.sh` is not quarantined.

## Runtime

Player options set by the launcher:

| Option                             | Effect                                                    |
| ---------------------------------- | --------------------------------------------------------- |
| `--no-gui`                         | Hides Ruffle's menu bar; the window shows only the game.  |
| `--filesystem-access-mode deny`    | The SWF cannot read files outside its own directory.      |
| `--config`, `--save-directory`     | `~/Library/Application Support/Motherload`                |
| `--cache-directory`                | `~/Library/Caches/Motherload`                             |

Player shortcuts:

| Key   | Action                                                                      |
| ----- | --------------------------------------------------------------------------- |
| F11   | Toggle full screen (Fn+F11 on Apple keyboards; macOS may bind F11 to Show Desktop) |
| Esc   | Leave full screen                                                           |
| Cmd+P | Pause / resume                                                              |
| Cmd+Q | Quit                                                                        |

The window's green button also switches to macOS full screen; the stage scales with the
window and keeps its aspect ratio.

Additional Ruffle options can be passed through the launcher:

```bash
open -a Motherload --args --fullscreen
```

## Known limitation: saving

The game's Save and Load functions log in to an XGen Studios account and send the game state
to `/motherload/save.php` and `/motherload/restore.php` on the host the SWF was served from.
The game does not use local storage (SharedObject). Loaded from a local file, those paths
resolve to nonexistent files, so saving and loading fail. Progress lasts for the current
session only.

## Icon

`macos/AppIcon.icns` is generated from the title-screen bitmap embedded in the SWF:

```bash
python3 tools/make_icon.py game/game.swf macos/AppIcon.icns
```

Requires Pillow. Only needed to regenerate the icon.

## Credits

- Motherload: XGen Studios. The SWF in `game/` is the original release, unmodified.
- Ruffle: Ruffle LLC and contributors, MIT or Apache-2.0. The full license text and
  third-party notices are copied into the bundle as `Resources/Ruffle-LICENSE.md`.
