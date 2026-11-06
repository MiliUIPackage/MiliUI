------------------------------------------------------------
-- 設定頁內嵌樣本條的離線煙霧測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/CastbarSample_test.lua
--
-- 樣本條（ns.Castbar.CreateSample／ns.FocusCastbar.CreateSample）跟畫面上那條是同一批函式：零件 BuildParts、版面與疊層
-- LayoutParts、上色／發光／名字／火花／延遲區／打斷畫面（PaintColorOn／ShowGlowOn／PaintNameOn／ShowSparkOn／DrawMarksOn／
-- PaintInterruptedOn…）。這裡用假的框把兩條樣本真的建出來、每種狀態跑一輪——那批函式畫面上那條也在用，所以這支同時是
-- 它們唯一的離線覆蓋：
--   1. 整條路不丟錯（零件、版面、效果層、每幀更新）
--   2. 樣本上的顏色／文字／發光就是設定裡的那一個（三態色、打斷色、斷法就緒染色、動畫材質底色白、「!」、發光開關）
--   3. 設定關著的東西樣本也不畫（glowImportant／bangImportant）
-- 假的框：大寫開頭的鍵一律當方法（SetX 記下參數、GetX 讀回來、CreateX 回另一個假物件），小寫開頭的是我們自己掛的欄位。
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

------------------------------------------------------------
-- 假物件
------------------------------------------------------------
local Mock
local function Method(k)
    if k == "SetScript" then
        return function(self, name, fn) self._scripts[name] = fn end
    elseif k == "GetScript" then
        return function(self, name) return self._scripts[name] end
    elseif k == "GetStatusBarTexture" or k == "GetFontString" then
        return function(self)
            self._sub = self._sub or {}
            self._sub[k] = self._sub[k] or Mock(k)
            return self._sub[k]
        end
    elseif k:match("^Create") then
        return function() return Mock(k) end
    elseif k == "SetSize" then
        return function(self, w, h) self._w, self._h = w, h end
    elseif k == "GetWidth" then
        return function(self) return self._w or 100 end
    elseif k == "GetHeight" then
        return function(self) return self._h or 20 end
    elseif k == "GetFrameLevel" then
        return function() return 1 end
    elseif k == "Show" then
        return function(self) self._shown = true end
    elseif k == "Hide" then
        return function(self) self._shown = false end
    elseif k == "SetShown" then
        return function(self, v) self._shown = v and true or false end
    elseif k == "IsShown" or k == "IsVisible" then
        return function(self) return self._shown ~= false end
    elseif k == "IsPlaying" then
        return function(self) return self._playing or false end
    elseif k == "Play" then
        return function(self) self._playing = true end
    elseif k == "Stop" then
        return function(self) self._playing = false end
    elseif k == "SetAlphaFromBoolean" then
        return function(self, flag, a, b) self._set.SetAlpha = { flag and a or b } end
    elseif k:match("^Set") or k:match("^Clear") or k:match("^Enable") or k:match("^Register") or k == "HookScript" then
        return function(self, ...) self._set[k] = { ... } end
    elseif k:match("^Get") then
        return function(self)
            local v = self._set["S" .. k:sub(2)]
            if v then return (table.unpack or unpack)(v) end
            return nil
        end
    end
    return function() end
end
Mock = function(kind)
    return setmetatable({ _kind = kind, _set = {}, _scripts = {} }, { __index = function(t, k)
        if type(k) == "string" and k:match("^%u") then
            local fn = Method(k)
            rawset(t, k, fn)
            return fn
        end
        return nil
    end })
end
local function Arg(obj, method, i) return obj._set[method] and obj._set[method][i or 1] end

