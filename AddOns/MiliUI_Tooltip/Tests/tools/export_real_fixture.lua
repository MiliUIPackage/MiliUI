------------------------------------------------------------
-- 把 /mtip record 存進 SavedVariables 的記錄轉成 Tests/fixtures/real_<locale>.lua，
-- 並把別家插件後加行裡的角色名／伺服器／公會名換成假名（repo 公開，不放個人資料）。
--
--   lua Tests/tools/export_real_fixture.lua <SV 檔> <輸出檔> <TooltipInfoSharedDocumentation.lua> <筆號...>
--
-- 第三個參數是 wow-ui-source 的 Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua，
-- 用來把 lines[].type 的 Enum 數字對成 typeName。先用 summary 模式看筆號：最後一個參數給 "summary"。
-- 測試只依賴「那一行存在、進附屬框」，不依賴名字，所以假名不影響斷言。
------------------------------------------------------------
local svPath, outPath, docPath = arg[1], arg[2], arg[3]
local picks, summary = {}, false
for i = 4, #arg do if arg[i] == "summary" then summary = true else picks[#picks + 1] = tonumber(arg[i]) end end
local env = {}
assert(loadfile(svPath, "t", env))()
local dumps = env.MiliUI_Tooltip_DB.dumps
if summary then
  for i, e in ipairs(dumps) do
    local d = e.data or {}
    local first = d.lines and d.lines[1] and tostring(d.lines[1].leftText) or ""
    print(string.format("%2d %-5s id=%-8s tip=%-18s lines=%-3s data=%-3s %s", i, tostring(e.kind), tostring(d.id),
      tostring(e.tip), tostring(e.numLines), d.lines and #d.lines or 0, first))
  end
  return
end
local names = {}
local doc = io.open(docPath):read("a")
local block = doc:match('Name = "TooltipDataLineType".-Fields =%s*(%b{})')
for name, value in block:gmatch('Name = "([%w_]+)",%s*Type = "TooltipDataLineType",%s*EnumValue = (%d+)') do names[tonumber(value)] = name end
local function ser(v, indent)
  local t = type(v)
  if t == "string" then return string.format("%q", v) end
  if t == "number" or t == "boolean" then return tostring(v) end
  if t ~= "table" then return "nil" end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
  end)
  local parts = {}
  for _, k in ipairs(keys) do
    local key = type(k) == "number" and ("[" .. k .. "]") or (k:match("^[%a_][%w_]*$") and k or ("[" .. string.format("%q", k) .. "]"))
    parts[#parts + 1] = indent .. "  " .. key .. " = " .. ser(v[k], indent .. "  ")
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end
local out = {}
out[#out + 1] = "-- 真實的 12.1.5 zhTW 提示資料（/mtip record 2026-10-18 抓的，Tests/fixtures/export 產生，不要手改）"
out[#out + 1] = "-- 每筆：kind、tip、locale、numLines（FontString 行數）、data（TooltipData 整張，lines[].type 是 Enum 數字，typeName 是對照名）、"
out[#out + 1] = "-- lines（post-call 當下 1..numLines 的 FontString 文字與顏色；lineIndex 不在 data 裡的就是別家後加的行）"
out[#out + 1] = "return {"
for _, i in ipairs(picks) do
  local e = dumps[i]
  local copy = { kind = e.kind, tip = e.tip, locale = e.locale, numLines = e.numLines, data = e.data, lines = e.lines, source = i }
  for _, l in ipairs(copy.data.lines or {}) do l.typeName = names[l.type] end
  out[#out + 1] = ser(copy, "  ") .. ","
end
out[#out + 1] = "}"
local f = assert(io.open(outPath, "w"))
f:write(table.concat(out, "\n"), "\n")
f:close()
print("wrote " .. outPath .. " (" .. #picks .. " entries)")

------------------------------------------------------------
-- 假名化（寫完檔再掃一次）
------------------------------------------------------------
do
  local src = io.open(outPath):read("a")
  local aliases, order = {}, 0
  local function alias(name)
    if not aliases[name] then order = order + 1; aliases[name] = "角色" .. order end
    return aliases[name]
  end
  -- 種族圖示後面的 |cff......名字(-伺服器)|r
  src = src:gsub("(|A:raceicon128[^|]*|a |cff%x%x%x%x%x%x)([^|%-]+)(%-?[^|]*)|r", function(pre, name, realm)
    return pre .. alias(name) .. (realm ~= "" and "-伺服器" or "") .. "|r"
  end)
  -- 公會旗幟後面的 |cff......公會名|r-伺服器
  src = src:gsub("(|A:communities%-guildbanner[^|]*|a |cff%x%x%x%x%x%x)([^|]+)|r%-([^\"\\]+)", function(pre)
    return pre .. "公會|r-伺服器"
  end)
  for real, fake in pairs(aliases) do src = src:gsub(real:gsub("%p", "%%%0"), fake) end
  io.open(outPath, "w"):write(src)
  print(("anonymized: %d character names"):format(order))
end
