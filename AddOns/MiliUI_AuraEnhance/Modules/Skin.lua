------------------------------------------------------------
-- 圖示樣式：光環圖示加上套組風格的 1px 邊框
--
-- ⚠⚠ 2026-08-28 第二次換做法，動手前先讀完這段歷史。
--
-- 第一代（外觀樣式引擎 + 鏡射圖示）：藏掉暴雪的 Icon、自畫一張、掛勾 SetTexture
-- 跟著換圖。12.1 光環受限時（首領戰／M+／PvP）材質值是秘密值，污染端既讀不出
-- 也餵不進，鏡射永遠停在樣板預設圖 —— 也就是紅問號，而且零報錯。
--
-- 第二代（外觀樣式引擎 + 交出真 Icon）：修掉了問號，但要維持一整串活動零件：
-- 包裝框、四個區塊搬家、排版後重錨 hook、引擎本身、玩家挑的任意皮膚。
-- 每個零件都是一個潛在的靜默失效面（減益驅散色被 ReSkin 蓋掉就是實例）。
--
-- 現在（第三代）：不用引擎了。一張 1px 邊框貼圖錨在 Icon 四周、疊在下層，
-- 純色直角，跟套組其他部分同一套視覺語言。
--
-- 污染紀律（這支檔案的存在理由就是把接觸面縮到最小）：
--  * 只建自己的區塊，只呼叫純 setter。不藏、不搬、不鏡射任何暴雪的東西。
--  * 邊框錨在 `btn.Icon` 上 —— 暴雪排版怎麼搬 Icon，邊框自動跟著，
--    所以完全不需要排版 hook，也永遠不讀幾何（12.1 幾何是秘密數字）。
--  * 唯一的一個值判斷（附魔與否）讀 `btn.auraType`：表欄位讀取永遠合法，
--    但比較之前要過 `issecretvalue` 護欄 —— 秘密值一比較就崩潰。
--  * 減益的驅散類型色**做不到也不用做**：類型是秘密值、專用 API
--    （C_UnitAuras.GetAuraDispelTypeColor）是 AllowedWhenUntainted、顏色烤死在
--    per-type atlas 裡、AddDispelTypeTexture 只存在於路線 A 的 AuraButton。
--    四條路都封死，所以保留暴雪自己的 DebuffBorder（安全端畫的，哪裡都正常）。
------------------------------------------------------------
local _, ns = ...

ns.Skin = {}
local Skin = ns.Skin

-- 一般光環黑框；武器附魔染紫（原本的橘金外框藝術跟增益邊框太像）
local BORDER_COLOR  = { 0, 0, 0 }
local ENCHANT_COLOR = { 0.75, 0, 1 }

-- ns.db.skin。hook 是熱路徑，抓成 upvalue（Init 時接上）。
-- ⚠ DB.ResetAll 只覆寫表的內容、不換表，upvalue 才不會指到舊表。
local SKN

-- 邊框厚度（框架單位；按鈕吃編輯模式的 SetScale，非整數倍時就跟著縮放）
local function Inset()
    return (SKN and SKN.inset) or 2
end

local function AnchorBorder(border, icon, inset)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -inset, inset)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", inset, -inset)
end

------------------------------------------------------------
-- 圖示間隔：接管容器的 iconPadding
--
-- 間隔本來歸編輯模式管（增益／減益框的「圖示間距」，暴雪預設 5），它的套用
-- 方式就是一行明碼欄位寫入（UpdateSystemSettingIconPadding 的本體只有
-- `self.AuraContainer.iconPadding = value`，查證過）。我們用同一招蓋回來：
--
--  * 寫的是明碼數字；下游只有非保護框的排版 setter，編輯模式**存檔**讀的是
--    它自己的資料存放區、不回讀這個欄位——所以不會把污染寫進玩家的版面存檔。
--  * 編輯模式每次套用版面都會重寫欄位，所以掛在它的套用函式後面蓋回來；
--    比較守門（值沒偏就不動）避免每輪白跑一次重排。
--  * 代價要知道：編輯模式裡那根「圖示間距」滑桿對增益／減益框會失效
--    （拖了就被蓋回來），設定頁的說明文字有交代。
------------------------------------------------------------
local function ApplyPadding(frame)
    local c = frame and frame.AuraContainer
    local pad = SKN and SKN.spacing
    if c and pad and c.iconPadding ~= pad then
        c.iconPadding = pad
        frame:UpdateGridLayout()
    end
