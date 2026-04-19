--- === ClaudeGlow ===
---
--- Orange screen-border glow that signals when Claude Code is waiting for your input.
--- Triggered by URL events from Claude Code hooks:
---   hammerspoon://claudeglowon   -- show the glow
---   hammerspoon://claudeglowoff  -- hide the glow
---
--- Usage (in ~/.hammerspoon/init.lua):
---   hs.loadSpoon("ClaudeGlow")
---   spoon.ClaudeGlow:start()
---
--- Optional configuration before :start():
---   spoon.ClaudeGlow.color     = { red = 1.0, green = 0.45, blue = 0.0 }
---   spoon.ClaudeGlow.thickness = 42   -- px of border band
---   spoon.ClaudeGlow.layers    = 24   -- stacked strokes for soft gradient

local obj = {}
obj.__index = obj

obj.name    = "ClaudeGlow"
obj.version = "0.1.0"
obj.author  = "noah.kirschbaum@gmail.com"
obj.license = "MIT"
obj.homepage = "https://github.com/noahkirsch/Claude-Code-Glow"

obj.color     = { red = 1.0, green = 0.45, blue = 0.0 }
obj.thickness = 42
obj.layers    = 24

obj.terminalBundleIDs = {
  ["com.apple.Terminal"]              = true,
  ["com.googlecode.iterm2"]           = true,
  ["com.mitchellh.ghostty"]           = true,
  ["org.alacritty"]                   = true,
  ["dev.warp.Warp-Stable"]            = true,
  ["net.kovidgoyal.kitty"]            = true,
  ["com.github.wez.wezterm"]          = true,
  ["co.zeit.hyper"]                   = true,
  ["org.tabby"]                       = true,
  ["com.microsoft.VSCode"]            = true,
  ["com.microsoft.VSCodeInsiders"]    = true,
  ["com.todesktop.230313mzl4w4u92"]   = true,
}

obj._canvases      = {}
obj._visible       = false
obj._screenWatcher = nil
obj._appWatcher    = nil

function obj:_build()
  for _, c in ipairs(self._canvases) do c:delete() end
  self._canvases = {}

  for _, screen in ipairs(hs.screen.allScreens()) do
    local frame  = screen:fullFrame()
    local canvas = hs.canvas.new({ x = frame.x, y = frame.y, w = frame.w, h = frame.h })

    for i = 1, self.layers do
      local t     = (i - 1) / self.layers
      local inset = t * self.thickness
      local alpha = 0.55 * (1 - t) * (1 - t)

      canvas:appendElements({
        type        = "rectangle",
        action      = "stroke",
        strokeColor = {
          red   = self.color.red,
          green = self.color.green,
          blue  = self.color.blue,
          alpha = alpha,
        },
        strokeWidth = (self.thickness / self.layers) + 1,
        frame = {
          x = inset,
          y = inset,
          w = frame.w - inset * 2,
          h = frame.h - inset * 2,
        },
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
      })
    end

    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:behavior({ "canJoinAllSpaces", "stationary", "transient" })
    canvas:clickActivating(false)
    canvas:canvasMouseEvents(false, false, false, false)

    table.insert(self._canvases, canvas)
  end
end

function obj:_startAppWatcher()
  if self._appWatcher then return end
  self._appWatcher = hs.application.watcher.new(function(_, event, app)
    if event == hs.application.watcher.activated and app then
      local bid = app:bundleID()
      if bid and self.terminalBundleIDs[bid] then self:hide() end
    end
  end):start()
end

function obj:_stopAppWatcher()
  if self._appWatcher then
    self._appWatcher:stop()
    self._appWatcher = nil
  end
end

function obj:show()
  self._visible = true
  for _, c in ipairs(self._canvases) do c:show() end
  self:_startAppWatcher()
end

function obj:hide()
  self._visible = false
  for _, c in ipairs(self._canvases) do c:hide() end
  self:_stopAppWatcher()
end

function obj:start()
  self:_build()

  hs.urlevent.bind("claudeglowon",  function() self:show() end)
  hs.urlevent.bind("claudeglowoff", function() self:hide() end)

  self._screenWatcher = hs.screen.watcher.new(function()
    local wasVisible = self._visible
    self:_build()
    if wasVisible then self:show() end
  end):start()

  return self
end

function obj:stop()
  if self._screenWatcher then
    self._screenWatcher:stop()
    self._screenWatcher = nil
  end
  self:_stopAppWatcher()
  for _, c in ipairs(self._canvases) do c:delete() end
  self._canvases = {}
  self._visible  = false
  return self
end

return obj
