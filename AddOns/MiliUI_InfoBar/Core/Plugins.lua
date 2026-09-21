------------------------------------------------------------
-- 外部插件的方塊（對外接口）
--
-- 其他插件這樣掛一顆方塊進來（放在自己的入口檔，檔案層直接塞，不必等事件）：
--
--   MiliUI_InfoBarPlugins = MiliUI_InfoBarPlugins or {}
--   MiliUI_InfoBarPlugins[#MiliUI_InfoBarPlugins + 1] = {
--       key       = "mythicplus",       -- 必填，唯一鍵（英數與底線）。⚠ 是存檔的 key，發佈後別改名
--       text      = L["M+ Summary"],    -- 必填，方塊上的字，自己在地化
--       label     = L["..."],           -- 選填，「區塊」分頁看板上的名字，省略用 text
--       desc      = L["..."],           -- 選填，看板上滑過方塊的說明
--       order     = 58,                 -- 選填，第一次出現時排在哪（對照 Config.lua 的 BLOCK_DEFS）
--       enabled   = true,               -- 選填，第一次出現時要不要顯示，預設顯示
--       OnClick   = function(tile, button) end,  -- 選填，button 是 "LeftButton"／"RightButton"…
--       OnTooltip = function(tooltip) end,       -- 選填，滑過時補提示行（標題已經寫好，不必 Show）
--   }
--
-- 走「往全域表塞」而不是呼叫資訊列的函式，理由同 MiliUI_MenuEntries（MiliUI/Menu.lua）：
-- 註冊方跟資訊列之間沒有相依宣告、載入順序不保證，而且玩家可能根本沒裝資訊列 ——
-- 塞表兩種情況都不會炸。「沒裝那支插件就不出現」也因此自然成立：沒人塞，就沒有方塊。
-- 同鍵重複註冊時後者覆蓋前者（跟選單那張表同一條規矩）。
--
-- 讀表時機：ApplyAll 每次都掃一遍（PLAYER_LOGIN 那次，所有非隨選載入的插件都已經載完）；
-- 隨選載入的插件在登入之後才塞，ADDON_LOADED 再掃一次，有新的才重套。
--
-- 存檔：db.blocks["ext_<key>"] = { enabled, order }，跟內建區塊同一張表、同一套看板。
-- 插件停用之後這一格留著但不讀（BLOCK_DEFS 裡沒有它），重新啟用時順序與開關都還在。
--
-- 刻意的限制：
--   * 只給普通按鈕，不給 secure 模板。第三方的 Lua 掛在 secure 方塊上就是 CreateTile
--     那段的污染問題（PreClick／OnMouseUp 把 secure 轉發染髒），資訊列沒辦法替別人把關。
--   * 文字是靜態的。要會變的讀數之後再開 API，現在沒有使用者。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Plugins = {}
local Plugins = ns.Plugins

local PREFIX = "ext_"
local DEFAULT_ORDER = 200     -- 沒給 order 的排在所有內建區塊後面

local entries = {}            -- 方塊 key（含前綴）→ 註冊項

-- 註冊表本身是全域的（見檔頭），資訊列比註冊方先載入時自己先建
MiliUI_InfoBarPlugins = MiliUI_InfoBarPlugins or {}

local function Valid(e)
    return type(e) == "table"
        and type(e.key) == "string" and e.key:match("^[%w_]+$") ~= nil
        and type(e.text) == "string" and e.text ~= ""
end

------------------------------------------------------------
-- 方塊實作：一顆可點的文字 tile
--
-- 點擊與提示都在點下去／滑過去的那一刻才去 entries 查，同鍵覆蓋之後立刻生效。
-- 第三方的函式一律包 xpcall：別人的錯不能把資訊列的滑過／點擊流程打斷。
------------------------------------------------------------
local function AnchorTooltip(tile)
    local _, cy = tile:GetCenter()
    local anchor = (cy and cy > UIParent:GetHeight() / 2) and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
    GameTooltip:SetOwner(tile, anchor)
end

local function MakeFactory(blockKey)
    return {
        create = function()
            local inst = { tiles = {} }
            local tile = ns.CreateTile("MiliUIInfoBar_" .. blockKey, { text = true, clickable = true })
            inst.tile = tile
            inst.tiles[1] = tile

            tile:SetScript("OnClick", function(self, button)
                local e = entries[blockKey]
                if e and type(e.OnClick) == "function" then
                    xpcall(e.OnClick, ns.ReportError, self, button)
                end
            end)
            tile:HookScript("OnEnter", function(self)
                local e = entries[blockKey]
                if not (e and type(e.OnTooltip) == "function") then return end
                AnchorTooltip(self)
                GameTooltip:SetText(e.label or e.text, 1, 1, 1)
                xpcall(e.OnTooltip, ns.ReportError, GameTooltip)
                GameTooltip:Show()
            end)
            tile:HookScript("OnLeave", function(self)
                if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end)

            function inst:Update()
                local e = entries[blockKey]
                tile:SetTileText(e and e.text or "")
            end

            return inst
        end,
    }
end

------------------------------------------------------------
-- 把全域表讀進來：新的鍵接上 BLOCK_DEFS 與 ns.Blocks，存檔缺格就補預設。
-- 回傳這一輪有沒有新方塊（呼叫端決定要不要重套）。
--
-- ⚠ 補存檔那段**每一輪都要跑**，不能只在第一次見到這個鍵時跑：還原預設值會把
--   db.blocks 整張清掉（ns.ResetDB），之後的 ApplyAll 要靠這裡把外部方塊補回來。
------------------------------------------------------------
function Plugins.Sync()
    local list = _G.MiliUI_InfoBarPlugins
    if type(list) ~= "table" then return false end
    local db = ns.GetDB()
    local added = false

    for _, e in ipairs(list) do
        if Valid(e) then
            local blockKey = PREFIX .. e.key
            if not entries[blockKey] then
                ns.BLOCK_DEFS[#ns.BLOCK_DEFS + 1] = {
                    key = blockKey, order = e.order or DEFAULT_ORDER, enabled = e.enabled ~= false,
                }
                ns.Blocks[blockKey] = MakeFactory(blockKey)
                added = true
            end
            entries[blockKey] = e
            if type(db.blocks[blockKey]) ~= "table" then
                db.blocks[blockKey] = {
                    enabled = e.enabled ~= false,
                    order   = tonumber(e.order) or DEFAULT_ORDER,
                }
            end
        end
    end
    return added
end

------------------------------------------------------------
-- 「區塊」分頁看板用：外部方塊的名字與說明（不是外部方塊就回 nil，照查語系表）
------------------------------------------------------------
function Plugins.Label(blockKey)
    local e = entries[blockKey]
    return e and (e.label or e.text) or nil
end

function Plugins.Desc(blockKey)
    local e = entries[blockKey]
    if not e then return nil end
    if type(e.desc) == "string" and e.desc ~= "" then
        return e.desc .. "\n\n" .. L["BLOCK_PLUGIN_NOTE"]
    end
    return L["BLOCK_PLUGIN_NOTE"]
end

-- 隨選載入的插件在登入之後才塞進來。登入前不理：PLAYER_LOGIN 的 ApplyAll 會掃
ns.Events.Register("ADDON_LOADED", "plugins", function()
    if not IsLoggedIn() then return end
    if Plugins.Sync() then ns.ApplyAll() end
end)
