------------------------------------------------------------
-- MiliUI: 12.1 移除的全域函式相容層
--
-- 12.1 從 FrameXML 移除了一批舊全域（見 Patch_12.1.0/API_changes 的
-- FrameXML Removed 清單）。有些第三方函式庫還在呼叫它們，而且是所有使用該
-- 函式庫的插件一起壞 —— 與其逐一去改函式庫（更新就被覆蓋、而且同一個函式庫
-- 常常有好幾份副本、只有版本最高的那份生效），不如把函式補回來。
--
-- 這些都是普通全域函式，不是受保護的 API，補回來沒有安全性問題。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

-- SetDesaturation(texture, desaturate)
--
-- AceGUI-3.0 的 CheckBox widget（AceGUIWidget-CheckBox.lua 的 SetValue）還在用
-- 它。少了這個函式，任何 AceConfig 選項面板只要含有勾選框就會在建立時丟出
-- 「attempt to call a nil value」，整個面板變成一片空白 —— Stuf 的設定介面就是
-- 這樣壞的，而且 Masque、HandyNotes、Mapster 等等同樣中招。
--
-- 材質本身的 SetDesaturated 方法還在，所以直接轉呼叫即可。
if not SetDesaturation then
    function SetDesaturation(texture, desaturate)
        if texture and texture.SetDesaturated then
            texture:SetDesaturated(desaturate)
        end
    end
end

-- AnimateTexCoords(texture, texW, texH, frameW, frameH, numFrames, elapsed, throttle)
--
-- 12.1 把它收進 TextureUtil 表（Blizzard_SharedXMLBase/TextureUtil.lua 現在是
-- `function TextureUtil.AnimateTexCoords(...)`），全域名稱就沒了。
--
-- LibCustomGlow-1.0 的「按鈕發光」（ButtonGlow_Start）在 OnUpdate 裡用它跑爬行
-- 螞蟻動畫，v24 以前都是直接呼叫全域，因此一開啟這個發光類型就會每幀噴
-- 「attempt to call a nil value」—— Ayije_CDM / Cell / WarpDeplete / MRT 帶的都是
-- 舊版副本。v25 起上游已改成先讀 TextureUtil，所以只要補回全域即可兩邊都活。
if not AnimateTexCoords and TextureUtil and TextureUtil.AnimateTexCoords then
    AnimateTexCoords = TextureUtil.AnimateTexCoords
end
