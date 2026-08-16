------------------------------------------------------------
-- SavedVariables：MiliUI_UnitFrame_DB
-- 單一帳號設定檔。預設值轉譯自 MiliUI/Config/Stuf.lua（使用者調好的 Stuf 樣式），
-- 邊框改為全域 1px 細框。
--
-- 座標語意：
--   units.<key>.frame.x/y = 框架「中心」相對 UIParent 中心的偏移（解析度無關）
--   元件 x/y             = 相對單位框 TOPLEFT 的偏移（沿用 Stuf 語意）
--
-- 合併規則（堵死 Stuf 的 boolean 陷阱）：
--   * defaults 每個 boolean 都明寫 true/false，一律正向 enabled（廢除 hide）
--   * 使用者值只補 nil、永不覆蓋
------------------------------------------------------------
local _, ns = ...

ns.DB = {}
local DB = ns.DB

------------------------------------------------------------
-- 共用小工具
------------------------------------------------------------
local function black(a) return { r = 0, g = 0, b = 0, a = a or 1 } end
local function white(a) return { r = 1, g = 1, b = 1, a = a or 1 } end

-- 標準文字元件預設
local function textDef(o)
    o.enabled  = o.enabled ~= false
    o.size     = o.size or 12
    o.flags    = o.flags or "OUTLINE"
    o.justifyH = o.justifyH or "LEFT"
    o.justifyV = o.justifyV or "TOP"
    o.level    = o.level or 5
    o.color    = o.color or white(1)
    return o
end

-- 大框（player/target 200×50）的 castbar 預設
-- own = 自己的施法條：單一顏色、不畫「不可打斷」的灰（Stuf 也是這樣，敵方才標示）
local function bigCastbar(own)
    return {
        enabled = true, x = 0, y = 0, w = 200, h = 52, level = 6,
        bg = black(0.8), timeFormat = "elapsedTotal",
        showInterruptState = not own,   -- 自己的施法不套「不可打斷灰」也不畫盾牌
        showCompleteFlash = true, fadeTime = 0.5, interruptHold = 0.4,
        showShield = not own, shieldStyle = "blizzard", shieldScale = own and 1.2 or 1.4, shieldOffsetX = 0, shieldOffsetY = 0,
        spell = { x = 34, y = -2, w = 166, h = 50, size = 12, flags = "OUTLINE",
                  justifyH = "LEFT", justifyV = "MIDDLE", color = white(1) },
        time  = { x = -2, y = -35, w = 200, h = 12, size = 12, flags = "OUTLINE",
                  justifyH = "CENTER", justifyV = "MIDDLE", color = white(1) },
        icon  = { x = 10, y = -17, w = 20, h = 20 },
    }
end

