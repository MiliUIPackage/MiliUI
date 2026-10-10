local _, ns = ...
if GetLocale() ~= "zhTW" then return end
local L = ns.L

-- 共用層（MiliUIWidgets）
L["Apply"] = "套用"
L["Okay"] = "確定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "戰鬥中無法調整設定"

-- 插件名稱
L["MiliUI Character Notes"] = "米利的角色筆記"
L["The MiliUI package still has its own character notes module loaded. Update the package — otherwise you will have two notebooks that do not share data."] = "米利UI套組裡還留著同一支角色筆記。請更新套組，否則會有兩個互不相通的筆記本。"

-- 資料
L["Default font"] = "預設字型"
L["Imported %d notes from the MiliUI package."] = "已從米利UI套組匯入 %d 筆筆記。"
L["Untitled"] = "無標題"
L["New note"] = "新筆記"
L["Note"] = "筆記"

-- 分享
L["Share this note"] = "分享這筆筆記"
L["Share..."] = "分享…"
L["To raid"] = "分享給團隊"
L["To party"] = "分享給隊伍"
L["To guild"] = "分享給公會"
L["Whisper to %s"] = "密語給 %s"
L["No one to share with right now"] = "目前沒有可以分享的對象"
L["Addon messages are blocked during a boss fight, a Mythic+ run or a battleground. Try again afterwards."] = "首領戰、傳奇鑰石計時中與戰場裡無法傳送插件訊息，請結束後再試一次。"
L["This note is too long to share."] = "這筆筆記太長，沒辦法分享。"
L["A note someone shared"] = "有人分享了一筆筆記"
L["Shared by you"] = "你自己分享的"
L["Shared by %s"] = "由 %s 分享"
L["Save"] = "儲存"
L["Saved to your shared notes."] = "已存進「戰隊共用」。"
L["Will be saved to your shared notes."] = "儲存後會放進「戰隊共用」。"
L["That shared note is no longer available — ask them to share it again."] = "這筆分享的內容已經不在了，請對方重新分享一次。"

-- 區塊
L["Add block:"] = "加入區塊："
L["Text"] = "文字"
L["Checkbox"] = "勾選"
L["Bullet"] = "項目"
L["Numbered"] = "編號"
L["Convert to text"] = "轉為文字"
L["Convert to checkbox"] = "轉為勾選框"
L["Convert to bullet"] = "轉為項目符號"
L["Convert to number"] = "轉為編號"
L["Indent (Tab)"] = "增加縮排 (Tab)"
L["Outdent (Shift+Tab)"] = "減少縮排 (Shift+Tab)"
L["Delete this block"] = "刪除此區塊"

-- 主視窗
L["Shared"] = "戰隊共用"
L["Character"] = "角色專屬"
L["Shared notes"] = "戰隊共用筆記"
L["Character note"] = "角色專屬筆記"
L["New"] = "新增"
L["Settings"] = "設定"
L["Search titles and text..."] = "搜尋標題與內容…"
L["Delete"] = "刪除"
L["Delete \"%s\"? This cannot be undone."] = "確定要刪除「%s」？此操作無法復原。"
L["Move to shared notes"] = "移到戰隊共用"
L["Move to this character"] = "移到角色專屬"
L["Pick a character"] = "選擇分身"
L["Nothing matches your search."] = "沒有符合搜尋的結果。"
L["No notes yet. Use New to write one."] = "還沒有筆記，按「新增」寫一筆吧。"

-- 小地圖按鈕
L["Open the notebook"] = "開啟筆記本"
L["Left click: open the notebook"] = "左鍵：開啟筆記本"
L["Right click: more options"] = "右鍵：更多選項"
L["Drag: move around the minimap"] = "拖曳：沿小地圖移動按鈕"

-- 設定視窗
L["General"] = "一般"
L["Sharing"] = "分享"
L["About"] = "關於"
L["Appearance"] = "外觀"
L["Note font"] = "筆記字型"
L["Font size"] = "文字大小"
L["Outline"] = "描邊"
L["None"] = "無"
L["Thick outline"] = "粗描邊"
L["Monochrome outline"] = "單色描邊"
L["Monochrome thick outline"] = "單色粗描邊"
L["Minimap button"] = "小地圖按鈕"
L["Show the notebook button on the minimap"] = "在小地圖旁顯示筆記本按鈕"

L["My group and my guild"] = "隊伍與公會"
L["Nobody"] = "都不接收"
L["How sharing works"] = "分享怎麼運作"
L["Right-click a note (or use the button in the editor) and pick who to share it with. Your group gets a chat line with a link; clicking it opens a preview, and nothing is saved until they press Save."] = "在筆記上按右鍵（或用編輯視窗上的按鈕）選要分享給誰。隊友的聊天視窗會出現一則帶連結的訊息，點開是預覽，按「儲存」才真的存下來。"
L["People without this addon just see the line as ordinary text. Clicking it does nothing for them, and they never see a wall of gibberish."] = "沒裝這支插件的人看到的就是一段普通文字，點下去不會有任何事，也不會看到一堆亂碼。"
L["Receiving"] = "接收"
L["Accept notes from"] = "接收誰分享的筆記"
L["Open the preview at once"] = "收到就直接開預覽"
L["Pop the preview open as soon as a note arrives, without waiting for me to click the link"] = "一收到就打開預覽視窗，不用等我點聊天連結"
L["Good to know"] = "注意事項"
L["The game blocks addon messages during a boss fight, a Mythic+ run and inside battlegrounds. Sharing during those will tell you to try again afterwards."] = "遊戲會在首領戰、傳奇鑰石計時中與戰場裡封鎖插件訊息。那些時候按分享會提示你稍後再試。"

-- 關於
L["A notebook that lives in the game: checkboxes, bullets and numbered blocks, kept either account-wide or per character."] = "住在遊戲裡的筆記本：勾選框、項目符號、編號區塊，可以存成戰隊共用或角色專屬。"
L["Any note can be shared with your group through a chat link."] = "任何一筆筆記都可以用聊天連結分享給隊友。"
L["Commands: |cffffd200/mnote|r opens the notebook, |cffffd200/mnote config|r opens the settings, |cffffd200/mnote debug|r reports recent errors"] = "指令：|cffffd200/mnote|r 開啟筆記本、|cffffd200/mnote config|r 開啟設定、|cffffd200/mnote debug|r 印出最近的錯誤|n|cffffd200/mnote migrate|r 從米利UI套組補搬一次筆記（第一次啟動時剛好沒裝套組的話用得上）"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套組）"
L["This used to be the character notes window of the MiliUI package; your notes were imported the first time this addon ran."] = "這原本是米利UI套組裡的角色筆記視窗；第一次啟動這支插件時，你原本的筆記已經自動搬過來了。"
L["Restore default settings"] = "還原預設設定"
L["Restore every setting to its default? Your notes are not touched."] = "把所有設定還原成預設值？你的筆記不會被動到。"
L["Notes are never deleted by this button."] = "這顆按鈕不會刪掉任何筆記。"
L["Restored the default settings."] = "已還原預設設定。"
L["No errors recorded"] = "沒有記錄到錯誤"
L["The MiliUI package is not loaded, so there is nothing to import."] = "米利UI套組沒有載入，沒有東西可以匯入。"
L["Nothing new to import — everything is already here."] = "沒有新的東西可以匯入，全都已經在這裡了。"

-- 暴雪選項頁
L["Version: %s"] = "版本：%s"
L["Use /mnote to open the notebook"] = "使用 /mnote 開啟筆記本"
L["Open options"] = "開啟設定"
