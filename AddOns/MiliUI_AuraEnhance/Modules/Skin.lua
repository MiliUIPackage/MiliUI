------------------------------------------------------------
-- 圖示樣式：把光環圖示交給外觀樣式引擎畫
--
-- ⚠⚠ 2026-08-28 換過做法，動手前先讀完這段。
--
-- 舊做法是「藏掉暴雪那張圖示、自己畫一張、掛勾 SetTexture 跟著換圖」。那份實作在
-- 12.1 之前跑了四年零錯誤，但**在 12.1 是結構性死路**：光環受限時（首領戰／M+／PvP，
-- 判斷式是 C_Secrets.ShouldAurasBeSecret）材質值是秘密值，污染端的我們既讀不出來也
-- 餵不進去，鏡射那張永遠停在樣板的預設圖 —— 而樣板預設圖正是 INV_Misc_QuestionMark。
-- 症狀是「倒數正常、整排圖示變紅問號」，而且一個錯誤都不會報。
--
-- 現在的做法：**把暴雪那張 Icon 原封不動交給引擎**，材質值我們從頭到尾不經手。
-- 引擎對它只做 SetParent／SetTexCoord／SetDrawLayer／SetSize／SetPoint 與遮罩，
-- 全是 setter 不讀值，所以秘密值碰不到我們這一側。
--
-- 代價是真的（舊做法藏圖示就是為了躲這個）：容器排版每一次都會無條件把 Icon 的錨點
-- 洗掉重錨到按鈕角落，覆蓋掉引擎排好的位置。所以排版之後要重套，見 RestoreAnchors。
--
-- 其餘幾條照舊，都是撞牆撞出來的：
--  * 不要把光環按鈕本身交出去。它是「圖示 ＋ 底下一行時間文字」的 30x40 長方形，
--    交出去樣式會被拉長、邊框糊掉。要另外包一層 30x30 的方框交出去。
--  * 包裝框的尺寸與錨點**寫死**，一個字都不從光環框上讀。12.1 連光環框的幾何都是
--    秘密值：`Icon:GetSize()` / `GetPoint()` 回的是秘密數字，比大小當場拋
--    "attempt to compare ... a secret number value"。
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
-- 已處理過的按鈕 → 它的包裝框。排版後要靠這張表找回去重套。
local skinned = {}

local function SkinFrames(group, frames)
    for i = 1, #frames do
        local frame = frames[i]
        -- 私人光環的錨點框也在這份清單裡，它的 Icon 是 Frame 不是 Texture。
        -- 這裡是拿 GetTexture 當型別探針（我們並不呼叫它），一條就擋掉。
        if not skinned[frame] and frame.Icon and frame.Icon.GetTexture then
            local skinWrapper = CreateFrame("Frame")
            skinWrapper:SetParent(frame)
            skinWrapper:SetSize(ICON_SIZE, ICON_SIZE)
            skinWrapper:SetPoint("TOP")
            -- 出事時 /framestack 認得出是誰的，不影響行為
            frame.MiliUIAura_Skin = skinWrapper
            skinned[frame] = skinWrapper

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

            -- ⚠ 交出去的是**暴雪自己那張** Icon，不是複製品。引擎會把它收進包裝框、
            --   套上尺寸／裁切／遮罩。材質值全程由暴雪那一側寫入，我們不讀也不寫 ——
            --   這是 12.1 秘密值底下唯一走得通的路。
            group:AddButton(skinWrapper, {
                Icon = frame.Icon,
                DebuffBorder = frame.DebuffBorder,
                EnchantBorder = frame.TempEnchantBorder,
                Count = frame.Count,
                HotKey = frame.Symbol,
            }, bType)
        end
    end
end

------------------------------------------------------------
-- 排版之後把樣式重套回去
--
-- 容器的排版函式每一次都會 `Icon:ClearAllPoints()` 再錨回按鈕角落，無條件、
-- 不管位置有沒有真的變，等於每次都洗掉引擎排好的位置。
--
-- ⚠ 還原**只能叫引擎自己重套**。位置是引擎從樣式資料算出來的，我們沒辦法先記下來
--   再擺回去 —— 讀 `Icon:GetPoint()` 在 12.1 回的是秘密數字。重套完全不讀框上的
--   幾何，是這裡唯一安全的還原手段。
--
-- 成本：一次排版對每顆圖示重套一次。排版是事件驅動（光環有增減才跑），不是每幀，
-- 所以可以接受；真的吃到 CPU 再從這裡開刀。
------------------------------------------------------------
local function RestoreAnchors(group, auras)
    if not auras then return end
    -- 用 ipairs 跟容器自己走同一份清單的方式一致
    for _, aura in ipairs(auras) do
        local wrapper = skinned[aura]
        if wrapper then
            group:ReSkin(wrapper)
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
--   （把區塊搬進包裝框、交給引擎），逐一還原是另一套沒有人驗證過的程式碼。
--   寧可要一次重載，不要一條沒跑過的路。
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

    -- 排版會洗掉引擎排好的圖示位置，排完要重套回去。
    --
    -- ⚠ 容器**不是 XML 建的**，是暴雪在 Lua 裡動態生出來的，PLAYER_LOGIN 當下不保證
    --   存在。掛不上不會報錯，只會安靜地沒作用（症狀是圖示位置偏掉），所以等到
    --   PLAYER_ENTERING_WORLD 才掛（跟 AuraStyle 的 InstallHooks 同一個時機），
    --   而且沒掛成就下次進場再試一次，兩個都掛上了才收工。
    local targets = { { BuffFrame, buffs }, { DebuffFrame, debuffs } }
    local hooked = {}

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:SetScript("OnEvent", function(self)
        local remaining = 0
        for i = 1, #targets do
            if not hooked[i] then
                local frame, group = targets[i][1], targets[i][2]
                local container = frame and frame.AuraContainer
                if container then
                    hooksecurefunc(container, "UpdateGridLayout", function(_, auras)
                        RestoreAnchors(group, auras)
                    end)
                    hooked[i] = true
                else
                    remaining = remaining + 1
                end
            end
        end
        if remaining == 0 then
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end)
end)
