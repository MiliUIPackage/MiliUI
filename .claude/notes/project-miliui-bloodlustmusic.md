---
name: project-miliui-bloodlustmusic
description: MiliUI_BloodlustMusic 自訂曲目（2026-11-04）：路徑放寬到整個 Interface、舊 filename 載入時遷移、可從 LSM 加曲目；只有 LSM 曲目走 C_Sound.IsPlaying 提早還原音量，尚未實機驗證
metadata:
  node_type: memory
  type: project
  originSessionId: 6a655916-4397-4dbf-a6a2-51232eeb7731
  modified: 2026-11-03T17:56:49.536Z
---

2026-11-03 玩家回報「更新後舊歌不能播、重放檔案也不能試聽」。播放程式其實沒動，成因是兩件事疊在一起：自訂歌只能放插件的 `Media\`，更新換掉資料夾就沒了；失敗訊息又叫人 `/reload`，但新音檔要整個重開遊戲（[[wow-new-file-needs-client-restart]]）。

**現在的設計（做法照 [[project-miliui-cooldownmanager]] 的自訂語音）：**
- `customTracks` 每筆是 `path`（Interface 之後的相對路徑）或 `lsm`（LSM 註冊名，播放當下才查，查不到就跳過）。
- 舊存檔的 `filename` 在 `InitDB` 遷移成 `path`：字串刻意不正規化，拼出來跟舊版一字不差；沒取名字的補上 `name`，顯示才不會變成整段路徑。`filename` 清掉就是遷移過的記號，重跑不會重複加前綴。
- 只填檔名仍然代表 `Media\`，舊教學照做還是會動。
- 內建與路徑曲目維持固定靜音 40 秒；只有 LSM 曲目用 `C_Sound.IsPlaying` 監看、播完就還原（LSM 多半是一兩秒的音效）。讀不到狀態一律當還在播，判定結束時也不呼叫 `StopSound`，就算誤判也不會切歌。

**Why:** 使用者要求「原本設定好的不要壞掉」，所以舊曲目的路徑、順序、勾選、靜音時間都不變，新行為只套用在新功能。

**How to apply:**
- `IsPlaying` 那段只跑過離線替身，**還沒進遊戲驗證**。確認可靠後，才考慮開放給路徑曲目（短檔案現在一樣靜音滿 40 秒）。
- 玩家自備的檔案一律不要叫他放進插件資料夾；失敗訊息別再寫 `/reload`。

**音效 CVar 的還原（2026-11-21）**：播放時把音樂／環境音設 0、聲道數與快取調高，原值以前只記在記憶體，播放中 /reload／斷線就永久停在我們的值。
現在改動當下就把原值寫進 `MiliUI_BloodlustMusic_DB.pendingSoundRestore`（帳號層、不進預設值表），Stop 還原後清掉；PLAYER_LOGIN 發現還留著就補還原；
PLAYER_LOGOUT 先停但**不清存檔**（那時 SetCVar 有沒有寫進 Config.wtf 沒驗證過）。兩個 session（正式播放、設定頁試聽）用持有數共用一份改動。
只還原「目前仍是我們設的值」的欄位，玩家中途自己改過的不蓋。離線劇本驗過，實機未驗。
