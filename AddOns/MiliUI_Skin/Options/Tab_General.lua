------------------------------------------------------------
-- 設定：總開關 ＋ 每個視窗一個勾選框
--
-- ⚠ **這一頁的任何改動都要 /reload 才生效。** 沒有「立刻還原」那條路：還原得記住
--   每個暴雪區域原本的 alpha／顏色／材質，而那份紀錄一旦跟暴雪改版對不上，
--   還原出來的會是「既不是原樣也不是皮」的第三種狀態。所以改完就問要不要重載。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local asked = false
local reloadPopup

-- ⚠ 只問**第一次**。每勾一個框就彈一次確認窗的話，想一次改三個視窗的人會被問三次，
--   而且每次都蓋住他正要勾的下一個框。之後靠表單裡那行說明與「重新載入介面」按鈕。
local function AskReload()
    if asked then return end
    asked = true
    local parent = ns.Options.panel
    if not parent then return end
    if not reloadPopup then
        reloadPopup = W.CreateConfirmPopup(parent, 320, L["Changes take effect after a UI reload. Reload now?"], function()
            ReloadUI()
        end)
    end
    reloadPopup:Show()
end

local controls = {
    { type = "header", label = L["General"] },
    {
        type  = "toggle",
        key   = "enabled",
        label = L["Enable the skin"],
        hint  = L["Repaints Blizzard's windows in the MiliUI settings-window look."],
    },
    { type = "text", label = L["This addon only repaints. It never moves, resizes or rebuilds anything Blizzard owns."] },
    {
        type  = "toggle",
        key   = "questDarkText",
        label = L["Dark quest and gossip background"],
        hint  = L["Uses Blizzard's own accessibility setting (Quest Text Contrast) instead of repainting the parchment: Blizzard swaps the background and every text colour together. Your original value is remembered and put back when you turn this off. If you change that setting in Blizzard's options yourself, this puts it back on the next login."],
    },

    { type = "header", label = L["Windows"] },
    { type = "toggle", sub = "windows", key = "gossip",      label = L["Gossip"] },
    { type = "toggle", sub = "windows", key = "character",   label = L["Character Info"] },
    { type = "toggle", sub = "windows", key = "achievement", label = L["Achievements"] },
    { type = "toggle", sub = "windows", key = "quest",       label = L["Quest"] },
    { type = "toggle", sub = "windows", key = "mail",        label = L["Mail"] },
    { type = "toggle", sub = "windows", key = "friends",     label = L["Friends List"] },
    { type = "toggle", sub = "windows", key = "collections", label = L["Collections"] },
    { type = "toggle", sub = "windows", key = "pve",         label = L["Group Finder"] },
    { type = "toggle", sub = "windows", key = "merchant",    label = L["Merchant"] },
    -- ⚠ 這兩個視窗的按鈕通往受保護的動作（出價、直購、建立拍賣、製作、接單、
    --   套用專精變更…），所以各自帶一句「出事先關這個」的說明。
    {
        type  = "toggle", sub = "windows", key = "auctionhouse",
        label = L["Auction House"],
        hint  = L["Turn this off first if a bid, buyout or posting button stops responding."],
    },
    {
        type  = "toggle", sub = "windows", key = "professions",
        label = L["Professions"],
        hint  = L["Turn this off first if a craft or crafting-order button stops responding."],
    },
    { type = "toggle", sub = "windows", key = "dressup",     label = L["Dressing Room"] },
    { type = "toggle", sub = "windows", key = "itemupgrade", label = L["Item Upgrade"] },
    { type = "toggle", sub = "windows", key = "addonlist",   label = L["AddOns"] },
    { type = "toggle", sub = "windows", key = "encounterjournal", label = L["Adventure Guide"] },
    -- ⚠ 寶庫的按鈕通往受保護的領獎動作，跟下面兩個特許視窗同一條理由。
    {
        type  = "toggle", sub = "windows", key = "weeklyrewards",
        label = L["Great Vault"],
        hint  = L["Turn this off first if you cannot select or claim a Great Vault reward."],
    },
    -- ⚠ 第十一輪：天賦視窗的按鈕通往提交天賦／切換專精；探究視窗的「進入」是傳送。
    {
        type  = "toggle", sub = "windows", key = "playerspells",
        label = L["Talents & Spellbook"],
        hint  = L["Turn this off first if applying talents, switching specialization or casting from the spellbook stops working."],
    },
    {
        type  = "toggle", sub = "windows", key = "delvespicker",
        label = L["Delve Difficulty Picker"],
        hint  = L["The difficulty window at a Delve or world instance entrance. Its background art is kept."],
    },
    -- 第十二輪
    {
        type  = "toggle", sub = "windows", key = "communities",
        label = L["Guild & Communities"],
        hint  = L["Turn this off first if changing guild notes or ranks, inviting, or community chat stops working."],
    },
    { type = "toggle", sub = "windows", key = "calendar", label = L["Calendar"] },
    { type = "toggle", sub = "windows", key = "macro", label = L["Macros"] },
    {
        type  = "toggle", sub = "windows", key = "trainer",
        label = L["Trainer"],
        hint  = L["Turn this off first if the Train button stops responding."],
    },
    {
        type  = "toggle", sub = "windows", key = "trade",
        label = L["Trade"],
        hint  = L["Turn this off first if the Trade button stops responding or the UI reports a blocked action."],
    },
    { type = "toggle", sub = "windows", key = "inspect", label = L["Inspect"] },
    { type = "toggle", sub = "windows", key = "socketing", label = L["Item Socketing"] },
    { type = "toggle", sub = "windows", key = "iteminteraction", label = L["Catalyst & Item Conversion"] },
    {
        type  = "toggle", sub = "windows", key = "loot",
        label = L["Loot Window"],
        hint  = L["Turn this off first if clicking an item in the loot window stops picking it up."],
    },
    { type = "toggle", sub = "windows", key = "delvescompanion", label = L["Delve Companion"] },
    {
        type  = "toggle", sub = "windows", key = "transmog",
        label = L["Transmogrifier"],
        hint  = L["Turn this off first if applying a transmog outfit stops responding."],
    },
    {
        type  = "toggle", sub = "windows", key = "customerorders",
        label = L["Crafting Orders"],
        hint  = L["Turn this off first if placing or cancelling a crafting order stops responding."],
    },
    {
        type  = "toggle", sub = "windows", key = "playerchoice",
        label = L["Player Choice"],
        hint  = L["Choice windows like the weekly \"how will you help\" picker. Only the frame and buttons are restyled; the cards keep their art."],
    },
    -- ⚠ 這兩個視窗的按鈕通往受保護的動作（刪除物品、離開隊伍、登出、編輯模式…），
    --   所以各自帶一句「出事先關這個」的說明 —— 玩家不必懂 taint 也知道該關哪一項。
    {
        type  = "toggle", sub = "windows", key = "popup",
        label = L["Confirmation Popups"],
        hint  = L["Turn this off first if a confirmation button stops responding or the UI reports a blocked action."],
    },
    {
        type  = "toggle", sub = "windows", key = "gamemenu",
        label = L["Game Menu"],
        hint  = L["Turn this off first if an Esc menu button stops responding or the UI reports a blocked action."],
    },

    -- ⚠ 這一節管的是「伴隨元件」—— 套組內建、固定掛在暴雪視窗上的**別家**插件
    --   （STYLE.md ③，實作在 `ThirdParty/`）。跟上面的視窗開關是「而且」的關係：
    --   host 視窗關掉、或這裡關掉，那一支都不跑。
    --   插件名稱一律用它們自己的英文名，**不進語系表**：那是專有名詞，
    --   翻成中文反而找不到是哪一支。
    { type = "header", label = L["Other Addons"] },
    { type = "text", label = L["Bundled addons that attach to Blizzard's windows. Only has an effect when that addon is installed."] },
    { type = "toggle", sub = "thirdparty", key = "postal",              label = "Postal" },
    { type = "toggle", sub = "thirdparty", key = "auctionator",         label = "Auctionator" },
    { type = "toggle", sub = "thirdparty", key = "premadegroupsfilter", label = "Premade Groups Filter" },
    { type = "toggle", sub = "thirdparty", key = "raiderio",            label = "RaiderIO" },

    { type = "space", h = 6 },
    { type = "text", label = L["Changes take effect after a UI reload."] },
    {
        type    = "button",
        label   = "",
        text    = L["Reload UI"],
        width   = 160,
        onClick = function() ReloadUI() end,
    },
    {
        type    = "button",
        label   = "",
        text    = L["Show status"],
        width   = 160,
        onClick = function() ns.Engine.Report() end,
    },
}

ns.Options.builders.general = function()
    local tab, scroll = ns.Options.MakeFormTab(L["MiliUI Skin"])

    local ctx = {
        get = function(spec)
            local t = ns.Controls.Resolve(ns.db, spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local t = ns.Controls.Resolve(ns.db, spec)
            if t then t[spec.key] = v end
        end,
        apply = AskReload,
    }

    local _, refreshers = ns.Options.BuildScrollBody(scroll, controls, ctx, ns.Options.FORM_W)

    tab.Refresh = function()
        for _, fn in ipairs(refreshers) do fn() end
    end
    tab.Refresh()
    return tab
end
