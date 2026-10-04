------------------------------------------------------------
-- 音效：就緒音效、光環出現／消失音效
--
--   ns.Sound.WantsReady(rec)          這一格有沒有設就緒音效（Glow 決定要不要建探針、武裝）
--   ns.Sound.OnReady(rec)             就緒探針觸發（Glow.FireReady 叫；跟就緒發光同一個訊號）
--   ns.Sound.HookItem(item, rec)      Viewers 第一次看到 item 時叫（只掛增益兩條）
--   ns.Sound.RequestAuraSync()        光環格放好／收起、設定變了：下一幀對一次 AddAuraSound 登記
--   ns.Sound.Preview(name)            設定介面「試聽」（不看總開關、不節流）
--   ns.Sound.Path(name)               LSM 音效名或自訂語音代號 → 路徑字串或檔案編號（查不到 nil）
--   ns.Sound.DisplayName(name)        下拉選單上的字（自訂語音是玩家取的名字）
--   ns.Sound.CustomList()／CustomAdd／CustomEdit／CustomMove／CustomRemove   自訂語音清單（見下）
--   ns.Sound.Speak(text, key, why)    語音播報（文字轉語音；跟音效同一個總開關、靜音與節流）
--   ns.Sound.CanSpeak()               遊戲有沒有文字轉語音的 API（沒有 ⇒ 設定頁那幾列不顯示）
--   ns.Sound.PreviewSpeak(text)       設定介面「試聽」
--   ns.Sound.Logic                    純函式（節流、讀取畫面靜音、合併抵消、登記對帳），
--                                      Tests/Sound_test.lua 測的是這一包
--
-- 設定
--   theme.sound = { enabled, channel }      總開關、聲道（Master／SFX／Music／Ambience／Dialog）
--   spells[spec].overrides[id].readySound   冷卻類：LSM 音效名；nil／false ＝ 無
--   ….gainSound／loseSound                  增益類：出現／消失；暴雪的冷卻格：增益時間開始／結束（S.OnAuraFlag）
--   ….readySpeak／gainSpeak／loseSpeak       語音播報：false ＝ 關、true ＝ 念法術名、字串 ＝ 念那段字
--   音效沒有條層的值，只有逐法術（DB.SPELL_CONST 給 false）。
--   帳號層 customSounds = { { id, name, path }, … }   自訂語音（順序＝玩家排的順序）
--   帳號層 customSoundNext                             下一個 id（不重用，刪掉的代號不會被別筆接走）
--
-- ── 自訂語音 ───────────────────────────────────────────────────────────
-- 玩家自己放在 Interface 底下的音檔：填「Interface 之後的相對路徑」（2026-10-03 起；之前是 AddOns 之後，
-- 玩家問「為什麼要放 AddOns 裡」⇒ 放寬到整個 Interface。舊存檔一次性補上 AddOns\ 前綴，見 S.CustomList）
-- （遊戲沒有列資料夾內容的 API，
-- 只能讓玩家自己打）。逐法術的值存代號 "custom:<id>"，不存名字也不存路徑 ⇒ 改名、改路徑
-- 不必回頭改每一格；刪掉時把所有設定檔裡指到它的格子清掉（不然下拉會露出代號）。
-- 不註冊進 LibSharedMedia：LSM 沒有撤銷，改名／刪除要 /reload 才乾淨，名字也會跟別的插件撞。
-- 帳號層：換設定檔、換角色都看得到同一份清單（逐法術的選擇才跟設定檔走）。
-- 遊戲只認得「啟動時就在」的檔案（C_UIFileAsset.IsKnownFile）：新放的音檔要整個重開遊戲，
-- /reload 不夠 ⇒ 清單上標「找不到檔案」提醒。
--   語音播報跟音效走同一個觸發點（就緒探針、增益 item 的出現／消失批次）；光環格的出現／消失是引擎播的
--   （AddAuraSound），Lua 端沒有訊號 ⇒ 光環格不提供語音播報。
--
-- ── 就緒音效 ───────────────────────────────────────────────────────────
-- 觸發＝就緒探針的 OnCooldownDone（Core/Glow.lua）：GCD 不算、多充能每回一層一次、
-- 只設音效沒開發光也照樣建探針。同一個法術 1.5 秒內不重複響；讀取畫面後 2 秒內靜音。
-- 暴雪 item 有自己的 TriggerAvailableAlert，但它只在玩家替那個法術設了暴雪警示時才被
-- OnUpdate 叫到（NeedsOnUpdateRegistration），不能當通用訊號。
--
-- ── 增益 item 的出現／消失 ────────────────────────────────────────────
-- 後掛勾 item 的 TriggerAuraAppliedAlert／TriggerAuraRemovedAlert（暴雪自己的警示呼叫點，
-- 12.1.0.69933 的 Blizzard_CooldownViewer/CooldownViewer.lua：CooldownViewerMixin:OnUnitAura 裡
-- CheckAuraRemovedAlertTriggers 先、CheckAuraAddedAlertTriggers 後；不管玩家有沒有設暴雪警示都會叫，
-- 空的 alertsByEvent 才在 TriggerAlertEvent 裡擋掉）。掛勾本體不讀任何值：拿 item 查我們自己的
-- 弱鍵表拿 cooldownID（明文，Viewers 存的）。
-- 同一個 UNIT_AURA 裡「消失又出現」（換一個光環實例的刷新）會各叫一次 ⇒ 事件先進批次、下一幀
-- 依「第一個事件推得的之前狀態」對「最後一個事件的之後狀態」合併：沒變就不響（Logic.Net）。
-- 暴雪哪天拿掉這兩支：退回 OnActiveStateChanged 後掛勾＋前後狀態比對（IsActive／IsShown，
-- 讀得到才算），一樣走合併。
-- 圖騰型的增益（不是光環）不經過 UNIT_AURA，暴雪那兩支不會叫 ⇒ 沒有出現／消失音效（README）。
--
-- ── 自訂光環格 ─────────────────────────────────────────────────────────
-- C_UnitAuras.AddAuraSound(Enum.UnitAuraSoundTrigger.Added／Removed, { unitToken, spellID,
-- soundFileName|soundFileID, outputChannel, throttleSeconds })，回傳 auraSoundID，
-- RemoveAuraSound(id) 撤銷。引擎自己播，插件端不看光環。
--   * HasRestrictions：戰鬥中、以及光環是秘密值的情境（C_Secrets.ShouldAurasBeSecret()：副本、
--     鑰石、PvP）呼叫會被當成封鎖動作（ADDON_ACTION_BLOCKED，pcall 攔不住）⇒ 先問再叫，
--     不行就排到脫戰／首領戰結束／過圖再試。
--   * 不跨 /reload：PLAYER_ENTERING_WORLD 先撤掉手上的再全部重登。
--   * 設定變了：對帳（Logic.Diff），多的撤、少的登，同樣的不動。
--   * 音效路徑是登記當下烘死的，總開關／聲道變了也是換一筆登記。
--   * 節流、讀取畫面靜音只管我們自己 PlaySoundFile 的那兩種；光環格由引擎播，只能給 throttleSeconds。
------------------------------------------------------------
local _, ns = ...

