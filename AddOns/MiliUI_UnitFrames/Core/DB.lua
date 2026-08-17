------------------------------------------------------------
-- SavedVariables：MiliUI_UnitFrames_DB
-- 單一帳號設定檔。預設值轉譯自使用者原本調好的版面，邊框改為全域 1px 細框。
--
-- 座標語意：
--   units.<key>.frame.x/y = 框架「中心」相對 UIParent 中心的偏移（解析度無關）
--   元件 x/y             = 相對單位框 TOPLEFT 的偏移
--
-- 合併規則（堵死 boolean 預設值陷阱）：
--   * defaults 每個 boolean 都明寫 true/false，一律正向 enabled（廢除 hide）
--   * 使用者值只補 nil、永不覆蓋
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.DB = {}
local DB = ns.DB

------------------------------------------------------------
-- 共用小工具
------------------------------------------------------------
local function black(a) return { r = 0, g = 0, b = 0, a = a or 1 } end
local function white(a) return { r = 1, g = 1, b = 1, a = a or 1 } end

------------------------------------------------------------
-- 每個單位的 frame 區塊共通欄位（顯示條件／淡出／高亮）
--
-- 抽成一支的理由：這幾個鍵七個單位都要有，散在七處遲早漂掉。呼叫點已經寫了的值
-- 不覆蓋（例如 target 的 fadeOutOfRange 是 true），這裡只補「維持現狀」的預設。
--
--   visibility        主模式，見 Core/Visibility.lua 的 MODES
--   vis*              附加條件，任一成立就藏
--   fadeOutOfRange    超出距離淡出（輪詢）
--   fadeOutOfCombat   脫戰淡出（吃事件）
--   highlight         滑鼠移過時畫一圈高亮邊框
------------------------------------------------------------
local function frameDef(o)
    if o.visibility == nil then o.visibility = "always" end
    if o.visOnlyInstances == nil then o.visOnlyInstances = false end
    if o.visHideMounted == nil then o.visHideMounted = false end
    if o.visHideNoTarget == nil then o.visHideNoTarget = false end
    if o.visHideNoEnemy == nil then o.visHideNoEnemy = false end
    if o.fadeOutOfRange == nil then o.fadeOutOfRange = false end
    if o.fadeOutOfCombat == nil then o.fadeOutOfCombat = false end
    if o.highlight == nil then o.highlight = true end
    return o
