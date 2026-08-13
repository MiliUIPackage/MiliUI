-- MiliUI Fix: BugSack 12.1 秘密值防護
--
-- 12.1 之後，只要呼叫堆疊上有秘密值參與，debugstack() / debuglocals() 回傳的就是
-- secret string。!BugGrabber 只擋掉 message（BugGrabber.lua:235 的 issecretvalue 檢查），
-- stack / locals 照樣被寫進錯誤資料庫。BugSack 顯示錯誤時對它做 :gsub() 上色就會炸：
--
--   BugSack/core.lua:218: attempt to index local 'ret' (a secret string value, ...)
--
-- 兩層防護：
--   1. 把資料庫裡的 secret 欄位換成占位字串 —— 搜尋（sack.lua:182 的 :find）、LDB 提示
--      （ldb.lua:52）、SendBugsToUser（core.lua:365 的 :sub）都直接對這些欄位做字串運算。
--   2. 換掉 FormatError / ColorStack / ColorLocals，讓漏網的 secret 也只是印占位字串。
--      （BugSack 自己的 BugGrabbed callback 註冊得比我們早，視窗開著時會搶先重繪。）

local issecretvalue = issecretvalue
if type(issecretvalue) ~= "function" then return end

local PLACEHOLDER = "|cffff4411<秘密值：12.1 不允許插件讀取這段內容>|r"

-----------------------------------------------------------------------
-- 1. 洗掉錯誤資料庫裡的 secret 欄位
--

local function SanitizeError(e)
    if type(e) ~= "table" then return end
    if issecretvalue(e.message) then e.message = PLACEHOLDER end
    if issecretvalue(e.stack) then e.stack = PLACEHOLDER end
    if issecretvalue(e.locals) then e.locals = PLACEHOLDER end
end

local function SanitizeDB()
    local BugGrabber = _G.BugGrabber
    if not BugGrabber or not BugGrabber.GetDB then return end
    local db = BugGrabber:GetDB()
    if type(db) ~= "table" then return end
    for _, e in next, db do
        SanitizeError(e)
    end
end

-----------------------------------------------------------------------
-- 2. 讓 BugSack 的格式化函式對 secret 免疫
--

local function ApplyToBugSack()
    local BugSack = _G.BugSack
    if not BugSack or BugSack.miliuiSecretGuard then return end

    local colorStack = BugSack.ColorStack
    local colorLocals = BugSack.ColorLocals
    if not colorStack or not colorLocals then return end
    BugSack.miliuiSecretGuard = true

    -- tostring(secret) 仍是 secret（BugGrabber 也是這樣測的），所以轉完再檢查一次
    local function safeColor(fn, v)
        local s = tostring(v)
        if issecretvalue(s) then return PLACEHOLDER end
        return fn(s)
    end

    BugSack.ColorStack = function(v) return safeColor(colorStack, v) end
    BugSack.ColorLocals = function(v) return safeColor(colorLocals, v) end

    -- 逐欄位處理：stack 是 secret 時，message 仍然看得到
    -- （欄位可能是 secret，只能做布林測試，不能拿去跟 nil 比較）
    function BugSack:FormatError(err)
        local s = safeColor(colorStack, err.message)
        if err.stack then
            s = s .. "\n" .. safeColor(colorStack, err.stack)
        end
        if not err.locals then
            return ("%dx %s"):format(err.counter or -1, s)
        end
        return ("%dx %s\n\nLocals:\n%s"):format(err.counter or -1, s, safeColor(colorLocals, err.locals))
    end

    -- 補洗一次：MiliUI 載入之前抓到的錯誤沒經過下面的 callback
    SanitizeDB()
end

-----------------------------------------------------------------------

-- owner 留成 upvalue，CallbackRegistry 只拿它當索引，沒人持有會被回收
local callbackOwner = {}
if _G.EventRegistry then
    EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", SanitizeDB, callbackOwner)
end

if _G.BugSack then
    ApplyToBugSack()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, loadedAddon)
        if loadedAddon == "BugSack" then
            ApplyToBugSack()
            self:UnregisterEvent("ADDON_LOADED")
            self:SetScript("OnEvent", nil)
        end
    end)
end
