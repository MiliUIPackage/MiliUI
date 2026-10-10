local _, ns = ...
if GetLocale() ~= "zhCN" then return end
local L = ns.L

-- 共享层（MiliUIWidgets）
L["Apply"] = "应用"
L["Okay"] = "确定"
L["Cancel"] = "取消"
L["Can't change settings during combat"] = "战斗中无法调整设置"

-- 插件名称
L["MiliUI Character Notes"] = "米利的角色笔记"
L["The MiliUI package still has its own character notes module loaded. Update the package — otherwise you will have two notebooks that do not share data."] = "米利UI套组里还留着同一支角色笔记。请更新套组，否则会有两个互不相通的笔记本。"

-- 数据
L["Default font"] = "默认字体"
L["Imported %d notes from the MiliUI package."] = "已从米利UI套组导入 %d 条笔记。"
L["Untitled"] = "无标题"
L["New note"] = "新笔记"
L["Note"] = "笔记"

-- 分享
L["Share this note"] = "分享这条笔记"
L["Share..."] = "分享…"
L["To raid"] = "分享给团队"
L["To party"] = "分享给小队"
L["To guild"] = "分享给公会"
L["Whisper to %s"] = "密语给 %s"
L["No one to share with right now"] = "目前没有可以分享的对象"
L["Addon messages are blocked during a boss fight, a Mythic+ run or a battleground. Try again afterwards."] = "首领战、史诗钥石计时中与战场里无法发送插件消息，请结束后再试一次。"
L["This note is too long to share."] = "这条笔记太长，无法分享。"
L["A note someone shared"] = "有人分享了一条笔记"
L["Shared by you"] = "你自己分享的"
L["Shared by %s"] = "由 %s 分享"
L["Save"] = "保存"
L["Saved to your shared notes."] = "已保存到「战团共享」。"
L["Will be saved to your shared notes."] = "保存后会放进「战团共享」。"
L["That shared note is no longer available — ask them to share it again."] = "这条分享的内容已经不在了，请对方重新分享一次。"

-- 区块
L["Add block:"] = "加入区块："
L["Text"] = "文字"
L["Checkbox"] = "勾选"
L["Bullet"] = "项目"
L["Numbered"] = "编号"
L["Convert to text"] = "转为文字"
L["Convert to checkbox"] = "转为勾选框"
L["Convert to bullet"] = "转为项目符号"
L["Convert to number"] = "转为编号"
L["Indent (Tab)"] = "增加缩进 (Tab)"
L["Outdent (Shift+Tab)"] = "减少缩进 (Shift+Tab)"
L["Delete this block"] = "删除此区块"

-- 主窗口
L["Shared"] = "战团共享"
L["Character"] = "角色专属"
L["Shared notes"] = "战团共享笔记"
L["Character note"] = "角色专属笔记"
L["New"] = "新建"
L["Settings"] = "设置"
L["Search titles and text..."] = "搜索标题与内容…"
L["Delete"] = "删除"
L["Delete \"%s\"? This cannot be undone."] = "确定要删除「%s」？此操作无法撤销。"
L["Move to shared notes"] = "移到战团共享"
L["Move to this character"] = "移到角色专属"
L["Pick a character"] = "选择角色"
L["Nothing matches your search."] = "没有符合搜索的结果。"
L["No notes yet. Use New to write one."] = "还没有笔记，点「新建」写一条吧。"

-- 小地图按钮
L["Open the notebook"] = "打开笔记本"
L["Left click: open the notebook"] = "左键：打开笔记本"
L["Right click: more options"] = "右键：更多选项"
L["Drag: move around the minimap"] = "拖动：沿小地图移动按钮"

-- 设置窗口
L["General"] = "常规"
L["Sharing"] = "分享"
L["About"] = "关于"
L["Appearance"] = "外观"
L["Note font"] = "笔记字体"
L["Font size"] = "文字大小"
L["Outline"] = "描边"
L["None"] = "无"
L["Thick outline"] = "粗描边"
L["Monochrome outline"] = "单色描边"
L["Monochrome thick outline"] = "单色粗描边"
L["Minimap button"] = "小地图按钮"
L["Show the notebook button on the minimap"] = "在小地图旁显示笔记本按钮"

L["My group and my guild"] = "小队与公会"
L["Nobody"] = "都不接收"
L["How sharing works"] = "分享怎么运作"
L["Right-click a note (or use the button in the editor) and pick who to share it with. Your group gets a chat line with a link; clicking it opens a preview, and nothing is saved until they press Save."] = "在笔记上点右键（或用编辑窗口上的按钮）选要分享给谁。队友的聊天窗口会出现一条带链接的消息，点开是预览，按「保存」才真的存下来。"
L["People without this addon just see the line as ordinary text. Clicking it does nothing for them, and they never see a wall of gibberish."] = "没装这支插件的人看到的就是一段普通文字，点下去不会有任何事，也不会看到一堆乱码。"
L["Receiving"] = "接收"
L["Accept notes from"] = "接收谁分享的笔记"
L["Open the preview at once"] = "收到就直接开预览"
L["Pop the preview open as soon as a note arrives, without waiting for me to click the link"] = "一收到就打开预览窗口，不用等我点聊天链接"
L["Good to know"] = "注意事项"
L["The game blocks addon messages during a boss fight, a Mythic+ run and inside battlegrounds. Sharing during those will tell you to try again afterwards."] = "游戏会在首领战、史诗钥石计时中与战场里封锁插件消息。那些时候点分享会提示你稍后再试。"

-- 关于
L["A notebook that lives in the game: checkboxes, bullets and numbered blocks, kept either account-wide or per character."] = "住在游戏里的笔记本：勾选框、项目符号、编号区块，可以存成战团共享或角色专属。"
L["Any note can be shared with your group through a chat link."] = "任何一条笔记都可以用聊天链接分享给队友。"
L["Commands: |cffffd200/mnote|r opens the notebook, |cffffd200/mnote config|r opens the settings, |cffffd200/mnote debug|r reports recent errors"] = "命令：|cffffd200/mnote|r 打开笔记本、|cffffd200/mnote config|r 打开设置、|cffffd200/mnote debug|r 打印最近的错误|n|cffffd200/mnote migrate|r 从米利UI套组补搬一次笔记（第一次启动时刚好没装套组的话用得上）"
L["Author: Mili (MiliUI package)"] = "作者：Mili（米利UI套组）"
L["This used to be the character notes window of the MiliUI package; your notes were imported the first time this addon ran."] = "这原本是米利UI套组里的角色笔记窗口；第一次启动这支插件时，你原本的笔记已经自动搬过来了。"
L["Restore default settings"] = "恢复默认设置"
L["Restore every setting to its default? Your notes are not touched."] = "把所有设置恢复成默认值？你的笔记不会被动到。"
L["Notes are never deleted by this button."] = "这个按钮不会删掉任何笔记。"
L["Restored the default settings."] = "已恢复默认设置。"
L["No errors recorded"] = "没有记录到错误"
L["The MiliUI package is not loaded, so there is nothing to import."] = "米利UI套组没有载入，没有东西可以导入。"
L["Nothing new to import — everything is already here."] = "没有新的东西可以导入，全都已经在这里了。"

-- 暴雪选项页
L["Version: %s"] = "版本：%s"
L["Use /mnote to open the notebook"] = "使用 /mnote 打开笔记本"
L["Open options"] = "打开设置"