end

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
-- own = 自己的施法條：單一顏色、不畫「不可打斷」的灰（只有敵方才需要標示）
--
-- ⚠ 這兩個框的施法條是 200×52 @ (0,0)，跟頭像 200×50 @ (0,0) **完全重疊**，
-- 所以填充不透明的話唱法時整片蓋住 3D 頭像。使用者定案：填充 0.3 + 開前緣亮點
-- ——薄薄一層色帶過去、頭像看得見，亮點負責標出進度到哪。
-- 專注／寵物／首領的施法條不疊在頭像上，維持 1.0 且不畫亮點。
local function bigCastbar(own)
    return {
        enabled = true, x = 0, y = 0, w = 200, h = 52, level = 6,
        bg = black(0.8), timeFormat = "elapsedTotal",
        showInterruptState = not own,   -- 自己的施法不套「不可打斷灰」也不畫盾牌
        showCompleteFlash = true, fadeTime = 0.5, interruptHold = 0.4,
        showSpark = true,               -- 填充前緣的亮點：填充變淡之後靠它讀進度
        barAlpha = 0.3,                 -- 只有彩色填充變淡；圖示與文字照樣清楚
        -- C8：你的斷法好了就換色。自己的施法沒有「能不能被斷」的意義，所以只有敵方開
        showInterruptReady = not own,
        -- C4：對誰施法。預設關（開了會多一行字，位置每個人喜好不同）
        showCastTarget = false,
        castTarget = { x = 0, y = -2, w = 196, h = 50, size = 10, flags = "OUTLINE",
                       justifyH = "RIGHT", justifyV = "MIDDLE",
                       color = { r = 1, g = 0.82, b = 0.4, a = 1 } },
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
            oorAlpha    = 0.45,          -- 超出距離時整個框的透明度
            oocAlpha    = 0.5,           -- 脫戰時整個框的透明度（哪些框要淡出是每單位設的）
            -- 滑鼠移過的高亮邊框（開關在每單位的 frame.highlight）
            highlightColor = white(0.7),
            highlightSize  = 1,
            -- 編輯模式格線（C11）：只在編輯模式期間出現，拖曳時 Shift 反轉吸附
            gridShow    = true,
            gridSnap    = false,
            gridSize    = 32,
            gridAlpha   = 0.25,
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
                -- 斷法就緒（C8）：你的打斷技能好了，敵方施法條換這個色
                interruptReady = { r = 0.20, g = 0.85, b = 1 },
            },
            classification = {
                worldboss = L[" Boss"], rareelite = L[" Rare Elite"],
                elite = L[" Elite"], rare = L[" Rare"], normal = "", unknown = "??",
            },
        },

        units = {
            ------------------------------------------------------------
            player = {
                enabled = true,
                frame = frameDef{ x = -300, y = -225, w = 200, h = 50, fadeOutOfRange = false },
                elements = {
                    -- 層級嚴格遞增：mp 條 0 / mp 框 1 / 血條背景 2 / 3D 頭像 3（去背）/ 血條前景 4
                    -- （背景若跟 mp 框同層，mp 的黑框會浮上來透過半透明前景露出）
                    portrait = { enabled = true, x = 0, y = 0, w = 200, h = 50, mode = "3d",
                                 bg = { r = 0.165, g = 0.165, b = 0.165, a = 0 }, level = 3,
                                 zoom = 1, rotation = 0,       -- 正面朝鏡頭（度）
                                 modelOffsetX = 0, modelOffsetY = 0,      -- 設定面板顯示 ×100
                                 fallback2D = false },
                    hpbar = { enabled = true, x = 0, y = 0, w = 200, h = 50, level = 4, bgLevel = 2, lossAlpha = 0.9,
                              colorMethod = "class", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.5, bgAlpha = 1, border = true,
                              showHealPrediction = true, showAbsorb = true,
                              -- 疊加層顏色／方向沿用團隊框慣用的預設
                              healPredictionFollowBar = false, healPredictionColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              absorbColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              absorbReverseFill = true,          -- 從右端往左長，讀起來像額外的血
                              showOvershield = true, overshieldGlowReverse = false,
                              -- 吸收盾獨立細條（C6）：預設關，開了就是血條外多一條
                              absorbBarPosition = "none", absorbBarHeight = 4, absorbBarGap = 1,
                              absorbBarColor = { r = 0.6, g = 0.85, b = 1, a = 1 },
                              overshieldColor = { r = 1, g = 1, b = 1, a = 1 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.1, b = 0.1, a = 1 } },
                    mpbar = { enabled = true, x = 8, y = -8, w = 200, h = 50, level = 0,
                              colorMethod = "power", bgColorMethod = "powerdark",
                              barAlpha = 1, bgAlpha = 1, border = true },
                    classpower = { enabled = true, x = 8, y = -14, totalw = 200, h = 6,
                                   spacing = 1, rowSpacing = 2, level = 5,
                                   barAlpha = 1, showText = false,
                                   resources = {} },   -- [資源key] = false 表示關掉
                    -- 小魔力條：設定完全獨立，但錨點語意與外觀比照資源條
                    -- （TOPLEFT 對框架 BOTTOMLEFT、底色＋1px 黑邊）。
                    -- 版面：框底 →6px→ 魔力條(6) →2px→ 資源條(y=-14, 6) 不重疊
                    manabar = { enabled = true, x = 8, y = -6, w = 200, h = 6, level = 6,
                                color = { r = 0.2, g = 0.5, b = 1, a = 1 },   -- 法力藍
                                barAlpha = 1, bgAlpha = 0.8, border = true },
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
                        textDef{ pattern = L["[gray_if_dead:Dead][gray_if_ghost:Ghost]"],
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
                              -- 只有玩家框吃得到這兩個：
                              --   restAnimated   休息 zzZ 用暴雪內建的 flipbook 動畫
                              --   combatBlizzard 戰鬥改用內建 AttackIcon（原尺寸 16×16，不吃寬高設定）
                              status     = { enabled = true,  x = -8,  y = 10, w = 14, h = 14, level = 10,
                                             restAnimated = true, combatBlizzard = false },
                              leader     = { enabled = true,  x = 7,   y = 10, w = 12, h = 12, level = 10 },
                              pvp        = { enabled = false, x = -15, y = -12, w = 28, h = 28, level = 10 } },
                },
            },

            ------------------------------------------------------------
            target = {
                enabled = true,
                frame = frameDef{ x = 300, y = -225, w = 200, h = 50, fadeOutOfRange = true },
                elements = {
                    -- 層級嚴格遞增：mp 條 0 / mp 框 1 / 血條背景 2 / 3D 頭像 3（去背）/ 血條前景 4
                    -- （背景若跟 mp 框同層，mp 的黑框會浮上來透過半透明前景露出）
                    portrait = { enabled = true, x = 0, y = 0, w = 200, h = 50, mode = "3d",
                                 bg = { r = 0.165, g = 0.165, b = 0.165, a = 0 }, level = 3,
                                 zoom = 1, rotation = 0,       -- 正面朝鏡頭（度）
                                 modelOffsetX = 0, modelOffsetY = 0,      -- 設定面板顯示 ×100
                                 fallback2D = false },   -- 副本小怪 3D 取不到時是否退 2D
                    hpbar = { enabled = true, x = 0, y = 0, w = 200, h = 50, level = 4, bgLevel = 2, lossAlpha = 0.9,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.5, bgAlpha = 1, border = true,
                              showHealPrediction = true, showAbsorb = true,
                              -- 疊加層顏色／方向沿用團隊框慣用的預設
                              healPredictionFollowBar = false, healPredictionColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              absorbColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              absorbReverseFill = true,          -- 從右端往左長，讀起來像額外的血
                              showOvershield = true, overshieldGlowReverse = false,
                              -- 吸收盾獨立細條（C6）：預設關，開了就是血條外多一條
                              absorbBarPosition = "none", absorbBarHeight = 4, absorbBarGap = 1,
                              absorbBarColor = { r = 0.6, g = 0.85, b = 1, a = 1 },
                              overshieldColor = { r = 1, g = 1, b = 1, a = 1 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.1, b = 0.1, a = 1 } },
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
                        textDef{ pattern = L["[gray_if_oor:Out of Range ][gray_if_tapped:Tapped ][gray_if_offline:Offline ][gray_if_dead:Dead ][gray_if_ghost:Ghost ]"],
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
                    -- 觀察按鈕：點下去開觀察視窗。座標是使用者在遊戲裡調定的
                    -- （框右上角外側，往上凸出 5）。
                    -- 預設是「圖示直接浮在框上」——不畫邊框也不畫底色（使用者定案）；
                    -- 圖本身帶描邊與投影，亮背景上也撐得住
                    inspect = { enabled = true, x = 180, y = 5, w = 25, h = 25, level = 8, alpha = 1,
                                style = "glass", border = false, bgColor = black(0),
                                iconPadding = 0 },
                },
            },

            ------------------------------------------------------------
            targettarget = {
                enabled = true,
                frame = frameDef{ x = 470, y = -214, w = 120, h = 28, fadeOutOfRange = true },
                elements = {
                    hpbar = { enabled = true, x = 0, y = 0, w = 120, h = 20, level = 4,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.4, bgAlpha = 1, border = true,
                              -- 治療預估仍然關著（跟護盾是不同的勾選）
                              showHealPrediction = false,
                              -- 護盾：全部單位一致（疊加層只對 cache.assist 的單位畫，
                              -- 敵人身上本來就不會出現，開著不會多花什麼）
                              showAbsorb = true, absorbColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              absorbReverseFill = true,
                              showOvershield = true, overshieldGlowReverse = false,
                              -- 吸收盾獨立細條（C6）：預設關，開了就是血條外多一條
                              absorbBarPosition = "none", absorbBarHeight = 4, absorbBarGap = 1,
                              absorbBarColor = { r = 0.6, g = 0.85, b = 1, a = 1 },
                              overshieldColor = { r = 1, g = 1, b = 1, a = 1 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.1, b = 0.1, a = 1 } },
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
                frame = frameDef{ x = 260, y = -115, w = 120, h = 30, fadeOutOfRange = true },
                elements = {
                    hpbar = { enabled = true, x = 0, y = 0, w = 120, h = 20, level = 5,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.4, bgAlpha = 1, border = true,      -- 跟目標框同款（0.4）
                              -- 治療預估仍然關著（跟護盾是不同的勾選）
                              showHealPrediction = false,
                              -- 護盾：全部單位一致（疊加層只對 cache.assist 的單位畫，
                              -- 敵人身上本來就不會出現，開著不會多花什麼）
                              showAbsorb = true, absorbColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              absorbReverseFill = true,
                              showOvershield = true, overshieldGlowReverse = false,
                              -- 吸收盾獨立細條（C6）：預設關，開了就是血條外多一條
                              absorbBarPosition = "none", absorbBarHeight = 4, absorbBarGap = 1,
                              absorbBarColor = { r = 0.6, g = 0.85, b = 1, a = 1 },
                              overshieldColor = { r = 1, g = 1, b = 1, a = 1 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.1, b = 0.1, a = 1 } },
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
                        enabled = true, x = -20, y = 20, w = 160, h = 10, level = 7, timeFormat = "elapsedTotal", showInterruptState = true, showCompleteFlash = true, fadeTime = 0.5, interruptHold = 0.4, showSpark = false, barAlpha = 1, showInterruptReady = true,
                        showCastTarget = false,
                        castTarget = { x = 0, y = 18, w = 160, h = 10, size = 9, flags = "OUTLINE",
                                      justifyH = "RIGHT", justifyV = "TOP",
                                      color = { r = 1, g = 0.82, b = 0.4, a = 1 } },
                        showShield = true, shieldStyle = "blizzard", shieldScale = 1.2, shieldOffsetX = 0, shieldOffsetY = 0,
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
                frame = frameDef{ x = 360, y = -115, w = 70, h = 30, fadeOutOfRange = true },
                elements = {
                    hpbar = { enabled = true, x = 0, y = 0, w = 70, h = 20, level = 4,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.4, bgAlpha = 1, border = true,
                              -- 治療預估仍然關著（跟護盾是不同的勾選）
                              showHealPrediction = false,
                              -- 護盾：全部單位一致（疊加層只對 cache.assist 的單位畫，
                              -- 敵人身上本來就不會出現，開著不會多花什麼）
                              showAbsorb = true, absorbColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              absorbReverseFill = true,
                              showOvershield = true, overshieldGlowReverse = false,
                              -- 吸收盾獨立細條（C6）：預設關，開了就是血條外多一條
                              absorbBarPosition = "none", absorbBarHeight = 4, absorbBarGap = 1,
                              absorbBarColor = { r = 0.6, g = 0.85, b = 1, a = 1 },
                              overshieldColor = { r = 1, g = 1, b = 1, a = 1 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.1, b = 0.1, a = 1 } },
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
                frame = frameDef{ x = -470, y = -225, w = 120, h = 50, fadeOutOfRange = false },
                elements = {
                    -- 3D 頭像：層級照玩家框那套三明治（mp 0 / hp 背景 2 / 頭像 3 / hp 前景 4），
                    -- 底色 alpha 0 去背、血條前景半透明，模型才透得出來。
                    -- 尺寸與座標是寵物框自己的（120 寬），不是跟玩家共用設定。
                    portrait = { enabled = true, x = 0, y = 0, w = 120, h = 40, mode = "3d",
                                 bg = { r = 0.165, g = 0.165, b = 0.165, a = 0 }, level = 3,
                                 zoom = 1, rotation = 0,
                                 modelOffsetX = 0, modelOffsetY = 0,
                                 fallback2D = false },
                    hpbar = { enabled = true, x = 0, y = 0, w = 120, h = 40, level = 4, bgLevel = 2, lossAlpha = 0.9,
                              colorMethod = "classreaction", bgColorMethod = "solid", bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.5, bgAlpha = 1, border = true,
                              -- 治療預估仍然關著（跟護盾是不同的勾選，要的話在單位→血條打開）
                              showHealPrediction = false,
                              -- 護盾：目標框有、Cell 也有，寵物沒理由沒有。
                              -- 自己的寵物 cache.assist 為真，過得了疊加層的 assist 閘門
                              showAbsorb = true, absorbColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              absorbReverseFill = true,
                              showOvershield = true, overshieldGlowReverse = false,
                              -- 吸收盾獨立細條（C6）：預設關，開了就是血條外多一條
                              absorbBarPosition = "none", absorbBarHeight = 4, absorbBarGap = 1,
                              absorbBarColor = { r = 0.6, g = 0.85, b = 1, a = 1 },
                              overshieldColor = { r = 1, g = 1, b = 1, a = 1 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.1, b = 0.1, a = 1 } },
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
                        textDef{ pattern = L["[gray_if_dead:Dead]"], x = 0, y = -2, w = 120, h = 40, size = 10,
                                 justifyH = "CENTER", justifyV = "BOTTOM" },
                    },
                    castbar = {
                        enabled = true, x = 0, y = 0, w = 120, h = 40, level = 6, timeFormat = "elapsedTotal",
                        showInterruptState = false, showCompleteFlash = true, fadeTime = 0.5, interruptHold = 0.4, showSpark = false, barAlpha = 1, showInterruptReady = false,
                        showCastTarget = false,
                        castTarget = { x = 0, y = -2, w = 116, h = 40, size = 9, flags = "OUTLINE",
                                      justifyH = "RIGHT", justifyV = "MIDDLE",
                                      color = { r = 1, g = 0.82, b = 0.4, a = 1 } },
                        showShield = false, shieldStyle = "blizzard", shieldScale = 1.2, shieldOffsetX = 0, shieldOffsetY = 0,
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
                frame = frameDef{ x = 499, y = 319, w = 220, h = 32, growth = "DOWN", spacing = 80,
                                 fadeOutOfRange = true },
                elements = {
                    portrait = { enabled = true, x = 37, y = 50, w = 66, h = 66, mode = "3d",
                                 bg = { r = 0, g = 0, b = 0, a = 0 },
                                 zoom = 1, rotation = 0, level = 0, fallback2D = false },
                    hpbar = { enabled = true, x = 36, y = 0, w = 184, h = 14, level = 4,
                              colorMethod = "classreaction", bgColorMethod = "solid",
                              bgColor = { r = 0.12, g = 0.12, b = 0.12, a = 1 },
                              barAlpha = 0.4, bgAlpha = 1, border = true,
                              showHealPrediction = false, healPredictionFollowBar = false,
                              healPredictionColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              showAbsorb = true, absorbColor = { r = 1, g = 1, b = 1, a = 0.4 },
                              absorbReverseFill = true,
                              showOvershield = true, overshieldGlowReverse = false,
                              -- 吸收盾獨立細條（C6）：預設關，開了就是血條外多一條
                              absorbBarPosition = "none", absorbBarHeight = 4, absorbBarGap = 1,
                              absorbBarColor = { r = 0.6, g = 0.85, b = 1, a = 1 },
                              overshieldColor = { r = 1, g = 1, b = 1, a = 1 },
                              showHealAbsorb = true, healAbsorbColor = { r = 1, g = 0.1, b = 0.1, a = 1 } },
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
                        showSpark = false, barAlpha = 1, showInterruptReady = true,
                        -- 首領對誰施法：條只有 14 高，字放在條**下方**才不會跟時間撞
                        showCastTarget = false,
                        castTarget = { x = 0, y = -16, w = 184, h = 12, size = 11, flags = "OUTLINE",
                                       justifyH = "RIGHT", justifyV = "TOP",
                                       color = { r = 1, g = 0.82, b = 0.4, a = 1 } },
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
                              raidtarget = { enabled = true, x = 14, y = 10, w = 24, h = 24, level = 10 } },
                },
            },

            ------------------------------------------------------------
            totem = {   -- 樣式 A 圖示膠囊列（使用者定案）
                enabled = true,
                style = "capsule",
                -- 座標語意與資源條同一組：TOPLEFT 對玩家框 BOTTOMLEFT（往下是負的），
                -- 玩家框搬家就自己跟著走。
                -- 版面：框底 →6→ 魔力條(y=-6, 6 高) →2→ 資源條(y=-14, 6 高) →5→ 召喚物(y=-25)
                frame = { x = 8, y = -25, iconSize = 28, spacing = 4, growth = "RIGHT" },
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

------------------------------------------------------------
-- 遷移
--
-- 分兩層：
--   帳號層  改的是 SV 的結構本身（例如 v2 的「單一設定 → 具名設定檔」），
--           只能在 DB.Migrate 裡做一次
--   設定檔層 改的是「一份設定檔的內容」，寫進 PROFILE_MIGRATIONS
--
-- 拆開的理由：**匯入字串**帶著自己的 schemaVersion，可能比目前舊。那一份要補遷移，
-- 但不能把帳號層的 schemaVersion 降下去——那會讓遷移在**所有**設定檔上重跑一次，
-- 而 v4 那步會把別人刻意選的「觀察者」圖示改成「放大鏡」。別份設定檔不該被一次匯入影響。
-- 見 Options/Tab_Share.lua 的 Share.Import。
--
-- 通則不變：只動「還是舊預設值」的欄位（值閘），使用者調過的不碰。
------------------------------------------------------------
-- [版本號] = 把一份設定檔補到那個版本要做的事。加條目時 ns.DB_VERSION 一起 bump。
local PROFILE_MIGRATIONS = {
    -- v3：觀察按鈕的圖示改用自製圖，樣式代號跟著換名。
    -- 暴雪的 atlas 在 Midnight 被拿掉了（微型選單重畫），留著舊值只會退成備援圖示。
    [3] = function(profile)
        local RENAME = { character = "inspector", magnifier = "glass", question = "round" }
        for _, udb in pairs(profile.units or {}) do
            local e = type(udb) == "table" and type(udb.elements) == "table" and udb.elements.inspect
            if type(e) == "table" and RENAME[e.style] then e.style = RENAME[e.style] end
        end
    end,

    -- v4：觀察按鈕預設改成「純放大鏡、不要外框」。值閘——只動仍等於 v3 預設的欄位，
    -- 自己調過樣式／邊框／底色的人不碰。
    [4] = function(profile)
        for _, udb in pairs(profile.units or {}) do
            local e = type(udb) == "table" and type(udb.elements) == "table" and udb.elements.inspect
            if type(e) == "table" then
                if e.style == "inspector" then e.style = "glass" end
                if e.border == true then e.border = false end
                if e.iconPadding == 2 then e.iconPadding = 0 end
                local c = e.bgColor
                if type(c) == "table" and c.r == 0 and c.g == 0 and c.b == 0 and c.a == 0.6 then
                    c.a = 0
                end
            end
        end
    end,
}

-- 把一份設定檔從 fromVersion 補到目前版本。fromVersion 認不出來就當最舊的跑全套。
function DB.MigrateProfile(profile, fromVersion)
    if type(profile) ~= "table" then return end
    local from = tonumber(fromVersion) or 1
    for v = from + 1, ns.DB_VERSION do
        local step = PROFILE_MIGRATIONS[v]
        if step then pcall(step, profile) end
    end
end

function DB.Migrate(db)
    local from = db.schemaVersion

    -- 帳號層：v2 單一帳號設定 → 具名設定檔。舊 SV 的 global/units 直接搬進「預設」。
    if from < 2 then
        if db.global or db.units then
            db.profiles = db.profiles or {}
            db.profiles[DB.DEFAULT_PROFILE] = { global = db.global, units = db.units }
            db.global, db.units = nil, nil
        end
    end

    -- 設定檔層：每一份都補到目前版本
    for _, profile in pairs(db.profiles or {}) do
        DB.MigrateProfile(profile, from)
    end
end

------------------------------------------------------------
-- 設定檔
--
-- SV 結構：
--   MiliUI_UnitFrames_DB = {
--       schemaVersion, minimap, optionsWindow,     -- 帳號層，不跟設定檔走
--       profiles    = { ["預設"] = { global=, units= } },
--       profileKeys = { ["米利 - 世界之樹"] = "預設" },   -- 每角色指標
--   }
--
-- ns.db 仍然是一張**扁平的表**（.global/.units/.minimap/.optionsWindow），
-- 所有既有讀取點都不用改。刻意不用 metatable proxy：ns.db.global 落在熱路徑上，
-- 不值得為了換設定檔多付一次 __index。
--
-- 換設定檔一律 ReloadUI：uf.db、Options 的各種 refresher 全都抓著舊表的參照，
-- 就地換指標要逐一補正，而換設定檔是罕見的刻意操作——重載最乾淨，也跟既有的
-- 「匯入並重載」一致。
------------------------------------------------------------
-- ⚠ 這是存進 SV 的 key，**不要翻譯**：翻了之後換客戶端語系就對不上，
-- 使用者會看到一份空白設定。顯示名稱由 Options 那邊翻（共用／角色專屬／自訂）。
DB.DEFAULT_PROFILE = "Default"

local function CharKey()
    return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end
DB.CharKey = CharKey

function DB.Init()
    MiliUI_UnitFrames_DB = type(MiliUI_UnitFrames_DB) == "table" and MiliUI_UnitFrames_DB or {}
    local db = MiliUI_UnitFrames_DB
    db.schemaVersion = db.schemaVersion or ns.DB_VERSION
    if db.schemaVersion > ns.DB_VERSION then
        -- SV 來自較新版（或開發期版本號被重置）：對齊到目前版本，之後的遷移才跑得到
        db.schemaVersion = ns.DB_VERSION
    end
    if db.schemaVersion < ns.DB_VERSION then
        DB.Migrate(db)
        db.schemaVersion = ns.DB_VERSION
    end

    db.profiles = db.profiles or {}
    db.profileKeys = db.profileKeys or {}
    -- 角色 → 職業。設定檔清單要用職業色顯示「角色-伺服器」，而別隻角色的職業
    -- 沒有 API 可查，只能靠每隻角色登入時自己記一筆。
    -- ⚠ 存在帳號層而不是設定檔裡：設定檔會被深拷貝／重新灌種子，放進去會被帶錯。
    db.charClasses = db.charClasses or {}
    db.charClasses[CharKey()] = ns.playerClass
    local key = CharKey()
    local name = db.profileKeys[key]
    if type(name) ~= "string" or not db.profiles[name] then
        name = DB.DEFAULT_PROFILE
        db.profileKeys[key] = name
    end
    db.profiles[name] = db.profiles[name] or {}

    local defaults = DB.BuildDefaults()
    MergeDefaults(db.profiles[name], { global = defaults.global, units = defaults.units })
    MergeDefaults(db, { minimap = defaults.minimap, optionsWindow = defaults.optionsWindow })

    local p = db.profiles[name]
    ns.db = { global = p.global, units = p.units,
              minimap = db.minimap, optionsWindow = db.optionsWindow }
    ns.profileName = name
    return ns.db
end

------------------------------------------------------------
-- 三種設定檔
--   共用      key = "Default"，所有角色的預設，不給刪
--   角色專屬  key = "char:<角色> - <伺服器>"，第一次選才建立，內容從共用複製一份
--   自訂      使用者自己命名的
-- 「角色專屬」用保留前綴而不是另開一張表：這樣切換／刪除／匯出匯入全部共用同一
-- 套邏輯，不用到處寫特例。
------------------------------------------------------------
local CHAR_PREFIX = "char:"

function DB.CharProfileKey()
    return CHAR_PREFIX .. CharKey()
end

function DB.IsCharProfile(name)
    return type(name) == "string" and name:sub(1, #CHAR_PREFIX) == CHAR_PREFIX
end

-- 深拷貝：兩份設定檔絕不能共用同一張子表
local function DeepCopy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and DeepCopy(v) or v end
    return o
end

-- "char:米利 - 世界之樹" → "米利 - 世界之樹"（顯示層要用）
function DB.CharProfileOwner(name)
    if not DB.IsCharProfile(name) then return nil end
    return name:sub(#CHAR_PREFIX + 1)
end

-- 那隻角色的職業（沒登入過就查不到，回 nil）
function DB.CharClass(charKey)
    local db = MiliUI_UnitFrames_DB
    return db and db.charClasses and db.charClasses[charKey]
end

-- 寫入角色專屬那份。seed 只接受這三種，**沒有預設值**——來源一律由使用者在
-- 切換前的選擇彈窗指定（見 Tab_Share），這裡不替他猜。
--   "current"  目前正在用的那份（眼前看到的樣子）
--   "shared"   共用那份
--   "fresh"    全新預設值
-- ⚠ 會覆蓋既有內容，呼叫端必須先問過。
function DB.SeedCharProfile(seed)
    local db = MiliUI_UnitFrames_DB
    local key = DB.CharProfileKey()
    if seed == "fresh" then
        local d = DB.BuildDefaults()
        db.profiles[key] = { global = d.global, units = d.units }
        return key
    end
    local src
    if seed == "shared" then
        src = db.profiles[DB.DEFAULT_PROFILE]
    elseif seed == "current" then
        src = db.profiles[ns.profileName]
    end
    if not src then return nil end
    db.profiles[key] = DeepCopy(src)
    return key
end

-- 全部列出來，包含**別隻角色**的角色專屬——刻意的：想直接切去用別人調好的版面，
-- 或是從別人那份複製一份出來，都靠這個。切過去之後兩邊共用同一張表，改動互相看得到。
function DB.ListProfiles()
    local out = {}
    for name in pairs(MiliUI_UnitFrames_DB.profiles or {}) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function DB.SwitchProfile(name)
    local db = MiliUI_UnitFrames_DB
    if not (db.profiles and db.profiles[name]) then return false end
    db.profileKeys[CharKey()] = name
    ReloadUI()
    return true
end

-- copyFrom = nil 代表從預設值建立
function DB.CreateProfile(name, copyFrom)
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return false, "empty" end
    if DB.IsCharProfile(name) then return false, "reserved" end   -- char: 是保留前綴
    local db = MiliUI_UnitFrames_DB
    if db.profiles[name] then return false, "exists" end
    if copyFrom then
        local src = db.profiles[copyFrom]
        if not src then return false, "nosource" end
        db.profiles[name] = DeepCopy(src)
    else
        local defaults = DB.BuildDefaults()
        db.profiles[name] = { global = defaults.global, units = defaults.units }
    end
    return true
end

-- 刪掉指定那份，指著它的角色改回共用。共用本身不給刪。
function DB.DeleteProfile(name)
    local db = MiliUI_UnitFrames_DB
    if name == DB.DEFAULT_PROFILE or not db.profiles[name] then return false end
    db.profiles[name] = nil
    -- 指著它的角色全部改回預設，不然下次登入會看到空白設定
    for k, v in pairs(db.profileKeys) do
        if v == name then db.profileKeys[k] = DB.DEFAULT_PROFILE end
    end
    return true
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

-- 目前這份設定檔全部恢復預設後重載。
-- ⚠ 只動這一份，其他設定檔與帳號層（小地圖、視窗位置）不碰——有設定檔系統之後，
-- 「重置」把整個帳號炸掉太超過了。
function DB.ResetAll()
    local db = MiliUI_UnitFrames_DB
    local name = db and db.profileKeys and db.profileKeys[CharKey()]
    if db and name and db.profiles then
        local defaults = DB.BuildDefaults()
        db.profiles[name] = { global = defaults.global, units = defaults.units }
    end
    ReloadUI()
end
