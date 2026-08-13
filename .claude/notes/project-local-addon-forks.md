---
name: project-local-addon-forks
description: 哪些第三方插件帶著不會回上游的本地修改（上游更新就會被洗掉），以及怎麼認出來
metadata: 
  node_type: memory
  type: project
  originSessionId: 234790cb-b07c-4327-9f5f-2c34e643bef3
  modified: 2026-08-12T18:31:08.219Z
---

`AddOns/` 底下第三方插件是上游原封不動的副本，但**有一批帶著本地修改**。這些修改在下一次 `update: <插件>` 同步上游時會被整包蓋掉，必須重套。動任何一支之前先確認它在不在這張表上。

（截至 2026-08-12。CLAUDE.md 的原則是**優先從 `MiliUI/Fix/`、`MiliUI/Enhance/` 掛勾**，下面這些是掛不上勾才直接改的。）

| 插件 | 本地改了什麼 | 細節 |
|---|---|---|
| **Cell** | 最多的一支：AuraContainer 路線 A 重寫、secret guard、停用版本檢查與更新日誌、載具名稱、LibGroupInfo GUID、預設值調整 | [[project-cell-auracontainer-rewrite]]、[[project-cell-no-update-notice]]、[[project-cell-vehicle-secret]]、[[project-cell-libgroupinfo-secret-guid]]。TOC 版本號帶 `-MiliUI` 尾綴 |
| **Stuf / Stuf_Options / Stuf_Range** | 12.1 secret 洗白（`core.lua` 的 `IsSecret`/`desecret`/`toBool`）、zhTW 語系、broker/小地圖按鈕、**整包 Ace 函式庫換版** | [[wow-121-setdesaturation-acegui]]。改動量僅次於 Cell |
| **TinyTooltip-Remake** | 效能修補 + secret 版 `UnitColor` 取代暴雪的 `GameTooltip_UnitColor` | [[project-tinytooltip-perf]] |
| **Ayije_CDM** | 12.1 secret guard、zhTW 翻譯修正 | TOC 有 `## OptionalDeps: MiliUI` |
| **Platynator** | `Core/Initialize.lua` 讀 MiliUI 內建 profile 並自動切換 | [[project-platynator-preset]] |
| **AppearanceTooltip** | `addon.lua` 的 `IsRectValid` guard | [[project-appearancetooltip-secret-rect]] |
| **DamageMeterTools** | 錯誤處理器改成鏈式（原本會吃掉 BugSack 的錯誤）、登入卡頓修補 | 見 [[project-121-addon-migration]] |
| **BuffReminders** | `Core/Bootstrap.lua` 註解掉每次登入的 external buffs 提示 | 一行 |
| **DiGuaTimelineAudioHelper** | `Core.lua` 註解掉每次登入的「愛發電」贊助提示 print | 一行，有 `fix from MiliUI` 標記。這支會定期 `update:` 同步上游 |
| **Leatrix_Plus** | 12.1 光環秘密值閘：`LeaPlusLC:AurasAreSecret()`（檔案頂端）＋ 7 個呼叫點 | 見 [[project-121-addon-migration]]。全部有 `fix from MiliUI` 標記 |
| **HandyNotes_Midnight / _TheWarWithin / _Dragonflight** | 三支的 `core/util.lua` 各有同一個 C_Calendar secret guard（同一份 core 的三份副本，更新任何一支都要檢查） | 各一行 |

**Why:** 「上游更新後要重套」這句話散在一堆各自的筆記裡，但真正需要的是**動手之前先知道這支有沒有被改過**——一支一支翻筆記不會發生，被洗掉時也不會報錯，只是某個修好的問題悄悄回來。

**How to apply:**
- 同步上游後，用 `git diff` 看那次 commit 有沒有把上面提到的檔案改回原樣。
- **本地修改一律留 `MiliUI` 字樣的註解**（例：`-- fix from MiliUI: ...`）。這樣 `grep -rn "MiliUI" AddOns/<插件>` 就能認出來。目前 DamageMeterTools、BuffReminders、AppearanceTooltip 的改動**沒有**這個標記，下次動到時順手補上。
- 沒有上游 remote 可以 diff，git 歷史 + 這張表就是唯一的紀錄。
