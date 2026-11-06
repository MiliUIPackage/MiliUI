------------------------------------------------------------
-- MiliUIGlow 的 BarGlow（長條用的三款發光）離線測試：假的框把三款各建一次、跑一輪，
-- 抓進不了遊戲時看不到的錯（方法名打錯、沒建就用、重複 Start 重建）。
--   lua AddOns/MiliUI/Libs/MiliUIGlow/Tests/BarGlow_test.lua      （從 Interface/ 跑；run_tests.sh 會跑）
------------------------------------------------------------
local passed, failed = 0, 0
local function check(name, ok, detail)
    if ok then passed = passed + 1 else
        failed = failed + 1
        print("FAIL " .. name .. (detail and ("  " .. tostring(detail)) or ""))
    end
end

-- 只認得真的存在的方法：打錯名字會當場丟錯（這份測試的重點）
local METHODS = {
    Frame = { "SetAllPoints", "SetPoint", "ClearAllPoints", "SetSize", "SetAlpha", "Show", "Hide", "SetScript",
              "CreateTexture", "CreateAnimationGroup", "SetClipsChildren", "SetFrameLevel", "GetFrameLevel" },
    Texture = { "SetTexture", "SetTexCoord", "SetBlendMode", "SetPoint", "ClearAllPoints", "SetSize", "SetWidth",
                "SetHeight", "SetVertexColor", "SetGradient", "SetSnapToPixelGrid", "SetTexelSnappingBias" },
    AnimationGroup = { "SetLooping", "CreateAnimation", "Play", "Stop", "IsPlaying" },
    Alpha = { "SetFromAlpha", "SetToAlpha", "SetDuration", "SetSmoothing", "SetStartDelay", "SetEndDelay" },
    Translation = { "SetOffset", "SetDuration", "SetEndDelay" },
}
local created = { Frame = 0, Texture = 0, AnimationGroup = 0 }
local function New(kind)
    local o = { _kind = kind, _calls = {}, _scripts = {} }
    created[kind] = (created[kind] or 0) + 1
    for _, m in ipairs(METHODS[kind]) do
        o[m] = function(self, ...) self._calls[m] = { ... } end
    end
    if kind == "Frame" then
        o.CreateTexture = function() return New("Texture") end
        o.CreateAnimationGroup = function(self)
            local ag = New("AnimationGroup")
            self._groups = self._groups or {}
            self._groups[#self._groups + 1] = ag
            return ag
        end
        o.Show = function(self) self._shown = true end
        o.Hide = function(self) self._shown = false end
        o.SetScript = function(self, name, fn) self._scripts[name] = fn end
        o.GetFrameLevel = function() return 1 end
    elseif kind == "AnimationGroup" then
        o.anims = {}
        o.CreateAnimation = function(self, t)
            local a = New(t)
            self.anims[#self.anims + 1] = a
            return a
        end
        o.Play = function(self) self._playing = true; self._plays = (self._plays or 0) + 1 end
        o.Stop = function(self) self._playing = false end
        o.IsPlaying = function(self) return self._playing or false end
    end
    return setmetatable(o, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then error(kind .. " 沒有方法 " .. k, 2) end
    end })
end

local env = setmetatable({}, { __index = _G })
env._G = env
env.CreateFrame = function() return New("Frame") end
env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
-- 檔案前半（上游的 Start 系列）載入時要的東西：給到能載完就好
env.GetTime = function() return 0 end
env.CreateFramePool = function() return { Acquire = function() end, Release = function() end } end
env.CreateTexturePool = env.CreateFramePool
env.UIParent = New("Frame")
env.C_AddOns = { IsAddOnLoaded = function() return false end }

local dir = arg[0]:match("^(.*)[/\\]Tests[/\\][^/\\]+$") or "AddOns/MiliUI/Libs/MiliUIGlow"
local ns = {}
local chunk, err
if setfenv then
    chunk, err = loadfile(dir .. "/MiliUIGlow.lua")
    if chunk then setfenv(chunk, env) end
else
    chunk, err = loadfile(dir .. "/MiliUIGlow.lua", "t", env)
end
assert(chunk, err)
local okLoad, loadErr = pcall(chunk, "Test", ns)
check("整支載得起來", okLoad, loadErr)
local lib = ns.MiliUIGlow
if not (lib and lib.BarGlow_Start) then
    print(("BarGlow_test: %d passed, %d failed"):format(passed, failed + 1))
    os.exit(1)
end

check("三款的清單", #lib.BarGlowStyles == 3)
local opts = { edgeFile = "edge", width = 300, height = 20, px = 1 }
for _, style in ipairs(lib.BarGlowStyles) do
    local host = New("Frame")
    local ok, e = pcall(lib.BarGlow_Start, host, style, { 0.3, 0.85, 1, 1 }, opts)
    check(style .. "：開得起來", ok, e)
    local g = host._barGlow and host._barGlow[style]
    check(style .. "：框顯示、動畫在播", g and g.on and g.root._shown == true and #g.groups > 0)
    if g then
        local all = true
        for _, ag in ipairs(g.groups) do all = all and ag._playing == true end
        check(style .. "：每一組都在播", all)
        -- 重複 Start（沒變）：不重建、不重播
        local frames, plays = created.Frame, g.groups[1]._plays
        lib.BarGlow_Start(host, style, { 0.3, 0.85, 1, 1 }, opts)
        check(style .. "：沒變 ⇒ 不重建不重播", created.Frame == frames and g.groups[1]._plays == plays)
        -- 換顏色：重排、從頭播（不建新框）
        lib.BarGlow_Start(host, style, { 1, 0, 0, 1 }, opts)
        check(style .. "：換色 ⇒ 重播、不建新框", created.Frame == frames and g.groups[1]._plays == plays + 1)
        -- 祖先藏過再顯示：動畫停了就接回去
        g.groups[1]._playing = false
        g.root._scripts.OnShow()
        check(style .. "：重新顯示 ⇒ 接著播", g.groups[1]._playing == true)
        -- 停
        lib.BarGlow_Stop(host)
        check(style .. "：停 ⇒ 藏起來、動畫停", g.on == false and g.root._shown == false and g.groups[1]._playing == false)
        g.root._scripts.OnShow()
        check(style .. "：停著時顯示 ⇒ 不自己播", g.groups[1]._playing == false)
    end
end

-- 同一個 host 換款：舊的關掉
do
    local host = New("Frame")
    lib.BarGlow_Start(host, "halo", { 1, 1, 1, 1 }, opts)
    lib.BarGlow_Start(host, "pulse", { 1, 1, 1, 1 }, opts)
    check("換款 ⇒ 舊的關掉", host._barGlow.halo.on == false and host._barGlow.halo.root._shown == false and host._barGlow.pulse.on == true)
    lib.BarGlow_Start(host, "nope", { 1, 1, 1, 1 }, opts)
    check("不認得的款 ⇒ 光暈", host._barGlow.halo.on == true and host._barGlow.pulse.on == false)
    -- 流光的位移量 ＝ 整條寬 ＋ 亮帶寬（從 opts 算，不讀框）
    lib.BarGlow_Start(host, "sweep", { 1, 1, 1, 1 }, opts)
    local off = host._barGlow.sweep.move._calls.SetOffset
    check("流光：位移量 ＝ 寬 ＋ 亮帶寬", off and off[1] == 300 + 60 and off[2] == 0, off and off[1])
    -- 脈衝：每一圈的一輪總長一樣（一起循環）
    local total
    local same = true
    for i = 1, 3 do
        local a = host._barGlow.pulse.groups[i].anims[1]._calls
        local t = a.SetStartDelay[1] + a.SetDuration[1] + a.SetEndDelay[1]
        total = total or t
        same = same and math.abs(t - total) < 1e-9
    end
    check("脈衝：三圈的週期一樣", same)
    check("沒有 host、沒 Start 過就 Stop 不丟錯", pcall(lib.BarGlow_Stop, nil) and pcall(lib.BarGlow_Stop, New("Frame")))
end

print(("BarGlow_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