------------------------------------------------------------
-- 預設值本體
------------------------------------------------------------
function DB.BuildDefaults()
    return {
        schemaVersion = ns.DB_VERSION,

        global = {
            barTexture  = "tuktex",
            font        = "DEFAULT",
            borderSize  = 1,
            borderColor = black(1),
            numberFormat = "auto",       -- auto | wan | km | raw（見 Tags.NumberMode）
            percentDecimals = 0,
            previewBossDisplayID = 131474,   -- 預覽敵對單位的示範模型（薩拉塔斯 12.x 形態；117121 = TWW 形態）
            strata      = "LOW",
            smoothBars  = true,
            showTooltip = true,          -- 滑鼠移到單位框顯示提示
            tooltipHideInCombat = false, -- 戰鬥中不顯示提示
            colors = {
                reaction = {
                    [1] = { r = 1, g = 0, b = 0 },     [2] = { r = 0.8, g = 0, b = 0 },
                    [3] = { r = 1, g = 0.3, b = 0 },   [4] = { r = 1, g = 1, b = 0 },
                    [5] = { r = 0.4, g = 0.8, b = 0.2 },[6] = { r = 0, g = 0.9, b = 0 },
                    [7] = { r = 0, g = 0.7, b = 0 },   [8] = { r = 0, g = 0.5, b = 0 },
                    [9] = { r = 0.8, g = 1, b = 0.8 }, [10] = { r = 1, g = 0.8, b = 0.8 },
                },
                power = {
                    [0] = { r = 0.2, g = 0.5, b = 1 },     -- 法力藍（其餘讀 PowerBarColor）
                },
                hpGreen = { r = 0, g = 0.5, b = 0, a = 1 },
                hpRed   = { r = 0.5, g = 0, b = 0, a = 1 },
                gray    = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 },
                bg      = black(0.4),
                shadow  = black(0.9),
                cast    = { r = 1, g = 0.7, b = 0 },
                channel = { r = 0, g = 1, b = 0 },
                complete = { r = 1, g = 1, b = 0 },
                fail    = { r = 1, g = 0, b = 0 },
                notInterruptible = { r = 0.53, g = 0.53, b = 0.53 },
            },
            classification = {
                worldboss = " 首領", rareelite = " 稀有精英",
                elite = " 精英", rare = " 稀有", normal = "", unknown = "??",
            },
        },

        units = {
            ------------------------------------------------------------
            player = {
                enabled = true,
                frame = { x = -300, y = -225, w = 200, h = 50 },
                elements = {
                    -- 層級嚴格遞增：mp 條 0 / mp 框 1 / 血條背景 2 / 3D 頭像 3（去背）/ 血條前景 4
                    -- （背景若跟 mp 框同層，mp 的黑框會浮上來透過半透明前景露出）
                    portrait = { enabled = true, x = 0, y = 0, w = 200, h = 50, mode = "3d",
                                 bg = { r = 0.165, g = 0.165, b = 0.165, a = 0 }, level = 3,
                                 zoom = 1, rotation = -35,     -- 側身（度）
                                 modelOffsetX = 0.1, modelOffsetY = 0,    -- 設定面板顯示 ×100
                                 fallback2D = false },
                    hpbar = { enabled = true, x = 0, y = 0, w = 200, h = 50, level = 4, bgLevel = 2, lossAlpha = 0.55,
                              colorMethod = "class", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.7, bgAlpha = 1, border = true,
                              showHealPrediction = true, showAbsorb = true,
                              healPredictionFollowBar = false, healPredictionColor = { r = 1, g = 1, b = 1, a = 0.25 },
                              absorbColor = { r = 0.6, g = 0.85, b = 1, a = 0.7 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.15, b = 0.15, a = 0.7 } },
                    mpbar = { enabled = true, x = 8, y = -8, w = 200, h = 50, level = 0,
                              colorMethod = "power", bgColorMethod = "powerdark",
                              barAlpha = 1, bgAlpha = 1, border = true },
                    classpower = { enabled = true, x = 8, y = -14, totalw = 200, h = 6,
                                   spacing = 1, rowSpacing = 2, level = 5,
                                   barAlpha = 1, showText = false,
                                   resources = {} },   -- [資源key] = false 表示關掉
                    manabar = { enabled = true, x = 63, y = -37, w = 127, h = 3, level = 6,
                                color = { r = 0.3, g = 0.3, b = 1, a = 1 }, bgAlpha = 0.4 },
                    texts = {
                        textDef{ pattern = "[name]",   x = 3,   y = -3,  w = 200, h = 50, size = 15 },
                        textDef{ pattern = "[level]",  x = 3,   y = -21, w = 140, h = 12 },
                        textDef{ pattern = "[curhp] || ", x = -42, y = -2, w = 200, h = 50, size = 10,
                                 justifyH = "RIGHT", justifyV = "MIDDLE",
                                 color = { r = 0.851, g = 0.851, b = 0.851, a = 1 } },
                        textDef{ pattern = "[curmp]/[maxmp]", x = 8, y = -10, w = 200, h = 50,
                                 justifyH = "CENTER", justifyV = "BOTTOM", level = 11 },
                        textDef{ pattern = "[percmp]%", x = 10, y = -48, w = 200, h = 10, size = 10,
                                 justifyH = "RIGHT", justifyV = "BOTTOM", level = 11 },
                        textDef{ pattern = "[gray_if_dead:死亡][gray_if_ghost:靈魂]",
                                 x = 0, y = 3, w = 200, h = 50, size = 14,
                                 justifyH = "CENTER", justifyV = "BOTTOM" },
                        textDef{ pattern = "[perchp]%", x = -2, y = -2, w = 200, h = 50, size = 13,
                                 justifyH = "RIGHT", justifyV = "MIDDLE" },
                    },
                    castbar = bigCastbar(true),
                    buffs  = { enabled = false, x = 0, y = -52, w = 17, h = 17,
                               maxCount = 32, perRow = 16, growth = "LRTB", spacing = 1,
                               showStack = true, stackSize = 10,
                               durationText = true, durationThreshold = 60 },
                    debuffs = { enabled = false, x = 0, y = -52, w = 17, h = 17,
                                maxCount = 40, perRow = 16, growth = "LRTB", spacing = 1,
                                showStack = true, stackSize = 10,
                                durationText = true, durationThreshold = 60 },
                    icons = { enabled = true,
                              raidtarget = { enabled = true,  x = 84,  y = 10, w = 20, h = 20, level = 5 },
                              status     = { enabled = true,  x = -8,  y = 10, w = 14, h = 14, level = 10 },
                              leader     = { enabled = true,  x = 7,   y = 10, w = 12, h = 12, level = 10 },
                              pvp        = { enabled = false, x = -15, y = -12, w = 28, h = 28, level = 10 } },
                },
            },

            ------------------------------------------------------------
            target = {
                enabled = true,
                frame = { x = 300, y = -225, w = 200, h = 50 },
                elements = {
                    -- 層級嚴格遞增：mp 條 0 / mp 框 1 / 血條背景 2 / 3D 頭像 3（去背）/ 血條前景 4
                    -- （背景若跟 mp 框同層，mp 的黑框會浮上來透過半透明前景露出）
                    portrait = { enabled = true, x = 0, y = 0, w = 200, h = 50, mode = "3d",
                                 bg = { r = 0.165, g = 0.165, b = 0.165, a = 0 }, level = 3,
                                 zoom = 1, rotation = -25,     -- 側身（度）
                                 modelOffsetX = 0.1, modelOffsetY = 0,    -- 側身後模型會偏左，往右推回來
                                 fallback2D = false },   -- 副本小怪 3D 取不到時是否退 2D
                    hpbar = { enabled = true, x = 0, y = 0, w = 200, h = 50, level = 4, bgLevel = 2, lossAlpha = 0.55,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.7, bgAlpha = 1, border = true,
                              showHealPrediction = true, showAbsorb = true,
                              healPredictionFollowBar = false, healPredictionColor = { r = 1, g = 1, b = 1, a = 0.25 },
                              absorbColor = { r = 0.6, g = 0.85, b = 1, a = 0.7 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.15, b = 0.15, a = 0.7 } },
                    mpbar = { enabled = true, x = -8, y = -8, w = 200, h = 50, level = 0,
                              colorMethod = "power", bgColorMethod = "powerdark",
                              barAlpha = 1, bgAlpha = 1, border = true },
                    texts = {
                        textDef{ pattern = "[name]",   x = 3, y = -3,  w = 200, h = 50, size = 15 },
                        textDef{ pattern = "[difficulty:level][difficulty:classification]",
                                 x = 3, y = -21, w = 200, h = 14 },
                        textDef{ pattern = "[curhp] || ", x = -42, y = -2, w = 200, h = 50, size = 10,
                                 justifyH = "RIGHT", justifyV = "MIDDLE",
                                 color = { r = 0.851, g = 0.851, b = 0.851, a = 1 } },
                        textDef{ pattern = "[curmp]/[maxmp]", x = -8, y = -10, w = 200, h = 50,
                                 justifyH = "CENTER", justifyV = "BOTTOM", level = 11 },
                        textDef{ pattern = "[percmp]%", x = 0, y = -48, w = 200, h = 10, size = 10,
                                 justifyH = "RIGHT", justifyV = "BOTTOM", level = 11 },
                        textDef{ pattern = "[gray_if_oor:超出距離 ][gray_if_tapped:無獎勵目標 ][gray_if_offline:離線 ][gray_if_dead:死亡 ][gray_if_ghost:鬼魂 ]",
                                 x = 0, y = 3, w = 200, h = 50, size = 14,
                                 justifyH = "CENTER", justifyV = "BOTTOM", level = 10 },
                        textDef{ pattern = "[perchp]%", x = -2, y = -2, w = 200, h = 50, size = 13,
                                 justifyH = "RIGHT", justifyV = "MIDDLE" },
                        textDef{ pattern = "[class_if_pc:race][class_if_pc:class][class_if_npc:creaturetype]",
                                 x = 3, y = -16, w = 195, h = 50, size = 10, justifyV = "MIDDLE",
                                 color = { r = 0.984, g = 1, b = 0.953, a = 0.861 } },
                    },
                    castbar = bigCastbar(),
                    buffs  = { enabled = true, x = -10, y = -62, w = 25, h = 25,
                               maxCount = 16, perRow = 8, growth = "LRTB", spacing = 1,
                               showStack = true, stackSize = 10,
                               durationText = true, durationThreshold = 60 },
                    debuffs = { enabled = true, x = 0, y = 8, w = 25, h = 25,
                                maxCount = 16, perRow = 8, growth = "LRBT", spacing = 1,
                                showStack = true, stackSize = 10,
                                durationText = true, durationThreshold = 60 },
                    icons = { enabled = true,
                              raidtarget = { enabled = true,  x = 84, y = 10, w = 20, h = 20, level = 5 },
                              status     = { enabled = true,  x = -8, y = 10, w = 14, h = 14, level = 10 },
                              leader     = { enabled = true,  x = 7,  y = 10, w = 12, h = 12, level = 10 },
                              pvp        = { enabled = false, x = 176, y = -12, w = 28, h = 28, level = 10 } },
                },
            },

            ------------------------------------------------------------
            targettarget = {
                enabled = true,
                frame = { x = 470, y = -214, w = 120, h = 28 },
                elements = {
                    hpbar = { enabled = true, x = 0, y = 0, w = 120, h = 20, level = 4,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.4, bgAlpha = 1, border = true,
                              showHealPrediction = false, showAbsorb = false },
                    mpbar = { enabled = true, x = 0, y = -20, w = 120, h = 10, level = 0,
                              colorMethod = "power", bgColorMethod = "powerdark",
                              barAlpha = 0.4, bgAlpha = 0.6, border = true },
                    texts = {
                        textDef{ pattern = "[name]", x = 0, y = 1, w = 120, h = 20,
                                 justifyH = "CENTER", justifyV = "MIDDLE" },
                        textDef{ pattern = "[perchp]%", x = 122, y = -2, w = 60, h = 10,
                                 justifyH = "LEFT", justifyV = "TOP" },
                    },
                    buffs  = { enabled = true, x = 0, y = -32, w = 20, h = 20,
                               maxCount = 12, perRow = 6, growth = "LRTB", spacing = 1,
                               showStack = true, stackSize = 10,
                               durationText = false, durationThreshold = 60 },
                    debuffs = { enabled = true, x = 0, y = 5, w = 20, h = 20,
                                maxCount = 12, perRow = 6, growth = "LRBT", spacing = 1,
                                showStack = true, stackSize = 10,
                                durationText = false, durationThreshold = 60 },
                    icons = { enabled = true,
                              raidtarget = { enabled = true, x = 54, y = 10, w = 15, h = 15, level = 5 } },
                },
            },

            ------------------------------------------------------------
            focus = {
                enabled = true,
                frame = { x = 260, y = -115, w = 120, h = 30 },
                elements = {
                    hpbar = { enabled = true, x = 0, y = 0, w = 120, h = 20, level = 5,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.4, bgAlpha = 1, border = true,      -- 跟目標框同款（0.4）
                              showHealPrediction = false, showAbsorb = false },
                    mpbar = { enabled = true, x = 0, y = -20, w = 120, h = 10, level = 5,
                              colorMethod = "power", bgColorMethod = "powerdark",
                              barAlpha = 1, bgAlpha = 1, border = true },
                    texts = {
                        textDef{ pattern = "[name]", x = 0, y = -4, w = 120, h = 12,
                                 justifyH = "CENTER", justifyV = "TOP" },
                        textDef{ pattern = "[perchp]%", x = 44, y = 6, w = 120, h = 10, size = 11,
                                 justifyH = "CENTER", justifyV = "MIDDLE", level = 6 },
                        textDef{ pattern = "[curmp]/[maxmp]", x = 0, y = -21, w = 120, h = 10,
                                 size = 10, justifyH = "CENTER", justifyV = "MIDDLE", level = 6 },
                    },
                    castbar = {
                        enabled = true, x = -20, y = 20, w = 160, h = 10, level = 7, timeFormat = "elapsedTotal", showInterruptState = true, showCompleteFlash = true, fadeTime = 0.5, interruptHold = 0.4, showShield = true, shieldStyle = "blizzard", shieldScale = 1.2, shieldOffsetX = 0, shieldOffsetY = 0,
                        bg = black(1), border = true,
                        spell = { x = 12, y = 7, w = 160, h = 10, size = 10, flags = "OUTLINE",
                                  justifyH = "LEFT", justifyV = "TOP", color = white(1) },
                        time  = { x = 0, y = 5, w = 160, h = 10, size = 8, flags = "OUTLINE",
                                  justifyH = "RIGHT", justifyV = "TOP", color = white(1) },
                        icon  = { x = 0, y = 0, w = 10, h = 10 },
                    },
                    icons = { enabled = true,
                              raidtarget = { enabled = true, x = 52, y = 12, w = 16, h = 16, level = 6 } },
                },
            },

            ------------------------------------------------------------
            focustarget = {
                enabled = true,
                frame = { x = 360, y = -115, w = 70, h = 30 },
                elements = {
                    hpbar = { enabled = true, x = 0, y = 0, w = 70, h = 20, level = 4,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.4, bgAlpha = 1, border = true,
                              showHealPrediction = false, showAbsorb = false },
                    mpbar = { enabled = true, x = 0, y = -20, w = 70, h = 10, level = 0,
                              colorMethod = "power", bgColorMethod = "powerdark",
                              barAlpha = 1, bgAlpha = 0.6, border = true },
                    texts = {
                        textDef{ pattern = "[name]", x = 0, y = 14, w = 70, h = 50, size = 10,
                                 justifyH = "CENTER", justifyV = "MIDDLE" },
                        textDef{ pattern = "[perchp]%", x = 17, y = 14, w = 70, h = 50, size = 8,
                                 justifyH = "RIGHT", justifyV = "MIDDLE" },
                        textDef{ pattern = "[curmp]/[maxmp]", x = 0, y = -21, w = 70, h = 10,
                                 size = 8, justifyH = "CENTER", justifyV = "MIDDLE", level = 6 },
                    },
                    icons = { enabled = true,
                              raidtarget = { enabled = true, x = 27, y = 10, w = 16, h = 16, level = 6 } },
                },
            },

            ------------------------------------------------------------
            pet = {
                enabled = true,
                frame = { x = -470, y = -225, w = 120, h = 50 },
                elements = {
                    portrait = { enabled = true, x = 0, y = 0, w = 120, h = 40, mode = "3d",
                                 bg = { r = 0.165, g = 0.165, b = 0.165, a = 1 }, level = 2,
                                 fallback2D = false },
                    hpbar = { enabled = true, x = 0, y = 0, w = 120, h = 40, level = 4, lossAlpha = 0.55,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.8, bgAlpha = 1, border = true,
                              showHealPrediction = false, showAbsorb = false },
                    mpbar = { enabled = true, x = 0, y = -40, w = 120, h = 10, level = 0,
                              colorMethod = "class", bgColorMethod = "classreactiondark",
                              barAlpha = 1, bgAlpha = 1, border = true },
                    texts = {
                        textDef{ pattern = "[name]", x = 3, y = -3, w = 120, h = 12, size = 13 },
                        textDef{ pattern = "[level] [class:creaturetype]", x = 3, y = -18, w = 108, h = 10, size = 10 },
                        textDef{ pattern = "[perchp]%", x = 0, y = 15, w = 120, h = 40,
                                 justifyH = "RIGHT", justifyV = "BOTTOM" },
                        textDef{ pattern = "[curmp]/[maxmp]", x = 0, y = 0, w = 120, h = 50, size = 10,
                                 justifyH = "CENTER", justifyV = "BOTTOM", level = 11 },
                        textDef{ pattern = "[curhp]/[maxhp]", x = -1, y = 2, w = 120, h = 40, size = 10,
                                 justifyH = "RIGHT", justifyV = "BOTTOM",
                                 color = { r = 0.851, g = 0.851, b = 0.851, a = 1 } },
                        textDef{ pattern = "[gray_if_dead:死亡]", x = 0, y = -2, w = 120, h = 40, size = 10,
                                 justifyH = "CENTER", justifyV = "BOTTOM" },
                    },
                    castbar = {
                        enabled = true, x = 0, y = 0, w = 120, h = 40, level = 6, timeFormat = "elapsedTotal",
                        showInterruptState = false, showCompleteFlash = true, fadeTime = 0.5, interruptHold = 0.4, showShield = false, shieldStyle = "blizzard", shieldScale = 1.2, shieldOffsetX = 0, shieldOffsetY = 0,
                        bg = black(0.5),
                        spell = { x = 34, y = 5, w = 120, h = 50, size = 12, flags = "OUTLINE",
                                  justifyH = "LEFT", justifyV = "MIDDLE",
                                  color = { r = 1, g = 0.5, b = 0.2, a = 1 } },
                        time  = { x = 0, y = -26, w = 120, h = 12, size = 12, flags = "OUTLINE",
                                  justifyH = "CENTER", justifyV = "MIDDLE", color = white(1) },
                        icon  = { x = 10, y = -11, w = 20, h = 20 },
                    },
                    buffs  = { enabled = true, x = 0, y = -52, w = 20, h = 20,
                               maxCount = 12, perRow = 6, growth = "LRTB", spacing = 1,
                               showStack = true, stackSize = 10,
                               durationText = false, durationThreshold = 60 },
                    debuffs = { enabled = true, x = 0, y = 5, w = 20, h = 20,
                                maxCount = 12, perRow = 6, growth = "LRBT", spacing = 1,
                                showStack = true, stackSize = 10,
                                durationText = false, durationThreshold = 60 },
                },
            },

            ------------------------------------------------------------
            boss = {   -- boss1-5 共用；boss1 在 frame.x/y，其餘依 growth/spacing 排
                -- 使用者實地調好的版面（2026-08-16 從 SavedVariables 原樣收進來，含位置）。
                -- 我們自己畫首領框、暴雪的已隱藏，所以位置與暴雪首領框無關。
                enabled = true,
                frame = { x = 499, y = 319, w = 220, h = 32, growth = "DOWN", spacing = 80 },
                elements = {
                    portrait = { enabled = true, x = 37, y = 50, w = 66, h = 66, mode = "3d",
                                 bg = { r = 0, g = 0, b = 0, a = 0 },
                                 zoom = 1, rotation = 0, level = 0, fallback2D = false },
                    hpbar = { enabled = true, x = 36, y = 0, w = 184, h = 14, level = 4,
                              colorMethod = "classreaction", bgColorMethod = "solid",
                              bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.4, bgAlpha = 1, border = true,
                              showHealPrediction = false, healPredictionFollowBar = false,
                              healPredictionColor = { r = 1, g = 1, b = 1, a = 0.25 },
                              showAbsorb = true, absorbColor = { r = 0.6, g = 0.85, b = 1, a = 0.7 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.15, b = 0.15, a = 0.7 } },
                    mpbar = { enabled = true, x = 36, y = -13, w = 184, h = 10, level = 4,
                              colorMethod = "power", bgColorMethod = "powerdark",
                              barAlpha = 1, bgAlpha = 1, border = true },
                    texts = {
                        textDef{ pattern = "[name]", x = 40, y = 13, w = 160, h = 14, size = 18,
                                 justifyH = "LEFT", justifyV = "MIDDLE", level = 10 },
                        textDef{ pattern = "[perchp]%", x = 36, y = 10, w = 184, h = 22, size = 16,
                                 justifyH = "RIGHT", justifyV = "MIDDLE" },
                        textDef{ pattern = "[percmp]%", x = 36, y = -14, w = 184, h = 10, size = 10,
                                 justifyH = "RIGHT", justifyV = "MIDDLE" },
                    },
                    castbar = {
                        enabled = true, x = 36, y = -22, w = 184, h = 14, level = 6,
                        timeFormat = "elapsedTotal", showInterruptState = true,
                        showCompleteFlash = true, fadeTime = 0.5, interruptHold = 0.4,
                        showShield = true, shieldStyle = "blizzard", shieldScale = 1.4,
                        shieldOffsetX = 0, shieldOffsetY = 0,
                        bg = black(0.7), border = true,
                        spell = { x = 18, y = 0, w = 130, h = 14, size = 14, flags = "OUTLINE",
                                  justifyH = "LEFT", justifyV = "MIDDLE", color = white(1) },
                        time  = { x = 0, y = 0, w = 180, h = 14, size = 12, flags = "OUTLINE",
                                  justifyH = "RIGHT", justifyV = "MIDDLE", color = white(1) },
                        icon  = { x = 0, y = 0, w = 14, h = 14 },
                    },
                    icons = { enabled = true,
                              raidtarget = { enabled = true, x = 204, y = 13, w = 14, h = 14, level = 10 } },
                },
            },

            ------------------------------------------------------------
            totem = {   -- 樣式 A 圖示膠囊列（使用者定案）
                enabled = true,
                style = "capsule",
                -- 玩家框下方、與框左緣對齊：
                -- 玩家框 200×50 中心 (-300,-225)：左緣 -400、下緣 -250；mp 條錯位 8px 到 -258、
                -- 職業資源條在下緣 -14 再 6 高到 -270 → 圖示頂 -272、28 高 → 中心 y=-286
                -- 四格寬 28*4+4*3=124 → 中心 x=-338
                frame = { x = -338, y = -286, iconSize = 28, spacing = 4, growth = "RIGHT" },
                colors = "accent",       -- "accent" | "element"
                swapEarthFire = true,
                showTimeText = true,     -- 圖示上的剩餘秒數
            },
        },

        minimap = { hide = false, angle = 200 },
        optionsWindow = { x = 0, y = 0 },
    }
