# 第三方插件的本地修補：重套腳本

`AddOns/` 底下的第三方插件是上游原封不動的副本，但有一批帶著不回上游的修改
（哪些、改了什麼：[`../notes/project-local-addon-forks.md`](../notes/project-local-addon-forks.md)）。
這些修改在下一次 `update: <插件>` 整包覆蓋時會被洗掉，而且**不報錯**。

兩道防線：

| 誰 | 做什麼 |
|---|---|
| [`../scripts/check_forks.py`](../scripts/check_forks.py)（check-all／CI 都跑） | 守門：修補的辨識字串不在了就失敗 |
| 這個資料夾 | 重套：每筆直接改檔的修補附一支冪等腳本，`--check` 只看不改 |

## 慣例

- 一筆修補一支腳本，檔名 `<插件>-<修了什麼>.py`；多份副本共用的（ChatThrottleLib）吃檔案路徑參數。
- **冪等**：套過就印「已套用」什麼都不做；找不到錨點（上游改寫了那段）就印出來交給人，不硬套。
- 上游後來自己修了同一件事的，腳本要認得並略過（例：ChatThrottleLib v32 的 `issecretvalue` 早退），
  `check_forks.py` 那筆改守上游的那一行。
- 加新修補時三處一起動：改檔（帶 `fix from MiliUI` 註解）、`check_forks.py` 加一筆、這裡加一支腳本。

## 現有腳本

| 腳本 | 對象 | 修什麼 |
|---|---|---|
| `AztarecHelper-zhTW.py`（＋`.json` 對照表） | AztarecHelper（目前不在套組裡） | 整包繁中化＋`AZT.Log` 接到存檔 |
| `MRT-RaidCheck-secret-gate.py` | MRT `RaidCheck.lua` | `CheckPotionsOnPull` 的光環秘密值閘（呼叫之前） |
| `ChatThrottleLib-SafeStrLen.py <檔…>` | 各插件內嵌的 ChatThrottleLib v31 | 流量統計對秘密字串用固定長度估，不 `tostring` |
| `TrueStatValues-zhTW.py` | TrueStatValues | 整包繁中化：補 `Locales.lua`、TOC 載入行與 MiliUI 區塊、字串改走 L、zhTW 黑名單、物品句型 pattern |

其餘筆記表上的修補（TinyInspect-Remake、AppearanceTooltip、TeleportMenu、Platynator、
HandyNotes 三支…）目前還沒有腳本，上游更新後照筆記手動重套、靠 `check_forks.py` 擋。
Cell 已經不追上游（我們自己就是上游），不在此列。
