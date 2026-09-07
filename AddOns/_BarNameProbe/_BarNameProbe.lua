-- 臨時診斷插件：追「增益長條沒名字」
--
-- 對 BuffBarCooldownViewer 的每一個項目框掛勾，把跟名字有關的每一步都記下來：
--   Bar.Name 的 SetText / Show / Hide / SetAlpha（誰叫的、值是什麼類型）
--   暴雪的 RefreshName（進去時名字框顯示著嗎、出來時字是什麼）
--   SetBarContent、OnActiveStateChanged
-- 加上 /bnp 可以隨時把每一條現在的狀態整個倒出來（顯示、alpha、字、寬度、錨點、
-- totemData 是不是秘密表……），空白的那條跟正常的那條並排比對就知道差在哪。
--
-- ⚠ 12.1：字可能是秘密字串、totemData 可能是秘密表，這裡只分類不取值。
--
-- 2026-09-07 起隨套組發佈：這個問題單機重現不出來，改請玩家幫忙收集。
-- 玩家看到沒名字的長條時打 /bnp 跟 /bnp log，把兩段輸出貼回來。
-- 抓到並修掉之後就把這支從套組拿掉。

local issecret = issecretvalue
local LOG = {}
local MAX = 300
local hooked = setmetatable({}, { __mode = "k" })

local function Cls(v)
    if v == nil then return "nil" end
    if issecret and issecret(v) then return "secret(" .. type(v) .. ")" end
    local t = type(v)
    if t == "string" then
        if v == "" then return "empty" end
        return string.format("str[%s]", v)
    end
    if t == "table" then return "table" end
    return t .. ":" .. tostring(v)
end

local function Caller()
    -- 跳過 Caller、掛勾本身、hooksecurefunc 的包裝，取三行
    local s = debugstack(3, 4, 0)
    if issecret and issecret(s) then return "<secret stack>" end
    s = (s or ""):gsub("Interface/AddOns/", ""):gsub("%[string \"", ""):gsub("\"%]", ""):gsub("\n", " | ")
    return s:sub(1, 220)
end

local function Tag(frame)
    local id = frame.cooldownID
    if issecret and issecret(id) then id = "secret" end
    local sid = frame.GetSpellID and frame:GetSpellID()
    if issecret and issecret(sid) then sid = "secret" end
    return string.format("#%s/%s", tostring(frame.layoutIndex or "?"), tostring(sid or id or "?"))
end

