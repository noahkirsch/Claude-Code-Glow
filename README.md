# claude-glow

An ambient screen-border glow that tells you when Claude Code is waiting on you.

The edges of your screen glow soft orange whenever Claude Code is blocked on your input — a finished turn, a permission prompt, an `AskUserQuestion`, or an MCP elicitation dialog. The glow clears the moment you unblock it — either by taking an action in the terminal, or simply by focusing a terminal window (so you can acknowledge the signal without losing context at the end of the day). No notifications, no dock bouncing, no context switch — just a peripheral-vision signal so you can work in another window and know the instant Claude needs you.

<img width="800" height="517" alt="OrangeGlowGif-ezgif com-video-to-gif-converter" src="https://github.com/user-attachments/assets/b812684d-87a1-4998-8c5e-174ebda69297" />


## Requirements

- macOS
- [Hammerspoon](https://www.hammerspoon.org/) (`brew install --cask hammerspoon`)
- [Claude Code](https://docs.claude.com/en/docs/claude-code)
- `jq` (`brew install jq`)

## Install

```bash
git clone https://github.com/noahkirsch/Claude-Code-Glow
cd Claude-Code-Glow
./install.sh
```

Then restart Claude Code so it picks up the new hook wiring.

The installer:

1. Copies `ClaudeGlow.spoon` into `~/.hammerspoon/Spoons/`
2. Appends a one-liner to `~/.hammerspoon/init.lua` that loads and starts the Spoon
3. Merges the Claude Code hook wiring into `~/.claude/settings.json` (a timestamped backup is saved alongside)
4. Reloads Hammerspoon

It is safe to re-run; steps already applied are skipped.

## Uninstall

```bash
./uninstall.sh
```

Removes the Spoon, the loader lines, and the hook entries. Backups are saved.

## How it works

Hammerspoon draws a full-screen transparent canvas with a stack of stroked rectangles at decreasing alpha — a soft gradient band around the edges of every connected display. The canvas sits at the `overlay` window level, ignores clicks, and joins all Spaces so you see it everywhere.

Claude Code hooks fire `open hammerspoon://claudeglowon` and `…glowoff` URLs at the right moments. Hammerspoon's URL event handler flips the canvases visible or hidden.

### Which events fire the glow

Claude Code has several hooks that *sound* like "user needs to do something" but fire for unrelated reasons too. The wiring in `hooks.json` is narrowed to the events that actually require input:

| Event                             | Glow | Why                                                        |
| --------------------------------- | ---- | ---------------------------------------------------------- |
| `Stop`                            |  on  | Claude finished its turn and is waiting for your next prompt |
| `Notification` (`permission_prompt`, `elicitation_dialog`) |  on  | Claude wants a tool permission, or an MCP server is asking you something |
| `PreToolUse` (`AskUserQuestion`)  |  on  | Claude called `AskUserQuestion` and is waiting on your selection |
| `UserPromptSubmit`                | off  | You sent a prompt — Claude is working again                |
| `PostToolUse`                     | off  | A tool finished — covers the "you approved a permission" case, since no hook fires at the approve-click moment |
| `SessionEnd`                      | off  | Session closed                                             |
| _focus change to a terminal app_  | off  | You came back to a terminal window — signal acknowledged, no typing required |

Notable exclusions:

- `Notification` filters out `idle_prompt` and `auth_success` — those are informational and would cause false glows.
- `SubagentStop` is not wired — subagent completion isn't something you need to react to.

## Configuration

Edit the Spoon call in `~/.hammerspoon/init.lua` to customize before `:start()`:

```lua
hs.loadSpoon("ClaudeGlow")
spoon.ClaudeGlow.color     = { red = 0.2, green = 0.7, blue = 1.0 }  -- cyan
spoon.ClaudeGlow.thickness = 60      -- wider band
spoon.ClaudeGlow.layers    = 32      -- smoother gradient
spoon.ClaudeGlow:start()
```

Defaults: `{ red = 1.0, green = 0.45, blue = 0.0 }` (orange), `thickness = 42`, `layers = 24`.

### Which apps count as "a terminal"

Focusing any of these clears the glow. To add, remove, or replace entries, set `spoon.ClaudeGlow.terminalBundleIDs` before `:start()`:

```lua
spoon.ClaudeGlow.terminalBundleIDs = {
  ["com.apple.Terminal"]              = true,
  ["com.googlecode.iterm2"]           = true,
  ["com.mitchellh.ghostty"]           = true,
  ["org.alacritty"]                   = true,
  ["dev.warp.Warp-Stable"]            = true,
  ["net.kovidgoyal.kitty"]            = true,
  ["com.github.wez.wezterm"]          = true,
  ["co.zeit.hyper"]                   = true,
  ["org.tabby"]                       = true,
  ["com.microsoft.VSCode"]            = true,  -- includes integrated terminal
  ["com.microsoft.VSCodeInsiders"]    = true,
  ["com.todesktop.230313mzl4w4u92"]   = true,  -- Cursor
}
```

To find an app's bundle ID: `osascript -e 'id of app "Ghostty"'`.

Note: Hammerspoon matches at the app level, so for editors-with-terminals (VS Code, Cursor) the glow clears whenever the app becomes frontmost, regardless of whether the terminal pane or the editor pane has focus. If that's too aggressive, drop those IDs from your config.

## Troubleshooting

- **Glow never appears.** Confirm Hammerspoon is running. In the Hammerspoon Console, run `hs.urlevent.openURL("hammerspoon://claudeglowon")` — if the glow appears, the Spoon is wired up and the issue is on the Claude Code side. Check `~/.claude/settings.json` contains the hook entries.
- **Glow appears but doesn't clear.** Likely a denied permission, since no hook fires on denial. The glow will clear on the next tool call or turn end.
- **Glow fires on things that don't need input.** If you see this, open an issue with the Claude Code version and a rough description of what was happening — the event filter may need tightening.
- **Multi-monitor.** Works out of the box; the Spoon subscribes to `hs.screen.watcher` and rebuilds when displays change.

## License

MIT
