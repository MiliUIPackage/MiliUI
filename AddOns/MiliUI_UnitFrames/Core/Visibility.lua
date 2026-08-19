------------------------------------------------------------
-- 顯示條件與整框透明度
--
-- ⚠⚠ 為什麼要多插一層「閘框」，不直接 uf:Hide()：
--
-- 單位框是 SecureUnitButton，顯示權已經交給 `RegisterUnitWatch` —— 它會從**安全端**
-- Show/Hide 那個框。我們再自己 Show/Hide 就是兩個人搶同一個開關：不是被安全端立刻
-- 蓋回去，就是在戰鬥中踩到保護。
--
-- 對策：在單位框**上面**插一層我們自己的普通 Frame（gate），單位框當它的子物件。
--   * 藏父層 = 子物件跟著看不見，而普通 frame 的 Show/Hide 戰鬥中完全合法
--   * 「看得到」＝ 閘框顯示 AND 單位存在（unit watch）—— 兩個條件天然 AND，
--     不需要任何 secure snippet、不碰 RegisterStateDriver、不動保護屬性
--   * unit watch 完全不受影響，它照樣管它那半邊
--
-- ⚠ 兩個跟著來的細節：
--   1. 閘框藏起來時子物件的 `IsVisible()` 是 false，`ns.Refresh` 的閘門會擋掉更新。
--      這正是我們要的（藏起來就不該付重畫成本）。
--   2. 但閘框**重新顯示時單位框的 OnShow 不會觸發**（它一路都是 Shown，只是父層藏著），
--      所以要在閘框的 OnShow 補一次全量重畫，否則會看到上一次藏起來前的舊資料。
--
-- 透明度只有一個出口 `V.ApplyAlpha`：超出距離淡出與脫戰淡出是兩個獨立來源，
-- 各自 SetAlpha 會互相蓋掉（先設淡出、後設不淡 ⇒ 永遠不淡）。一律算完再設一次，取最低。
------------------------------------------------------------
local _, ns = ...

ns.Visibility = {}
local V = ns.Visibility

