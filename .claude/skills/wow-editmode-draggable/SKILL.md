---
name: wow-editmode-draggable
description: Make a custom WoW addon frame draggable inside Blizzard's Edit Mode (拖曳/編輯模式移動自訂框架), saving its position to SavedVariables as a CENTER offset. Use whenever a MiliUI/WoW addon needs a frame the user can reposition by entering Edit Mode and dragging — cast bars, reminders, timer/countdown bars, custom HUD elements. Trigger on "編輯模式拖曳", "Edit Mode drag", "EditModeSystemSelectionTemplate", "讓框架可以在編輯模式移動".
---

# WoW Edit Mode Draggable Frame

讓**自訂（非暴雪）框**在編輯模式裡可拖曳，不註冊真的 Edit Mode 系統（那要碰暴雪
內部、會污染）。做法：借用 `EditModeSystemSelectionTemplate`（藍色選取框）當視覺、
搭編輯模式的進出訊號順風車，拖曳與存檔全部自己來。位置存成相對 UIParent CENTER
的偏移，跟解析度／UI 縮放脫鉤。

參考實作（新到舊）：
- `MiliUI_InfoBar/Core/Bar.lua` —— **最完整**：保護框（帶 secure 子按鈕）、三重訊號、
  pcall 備援、手動拖曳。2026-08-29 的地雷全在這裡踩掉的。
- `MiliUI_DamageMeters/Meter/Move.lua` —— 手動拖曳機制的出處（含吸附與縮放）。
- `MiliUI_BloodlustMusic/Music.lua` —— 最簡版（**注意：缺下面幾個修補**，見 Gotchas）。

## 1. 框的設定（movable、非 user-placed）

```lua
local frame = CreateFrame("Frame", "MyAddon_MyBar", UIParent)
frame:SetSize(fw, fh)
frame:SetPoint("CENTER", UIParent, "CENTER", db.x or DEFAULT_X, db.y or DEFAULT_Y)
frame:SetMovable(true)
frame:SetUserPlaced(false)          -- 位置自己存 SavedVariables，不給版面快取管
frame:SetClampedToScreen(true)
```

## 2. 選取框：**開檔就建、包 pcall、中和 OnMouseDown**

```lua
-- ⚠ 開檔（建 frame 時）就建，不要等進了編輯模式才建 ——
--   在暴雪的 OnShow 執行路徑裡建框是沒驗證過的時序，實測會整組靜默失效。
local editSelection
local ok, sel = pcall(CreateFrame, "Frame", nil, frame, "EditModeSystemSelectionTemplate")
if ok and sel then
    -- ⚠⚠ 模板的 XML 綁了 OnMouseDown → EditModeManagerFrame:SelectSystem(self.parent)
    --（Blizzard_EditMode/Shared/EditModeSystemTemplates.xml，源碼查證過）。
    -- 我們不是真的系統，讓它跑下去＝暴雪去讀我們寫的 self.parent，那條執行流程
    -- 就帶著本插件的 taint 掃過每一個已註冊系統（動作條也在內）。宿主是普通框時
    -- **當下完全不報錯**，戰鬥中動作條被封鎖才爆出來。點一下不拖曳必須 no-op 化：
    sel:SetScript("OnMouseDown", function() end)
    -- 標籤／工具提示都走 self.system:GetSystemName()，塞個 stub 就好
    sel.system = { GetSystemName = function() return "我的框架名" end }
else
    -- 模板建不出來就自己畫一個藍框頂著，拖曳照常（DamageMeters 同款防禦）
    sel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                      edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    sel:SetBackdropColor(0.25, 0.6, 1, 0.15)
    sel:SetBackdropBorderColor(0.25, 0.6, 1, 0.9)
    sel:EnableMouse(true)
    sel.ShowHighlighted = sel.Show
end
sel:SetAllPoints(frame)
sel:Hide()
sel:RegisterForDrag("LeftButton")
sel:SetScript("OnDragStart", BeginDrag)   -- 見下一節，不用 StartMoving
sel:SetScript("OnDragStop", EndDrag)
editSelection = sel
```

`editSelection:ShowHighlighted()` 顯示藍框；`:Hide()` 收掉。

## 3. 拖曳：**手動算，不用 StartMoving**

`StartMoving()` 在「保護框（帶 secure 子物件）＋編輯模式」的組合下實測完全不動
（MiliUI_InfoBar，2026-08-29，兩種掛法都試過）。套組裡真正在動的實作
（DamageMeters／InfoBar）一律手動：記按下那一刻的游標與框位，拖曳中每幀用游標
差值 `ClearAllPoints`＋`SetPoint`（OOC 對保護框合法，編輯模式必然 OOC）。
driver 只在拖曳中存在 OnUpdate，平常零成本。

```lua
local dragState, dragDriver

local function EndDrag()
    if not dragState then return end
    dragState = nil
    if dragDriver then dragDriver:Hide() end
    local cx, cy = UIParent:GetCenter()
    local fx, fy = frame:GetCenter()
    db.x = math.floor(fx - cx + 0.5)   -- 存 CENTER 偏移
    db.y = math.floor(fy - cy + 0.5)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local function DragTick()
    local d = dragState
    if not d then return end
    -- 收不到 OnDragStop 的情況（滑鼠出視窗、被別的框吃掉）自己補救
    if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then EndDrag() return end
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local dx, dy = cx / scale - d.cx, cy / scale - d.cy
    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (d.left + dx) - pl, (d.top + dy) - pt)
end

local function BeginDrag()
    if InCombatLockdown() then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then return end
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    dragState = { cx = cx / scale, cy = cy / scale, left = left, top = top }
    if not dragDriver then
        dragDriver = CreateFrame("Frame")
        dragDriver:Hide()
        dragDriver:SetScript("OnUpdate", DragTick)
    end
    dragDriver:Show()
end
```