local function Log(frame, what, detail)
    local line = string.format("%.2f %s %s %s", GetTime(), Tag(frame), what, detail or "")
    LOG[#LOG + 1] = line
    if #LOG > MAX then table.remove(LOG, 1) end
end

local function NameState(frame)
    local n = frame.Bar and frame.Bar.Name
    if not n then return "noName" end
    local ok, text = pcall(n.GetText, n)
    return string.format("shown=%s alpha=%.2f text=%s", tostring(n:IsShown()), n:GetAlpha(), ok and Cls(text) or "GetText-err")
end

local function HookFrame(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    local name = frame.Bar and frame.Bar.Name
    if name then
        hooksecurefunc(name, "SetText", function(self, v)
            Log(frame, "SetText", Cls(v) .. "  <- " .. Caller())
        end)
        hooksecurefunc(name, "Show", function() Log(frame, "Name:Show", "<- " .. Caller()) end)
        hooksecurefunc(name, "Hide", function() Log(frame, "Name:Hide", "<- " .. Caller()) end)
        hooksecurefunc(name, "SetAlpha", function(_, a) Log(frame, "Name:SetAlpha", tostring(a) .. " <- " .. Caller()) end)
        hooksecurefunc(name, "SetWidth", function(_, w) Log(frame, "Name:SetWidth", tostring(w)) end)
    end
    if frame.RefreshName then
        hooksecurefunc(frame, "RefreshName", function(self)
            Log(self, "RefreshName(after)", NameState(self) .. "  <- " .. Caller())
        end)
    end
    if frame.SetBarContent then
        hooksecurefunc(frame, "SetBarContent", function(self, c)
            Log(self, "SetBarContent", tostring(c) .. "  " .. NameState(self))
        end)
    end
    if frame.OnActiveStateChanged then
        hooksecurefunc(frame, "OnActiveStateChanged", function(self)
            Log(self, "OnActiveStateChanged", "active=" .. tostring(self.isActive) .. "  " .. NameState(self))
        end)
    end
    if frame.RefreshData then
        hooksecurefunc(frame, "RefreshData", function(self)
            Log(self, "RefreshData(after)", NameState(self)
                .. " totem=" .. Cls(self.totemData) .. " aura=" .. Cls(self.auraDataCached))
        end)
    end
    Log(frame, "hooked", NameState(frame))
end

local function HookViewer()
    local v = BuffBarCooldownViewer
    if not v then return end
    hooksecurefunc(v, "OnAcquireItemFrame", function(_, f) HookFrame(f); Log(f, "acquire", NameState(f)) end)
    if v.itemFramePool then
        for f in v.itemFramePool:EnumerateActive() do HookFrame(f) end
    end
end

local function S(v)
    if issecret and issecret(v) then return "secret" end
    if type(v) == "number" then return string.format("%.1f", v) end
    return tostring(v)
end

local function Dump()
    local v = BuffBarCooldownViewer
    if not (v and v.itemFramePool) then print("BarNameProbe: 沒有檢視器"); return end
    print("|cffff4411BarNameProbe|r 目前的長條：")
    for f in v.itemFramePool:EnumerateActive() do
      local parts = {}
      local function add(label, fn)
          local ok, r = pcall(fn)
          parts[#parts + 1] = label .. "=" .. (ok and S(r) or ("ERR:" .. tostring(r)))
      end
      local n = f.Bar and f.Bar.Name
      parts[#parts + 1] = Tag(f)
      add("frameShown", function() return f:IsShown() end)
      add("frameVisible", function() return f:IsVisible() end)
      add("active", function() return f.isActive end)
      if n then
          add("shown", function() return n:IsShown() end)
          add("alpha", function() return n:GetAlpha() end)
          add("text", function() return Cls(n:GetText()) end)
          add("w", function() return n:GetWidth() end)
          add("h", function() return n:GetHeight() end)
          add("strW", function() return n:GetStringWidth() end)
          add("parentShown", function() return n:GetParent():IsShown() end)
          add("parentVisible", function() return n:GetParent():IsVisible() end)
          add("parentLevel", function() return n:GetParent():GetFrameLevel() end)
          add("font", function() local a, b, c = n:GetFont(); return tostring(a and a:match("[^\\/]+$")) .. "/" .. S(b) .. "/" .. tostring(c) end)
          add("color", function() local r, g, b, a = n:GetTextColor(); return S(r) .. "," .. S(g) .. "," .. S(b) .. "," .. S(a) end)
          add("layer", function() local l, sub = n:GetDrawLayer(); return tostring(l) .. "/" .. tostring(sub) end)
          add("points", function() return n:GetNumPoints() end)
          for i = 1, (n:GetNumPoints() or 0) do
              add("p" .. i, function()
                  local pt, rel, rp, x, y = n:GetPoint(i)
                  local relName = (rel == f.Bar and "Bar") or (rel and rel.GetName and rel:GetName()) or "?"
                  return S(pt) .. "->" .. tostring(relName) .. "." .. S(rp) .. " " .. S(x) .. "," .. S(y)
              end)
          end
      end
      add("totem", function() return Cls(f.totemData) end)
      add("aura", function() return Cls(f.auraDataCached) end)
      add("custom", function() return Cls(f.cdmResolvedCustomName) end)
      add("retry", function() return f.cdmNameRetryPending end)
      add("styled", function() return f.cdmBarStyled end)
      add("iconPos", function() return f.cdmLastBarIconPosition end)
      print("  " .. table.concat(parts, " "))
    end
end

SLASH_BARNAMEPROBE1 = "/bnp"
SlashCmdList.BARNAMEPROBE = function(msg)
    msg = (msg or ""):lower()
    if msg == "clear" then wipe(LOG); print("BarNameProbe: 記錄已清"); return end
    if msg:match("^log") then
        local n = tonumber(msg:match("%d+")) or 40
        print(string.format("|cffff4411BarNameProbe|r 最後 %d 筆（共 %d）：", math.min(n, #LOG), #LOG))
        for i = math.max(1, #LOG - n + 1), #LOG do print("  " .. LOG[i]) end
        return
    end
    Dump()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    HookViewer()
    print("|cffff4411BarNameProbe|r 已接上 BuffBarCooldownViewer。/bnp 看狀態，/bnp log 看記錄。")
end)
