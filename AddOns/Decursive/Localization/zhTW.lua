--[[
    This file is part of Decursive.

    Decursive (v 2.7.24) add-on for World of Warcraft UI
    Copyright (C) 2006-2019 John Wellesz (Decursive AT 2072productions.com) ( http://www.2072productions.com/to/decursive.php )

    Decursive is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Decursive is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Decursive.  If not, see <https://www.gnu.org/licenses/>.


    Decursive is inspired from the original "Decursive v1.9.4" by Patrick Bohnet (Quu).
    The original "Decursive 1.9.4" is in public domain ( www.quutar.com )

    Decursive is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY.

    This file was last updated on 2023-09-03T20:24:23Z
--]]
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Traditional Chinese localization
-------------------------------------------------------------------------------

--[=[
--                      YOUR ATTENTION PLEASE
--
--         !!!!!!! TRANSLATORS TRANSLATORS TRANSLATORS !!!!!!!
--
--    Thank you very much for your interest in translating Decursive.
--    Do not edit those files. Use the localization interface available at the following address:
--
--      ################################################################
--      #  http://wow.curseforge.com/projects/decursive/localization/  #
--      ################################################################
--
--    Your translations made using this interface will be automatically included in the next release.
--
--]=]

local addonName, T = ...;
-- big ugly scary fatal error message display function {{{
if not T._FatalError then
-- the beautiful error popup : {{{ -
StaticPopupDialogs["DECURSIVE_ERROR_FRAME"] = {
    text = "|cFFFF0000一鍵驅散錯誤：|r\n%s",
    button1 = "確定",
    OnAccept = function()
        return false;
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
    preferredIndex = 3,
    }; -- }}}
T._FatalError = function (TheError) StaticPopup_Show ("DECURSIVE_ERROR_FRAME", TheError); end
end
-- }}}
if not T._LoadedFiles or not T._LoadedFiles["enUS.lua"] then
    if not DecursiveInstallCorrupted then T._FatalError("Decursive installation is corrupted! (enUS.lua not loaded)"); end;
    DecursiveInstallCorrupted = true;
    return;
end
T._LoadedFiles["zhTW.lua"] = false;

local L = LibStub("AceLocale-3.0"):NewLocale("Decursive", "zhTW");

if not L then
    T._LoadedFiles["zhTW.lua"] = "2.7.24";
    return;
end;

L["ABOLISH_CHECK"] = "施法前檢查是否需要淨化"
L["ABOUT_AUTHOREMAIL"] = "作者 E-Mail"
L["ABOUT_CREDITS"] = "貢獻者"
L["ABOUT_LICENSE"] = "版權"
L["ABOUT_NOTES"] = "當單獨、小隊和團隊時清除有害狀態，並可使用高級過濾和優先等級系統。"
L["ABOUT_OFFICIALWEBSITE"] = "官方網站"
L["ABOUT_SHAREDLIBS"] = "共用函示庫"
L["ABSENT"] = "不存在 (%s)"
L["AFFLICTEDBY"] = "受 %s 影響"
L["ALT"] = "Alt"
L["AMOUNT_AFFLIC"] = "即時清單顯示人數: "
L["ANCHOR"] = "一鍵驅散文字定位點"
L["BINDING_NAME_DCRMUFSHOWHIDE"] = "顯示/隱藏單位格子"
L["BINDING_NAME_DCRPRADD"] = "新增目標至優先名單"
L["BINDING_NAME_DCRPRCLEAR"] = "清空優先名單"
L["BINDING_NAME_DCRPRLIST"] = "顯示優先名單至聊天視窗"
L["BINDING_NAME_DCRPRSHOW"] = "開/關優先名單"
L["BINDING_NAME_DCRSHOW"] = "顯示/隱藏工具列"
L["BINDING_NAME_DCRSHOWOPTION"] = "顯示設定選項"
L["BINDING_NAME_DCRSKADD"] = "新增目標至忽略名單"
L["BINDING_NAME_DCRSKCLEAR"] = "清空忽略名單"
L["BINDING_NAME_DCRSKLIST"] = "顯示忽略名單至聊天視窗"
L["BINDING_NAME_DCRSKSHOW"] = "開/關忽略名單"
L["BLACK_LENGTH"] = "停留在排除名單的時間: "
L["BLACKLISTED"] = "在排除名單"
L["BLEED"] = "流血"
L["CHARM"] = "魅惑"
L["CLASS_HUNTER"] = "獵人"
L["CLEAR_PRIO"] = "C"
L["CLEAR_SKIP"] = "C"
L["COLORALERT"] = "設定按鍵警示'%s'的顏色"
L["COLORCHRONOS"] = "秒錶"
L["COLORCHRONOS_DESC"] = "設定秒錶顏色"
L["COLORSTATUS"] = "設定當玩家狀態是 '%s' 時的迷你單位格子顏色。"
L["CTRL"] = "Ctrl"
L["CURE_PETS"] = "檢測並淨化寵物"
L["CURSE"] = "詛咒"
L["DEBUG_REPORT_HEADER"] = [=[|cFF11FF33請報告此視窗的內容給 <Archarodim+DcrReport@teaser.fr>|r
|cFF009999（使用 CTRL+A 選擇全部 CTRL+C 復制文本到剪切板）|r
如果發現一鍵驅散任何奇怪的行為也一并報告。
]=]
L["DECURSIVE_DEBUG_REPORT"] = "**** |cFFFF0000一鍵驅散除錯報告|r ****"
L["DECURSIVE_DEBUG_REPORT_BUT_NEW_VERSION"] = [=[|cFF11FF33D一鍵驅散啟動失敗但請勿擔心! 一個新版本的一鍵驅散已經被偵測到 (%s)。你只需要執行更新。前往curse.com並搜索"Decursive" 或使用Curse Client，此服務會自動更新所有您最愛的UI。|r
|cFFFF1133 所以請不要浪費你的時間回報此錯誤，因為它也許已被修正。安裝新更新並排除問題! |r
|cFF11FF33 感謝你閱讀此訊息! |r
]=]
L["DECURSIVE_DEBUG_REPORT_NOTIFY"] = [=[一個出錯報告可用！
輸入 |cFFFF0000/DCRREPORT|r 查看]=]
L["DECURSIVE_DEBUG_REPORT_SHOW"] = "除錯報告可用！"
L["DECURSIVE_DEBUG_REPORT_SHOW_DESC"] = "顯示作者需要看到的除錯報告…"
L["DEFAULT_MACROKEY"] = "`"
L["DEV_VERSION_ALERT"] = [=[您正在使用的是開發版本的一鍵驅散。

如果不想參加測試新功能與修復，得到遊戲中的除錯報告后發送問題給作者，請“不要使用此版本”並從 curse.com 和 wowace.com 下載最新的“穩定”版本。

這條消息只將在版本更新中顯示一次]=]
L["DEV_VERSION_EXPIRED"] = [=[此開發版一鍵驅散已過期。
請從 CURSE.COM 和 WOWACE.COM 下載最新的開發版或使用當前穩定版。謝謝！ ^_^
此提示每兩天顯示一次。]=]
L["DEWDROPISGONE"] = "Alt+右鍵 開啟設定選項。"
L["DISABLEWARNING"] = [=[一鍵驅散已停用！

如欲啟用, 輸入 |cFFFFAA44/DCR ENABLE|r]=]
L["DISEASE"] = "疾病"
L["DONOT_BL_PRIO"] = "不新增優先名單的玩家到排除名單"
L["DONT_SHOOT_THE_MESSENGER"] = "一鍵驅散僅提供事件報告。問題並非由一鍵驅散產生，請尋找真正錯誤來源。"
L["FAILEDCAST"] = [=[|cFF22FFFF%s %s|r |cFFAA0000對|r %s釋放失敗
|cFF00AAAA%s|r]=]
L["FOCUSUNIT"] = "監控單位"
L["FUBARMENU"] = "Fubar 選單"
L["FUBARMENU_DESC"] = "Fubar 圖示相關設定"
L["GLOR1"] = "紀念 Glorfindal"
L["GLOR2"] = [=[一鍵驅散獻給匆匆離我們而去的 Bertrand
他將永遠被我們所銘記。]=]
L["GLOR3"] = [=[紀念 Bertrand 
1969 - 2007]=]
L["GLOR4"] = [=[對於那些在魔獸世界裡遇見過 Glorfindal 的人來說，他是一個重承諾的男人，也是一個有超凡魅力的領袖。

友誼和慈愛將永植於他們的心中。他在遊戲中就如同在他生活中一樣的無私，彬彬有禮，樂於奉獻，最重要的是他對生活充滿熱情。

他離開我們的時候才僅僅38歲，隨他離去的絕不會是虛擬世界匿名的角色；在這裡還有一群忠實的朋友在永遠想念他。]=]
L["GLOR5"] = "他將永遠被我們所銘記。"
L["HANDLEHELP"] = "拖曳移動全部的迷你單位格子 (MUF)"
L["HIDE_MAIN"] = "隱藏一鍵驅散視窗工具列"
L["HIDESHOW_BUTTONS"] = "顯示/隱藏按鈕和鎖定/解鎖 \"一鍵驅散\" 工具列"
L["HLP_LEFTCLICK"] = "左鍵"
L["HLP_LL_ONCLICK_TEXT"] = [=[即時清單不是用來點擊的。請先爬文學習如何使用這個插件，Google '一鍵驅散' 或在 WoWAce.com 搜尋 'Decursive'。
(要移動這個清單必須移動一鍵驅散工具列，輸入 /dcrshow 和使用 Alt-左鍵來移動)]=]
L["HLP_MIDDLECLICK"] = "中鍵"
L["HLP_NOTHINGTOCURE"] = "沒有可處理的負面效果！"
L["HLP_RIGHTCLICK"] = "右鍵"
L["HLP_USEXBUTTONTOCURE"] = "用 \"%s\" 來淨化這個負面效果！"
L["HLP_WRONGMBUTTON"] = "錯誤的滑鼠按鍵！"
L["IGNORE_STEALTH"] = "忽略潛行的玩家"
L["IS_HERE_MSG"] = "一鍵驅散已經啟動，請核對設定選項。"
L["LIST_ENTRY_ACTIONS"] = [=[|cFF33AA33[CTRL]|r-左鍵: 移除該玩家
 |cFF33AA33左|r-鍵: 提升該玩家順序
 |cFF33AA33右|r-鍵: 降低該玩家順序
 |cFF33AA33[SHIFT] 左|r-鍵: 將該玩家置頂
 |cFF33AA33[SHIFT] 右|r-鍵: 將該玩家置底]=]
L["MACROKEYALREADYMAPPED"] = [=[警告：巨集對應按鍵 [%s] 先前對應到 '%s' 動作。
當你設定別的巨集按鍵後一鍵驅散會回復此按鍵原有的對應動作。]=]
L["MACROKEYMAPPINGFAILED"] = "按鍵 [%s] 不能被對應到一鍵驅散巨集！"
L["MACROKEYMAPPINGSUCCESS"] = "按鍵 [%s] 已成功對應到一鍵驅散巨集。"
L["MACROKEYNOTMAPPED"] = "一鍵驅散巨集未對應到一個按鍵，你可以透過設定選單來設定此一按鍵。(別錯過這個神奇的功能)"
L["MAGIC"] = "魔法"
L["MAGICCHARMED"] = "魔法誘惑"
L["MISSINGUNIT"] = "找不到的單位"
L["NEW_VERSION_ALERT"] = [=[已檢測到新版本的一鍵驅散：|cFFEE7722%q|r 發佈於 |cFFEE7722%s|r！


請前往|cFFFF0000WoWAce.com|r下載！
--------]=]
L["NORMAL"] = "一般"
L["NOSPELL"] = "沒有可用法術"
L["NOTICE_FRAME_TEMPLATE"] = [=[|cFFFF0000一鍵驅散 - 提醒|r

%s
]=]
L["OPT_ABOLISHCHECK_DESC"] = "檢查玩家身上是否有淨化法術在運作。"
L["OPT_ABOUT"] = "關於"
L["OPT_ADD_A_CUSTOM_SPELL"] = "新增自訂法術"
L["OPT_ADD_A_CUSTOM_SPELL_DESC"] = "點擊這裡並 Shift+點擊技能書上的法術。也可以直接寫法術名稱或數字 ID。"
L["OPT_ADD_BLEED_EFFECT_ID"] = "新增流血效果"
L["OPT_ADD_BLEED_EFFECT_ID_DESC"] = "輸入法術 ID 來直接新增流血效果 (可在 wowhead.com 找到法術 ID)。"
L["OPT_ADDDEBUFF"] = "新增負面效果到清單中"
L["OPT_ADDDEBUFF_DESC"] = "將一個新的負面效果新增到清單中。"
L["OPT_ADDDEBUFF_USAGE"] = "<輸入負面效果法術 ID> (可以在 WoWHead.com 的網址中找到法術 ID)"
L["OPT_ADDDEBUFFFHIST"] = "新增最近驅散的負面效果"
L["OPT_ADDDEBUFFFHIST_DESC"] = "從最近驅散的歷史記錄中新增負面效果"
L["OPT_ADVDISP"] = "進階顯示選項"
L["OPT_ADVDISP_DESC"] = "可設定邊框與中央色塊各自的透明度，以及迷你單位格子之間的距離。"
L["OPT_AFFLICTEDBYSKIPPED"] = "%s 受到 %s 的影響，但將被忽略。"
L["OPT_ALLOWMACROEDIT"] = "允許巨集版本"
L["OPT_ALLOWMACROEDIT_DESC"] = "啟用此項以防止一鍵驅散更新巨集，可自行編輯所需的巨集。"
L["OPT_ALWAYSIGNORE"] = "非戰鬥中也忽略"
L["OPT_ALWAYSIGNORE_DESC"] = "啟用時，即使脫離戰鬥也忽略該負面效果而不解除。"
L["OPT_AMOUNT_AFFLIC_DESC"] = "設定即時清單最多顯示幾人。"
L["OPT_ANCHOR_DESC"] = "顯示自訂視窗的文字定位點。"
L["OPT_AUTOHIDEMFS"] = "隱藏迷你單位格子："
L["OPT_AUTOHIDEMFS_DESC"] = "選擇何時自動隱藏迷你單位格子"
L["OPT_BLACKLENTGH_DESC"] = "設定一個人停留在排除名單中的時間。"
L["OPT_BLEED_EFFECT_BAD_SPELLID"] = "法術 ID 錯誤。只能輸入數字，並且和  wowhead.com 找到的法術 ID 相同。"
L["OPT_BLEED_EFFECT_DESCRIPTION"] = "說明 (法術 ID: |cFF00C000%s|r)"
L["OPT_BLEED_EFFECT_HOLDER"] = "流血效果管理"
L["OPT_BLEED_EFFECT_HOLDER_DESC"] = "管理流血效果的偵測方式"
L["OPT_BLEED_EFFECT_IDENTIFIERS"] = "流血效果說明關鍵字:"
L["OPT_BLEED_EFFECT_IDENTIFIERS_DESC"] = [=[每個關鍵字都必須符合造成目標流血的減益效果的|cFFFF0000說明|r，並且能夠用來辨識為此效果。

每行一個關鍵字。

清空欄位會重置為預設關鍵字。

你會需要依據所使用的語言來手動調整這些關鍵字。
可以參考下方列出預先設定好的流血效果清單，說明中至少要包含一個關鍵字。(符合的關鍵字在下方的每個效果說明中會顯著標示出來)。

(也可以使用 Lua pattern，每行一個 pattern)
]=]
L["OPT_BLEED_EFFECT_UNKNOWN_SPELL"] = "未知的法術 (%s)"
L["OPT_BLEEDCHECK_DESC"] = "勾選時，將無法看到和驅散流血效果。"
L["OPT_BORDERTRANSP"] = "邊框透明度"
L["OPT_BORDERTRANSP_DESC"] = "設定邊框的透明度。"
L["OPT_CENTERTEXT"] = "中央計數器:"
L["OPT_CENTERTEXT_DESC"] = [=[顯示每個迷你單位格子的中心最上面的（根據你的優先次序）受影響信息。

其中之一：
- 剩餘時間直至結束
- 從過去時間的影響量(Time elapsed since the affliction hit)
- 距離數]=]
L["OPT_CENTERTEXT_DISABLED"] = "關閉"
L["OPT_CENTERTEXT_ELAPSED"] = "經過時間"
L["OPT_CENTERTEXT_STACKS"] = "距離數"
L["OPT_CENTERTEXT_TIMELEFT"] = "剩餘時間"
L["OPT_CENTERTRANSP"] = "中央透明度"
L["OPT_CENTERTRANSP_DESC"] = "設定中間色塊的透明度"
L["OPT_CHARMEDCHECK_DESC"] = "選取後你可以看見並處理被媚惑的玩家。"
L["OPT_CHATFRAME_DESC"] = "顯示到預設的聊天視窗。"
L["OPT_CHECKOTHERPLAYERS"] = "檢查其他玩家"
L["OPT_CHECKOTHERPLAYERS_DESC"] = "顯示當前小隊或團隊玩家一鍵驅散版本（不能顯示 Decursive 2.4.6之前的版本）。"
L["OPT_CMD_DISBLED"] = "已停用"
L["OPT_CMD_ENABLED"] = "啟用"
L["OPT_CREATE_VIRTUAL_DEBUFF"] = "建立虛擬負面效果測試"
L["OPT_CREATE_VIRTUAL_DEBUFF_DESC"] = "讓你看到當負面效果發生時一鍵驅散的樣子。"
L["OPT_CURE_PRIORITY_NUM"] = "優先級 #%d"
L["OPT_CUREPETS_DESC"] = "寵物會被顯示出來也可淨化。"
L["OPT_CURINGOPTIONS"] = "淨化選項"
L["OPT_CURINGOPTIONS_DESC"] = "淨化的選項包含更改每種負面效果與順序的選項。"
L["OPT_CURINGOPTIONS_EXPLANATION"] = [=[選擇你想要治療的傷害類型，未經檢查的類型將被一鍵驅散完全忽略。

綠色數字確定優先的傷害。這一優先事項將影響幾方面：

- 如果一個玩家獲得許多類型的減益效果，一鍵驅散將優先顯示。

- 滑鼠按鈕點擊將治療減益（第一法術是左鍵點擊，第二法術是右鍵點擊，等等…）

所有這一切的說明文檔（請見）：
http://www.wowace.com/addons/decursive/]=]
L["OPT_CURINGORDEROPTIONS"] = "淨化順序設定"
L["OPT_CURSECHECK_DESC"] = "選取後你可以看見並解除被詛咒的玩家。"
L["OPT_CUSTOM_SPELL_ALLOW_EDITING"] = "允許巨集編輯（僅限進階使用者）"
L["OPT_CUSTOM_SPELL_ALLOW_EDITING_DESC"] = [=[如果要編輯內部巨集請勾選此項，一鍵驅散將使用您的自訂法術。

注意：勾選此項將允許你編輯由一鍵驅散所管理的法術。

If a spell is already listed you'll need to remove it first to enable macro editing.

（--- 僅限進階使用者 ---）]=]
L["OPT_CUSTOM_SPELL_CURE_TYPES"] = "傷害類型"
L["OPT_CUSTOM_SPELL_IS_DEFAULT"] = "此法術是一鍵驅散自動配置的一部份，如果此法術無法正常運作，移除或停用此項以回復預設的一鍵驅散設定。"
L["OPT_CUSTOM_SPELL_ISPET"] = "寵物能力"
L["OPT_CUSTOM_SPELL_ISPET_DESC"] = "檢查此技能是否屬於你的寵物，使一鍵驅散能正確偵測並且使用該技能。"
L["OPT_CUSTOM_SPELL_MACRO_MISSING_NOMINAL_SPELL"] = "警告：法術 %q 未出現在巨集中，範圍及冷卻資訊將無法符合。"
L["OPT_CUSTOM_SPELL_MACRO_MISSING_UNITID_KEYWORD"] = "缺少結合關鍵字。"
L["OPT_CUSTOM_SPELL_MACRO_TEXT"] = "巨集文字："
L["OPT_CUSTOM_SPELL_MACRO_TEXT_DESC"] = [=[編輯預設的巨集文字。
|cFFFF0000有兩項限制：|r

- 必須指定目標使用 UNITID 關鍵字，將自動被每個迷你單位格子的單位 ID 取代。

- 無論法術在巨集中如何使用，一鍵驅散將保持顯示左方的原始名稱，以利範圍及冷卻的顯示 / 追蹤。
（如果你計畫要使用不同的法術名稱的話，請注意這一點）]=]
L["OPT_CUSTOM_SPELL_MACRO_TOO_LONG"] = "你的巨集過長，需移除 %d 個字元。"
L["OPT_CUSTOM_SPELL_PRIORITY"] = "法術優先級"
L["OPT_CUSTOM_SPELL_PRIORITY_DESC"] = [=[當有多個法術可以治療相同類型的傷害，將選擇優先級高的。

注意一鍵驅散預設管理的能力，優先程度設定範圍為0到9。

因此如果你將自行設定之施法能力的優先程度設為負值，此能力只有在預設施法能力無法使用時才會被選用。]=]
L["OPT_CUSTOM_SPELL_UNAVAILABLE"] = "不可用"
L["OPT_CUSTOM_SPELL_UNIT_FILTER"] = "單位過濾方式"
L["OPT_CUSTOM_SPELL_UNIT_FILTER_DESC"] = "選擇這個法術套用的單位"
L["OPT_CUSTOM_SPELL_UNIT_FILTER_NONE"] = "所有單位"
L["OPT_CUSTOM_SPELL_UNIT_FILTER_NONPLAYER"] = "只有其他"
L["OPT_CUSTOM_SPELL_UNIT_FILTER_PLAYER"] = "只有玩家"
L["OPT_CUSTOMSPELLS"] = "自訂法術"
L["OPT_CUSTOMSPELLS_DESC"] = [=[這裡新增法術以擴展一鍵驅散的自動配置。
您的自訂法術總是會有高優先權，並且將蓋過與替代預設的法術(只有在你的角色可以使用這些法術的時候)。
]=]
L["OPT_CUSTOMSPELLS_EFFECTIVE_ASSIGNMENTS"] = "有效法術分配"
L["OPT_DEBCHECKEDBYDEF"] = [=[

Checked by default]=]
L["OPT_DEBUFFENTRY_DESC"] = "選擇戰鬥中要忽略受到此負面效果影響的職業。"
L["OPT_DEBUFFFILTER"] = "負面效果過濾設定"
L["OPT_DEBUFFFILTER_DESC"] = "設定戰鬥中要忽略的職業與負面效果"
L["OPT_DELETE_A_CUSTOM_SPELL"] = "移除"
L["OPT_DISABLEABOLISH"] = "不使用\"驅散\"法術"
L["OPT_DISABLEABOLISH_DESC"] = "如啟用，一鍵驅散將為“無效”減益選擇使用“淨化疾病”和“淨化中毒”。"
L["OPT_DISABLEMACROCREATION"] = "禁止創建巨集"
L["OPT_DISABLEMACROCREATION_DESC"] = "一鍵驅散巨集將不再創建和保留"
L["OPT_DISEASECHECK_DESC"] = "選取後你可以看見並治療生病的玩家。"
L["OPT_DISPLAYOPTIONS"] = "顯示設定"
L["OPT_DONOTBLPRIO_DESC"] = "設定到優先清單的玩家不會被移入排除清單中。"
L["OPT_ENABLE_A_CUSTOM_SPELL"] = "啟用"
L["OPT_ENABLE_BLEED_EFFECTS_DETECTION"] = "發現流血效果"
L["OPT_ENABLE_BLEED_EFFECTS_DETECTION_DESC"] = "啟用當新的流血效果說明含有在 '流血效果關鍵字' 欄位中所出現的關鍵字時，一鍵驅散會發現新的流血效果。"
L["OPT_ENABLE_LIVELIST"] = "啟用即時清單"
L["OPT_ENABLE_LIVELIST_DESC"] = [=[顯示受影響的玩家清單。

移動一鍵驅散工具列來移動清單 (輸入 /DCRSHOW 顯示工具列)。]=]
L["OPT_ENABLEDEBUG"] = "啟用除錯"
L["OPT_ENABLEDEBUG_DESC"] = "啟用除錯輸出"
L["OPT_ENABLEDECURSIVE"] = "啟用一鍵驅散"
L["OPT_FILTERED_DEBUFF_RENAMED"] = "已過濾的負面效果 \"%s\" 被自動重新命名成 \"%s\" (法術 ID %d)"
L["OPT_FILTEROUTCLASSES_FOR_X"] = "在戰鬥中指定的職業%q將被忽略。"
L["OPT_GENERAL"] = "一般選項"
L["OPT_GROWDIRECTION"] = "反向顯示"
L["OPT_GROWDIRECTION_DESC"] = "迷你單位格子會從尾端開始顯示。"
L["OPT_HIDEMFS_GROUP"] = "單人或小隊"
L["OPT_HIDEMFS_GROUP_DESC"] = "不在團隊中時隱藏迷你單位格子。"
L["OPT_HIDEMFS_NEVER"] = "永不自動隱藏"
L["OPT_HIDEMFS_NEVER_DESC"] = "從不自動隱藏迷你單位格子。"
L["OPT_HIDEMFS_RAID"] = "團隊"
L["OPT_HIDEMFS_RAID_DESC"] = "在團隊中時隱藏迷你單位格子。"
L["OPT_HIDEMFS_SOLO"] = "單人"
L["OPT_HIDEMFS_SOLO_DESC"] = "不在團隊或隊伍中時隱藏迷你單位格子。"
L["OPT_HIDEMUFSHANDLE"] = "隱藏迷你單位格子控制點"
L["OPT_HIDEMUFSHANDLE_DESC"] = [=[隱藏迷你單位格子（MUF）的控制點並禁止移動。
使用相同的指令恢復顯示。]=]
L["OPT_IGNORESTEALTHED_DESC"] = "忽略潛行的玩家。"
L["OPT_INPUT_SPELL_BAD_INPUT_ALREADY_HERE"] = "法術已在清單中！"
L["OPT_INPUT_SPELL_BAD_INPUT_DEFAULT_SPELL"] = "一鍵驅散已經包含此法術。Shift+點擊此法術或輸入它的 ID 新增一個特殊等級。"
L["OPT_INPUT_SPELL_BAD_INPUT_ID"] = "法術 ID 不可用！"
L["OPT_INPUT_SPELL_BAD_INPUT_NOT_SPELL"] = "不能在技能書中找到法術!"
L["OPT_IS_BLEED_EFFECT"] = "是流血效果"
L["OPT_IS_BLEED_EFFECT_DESC"] = [=[勾選此選項讓一鍵驅散將此效果視為 '流血' 類型。
誤認時也可取消勾選...]=]
L["OPT_ISNOTVALID_SPELLID"] = "不是有效的法術 ID"
L["OPT_KNOWN_BLEED_EFFECTS"] = "已知的流血效果"
L["OPT_LIVELIST"] = "即時清單"
L["OPT_LIVELIST_DESC"] = [=[這裡可以設定受到負面效果的單位清單。

要移動清單必須移動 "一鍵驅散" 工具列，某些設定只有在工具列顯示時才能調整。在聊天文字框輸入 |cff20CC20/DCRSHOW|r 或在第一個迷你單位格子上方點 Shift-右鍵可以顯示工具列。

設定好即時清單的位置、大小和透明度後，便可以放心的輸入 |cff20CC20/DCRHIDE|r 隱藏一鍵驅散工具列。]=]
L["OPT_LLALPHA"] = "即時清單的透明度"
L["OPT_LLALPHA_DESC"] = "變更一鍵驅散工具列及即時清單的透明度(工具列必須設定為顯示)"
L["OPT_LLSCALE"] = "縮放即時清單"
L["OPT_LLSCALE_DESC"] = "設定一鍵驅散狀態條以及其即時清單的大小（狀態條必須顯示）"
L["OPT_LVONLYINRANGE"] = "只顯示法術有效範圍內的目標"
L["OPT_LVONLYINRANGE_DESC"] = "即時清單只顯示淨化法術有效範圍內的目標。"
L["OPT_MACROBIND"] = "設定巨集按鍵"
L["OPT_MACROBIND_DESC"] = [=[定義呼叫一鍵驅散巨集的按鍵。

按你想設定的按鍵然後按 'Enter' 鍵儲存設定(滑鼠要移動到編輯區域)]=]
L["OPT_MACROOPTIONS"] = "巨集設定選項"
L["OPT_MACROOPTIONS_DESC"] = "設定一鍵驅散產生的巨集如何動作"
L["OPT_MAGICCHARMEDCHECK_DESC"] = "選取後你可以看見並處理被魔法媚惑的玩家。"
L["OPT_MAGICCHECK_DESC"] = "選取後你可以看見並處理受魔法影響的玩家。"
L["OPT_MAXMFS"] = "最多顯示幾個"
L["OPT_MAXMFS_DESC"] = "設定在螢幕上最多顯示幾個迷你單位格子。"
L["OPT_MESSAGES"] = "訊息設定"
L["OPT_MESSAGES_DESC"] = "設定訊息顯示。"
L["OPT_MFALPHA"] = "透明度"
L["OPT_MFALPHA_DESC"] = "設定沒有減益效果時迷你單位格子的透明度。"
L["OPT_MFPERFOPT"] = "效能設定選項"
L["OPT_MFREFRESHRATE"] = "刷新頻率"
L["OPT_MFREFRESHRATE_DESC"] = "設定多久刷新一次(一次可刷新一個或數個迷你單位格子)。"
L["OPT_MFREFRESHSPEED"] = "刷新速度"
L["OPT_MFREFRESHSPEED_DESC"] = "設定每次刷新多少個迷你單位格子。"
L["OPT_MFSCALE"] = "迷你單位格子大小"
L["OPT_MFSCALE_DESC"] = "設定螢幕上迷你單位格子的大小。"
L["OPT_MFSETTINGS"] = "迷你單位格子(MUF)設定選項"
L["OPT_MFSETTINGS_DESC"] = "設定迷你單位格子以顯示不同的負面類型與順序。"
L["OPT_MUFFOCUSBUTTON"] = "監控按鈕："
L["OPT_MUFHANDLE_HINT"] = "移動迷你單位格子：在第一個迷你單位格子之上方按住 Alt+拖曳的看不見的方塊。"
L["OPT_MUFMOUSEBUTTONS"] = "滑鼠綁定"
L["OPT_MUFMOUSEBUTTONS_DESC"] = [=[設定每個迷你單位格子滑鼠按鈕的警報顏色。

每個優先級數字代表不同的負面效果類型，如同  '|cFFFF5533淨化選項|r' 設定中所顯示的類型。

用於驅散每種負面類型的法術都是預先設定好的，可以從 '|cFF00DDDD自訂法術|r' 設定中來更改。]=]
L["OPT_MUFSCOLORS"] = "顏色"
L["OPT_MUFSCOLORS_DESC"] = [=[設定迷你單位格子不同負面類型的顏色與順序的選項。"

每個優先級數字代表不同的負面效果類型，如同  '|cFFFF5533淨化選項|r' 設定中所顯示的類型。]=]
L["OPT_MUFSVERTICALDISPLAY"] = "垂直顯示"
L["OPT_MUFSVERTICALDISPLAY_DESC"] = "迷你單位格子視窗將垂直增長"
L["OPT_MUFTARGETBUTTON"] = "目標按鈕："
L["OPT_NEWVERSIONBUGMENOT"] = "新版本通知"
L["OPT_NEWVERSIONBUGMENOT_DESC"] = "如果有較新版本的一鍵驅散被檢測到，每 7 天將顯示一個彈出警報。"
L["OPT_NOKEYWARN"] = "沒有設定按鍵時警告"
L["OPT_NOKEYWARN_DESC"] = "巨集按鍵沒有設定時顯示警告"
L["OPT_NOSTARTMESSAGES"] = "停用歡迎訊息"
L["OPT_NOSTARTMESSAGES_DESC"] = "移除每次登入時在聊天框架顯示的兩個一鍵驅散訊息。"
L["OPT_OPTIONS_DISABLED_WHILE_IN_COMBAT"] = "此選項戰鬥中被停用。"
L["OPT_PERFOPTIONWARNING"] = "警告：不要更改這些值，除非你確切知道你在做什麼。這些設置可以對遊戲性能影響很大。大多數用戶應當使用0.1和10的默認值。"
L["OPT_PLAYSOUND_DESC"] = "有玩家中了負面效果時發出音效。"
L["OPT_POISONCHECK_DESC"] = "選取後你可以看見並清除中毒的玩家。"
L["OPT_PRINT_CUSTOM_DESC"] = "顯示到自訂的聊天視窗。"
L["OPT_PRINT_ERRORS_DESC"] = "顯示錯誤訊息。"
L["OPT_PROFILERESET"] = "重置設定檔..."
L["OPT_RANDOMORDER_DESC"] = "隨機顯示與淨化玩家 (不推薦使用)。"
L["OPT_READD_DEFAULT_BLEED_EFFECTS"] = "重新加入預設值"
L["OPT_READD_DEFAULT_BLEED_EFFECTS_DESC"] = "重新將一鍵驅散預設的流血效果加入倒清單中。"
L["OPT_READDDEFAULTSD"] = "回復預設負面效果"
L["OPT_READDDEFAULTSD_DESC1"] = [=[新增被移除的預設負面效果
你的設定不會被改變。]=]
L["OPT_READDDEFAULTSD_DESC2"] = "全部的預設負面效果都在此清單中。"
L["OPT_REMOVESKDEBCONF"] = [=[你確定要把
 '%s' 
 從負面效果忽略清單中移除？]=]
L["OPT_REMOVETHISDEBUFF"] = "移除此負面效果"
L["OPT_REMOVETHISDEBUFF_DESC"] = "將 '%s' 從忽略清單移除。"
L["OPT_RESET_DEFAULT_BLEED_EFFECTS"] = "清空清單"
L["OPT_RESET_DEFAULT_BLEED_EFFECTS_DESC"] = "清空清單並且恢復成預設值，所有已加入和偵測到的減益效果都會被清除!!"
L["OPT_RESETDEBUFF"] = "重置此負面效果"
L["OPT_RESETDTDCRDEFAULT"] = "重置 '%s' 為一鍵驅散預設值。"
L["OPT_RESETMUFMOUSEBUTTONS"] = "重置"
L["OPT_RESETMUFMOUSEBUTTONS_DESC"] = "重置滑鼠按鈕指派為默認。"
L["OPT_RESETOPTIONS"] = "重置為原始設定"
L["OPT_RESETOPTIONS_DESC"] = "回復目前的設定檔為原始設定"
L["OPT_RESTPROFILECONF"] = [=[你確定要重置
 '(%s) %s'
 為原始設定?]=]
L["OPT_REVERSE_LIVELIST_DESC"] = "由下到上填滿即時清單。"
L["OPT_SCANLENGTH_DESC"] = "設定掃描時間間隔。"
L["OPT_SETAFFTYPECOLOR_DESC"] = [=[設定 "%s" 負面效果類型的顏色。

(大部分會出現在迷你單位格子的滑鼠提示和即時清單中)]=]
L["OPT_SHOW_STEALTH_STATUS"] = "顯示潛行狀態"
L["OPT_SHOW_STEALTH_STATUS_DESC"] = "當玩家前行時，他的迷你單位格子將有一個特殊的顏色"
L["OPT_SHOWBORDER"] = "顯示職業顏色邊框"
L["OPT_SHOWBORDER_DESC"] = "迷你單位格子邊框會顯示出該玩家的職業代表顏色。"
L["OPT_SHOWHELP"] = "顯示小提示"
L["OPT_SHOWHELP_DESC"] = "當滑鼠移到一個迷你單位格子上時顯示小提示。"
L["OPT_SHOWMFS"] = "在螢幕上顯示迷你單位格子 (MUF)"
L["OPT_SHOWMFS_DESC"] = "如果你要在螢幕上按按鍵清除就必須點選這個設定。"
L["OPT_SHOWMINIMAPICON"] = "迷你地圖圖標"
L["OPT_SHOWMINIMAPICON_DESC"] = "啟用迷你地圖小圖示。"
L["OPT_SHOWTOOLTIP_DESC"] = "在即時清單跟迷你單位格子上顯示負面效果的小提示。"
L["OPT_SPELL_DESCRIPTION_LOADING"] = "正在載入說明...請稍後再回來看看。"
L["OPT_SPELL_DESCRIPTION_UNAVAILABLE"] = "沒有說明"
L["OPT_SPELLID_MISSING_READD"] = "必須使用此負面效果的法術 ID 來將它重新加入才能看到正確的說明，而不是這段訊息。"
L["OPT_STICKTORIGHT"] = "向右對齊"
L["OPT_STICKTORIGHT_DESC"] = "設定這個選項將會使迷你單位格子由右邊向左邊成長"
L["OPT_TESTLAYOUT"] = "測試版面配置"
L["OPT_TESTLAYOUT_DESC"] = [=[新建測試單位以測試顯示版面配置。
（點擊後稍等片刻）]=]
L["OPT_TESTLAYOUTUNUM"] = "單位數字"
L["OPT_TESTLAYOUTUNUM_DESC"] = "設定新建測試單位數字。"
L["OPT_TIE_LIVELIST_DESC"] = "即時清單顯示與否取決於 \"一鍵驅散\" 工具列是否顯示。"
L["OPT_TIECENTERANDBORDER"] = "固定格子中心與邊框透明度"
L["OPT_TIECENTERANDBORDER_OPT"] = "選取時邊界的透明度固定為中央的一半。"
L["OPT_TIEXYSPACING"] = "固定水平與垂直距離"
L["OPT_TIEXYSPACING_DESC"] = "固定迷你單位格子之間的水平與垂直距離 (空白)。"
L["OPT_UNITPERLINES"] = "每一行單位數"
L["OPT_UNITPERLINES_DESC"] = "設定每行最多顯示幾個迷你單位格子。"
L["OPT_USERDEBUFF"] = "這項負面效果不是一鍵驅散預設的效果之一"
L["OPT_XSPACING"] = "水平距離"
L["OPT_XSPACING_DESC"] = "設定迷你單位格子之間的水平距離。"
L["OPT_YSPACING"] = "垂直距離"
L["OPT_YSPACING_DESC"] = "設定迷你單位格子之間的垂直距離。"
L["OPTION_MENU"] = "一鍵驅散選項"
L["PLAY_SOUND"] = "有玩家需要淨化時發出音效"
L["POISON"] = "中毒"
L["POPULATE"] = "p"
L["POPULATE_LIST"] = "一鍵驅散名單快速新增介面"
L["PRINT_CHATFRAME"] = "在聊天視窗顯示訊息"
L["PRINT_CUSTOM"] = "在遊戲畫面中顯示訊息"
L["PRINT_ERRORS"] = "顯示錯誤訊息"
L["PRIORITY_LIST"] = "一鍵驅散優先名單"
L["PRIORITY_SHOW"] = "P"
L["RANDOM_ORDER"] = "隨機淨化玩家"
L["REVERSE_LIVELIST"] = "反向顯示即時清單"
L["SCAN_LENGTH"] = "即時檢測時間間隔(秒): "
L["SHIFT"] = "Shift"
L["SHOW_MSG"] = "要顯示一鍵驅散工具列，請輸入 /dcrshow。"
L["SHOW_TOOLTIP"] = "顯示即時清單的滑鼠提示"
L["SKIP_LIST_STR"] = "一鍵驅散忽略名單"
L["SKIP_SHOW"] = "S"
L["SPELL_FOUND"] = "找到 %s 法術"
L["STEALTHED"] = "已潛行"
L["STR_CLOSE"] = "關閉"
L["STR_DCR_PRIO"] = "一鍵驅散優先名單"
L["STR_DCR_SKIP"] = "一鍵驅散忽略名單"
L["STR_GROUP"] = "隊伍 "
L["STR_OPTIONS"] = "一鍵驅散設定選項"
L["STR_OTHER"] = "其他"
L["STR_POP"] = "快速新增清單"
L["STR_QUICK_POP"] = "快速新增介面"
L["SUCCESSCAST"] = "|cFF22FFFF%s %s|r |cFF00AA00成功淨化|r %s"
L["TARGETUNIT"] = "選取目標"
L["TIE_LIVELIST"] = "即時清單顯示與 DCR 視窗連結"
L["TOC_VERSION_EXPIRED"] = [=[你的一鍵驅散版本已經過期。當前魔獸世界版本比你的一鍵驅散版本新。
你需要更新一鍵驅散以修正潛在的錯誤。

前往curse.com搜索Decursive，或使用Curse's client軟體更新您全部的使用者外掛。

此訊息將每兩天提示一次。]=]
L["TOO_MANY_ERRORS_ALERT"] = [=[你的UI有太多LUA錯誤 (%d)。你的遊戲體驗正受到影響。關閉或更新產生錯誤的UI以關閉此訊息並重新取得正常的禎數。
你可開啟LUA錯誤報告來辨別產生錯誤的UI (/console scriptErrors 1)。]=]
L["TOOFAR"] = "太遠"
L["UNITSTATUS"] = "玩家狀態: "
L["UNSTABLERELEASE"] = "不穩定測試版"
L["Decursive"] = "一鍵驅散"



T._LoadedFiles["zhTW.lua"] = "2.7.24";
