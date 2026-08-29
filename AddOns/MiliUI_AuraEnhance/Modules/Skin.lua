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
-- ⚠⚠ 圖示間隔做過又撤掉了（2026-08-28），不要再做。
--
-- 當時的做法是寫 `AuraContainer.iconPadding` ＋ 呼叫 `UpdateGridLayout()`
-- 蓋過編輯模式。結果：我們寫的值帶污染 → 暴雪排版讀它、整段執行帶污染 →
-- 排版尾端的 UpdateSize 把污染寫進編輯模式管理層的共用狀態 → 團隊框架
-- 在同一片狀態下更新、讀秘密血量做比較 → CompactUnitFrame 每次血量更新
-- 都炸（"attempt to compare local 'health' ... while execution tainted
-- by 'MiliUI_AuraEnhance'"，實測 336 次）。
--
-- 12.1 的判準：**到處都在比較秘密值，執行污染流到哪、哪裡就炸**——
-- 「下游沒有保護框」不再是安全線，暴雪會讀的欄位一個都不能寫。
-- 間隔請玩家在編輯模式調（增益／減益框的「圖示間距」），那條是安全端。
------------------------------------------------------------

local _issecret = issecretvalue
local _issecrettable = issecrettable

------------------------------------------------------------
-- 減益的驅散色：可讀才上，秘密完全不動
--
-- 受限場合（首領戰／M+／PvP）光環資料是秘密值，那裡讀不到、也不去讀——
-- 黑框照舊、暴雪自己的驅散色外框照舊，玩家一樣看得到類型色。
-- 非受限場合 `buttonInfo.debuffType`（＝auraData.dispelName）是明碼字串，
-- 這時把 1px 染成類型色、順手用 alpha 收掉暴雪那圈外框藝術，得到跟
-- 單位框架一樣乾淨的樣子。每輪重判，狀態切換自己會跟上。
------------------------------------------------------------
local DISPEL_COLOR = {
    Magic   = { 0.2, 0.6, 1.0 },
    Curse   = { 0.6, 0.0, 1.0 },
    Disease = { 0.6, 0.4, 0.0 },
    Poison  = { 0.0, 0.6, 0.0 },
}

-- 回傳驅散色，讀不到（秘密／沒類型／不可驅散）一律回 nil ＝「不動」。
-- 三道護欄缺一不可：buttonInfo 可能整張表是秘密（索引就炸）、
-- debuffType 可能單值是秘密（比較就炸）、明碼才准進色表查表。
local function DispelColor(btn)
    local info = btn.buttonInfo
    if type(info) ~= "table" then return nil end
    if _issecrettable and _issecrettable(info) then return nil end
    local t = info.debuffType
    if t == nil then return nil end
    if _issecret and _issecret(t) then return nil end
    return DISPEL_COLOR[t]
end

-- 這顆按鈕現在是不是武器附魔。
-- 表欄位讀取永遠合法；比較之前先驗秘密值 —— 萬一哪天 auraType 變成秘密，
-- 退成黑框，而不是整條 hook 鏈崩潰。
local function IsTempEnchant(btn)
    local t = btn.auraType
    if t == nil then return false end
    if _issecret and _issecret(t) then return false end
    return t == "TempEnchant"
end

local function ApplyFrames(frames, isDebuff)
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
            if isDebuff then
                local dc = DispelColor(btn)
                if dc then
                    c = dc
                    -- 類型色上了 1px，暴雪那圈外框藝術就收掉（alpha 它不會動）
                    if btn.DebuffBorder then btn.DebuffBorder:SetAlpha(0) end
                elseif btn.DebuffBorder then
                    btn.DebuffBorder:SetAlpha(1)
                end
            end
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
end

local function MakeHook(isDebuff)
    return function(self)
        ApplyFrames(self.auraFrames, isDebuff)
        if self.exampleAuraFrames then
            ApplyFrames(self.exampleAuraFrames, isDebuff)
        end
    end
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

    local buffHook, debuffHook = MakeHook(false), MakeHook(true)
    hooksecurefunc(BuffFrame, "UpdateAuraButtons", buffHook)
    hooksecurefunc(BuffFrame, "OnEditModeEnter", buffHook)
    hooksecurefunc(DebuffFrame, "UpdateAuraButtons", debuffHook)
    hooksecurefunc(DebuffFrame, "OnEditModeEnter", debuffHook)
end)