------------------------------------------------------------
-- 明文守衛
------------------------------------------------------------
-- 這個檔問的東西幾乎都是玩家自己的狀態（明文），只有 UnitCanAttack 對受限單位
-- 可能回秘密布林。秘密與 nil 一律回 nil ＝「判不出來」，呼叫端當作不擋（fail open）：
-- 把該看到的框藏掉，比偶爾多顯示一次糟糕得多。
local function PlainBool(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v and true or false
end

------------------------------------------------------------
-- 主模式（單選）
------------------------------------------------------------
-- 回 true = 這個條件允許顯示。全部走明文 API：
-- InCombatLockdown / IsInGroup / IsInRaid 都不受 12.1 秘密值影響。
local MODES = {
    always      = function() return true end,
    inCombat    = function() return InCombatLockdown() and true or false end,
    outOfCombat = function() return not InCombatLockdown() end,
    inGroup     = function() return IsInGroup() and true or false end,
    inParty     = function() return IsInGroup() and not IsInRaid() end,
    inRaid      = function() return IsInRaid() and true or false end,
    solo        = function() return not IsInGroup() end,
}
V.MODES = MODES

------------------------------------------------------------
-- 附加條件（各自獨立的勾選，任一成立就藏）
------------------------------------------------------------
-- 副本＝有難度的實例地圖。要排除要塞／庭園那種「技術上是實例但感覺是開放世界」的地方，
-- 所以看 instanceType 而不是只看 IsInInstance()。
local INSTANCE_TYPES = { party = true, raid = true, scenario = true, arena = true, pvp = true }

local function InInstance()
    local _, iType = GetInstanceInfo()
    return INSTANCE_TYPES[iType] == true
end

-- 「騎乘中」要把德魯伊的旅行／水生／飛行型態算進去：IsMounted 看不到型態，
-- 但玩家的體感是一樣的（在趕路，不想看單位框）。
local TRAVEL_FORMS = { [3] = true, [4] = true, [27] = true, [29] = true }

local function MountedLike()
    if IsMounted and IsMounted() then return true end
    local form = GetShapeshiftFormID and GetShapeshiftFormID()
    return form ~= nil and TRAVEL_FORMS[form] == true
end

------------------------------------------------------------
-- 判定
------------------------------------------------------------
function V.Eval(uf)
    local fdb = uf.db and uf.db.frame
    if not fdb then return true end

    local mode = MODES[fdb.visibility or "always"] or MODES.always
    if not mode() then return false end

    if fdb.visOnlyInstances and not InInstance() then return false end
    if fdb.visHideMounted and MountedLike() then return false end

    -- UnitExists 回明文布林（受限身分改的是「內容」，不是「存不存在」）
    if fdb.visHideNoTarget and not UnitExists("target") then return false end
    if fdb.visHideNoEnemy then
        if not UnitExists("target") then return false end
        -- 只有「明文確定打不到」才擋；秘密值判不出來就放行
        if PlainBool(UnitCanAttack("player", "target")) == false then return false end
    end

    return true
end

-- 這個框有沒有用到任何條件？沒有的話事件處理可以整個早退。
local function HasConditions(uf)
    local fdb = uf.db and uf.db.frame
    if not fdb then return false end
    return (fdb.visibility or "always") ~= "always"
        or fdb.visOnlyInstances or fdb.visHideMounted
        or fdb.visHideNoTarget or fdb.visHideNoEnemy
end

------------------------------------------------------------
-- 閘框
------------------------------------------------------------
-- spawn 時建一次。⚠ SetParent 對 secure 框在戰鬥中不合法，所以只在這裡做
-- （spawn 走 PLAYER_LOGIN 與設定套用，兩邊都保證不在戰鬥）。
function V.CreateGate(uf)
    if uf.visGate then return uf.visGate end
    local gate = CreateFrame("Frame", nil, UIParent)
    -- 純粹當顯示開關，不管版面：單位框自己錨在 UIParent 上（錨點跟父子關係無關），
    -- 所以閘框的尺寸與位置對畫面沒有影響。鋪滿只是為了不要留一個零尺寸的怪東西。
    gate:SetAllPoints(UIParent)
    gate:HookScript("OnShow", function()
        -- 父層重新顯示時子物件的 OnShow 不會觸發（它一路都是 Shown）→ 這裡補一次，
        -- 否則會看到藏起來之前的舊資料
        ns.Refresh(uf, "unitchanged")
        V.ApplyAlpha(uf)
    end)
    uf:SetParent(gate)
    uf.visGate = gate
    return gate
end

-- ⚠ 這一行會在**戰鬥中**跑（進戰鬥、換目標、隊伍變動都會推它）。
-- 依據是「保護只管對受保護物件本身做 Show/Hide/移動/換父層」，藏一個我們自己建的
-- 普通父層不在那張清單裡 —— 這也是很多動作條插件放 secure 按鈕的做法。
-- 萬一這個判斷錯了，失敗方式是可見的：Core/Init.lua 的 ADDON_ACTION_FORBIDDEN
-- 攔截器會印出「封鎖動作」並指名函式，不會靜默壞掉。首次進副本值得留意一下。
function V.Apply(uf)
    local gate = uf and uf.visGate
    if not gate then return end
    if uf.isPreview then gate:Show(); return end
    gate:SetShown(V.Eval(uf))
end

------------------------------------------------------------
-- 整框透明度（唯一出口）
------------------------------------------------------------
-- 兩個來源取最低。用 uf.appliedAlpha 記住現值，一樣就不重設——SetAlpha 本身便宜，
-- 但它會跟預覽的高亮 alpha 打架，能不叫就不叫。
-- 超出距離的暗色遮罩層級。
-- 非文字元件的預設 level 最高是 8、文字最低是 10 ⇒ 放 9 剛好把「條與頭像」蓋住、
-- 「數字」留在上面。超出距離時最需要的資訊恰好是「他還剩多少血、要不要移動」，
-- 那行數字不該跟著糊掉。
-- ⚠ 使用者若把某條文字的 level 設到 9 以下，那條就會一起變暗 —— 這是可預期的，
-- 不特別處理（level 本來就是「誰蓋誰」的唯一依據）。
local OOR_SCRIM_LEVEL = 9

local function OutOfRange(uf)
    local fdb = uf.db and uf.db.frame
    return fdb and fdb.fadeOutOfRange and ns.Range.IsOut(uf.unit) and true or false
end

-- 暗色層：不降 alpha，改在上面疊一層半透明黑。
-- 降 alpha 會讓背景透出來 —— 紅血條疊在草地上變成濁褐色，而且在亮背景上甚至會
-- 顯得更亮，語意剛好相反。疊暗色則是不管背景是什麼都一定變暗，顏色可預測，
-- 也完全不碰 vertex color（職業色可能是秘密值，碰不得）。
local function Scrim(uf)
    local sc = uf.oorScrim
    if not sc then
        -- CreateFrame 本身不受戰鬥限制；這是我們自己建的普通框，不是受保護物件
        sc = CreateFrame("Frame", nil, uf)
        sc:SetAllPoints(uf)
        sc:SetFrameLevel(OOR_SCRIM_LEVEL)
        sc:EnableMouse(false)          -- 不要吃掉滑鼠（右鍵選單、提示都靠它）
        sc.tex = sc:CreateTexture(nil, "OVERLAY")
        sc.tex:SetAllPoints(sc)
        sc.tex:SetColorTexture(0, 0, 0, 1)
        sc:Hide()
        uf.oorScrim = sc
    end
    return sc
end

function V.Alpha(uf)
    local fdb = uf.db and uf.db.frame
    if not fdb then return 1 end
    local g = ns.db.global
    local a = 1
    -- 只有 fade 模式才降整框 alpha；dim 模式改走 Scrim
    if (g.oorStyle or "dim") == "fade" and OutOfRange(uf) then
        local oor = g.oorAlpha or 0.45
        if oor < a then a = oor end
    end
    if fdb.fadeOutOfCombat and not InCombatLockdown() then
        local ooc = g.oocAlpha or 0.5
        if ooc < a then a = ooc end
    end
    return a
end

-- 暗色層的開關。跟 alpha 一樣，狀態沒變就不要重設（這支落在 0.2 秒的輪詢上）
local function ApplyScrim(uf)
    local g = ns.db.global
    local on = (g.oorStyle or "dim") == "dim" and OutOfRange(uf)
    if not on then
        if uf.oorScrim then uf.oorScrim:Hide() end
        uf.appliedScrim = nil
        return
    end
    local strength = g.oorDim or 0.55
    if uf.appliedScrim == strength then return end
    uf.appliedScrim = strength
    local sc = Scrim(uf)
    sc.tex:SetAlpha(strength)
    sc:Show()
end

function V.ApplyAlpha(uf)
    if not uf or uf.isPreview then return end   -- 預覽的 alpha 由 Preview.Highlight 管
    ApplyScrim(uf)
    local a = V.Alpha(uf)
    if a == uf.appliedAlpha then return end
    uf.appliedAlpha = a
    uf:SetAlpha(a)
end

------------------------------------------------------------
-- 全部重算
------------------------------------------------------------
-- anyConditions / anyOocFade 是快取旗標：沒有任何框用到的時候，事件處理連迴圈都不跑。
-- 由 SettingsApplied 重算（設定是唯一會改這件事的入口）。
V.anyConditions = false
V.anyOocFade = false

function V.Refresh()
    local conds, ooc = false, false
    for _, uf in pairs(ns.frames) do
        if HasConditions(uf) then conds = true end
        if uf.db and uf.db.frame and uf.db.frame.fadeOutOfCombat then ooc = true end
        V.Apply(uf)
        uf.appliedAlpha = nil       -- 設定可能剛改過 oorAlpha／oocAlpha，強迫重設
        V.ApplyAlpha(uf)
    end
    V.anyConditions, V.anyOocFade = conds, ooc
end

local function ApplyAllIfNeeded()
    if not V.anyConditions then return end
    for _, uf in pairs(ns.frames) do V.Apply(uf) end
end

local function ApplyAllAlpha()
    if not V.anyOocFade then return end
    for _, uf in pairs(ns.frames) do V.ApplyAlpha(uf) end
end

------------------------------------------------------------
-- 事件
--
-- PLAYER_REGEN_*／GROUP_ROSTER_UPDATE／PLAYER_ENTERING_WORLD／PLAYER_TARGET_CHANGED／
-- UPDATE_SHAPESHIFT_FORM 其他模組已經在收了，多掛一個 callback 不增加註冊成本。
-- 只有 ZONE_CHANGED_NEW_AREA 與 PLAYER_MOUNT_DISPLAY_CHANGED 是新的，兩個都很罕見。
------------------------------------------------------------
local function OnCombat()
    ApplyAllIfNeeded()
    ApplyAllAlpha()          -- 脫戰淡出吃的就是這個
end

ns.Events.Register("PLAYER_REGEN_DISABLED", "visibility_combat_in", OnCombat)
ns.Events.Register("PLAYER_REGEN_ENABLED", "visibility_combat_out", OnCombat)
ns.Events.Register("GROUP_ROSTER_UPDATE", "visibility_group", ApplyAllIfNeeded)
ns.Events.Register("PLAYER_TARGET_CHANGED", "visibility_target", ApplyAllIfNeeded)
ns.Events.Register("ZONE_CHANGED_NEW_AREA", "visibility_zone", ApplyAllIfNeeded)
ns.Events.Register("UPDATE_SHAPESHIFT_FORM", "visibility_form", ApplyAllIfNeeded)
ns.Events.Register("PLAYER_MOUNT_DISPLAY_CHANGED", "visibility_mount", ApplyAllIfNeeded)
-- 進世界：副本判定與載具都可能變，而且旗標本身要重算（設定檔可能剛換）
ns.Events.Register("PLAYER_ENTERING_WORLD", "visibility_pew", function() V.Refresh() end)

-- 設定套用完重算旗標並重跑一次
ns.RegisterCallback("SettingsApplied", "visibility", function() V.Refresh() end)

------------------------------------------------------------
-- /muf debug
------------------------------------------------------------
function V.Debug()
    local out = {}
    for _, unit in ipairs(ns.UNITS) do
        local uf = ns.frames[unit]
        if uf and uf.visGate then
            local fdb = uf.db.frame
            local extra = {}
            if fdb.visOnlyInstances then extra[#extra + 1] = "副本" end
            if fdb.visHideMounted then extra[#extra + 1] = "騎乘藏" end
            if fdb.visHideNoTarget then extra[#extra + 1] = "無目標藏" end
            if fdb.visHideNoEnemy then extra[#extra + 1] = "無敵目標藏" end
            out[#out + 1] = ("%s=%s/%s%s alpha=%.2f"):format(
                unit, fdb.visibility or "always",
                uf.visGate:IsShown() and "開" or "關",
                #extra > 0 and ("(" .. table.concat(extra, ",") .. ")") or "",
                uf.appliedAlpha or 1)
        end
    end
    return out
end
