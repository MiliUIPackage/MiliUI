---
description: Make a custom WoW addon frame draggable inside Blizzard's Edit Mode (拖曳/編輯模式移動自訂框架), saving its position to SavedVariables as a CENTER offset. Use whenever a MiliUI/WoW addon needs a frame the user can reposition by entering Edit Mode and dragging — cast bars, reminders, timer/countdown bars, custom HUD elements. Trigger on "編輯模式拖曳", "Edit Mode drag", "EditModeSystemSelectionTemplate", "讓框架可以在編輯模式移動".
---

# WoW Edit Mode Draggable Frame

Reference implementation distilled from `MiliUI_BloodlustMusic` (`Music.lua` countdown bar and
`Reminder.lua`). Lets a **custom, non-Blizzard** frame be dragged while the player is in Blizzard's
Edit Mode, without registering a real Edit Mode system (which requires taint-prone internals).

The trick: overlay an `EditModeSystemSelectionTemplate` frame (the blue selection highlight box) on
your frame, drive `StartMoving`/`StopMovingOrSizing` yourself, and gate it on Edit Mode
show/hide. Position is stored as an offset from `UIParent`'s CENTER so it's resolution-independent.

## 1. Frame setup (movable, not user-placed)

```lua
local frame = CreateFrame("Frame", "MyAddon_MyBar", UIParent)
frame:SetSize(fw, fh)
frame:SetPoint("CENTER", UIParent, "CENTER", db.x or DEFAULT_X, db.y or DEFAULT_Y)
frame:SetMovable(true)
frame:SetUserPlaced(false)          -- we manage position ourselves via SavedVariables
frame:SetClampedToScreen(true)
frame:Hide()
```

## 2. The Edit Mode selection overlay + drag handlers

```lua
-- Optional: also allow dragging the frame body when unlocked
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) if self.unlocked then self:StartMoving() end end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    local cx, cy = UIParent:GetCenter()
    local fx, fy = self:GetCenter()
    db.x = math.floor(fx - cx + 0.5)   -- store CENTER-relative offset
    db.y = math.floor(fy - cy + 0.5)
end)

-- The blue Edit Mode selection box, shown only while editing
local editSelection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
editSelection:SetAllPoints()
editSelection:Hide()
editSelection:RegisterForDrag("LeftButton")
editSelection:SetScript("OnDragStart", function() frame:StartMoving() end)
editSelection:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    frame:SetUserPlaced(false)
    local cx, cy = UIParent:GetCenter()
    local fx, fy = frame:GetCenter()
    db.x = math.floor(fx - cx + 0.5)
    db.y = math.floor(fy - cy + 0.5)
end)
editSelection.system = {                        -- label shown on the selection box
    GetSystemName = function() return "焦點目標施法" end,
}
frame.editSelection = editSelection
```

`editSelection:ShowHighlighted()` shows the blue box + label; `:Hide()` removes it.

## 3. Enter/exit Edit Mode toggling

```lua
local isInEditMode = false
local function UpdateEditModeState()
    if isInEditMode and db.enabled then
        frame.unlocked = true
        frame:EnableMouse(true)
        -- show representative sample content so the user can see/aim the frame
        frame.editSelection:ShowHighlighted()
        UpdatePosition()                        -- re-apply db.x/db.y via SetPoint CENTER
        frame:Show()
    else
        frame.unlocked = false
        frame:EnableMouse(false)
        frame.editSelection:Hide()
        if not activeRealContent then frame:Hide() end   -- keep showing if a real cast/timer is live
    end
end
```

When `db.enabled` is false, keep the frame out of Edit Mode entirely (hide selection + frame).

## 4. Three-tier Edit Mode hook (robust against load order)

`EditModeManagerFrame` may not exist yet at file scope. Register the hook at whichever tier fires
first; `editModeHooked` guards against double-hooking.

```lua
local editModeHooked = false
local function HookEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true
    EditModeManagerFrame:HookScript("OnShow", function() isInEditMode = true;  UpdateEditModeState() end)
    EditModeManagerFrame:HookScript("OnHide", function() isInEditMode = false; UpdateEditModeState() end)
    if EditModeManagerFrame:IsShown() then isInEditMode = true; UpdateEditModeState() end
end

HookEditMode()  -- Tier 1: file scope (works if Blizzard_EditMode already loaded)
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)  -- Tier 2: on demand-load
end
-- Tier 3: also call HookEditMode() again from your PLAYER_LOGIN handler as a final fallback.
```

## 5. Re-apply saved position

```lua
local function UpdatePosition()
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x or DEFAULT_X, db.y or DEFAULT_Y)
end
```

## Gotchas / notes

- **Decouple defaults.** Store your own `DEFAULT_X/DEFAULT_Y` constants. Don't read another addon's
  SavedVariables to position relative to it — hardcode a sensible offset so the addons stay independent.
- **CENTER offset, not TOPLEFT.** Storing `GetCenter() - UIParent:GetCenter()` survives resolution/UI-scale
  changes far better than absolute coordinates.
- `SetUserPlaced(false)` after every move — otherwise WoW's layout-cache tries to manage the frame and
  fights your SetPoint.
- Create the frame **eagerly** (at load), so Edit Mode can find and show it the moment the user enters.
- Show sample content in Edit Mode (a fake bar value / placeholder text) so an otherwise-hidden frame is
  visible to drag.
- The frame is a plain `CreateFrame("Frame")` — this does NOT register a real Edit Mode system, so it
  won't appear in the Edit Mode layout list, and it's taint-safe. It just piggybacks on the Edit Mode
  show/hide state and reuses the selection-box visual.
