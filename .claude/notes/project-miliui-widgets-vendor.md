---
name: project-miliui-widgets-vendor
description: MiliUI 自製插件的共用設定介面（MiliUIWidgets）—— 走 vendor 複製而非 LibStub，唯一 source 在 UnitFrames
metadata: 
  node_type: memory
  type: project
  originSessionId: 7d08d4b9-4715-4b8f-87ca-737e01131ca6
  modified: 2026-08-21T16:37:39.192Z
---

**任何 MiliUI 自製插件要做設定介面，複製 `AddOns/MiliUI_UnitFrames/Libs/MiliUIWidgets/`
整包過去，不要重寫、也不要叫 agent「參考頭像的介面」。** 那是唯一 source，包內
`README.md` 寫了完整的複製契約。（2026-08-18 建立）

**內容**：`Widgets.lua`（元件庫）、`Controls.lua`（宣告式表單引擎）、`PixelPerfect.lua`、
`Env.lua`。前三支逐字複製，**只改 `Env.lua`** —— 它是唯一的宿主接點，提供
`NAMESPACE / L / P / Font / Accent / PopupParent` 六項。
宿主專屬的選單清單與 spec 工廠放各自的 `Options/Specs_*.lua`，不要寫回 `Controls.lua`。

**Why 選 vendor 而不是 LibStub 或 MiliUI_Core 插件**：
- Core 插件 → 玩家從 GitHub 抓 zip 會缺件，而缺件的後果是插件整個不能設定（硬失敗）。
  插件都是單體發佈的，不能有這種前置條件。
- LibStub → 能共享單一視窗，但要背「API 只能加不能改語意」的永久稅。
- vendor → 拿到「介面不漂移、bug 修一次跑腳本同步」，又不用背相容包袱；代價是不能
  共用同一個設定視窗（各插件各開各的）。**哪天真的想要「一個視窗多分頁」再升級成
  LibStub 不遲**，原始碼已經是單一 source。

**踩雷點**：`Env.NAMESPACE` 每個插件必須不同。`CreateFont("同名")` 回傳既有物件而非
新的，具名 frame 也一樣 —— 撞名會讓兩個插件互相蓋掉字型設定，而且不報錯。

**現況**：兩個消費者——UnitFrames（source）與 **MiliUI_Tooltip**（2026-08-22 複製，
第二個消費者，見 [[project-miliui-tooltip]]）。Env 六項契約在程式層夠用，未動共用層一字
（遊戲內未驗證）。設定視窗本體（`Options/Panel.lua`）仍是各插件自己組裝（Tooltip 抄了
一份簡化版：無搜尋、無小地圖鈕）；設定搜尋刻意不進包，理由寫在 README 末段。

相關：[[project-miliui-unit-frame]]、[[project-miliui-release-version]]
