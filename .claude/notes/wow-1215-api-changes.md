---
name: wow-1215-api-changes
description: 12.1.5（120105）對插件有影響的 API 變動與 MiliUI 系列已修清單：相容層全拔（GetItemInfo 等舊全域變 nil）、SetAuraBorder 刪除、小地圖新座標框、GetInventoryItemCooldown 第 4 回傳、保護 Cooldown 不能 SetCooldown、ChatFrameTemplate 收件框要補 ScrollToBottomButton；怎麼用 Ketho＋wow-ui-source 比對
metadata:
  node_type: memory
  type: project
  originSessionId: 2ed86f54-d12c-4e9c-82e8-4d150c50b5be
  modified: 2026-10-15T00:00:00.000Z
---

12.1.5（build 69952，2026-09-21）對插件實際有影響的變動，2026-10-15 掃過 MiliUI 系列並修完：

**會硬錯／靜默失效的（已修）**
- **相容層整組移除**：`Blizzard_DeprecatedItemScript`／`CurrencyScript`／`ItemSocketInfo`／`LFG`／`PetInfo`／
  `PvpScript`／`SoundScript`／`TradeInfo`／`Glue`／`WorldElapsedTimerTypes` 都刪了 ⇒ `GetItemInfo`、
  `GetItemInfoInstant`、`GetItemQualityColor`、`IsEquippableItem`、`GetItemIcon`（→ `C_Item.GetItemIconByID`）、
  `GetItemCooldown`、`GetItemCount`、`GetDetailedItemLevelInfo`、`GetCoinTextureString`、`GetZonePVPInfo`、
  `C_LFGList.GetSearchResultMemberInfo` 等全域直接是 nil。**`X and X(...)` 的存在檢查不會報錯但功能靜默消失**
  （MiliUI_Tooltip 的附加 ID 三行就是這樣壞的）。
- **`CustomAuraButton:SetAuraBorder`／`GetAuraBorder`／`ClearAuraBorder` 刪除**：它只是
  `ClearDispelTypeTextures()`＋`AddDispelTypeTexture(tex, options)` 的包裝，直接呼叫後者兩版都通；
  12.1.5 起同一張貼圖 Add 兩次會拋錯。`AddDispelTypeTexture`／`AddPandemicRegion` 不再回 index，
  `Remove*` 改收 region。options 結構沒變。
- **小地圖多了 `MinimapCluster.MinimapContainer.PlayerCoords`**：cvar `minimapShowPlayerCoords` 預設 1、
  錨在 Minimap BOTTOM y=-18、OnUpdate 每 0.1 秒查座標。自畫座標的插件要 `Hide()`（alpha 停不掉 OnUpdate）。
- `StringContains` 全域刪了、沒有別名（`string.contains` 是新的）；`Clamp`／`Round`／`Lerp`／`Saturate`／
  `tContains`／`tIndexOf`／`CountTable` 等搬去 C 端但**保留同名別名**，不用改。
- **`ChatFrameTemplate` 的 OnLoad 現在無條件讀 `self.ScrollToBottomButton.Flash.FlashAnim`**
  （ChatFrameOverrides.lua:47），但那顆鈕只長在 FloatingChatFrame.xml 的 ChatFrameN 本體，不在模板裡
  ⇒ 只繼承模板的超連結收件框載入就報「attempt to index field 'ScrollToBottomButton'」。
  已修：MiliUI_ChatBar/Sink.xml、MiliUI_Minimap/Panel/LinkSink.xml 用純 XML 補一顆隱藏的
  `ScrollToBottomButton`（Flash→FlashAnim→FadeIn/FadeOut），框內維持零插件 Lua；Chattynator 自己蓋掉
  OnLoad 所以不中招。再開新的收件框照這兩份抄，**別學 Chattynator 寫 OnLoad**（那是插件執行）。

**安全面（MiliUI 系列核對過不受影響，寫新碼要記得）**
- 保護的 Cooldown 框，tainted 程式不能 `SetCooldown`／`Clear`（自己建的框不受限）。
- 施法條 ID 改成**每個 unit token 不同**，不能拿它比較兩個單位；`"PLAYER"` 跟 `"player"` 拿到的 ID 也不同，事件一律小寫。
- 傷害統計 API 的 `sourceGUID` 在身分秘密時是秘密值（MDM 本來就走 `D.PlainGUID`）。
- `GetArenaOpponentSpec` 回秘密值；新的 `UnitFrameUtil`（角色圖示／PvP 標記／競技場專精）給秘密身分的安全畫法，
  MiliUI_UnitFrames 還沒接（Icons.lua 走 Desecret 退路）。
- `GetInventoryItemCooldown` 多了第 4 回傳 `isOnGCD`，暴雪 CooldownViewer 的裝備欄 GCD 誤判自己修了；MCDM 的
  `EquipRealCooldown` 改成讀得到就用它、讀不到退回 `duration > 1.5`。
- 新東西沒接：`ScriptRegion:SetRoundLayoutToNearestPixel`（取代 PixelUtil）、`C_Timer.NewTimedSignalMap`、
  `CreateFrameWithOptions`、`SetCasterName`＋cvar `tooltipShowAuraCasterNames`、`C_UnitAuras.AddAuraSound` 的
  `throttleSeconds`（上限 5 秒）、`C_ClassColor.GetClassColor` 的 tint 參數。

**Cell 不用修**：`RaidFrames/AuraContainerCore.lua` 本來就 `AddDispelTypeTexture` 優先且先 Clear，`SetAuraBorder` 只是死退路，
已拿掉。**沒做的**：第三方直接呼叫舊全域的粗估（含別名誤判）：Plumber 53、MRT 53、
YUI_AuctionHelper 26、TinyInspect-Remake 17、AppearanceTooltip 7、TeleportMenu／Cell／BuffReminders／Ayije_CDM 各 3。

**怎麼比對（下次改版照抄）**：
1. wiki `Patch_X/API_changes?action=raw` ＋ `/notes` 子頁（官方說明）。
2. Ketho/BlizzardInterfaceResources 的 `Resources/{FrameXML,GlobalAPI,Events}.lua` 兩個版本 tag 各抓一份做差集
   （mixin 方法不在裡面）。
3. `git clone --filter=blob:none --no-checkout --depth 1 --branch 12.1.5 Gethe/wow-ui-source`＋
   `git fetch --depth 1 origin tag 12.1.0`，`git diff --stat 12.1.0 12.1.5 -- Interface/AddOns/Blizzard_X`
   只看我們掛勾的那幾支；`grep '^[-+]function'` 抓改名。**別對 tag 跑 `git grep`，逐檔抓 blob 慢到跑不完**，
   要 `git checkout <tag> -- Interface/AddOns` 一次拉完。
4. 掛勾清單：`hooksecurefunc\((obj,)?"name"` 全掃一遍對差集。

相關：[[project-121-addon-migration]]、[[wow-121-aura-containers]]、[[project-miliui-minimap]]、
[[project-miliui-cooldownmanager]]、[[project-cell-auracontainer-rewrite]]