end

------------------------------------------------------------
-- 明確 nil-merge：只補 nil、不覆蓋使用者值
------------------------------------------------------------
local function MergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            MergeDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end
DB.MergeDefaults = MergeDefaults

-- 遷移常用工具：走訪每個單位的某個元件表（含 nil 安全）
-- 用法：DB.EachElement(db, "castbar", function(cb, unitKey) ... end)
function DB.EachElement(db, elementName, fn)
    for unitKey, udb in pairs(db.units or {}) do
        local e = type(udb) == "table" and type(udb.elements) == "table" and udb.elements[elementName]
        if type(e) == "table" then fn(e, unitKey) end
    end
end

function DB.Migrate(db)
    -- 版本閘遷移鏈：只動「還是舊預設值」的欄位，使用者調過的不碰。
    -- 寫法：if db.schemaVersion < N then ... end（由小到大排），改完把 ns.DB_VERSION bump 到 N。
    -- 目前無遷移（插件尚未發佈，開發期的歷史遷移已清空）。
end

function DB.Init()
    MiliUI_UnitFrame_DB = type(MiliUI_UnitFrame_DB) == "table" and MiliUI_UnitFrame_DB or {}
    local db = MiliUI_UnitFrame_DB
    db.schemaVersion = db.schemaVersion or ns.DB_VERSION
    if db.schemaVersion > ns.DB_VERSION then
        -- SV 來自較新版（或開發期版本號被重置）：對齊到目前版本，之後的遷移才跑得到
        db.schemaVersion = ns.DB_VERSION
    end
    if db.schemaVersion < ns.DB_VERSION then
        DB.Migrate(db)
        db.schemaVersion = ns.DB_VERSION
    end
    MergeDefaults(db, DB.BuildDefaults())
    ns.db = db
    return db
end

-- boss1-5 共用 units.boss；其餘直取
function ns.GetUnitDB(unitKey)
    return ns.db and ns.db.units[unitKey]
end

------------------------------------------------------------
-- 恢復預設
------------------------------------------------------------
-- 單一單位（含 totem）：原地 wipe 再灌預設。必須原地——各 uf.db / Options 都抓著這張表的參照
function DB.ResetUnit(unitKey)
    local defaults = DB.BuildDefaults().units[unitKey]
    local live = ns.db and ns.db.units[unitKey]
    if not (defaults and live) then return false end
    wipe(live)
    MergeDefaults(live, defaults)
    return true
end

-- 全域樣式（global 區塊）
function DB.ResetGlobal()
    local defaults = DB.BuildDefaults().global
    wipe(ns.db.global)
    MergeDefaults(ns.db.global, defaults)
end

-- 全部：清 SV 後重載（最乾淨，避免殘留參照）
function DB.ResetAll()
    MiliUI_UnitFrame_DB = nil
    ReloadUI()
end
