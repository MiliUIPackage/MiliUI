--[[---------------------------------------------------------------------------
    File:   CursorTrailHelp.lua
    Desc:   Functions and variables for showing this addon's help text.
-----------------------------------------------------------------------------]]

local kAddonFolderName, private = ...

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
local GetAddOnMetadata = _G.GetAddOnMetadata or _G.C_AddOns.GetAddOnMetadata
local print = _G.print
local UNKNOWN = _G.UNKNOWN  -- Translated word for "Unknown".

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Declare Namespace                                 ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local CursorTrail = _G.CursorTrail or {}
if (not _G.CursorTrail) then _G.CursorTrail = CursorTrail end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Remap Global Environment                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

setfenv(1, _G.CursorTrail)  -- Everything after this uses our namespace rather than _G.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Constants                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

kHelpText_Options = [[
主要選項視窗可從 Esc>選項>插件>滑鼠，開啟，或是輸入 /ct 或 /cursortrail。設定是每個角色分開儲存的，因此 (例如) 你的戰坦可以擁有與其他角色不同的滑鼠游標效果。

* 整體縮放 %: 控制所有圖層上所有模型、形狀和大小的尺寸。在設計一組新的特效時，將此值保留為 100%，然後稍後可以使用它來根據需要放大或縮小所有內容。
注意：整體縮放會與每個圖層的縮放值組合起來計算每個特效的最終大小。

* 圖層: 選擇一個圖層分頁會顯示該圖層的選項。已啟用圖層的分頁將會呈現淡淡的綠色，而不是它的標準顏色，這表示哪些圖層已啟用，而無需選取它們。
如果圖層具有相同的「框架層級」設定，則圖層 1 的特效會繪製在圖層 2 的特效之上。

* 啟用圖層: 開啟時，當前圖層的特效將會繪製在螢幕上。

* 形狀: 可供選擇的形狀特效清單。
可以透過點擊形狀選擇右側的顏色樣本按鈕來更改形狀的顏色。
當「閃爍」開啟時，將會忽略所選的形狀顏色，並且形狀會改為「閃爍」。 （閃爍不會影響模型顏色。）

* 軌跡: 可供選擇的游標特效清單。可以利用下方的「調整位置」來移動位置。

* 陰影%: 控制黑色背景圓圈的強度。99% 最暗，而 0% 是隱形 (關閉)。

* 縮放比例 %: 控制特效的大小。可以是 2 到 998。

* 不透明度%: 控制圖形和軌跡的透明度。100% 完全可見，而 0% 則是隱形 (關閉)。

* 圖層層級: 控制形狀和模型是繪製在其他 UI 物件的後面還是前面。它不會影響陰影選項。（「背景」是最底層的繪製圖層，「工具提示」是最頂層的。）

* 調整位置: 移動軌跡特效的中心位置。第一個數字框是水平移動 (負數向左移動，正數向右移動)。第二個數字框是垂直移動 (負數向下移動，正數向上移動)。

* 滑鼠不動時隱藏: 啟用時，當滑鼠停止移動時，游標效果會淡出。

* 只在戰鬥中顯示: 啟用時，游標效果只會在戰鬥中出現。

* 用滑鼠控制視角時要顯示: 啟用時，游標效果在使用滑鼠環顧四周時仍會保持可見。

* 預設值: 每個預設值都有不同的預設選項。可以將它們作為自己效果的起點。要儲存一個預設值，請從設定檔選單中選擇 "另存新檔"。
]]

