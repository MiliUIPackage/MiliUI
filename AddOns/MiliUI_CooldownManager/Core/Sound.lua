------------------------------------------------------------
-- 音效：就緒音效、充能滿音效、光環出現／消失音效、層數增加音效
--
--   ns.Sound.WantsReady(rec)          這一格有沒有設就緒音效（Glow 決定要不要建探針、武裝）
--   ns.Sound.OnReady(rec)             就緒探針觸發（Glow.FireReady 叫；跟就緒發光同一個訊號）
--   ns.Sound.SyncFull(rec, barKey, hidden)   充能滿音效的監看表對帳（Glow.SyncFull 叫：排版、設定變了）
--   ns.Sound.UnwatchFull(rec)         停放／收起：出監看表（Glow.OnParked 叫）
--   ns.Sound.OnBuffItemChanged(old, new)   暴雪增益 item 換了身分（Viewers 叫）：有設層數增加音效的才重登
--   ns.Sound.HookItem(item, rec)      Viewers 第一次看到 item 時叫（只掛增益兩條）
--   ns.Sound.RequestAuraSync()        光環格（含飾品欄的增益疊層）放好／收起、暴雪增益 item 換了身分、設定變了：
--                                      下一幀對一次 AddAuraSound 登記
--   ns.Sound.PlayNamed(name, key)     不屬於任何一格的音效（虛空化身的門檻規則）：同 S.Play 的總開關／靜音／節流
--   ns.Sound.Preview(name)            設定介面「試聽」（不看總開關、不節流）
--   ns.Sound.Path(name)               LSM 音效名或自訂語音代號 → 路徑字串或檔案編號（查不到 nil）
--   ns.Sound.DisplayName(name)        下拉選單上的字（自訂語音是玩家取的名字）
--   ns.Sound.CustomList()／CustomAdd／CustomEdit／CustomMove／CustomRemove   自訂語音清單（見下）
--   ns.Sound.Speak(text, key, why)    語音播報（文字轉語音；跟音效同一個總開關、靜音與節流）
--   ns.Sound.CanSpeak()               遊戲有沒有文字轉語音的 API（沒有 ⇒ 設定頁那幾列不顯示）
--   ns.Sound.PreviewSpeak(text)       設定介面「試聽」
--   ns.Sound.SyncCast()               施放後提醒的事件註冊與排程對帳（設定變了、換設定檔、換專精、進場叫）
--   ns.Sound.TalentOK(id)             這一格的天賦條件（soundTalent）現在過不過（只查快取）
--   ns.Sound.Logic                    純函式（節流、讀取畫面靜音、合併抵消、登記對帳、施放後提醒的時間表、天賦條件），
--                                      Tests/Sound_test.lua 測的是這一包
--
-- 設定
--   theme.sound = { enabled, channel }      總開關、聲道（Master／SFX／Music／Ambience／Dialog）
--   spells[spec].overrides[id].readySound   冷卻類：LSM 音效名；nil／false ＝ 無
--   ….fullSound                             冷卻類（只有充能技能）：所有充能都回滿的那一刻
--   ….gainSound／loseSound                  增益類：出現／消失；暴雪的冷卻格：增益持續時間開始／結束（S.OnAuraFlag）
--   ….stackSound                            增益類：每多一層（引擎播，AddAuraSound；沒有語音播報）
--   ….readySpeak／fullSpeak／gainSpeak／loseSpeak   語音播報：false ＝ 關、true ＝ 念法術名、字串 ＝ 念那段字
--   ….castSound／castSpeak                  施放後提醒：施放成功後 castDelay 秒響（音效／語音，語意同上）
--   ….castDelay                             0～60 秒（0 ＝ 施放當下）；castCountdown 0～5（0 ＝ 不倒數），見「施放後提醒」
--   ….soundTalent                           false ＝ 不限；{ id = 天賦法術 ID, need = true|false }，見「天賦條件」
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
-- ── 充能滿音效 ─────────────────────────────────────────────────────────
-- 就緒音效在充能技能上是「每回一層響一次」（可以用了）；充能滿音效是「全部回滿響一次」（再不用就浪費）。
-- 判斷跟充能滿了發光同一套（Core/Glow.lua 的 G.FullSpellOf＋G.ReadFull：maxCharges > 1 而且 isActive 明文 false；
-- 不讀 currentCharges），用三態：滿／沒滿／讀不到。只有「上一次明確沒滿 → 這一次明確滿了」才響；
-- 讀不到把記的狀態清成「不知道」（秘密 → 明文那一下不算轉變，寧可漏響也不誤響）。進表當下只記不響。
-- 監看表自己一份（弱鍵 rec → { 法術, cooldownID, 狀態 }），跟發光的 fullWatch 分開：發光沒開也要能響。
-- 只有設了 fullSound／fullSpeak 的格進表；表空時不聽 SPELL_UPDATE_CHARGES。換天賦不再是充能技能 ⇒ 出表。
-- 暴雪的冷卻格與自訂法術才有（FullSpellOf 涵蓋）；裝備欄、物品、光環不做。
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
-- C_UnitAuras.AddAuraSound(Enum.UnitAuraSoundTrigger.Added／ApplicationsIncreased／Removed, { unitToken, spellID,
-- soundFileName|soundFileID, outputChannel, throttleSeconds })，回傳 auraSoundID，
-- RemoveAuraSound(id) 撤銷。引擎自己播，插件端不看光環。
--   * HasRestrictions：戰鬥中、以及光環是秘密值的情境（C_Secrets.ShouldAurasBeSecret()：副本、
--     鑰石、PvP）呼叫會被當成封鎖動作（ADDON_ACTION_BLOCKED，pcall 攔不住）⇒ 先問再叫，
--     不行就排到脫戰／首領戰結束／過圖再試。
--   * 不跨 /reload：PLAYER_ENTERING_WORLD 先撤掉手上的再全部重登。
--   * 設定變了：對帳（Logic.Diff），多的撤、少的登，同樣的不動。
--   * 音效路徑是登記當下烘死的，總開關／聲道變了也是換一筆登記。
--   * 節流、讀取畫面靜音只管我們自己 PlaySoundFile 的那兩種；光環格由引擎播，只能給 throttleSeconds。
--
-- ── 層數增加音效 ───────────────────────────────────────────────────────
-- 一樣走 AddAuraSound（ApplicationsIncreased）：Lua 端不碰層數（秘密值）。每多一層響一次，0→1 算「出現」不算增加
-- ⇒ 最多 2 層的增益（殺戮機器）正好在疊到 2 層那一刻響。節流用 0.3 秒（Logic.STACK_THROTTLE；快速連疊不被吞），
-- 節流值進簽章（改了會換一筆）。沒有語音播報（引擎播的，沒有訊號）。
--   * 光環格（含飾品欄的增益疊層）：跟出現／消失同一條路，多一個欄位對應。
--   * 暴雪的增益 item（增益圖示列／增益長條，搬進自訂群組也一樣）：它們的出現／消失走 Lua 掛勾，層數只能走引擎。
--     法術 ID 用目錄的 spellID、overrideTooltipSpellID（增益類常靠它指到真正的光環）加上全部 linkedSpellIDs，
--     去重後各登一筆（引擎只在那個 ID 的光環疊層時播，多登無害）。
--     列舉的是檢視器池子裡作用中、有身分的 item，**不看放沒放格**：增益不在時暗格會被停放、增益回來才放格，
--     那常在戰鬥中，登記不了 ⇒ 登記要跟身分走，不能跟放格走（出現／消失的掛勾一樣不看放格）。
--     item 換身分（Viewers 的 SetCooldownID／ClearCooldownID 後掛勾）時，前後任一個有設層數增加音效才重登。
--
-- ── 施放後提醒（castSound／castSpeak／castDelay／castCountdown）──────────────
-- 「施放後 N 秒提醒我」：時間從**施放事件那一刻**自己用 C_Timer 算，不讀冷卻、不讀光環剩餘時間（12.1 戰鬥中是秘密值，
-- 「剩 N 秒」這種訊號拿不到）⇒ 急速、減冷卻、光環被延長都不會讓它跟著動，它就是「施放後固定秒數」。
--   * 觸發：UNIT_SPELLCAST_SUCCEEDED，RegisterUnitEvent 綁 player（C 層濾掉別人，也不必拿可能是秘密字串的 unit token
--     比對）。**只有某一格設了才註冊**（S.SyncCast 掃目前專精的覆寫與寬層自訂項目的覆寫）。
--   * spellID 是秘密值 ⇒ 那一次略過（不比較、不當 key；S.castSecret 記次數）。參數形狀照資源條的崩陷之星計數相容
--     (unit, castGUID, spellID)／(unit, spellID) 兩種。
--   * 對格子：查 ns.SpellIndex（認領中／放好的格：暴雪 item 收目錄的 spellID 與 overrideSpellID、自訂法術收 spellID 與
--     overrideID）⇒ 覆寫法術／基底法術都對得上，跟冷卻事件同一張表。
--   * 適用：暴雪的冷卻格（核心／輔助，增益兩條不算）與自訂法術。光環格、物品、裝備欄不做（物品的「施放」對不上法術 ID）。
--   * 排程：每格一筆（key ＝ cooldownID），**一次只排下一個時間點**（倒數的每一聲、最後的提醒），到點再排下一個；
--     同一格再施放 ⇒ 取消重排。不用 OnUpdate、不一次開 N 顆。
--   * 倒數播報（castCountdown ＝ N）：到點前 N、N−1…1 秒各念一個數字（tostring(n)，TTS 照語系念），最後一聲在到點前 1 秒；
--     只在 castDelay ≥ N＋1 時成立（Logic.Countdown 夾範圍，設定頁也夾）。數字不走節流（排程本身不會重複）。
--   * 取消：讀取畫面、換專精、換設定檔、總開關關掉、那一格的設定拿掉（S.SyncCast）時全部／那一格取消。
--   * 到點時照樣過總開關、讀取畫面靜音、節流（key "cast:<id>"）與天賦條件。
--
-- ── 天賦條件（soundTalent）────────────────────────────────────────────
-- 閘住這一格的**全部**音效與語音（就緒、充能滿、出現、消失、層數增加、施放後）。
--   * 判斷：Catalog.TalentKnown（C_SpellBook.IsSpellKnown 與 IsPlayerSpell 都問：天賦被動只有 IsPlayerSpell 準；
--     跟格子的「天賦條件」同一支，兩個功能才不會對同一個天賦給出不同答案）。讀不到（秘密、API 不在）＝ 條件成立（fail-open）。
--   * 快取：天賦 ID → 結果。TRAIT_CONFIG_UPDATED／PLAYER_TALENT_UPDATE／SPELLS_CHANGED／ACTIVE_TALENT_GROUP_CHANGED／
--     換專精／進場時下一幀重算快取裡的每一個；觸發時只查快取（快取裡沒有的第一次才問 API）。
--   * Lua 播的那幾種：觸發時過閘。光環格與增益 item 的層數增加是引擎播的（AddAuraSound）⇒ 在**對帳時**決定登不登記；
--     重算快取時結果有變就重對帳一次。
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
Logic.STACK_THROTTLE = 0.3 -- 層數增加音效（引擎的 throttleSeconds）：快速連疊不要被吞
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

