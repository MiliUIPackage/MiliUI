------------------------------------------------------------
-- Core/Import.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Import_test.lua
--
-- 做法同 DB_test.lua：DB.lua、Import.lua、Modules/ResourceConditions.lua、Modules/Resources.lua（專精 → 候選資源，
-- 「哪幾個專精顯示這一列」要用）載進自己的環境表，
-- WoW API 全部 stub。這支本身一個全域都不寫。
--
-- 夾具：使用者 Ayije_CDM 存檔（2026-10-01）的縮小版，角色名換成占位字；再加一份合成的設定檔，
-- 把實際存檔沒用到的分支（螢幕座標的資源條／施法條、增益群組裡的光環格、音效覆寫、
-- 輔助技能解鎖、發光、舊版平鋪的資源鍵…）補齊。
--
-- 覆蓋：四條檢視器的位置換算、尺寸／間距／每列上限、文字、字型、淡出、無損刷新與發光、
-- 資源條（顏色、條件規則同形狀而且求值結果一樣、法力百分比、數值文字、位置）、施法條、
-- 自訂群組（目前專精當場對表、其他專精進 pending、登入後 ApplyPending）、自訂光環格、
-- 逐法術覆寫、報告的略過分類、設定檔撞名、沒出現的鍵不動、對照表的優先序。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end
local function eqColor(name, got, r, g, b, a)
    check(name, type(got) == "table" and got.r == r and got.g == g and got.b == b and (got.a or 1) == (a or 1),
          type(got) == "table" and ("%s,%s,%s,%s"):format(tostring(got.r), tostring(got.g), tostring(got.b), tostring(got.a)) or tostring(got))
end
local function list(t) local o = {} for i, v in ipairs(t or {}) do o[i] = tostring(v) end return table.concat(o, ",") end

------------------------------------------------------------
-- WoW API stub
------------------------------------------------------------
local env = setmetatable({}, { __index = _G })
env.UnitName = function() return "角色甲" end
env.GetRealmName = function() return "伺服器" end
env.InCombatLockdown = function() return false end
env.GetSpecialization = function() return 3 end
env.GetSpecializationInfo = function() return 70 end
env.GetLocale = function() return "zhTW" end
env.CreateFrame = function()
    return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end }
end

local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    playerClass = "PALADIN",
    IsSecret = function() return false end,
    Fire = function() end,
    ReportError = function(err) print("ReportError: " .. tostring(err)) end,
}

local function Load(rel)
    local path = here .. "/../" .. rel
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end
Load("Core/DB.lua")
Load("Modules/ResourceConditions.lua")
Load("Modules/Resources.lua")
Load("Core/Import.lua")
local DB, Import, RC = ns.DB, ns.Import, ns.ResCond