------------------------------------------------------------
-- 環境
------------------------------------------------------------
local env = setmetatable({}, { __index = _G })
env._G = env
env.CreateFrame = function(kind) return Mock(kind) end
env.GetTime = function() return 0 end
env.UnitName = function() return "米利" end
env.UnitClassBase = function() return "PALADIN" end
env.C_Spell = { GetSpellTexture = function(id) return "kick-" .. tostring(id) end }
env.C_ClassColor = { GetClassColor = function() return { GetRGB = function() return 0.96, 0.55, 0.73 end } end }
env.C_Texture = { GetAtlasInfo = function() return {} end }

local castCfg = { texture = "Flat", height = 20, width = 300, colors = { cast = { r = 0.1, g = 0.2, b = 0.3 },
    interruptReady = { r = 0.9, g = 0.8, b = 0.7 } }, animSpeed = 1 }
local focusCfg = { texture = "Flat", height = 20, width = 300, glowImportant = true, bangImportant = true,
    colors = { ready = { r = 1, g = 0, b = 0 }, cd = { r = 0, g = 1, b = 0 }, immune = { r = 0, g = 0, b = 1 },
        interrupted = { r = 0.5, g = 0.5, b = 0.5 }, glow = { r = 1, g = 1, b = 0 } } }
local kickReady, hasKick = false, true
local glowLog = {}

