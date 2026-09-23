---@class addonTableBaganator
local addonTable = select(2, ...)

------------------------------------------------------------
-- 米利UI 皮：薄轉接層
--
-- 這支只做「分派」：把 Baganator 交給皮膚的每一個框，依 regionType 轉交給
-- MiliUI_Skin 的對外 handle（`MiliUISkin_API`）。怎麼畫、什麼能碰什麼不能碰，
-- 全部在 MiliUI_Skin 那一邊（`Core/External.lua` ＋ `STYLE.md`），這裡一個貼圖都不建。
--
-- ## 時機
--
-- Baganator 在自己的 ADDON_LOADED 裡登記一個 PLAYER_LOGIN 處理器，到那時才呼叫
-- 皮膚的 LoadSkin（並設定目前的 skinner）。MiliUI_Skin 按字母序比 Baganator 晚載入，
-- 而它的引擎也是在 PLAYER_LOGIN 才 Boot —— 兩個處理器誰先跑不保證。所以：
--   * LoadSkin 向 `MiliUISkin_API.RegisterSkin` 登記；對方 Boot 之前的登記會先暫存，
--     Boot 當下交付 handle，之後的登記立刻交付。
--   * handle 到手之前進來的框全部排隊，到手的那一刻依序補畫。
--   * PLAYER_LOGIN 的時候所有非隨需載入的插件都載完了；那時全域還不存在，
--     就只再等一幀，還是沒有就放棄（框維持 Baganator 原本的樣子）。
--
-- ## 物品格與 Masque
--
-- Masque 在套 Baganator 的格子時，格子交給它 —— 兩邊都畫就是兩圈框。
--
-- ## 刻意不處理
--
--   CornerWidget  角落小元件是各插件自己的資訊（裝等、綁定、升級箭頭），長相由它們決定。
--   其餘未知的 regionType 一律略過（Baganator 之後新增的種類不會因此報錯）。
------------------------------------------------------------

if not addonTable.Skins.IsAddOnLoading("MiliUI_Skin") then
  return
end

local handle
local queue = {}
local requested = false

-- 對話框登記過的框。同一個對話框裡第一顆交進來的按鈕是「確認」那一顆
-- （對話框的按鈕一律是先建確認、再建取消），它是主按鈕，其餘次要。
local dialogs = setmetatable({}, { __mode = "k" })

local function TagSet(tags)
  local set = {}
  if tags then
    for _, tag in ipairs(tags) do
      set[tag] = true
    end
  end
  return set
end

local function ButtonVariant(button)
  local parent = button:GetParent()
  if parent and dialogs[parent] ~= nil then
    local first = dialogs[parent] == 0
    dialogs[parent] = dialogs[parent] + 1
    return first and "primary" or "secondary"
  end
  -- 單獨一顆的動作鈕（公會分頁文字的「儲存」）
  if parent and parent.SaveButton == button then
    return "primary"
  end
  -- 其餘多半是一排平行的工具鈕（存入／提取、匯出／匯入……）
  return "secondary"
end

local routes = {
  ButtonFrame = function(h, frame)
    h.Shell(frame)
  end,
  InsetFrame = function(h, frame)
    h.Inset(frame)
  end,
  Dialog = function(h, frame)
    dialogs[frame] = 0
    h.Dialog(frame, { art = { "NineSlice" } })
  end,
  Button = function(h, button)
    h.Button(button, { variant = ButtonVariant(button) })
  end,
  IconButton = function(h, button)
    h.IconButton(button)
  end,
  ItemButton = function(h, button)
    -- 有 Masque 在套：格子的長相整個交給它，但空格那張底圖（翅膀）照樣藏掉 ——
    -- Masque 不認得這張 Baganator 自己加的貼圖，不藏就會從 Masque 的框裡透出來。
    local masque = addonTable.API.IsMasqueApplying and addonTable.API.IsMasqueApplying()
    h.ItemButton(button, { art = { "SlotBackground" }, artOnly = masque })
  end,
  SideTabButton = function(h, button)
    h.SideTab(button, { art = { "Background" }, selected = "SelectedTexture" })
  end,
  TopTabButton = function(h, tab)
    h.Tab(tab, { joined = "BOTTOM" })
  end,
  TabButton = function(h, tab)
    h.Tab(tab, { joined = "TOP" })
  end,
  SearchBox = function(h, editBox)
    h.EditBox(editBox)
  end,
  EditBox = function(h, editBox)
    h.EditBox(editBox)
  end,
  Dropdown = function(h, dropdown)
    h.Dropdown(dropdown)
  end,
  CheckBox = function(h, checkBox)
    h.CheckBox(checkBox, { art = { "HoverBackground" } })
  end,
  Slider = function(h, holder)
    h.Slider(holder)
  end,
  TrimScrollBar = function(h, scrollBar)
    h.ScrollBar(scrollBar)
  end,
  CategoryLabel = function(h, label)
    h.Label(label, { baseFont = "GameFontNormal" })
  end,
  CategorySectionHeader = function(h, button)
    h.SectionHeader(button, { baseFont = "GameFontNormalMed2", arrow = "arrow" })
  end,
  Divider = function(h, texture)
    h.Divider(texture)
  end,
}

local function Dispatch(details)
  local route = routes[details.regionType]
  if route then
    route(handle, details.region, TagSet(details.tags))
  end
end

local function SkinFrame(details)
  if handle then
    Dispatch(details)
  else
    table.insert(queue, details)
  end
end

local function Receive(h)
  if type(h) ~= "table" or (h.version or 0) < 1 then
    return
  end
  handle = h
  local pending = queue
  queue = {}
  for _, details in ipairs(pending) do
    xpcall(Dispatch, CallErrorHandler, details)
  end
end

local function Request()
  local api = MiliUISkin_API
  if type(api) == "table" and type(api.RegisterSkin) == "function" then
    api.RegisterSkin("Baganator", Receive)
    return true
  end
  return false
end

local function LoadSkin()
  if requested then
    return
  end
  requested = true
  if not Request() then
    C_Timer.After(0, Request)
  end
end

-- 我們的外框只有 1px：內容離左緣 1 就不會壓到邊；上緣不必再讓（沒有凸出的雕花）。
local function SetConstants()
  addonTable.Constants.ButtonFrameOffset = 1
  addonTable.Constants.ButtonFrameOffsetTop = 0
end

addonTable.Skins.RegisterSkin("MiliUI", "miliui", LoadSkin, SkinFrame, SetConstants, {}, true)
