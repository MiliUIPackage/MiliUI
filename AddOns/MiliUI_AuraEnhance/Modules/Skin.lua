------------------------------------------------------------
-- 圖示樣式：把光環圖示交給外觀樣式引擎（Masque）畫
--
-- ⚠⚠ 這支是**照搬**一份已經在遊戲裡跑到零錯誤的實作，不是重寫。每一個看起來
--    「可以更聰明一點」的地方，都是別人撞牆撞出來的結果：
--
--  * 不要把光環按鈕本身交出去。那顆按鈕是「圖示 ＋ 底下一行時間文字」的長方形，
--    交出去樣式會被拉成長方形、邊框糊掉。要另外包一層 30x30 的方框交出去。
--  * 包裝框的尺寸與錨點**寫死**（30x30、錨在按鈕 TOP），一個字都不從光環框上讀。
--    12.1 連光環框的幾何都是秘密值：`Icon:GetSize()` / `GetPoint()` 回的是秘密數字，
--    比大小當場拋 "attempt to compare ... a secret number value"。
--    唯一的讀是 `Icon:GetTexture()` 直接轉手餵給 `SetTexture` —— 傳遞者不是讀取者，
--    這個秘密值允許。
--  * 暴雪會不停把它自己那張圖示搬回原位，所以是**藏掉它、自己畫一張**，
--    再掛勾 `SetTexture` 跟著換圖。不要試圖去移動它。
--  * 群組是**兩組**，由「哪個容器」決定（增益容器一組、減益容器一組），
--    不是由光環種類決定。種類走 AddButton 的第三個參數。
--  * 每顆按鈕只處理一次（`skinned` 表）。按鈕是回收再用的，重複處理會疊。
------------------------------------------------------------
local _, ns = ...

ns.Skin = {}
local Skin = ns.Skin

local L = ns.L

-- 武器附魔外框染紫。原始貼圖是橘金色，跟增益的邊框太像。
local ENCHANT_BORDER_COLOR = { 0.75, 0, 1 }

local ICON_SIZE = 30

------------------------------------------------------------
-- 引擎
------------------------------------------------------------
local engine
local function Engine()
    if engine ~= nil then return engine end
    engine = (LibStub and LibStub("Masque", true)) or false
    return engine
end

function Skin.IsAvailable()
    return Engine() and true or false
end

-- 帶玩家去挑樣式。引擎自己的設定介面，沒有就算了。
function Skin.OpenEngineOptions()
    if SlashCmdList and SlashCmdList["MASQUE"] then
        SlashCmdList["MASQUE"]("")
    end
end

------------------------------------------------------------
-- 套用
------------------------------------------------------------
local skinned = {}

local function SkinFrames(group, frames)
    for i = 1, #frames do
        local frame = frames[i]
        -- 私人光環的錨點框也在這份清單裡，它的 Icon 是 Frame 不是 Texture，
        -- 沒有 GetTexture，這一條就擋掉了
        if not skinned[frame] and frame.Icon.GetTexture then
            skinned[frame] = 1

            local skinWrapper = CreateFrame("Frame")
            skinWrapper:SetParent(frame)
            skinWrapper:SetSize(ICON_SIZE, ICON_SIZE)
            skinWrapper:SetPoint("TOP")
            -- 出事時 /framestack 認得出是誰的，不影響行為
            frame.MiliUIAura_Skin = skinWrapper

            frame.Icon:Hide()
            frame.SkinnedIcon = skinWrapper:CreateTexture(nil, "BACKGROUND")
            frame.SkinnedIcon:SetSize(ICON_SIZE, ICON_SIZE)
            frame.SkinnedIcon:SetPoint("CENTER")
            frame.SkinnedIcon:SetTexture(frame.Icon:GetTexture())
            hooksecurefunc(frame.Icon, "SetTexture", function(_, tex)
                frame.SkinnedIcon:SetTexture(tex)
            end)

            if frame.Count then
                -- 編輯模式的示範圖示沒有層數文字
                frame.Count:SetParent(skinWrapper)
            end
            if frame.DebuffBorder then
                frame.DebuffBorder:SetParent(skinWrapper)
            end
            if frame.TempEnchantBorder then
                frame.TempEnchantBorder:SetParent(skinWrapper)
                frame.TempEnchantBorder:SetVertexColor(
                    ENCHANT_BORDER_COLOR[1], ENCHANT_BORDER_COLOR[2], ENCHANT_BORDER_COLOR[3])
            end
            if frame.Symbol then
                -- 色盲模式用文字標示驅散類型
                frame.Symbol:SetParent(skinWrapper)
            end

            local bType = frame.auraType or "Aura"
            if bType == "DeadlyDebuff" then
                bType = "Debuff"
            end

            group:AddButton(skinWrapper, {
                Icon = frame.SkinnedIcon,
                DebuffBorder = frame.DebuffBorder,
                EnchantBorder = frame.TempEnchantBorder,
                Count = frame.Count,
                HotKey = frame.Symbol,
            }, bType)
        end
    end
end

local function MakeHook(group)
    return function(self)
        SkinFrames(group, self.auraFrames)
        if self.exampleAuraFrames then
            SkinFrames(group, self.exampleAuraFrames)
        end
    end
end

------------------------------------------------------------
-- 啟動
--
-- ⚠ 開關只在啟動時看一次，改完要重載介面。這是刻意的：上面每一步都是單向的
--   （藏掉暴雪的圖示、把區塊搬進包裝框、交給引擎），逐一還原是另一套沒有人
--   驗證過的程式碼。寧可要一次重載，不要一條沒跑過的路。
------------------------------------------------------------
ns.RegisterCallback("Init", "skin", function()
    if not ns.db.skin.enabled then return end

    local LMB = Engine()
    if not LMB then return end

    local buffs   = LMB:Group(L["MiliUI Aura Enhance"], L["Buffs"])
    local debuffs = LMB:Group(L["MiliUI Aura Enhance"], L["Debuffs"])

    hooksecurefunc(BuffFrame, "UpdateAuraButtons", MakeHook(buffs))
    hooksecurefunc(BuffFrame, "OnEditModeEnter", MakeHook(buffs))
    hooksecurefunc(DebuffFrame, "UpdateAuraButtons", MakeHook(debuffs))
    hooksecurefunc(DebuffFrame, "OnEditModeEnter", MakeHook(debuffs))
end)
