---
name: wow-ping-unit-detection
description: 插件要知道「哪個單位被 ping」只有 CHAT_MSG_PING 的聊天文字可用；UNIT_PING_PIN_ADDED 註冊得起來但收不到
metadata:
  type: reference
---

2026-11-28 實機探針（12.1.5，追隨者地城，脫戰與戰鬥中都測）：

- 暴雪自己的單位框靠 `UNIT_PING_PIN_ADDED(guid, uiTextureKit)`／`UNIT_PING_PIN_REMOVED(guid)` 畫標記（`UnitPingIconFrameTemplate`，
  整組標 forbidden）。**插件 RegisterEvent 會成功，但 ping 自己／隊友／敵人一次都收不到**。`RegisterAllEvents` 過濾名字含 PING 的，也只有 `CHAT_MSG_PING`。
- `CHAT_MSG_PING` 的 arg1 是組好的一句話：`|A:ping_chat_<種類>:0:0:0:0|a` ＋ 內文。種類看到 nonthreat／warning／threat（還有 assist／attack／onmyway）。
  內文是「名字」或「在地化前綴：名字」（警告：某某、威脅警報：某某）；ping 地面是「注意這裡」。**沒有 GUID**（arg12 是 nil），arg2 帶聊天頻道裝飾（`[隊長] [名字]`）不能用。
- 追隨者地城戰鬥中文字是明文；事件有 `SecretInChatMessagingLockdown`，首領戰／傳奇鑰石會是秘密值（未實機）。
- 做法：拿內文對 `UnitName`（整句相等，或前綴＋冒號／空白＋名字結尾），圖示直接用 `ping_chat_<種類>` 那張 atlas。
  實作在 `MiliUI_UnitFrames/Core/PingMark.lua` 與 `MiliUI/Enhance/Cell_PingMark.lua`（圖示框掛 UIParent、錨到單位框，戰鬥中可用）。兩支都**未實機看過**。