-- 一筆登記的簽章（路徑可能是字串或檔案編號；節流值也進簽章，改了要換一筆）
function Logic.Sig(trigger, spellID, path, channel, throttle)
    return table.concat({ tostring(trigger), tostring(spellID), type(path), tostring(path), tostring(channel),
                          tostring(throttle or Logic.THROTTLE) }, "|")
end

-- 充能滿音效的轉變（純函式）：before／now ＝ true 滿／false 沒滿／nil 讀不到。只有明確的沒滿 → 明確的滿才響
function Logic.FullEdge(before, now)
    return before == false and now == true
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

-- 施放後提醒：延遲（整數秒 0～60；讀不懂 ＝ 0）
Logic.CAST_DELAY_MAX = 60
Logic.COUNTDOWN_MAX = 5
function Logic.CastDelay(v)
    v = tonumber(v)
    if not v or v ~= v then return 0 end
    v = math.floor(v + 0.5)
    if v < 0 then return 0 end
    if v > Logic.CAST_DELAY_MAX then return Logic.CAST_DELAY_MAX end
    return v
end

-- 這個延遲最多能倒數幾聲（castDelay ≥ castCountdown ＋ 1）
function Logic.CountdownMax(delay)
    return math.max(0, math.min(Logic.COUNTDOWN_MAX, Logic.CastDelay(delay) - 1))
