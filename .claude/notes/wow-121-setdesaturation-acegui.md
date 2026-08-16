---
name: wow-121-setdesaturation-acegui
description: "WoW 12.1 removed FrameXML globals (SetDesaturation, AnimateTexCoords); restore them in MiliUI/Fix/DeprecatedGlobals.lua instead of patching each library copy"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-10T03:46:06.403Z
---

12.1 把全域函式 **`SetDesaturation(texture, desaturate)`** 從 FrameXML 移除了（見 `Patch_12.1.0/API_changes` 的 FrameXML Removed 清單）。

**影響範圍遠大於表面**：`AceGUI-3.0` 的 CheckBox widget（`AceGUIWidget-CheckBox.lua` 的 `SetValue`）還在呼叫它。因此**任何含有勾選框的 AceConfig 選項面板，在 12.1 建立時就會丟 `attempt to call a nil value`，整個面板變成一片空白**——而且錯誤常被吞掉，只看得到空白。Ace 上游截至 ACD r92 / AceGUI 41 都還沒修，所以**換新版函式庫沒有用**。

修法是把全域補回來，不要去改函式庫：

```lua
if not SetDesaturation then
    function SetDesaturation(texture, desaturate)
        if texture and texture.SetDesaturated then texture:SetDesaturated(desaturate) end
    end
end
```

放在 `MiliUI/Fix/DeprecatedGlobals.lua`，TOC 排最前面。**不要逐一改函式庫副本**：同一個 widget 在十幾個插件裡各有一份，AceGUI 只讓「版本最高的那份」生效，你無法預測會用到誰的；而且插件更新就被覆蓋。

診斷這類「面板空白」的方法：用 pcall 分別呼叫 `Stuf:GetOptionsTable()`、`AceConfigRegistry:ValidateOptionsTable()`、`AceConfigDialog:Open(appName)`，錯誤會在最後一步現形（見 `MiliUI/Fix/Stuf_OptionsCategory.lua` 的 `/stufopt`）。

**同一批修 Stuf 設定介面時踩到的其他問題**（都在 `SetDesaturation` 之前、各自獨立）：
1. `Stuf_Options` 內附 AceConfigDialog **r82**，其 `AddToBlizOptions` 呼叫 10.0 就移除的 `InterfaceOptions_AddCategory` → 註冊失敗。平時靠別的插件載入 r87+ 才勉強能用，那些插件一停用就壞。
2. `AceGUI` 的 `BlizOptionsGroup` widget 需要 **v26**（v22 缺 10.0 才加的 `OnCommit`/`OnDefault`/`OnRefresh` 別名），否則 Settings canvas 撐不起面板。
3. `Stuf_Options` 是 **LoadOnDemand** 且載入時不呼叫 `CreateOptionFrame()`，所以沒打過 `/stuf` 就完全沒有分類。解法：`options.lua` 尾端補一次 `CreateOptionFrame()`，並由 `MiliUI/Fix/Stuf_OptionsCategory.lua` 在登入時載入它。

1～3 直接改在 `Stuf_Options` 底下（含 Ace 整包換成 Mapster 的 ACD 92 / Registry 22 / AceGUI 41），**Stuf 更新時會被覆蓋**。舊檔備份在該次 session 的 scratchpad。

## AnimateTexCoords（同一類，同一個修法）

12.1 把 `AnimateTexCoords` 收進命名空間表：Blizzard 現在寫成
`function TextureUtil.AnimateTexCoords(...)`（`Blizzard_SharedXMLBase/TextureUtil.lua`），
**沒有留全域別名**。

中招的是 **LibCustomGlow-1.0 的「按鈕發光」（`ButtonGlow_Start`）**：它在 OnUpdate
裡用這個函式跑爬行螞蟻動畫，所以只要把發光類型選成按鈕發光，就會**每幀**噴
`LibCustomGlow-1.0.lua:548: attempt to call a nil value`。本機有五份副本，
Ayije_CDM／Cell／WarpDeplete 是 v24、MRT 是 v19，都直接呼叫全域；只有
BuffReminders 的 v25 已經自己改成 `(TextureUtil and TextureUtil.AnimateTexCoords) or _G.AnimateTexCoords`。

一樣補全域就好（同樣在 `Fix/DeprecatedGlobals.lua`）：

```lua
if not AnimateTexCoords and TextureUtil and TextureUtil.AnimateTexCoords then
    AnimateTexCoords = TextureUtil.AnimateTexCoords
end
```

舊版副本是**呼叫時**才查全域，所以 MiliUI 比它們晚載入也沒關係；v25 是載入時就
取值，但它先讀 `TextureUtil`，不依賴這個補丁。

**通則**：看到 `attempt to call a nil value` 指向某個函式庫裡一行大寫開頭的舊全域，
先去 `Blizzard_SharedXMLBase/` 找同名的 `XxxUtil.<Name>`，多半只是被收進表裡。

相關：[[project-121-addon-migration]]