kHelpText_Tips = [[
* 圖層: 

- 在介面的空白區域點擊滑鼠右鍵會在滑鼠位置開啟一個操作圖層的快捷選單。

- 點擊圖層標籤名稱時...
        左鍵點擊              = 選擇該圖層。（正常行為。）
        Shift + 左鍵點擊  = 切換該圖層的啟用狀態，但不選擇它。
        右鍵點擊            = 開啟快捷選單。
        Shift + 右鍵點擊 = 選擇該圖層並切換其啟用狀態。

- 按下 Ctrl+Tab 或 Shift+Ctrl+Tab 可以選擇下一個/上一個圖層。

- 將滑鼠指向圖層標籤名稱並使用滑鼠滾輪可以在所有圖層之間循環切換。

* 設定檔: 

- 右鍵點擊設定檔名稱可以快速儲存它。

- 在設定檔列表中按住 Shift 鍵並點擊名稱，可以在載入設定檔後保持列表開啟。

* 變更數值: 

- 右鍵點擊大多數選項會將其設定為預設值。再次右鍵點擊它們會變回之前的數值。

- 可以使用滑鼠滾輪來更改滑鼠下方的選項。

- 可以使用向上/向下箭頭鍵來更改具有焦點的選項。
]]

kHelpText_ProfileCommands = [[
你的所有角色都可以從選項視窗儲存和載入設定檔 (你的設定): 
]] .."\n".. (private.ProfilesUI_ProfilesHelp or "") .."\n".. [[
也可以使用指令來管理設定檔:
        /ct save  <設定檔名稱>
        /ct load  <設定檔名稱>
        /ct delete  <設定檔名稱>
        /ct list
]]

kHelpText_BackupCommands = [[
從選項視窗可以建立和回復設定檔的備份:
]] .."\n".. (private.ProfilesUI_BackupsHelp or "") .."\n".. [[
也可以使用指令來管理備份:
        /ct backup  <備份名稱>
        /ct restore  <備份名稱>
        /ct deletebackup  <備份名稱>
        /ct listbackups
]]

kHelpText_SlashCommands = [[
輸入 "/ct help" 查看所有可用的指令。
]]