end

-- 倒數播報幾聲（false／nil／讀不懂 ＝ 0；夾在 0～CountdownMax(delay)）
function Logic.Countdown(v, delay)
    v = tonumber(v)
    if not v or v ~= v then return 0 end
    v = math.floor(v + 0.5)
    local hi = Logic.CountdownMax(delay)
    if v < 0 then return 0 end
    if v > hi then return hi end
    return v
end

-- 時間表（從施放那一刻算的秒數）：倒數的每一聲 { at, n }，最後一筆 { at = delay } 是提醒本身
function Logic.CastSteps(delay, countdown)
    delay = Logic.CastDelay(delay)
    local n = Logic.Countdown(countdown, delay)
    local out = {}
    for k = n, 1, -1 do out[#out + 1] = { at = delay - k, n = k } end
    out[#out + 1] = { at = delay }
    return out
end

-- UNIT_SPELLCAST_SUCCEEDED 的 spellID：(unit, castGUID, spellID)／(unit, spellID) 兩種形狀
function Logic.CastSpellID(a2, a3)
    if type(a2) == "number" then return a2 end
    return a3
end

-- 天賦條件：合法 ⇒ 天賦 ID, need；false／壞資料（沒有 ID、need 不是布林）⇒ nil（＝不限）
function Logic.TalentCond(v)
    if type(v) ~= "table" then return nil end
    local id, need = v.id, v.need
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    if type(need) ~= "boolean" then return nil end
    return id, need
end

-- known：true／false／nil（讀不到 ⇒ 條件成立，fail-open）
function Logic.TalentPass(v, known)
    local id, need = Logic.TalentCond(v)
    if not id then return true end
    if type(known) ~= "boolean" then return true end
    return known == need
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

-- 不屬於任何一格的音效（資源條：虛空化身計時／崩陷之星的門檻規則，Modules/DevourerMeta.lua）：
-- 跟逐法術那幾種同一個出口（總開關、聲道、讀取畫面靜音、節流），key 由呼叫端給（"meta:time:<規則序號>"…）
function S.PlayNamed(name, key)
    return S.Play(name, key, "meta")
end

function S.Preview(name)
    return PlayRaw(name)
end

------------------------------------------------------------
-- 自訂語音清單（帳號層）
------------------------------------------------------------
local SOUND_FIELDS = { "readySound", "fullSound", "gainSound", "loseSound", "stackSound", "castSound" }

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
-- 天賦條件（soundTalent，見檔頭）
------------------------------------------------------------
local talentCache = {}     -- 天賦 ID → true／false／"?"（讀不到）
local talentArmed = false
S.talentCache = talentCache                           -- 測試用

local function AskTalent(tid)
    local C = ns.Catalog
    local k = C and C.TalentKnown and C.TalentKnown(tid)
    if type(k) ~= "boolean" then return "?" end
    return k
end

local function TalentKnown(tid)
    local v = talentCache[tid]
    if v == nil then
        v = AskTalent(tid)
        talentCache[tid] = v
    end
    if v == "?" then return nil end
    return v
end

-- 這一格的音效與語音現在能不能響（沒設條件 ＝ 能）
function S.TalentOK(id)
    if id == nil then return true end
    local cond = ns.SpellSetting(nil, id, "soundTalent")
    if not Logic.TalentCond(cond) then return true end
    return Logic.TalentPass(cond, TalentKnown(cond.id))
end

-- 天賦可能變了：下一幀重算快取裡的每一個；有變 ⇒ 光環格的引擎音效重對帳（登不登記看天賦）
local function RecheckTalents()
    talentArmed = false
    local changed = false
    for tid, old in pairs(talentCache) do
        local v = AskTalent(tid)
        if v ~= old then
            talentCache[tid] = v
            changed = true
        end
    end
    if changed then S.RequestAuraSync() end
end
S.RecheckTalents = RecheckTalents                     -- 測試用

local function RequestTalentRecheck()
    if talentArmed or next(talentCache) == nil then return end
    talentArmed = true
    ns.Defer(RecheckTalents)
end
S.RequestTalentRecheck = RequestTalentRecheck

------------------------------------------------------------
-- 就緒音效（Glow 叫）
------------------------------------------------------------
function S.WantsReady(rec)
    if not rec or rec.cooldownID == nil or not S.Enabled() then return false end
    return S.NameOf(rec.claimKey, rec.cooldownID, "readySound") ~= nil
        or S.SpeakTextOf(rec.claimKey, rec.cooldownID, "readySpeak") ~= nil
end

function S.OnReady(rec)
    if not rec or rec.cooldownID == nil or not S.TalentOK(rec.cooldownID) then return end
    local key = "ready:" .. tostring(rec.cooldownID)
    S.Play(S.NameOf(rec.claimKey, rec.cooldownID, "readySound"), key, "ready")
    S.Speak(S.SpeakTextOf(rec.claimKey, rec.cooldownID, "readySpeak"), key, "ready")
end

------------------------------------------------------------
-- 充能滿音效（Glow.SyncFull 對帳、SPELL_UPDATE_CHARGES 判轉變）
------------------------------------------------------------
local fullWatch = setmetatable({}, { __mode = "k" })   -- rec → { spell, cid, state }
local fullEventOn = false
S.fullWatch = fullWatch                                 -- 測試用

function S.WantsFull(rec, barKey)
    if not rec or rec.cooldownID == nil or not S.Enabled() then return false end
    barKey = barKey or rec.claimKey or rec.placedBar
    return S.NameOf(barKey, rec.cooldownID, "fullSound") ~= nil
        or S.SpeakTextOf(barKey, rec.cooldownID, "fullSpeak") ~= nil
end

local OnChargesChanged

local function SetFullEvent()
    local any = next(fullWatch) ~= nil
    if any == fullEventOn then return end
    fullEventOn = any
    if any then ns.Events.Register("SPELL_UPDATE_CHARGES", "sound_full", OnChargesChanged)
    else ns.Events.Unregister("SPELL_UPDATE_CHARGES", "sound_full") end
end

function S.UnwatchFull(rec)
    if rec and fullWatch[rec] then
        fullWatch[rec] = nil
        SetFullEvent()
    end
end

-- 記下這一次讀到的狀態；明確的沒滿 → 明確的滿就響（讀不到 ＝ nil：下次要先看到明確的沒滿才算）
local function Step(w, now)
    if Logic.FullEdge(w.state, now) and S.TalentOK(w.cid) then
        local key = "full:" .. tostring(w.cid)
        S.Play(S.NameOf(w.bar, w.cid, "fullSound"), key, "full")
        S.Speak(S.SpeakTextOf(w.bar, w.cid, "fullSpeak"), key, "full")
    end
    w.state = now
end

OnChargesChanged = function()
    if ns.released then return end
    local G, gone = ns.Glow, nil
    for rec, w in pairs(fullWatch) do
        local isCharge, now = G.ReadFull(rec, w.spell)
        if isCharge then
            Step(w, now)
        else
            gone = gone or {}                       -- 換天賦不再是充能技能：出表
            gone[#gone + 1] = rec
        end
    end
    if gone then
        for _, rec in ipairs(gone) do fullWatch[rec] = nil end
        SetFullEvent()
    end
end
S.OnChargesChanged = OnChargesChanged                 -- 測試用

-- hidden：Glow 的 Hidden（停放、藏起來）
function S.SyncFull(rec, barKey, hidden)
    if not rec then return end
    barKey = barKey or rec.claimKey or rec.placedBar
    local G = ns.Glow
    local spell = nil
    if not hidden and not ns.released and G and G.FullSpellOf and G.ReadFull and S.WantsFull(rec, barKey) then
        spell = G.FullSpellOf(rec)
    end
    local isCharge, now = false, nil
    if spell then isCharge, now = G.ReadFull(rec, spell) end
    if not isCharge then
        S.UnwatchFull(rec)
        return
    end
    local w = fullWatch[rec]
    if w and w.spell == spell and w.cid == rec.cooldownID then
        w.bar = barKey
        Step(w, now)                                -- 已經在看：排版時剛好碰上回滿也算
        return
    end
    -- 進表（或這顆框換了一招）：只記不響
    fullWatch[rec] = { spell = spell, cid = rec.cooldownID, bar = barKey, state = now }
    SetFullEvent()
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
        if S.TalentOK(id) then
            local field = e.what == "gain" and "gainSound" or "loseSound"
            local key = e.what .. ":" .. tostring(id)
            S.Play(S.NameOf(nil, id, field), key, e.what)
            S.Speak(S.SpeakTextOf(nil, id, e.what == "gain" and "gainSpeak" or "loseSpeak"), key, e.what)
        end
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

-- 暴雪的冷卻格（核心／輔助）：「增益出現／消失」＝暴雪開始／停止倒增益持續時間（玩家回報 2026-10-03：狂暴觸發時要語音）。
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
    return (E and E.Added) or 0, (E and E.Removed) or 2, (E and E.ApplicationsIncreased) or 1
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

-- 暴雪增益 item 要登記的法術：目錄的 spellID、overrideTooltipSpellID、全部 linkedSpellIDs（去重、只收明文數字；
-- Catalog 讀進來時已過 Plain）
local function BuffItemSpells(cooldownID)
    local info = ns.Catalog and ns.Catalog.Info and ns.Catalog.Info(cooldownID)
    if type(info) ~= "table" then return {} end
    local out, seen = {}, {}
    local function Add(v)
        if type(v) == "number" and v > 0 and not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end
    Add(info.spellID)
    Add(info.overrideTooltipSpellID)
    if type(info.linkedSpellIDs) == "table" then
        for _, v in ipairs(info.linkedSpellIDs) do Add(v) end
    end
    return out
end
S.BuffItemSpells = BuffItemSpells                    -- 測試用

local function Want(want, trig, sid, path, channel, throttle)
    local sig = Logic.Sig(trig, sid, path, channel, throttle)
    want[sig] = { trigger = trig, spellID = sid, path = path, channel = channel, throttle = throttle }
end

function S.WantAuraSounds()
    local want = {}
    if not (API() and S.Enabled()) then return want end
    local added, removed, increased = Triggers()
    local channel = S.Channel()
    local CU = ns.Custom
    if CU and CU.Records then
        local FIELDS = {
            gainSound  = { trig = added,     throttle = Logic.THROTTLE },
            loseSound  = { trig = removed,   throttle = Logic.THROTTLE },
            stackSound = { trig = increased, throttle = Logic.STACK_THROTTLE },
        }
        for _, r in pairs(CU.Records()) do
            -- 飾品欄的增益疊層（r.buffOverlay，Modules/Custom.lua）是光環格形狀的子 rec：疊著的時候（placedBar 有值）
            -- 照冷卻格那一筆的 cooldownID 讀 gainSound／loseSound／stackSound、認的法術是解出來的增益（AuraIDsOf 讀 auraIDs）
            local rec = r
            if r.kind ~= "aura" then rec = r.buffOverlay end
            -- 天賦條件不過：不登記（天賦變了 RecheckTalents 會重對帳）
            if rec and rec.kind == "aura" and rec.placedBar and rec.cooldownID and type(rec.spellID) == "number"
                and S.TalentOK(rec.cooldownID) then
                -- 多法術的光環格（嗜血那種）：每個法術各登一筆（引擎只認單一 spellID）
                local ids = (CU.AuraIDsOf and CU.AuraIDsOf(rec)) or { rec.spellID }
                for field, f in pairs(FIELDS) do
                    local path = S.Path(S.NameOf(rec.placedBar, rec.cooldownID, field))
                    if path ~= nil then
                        for _, sid in ipairs(ids) do Want(want, f.trig, sid, path, channel, f.throttle) end
                    end
                end
            end
        end
    end
    -- 暴雪的增益 item：只有層數增加音效走這裡（出現／消失是 Lua 掛勾）。池子裡作用中、有身分的都算，不看放格（見檔頭）
    local V = ns.Viewers
    if not ns.released and V and V.EnumerateItems and V.AURA_KIND then
        for src in pairs(V.AURA_KIND) do
            V.EnumerateItems(function(_, rec)
                local cid = rec.cooldownID
                if cid == nil or rec.custom then return end
                local path = S.Path(S.NameOf(nil, cid, "stackSound"))
                if path ~= nil and not S.TalentOK(cid) then return end
                if path == nil then return end
                for _, sid in ipairs(BuffItemSpells(cid)) do
                    Want(want, increased, sid, path, channel, Logic.STACK_THROTTLE)
                end
            end, src)
        end
    end
    return want
end

-- 暴雪增益 item 換了身分（Viewers 的 SetCooldownID／ClearCooldownID 後掛勾）：前後任一個有設層數增加音效才重登
function S.OnBuffItemChanged(old, new)
    if (old ~= nil and S.NameOf(nil, old, "stackSound") ~= nil)
        or (new ~= nil and S.NameOf(nil, new, "stackSound") ~= nil) then
        S.RequestAuraSync()
    end
end

local function Register(spec)
    local U = API()
    local info = { unitToken = "player", spellID = spec.spellID, outputChannel = spec.channel,
                   throttleSeconds = spec.throttle or Logic.THROTTLE }
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
-- 施放後提醒（見檔頭）
------------------------------------------------------------
local pending = {}         -- cooldownID → { bar, start, steps, i, timer }
local castOn = false
S.castPending = pending                               -- 測試用
S.castSecret = 0                                      -- 秘密 spellID 略過的次數（debug）
S.castScheduled = 0

-- 這一格能不能用施放後提醒：暴雪的冷卻格（增益兩條不算）與自訂法術
local function CastCapable(rec)
    if not rec or rec.cooldownID == nil then return false end
    if rec.custom then return rec.kind == "spell" end
    local V = ns.Viewers
    return not (V and V.AURA_KIND and V.AURA_KIND[rec.barKey])
end
S.CastCapable = CastCapable                           -- 測試用

-- 這一格設了施放後提醒（音效、語音或倒數任一個）
function S.WantsCast(bar, id)
    if id == nil then return false end
    if S.NameOf(bar, id, "castSound") ~= nil or S.SpeakTextOf(bar, id, "castSpeak") ~= nil then return true end
    return S.CanSpeak() and Logic.Countdown(ns.SpellSetting(bar, id, "castCountdown"),
                                            ns.SpellSetting(bar, id, "castDelay")) > 0
end

local function CancelCast(id)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    if p.timer then p.timer:Cancel() end
end

function S.CancelAllCasts()
    for id in pairs(pending) do CancelCast(id) end
end

local ArmCast

local function FireCast(id, p)
    if pending[id] ~= p then return end              -- 已取消／重排
    local st = p.steps[p.i]
    p.i = p.i + 1
    p.timer = nil
    if st and not ns.released and S.TalentOK(id) then
        if st.n then
            S.Speak(tostring(st.n), nil, "countdown")  -- 不走節流：排程本身不會重複
        else
            local key = "cast:" .. tostring(id)
            S.Play(S.NameOf(p.bar, id, "castSound"), key, "cast")
            S.Speak(S.SpeakTextOf(p.bar, id, "castSpeak"), key, "cast")
        end
    end
    if p.steps[p.i] then ArmCast(id, p) else pending[id] = nil end
end

-- 只排下一個時間點（倒數的下一聲或提醒本身）
ArmCast = function(id, p)
    local st = p.steps[p.i]
    local wait = math.max(0, p.start + st.at - Now())
    p.timer = C_Timer.NewTimer(wait, function() FireCast(id, p) end)
end

local function ScheduleCast(id, bar, now)
    CancelCast(id)                                    -- 同一格再施放：取消重排
    local p = { bar = bar, start = now, i = 1,
                steps = Logic.CastSteps(ns.SpellSetting(bar, id, "castDelay"), ns.SpellSetting(bar, id, "castCountdown")) }
    if not S.CanSpeak() then
        -- 沒有語音 API：倒數那幾聲拿掉，只留提醒本身
        p.steps = { p.steps[#p.steps] }
    end
    pending[id] = p
    S.castScheduled = S.castScheduled + 1
    ArmCast(id, p)
end

local function OnCast(_, a2, a3)
    if ns.released or not S.Enabled() then return end
    local sid = Logic.CastSpellID(a2, a3)
    if sid == nil then return end
    if ns.IsSecret(sid) then                          -- 秘密：不比較、不當 key，這一次略過
        S.castSecret = S.castSecret + 1
        return
    end
    if type(sid) ~= "number" then return end
    local SI = ns.SpellIndex
    if not (SI and SI.Lookup) then return end
    local now = Now()
    for _, e in ipairs(SI.Lookup(sid)) do
        local rec = e.rec
        if CastCapable(rec) then
            local id = rec.cooldownID
            local bar = e.key or rec.claimKey
            if S.WantsCast(bar, id) and S.TalentOK(id) then ScheduleCast(id, bar, now) end
        end
    end
end
S.OnCast = OnCast                                     -- 測試用

-- 某一張覆寫表有沒有設施放後提醒（原始值，不看總開關與語音 API：只決定要不要聽事件）
local function OverrideWantsCast(o)
    if type(o) ~= "table" then return false end
    if Logic.Name(o.castSound) then return true end
    if o.castSpeak ~= nil and o.castSpeak ~= false then return true end
    return Logic.Countdown(o.castCountdown, o.castDelay) > 0
end

-- 目前專精的覆寫＋寬層自訂項目身上的覆寫，有沒有任何一格設了
local function AnyCastWanted()
    local DB = ns.DB
    local sp = DB and DB.SpecSpells and DB.SpecSpells(false)
    local all = sp and type(sp.overrides) == "table" and sp.overrides
    for _, o in pairs(all or {}) do
        if OverrideWantsCast(o) then return true end
    end
    local found = false
    if DB and DB.EachWideList then
        DB.EachWideList(ns.profile, function(list)
            for _, e in ipairs(list) do
                if not found and type(e) == "table" and OverrideWantsCast(e.overrides) then found = true end
            end
        end)
    end
    return found
end

-- 事件註冊與排程對帳：設定變了（Options 的 FlushEngine）、換設定檔、換專精、進場
function S.SyncCast()
    local on = not ns.released and S.Enabled() and AnyCastWanted()
    if on ~= castOn then
        castOn = on
        if on then ns.Events.Register("UNIT_SPELLCAST_SUCCEEDED", "sound_cast", OnCast, "player")
        else ns.Events.Unregister("UNIT_SPELLCAST_SUCCEEDED", "sound_cast") end
    end
    if not on then
        S.CancelAllCasts()
        return
    end
    for id, p in pairs(pending) do
        if not S.WantsCast(p.bar, id) then CancelCast(id) end
    end
end

function S.CastListening() return castOn end

function S.CastPendingCount()
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    return n
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function S.DebugLine()
    local last = S.last
    local lastText = last and ("%s（%s，%.1f 秒前）"):format(tostring(last.name), tostring(last.why), Now() - last.t) or "無"
    return ("  音效：%s  聲道 %s  光環格登記 %d 筆%s  增益掛勾 %s  播過 %d 次、念過 %d 次（語音 API %s）（擋掉 %d）  最近：%s%s"
            .. "\n  施放後提醒：%s  排過 %d 次、排程中 %d 格、略過秘密 %d 次")
        :format(S.Enabled() and "開" or "關", S.Channel(), S.AuraCount(),
                S.auraPending and "（待登記）" or "", tostring(S.hookMode), S.played, S.spoken,
                S.CanSpeak() and "有" or "沒有", S.skipped, lastText,
                S.lastAuraError and ("  登記失敗 %d 次：%s"):format(S.auraErrors, S.lastAuraError) or "",
                castOn and "聽施法事件" or "沒在聽", S.castScheduled, S.CastPendingCount(), S.castSecret)
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
        RequestTalentRecheck()
        ns.Defer(S.SyncCast)
    end)
    -- 讀取畫面：施放後提醒全部取消（過圖之後還響只會嚇人）
    E.Register("LOADING_SCREEN_ENABLED", "sound", function() Logic.OnLoadingStart(mute); S.CancelAllCasts() end)
    E.Register("LOADING_SCREEN_DISABLED", "sound", function() Logic.OnLoadingEnd(mute, Now()) end)
    -- 天賦條件的快取：天賦可能變了就下一幀重算
    for _, ev in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" }) do
        E.Register(ev, "sound_talent", RequestTalentRecheck)
    end
    ns.RegisterCallback("ProfileChanged", "sound", function()
        S.RequestAuraSync()
        S.CancelAllCasts()
        S.SyncCast()
    end)
    ns.RegisterCallback("SpecChanged", "sound", function()
        S.RequestAuraSync()
        S.CancelAllCasts()
        RequestTalentRecheck()
        S.SyncCast()
    end)
    S.SyncCast()
end