end

-- 光環按鈕 → 邊框貼圖。按鈕池只長不消（暴雪 frame 刪不掉），一顆只建一次。
local borders = {}

local _issecret = issecretvalue

-- 這顆按鈕現在是不是武器附魔。
-- 表欄位讀取永遠合法；比較之前先驗秘密值 —— 萬一哪天 auraType 變成秘密，
-- 退成黑框，而不是整條 hook 鏈崩潰。
local function IsTempEnchant(btn)
    local t = btn.auraType
    if t == nil then return false end
    if _issecret and _issecret(t) then return false end
    return t == "TempEnchant"
end

local function ApplyFrames(frames)
    for i = 1, #frames do
        local btn = frames[i]
        -- 私人光環的錨點框也在這份清單裡，它的 Icon 是 Frame 不是 Texture。
        -- GetTexture 只當型別探針（看欄位在不在，不呼叫）。
        if btn.Icon and btn.Icon.GetTexture and not btn.isAuraAnchor then
            local border = borders[btn]
            if not border then
                -- 裁掉圖示素材烤在圖裡的內建斜邊框，1px 框才會像 Cell 一樣乾淨。
                -- 0.12/0.88 是套組標準裁切（Cell、MiliUI_UnitFrames 同值）。
                -- 純 setter、常數進場；暴雪的光環路徑不會重設 TexCoord，設一次就好。
                btn.Icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)

                -- Icon 在 BACKGROUND 層級 0（AuraButtonArtTemplate），邊框墊在 -1
                border = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
                AnchorBorder(border, btn.Icon, Inset())
                borders[btn] = border

                -- 附魔的橘金外框藝術不再需要（1px 紫框取代）。用 alpha 藏：
                -- Show/Hide 歸暴雪管、我們不跟它搶，alpha 它不會動，藏一次就永久有效
                if btn.TempEnchantBorder then
                    btn.TempEnchantBorder:SetAlpha(0)
                end
            end

            -- 顏色每輪重判：按鈕是回收再用的，種類（減益→附魔）會變
            local c = IsTempEnchant(btn) and ENCHANT_COLOR or BORDER_COLOR
            border:SetColorTexture(c[1], c[2], c[3])
        end
    end
end

-- 設定改變時把新厚度套到既有的邊框上（設定頁的 apply 就是它）。
-- 純 setter 重錨自己的貼圖，所以厚度不用重載；開關才需要（hook 是單向的）。
function Skin.Apply()
    local inset = Inset()
    for btn, border in pairs(borders) do
        AnchorBorder(border, btn.Icon, inset)
    end
    ApplyPadding(BuffFrame)
    ApplyPadding(DebuffFrame)
end

local function Hook(self)
    ApplyFrames(self.auraFrames)
    if self.exampleAuraFrames then
        ApplyFrames(self.exampleAuraFrames)
    end
    -- 順手把間隔守住（比較守門，值沒偏是兩次表讀取而已）——
    -- 這條也涵蓋「編輯模式在我們掛勾之前就套完設定」的登入時序
    ApplyPadding(self)
end

------------------------------------------------------------
-- 啟動
--
-- ⚠ 開關只在啟動時看一次，改完要重載介面。停用時不跑任何還原：那時候
--   什麼都還沒建，也就沒有東西要收。
------------------------------------------------------------
ns.RegisterCallback("Init", "skin", function()
    SKN = ns.db.skin
    if not SKN.enabled then return end

    hooksecurefunc(BuffFrame, "UpdateAuraButtons", Hook)
    hooksecurefunc(BuffFrame, "OnEditModeEnter", Hook)
    hooksecurefunc(DebuffFrame, "UpdateAuraButtons", Hook)
    hooksecurefunc(DebuffFrame, "OnEditModeEnter", Hook)

    -- 編輯模式重寫間隔的當下就蓋回來（見 ApplyPadding 的說明）
    for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
        if frame.UpdateSystemSettingIconPadding then
            hooksecurefunc(frame, "UpdateSystemSettingIconPadding", ApplyPadding)
        end
    end
end)