kHelpText_Troubleshooting = [[
- 如果縮放設定得太低，部分軌跡會消失。如果選擇軌跡後卻沒有顯示，請嘗試較大的縮放百分比。(所有軌跡皆能在 100% 縮放下運作。)

- 如果游標效果突然消失，可以輸入 /ct reload 來快速回復。

- 如果圖形和陰影無法正常跟隨滑鼠游標，同時您有使用插件將遊戲介面縮放到低於正常最小值 (64%)，請輸入 /ct reload (或正常重新載入介面)，讓游標軌跡使用新的縮放值。

- 如果你使用 CTMod 外掛，它與 CursorTrail 使用相同的斜線指令（/ct），只會開啟其中一個外掛。
如果 CTMod 總是先開啟，請輸入 /cursortrail 來開啟 CursorTrail。
如果 CursorTrail 總是先開啟，你可以手動修改 CursorTrail 的斜線指令，例如改成 /ctr。
重要提示：每次下載 CursorTrail 後，你都需要重複進行此操作。
    1.使用任何文字編輯器，開啟 CursorTrail 資料夾中的 "CursorTrail.lua" 檔案，
      這個資料夾位於你的魔獸世界外掛資料夾中。
    （例如："C:\Program Files\World of Warcraft_retail_\Interface\AddOns\CursorTrail\CursorTrail.lua"）
    2.在檔案中搜尋 "SLASH_"。
    3.修改該行後面的內容。將原本的
      Globals["SLASH_"..kAddonFolderName.."2"] = "/ct"
      改成你新的斜線指令：
      Globals["SLASH_"..kAddonFolderName.."2"] = "/ctr"
    4.儲存修改，然後重新載入魔獸世界（/reload）。
]]

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Functions                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function CursorTrail_ShowHelp(parent, scrollToTopic)
    local topMargin = 3
    local scrollDelaySecs = nil
    local ORANGE = "|cffEE5500"
    local YELLOW = "|cffFFD200"
    local BLUE = "|cff0099DD"
    local GRAY = "|cff909090"

    if not HelpFrame then
        HelpFrame = private.UDControls.CreateTextScrollFrame(parent, "*** "..kAddonFolderName.." "..kAddonVersion.." Help ***", 750)
        ----HelpFrame:SetFrameLevel( HelpFrame:GetFrameLevel()+1 )
        HelpFrame:Hide()
        HelpFrame.topicOffsets = {}
        scrollDelaySecs = 0.1  -- Required so this newly created window has its scrollbar update correctly.

        -- Colorize option names.
        kHelpText_Options = kHelpText_Options:gsub("* ", YELLOW.."* |r"..BLUE)
        kHelpText_Options = kHelpText_Options:gsub(": ", "|r: ")

        -- Colorize tip sections.
        kHelpText_Tips = kHelpText_Tips:gsub("* ", BLUE)
        kHelpText_Tips = kHelpText_Tips:gsub(":", ":|r")

        ------ Colorize slash commands.
        ----kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub(" /ct ", BLUE.." /ct ")
        ----kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub(" <", "|r <")
        ----kHelpText_BackupCommands = kHelpText_BackupCommands:gsub(" /ct ", BLUE.." /ct ")
        ----kHelpText_BackupCommands = kHelpText_BackupCommands:gsub(" <", "|r <")

        -- Colorize slash command parameters.
        kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub("<", GRAY.."<")
        kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub(">", ">|r")
        kHelpText_BackupCommands = kHelpText_BackupCommands:gsub("<", GRAY.."<")
        kHelpText_BackupCommands = kHelpText_BackupCommands:gsub(">", ">|r")

        ------ Colorize bullet chars.
        kHelpText_Tips = kHelpText_Tips:gsub("- ", YELLOW.."- |r")
        kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub("\n%- ", YELLOW.."\n- |r")
        kHelpText_BackupCommands = kHelpText_BackupCommands:gsub("\n%- ", YELLOW.."\n- |r")
        kHelpText_Troubleshooting = kHelpText_Troubleshooting:gsub("\n%- ", YELLOW.."\n- |r")

        -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
        local bigFont = "GameFontNormalHuge" --"OptionsFontLarge" --"GameFontNormalLarge"
        local smallFont = "GameTooltipText"
        local lineSpacing = 6

        -- OPTIONS:
        ----HelpFrame.topicOffsets["OPTIONS"] = HelpFrame:GetNextVerticalPosition()
        HelpFrame:AddText(ORANGE.."選項", 0, topMargin, bigFont)
        HelpFrame:AddText(kHelpText_Options, 0, lineSpacing, smallFont)
        ----HelpFrame:AddText(BLUE.."\nTIP:|r You can use the mouse wheel or Up/Down keys to change values.", 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- TIPS:
        HelpFrame.topicOffsets["TIPS"] = HelpFrame:GetNextVerticalPosition() -12
        HelpFrame:AddText(ORANGE.."小提示", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_Tips, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- PROFILE COMMANDS:
        HelpFrame.topicOffsets["PROFILE_COMMANDS"] = HelpFrame:GetNextVerticalPosition() -12
        HelpFrame:AddText(ORANGE.."設定檔", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_ProfileCommands, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- BACKUP COMMANDS:
        HelpFrame.topicOffsets["BACKUP_COMMANDS"] = HelpFrame:GetNextVerticalPosition() -12
        HelpFrame:AddText(ORANGE.."備份", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_BackupCommands, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- SLASH COMMANDS:
        ----HelpFrame.topicOffsets["SLASH_COMMANDS"] = HelpFrame:GetNextVerticalPosition()
        HelpFrame:AddText(ORANGE.."指令", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_SlashCommands, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- TROUBLESHOOTING:
        ----HelpFrame.topicOffsets["TROUBLESHOOTING"] = HelpFrame:GetNextVerticalPosition()
        HelpFrame:AddText(ORANGE.."問題排除", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_Troubleshooting, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- VERSION INFO:
        local sUnknown = "("..UNKNOWN..")"
        local spc = BLUE.."    "
        local addonTitle = GetAddOnMetadata(kAddonFolderName, "Title") or kAddonFolderName
        local addonVersion = GetAddOnMetadata(kAddonFolderName, "Version") or sUnknown
        HelpFrame:AddText(ORANGE.."版本", 0, 0, bigFont)
        HelpFrame:AddText(spc..addonTitle.."|r:  "..addonVersion, 0, lineSpacing, smallFont)
        HelpFrame:AddText(spc.."Controls|r:  "..(private.UDControls.VERSION or sUnknown), 0, lineSpacing, smallFont)
        if private.ProfilesUI then
            HelpFrame:AddText(spc.."Profiles|r:  "..(private.ProfilesUI.VERSION or sUnknown), 0, lineSpacing, smallFont)
        end
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
        -- Add some space at bottom so we can scroll any topic to the top.
        HelpFrame:AddText(" ", 0, HelpFrame.scrollFrame:GetHeight() - 56, smallFont)

        -- Allow moving the window.
        local w, h = HelpFrame:GetSize()
        local clampW, clampH = w*0.7, h*0.8
        HelpFrame:EnableMouse(true)
        HelpFrame:SetMovable(true)
        HelpFrame:SetClampedToScreen(true)
        HelpFrame:SetClampRectInsets(clampW, -clampW, -clampH, clampH)
        HelpFrame:RegisterForDrag("LeftButton")
        HelpFrame:SetScript("OnDragStart", function() HelpFrame:StartMoving() end)
        HelpFrame:SetScript("OnDragStop", function() HelpFrame:StopMovingOrSizing() end)

        -- EVENTS --
        HelpFrame:SetScript("OnShow", function(self)
                self:SetFrameLevel( self:GetParent():GetFrameLevel()+10 )
                Globals.PlaySound(829)  -- IG_SPELLBOOK_OPEN
            end)
        HelpFrame:SetScript("OnHide", function(self)
                Globals.PlaySound(830)  -- IG_SPELLBOOK_CLOSE
            end)
    end

    -- Scroll to top, or to specified topic.
    local scrollOffset = 0
    if scrollToTopic then
        scrollOffset = HelpFrame.topicOffsets[ scrollToTopic ]
        if scrollOffset then
            scrollOffset = scrollOffset - topMargin
        else
            print(kAddonErrorHeading.."Invalid help topic!  ("..scrollToTopic..")")
            scrollOffset = 0
        end
    end
    HelpFrame:SetVerticalScroll( scrollOffset, scrollDelaySecs )
    if ChangelogFrame and ChangelogFrame:IsShown() then
        HelpFrame:ClearAllPoints()
        HelpFrame:SetPoint("RIGHT", UIParent, "CENTER", -1, 0)
        ChangelogFrame:ClearAllPoints()
        ChangelogFrame:SetPoint("LEFT", UIParent, "CENTER", 1, 0)
    else
        HelpFrame:ClearAllPoints()
        HelpFrame:SetPoint("CENTER", UIParent, "CENTER")
    end
    HelpFrame:Show()
    ----Globals.UIFrameFadeIn(HelpFrame, 0.3, 0, 1)
end

-------------------------------------------------------------------------------
function CursorTrail_HideHelp()
    if HelpFrame and HelpFrame:IsShown() then
        HelpFrame:Hide()
        if ChangelogFrame and ChangelogFrame:IsShown() then
            ChangelogFrame:ClearAllPoints()
            ChangelogFrame:SetPoint("CENTER", UIParent, "CENTER")
        end
        return true
    end
    return false
end

-------------------------------------------------------------------------------
function CursorTrail_ToggleHelp(parent)
    if HelpFrame and HelpFrame:IsShown() then
        CursorTrail_HideHelp()
    else
        CursorTrail_ShowHelp(parent)
    end
end

--- End of File ---