local function c(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

------------------------------------------------------------
-- 夾具 1：實際存檔的縮小版（聖騎士角色用的 Default）
------------------------------------------------------------
local REAL = {
    assistEnabled = true, assistFontSize = 10, rotationAssistEnabled = true,
    buffBarApplicationsFontSize = 12, buffBarDurationFontSize = 16, buffBarGrowDirection = "UP",
    buffBarNameFontSize = 16, buffBarTexture = "TukTex", buffCooldownFontSize = 16,
    buffSecondaryOffsetX = -120, sizeBuffSecondary = { w = 40, h = 36 }, countPositionSec = "RIGHT",
    castBarAnchorToResources = true, castBarResourcesSpacing = 2, castBarContainerLocked = true,
    castBarBackgroundTexture = "TukTex", castBarChannelColor = c(1, 0.31, 0.26),
    castBarFontSize = 12, castBarNameOffsetY = 6, castBarShowIcon = true, castBarShowTotalDuration = true,
    castBarTexture = "TukTex", castBarTimerOffsetY = 6, castBarUseClassColor = true,
    chargeFontSize = 12, cooldownFontSize = 16, countFontSize = 12, countOffsetYMain = 0,
    cooldownGroups = {
        [268] = {},
        [269] = { { anchorPoint = "BOTTOM", anchorRelativeTo = "TOP", anchorTarget = "essential",
                    chargeColor = c(1, 1, 1), chargeFontSize = 15, chargeOffsetX = 0, chargeOffsetY = 0,
                    chargePosition = "BOTTOMRIGHT", cooldownColor = c(1, 1, 1), cooldownFontSize = 15,
                    grow = "RIGHT", iconHeight = 40, iconWidth = 46, name = "Group 1",
                    offsetX = 58, offsetY = 157, spacing = 1, spells = { 1249625 } } },
        [270] = { { anchorPoint = "BOTTOM", anchorRelativeTo = "TOPRIGHT", anchorTarget = "essential",
                    chargeFontSize = 15, chargePosition = "BOTTOMRIGHT", cooldownFontSize = 15,
                    grow = "LEFT", iconHeight = 40, iconWidth = 46, name = "Group 1",
                    offsetX = 58, offsetY = 49, spacing = 1, spells = { 115310, 443028, 325197 } } },
    },
    customBuffRegistry = { [774] = { auraFilter = "HELPFUL", hideCooldownText = false, icon = 136081,
                                     kind = "aura", name = "回春術", placeholder = true } },
    ungroupedCustomBuffOrder = {
        [105] = { { afterNative = 0, spellID = 774 } },
        [70]  = { { afterNative = 0, spellID = 774 } },
    },
    defensivesCooldownFontSize = 16, defensivesHideFromViewers = true,
    editModePositions = {
        BuffBarCooldownViewer   = { Default = { point = "BOTTOM", x = 0, y = 500 } },
        BuffIconCooldownViewer  = { Default = { point = "CENTER", x = 3, y = -155 } },
        EssentialCooldownViewer = { Default = { point = "CENTER", x = 0, y = -204 } },
    },
    fadingEnabled = true,
    hideBlizzardCastBar = true, hideCooldownBling = false, maxRowEss = 8,
    pandemicBorderColor = c(1, 0.70196080207824707, 0.1019607931375504), pandemicCustomizationEnabled = true,
    racialsOffsetY = 54,
    resourceBarSettings = {
        General = { Mana = { color = c(0.2, 0.353, 0.639), height = 16 } },
        MONK = { Stagger = { tier3Enabled = true, tier4Enabled = true } },
        PALADIN = { HolyPower = {
            color = c(0.914, 0.678, 0.306),
            conditions = {
                { check = { cmp = ">=", value = 5, var = "powerValue" }, overrides = { color = c(1, 0.38, 0.443) } },
                { check = { cmp = ">=", value = 3, var = "powerValue" }, overrides = { color = c(0.969, 0.514, 1) } },
            },
        } },
        WARLOCK = { SoulShards = { conditions = {
            { check = { cmp = "<", value = 3, var = "powerValue" }, overrides = { color = c(1, 0.341, 0.945) } },
            { check = { value = true, var = "powerFull" }, overrides = { color = c(1, 0.247, 0.282) } },
        } } },
    },
    resourcesManaColor = c(0, 0.56, 1), resourcesBarHeight = 16, resourcesOffsetY = -200,
    resourcesManaPercentage = false,
    sizeUtility = { w = 26, h = 24 },
    textFont = "提示訊息",
    trinketsMode = "defensives", trinketsShowPassive = false,
    ungroupedBuffOverrides = { [105] = { [774] = {} } },
    ungroupedCooldownOverrides = { [266] = { [172] = { cooldownFontSize = 12, showAuraOverlay = false } } },
    utilityYOffset = -4,
}

------------------------------------------------------------
-- 夾具 2：合成的設定檔（補實際存檔沒走到的分支）
------------------------------------------------------------
local SYN = {
    sizeEssRow1 = { w = 50, h = 44 }, sizeEssRow2 = { w = 40, h = 36 }, sizeBuff = { w = 30, h = 30 },
    spacing = 2, maxRowEss = 10, utilityWrap = true, utilityUnlock = true, maxRowUtil = 6,
    utilityXOffset = 12, utilityYOffset = 3,
    buffBarWidth = 250, buffBarHeight = 18, buffBarSpacing = 3, buffBarIconPosition = "HIDDEN",
    buffBarColor = c(0.1, 0.2, 0.3), buffBarShowName = false,
    textFontOutline = "NONE", cooldownColor = c(1, 1, 0), cooldownDecimalThreshold = 2,
    cooldownColorThresholdEnabled = true, cooldownColorThreshold = 4, cooldownColorThresholdColor = c(1, 0, 0),
    chargePosition = "TOPLEFT", chargeOffsetX = 2, chargeOffsetY = -2,
    countPositionMain = "BOTTOM", countOffsetXMain = 1, countOffsetYMain = 3, countColor = c(0, 1, 1),
    utilityCooldownFontSize = 11, utilityChargeFontSize = 13,
    zoomIcons = false, disableCooldownDesat = true, hideGCDSwipe = true, borderSize = 2, borderColor = c(0.5, 0.5, 0.5),
    borderFile = "1 Pixel",
    glowType = "autocast", glowUseCustomColor = true, glowColor = c(0, 1, 0), glowAutocastParticles = 6,
    glowAutocastFrequency = 0.5, glowPixelLines = 99,
    hidePandemicIndicator = true, pandemicCustomizationEnabled = true, pandemicBorderEnabled = true,
    pandemicBorderColorBuffBars = false,
    fadingEnabled = true, fadingTriggerNoTarget = false, fadingTriggerOOC = true, fadingOpacity = 50,
    fadingUtility = false, fadingResources = false,
    resourcesEnabled = true, manaNumberFormat = "km",
    resourceBarSettings = {
        General = { Mana = { displayAsPercent = true, offsetX = 10, offsetY = -100, tagFontSize = 14,
                             tagEnabled = true, barTexture = "Solid", barSpacing = 2, width = 300,
                             -- 法力只在神聖聖騎與暗牧顯示（暗牧預設不顯示 ⇒ 要寫 true；戒律預設顯示 ⇒ 要寫 false）
                             loadMode = "conditional", load = { spec = { [65] = true, [258] = true }, combat = true } } },
        DEMONHUNTER = { DevourerSoulFragments = { color = c(0.1, 0.2, 0.3) },
                        Fury = { loadMode = "never" } },
        MONK = { Stagger = { lightColor = c(0, 1, 0), moderateColor = c(1, 1, 0), heavyColor = c(1, 0, 0),
                             tier1Threshold = 25, tier2Threshold = 70, ceilingPercent = 150,
                             tier3Enabled = true, tier3Threshold = 95, tier3Color = c(0.5, 0, 0.5),
                             tier4Enabled = false, tier4Threshold = 220, tier4Color = c(0, 0.5, 0.5) } },
        ROGUE = { ComboPoints = { chargedColor = c(0, 0, 1), overflowingColor = c(1, 1, 1),
                                  conditions = { { target = 5, check = { op = "and", children = {
                                      { var = "powerValue", cmp = ">=", value = 5 },
                                      { var = "bogus", cmp = ">", value = 1 } } },
                                      overrides = { color = c(1, 0, 0), alpha = 0.5 } },
                                    { check = { var = "powerValue", cmp = "??", value = 1 }, overrides = { color = c(0, 0, 0) } } } } },
        NOPE = { NotAResource = { color = c(1, 1, 1) } },
    },
    castBarWidth = 240, castBarHeight = 24, castBarAnchor = "screen", castBarAnchorPoint = "BOTTOM",
    castBarTargetPoint = "CENTER", castBarOffsetX = 0, castBarOffsetY = -300,
    castBarIconPosition = "RIGHT", castBarShowTotalDuration = false,
    castBarEmpowerStage3Color = c(0.3, 0.3, 0.3), castBarEnabled = false, castBarTexture = "Solid",
    buffGroups = { [70] = { { name = "Procs", anchorTarget = "screen", anchorPoint = "CENTER",
                              grow = "CENTER_H", iconWidth = 32, iconHeight = 32, spacing = 2,
                              offsetX = 100, offsetY = 50, spells = { 223819, 10060 },
                              countFontSize = 20, countPosition = "TOP",
                              spellOverrides = { [223819] = { soundEnabled = true, soundOnShow = "Ding",
                                                              soundOnHide = "Dong", soundOnHideEnabled = false,
                                                              auraGlowEnabled = true } } } } },
    barGroups = { [70] = { { name = "Bars", anchorTarget = "resources", anchorPoint = "BOTTOM",
                             anchorRelativeTo = "TOP", grow = "UP", barWidth = 0, barHeight = 16,
                             spacing = 1, offsetX = 0, offsetY = 2, spells = { 31884 } } } },
    customBuffRegistry = { [10060] = { kind = "aura", auraFilter = "HELPFUL", placeholder = false, hideCooldownText = true },
                           [55555] = { name = "fixed timer", duration = 10 } },
    ungroupedCustomBuffOrder = { [70] = { { spellID = 55555, afterNative = 1 } } },
    ungroupedBuffOverrides = { [70] = { [31884] = { hideCooldown = true } },
                               [66] = { [642] = { soundEnabled = true, soundOnShow = "Ping" } } },
    ungroupedCooldownOverrides = { [70] = { [9001] = { hideCooldown = true, readyGlowEnabled = true } } },
    externalsEnabled = false, pressOverlayEnabled = true, castBarOverridesEnabled = true,
    someFutureKey = 1,
}

-- spellID → cooldownID 的假對照（目前專精 70）
local function resolve70(spellID, kind)
    local map = { [31884] = 5001, [223819] = 5002 }
    return map[spellID]
end

local function Convert(src, extra)
    local opts = { defaults = DB.BuildDefaults().profile, class = "PALADIN", newBar = DB.NewBarTable,
                   specName = function(id) return "spec" .. id end }
    for k, v in pairs(extra or {}) do opts[k] = v end
    return Import.Convert(src, opts)
end

local function HasSkip(R, key, why, cat)
    for _, s in ipairs(R.skipped) do
        if s.key == key and (why == nil or s.why == why) and (cat == nil or s.cat == cat) then return true end
    end
    return false
end

------------------------------------------------------------
-- 1. 實際存檔
------------------------------------------------------------
local P, R = Convert(REAL, { specID = 70, resolve = function() return nil end })
local D = DB.BuildDefaults().profile

-- 位置：四條檢視器
eq("核心 pos.point", P.bars.essential.pos.point, "CENTER")
eq("核心 pos.x（上緣中點，不扣半寬）", P.bars.essential.pos.x, 0)
eq("核心 pos.y", P.bars.essential.pos.y, -204)
eq("核心 grow 置中往下（錨點＝TOP 中點）", P.bars.essential.layout.grow, "CENTER_DOWN")
eq("核心 不錨定", P.bars.essential.anchor, false)
eq("增益圖示 pos", P.bars.buffs.pos.x .. "," .. P.bars.buffs.pos.y, "3,-155")
eq("增益圖示 grow 置中往上（錨點＝BOTTOM）", P.bars.buffs.layout.grow, "CENTER_UP")
eq("增益長條 pos.point", P.bars.buffbars.pos.point, "BOTTOM")
eq("增益長條 pos.y", P.bars.buffbars.pos.y, 500)
eq("增益長條 往上長", P.bars.buffbars.layout.grow, "CENTER_UP")
eq("輔助 錨在核心", P.bars.utility.anchor.to, "essential")
eq("輔助 TOP→BOTTOM", P.bars.utility.anchor.point .. "→" .. P.bars.utility.anchor.relPoint, "TOP→BOTTOM")
eq("輔助 y ＝ −spacing(預設 1) + yOff", P.bars.utility.anchor.y, -5)
eq("輔助 x（沒解鎖 ⇒ 0）", P.bars.utility.anchor.x, 0)

-- 尺寸、文字、字型
eq("輔助 尺寸", P.bars.utility.layout.size.w .. "x" .. P.bars.utility.layout.size.h, "26x24")
eq("核心 每列", P.bars.essential.layout.maxPerRow, 8)
eq("字型", P.theme.font, "提示訊息")
eq("倒數字級", P.theme.cooldownText.size, 16)
eq("充能字級", P.theme.chargeText.size, 12)
eq("層數字級", P.theme.stackText.size, 12)
eq("層數 y", P.theme.stackText.y, 0)
eq("增益圖示 倒數 16 ＝ 主題 ⇒ 不寫、仍跟隨主題", P.bars.buffs.follow.text, true)
eq("增益長條 名稱字級", P.bars.buffbars.bar.nameSize, 16)
eq("增益長條 時間字級", P.bars.buffbars.bar.timeSize, 16)
eq("增益長條 層數字級 12 ＝ 主題 ⇒ 不寫（v6 起沒有 bar.stackSize）", P.bars.buffbars.bar.stackSize, nil)
eq("增益長條 材質（LSM 名照搬）", P.bars.buffbars.bar.texture, "TukTex")

-- 淡出、無損刷新
eq("淡出 開", P.theme.fade.enabled, true)
eq("淡出 預設觸發＝沒目標 ⇒ keepWithTarget", P.theme.fade.keepWithTarget, true)
eq("淡出 keepInCombat 關", P.theme.fade.keepInCombat, false)
eq("淡出 透明度沒存 ⇒ 不動", P.theme.fade.alpha, D.theme.fade.alpha)
eq("無損刷新：pandemicBorderEnabled 沒開 ⇒ 關", P.theme.pandemic.enabled, false)
eqColor("無損刷新 顏色", P.theme.pandemic.color, 1, 0.70196080207824707, 0.1019607931375504, 1)

-- 資源條
eq("資源條 列高（General.Mana 的 height）", P.resources.rowHeight, 16)
eqColor("聖能 顏色", P.resources.colors.HolyPower.color, 0.914, 0.678, 0.306)
eqColor("法力 顏色", P.resources.colors.Mana.color, 0.2, 0.353, 0.639)
eq("聖能 條件 2 條", #P.resources.conditions.HolyPower, 2)
eq("靈魂碎片 條件 powerFull", P.resources.conditions.SoulShards[2].check.var, "powerFull")
eq("條件計數", R.counts.conditions, 4)
do  -- 同形狀：照本插件的求值器跑一次，結果跟規則的意思一樣
    local st = RC.FillState(RC.NewState(), 5, 5, 70)
    local ov = RC.FirstMatch(P.resources.conditions.HolyPower, st)
    eqColor("條件求值：聖能 5 ⇒ 第一條", ov and ov.color, 1, 0.38, 0.443)
    st = RC.FillState(RC.NewState(), 3, 5, 70)
    ov = RC.FirstMatch(P.resources.conditions.HolyPower, st)
    eqColor("條件求值：聖能 3 ⇒ 第二條", ov and ov.color, 0.969, 0.514, 1)
    st = RC.FillState(RC.NewState(), 5, 5, 266)
    ov = RC.FirstMatch(P.resources.conditions.SoulShards, st)
    eqColor("條件求值：碎片滿 ⇒ powerFull", ov and ov.color, 1, 0.247, 0.282)
end
eq("資源條 位置沒存 ⇒ 預設錨定不動", P.resources.anchor.to, "essential")
eq("資源條 數值文字沒存 ⇒ 不動", P.resources.showText, D.resources.showText)
eq("資源條 舊版平鋪鍵不讀（rbs 在）", P.resources.manaPercent, false)
-- 醉仙緩勁第 3／4 段：開關真的匯入（實際存檔只存了「開」，門檻與顏色沒存 ⇒ 留本插件的預設）
eq("醉仙緩勁 第 3 段開關匯入", P.resources.staggerTier3Enabled, true)
eq("醉仙緩勁 第 4 段開關匯入", P.resources.staggerTier4Enabled, true)
eq("醉仙緩勁 第 3 段門檻沒存 ⇒ 預設 90", P.resources.staggerTier3At, 90)
check("醉仙緩勁 tier3 不再記略過", not HasSkip(R, "resourceBarSettings.*.tier3Enabled", "noEquivalent", "resources"))

-- 施法條
eqColor("施法條 引導色", P.castbar.colors.channel, 1, 0.31, 0.26)
eq("施法條 字級", P.castbar.textSize, 12)
eq("施法條 圖示", P.castbar.showIcon, true)
eq("施法條 時間格式（顯示總長）", P.castbar.timeFormat, "remainTotal")
eq("施法條 材質", P.castbar.texture, "TukTex")
eq("施法條 職業色", P.castbar.useClassColor, true)
eq("施法條 隱藏暴雪", P.castbar.hideBlizzard, true)
eq("施法條 位置沒存 ⇒ 預設錨定", P.castbar.anchor.to, "essential")

-- 自訂群組：兩個專精都不是目前專精 ⇒ 全部 pending
eq("群組數", R.counts.groups, 2)
eq("群組 g1 名字撞名 ⇒ 加專精名", P.bars.g1.name, "Group 1 (spec269)")
eq("群組 g2 名字", P.bars.g2.name, "Group 1 (spec270)")
eq("barOrder 接在後面", P.barOrder[5] .. "," .. P.barOrder[6], "g1,g2")
eq("g1 往右長 ⇒ LEFT_UP（BOTTOM 那半）", P.bars.g1.layout.grow, "LEFT_UP")
eq("g1 錨定目標", P.bars.g1.anchor.to, "essential")
-- 第一格左下角在核心上緣中點 + (58,157)；BOTTOMLEFT→TOP 會被排開 ⇒ 換成 LEFT、y 補半格高 20
eq("g1 point 換成中線（不參與排開）", P.bars.g1.anchor.point, "LEFT")
eq("g1 relPoint", P.bars.g1.anchor.relPoint, "TOP")
eq("g1 x", P.bars.g1.anchor.x, 58)
eq("g1 y ＝ 157 + 20", P.bars.g1.anchor.y, 177)
eq("g1 尺寸", P.bars.g1.layout.size.w .. "x" .. P.bars.g1.layout.size.h, "46x40")
eq("g1 間距", P.bars.g1.layout.spacing, 1)
eq("g1 每列不限", P.bars.g1.layout.maxPerRow, 20)
eq("g1 文字 15 ≠ 主題 16 ⇒ 不跟隨", P.bars.g1.follow.text, false)
eq("g1 倒數字級", P.bars.g1.text.cooldownText.size, 15)
eq("g1 充能位置跟主題一樣 ⇒ 不寫", P.bars.g1.text.chargeText.point, nil)
eq("g2 往左長 ⇒ RIGHT_UP", P.bars.g2.layout.grow, "RIGHT_UP")
eq("g2 point", P.bars.g2.anchor.point, "RIGHT")
eq("g2 relPoint", P.bars.g2.anchor.relPoint, "TOPRIGHT")
eq("g2 y ＝ 49 + 20", P.bars.g2.anchor.y, 69)
eq("pending 269 一個群組", R.pending[269] and R.pending[269].groups, 1)
eq("pending 270 三個法術", R.pending[270] and R.pending[270].spells, 3)
eq("pending 270 往左長 ⇒ 清單反過來", list(P.pendingImport[270].groups[1].spells), "325197,443028,115310")
eq("pending 群組 kind", P.pendingImport[269].groups[1].kind, "cooldown")
eq("groupsPending", R.counts.groupsPending, 2)

-- 自訂光環格
eq("光環格 計數（105、70 兩個專精）", R.counts.auras, 2)
local c70 = P.spells[70] and P.spells[70].custom
eq("光環格 70", c70 and c70[1] and c70[1].spellID, 774)
eq("光環格 filter", c70 and c70[1].filter, "HELPFUL")
eq("光環格 placeholder", c70 and c70[1].placeholder, true)
eq("光環格 放增益圖示", c70 and c70[1].bar, "buffs")
eq("光環格 hideCooldownText false ⇒ 不寫覆寫", P.spells[70].overrides["c:1"], nil)

-- 逐法術覆寫：兩個欄位都沒有對應
eq("冷卻覆寫 沒有對得上的欄位 ⇒ 不寫", P.spells[266], nil)
check("覆寫欄位略過（字級）", HasSkip(R, "ungroupedCooldownOverrides.*.cooldownFontSize", "noEquivalent", "overrides"))
check("覆寫欄位略過（aura overlay）", HasSkip(R, "ungroupedCooldownOverrides.*.showAuraOverlay"))
eq("增益覆寫 空表 ⇒ 什麼都沒有", R.counts.overrides, 0)

-- 報告：略過的分類
check("略過：一鍵輔助", HasSkip(R, "assistEnabled", "noEquivalent", "assist"))
check("略過：rotationAssist", HasSkip(R, "rotationAssistEnabled", "noEquivalent", "assist"))
check("略過：防禦技能", HasSkip(R, "defensivesCooldownFontSize", "noEquivalent", "defensives"))
check("略過：種族技能", HasSkip(R, "racialsOffsetY", "noEquivalent", "racials"))
check("略過：飾品", HasSkip(R, "trinketsMode", "noEquivalent", "trinkets"))
check("舊版殘留：資源平鋪鍵", HasSkip(R, "resourcesManaColor", "obsolete", "legacy"))
check("舊版殘留：第二排增益", HasSkip(R, "sizeBuffSecondary", "obsolete", "legacy"))
check("舊版殘留：countPositionSec", HasSkip(R, "countPositionSec", "obsolete"))
check("舊版殘留：施法條舊錨定", HasSkip(R, "castBarAnchorToResources", "obsolete"))
check("外觀細節：施法條文字偏移", HasSkip(R, "castBarNameOffsetY", "noEquivalent", "other"))
check("imported 有 editModePositions", (function() for _, k in ipairs(R.imported) do if k == "editModePositions" then return true end end end)())

-- 沒出現的鍵不動
eq("沒存：核心尺寸", P.bars.essential.layout.size.w, D.bars.essential.layout.size.w)
eq("沒存：間距", P.bars.essential.layout.spacing, D.bars.essential.layout.spacing)
eq("沒存：發光型式", P.theme.glow.proc.type, D.theme.glow.proc.type)
eq("沒存：縮放", P.theme.icon.zoom, D.theme.icon.zoom)
eq("沒存：倒數小數門檻", P.theme.cooldownText.decimalsBelow, D.theme.cooldownText.decimalsBelow)
eq("沒存：自訂格子面板", P.pips.anchor.to, D.pips.anchor.to)
eq("沒存：按鍵文字", P.theme.keybind.enabled, D.theme.keybind.enabled)
eq("沒存：施法條高", P.castbar.height, D.castbar.height)
eq("預設表本身沒被改到", DB.BuildDefaults().profile.theme.font, D.theme.font)

------------------------------------------------------------
-- 2. 登入後對表（ApplyPending）：換到 270 那個專精
------------------------------------------------------------
do
    local map = { [115310] = 7001, [443028] = 7002 }       -- 325197 查不到
    local done, left = Import.ApplyPending(P, 270, function(sid) return map[sid] end)
    eq("ApplyPending 換到 2 筆", done, 2)
    eq("ApplyPending 剩 1 筆", left, 1)
    eq("groupOf 寫進 270", P.spells[270].groupOf[7001], "g2")
    eq("order 照反過來的順序", list(P.spells[270].order.g2), "7002,7001")
    eq("剩下的留在 pending", list(P.pendingImport[270].groups[1].spells), "325197")
    done, left = Import.ApplyPending(P, 270, function(sid) return sid == 325197 and 7003 or nil end)
    eq("第二次換到最後一筆", done, 1)
    eq("order 接在後面", list(P.spells[270].order.g2), "7002,7001,7003")
    eq("270 清掉", P.pendingImport[270], nil)
    Import.ApplyPending(P, 269, function() return 8001 end)
    eq("全部換完 ⇒ pendingImport 整張拿掉", P.pendingImport, nil)
    eq("群組被刪 ⇒ 那筆作廢不報錯", select(1, Import.ApplyPending({ pendingImport = { [1] = { groups = { { bar = "g9", spells = { 1 } } } } } }, 1, function() return 5 end)), 0)
    -- 秘密值／拋錯的 resolve 一律當查不到
    local prof = { bars = { g1 = {} }, pendingImport = { [1] = { groups = { { bar = "g1", kind = "cooldown", spells = { 1 } } } } } }
    local d2 = Import.ApplyPending(prof, 1, function() error("boom") end)
    eq("resolve 拋錯 ⇒ 0", d2, 0)
    d2 = Import.ApplyPending(prof, 1, function() return "x" end)
    eq("resolve 回非數字 ⇒ 0", d2, 0)
end

------------------------------------------------------------
-- 3. 合成的設定檔
------------------------------------------------------------
local S, R2 = Convert(SYN, { specID = 70, resolve = resolve70, class = "MONK" })

-- 尺寸、每列
eq("核心第一列", S.bars.essential.layout.size.w .. "x" .. S.bars.essential.layout.size.h, "50x44")
eq("核心第二列不同 ⇒ row2Size", S.bars.essential.layout.row2Size and S.bars.essential.layout.row2Size.w, 40)
eq("增益圖示尺寸", S.bars.buffs.layout.size.w, 30)
eq("間距套三條圖示", S.bars.essential.layout.spacing .. S.bars.utility.layout.spacing .. S.bars.buffs.layout.spacing, "222")
eq("核心每列", S.bars.essential.layout.maxPerRow, 10)
eq("輔助換列 ⇒ maxRowUtil", S.bars.utility.layout.maxPerRow, 6)
eq("輔助解鎖 ⇒ x", S.bars.utility.anchor.x, 12)
eq("輔助 y ＝ −2 + 3", S.bars.utility.anchor.y, 1)
eq("增益長條 寬", S.bars.buffbars.bar.width, 250)
eq("增益長條 高（bar 與 layout 兩處）", S.bars.buffbars.bar.height .. "/" .. S.bars.buffbars.layout.size.h, "18/18")
eq("增益長條 間距", S.bars.buffbars.layout.spacing, 3)
eq("增益長條 圖示隱藏", S.bars.buffbars.bar.iconSide, "NONE")
eq("增益長條 不顯示名字", S.bars.buffbars.bar.showName, false)
eqColor("增益長條 顏色", S.bars.buffbars.bar.color, 0.1, 0.2, 0.3)
eq("增益長條 沒存方向與位置 ⇒ grow 不動", S.bars.buffbars.layout.grow, D.bars.buffbars.layout.grow)

-- 文字、字型
eq("描邊 NONE ⇒ 空字串", S.theme.outline, "")
eqColor("倒數顏色", S.theme.cooldownText.color, 1, 1, 0)
eq("小數門檻", S.theme.cooldownText.decimalsBelow, 2)
eq("低秒門檻", S.theme.cooldownText.lowBelow, 4)
eq("低秒變色開關（開）", S.theme.cooldownText.lowColorOn, true)
eqColor("低秒顏色", S.theme.cooldownText.lowColor, 1, 0, 0)
eq("充能位置", S.theme.chargeText.point .. S.theme.chargeText.x .. S.theme.chargeText.y, "TOPLEFT2-2")
eq("層數位置", S.theme.stackText.point .. S.theme.stackText.x .. S.theme.stackText.y, "BOTTOM13")
eq("輔助自己的倒數字級", S.bars.utility.text.cooldownText.size, 11)
eq("輔助自己的充能字級", S.bars.utility.text.chargeText.size, 13)
eq("輔助不跟隨主題文字", S.bars.utility.follow.text, false)

-- 圖示、邊框、發光、無損刷新
eq("zoomIcons false ⇒ 0", S.theme.icon.zoom, 0)
eq("冷卻中不去飽和", S.theme.icon.desaturateOnCooldown, false)
eq("隱藏 GCD 轉圈", S.theme.icon.hideGCDSwipe, true)
eq("邊框粗細", S.theme.border.size, 2)
eq("邊框 1 Pixel ⇒ solid", S.theme.border.texture, "solid")
eq("發光型式", S.theme.glow.proc.type, "autocast")
eqColor("發光自訂色", S.theme.glow.proc.color, 0, 1, 0)
eq("autocast 粒子數 ⇒ lines（像素線數不用）", S.theme.glow.proc.lines, 6)
eq("autocast 頻率", S.theme.glow.proc.frequency, 0.5)
eq("無損刷新 三條件都成立 ⇒ 開", S.theme.pandemic.enabled, true)
eq("無損刷新 長條不換色", S.theme.pandemic.bars, false)

-- 淡出：只有脫戰
eq("淡出 只脫戰 ⇒ keepInCombat", S.theme.fade.keepInCombat, true)
eq("淡出 只脫戰 ⇒ 不看目標", S.theme.fade.keepWithTarget, false)
eq("淡出 透明度 50%", S.theme.fade.alpha, 0.5)
eq("淡出 輔助不淡：自己的設定", S.bars.utility.follow.fade, false)
eq("淡出 輔助不淡：關", S.bars.utility.fade.enabled, false)
eq("淡出 資源條不跟核心", S.resources.fadeWithEssential, false)

-- 資源條
eq("法力百分比", S.resources.manaPercent, true)
eq("法力縮寫 km ⇒ k", S.resources.manaAbbrev, "k")
eq("數值文字 開", S.resources.showText, true)
eq("數值文字 字級", S.resources.textSize, 14)
eq("材質 Solid ⇒ solid", S.resources.texture, "solid")
eq("列距", S.resources.rowSpacing, 2)
eq("寬", S.resources.width, 300)
eqColor("噬靈魂碎片改名", S.resources.colors.DevourerFragments.color, 0.1, 0.2, 0.3)
-- 載入條件 → 分專精的開關 rows[specID][key]
local rows = S.resources.rows
eq("魔怒 loadMode never ⇒ 浩劫關掉", rows[577] and rows[577].Fury, false)
eq("魔怒 loadMode never ⇒ 復仇關掉", rows[581] and rows[581].Fury, false)
eq("魔怒 loadMode never ⇒ 噬魂者關掉", rows[1480] and rows[1480].Fury, false)
eq("沒有平面的開關鍵", rows.Fury, nil)
eq("法力 load.spec：神聖聖騎在集合裡、預設就開 ⇒ 不寫", rows[65], nil)
eq("法力 load.spec：暗牧在集合裡、預設關 ⇒ 寫 true", rows[258] and rows[258].Mana, true)
eq("法力 load.spec：戒律不在集合裡、預設開 ⇒ 寫 false", rows[256] and rows[256].Mana, false)
eq("法力 load.spec：增強不在集合裡、預設關 ⇒ 不寫", rows[263], nil)
eq("法力 load.spec：沒有法力的專精不寫", rows[71], nil)
check("載入條件的戰鬥中略過", HasSkip(R2, "resourceBarSettings.*.load.combat", "noEquivalent", "resources"))
check("專精集合不記略過", not HasSkip(R2, "resourceBarSettings.*.load.spec", "noEquivalent", "resources"))
eq("醉仙緩勁 第 3 段", S.resources.staggerTier3Enabled, true)
eq("醉仙緩勁 第 3 段門檻", S.resources.staggerTier3At, 95)
eqColor("醉仙緩勁 第 3 段顏色", S.resources.colors.Stagger.tier3Color, 0.5, 0, 0.5)
eq("醉仙緩勁 第 4 段關", S.resources.staggerTier4Enabled, false)
eq("醉仙緩勁 第 4 段門檻照樣匯入", S.resources.staggerTier4At, 220)
eqColor("醉仙緩勁 第 4 段顏色", S.resources.colors.Stagger.tier4Color, 0, 0.5, 0.5)
do
    -- always：每個專精都開（法力在輸出專精寫 true）；沒存 loadMode 的法力照對方預設 conditional 看 load.spec
    local res = { rows = {} }
    Import.ImportRows(res, "General", "Mana", function() return true end)
    eq("always：暗牧法力寫 true", res.rows[258] and res.rows[258].Mana, true)
    eq("always：神聖聖騎跟預設一樣不寫", res.rows[65], nil)
    local A = Convert({ resourceBarSettings = { General = { Mana = { load = { spec = { [258] = true } } } } } }, { specID = 70 })
    eq("沒存 loadMode 的法力照 conditional：暗牧開", A.resources.rows[258] and A.resources.rows[258].Mana, true)
    eq("沒存 loadMode 的法力照 conditional：神聖聖騎關", A.resources.rows[65] and A.resources.rows[65].Mana, false)
    local B = Convert({ resourceBarSettings = { WARRIOR = { Rage = { load = { spec = { [71] = true } } } } } }, { specID = 70 })
    eq("沒存 loadMode 的其他列照 always：不寫", next(B.resources.rows), nil)
    local C = Convert({ resourceBarSettings = { DRUID = { Rage = { loadMode = "never" } } } }, { specID = 70 })
    check("德魯伊的怒氣（熊形）每個德魯伊專精都關", C.resources.rows[102].Rage == false and C.resources.rows[105].Rage == false
        and C.resources.rows[104].Rage == false and C.resources.rows[103].Rage == false)
    eq("德魯伊的怒氣不影響戰士", C.resources.rows[71], nil)
end
eqColor("醉仙緩勁 輕度＝主色", S.resources.colors.Stagger.color, 0, 1, 0)
eqColor("醉仙緩勁 重度", S.resources.colors.Stagger.heavyColor, 1, 0, 0)
eq("醉仙緩勁 門檻", S.resources.staggerModerateAt .. "/" .. S.resources.staggerHeavyAt, "25/70")
eq("醉仙緩勁 滿條", S.resources.staggerCeiling, 150)
eqColor("連擊點數 充能色", S.resources.colors.ComboPoints.chargedColor, 0, 0, 1)
check("連擊點數 溢出色略過", HasSkip(R2, "resourceBarSettings.*.overflowingColor", "noEquivalent"))
check("不認得的資源略過", HasSkip(R2, "resourceBarSettings.NOPE.NotAResource", "noEquivalent", "resources"))
local cp = S.resources.conditions.ComboPoints
eq("壞規則丟掉、壞葉子丟掉", cp and #cp, 1)
eq("target 帶過來", cp and cp[1].target, 5)
eq("and 只剩一個葉子 ⇒ 攤平", cp and cp[1].check.var, "powerValue")
eq("alpha 帶過來", cp and cp[1].overrides.alpha, 0.5)
-- 位置：螢幕座標 (10,−100)，離核心上緣遠 ⇒ 存 pos
eq("資源條 螢幕座標 ⇒ 不錨定", S.resources.anchor, false)
eq("資源條 pos", S.resources.pos.point .. S.resources.pos.x .. "," .. S.resources.pos.y, "CENTER10,-100")

-- 施法條：螢幕、BOTTOM → CENTER (0, −300)，高 24 ⇒ 中心 y = −300 + 12
eq("施法條 關", S.castbar.enabled, false)
eq("施法條 寬", S.castbar.width, 240)
eq("施法條 螢幕 ⇒ 不錨定", S.castbar.anchor, false)
eq("施法條 pos.point ＝ targetPoint", S.castbar.pos.point, "CENTER")
eq("施法條 pos.y 換算成中心", S.castbar.pos.y, -288)
eq("施法條 圖示右", S.castbar.iconSide, "RIGHT")
eq("施法條 不顯示總長", S.castbar.timeFormat, "remain")
eqColor("施法條 蓄力三階", S.castbar.colors.empowerStage3, 0.3, 0.3, 0.3)
eq("施法條 材質 Solid", S.castbar.texture, "solid")

-- 群組：目前專精（70）當場對表
local gp, gb
for _, k in ipairs(S.barOrder) do
    local b = S.bars[k]
    if b.name == "Procs" then gp = k elseif b.name == "Bars" then gb = k end
end
check("增益群組建出來", gp ~= nil)
check("長條群組建出來", gb ~= nil)
eq("長條群組 kind", gb and S.bars[gb].kind, "bars")
eq("CENTER_H ⇒ CENTER_DOWN", gp and S.bars[gp].layout.grow, "CENTER_DOWN")
-- 螢幕：容器（32×32）中心在 (100,50)、第一格 CENTER 貼容器 CENTER ⇒ 外框 TOP 中點在 (100, 66)
eq("CENTER_H 螢幕 pos.x", gp and S.bars[gp].pos.x, 100)
eq("CENTER_H 螢幕 pos.y", gp and S.bars[gp].pos.y, 66)
eq("群組自己的層數字級", gp and S.bars[gp].text.stackText.size, 20)
eq("群組自己的層數位置", gp and S.bars[gp].text.stackText.point, "TOP")
eq("目前專精當場對表：groupOf", S.spells[70].groupOf[5002], gp)
eq("長條群組法術也對到", S.spells[70].groupOf[5001], gb)
eq("目前專精全部對到、光環格不進 pending", S.pendingImport and S.pendingImport[70], nil)
eq("長條群組錨在資源條", gb and S.bars[gb].anchor.to, "resources")
eq("report.pending 只剩別專精（66）的覆寫", R2.pending[66] and R2.pending[66].overrides, 1)
eq("report.pending 沒有 70", R2.pending[70], nil)

-- 光環格：放在增益群組裡的 10060 ⇒ 進那個群組；非光環登記 ⇒ 略過
local list70 = S.spells[70].custom
eq("群組裡的光環格", list70 and list70[1] and list70[1].bar, gp)
eq("光環格 placeholder false", list70 and list70[1].placeholder, false)
eq("光環格 placeholder false ⇒ 增益不在時留空位", S.spells[70].overrides["c:1"] and S.spells[70].overrides["c:1"].emptyMode, "blank")
eq("光環格 hideCooldownText ⇒ c:1 覆寫", S.spells[70].overrides["c:1"] and S.spells[70].overrides["c:1"].hideCooldownText, true)
check("固定秒數的自訂增益略過", HasSkip(R2, "customBuffRegistry.55555", "noEquivalent", "customBuffs"))

-- 覆寫
eq("冷卻覆寫 hideCooldown ⇒ hideCooldownText", S.spells[70].overrides[9001].hideCooldownText, true)
check("readyGlowEnabled 沒有對應", HasSkip(R2, "ungroupedCooldownOverrides.*.readyGlowEnabled", "noEquivalent", "overrides"))
eq("增益覆寫 目前專精對到", S.spells[70].overrides[5001] and S.spells[70].overrides[5001].hideCooldownText, true)
eq("群組裡的覆寫：出現音效", S.spells[70].overrides[5002] and S.spells[70].overrides[5002].gainSound, "Ding")
eq("群組裡的覆寫：消失音效關 ⇒ 不帶", S.spells[70].overrides[5002] and S.spells[70].overrides[5002].loseSound, nil)
check("auraGlowEnabled 沒有對應", HasSkip(R2, "buffGroups.spellOverrides.*.auraGlowEnabled"))
-- 別的專精的增益覆寫進 pending
local S2, R3 = Convert({ ungroupedBuffOverrides = SYN.ungroupedBuffOverrides }, { specID = 70, resolve = resolve70 })
eq("別專精的增益覆寫 ⇒ pending", S2.pendingImport and S2.pendingImport[66] and S2.pendingImport[66].overrides[1].fields.gainSound, "Ping")
eq("overridesPending", R3.counts.overridesPending, 1)
-- 增益群組的逐法術發光（spellRegistry）⇒ 生效發光；光環格不收、邊框色沒有對應
do
    local S4, R4 = Convert({
        customBuffRegistry = { [10060] = { kind = "aura", auraFilter = "HELPFUL" } },
        ungroupedCustomBuffOrder = { [70] = { { spellID = 10060 } } },
        spellRegistry = {
            [70] = { glowEnabled = { [31884] = true, [10060] = true, [223819] = false },
                     glowColors = { [31884] = { r = 1, g = 0, b = 0 } },
                     colors = { [31884] = c(0, 1, 0) } },
            [66] = { glowEnabled = { [642] = true } },
        },
    }, { specID = 70, resolve = resolve70 })
    local o = S4.spells[70] and S4.spells[70].overrides[5001]
    eq("生效發光 目前專精對到", o and o.activeGlow, true)
    eq("生效發光 顏色不帶（顏色是條層的）", o and o.activeGlowColor, nil)
    eq("glowEnabled false 不收", S4.spells[70].overrides[5002], nil)
    eq("別專精 ⇒ pending", S4.pendingImport and S4.pendingImport[66] and S4.pendingImport[66].overrides[1].fields.activeGlow, true)
    eq("光環格直接寫在 c:1", S4.spells[70].overrides["c:1"] and S4.spells[70].overrides["c:1"].activeGlow, true)
    eq("光環格沒有顏色就不寫顏色", S4.spells[70].overrides["c:1"] and S4.spells[70].overrides["c:1"].activeGlowColor, nil)
    check("邊框色沒有對應", HasSkip(R4, "spellRegistry.*.colors", "noEquivalent", "overrides"))
    check("spellRegistry 不再整張略過", not HasSkip(R4, "spellRegistry"))
end

-- 報告
check("略過：外部防禦", HasSkip(R2, "externalsEnabled", "noEquivalent", "externals"))
check("略過：按下效果", HasSkip(R2, "pressOverlayEnabled", "noEquivalent", "pressOverlay"))
check("略過：施法條逐法術", HasSkip(R2, "castBarOverridesEnabled", "noEquivalent", "castbarOverrides"))
check("不認得的鍵 ⇒ unknown", HasSkip(R2, "someFutureKey", "unknown"))

------------------------------------------------------------
-- 4. 淡出的其他組合、舊版平鋪的資源鍵、輔助沒解鎖
------------------------------------------------------------
local F = Convert({ fadingEnabled = true, fadingTriggerOOC = true })
eq("沒目標＋脫戰 ⇒ 取 keepInCombat（近似）", F.theme.fade.keepInCombat, true)
eq("沒目標＋脫戰 ⇒ keepWithTarget 關", F.theme.fade.keepWithTarget, false)
F = Convert({ fadingEnabled = false })
eq("淡出關", F.theme.fade.enabled, false)
F = Convert({ fadingEnabled = true, fadingTriggerNoTarget = false, fadingTriggerMounted = true })
eq("只有騎乘 ⇒ whenMounted", F.theme.fade.whenMounted, true)
eq("只有騎乘 ⇒ 開", F.theme.fade.enabled, true)
F = Convert({ fadingEnabled = true, fadingTriggerNoTarget = false })
eq("三個觸發都關 ⇒ 不淡", F.theme.fade.enabled, false)

local LG, RL = Convert({ resourcesManaColor = c(0, 0.56, 1), resourcesBarHeight = 12, resourcesManaPercentage = true,
                         resourcesStaggerHeavyColor = c(1, 0, 0) })
eqColor("舊版平鋪：法力色", LG.resources.colors.Mana.color, 0, 0.56, 1)
eq("舊版平鋪：列高", LG.resources.rowHeight, 12)
eq("舊版平鋪：法力百分比", LG.resources.manaPercent, true)
eqColor("舊版平鋪：醉仙緩勁重度", LG.resources.colors.Stagger.heavyColor, 1, 0, 0)
eq("舊版平鋪：不算略過", #RL.skipped, 0)

local U = Convert({ utilityXOffset = 30, utilityYOffset = 0 })
eq("輔助沒解鎖 ⇒ x 不生效", U.bars.utility.anchor.x, 0)

-- 資源條貼在核心上方 2px（螢幕座標，跟核心同一條中線）⇒ 錨定、y = 差距
local RS = Convert({ editModePositions = { EssentialCooldownViewer = { Default = { point = "CENTER", x = 0, y = -204 } } },
                     resourceBarSettings = { General = { Mana = { offsetX = 0, offsetY = -202 } } } })
eq("資源條貼著核心 ⇒ 錨定", RS.resources.anchor.to, "essential")
eq("資源條 y ＝ 差距", RS.resources.anchor.y, 2)
RS = Convert({ resourceBarSettings = { WARRIOR = { Rage = { anchorTo = "essential", anchorPoint = "BOTTOM",
                                                             anchorTargetPoint = "TOP", offsetX = 0, offsetY = 5 } } } })
eq("資源條 anchorTo essential", RS.resources.anchor.to .. RS.resources.anchor.y, "essential5")

-- 施法條錨在核心、BOTTOM→TOP ⇒ 換成 CENTER、y 補半高（不讓排開把它推到資源條外面）
local CB = Convert({ castBarAnchor = "essential", castBarOffsetY = 40, castBarHeight = 20 })
eq("施法條錨核心 point", CB.castbar.anchor.point, "CENTER")
eq("施法條錨核心 y", CB.castbar.anchor.y, 50)
CB = Convert({ castBarOffsetY = 3 })
eq("施法條跟著資源條（預設模式）⇒ 錨核心上方、交給排開", CB.castbar.anchor.point .. CB.castbar.anchor.y, "BOTTOM3")

-- 群組：往下長、螢幕；錨到玩家框（不支援）
local placement = Import.GroupPlacement({ grow = "DOWN", anchorPoint = "TOPLEFT", anchorTarget = "screen",
                                          iconWidth = 30, iconHeight = 30, offsetX = 0, offsetY = 0 }, "icons")
eq("往下長 ⇒ 一列一格", placement.maxPerRow, 1)
eq("往下長 grow", placement.grow, "LEFT_DOWN")
-- 容器 30×30 中心在 (0,0) ⇒ 容器 TOPLEFT 在 (−15, 15)；第一格 TOPLEFT 貼那裡 ⇒ 外框 TOPLEFT 同一點
eq("往下長 pos.x", placement.pos.x, -15)
eq("往下長 pos.y", placement.pos.y, 15)
placement = Import.GroupPlacement({ grow = "RIGHT", anchorTarget = "playerFrame" }, "icons")
eq("錨玩家框 ⇒ 螢幕中央＋近似", placement.pos.x .. "," .. tostring(placement.approx ~= nil), "0,true")
placement = Import.GroupPlacement({ grow = "RIGHT", anchorPoint = "LEFT", anchorRelativeTo = "RIGHT",
                                    anchorTarget = "utility", offsetX = 4, offsetY = 0, iconWidth = 20, iconHeight = 20 }, "icons")
eq("錨在輔助右側 ⇒ 不換點（左右向照舊）", placement.anchor.point .. "→" .. placement.anchor.relPoint, "TOPLEFT→RIGHT")
eq("錨在輔助右側 y 補半格", placement.anchor.y, 10)

------------------------------------------------------------
-- 5. 對照表的優先序
------------------------------------------------------------
local resolve = Import.BuildResolver({
    { cooldownID = 1, kind = "buff",     placed = true,  spells = { 100 } },
    { cooldownID = 2, kind = "cooldown", placed = false, spells = { 100 } },
    { cooldownID = 3, kind = "cooldown", placed = true,  spells = { 100, 200 } },
    { cooldownID = 4, kind = "buff",     placed = false, spells = { 300 } },
    { cooldownID = 5, kind = "cooldown", placed = true,  spells = { 300 } },
})
eq("同種類、在檢視器上", resolve(100, "cooldown"), 3)
eq("增益要增益", resolve(100, "buff"), 1)
eq("同種類沒上檢視器 < 別種類在檢視器上", resolve(300, "buff"), 5)
eq("查不到", resolve(999, "cooldown"), nil)

------------------------------------------------------------
-- 6. 取名：撞名加序號、重新匯入沿用上次的名字
------------------------------------------------------------
local fmt = function(n) return "Ayije：" .. n end
local plan = Import.PlanNames({ "Default", "武僧" }, { Default = {}, ["Ayije：Default"] = {} }, nil, fmt, "Default")
eq("撞名加序號", plan.Default, "Ayije：Default (2)")
eq("不撞名照原樣", plan["武僧"], "Ayije：武僧")
plan = Import.PlanNames({ "Default", "武僧" }, { Default = {}, ["Ayije：Default (2)"] = {} },
                        { Default = "Ayije：Default (2)" }, fmt, "Default")
eq("重新匯入：覆蓋上次那份", plan.Default, "Ayije：Default (2)")
eq("重新匯入：新的照常取名", plan["武僧"], "Ayije：武僧")
plan = Import.PlanNames({ "A", "B" }, { Default = {} }, { A = "Default", B = "X" }, fmt, "Default")
eq("上次的對照指到預設設定檔 ⇒ 不覆蓋", plan.A, "Ayije：A")
eq("上次的對照沿用", plan.B, "X")
plan = Import.PlanNames({ "A", "B" }, {}, { A = "X", B = "X" }, fmt)
eq("兩個原名指到同一份 ⇒ 只給第一個", plan.A .. "|" .. plan.B, "X|Ayije：B")

------------------------------------------------------------
-- 7. 摘要文字
------------------------------------------------------------
local lines = Import.SummaryLines({ profiles = 2, groups = 3, groupsPending = 2, auras = 1, overrides = 4,
                                    cats = { "trinkets", "assist" }, other = 5 }, "Ayije：Default")
eq("摘要行數（含飾品提示）", #lines, 5)
check("摘要第一行有設定檔名", lines[1]:find("Ayije：Default", 1, true) ~= nil)
do
    -- 對方勾了「用暴雪的施法條圖」⇒ 我們的「暴雪施法條」；沒勾照它的材質名
    local a = Import.Convert({ castBarUseAtlasTextures = true, castBarTexture = "Solid" }, {})
    eq("施法條 暴雪圖集 ⇒ blizzard", a.castbar and a.castbar.texture, "blizzard")
    local b = Import.Convert({ castBarUseAtlasTextures = false, castBarTexture = "TukTex" }, {})
    eq("施法條 沒勾圖集 ⇒ 照材質名", b.castbar and b.castbar.texture, "TukTex")
end
eq("Convert 收 nil 不報錯", type(select(2, Import.Convert(nil, {}))), "table")
do
    -- 冷卻低秒變色：開關跟秒數分兩欄寫（lowColorOn＋lowBelow）；關掉的也帶秒數，不再寫 lowBelow = 0
    local a = Import.Convert({ cooldownColorThresholdEnabled = false, cooldownColorThreshold = 6 }, {})
    local ct = a.theme.cooldownText
    check("對方關掉 ⇒ 開關關、秒數照對方的", ct.lowColorOn == false and ct.lowBelow == 6)
    local b = Import.Convert({ cooldownColorThresholdEnabled = false }, {})
    check("對方關掉、沒秒數 ⇒ 開關關、秒數 5", b.theme.cooldownText.lowColorOn == false and b.theme.cooldownText.lowBelow == 5)
    local c = Import.Convert({}, {})
    check("對方沒這幾欄 ⇒ 不寫", c.theme.cooldownText.lowColorOn == nil and c.theme.cooldownText.lowBelow == nil)
end

print(("Import_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
