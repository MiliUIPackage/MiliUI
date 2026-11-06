------------------------------------------------------------
-- MiliUIMedia.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua AddOns/MiliUI/Libs/MiliUIMedia/Tests/MiliUIMedia_test.lua
--   （.claude/scripts/run_tests.sh 會一起跑）
--
-- 守的是命名規則本身：登記名 `MiliUI <英文名>`、中文顯示名 `米利UI: <譯名>`、繁簡都要有、
-- 米利的材質照名冊順序排前面。新增材質時漏了譯名或前綴寫錯，這裡會先叫。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local LIB_PATH = here .. "/../MiliUIMedia.lua"

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

local clientLocale = "zhTW"
_G.GetLocale = function() return clientLocale end

local ns = {}
assert(loadfile(LIB_PATH))("MiliUIMedia_test", ns)
local MM = ns.MiliMedia

-- 名冊的格式
local seen = {}
for i, def in ipairs(MM.TEXTURES) do
    check("登記名是 MiliUI <英文名>：" .. tostring(def.name),
        type(def.name) == "string" and def.name:match("^MiliUI [A-Z][A-Za-z0-9]*[A-Za-z0-9 ]*$") ~= nil and not def.name:match(" $"))
    check("登記名不重複：" .. def.name, not seen[def.name])
    seen[def.name] = true
    for _, loc in ipairs({ "zhTW", "zhCN" }) do
        local text = def[loc]
        check(def.name .. " 有 " .. loc .. " 譯名", type(text) == "string" and text ~= "")
        check(def.name .. " 的 " .. loc .. " 譯名不自帶前綴／半形括號",
            type(text) == "string" and not text:find("米利", 1, true) and not text:find("[%(%):]"))
        eq(def.name .. " 的 " .. loc .. " 顯示名", MM.TextureLabel(def.name, loc), "米利UI: " .. tostring(text))
    end
    eq(def.name .. " 在其他語系照登記名", MM.TextureLabel(def.name, "deDE"), def.name)
    eq(def.name .. " 在英文照登記名", MM.TextureLabel(def.name, "enUS"), def.name)
end
eq("第一款是套組預設材質", MM.TEXTURES[1].name, "MiliUI Satin")

-- 顯示名
eq("繁中", MM.TextureLabel("MiliUI Satin"), "米利UI: 緞面")
clientLocale = "zhCN"
eq("簡中（跟著客戶端語系）", MM.TextureLabel("MiliUI Satin"), "米利UI: 缎面")
eq("簡中的變體", MM.TextureLabel("MiliUI Rainbow Soft"), "米利UI: 彩虹（柔和）")
clientLocale = "zhTW"
eq("不是自製的回原名", MM.TextureLabel("Minimalist"), "Minimalist")
eq("nil 回 nil", MM.TextureLabel(nil), nil)
check("IsOwnTexture", MM.IsOwnTexture("MiliUI Rainbow") and not MM.IsOwnTexture("Melli") and not MM.IsOwnTexture(nil))

-- 拆清單
local list = { "Lyfe", "Melli", "MiliUI Rainbow", "MiliUI Rainbow Soft", "MiliUI Satin", "Minimalist" }
local own, rest = MM.TextureItems(list)
eq("own：三款都在", #own, 3)
eq("own：照名冊順序（不是字母順序）", own[1].value .. "|" .. own[2].value .. "|" .. own[3].value,
    "MiliUI Satin|MiliUI Rainbow|MiliUI Rainbow Soft")
eq("own：顯示名在地化", own[1].text, "米利UI: 緞面")
eq("rest：其餘照原順序", rest[1].value .. "|" .. rest[2].value .. "|" .. rest[3].value, "Lyfe|Melli|Minimalist")
eq("rest：不含自製的", #rest, 3)
eq("rest：原名", rest[3].text, "Minimalist")

-- 清單裡沒有的自製材質不出現（別的插件沒登記）
own, rest = MM.TextureItems({ "Melli", "MiliUI Satin" })
eq("沒登記的不列", #own, 1)

-- always：自己帶檔的照列、value 用自己的 token
own, rest = MM.TextureItems({ "Melli", "MiliUI Rainbow" }, { ["MiliUI Satin"] = "satin" })
eq("always：清單裡沒有也列", own[1].value, "satin")
eq("always：顯示名照舊在地化", own[1].text, "米利UI: 緞面")
eq("always：別人登記的接在後面、value 是登記名", own[2] and own[2].value, "MiliUI Rainbow")
eq("always：其餘不受影響", #rest, 1)

-- 清單同時有登記名：不重複
own, rest = MM.TextureItems({ "MiliUI Satin" }, { ["MiliUI Satin"] = "satin" })
eq("always ＋清單裡也有：只列一次", #own, 1)
eq("always 的 value 優先", own[1].value, "satin")
eq("登記名不漏進 rest", #rest, 0)

-- 沒有 LSM（清單 nil／空）
own, rest = MM.TextureItems(nil, { ["MiliUI Satin"] = "MiliUI Satin" })
eq("清單 nil：自己帶的照列", #own, 1)
eq("清單 nil：rest 空", #rest, 0)
own, rest = MM.TextureItems(nil)
eq("清單 nil、沒 always：兩段都空", #own + #rest, 0)

-- 髒資料
own, rest = MM.TextureItems({ "Melli", 42, false, "MiliUI Satin" })
eq("非字串略過", #own + #rest, 2)

print(("MiliUIMedia_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
