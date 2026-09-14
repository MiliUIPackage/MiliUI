------------------------------------------------------------
-- 坐騎：滑過方塊彈出來的面板
--
-- 皮、開關節奏、定位、列層與所有版面常數都在 Core/HoverPanel.lua，這支只負責
-- 「這張面板有哪些列」。⚠ 版面數字一個都不要搬回來：四張面板長得一樣是需求，
-- 複製一份就是下一次分岔的起點。
--
-- 內容由上而下：快捷區（左／右鍵各一隻）→ 各分類（標題旁有「隨機」）→ 設定入口。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local HP = ns.HoverPanel
local Mounts = ns.Mounts

ns.MountPopup = {}
local Popup = ns.MountPopup

-- 沒有坐騎可顯示時的通用騎乘圖示。設定分頁也在用，所以掛在對外的表上
local FALLBACK_ICON = "Interface\\Icons\\Ability_Mount_RidingHorse"
Popup.FALLBACK_ICON = FALLBACK_ICON

local panel         -- 檔尾建立；下面的處理器都在載入後才會跑到

local BOUND_LABEL = {
    left  = "MOUNT_BIND_LEFT",
    right = "MOUNT_BIND_RIGHT",
    both  = "MOUNT_BIND_BOTH",
}

------------------------------------------------------------
-- 列的動作
------------------------------------------------------------
-- 右鍵選單：把它錨在游標上而不是這一列。列會隨著面板關掉而消失，
-- 選單卻是掛 UIParent 的共用框——錨在會消失的東西上，位置就不可信。
local function ShowRowMenu(spellID)
    local items = {
        { isTitle = true, text = Mounts.Name(spellID) },
        {
            text = L["MOUNT_SET_LEFT"],
            isActive = (Mounts.Profile().left == spellID),
            onClick = function() Mounts.SetAssigned("left", spellID) end,
        },
        {
            text = L["MOUNT_SET_RIGHT"],
            isActive = (Mounts.Profile().right == spellID),
            onClick = function() Mounts.SetAssigned("right", spellID) end,
        },
        { isSeparator = true },
        {
            text = L["MOUNT_MENU_SETTINGS"],
            onClick = function() ns.OpenSettings("mounts") end,
        },
    }
    panel:Hide()
    W.Menu.Show(items)
end

local function SummonRow(spellID)
    panel:Hide()
    Mounts.Summon(spellID)
end

-- 這顆鍵還沒有坐騎：帶玩家去設定，而不是安靜地什麼都沒發生
local function OpenMountSettings()
    panel:Hide()
    ns.OpenSettings("mounts")
end

------------------------------------------------------------
-- 內容
------------------------------------------------------------
local function BuildModel()
    local model = {}

    -- 快捷區＝跟分類**一模一樣**的一個區段（標題 ＋ 兩列），差別只有沒有隨機鈕。
    -- 區段之間靠「留白 ＋ 標題的髮絲線」就分得開了，所以這裡**不畫分隔線**——
    -- 分隔線只留給「內容」與最底下那條功能列之間。
    model[#model + 1] = { kind = "title", text = L["MOUNT_SECTION_SHORTCUTS"] }
    for _, side in ipairs({ "left", "right" }) do
        local spellID = Mounts.Assigned(side)
        local info = spellID and Mounts.Info(spellID) or nil
        -- 右側標跟分類列共用同一組詞彙：快捷列不另外開一欄放「左鍵」標籤，
        -- 不然它的圖示會跟底下分類的圖示差了一整個標籤寬
        local tag = L[side == "left" and "MOUNT_BIND_LEFT" or "MOUNT_BIND_RIGHT"]
        if info then
            model[#model + 1] = {
                kind         = "item",
                icon         = info.icon or FALLBACK_ICON,
                text         = info.name or "?",
                suffix       = Mounts.IsAuto(side) and L["MOUNT_AUTO"] or nil,
                tag          = tag,
                data         = info.spellID,
                onClick      = SummonRow,
                onRightClick = ShowRowMenu,
            }
        else
            model[#model + 1] = {
                kind    = "item",
                icon    = FALLBACK_ICON,
                text    = L["MOUNT_UNSET"],
                dim     = true,
                tag     = tag,
                onClick = OpenMountSettings,
            }
        end
    end

    local any = false
    for index, cat in ipairs(Mounts.Categories()) do
        local list = {}
        for _, spellID in ipairs(cat.spells or {}) do
            local info = Mounts.Info(spellID)
            -- 判準是 available 不是 collected：未收藏的不列（面板是拿來用的，
            -- 不是拿來看目標的），另一個陣營的版本也不列——不然同一隻長毛象
            -- 會在修裝分類裡出現兩次，而其中一隻點了只會跳訊息
            if info and info.available then list[#list + 1] = info end
        end
        if #list > 0 then
            any = true
            model[#model + 1] = {
                kind   = "title",
                text   = Mounts.CategoryName(cat),
                -- 只有一隻的話「隨機」沒有意義
                action = #list >= 2 and {
                    text    = L["MOUNT_RANDOM"],
                    onClick = function()
                        panel:Hide()
                        Mounts.RandomIn(index)
                    end,
                } or nil,
            }
            for _, info in ipairs(list) do
                local bound = Mounts.BoundSide(info.spellID)
                model[#model + 1] = {
                    kind         = "item",
                    icon         = info.icon or FALLBACK_ICON,
                    text         = info.name or "?",
                    tag          = bound and L[BOUND_LABEL[bound]] or nil,
                    data         = info.spellID,
                    onClick      = SummonRow,
                    onRightClick = ShowRowMenu,
                }
            end
        end
    end

    if not any then
        model[#model + 1] = { kind = "note", text = L["MOUNT_EMPTY"] }
        model[#model + 1] = { kind = "note", text = L["MOUNT_EMPTY_SUB"] }
    end

    -- 設定入口永遠在最底下。空清單時最需要它——「我的坐騎清單在哪裡改」
    -- 正是使用者第一天就問的問題。
    model[#model + 1] = { kind = "sep" }
    model[#model + 1] = { kind = "settings", text = L["MOUNT_POPUP_SETTINGS"], tab = "mounts" }
    return model
end

------------------------------------------------------------
-- 面板
------------------------------------------------------------
panel = HP.New({
    name = "MiliUIInfoBar_MountPopup",
    populate = function(rows)
        rows:Render(BuildModel())
    end,
    onOpen = function()
        Mounts.AddListener("popup", function() panel:Refresh() end)
    end,
    onHide = function()
        Mounts.RemoveListener("popup")
    end,
})

------------------------------------------------------------
-- 對外（名字保留給 Core/Blocks.lua 與設定分頁）
------------------------------------------------------------
function Popup.CancelClose()   panel:CancelClose() end
function Popup.CancelOpen()    panel:CancelOpen() end
function Popup.Hide()          panel:Hide() end
function Popup.ScheduleClose() panel:ScheduleClose() end
function Popup.Open(tile)         panel:Open(tile) end
function Popup.ScheduleOpen(tile) panel:ScheduleOpen(tile) end
function Popup.IsOpenFor(tile)    return panel:IsOpenFor(tile) end
