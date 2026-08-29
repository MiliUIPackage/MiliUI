------------------------------------------------------------
-- 資訊列專用的提示框
--
-- **自己開一個 GameTooltip，不借 GameTooltip 全域那一個。**
-- 借全域的有兩個問題：
--   1. 它的外觀被 MiliUI_Tooltip（或玩家裝的任何提示插件）接管了，我們在上面
--      再蓋一層皮就是兩個插件輪流改同一個框。
--   2. 一長串公會名單會把全域提示的行數池撐大，之後每一個普通的物品提示都帶著
--      那些行走 —— 行是回收不掉的（見 wow-frame-lifecycle-costs）。
--
-- 用 `GameTooltipTemplate` 而不是自己畫兩欄清單：AddDoubleLine 的欄寬計算、
-- 自動調整大小、字型繼承全部是現成的，自己重做一遍只會多出一堆對不齊的邊界情況。
-- 我們只換皮：把暴雪的 NineSlice alpha 歸零，在它底下墊自己的 HUD 皮。
-- （同一個手法在 MiliUI_Tooltip/Core/Skin.lua 已經跑過一年。）
------------------------------------------------------------
local _, ns = ...

ns.Tip = {}
local Tip = ns.Tip
local S = ns.Style

local tip, skin

local function Build()
    if tip then return tip end

    tip = CreateFrame("GameTooltip", "MiliUIMinimapTooltip", UIParent, "GameTooltipTemplate")
    tip:SetClampedToScreen(true)

    -- 皮是 tip 的**子框**、層級壓在它之下 ⇒ 蓋不到文字，而且 tip 顯示／隱藏時
    -- 自動跟著，不必掛 OnShow/OnHide。
    skin = CreateFrame("Frame", nil, tip, "BackdropTemplate")
    skin:SetAllPoints(tip)
    skin:SetFrameLevel(math.max(0, tip:GetFrameLevel() - 1))
    -- 深色、有質感、不透明的提示皮。完整理由寫在 Core/Style.lua 的
    -- S.ApplyTooltipSkin：一句話是「面板底色不承載資訊所以可以透，
    -- 提示底色承載的是『讓字讀得出來』，那就不能透」。
    S.ApplyTooltipSkin(skin)

    tip:HookScript("OnShow", function(self)
        -- NineSlice 每次顯示都要重申：暴雪在 OnShow 會依 tooltip 型別重設底框樣式
        local nine = self.NineSlice
        if nine then pcall(nine.SetAlpha, nine, 0) end
        skin:SetFrameLevel(math.max(0, self:GetFrameLevel() - 1))
        S.RefreshTooltipSkin(skin)
    end)

    return tip
end

------------------------------------------------------------
-- 開啟：一律錨在來源按鈕上
--
-- anchor 由呼叫端決定貼哪一邊 —— 資訊列在畫面右上角，提示往左下長才不會出畫面。
------------------------------------------------------------
function Tip.Open(owner, anchorPoint, relPoint, x, y)
    Build()
    tip:SetOwner(owner, "ANCHOR_NONE")
    tip:ClearAllPoints()
    tip:SetPoint(anchorPoint or "TOPRIGHT", owner, relPoint or "BOTTOMRIGHT", x or 0, y or -4)
    tip:ClearLines()
    return tip
end

function Tip.Close()
    if tip then tip:Hide() end
end

function Tip.IsOwnedBy(owner)
    return tip and tip:IsShown() and tip:GetOwner() == owner
end

function Tip.Frame()
    return tip
end

------------------------------------------------------------
-- 一行「名字 ── 區域」
--
-- 左欄職業色、右欄同區綠／不同區灰。這是提示裡唯一破例上彩色的地方：
-- 職業色在這裡承載的是「這是誰、哪個職業」，不是狀態，符合
-- miliui-color-states 的「顏色只承載身分」那條。
------------------------------------------------------------
local ZONE_SAME = { 0.35, 0.85, 0.35 }
local ZONE_OTHER = { 0.6, 0.6, 0.6 }

function Tip.AddMember(entry, currentZone, showZone)
    ------------------------------------------------------------
    -- 不在 WoW 的好友：整列壓成灰的，右欄顯示他在玩什麼。
    -- 不上職業色也不標等級 —— 那兩樣是「這個人現在能不能一起打」的訊號，
    -- 對不在遊戲裡的人套上去只會讓清單看起來每一列都一樣重要。
    ------------------------------------------------------------
    if entry.inWoW == false then
        local left = "|cff888888" .. entry.name .. "|r"
        if entry.zone ~= "" then
            tip:AddDoubleLine(left, entry.zone, 1, 1, 1, 0.45, 0.45, 0.45)
        else
            tip:AddLine(left, 1, 1, 1)
        end
        return
    end

    local hex = S.ClassHex(entry.class)
    local left
    if entry.level then
        local lc = GetQuestDifficultyColor(entry.level)
        left = string.format("|cff%02x%02x%02x%d|r |c%s%s|r",
            lc.r * 255, lc.g * 255, lc.b * 255, entry.level, hex, entry.name)
    else
        left = string.format("|c%s%s|r", hex, entry.name)
    end

    -- 戰網好友：角色名後面補戰網暱稱，兩個都要看得到才認得出是誰
    if entry.tag and entry.tag ~= entry.name then
        left = left .. " |cff888888(" .. entry.tag .. ")|r"
    end

    local tag = ns.Data.StatusTag(entry)
    if tag then left = left .. " " .. tag end

    if not showZone or entry.zone == "" then
        tip:AddLine(left, 1, 1, 1)
        return
    end

    local zc = (entry.zone == currentZone) and ZONE_SAME or ZONE_OTHER
    tip:AddDoubleLine(left, entry.zone, 1, 1, 1, zc[1], zc[2], zc[3])
end

------------------------------------------------------------
-- 區段標題。用強調色（職業色）＋一行空白隔開。
------------------------------------------------------------
-- ⚠ **不能寫 `AddDoubleLine(l, r, S.Accent())`。** S.Accent() 回四個值（含 alpha），
--   而 AddDoubleLine 的簽章是 (左, 右, rL, gL, bL, rR, gR, bR) —— alpha 會被當成
--   右欄的紅色分量，右欄變成半紅的字。AddLine 同理，第四個參數是 wrapText。
--   一律先解成三個變數再傳。
function Tip.AddSection(text, count)
    local ar, ag, ab = S.Accent()
    tip:AddLine(" ")
    if count then
        tip:AddDoubleLine(text, count, ar, ag, ab, ar, ag, ab)
    else
        tip:AddLine(text, ar, ag, ab)
    end
end

-- 提示底部的操作說明。一律灰字、一律排在最後。
function Tip.AddHint(...)
    tip:AddLine(" ")
    local dim = S.TEXT_DIM
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then tip:AddLine(line, dim[1], dim[2], dim[3]) end
    end
end

ns.RegisterCallback("AccentChanged", "Tip", function()
    if skin then S.RefreshTooltipSkin(skin) end
end)

ns.RegisterCallback("ConfigChanged", "Tip", function()
    if skin then S.RefreshTooltipSkin(skin) end
end)