## 4. 進出編輯模式：**三重訊號，全部冪等**

只掛 `EditModeManagerFrame` 的 OnShow/OnHide（舊版技能的做法）實測會漏接。
三路並存，誰先到都一樣：

```lua
local isInEditMode = false
local function OnEnter() isInEditMode = true;  UpdateEditModeState() end
local function OnExit()  isInEditMode = false; UpdateEditModeState() end

local editModeHooked = false
local function HookEditMode()
    if editModeHooked or not EditModeManagerFrame then return end
    editModeHooked = true
    -- 訊號一：管理視窗的顯示狀態
    EditModeManagerFrame:HookScript("OnShow", OnEnter)
    EditModeManagerFrame:HookScript("OnHide", OnExit)
    -- 訊號二：直接掛方法本體 —— 編輯模式真的啟動就必然執行
    if EditModeManagerFrame.EnterEditMode then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", OnEnter)
    end
    if EditModeManagerFrame.ExitEditMode then
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", OnExit)
    end
    if EditModeManagerFrame:IsShown() then OnEnter() end
end

HookEditMode()  -- 檔案層先試一次
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)
end
-- PLAYER_LOGIN 再呼叫一次 HookEditMode() 保底

-- 訊號三：官方 EventRegistry 事件（EnterEditMode/ExitEditMode 內部發的，
-- Blizzard_EditMode/Shared/EditModeManager.lua）
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", OnEnter, "MyAddon")
    EventRegistry:RegisterCallback("EditMode.Exit",  OnExit,  "MyAddon")
end
```

```lua
local function UpdateEditModeState()
    if isInEditMode and db.enabled then
        editSelection:ShowHighlighted()
        frame:Show()      -- 平常會藏的框要給樣板內容讓玩家瞄得到
    else
        editSelection:Hide()   -- 宿主是保護框時見 Gotchas 的戰鬥條款
    end
end
```

## Gotchas / notes

- **OnMouseDown 一定要 no-op 化。** 模板 XML 綁的 `OnMouseDown` 會呼叫
  `EditModeManagerFrame:SelectSystem(self.parent)`——自訂框不是真系統，暴雪讀我們寫的
  `self.parent`，整條選取流程就帶著本插件的 taint 對**每一個**已註冊系統呼叫
  `HighlightSystem()`（動作條全在內），離開編輯模式時 `ClearHighlight` 再讀髒掉的
  `isSelected`，把動作條的欄位永久弄髒。宿主是普通框時**當下靜默、不報錯**，症狀
  要等戰鬥才出現：動作按鈕的 `SetAttribute`／`SetShown` 被封鎖、`SetCooldown` 每個
  tick 丟秘密值錯誤，而且全部記在插件頭上（2026-09-17 玩家回報，指向
  MiliUI_UnitFrames）。套組內所有借模板的實作已於 2026-09-17 全部補上。
- **選取框開檔就建**，並且 `pcall(CreateFrame, ...)`＋自畫備援——模板建立失敗是
  靜默的，沒有備援就是「藍框永遠不出現」。
- **`EditModeManagerFrame` 的 OnShow/OnHide 用 `HookScript` 是後掛勾**，跑到我們時
  暴雪那一輪（含動作條那段）已經做完，同步做就好——延一幀什麼也換不到。
  真正要記住的規則是另一條：**編輯模式不會被戰鬥關掉**，整場戰鬥都進得去（頭像
  右鍵選單）也出得來（ESC／關閉鈕），`EditModeManager` 根本沒有 PLAYER_REGEN 處理。
  所以任何「進／出編輯模式」處理器只要碰保護框（或帶保護子物件的框——錨在上面的
  選取框也連坐被保護），就要有 `InCombatLockdown()` 閘 ＋ `PLAYER_REGEN_ENABLED`
  重試；另外可以加一個**同步**的 `PLAYER_REGEN_DISABLED` 處理器當最後一個窗口把
  真實框放回去（那個事件派送當下鎖定還沒生效，所以**不能延一幀**）。
- **不要用 `StartMoving()`**，用上面的手動拖曳——至少在保護框上它是死的，而
  手動機制兩種框都通吃。
- **宿主是保護框**（帶 secure 子物件）時：選取框連坐被保護，**戰鬥中離開（或進入）
  編輯模式**那條路的 `Hide()` 會被封鎖——要延到 `PLAYER_REGEN_ENABLED` 再收
  （InfoBar 的 `ns.Defer` 模式）。
- **預設值不要讀別家的 SavedVariables**，寫死一組合理偏移；要「跟隨某個暴雪框」
  就執行期讀它的 `GetCenter()` 換算（乘有效縮放比），沒拖過（db.x=nil）才用。
- `SetUserPlaced(false)`——否則 WoW 的版面快取會跟你的 SetPoint 打架。
- 進編輯模式時平常隱藏的框要給樣板內容（假的條值／佔位文字），玩家才瞄得到。
- 借模板不註冊真系統：不會出現在編輯模式的版面清單，也因此無污染。