ns.Sound = {}
local S = ns.Sound

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
local Logic = {}
S.Logic = Logic

Logic.THROTTLE  = 1.5      -- 同一個法術同一種音效的最短間隔（秒）
Logic.LOAD_MUTE = 2        -- 讀取畫面結束後靜音幾秒

Logic.CHANNELS = { "Master", "SFX", "Music", "Ambience", "Dialog" }
local CHANNEL_OK = {}
for _, c in ipairs(Logic.CHANNELS) do CHANNEL_OK[c] = true end

function Logic.Channel(v)
    return CHANNEL_OK[v] and v or "Master"
end

-- 音效名：只收非空字串（nil／false／"" ＝ 無）
function Logic.Name(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

function Logic.NewThrottle(window)
    return { window = window or Logic.THROTTLE, last = {} }
end

-- 通過就記下時間；被擋的那次不算（不延長窗口）
function Logic.Allow(th, key, now)
    local last = th.last[key]
    if last and now - last < th.window then return false end
    th.last[key] = now
    return true
end

function Logic.NewMute()
    return { loading = false, untilT = 0 }
end

function Logic.OnLoadingStart(m)
    m.loading = true
end

function Logic.OnLoadingEnd(m, now)
    m.loading = false
    m.untilT = math.max(m.untilT, now + Logic.LOAD_MUTE)
end

function Logic.OnEnterWorld(m, now)
    m.untilT = math.max(m.untilT, now + Logic.LOAD_MUTE)
end

function Logic.Muted(m, now)
    return m.loading or now < m.untilT
end

-- 合併：同一批裡某一格的第一個與最後一個事件（"gain"｜"lose"）→ 要響哪一個（nil ＝ 不響）。
-- 第一個是「消失」⇒ 之前在；最後一個是「出現」⇒ 之後在。前後一樣 ＝ 淨變化為零。
function Logic.Net(first, last)
    local before = first == "lose"
    local after = last == "gain"
    if before == after then return nil end
    return last
end

function Logic.NewBatch()
    return { order = {}, byKey = {} }
end

function Logic.Push(b, key, what, payload)
    local e = b.byKey[key]
    if not e then
        e = { first = what }
        b.byKey[key] = e
        b.order[#b.order + 1] = key
    end
    e.last, e.payload = what, payload
end

-- 取出並清空：{ { key, what, payload }, … }（合併後沒有淨變化的不在裡面）
function Logic.Drain(b)
    local out = {}
    for _, key in ipairs(b.order) do
        local e = b.byKey[key]
        local what = Logic.Net(e.first, e.last)
        if what then out[#out + 1] = { key = key, what = what, payload = e.payload } end
    end
    b.order, b.byKey = {}, {}
    return out
end

-- 登記對帳：have = { sig → auraSoundID }，want = { sig → spec }
-- → removes = { { sig, id } … }（照 sig 排序），adds = { { sig, spec } … }
function Logic.Diff(have, want)
    local removes, adds = {}, {}
    for sig, id in pairs(have) do
        if want[sig] == nil then removes[#removes + 1] = { sig = sig, id = id } end
    end
    for sig, spec in pairs(want) do
        if have[sig] == nil then adds[#adds + 1] = { sig = sig, spec = spec } end
    end
    table.sort(removes, function(a, b) return a.sig < b.sig end)
    table.sort(adds, function(a, b) return a.sig < b.sig end)
    return removes, adds
end

-- 自訂語音的代號："custom:<id>"
Logic.CUSTOM_PREFIX = "custom:"
function Logic.CustomValue(id) return Logic.CUSTOM_PREFIX .. tostring(id) end
function Logic.CustomID(v)
    if type(v) ~= "string" then return nil end
    local n = v:match("^custom:(%d+)$")
    return n and tonumber(n) or nil
end

-- 玩家填的路徑 → Interface 底下的相對路徑（反斜線、去掉頭尾空白與開頭的 Interface\）。
-- 整段絕對路徑（…\_retail_\Interface\…）一樣只留 Interface 之後那截。
-- 只收 .ogg／.mp3（PlaySoundFile 只播這兩種）。不合法回 nil, 原因（"empty"｜"ext"）
function Logic.NormalizePath(input)
    if type(input) ~= "string" then return nil, "empty" end
    local p = input:gsub("^%s+", ""):gsub("%s+$", "")
    p = p:gsub("^[\"']+", ""):gsub("[\"']+$", "")       -- 從檔案總管複製時常帶引號
    p = p:gsub("/", "\\"):gsub("\\+", "\\")
    local low = "\\" .. p:lower()
    local _, cut = low:find("\\interface\\", 1, true)
    if cut then p = p:sub(cut) end                       -- low 前面多墊了一個反斜線：cut 剛好是 p 裡的下一個字
    p = p:gsub("^\\+", "")
    if p == "" then return nil, "empty" end
    local ext = (p:match("%.([^.\\]+)$") or ""):lower()
    if ext ~= "ogg" and ext ~= "mp3" then return nil, "ext" end
    return p
end

function Logic.FullPath(rel) return "Interface\\" .. rel end

-- 舊存檔（路徑是 AddOns 之後）→ Interface 之後：補 AddOns\ 前綴。帳號層記 customSoundsRoot 只做一次
Logic.SOUND_ROOT = "Interface"
function Logic.MigrateRoot(sv)
    if type(sv) ~= "table" or sv.customSoundsRoot == Logic.SOUND_ROOT then return false end
    for _, e in ipairs(type(sv.customSounds) == "table" and sv.customSounds or {}) do
        if type(e) == "table" and type(e.path) == "string" and e.path ~= "" then e.path = "AddOns\\" .. e.path end
    end
    sv.customSoundsRoot = Logic.SOUND_ROOT
    return true
end

-- 沒取名字時用檔名（去掉副檔名）
function Logic.DefaultName(rel)
    local file = (rel or ""):match("([^\\]+)$") or rel or ""
    return (file:gsub("%.[^.]+$", ""))
end

-- 一筆登記的簽章（路徑可能是字串或檔案編號）
function Logic.Sig(trigger, spellID, path, channel)
    return table.concat({ tostring(trigger), tostring(spellID), type(path), tostring(path), tostring(channel) }, "|")
end

-- 語音播報要念什麼：true ＝ 法術名；字串 ＝ 那段字（頭尾空白不算，空字串也念法術名）；false／nil／其他 ＝ 不念
-- 法術名讀不到（nil／空字串）時 true 也不念
function Logic.SpeakText(v, spellName)
    local name = (type(spellName) == "string" and spellName ~= "") and spellName or nil
    if v == true then return name end
    if type(v) == "string" then
        local t = (v:gsub("^%s+", ""):gsub("%s+$", ""))
        if t ~= "" then return t end
        return name
    end
    return nil
end

------------------------------------------------------------
-- 設定與播放
------------------------------------------------------------
S.played = 0
S.skipped = 0             -- 讀取畫面靜音／節流擋掉的次數（debug）
S.last = nil              -- { name, why, t }
S.auraErrors = 0

local throttle = Logic.NewThrottle()
local mute = Logic.NewMute()

local function Now()
    return GetTime and GetTime() or 0
end

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function S.Path(name)
    name = Logic.Name(name)
    if not name then return nil end
    local cid = Logic.CustomID(name)
    if cid then
        local e = S.CustomByID(cid)
        return e and type(e.path) == "string" and e.path ~= "" and Logic.FullPath(e.path) or nil
    end
    local lsm = LSM()
    if not lsm then return nil end
    local ok, path = pcall(lsm.Fetch, lsm, "sound", name, true)
    if not ok then return nil end
    if type(path) == "string" and path ~= "" then return path end
    if type(path) == "number" then return path end
    return nil
end

function S.Enabled()
    return ns.Setting("theme", "sound.enabled") ~= false
end

function S.Channel()
    return Logic.Channel(ns.Setting("theme", "sound.channel"))
end

-- 某一格的某種音效（逐法術覆寫；沒有條層）
function S.NameOf(barKey, id, field)
    if id == nil then return nil end
    return Logic.Name(ns.SpellSetting(barKey, id, field))
end

local function PlayRaw(name)
    local path = S.Path(name)
    if path == nil then return false end
    local ok, willPlay = pcall(PlaySoundFile, path, S.Channel())
    return ok and willPlay ~= false
end

-- key：節流用（同一個 key 1.5 秒內只響一次）
function S.Play(name, key, why)
    name = Logic.Name(name)
    if not name or not S.Enabled() then return false end
    local now = Now()
    if Logic.Muted(mute, now) or (key and not Logic.Allow(throttle, key, now)) then
        S.skipped = S.skipped + 1
        return false
    end
    if PlayRaw(name) then
        S.played = S.played + 1
        S.last = { name = name, why = why, t = now }
        return true
    end
    return false
end

function S.Preview(name)
    return PlayRaw(name)
end

------------------------------------------------------------
-- 自訂語音清單（帳號層）
------------------------------------------------------------
local SOUND_FIELDS = { "readySound", "gainSound", "loseSound" }

local function Account() return MiliUI_CooldownManager_DB end

function S.CustomList()
    local sv = Account()
    if type(sv) ~= "table" then return {} end
    if type(sv.customSounds) ~= "table" then sv.customSounds = {} end
    Logic.MigrateRoot(sv)
    return sv.customSounds
end

function S.CustomByID(id)
    for _, e in ipairs(S.CustomList()) do
        if e.id == id then return e end
    end
    return nil
end

-- 下拉與提示上的字：自訂語音是玩家取的名字，其餘就是 LSM 名稱
function S.DisplayName(v)
    local cid = Logic.CustomID(v)
    if not cid then return v end
    local e = S.CustomByID(cid)
    return e and e.name or nil
end

-- 檔案在不在：true／false；API 不在 ⇒ nil（不知道）
function S.CustomFileKnown(e)
    local api = C_UIFileAsset and C_UIFileAsset.IsKnownFile
    if type(api) ~= "function" or not (e and e.path) then return nil end
    local ok, known = pcall(api, Logic.FullPath(e.path))
    if not ok then return nil end
    return known and true or false
end

local function CustomChanged()
    S.RequestAuraSync()            -- 光環格的登記是路徑烘死的：改了路徑要換一筆
    if ns.Fire then ns.Fire("CustomSoundsChanged") end
end

-- name 空白 ⇒ 用檔名。回傳 entry；路徑不合法回 nil, 原因
function S.CustomAdd(name, path)
    local rel, why = Logic.NormalizePath(path)
    if not rel then return nil, why end
    local sv = Account()
    if type(sv) ~= "table" then return nil, "empty" end
    local list = S.CustomList()
    local id = math.max(tonumber(sv.customSoundNext) or 1, 1)
    for _, e in ipairs(list) do
        if type(e.id) == "number" and e.id >= id then id = e.id + 1 end
    end
    sv.customSoundNext = id + 1
    local e = { id = id, name = (name and name ~= "") and name or Logic.DefaultName(rel), path = rel }
    list[#list + 1] = e
    CustomChanged()
    return e
end

function S.CustomEdit(index, name, path)
    local e = S.CustomList()[index]
    if not e then return nil, "empty" end
    local rel, why = Logic.NormalizePath(path)
    if not rel then return nil, why end
    e.name = (name and name ~= "") and name or Logic.DefaultName(rel)
    e.path = rel
    CustomChanged()
    return e
end

function S.CustomMove(index, delta)
    local list = S.CustomList()
    local to = index + delta
    if not (list[index] and list[to]) then return false end
    list[index], list[to] = list[to], list[index]
    CustomChanged()
    return true
end

-- 刪掉一筆：所有設定檔、所有專精裡指到它的格子一起清掉。回傳清掉幾格
function S.CustomRemove(index)
    local list = S.CustomList()
    local e = list[index]
    if not e then return 0 end
    table.remove(list, index)
    local value, cleared = Logic.CustomValue(e.id), 0
    local function Clean(o)
        for _, f in ipairs(SOUND_FIELDS) do
            if o[f] == value then o[f] = nil; cleared = cleared + 1 end
        end
        return next(o) == nil
    end
    for _, profile in pairs((Account() or {}).profiles or {}) do
        for _, sp in pairs(type(profile.spells) == "table" and profile.spells or {}) do
            local all = type(sp) == "table" and sp.overrides
            for id, o in pairs(type(all) == "table" and all or {}) do
                if type(o) == "table" and Clean(o) then all[id] = nil end
            end
        end
        -- 職業層／戰隊層的自訂項目：覆寫跟著那一筆走（Core/DB.lua）
        if ns.DB and ns.DB.EachWideList then
            ns.DB.EachWideList(profile, function(list)
                for _, ce in ipairs(list) do
                    if type(ce) == "table" and type(ce.overrides) == "table" and Clean(ce.overrides) then
                        ce.overrides = nil
                    end
                end
            end)
        end
    end
    -- 上面直接改了覆寫表（不經 DB.SetOverride）：讀取端的 memo 作廢點（Core/DB.lua「寫入世代」）
    if ns.DB and ns.DB.TouchOverrides then ns.DB.TouchOverrides() end
    CustomChanged()
    return cleared
end

------------------------------------------------------------
-- 語音播報（文字轉語音）
--
-- C_VoiceChat.SpeakText(voiceID, text, rate, volume, overlap)（12.x 生成文件：voiceID／rate／volume／overlap
-- NeverSecret、text ConditionalSecret、AllowedWhenTainted、沒標 HasRestrictions）。voiceID 從
-- C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)，速率／音量用玩家在遊戲「文字轉語音」設定的值，
-- 讀不到用 0／100。全部 pcall。API 不在 ⇒ S.CanSpeak() 假，設定頁整列不顯示、觸發點什麼都不做。
-- 跟音效同一個總開關、同一套讀取畫面靜音與節流（key 加 "speak:" 前綴，音效與語音互不擋）。
------------------------------------------------------------
S.spoken = 0

function S.CanSpeak()
    local V = C_VoiceChat
    return type(V) == "table" and type(V.SpeakText) == "function"
end

local function PlainNumber(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or v == nil or ns.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

local function VoiceSettings()
    local T = C_TTSSettings
    if type(T) ~= "table" then return nil end
    local E = Enum and Enum.TtsVoiceType
    local voiceID = PlainNumber(T.GetVoiceOptionID, (E and E.Standard) or 0)
    if not voiceID then return nil end
    return voiceID, PlainNumber(T.GetSpeechRate) or 0, PlainNumber(T.GetSpeechVolume) or 100
end

local function SpeakRaw(text)
    if type(text) ~= "string" or text == "" or not S.CanSpeak() then return false end
    local voiceID, rate, volume = VoiceSettings()
    if not voiceID then return false end
    return (pcall(C_VoiceChat.SpeakText, voiceID, text, rate, volume, false))
end

-- 這一格的名字（明文才念）
function S.SpellName(id)
    local info = id ~= nil and ns.Catalog and ns.Catalog.Info and ns.Catalog.Info(id) or nil
    local n = info and info.name
    if type(n) ~= "string" or ns.IsSecret(n) then return nil end
    return n
end

-- 某一格某個觸發要念的字（沒設／念不出來 ＝ nil）
function S.SpeakTextOf(barKey, id, field)
    if id == nil or not S.CanSpeak() then return nil end
    local v = ns.SpellSetting(barKey, id, field)
    if v == nil or v == false then return nil end
    return Logic.SpeakText(v, S.SpellName(id))
end

-- key：節流用（跟音效同一個窗口）
function S.Speak(text, key, why)
    if type(text) ~= "string" or text == "" or not S.Enabled() then return false end
    local now = Now()
    if Logic.Muted(mute, now) or (key and not Logic.Allow(throttle, "speak:" .. key, now)) then
        S.skipped = S.skipped + 1
        return false
    end
    if SpeakRaw(text) then
        S.spoken = S.spoken + 1
        S.last = { name = text, why = why, t = now }
        return true
    end
    return false
end

-- 設定介面「試聽」（不看總開關、不節流）
function S.PreviewSpeak(text)
    return SpeakRaw(text)
end

------------------------------------------------------------
-- 就緒音效（Glow 叫）
------------------------------------------------------------
function S.WantsReady(rec)
    if not rec or rec.cooldownID == nil or not S.Enabled() then return false end
    return S.NameOf(rec.claimKey, rec.cooldownID, "readySound") ~= nil
        or S.SpeakTextOf(rec.claimKey, rec.cooldownID, "readySpeak") ~= nil
end

function S.OnReady(rec)
    if not rec or rec.cooldownID == nil then return end
    local key = "ready:" .. tostring(rec.cooldownID)
    S.Play(S.NameOf(rec.claimKey, rec.cooldownID, "readySound"), key, "ready")
    S.Speak(S.SpeakTextOf(rec.claimKey, rec.cooldownID, "readySpeak"), key, "ready")
end

------------------------------------------------------------
-- 增益 item：出現／消失（批次、下一幀合併）
------------------------------------------------------------
local batch = Logic.NewBatch()
local batchArmed = false

local function FlushBatch()
    batchArmed = false
    for _, e in ipairs(Logic.Drain(batch)) do
        local id = e.payload
        local field = e.what == "gain" and "gainSound" or "loseSound"
        local key = e.what .. ":" .. tostring(id)
        S.Play(S.NameOf(nil, id, field), key, e.what)
        S.Speak(S.SpeakTextOf(nil, id, e.what == "gain" and "gainSpeak" or "loseSpeak"), key, e.what)
    end
end

-- 這一格出現／消失時有沒有東西要響（音效或語音）
local function HasAuraSound(id)
    return S.NameOf(nil, id, "gainSound") ~= nil or S.NameOf(nil, id, "loseSound") ~= nil
        or S.SpeakTextOf(nil, id, "gainSpeak") ~= nil or S.SpeakTextOf(nil, id, "loseSpeak") ~= nil
end

local function Push(rec, what)
    local id = rec and rec.cooldownID
    -- 兩種都要排（只設了出現音效，也要讓「消失又出現」抵消掉）；兩種都沒設就不排
    if id == nil or ns.released or not HasAuraSound(id) then return end
    Logic.Push(batch, rec, what, id)
    if not batchArmed then
        batchArmed = true
        ns.Defer(FlushBatch)
    end
end
S.PushAura = Push        -- 測試／除錯用

local function OnApplied(item)
    Push(ns.Viewers.frames[item], "gain")
end

local function OnRemoved(item)
    Push(ns.Viewers.frames[item], "lose")
end

-- 退路：暴雪的布林 getter（pcall、明文才算）
local function ReadBool(item, getter)
    local fn = item[getter]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, item)
    if not ok or v == nil or ns.IsSecret(v) then return nil end
    if type(v) ~= "boolean" then return v and true or false end
    return v
end

local function OnActiveChanged(item)
    local rec = ns.Viewers.frames[item]
    if not rec then return end
    local now = ReadBool(item, "IsActive")
    if now == nil then now = ReadBool(item, "IsShown") end
    if now == nil then return end                 -- 讀不到：不猜
    local before = nil                            -- ⚠ 不能寫成 a and b or nil：false 會被吃掉
    if rec.soundActiveID == rec.cooldownID then before = rec.soundActive end
    rec.soundActive, rec.soundActiveID = now, rec.cooldownID
    if before == nil or before == now then return end
    Push(rec, now and "gain" or "lose")
end

-- 暴雪的冷卻格（核心／輔助）：「增益出現／消失」＝暴雪開始／停止倒增益時間（玩家回報 2026-10-03：狂暴觸發時要語音）。
-- Decorate 的 SetUseAuraDisplayTime 後掛勾每次都叫（值是 Plain 過的明文；秘密值／讀不到 ＝ nil ⇒ 不動）。
-- 暴雪一次刷新常連叫兩次同樣的值 ⇒ 只在值真的變了才排；第一次看到（掛勾時讀的初值、/reload 時增益還在）
-- 只記不響；框被暴雪回收給別的法術（cooldownID 換了）也重新起算。走同一個批次（下一幀合併、節流、讀取靜音）。
-- 設定欄位跟增益格同一組（gainSound／loseSound／gainSpeak／loseSpeak）。
function S.OnAuraFlag(rec, now)
    if not rec or rec.custom or rec.cooldownID == nil or type(now) ~= "boolean" then return end
    if ns.Viewers.AURA_KIND and ns.Viewers.AURA_KIND[rec.barKey] then return end
    local before = nil                            -- ⚠ 不能寫成 a and b or nil：false 會被吃掉
    if rec.soundFlagID == rec.cooldownID then before = rec.soundFlag end
    rec.soundFlag, rec.soundFlagID = now, rec.cooldownID
    if before == nil or before == now then return end
    Push(rec, now and "gain" or "lose")
end

S.hookMode = nil          -- "alert" | "active" | nil（debug）

function S.HookItem(item, rec)
    if rec.soundHooked or not (ns.Viewers.AURA_KIND and ns.Viewers.AURA_KIND[rec.barKey]) then return end
    rec.soundHooked = true
    if type(item.TriggerAuraAppliedAlert) == "function" and type(item.TriggerAuraRemovedAlert) == "function" then
        hooksecurefunc(item, "TriggerAuraAppliedAlert", ns.Guard(OnApplied))
        hooksecurefunc(item, "TriggerAuraRemovedAlert", ns.Guard(OnRemoved))
        S.hookMode = S.hookMode or "alert"
    elseif type(item.OnActiveStateChanged) == "function" then
        hooksecurefunc(item, "OnActiveStateChanged", ns.Guard(OnActiveChanged))
        S.hookMode = "active"
    end
end

------------------------------------------------------------
-- 自訂光環格：AddAuraSound 登記
------------------------------------------------------------
local have = {}            -- sig → auraSoundID
local syncArmed = false
local retryArmed = false
S.auraPending = false

local function API()
    local U = C_UnitAuras
    if not (U and U.AddAuraSound and U.RemoveAuraSound) then return nil end
    return U
end

local function Triggers()
    local E = Enum and Enum.UnitAuraSoundTrigger
    return (E and E.Added) or 0, (E and E.Removed) or 2
end

local function AurasSecret()
    local fn = C_Secrets and C_Secrets.ShouldAurasBeSecret
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn)
    if not ok then return false end
    if ns.IsSecret(v) then return true end
    return v == true
end

-- 現在能不能動登記表（不行的時候叫下去是封鎖動作，pcall 攔不住）
local function CanChange()
    if InCombatLockdown() then return false end
    return not AurasSecret()
end
S.CanChangeRegistrations = CanChange

function S.WantAuraSounds()
    local want = {}
    local CU = ns.Custom
    if not (API() and S.Enabled() and CU and CU.Records) then return want end
    local added, removed = Triggers()
    local channel = S.Channel()
    for _, rec in pairs(CU.Records()) do
        if rec.kind == "aura" and rec.placedBar and rec.cooldownID and type(rec.spellID) == "number" then
            -- 多法術的光環格（嗜血那種）：每個法術各登一筆（引擎只認單一 spellID）
            local ids = (CU.AuraIDsOf and CU.AuraIDsOf(rec)) or { rec.spellID }
            for field, trig in pairs({ gainSound = added, loseSound = removed }) do
                local path = S.Path(S.NameOf(rec.placedBar, rec.cooldownID, field))
                if path ~= nil then
                    for _, sid in ipairs(ids) do
                        local sig = Logic.Sig(trig, sid, path, channel)
                        want[sig] = { trigger = trig, spellID = sid, path = path, channel = channel }
                    end
                end
            end
        end
    end
    return want
end

local function Register(spec)
    local U = API()
    local info = { unitToken = "player", spellID = spec.spellID, outputChannel = spec.channel,
                   throttleSeconds = Logic.THROTTLE }
    if type(spec.path) == "number" then info.soundFileID = spec.path else info.soundFileName = spec.path end
    local ok, id = pcall(U.AddAuraSound, spec.trigger, info)
    if not (ok and id) then
        -- 萬一節流參數被拒（非法值會整筆拒收）：不帶節流再試一次
        info.throttleSeconds = nil
        ok, id = pcall(U.AddAuraSound, spec.trigger, info)
    end
    if ok and id then return id end
    S.auraErrors = S.auraErrors + 1
    S.lastAuraError = ok and "no id" or tostring(id)
    return nil
end

local RETRY_EVENTS = { "PLAYER_REGEN_ENABLED", "ENCOUNTER_END", "ZONE_CHANGED_NEW_AREA", "CHALLENGE_MODE_COMPLETED" }

local function ArmRetry()
    if retryArmed then return end
    retryArmed = true
    for _, ev in ipairs(RETRY_EVENTS) do
        ns.Events.Register(ev, "sound_retry", function() S.RequestAuraSync() end)
    end
end

local function DisarmRetry()
    if not retryArmed then return end
    retryArmed = false
    for _, ev in ipairs(RETRY_EVENTS) do ns.Events.Unregister(ev, "sound_retry") end
end

local function SyncAuraSounds(reset)
    syncArmed = false
    local U = API()
    if not U then return end
    if not CanChange() then
        S.auraPending = true
        ArmRetry()
        return
    end
    S.auraPending = false
    DisarmRetry()
    if reset then
        for sig, id in pairs(have) do
            pcall(U.RemoveAuraSound, id)
            have[sig] = nil
        end
    end
    local removes, adds = Logic.Diff(have, S.WantAuraSounds())
    for _, r in ipairs(removes) do
        pcall(U.RemoveAuraSound, r.id)
        have[r.sig] = nil
    end
    for _, a in ipairs(adds) do
        local id = Register(a.spec)
        if id then have[a.sig] = id end
    end
end

function S.RequestAuraSync()
    if syncArmed then return end
    syncArmed = true
    ns.Defer(SyncAuraSounds, false)
end

function S.AuraCount()
    local n = 0
    for _ in pairs(have) do n = n + 1 end
    return n
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function S.DebugLine()
    local last = S.last
    local lastText = last and ("%s（%s，%.1f 秒前）"):format(tostring(last.name), tostring(last.why), Now() - last.t) or "無"
    return ("  音效：%s  聲道 %s  光環格登記 %d 筆%s  增益掛勾 %s  播過 %d 次、念過 %d 次（語音 API %s）（擋掉 %d）  最近：%s%s")
        :format(S.Enabled() and "開" or "關", S.Channel(), S.AuraCount(),
                S.auraPending and "（待登記）" or "", tostring(S.hookMode), S.played, S.spoken,
                S.CanSpeak() and "有" or "沒有", S.skipped, lastText,
                S.lastAuraError and ("  登記失敗 %d 次：%s"):format(S.auraErrors, S.lastAuraError) or "")
end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
local initialized = false
function S.Init()
    if initialized then return end
    initialized = true
    local E = ns.Events
    -- 進場（登入、/reload、過圖）：靜音 2 秒；光環格的登記全部重來（不跨 /reload）
    Logic.OnEnterWorld(mute, Now())
    E.Register("PLAYER_ENTERING_WORLD", "sound", function()
        Logic.OnEnterWorld(mute, Now())
        syncArmed = true
        ns.Defer(SyncAuraSounds, true)
    end)
    E.Register("LOADING_SCREEN_ENABLED", "sound", function() Logic.OnLoadingStart(mute) end)
    E.Register("LOADING_SCREEN_DISABLED", "sound", function() Logic.OnLoadingEnd(mute, Now()) end)
    ns.RegisterCallback("ProfileChanged", "sound", function() S.RequestAuraSync() end)
    ns.RegisterCallback("SpecChanged", "sound", function() S.RequestAuraSync() end)
end