local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = function() return false end,
    DB = { ConfigTable = function(key) return key == "castbar" and castCfg or focusCfg end },
    P = { Scale = function(v) return v end, Pixel = function(v) return v end },
    NoSnap = function() end,
    NoSnapBackdrop = function() end,
    Setting = function() return nil end,
    FillReversed = function(cfg) return cfg.fillDirection == "rtl" end,
    Bars = { AutoWidth = function() return 300 end, SetPanelSize = function() end },
    Style = { Accent = function() return 0.4, 0.5, 0.6 end },
    Shape = { ShadowOf = function() return nil, nil end, EdgeShadow = function() end },
    Interrupt = { IsReady = function() return kickReady, hasKick end, SpellID = function() return 96231 end },
    playerClass = "PALADIN",
    MiliUIGlow = {
        PixelGlow_Start = function(host) glowLog[#glowLog + 1] = "pixel+"; host._glow = "pixel" end,
        PixelGlow_Stop = function(host) glowLog[#glowLog + 1] = "pixel-"; host._glow = nil end,
        AutoCastGlow_Start = function(host) glowLog[#glowLog + 1] = "autocast+"; host._glow = "autocast" end,
        AutoCastGlow_Stop = function(host) glowLog[#glowLog + 1] = "autocast-"; host._glow = nil end,
        ProcGlow_Start = function(host) glowLog[#glowLog + 1] = "proc+"; host._glow = "proc" end,
        ProcGlow_Stop = function(host) glowLog[#glowLog + 1] = "proc-"; host._glow = nil end,
    },
}
local FX = { Anim = { { kind = "scroll", tex = "a", period = 3 },
                      { kind = "flip", tex = "b", cols = 2, rows = 2, frames = 4, time = 1, pause = 0.5, overflow = 0.5, alpha = 0.5 },
                      { kind = "scroll", tex = "c", period = 2, twinkle = { lo = 0.4, period = 1 } } } }
ns.Media = {
    SetFont = function() end,
    Texture = function(token) return "tex-" .. tostring(token) end,
    BorderInset = function() return 1 end,
    ThemeOutline = function() return "OUTLINE" end,
    ElementFont = function() return "font" end,
    IsFx = function(token) return FX[token] ~= nil end,
    FxLayers = function(token) return FX[token] end,
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
Load("Modules/Castbar.lua")
Load("Modules/FocusCastbar.lua")
local CB, FC = ns.Castbar, ns.FocusCastbar

local function Tick(frame, n)
    local fn = frame._scripts.OnUpdate
    for _ = 1, n or 1 do fn(frame, 0.06) end
end
local function Fill(bar)
    local t = bar:GetStatusBarTexture()._set.SetVertexColor
    return t and (t[1] .. "," .. t[2] .. "," .. t[3]) or "nil"
end

------------------------------------------------------------
-- 1. 玩家施法條的樣本
------------------------------------------------------------
do
    local s = CB.CreateSample(Mock("parent"))
    local ok, err = pcall(s.Refresh, s, 500)
    check("施法條樣本：建得出來、Refresh 不丟錯", ok, err)
    eq("施法條樣本：寬照設定", s._w, 300)
    eq("施法條樣本：名字", Arg(s.nameText, "SetText"), "Preview cast")
    eq("施法條樣本：圖示在", s.iconFrame._shown, true)
    eq("施法條樣本：施法色", Fill(s.bar), "0.1,0.2,0.3")
    -- 疊層照 LayoutParts（畫面上那條的同一支）：底 L → 條 L+1 → 效果層 L+2 → 刻度與火花 L+3 → 文字 L+4；圖示 L+1
    eq("施法條樣本：疊層", table.concat({ Arg(s.barHolder, "SetFrameLevel"), Arg(s.bar, "SetFrameLevel"),
        Arg(s.flowClip, "SetFrameLevel"), Arg(s.marks, "SetFrameLevel"), Arg(s.textFrame, "SetFrameLevel"),
        Arg(s.iconFrame, "SetFrameLevel") }, ","), "1,2,3,4,5,2")
    eq("施法條樣本：延遲區照畫（同頁首預覽的假延遲）", s.latency._shown, true)
    castCfg.latency = false
    s:Refresh(500)
    eq("施法條樣本：延遲關掉 ⇒ 不畫", s.latency._shown, false)
    castCfg.latency = nil
    s:Refresh(500)
    ok, err = pcall(Tick, s, 80)
    check("施法條樣本：每幀更新不丟錯（跑過一整輪）", ok, err)
    check("施法條樣本：時間文字有寫", type(Arg(s.timeText, "SetText")) == "string" and Arg(s.timeText, "SetText") ~= "")

    castCfg.useClassColor = true
    s:Refresh(500)
    eq("施法條樣本：職業色", Fill(s.bar), "0.4,0.5,0.6")
    castCfg.useClassColor = false

    -- 斷法就緒染色：走畫面上那條的同一支，所以設定開著、斷法就緒時樣本也染
    castCfg.interruptReady, kickReady = true, true
    s:Refresh(500)
    eq("施法條樣本：斷法就緒染色照演", Fill(s.bar), "0.9,0.8,0.7")
    castCfg.interruptReady, kickReady = false, false

    -- 動畫材質：底色白、效果層開起來；放不下縮到可用寬；圖示關掉
    castCfg.texture, castCfg.showIcon, castCfg.fillDirection = "Anim", false, "rtl"
    ok, err = pcall(s.Refresh, s, 120)
    check("施法條樣本：動畫材質不丟錯", ok, err)
    eq("施法條樣本：動畫材質底色白", Fill(s.bar), "1,1,1")
    eq("施法條樣本：效果層開著", s.st.flow, true)
    eq("施法條樣本：效果層三層都在播", #s.fxActive, 3)
    eq("施法條樣本：放不下縮到可用寬", s._w, 120)
    eq("施法條樣本：圖示關了", s.iconFrame._shown, false)
    castCfg.animate = false
    s:Refresh(500)
    eq("施法條樣本：關掉動畫 ⇒ 效果層收掉", s.st.flow, false)
    castCfg.texture, castCfg.showIcon, castCfg.fillDirection, castCfg.animate = "Flat", nil, nil, nil
end

------------------------------------------------------------
-- 2. 專注目標施法條的樣本
------------------------------------------------------------
do
    local s = FC.CreateSample(Mock("parent"))
    local ok, err = pcall(s.Refresh, s, 500)
    check("專注樣本：建得出來、Refresh 不丟錯", ok, err)
    eq("專注樣本：預設狀態", s.state, "ready")
    eq("專注樣本：斷法就緒色", Fill(s.bar), "1,0,0")
    eq("專注樣本：名字帶施法者", Arg(s.nameText, "SetText"), "Focus target: Preview cast")
    check("專注樣本：「!」版的名字", tostring(Arg(s.bangText, "SetText")):find("!", 1, true) ~= nil)
    eq("專注樣本：「!」開著 ⇒ 顯示「!」版", Arg(s.bangText, "SetAlpha"), 1)
    eq("專注樣本：發光開著", s.glowShown, "pixel")
    eq("專注樣本：斷法圖示", Arg(s.kickIcon, "SetTexture"), "kick-96231")
    eq("專注樣本：斷法就緒 ⇒ 圖示亮", Arg(s.kickIcon, "SetAlpha"), 1)
    eq("專注樣本：打向自己", Arg(s.targetText, "SetText"), "米利")
    -- 疊層照 LayoutParts：底 L → 條 L+1 → 效果層 L+2 → 火花 L+3 → 文字 L+4；圖示與斷法圖示 L+1；發光宿主 L+20
    eq("專注樣本：疊層", table.concat({ Arg(s.barHolder, "SetFrameLevel"), Arg(s.bar, "SetFrameLevel"),
        Arg(s.flowClip, "SetFrameLevel"), Arg(s.top, "SetFrameLevel"), Arg(s.textFrame, "SetFrameLevel"),
        Arg(s.iconFrame, "SetFrameLevel"), Arg(s.kickFrame, "SetFrameLevel"),
        Arg(s.glowHosts.pixel, "SetFrameLevel") }, ","), "1,2,3,4,5,2,2,21")
    eq("專注樣本：一般材質沒有效果層", s.fxOn, false)
    ok, err = pcall(Tick, s, 80)
    check("專注樣本：每幀更新不丟錯", ok, err)

    s.state = "cd"; s:Paint()
    eq("專注樣本：斷法冷卻中色", Fill(s.bar), "0,1,0")
    eq("專注樣本：冷卻中 ⇒ 斷法圖示暗", Arg(s.kickIcon, "SetAlpha"), 0.55)
    s.state = "immune"; s:Paint()
    eq("專注樣本：不可中斷色", Fill(s.bar), "0,0,1")

    s.bangOn = false; s:Paint()
    eq("專注樣本：「!」關掉 ⇒ 顯示一般名字", Arg(s.nameText, "SetAlpha"), 1)
    eq("專注樣本：「!」關掉 ⇒ 「!」版藏起來", Arg(s.bangText, "SetAlpha"), 0)
    s.glowOn = false; s:Paint()
    eq("專注樣本：發光關掉 ⇒ 宿主透明", Arg(s.glowHosts.pixel, "SetAlpha"), 0)
    s.glowOn, s.bangOn = true, true; s:Paint()
    eq("專注樣本：發光再開 ⇒ 宿主不透明", Arg(s.glowHosts.pixel, "SetAlpha"), 1)

    s.state = "interrupted"; s:Paint()
    eq("專注樣本：打斷色", Fill(s.bar), "0.5,0.5,0.5")
    eq("專注樣本：打斷 ⇒ 名字換掉", Arg(s.nameText, "SetText"), "Interrupted")
    eq("專注樣本：打斷 ⇒ 右側印斷法者", Arg(s.timeText, "SetText"), "米利")
    eq("專注樣本：打斷 ⇒ 不發光", s.glowShown, nil)
    eq("專注樣本：打斷 ⇒ 滿條", Arg(s.bar, "SetValue"), 1)
    focusCfg.showInterrupter = false; s:Paint()
    eq("專注樣本：不印斷法者", Arg(s.timeText, "SetText"), "")
    focusCfg.showInterrupter = nil

    s.state = "ready"; s:Paint()
    eq("專注樣本：離開打斷 ⇒ 發光回來", s.glowShown, "pixel")

    -- 設定關著的東西樣本也不畫（跟實際一樣）
    focusCfg.glowImportant, focusCfg.bangImportant = false, false
    s:Refresh(500)
    eq("專注樣本：發光設定關著 ⇒ 不發光", s.glowShown, nil)
    eq("專注樣本：「!」設定關著 ⇒ 不標", Arg(s.bangText, "SetAlpha"), 0)
    focusCfg.glowImportant, focusCfg.bangImportant = true, true

    -- 換發光樣式、換顏色：先停再開
    focusCfg.glowStyle = "proc"
    s:Refresh(500)
    eq("專注樣本：換樣式", s.glowShown, "proc")
    local n = #glowLog
    focusCfg.colors.glow = { r = 0, g = 1, b = 1 }
    s:Refresh(500)
    check("專注樣本：換發光色 ⇒ 重開一次", #glowLog == n + 2 and glowLog[n + 1] == "proc-" and glowLog[n + 2] == "proc+",
        table.concat(glowLog, " ", n + 1))
    n = #glowLog
    s:Refresh(500)
    eq("專注樣本：沒變 ⇒ 不重開", #glowLog, n)
    focusCfg.glowStyle = nil

    -- 動畫材質：斷法冷卻中的底色是白（顏色在圖裡），就緒／不可中斷照舊蓋上去
    focusCfg.texture = "Anim"
    s.state = "cd"; s:Refresh(500)
    eq("專注樣本：動畫材質＋冷卻中 ⇒ 底色白", Fill(s.bar), "1,1,1")
    eq("專注樣本：動畫材質 ⇒ 效果層開著、三層都在", (s.fxOn and "on" or "off") .. #s.fxActive, "on3")
    eq("專注樣本：冷卻中 ⇒ 動畫在播", s.fxActive[1].group._playing, true)
    -- 效果層照播、整層染上跟填充同一個顏色（不讓位）；各層登記的 alpha 要帶著
    local function Tint(i)
        local t = s.fxActive[i].tex._set.SetVertexColor
        return table.concat(t, ",")
    end
    eq("專注樣本：冷卻中 ⇒ 效果層是圖自己的顏色", Tint(1), "1,1,1,1")
    s.state = "ready"; s:Paint()
    eq("專注樣本：動畫材質＋就緒 ⇒ 就緒色", Fill(s.bar), "1,0,0")
    eq("專注樣本：就緒 ⇒ 效果層染就緒色", Tint(1) .. " " .. Tint(2), "1,0,0,1 1,0,0,0.5")
    eq("專注樣本：就緒 ⇒ 動畫照播", s.fxActive[1].group._playing, true)
    eq("專注樣本：就緒 ⇒ 效果層沒有被壓透明", tostring(Arg(s.flowClip, "SetAlpha")) .. "," .. tostring(Arg(s.flowHost, "SetAlpha")), "nil,nil")
    s.state = "immune"; s:Paint()
    eq("專注樣本：不可中斷 ⇒ 效果層染不可中斷色", Tint(1), "0,0,1,1")
    eq("專注樣本：不可中斷 ⇒ 動畫照播", s.fxActive[1].group._playing, true)
    s.state = "interrupted"; s:Paint()
    eq("專注樣本：被打斷 ⇒ 動畫停", s.fxActive[1].group._playing, false)
    eq("專注樣本：被打斷 ⇒ 效果層收起來", s.flowClip._shown, false)
    s.state = "cd"; s:Paint()
    eq("專注樣本：離開打斷 ⇒ 動畫接著播", s.fxActive[1].group._playing, true)
    focusCfg.animate = false
    s:Refresh(500)
    eq("專注樣本：關掉動畫 ⇒ 效果層收掉", s.fxOn, false)
    focusCfg.animate = nil
    s.state = "ready"
    focusCfg.texture = "Flat"

    -- 這個專精沒有斷法：不畫斷法圖示、不丟錯
    ns.Interrupt.SpellID = function() return nil end
    ok, err = pcall(s.Refresh, s, 500)
    check("專注樣本：沒有斷法的專精不丟錯", ok, err)
    eq("專注樣本：沒有斷法 ⇒ 斷法圖示藏起來", s.kickFrame._shown, false)
end

print(("CastbarSample_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
