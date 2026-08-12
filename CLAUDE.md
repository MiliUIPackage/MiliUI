# 米利UI套組 MiliUI Package

魔獸世界的整合 UI 套組。這個 repo **就是一份實際的 `Interface/` 資料夾** —— 改完存檔，遊戲
裡 `/reload` 就會生效，不需要另外部署。

repo 是**公開的**（github.com/MiliUIPackage/MiliUI），玩家會整包 clone 下來用。不要放個人
資料、對話記錄或任何跟套組無關的大檔。

## 分支

| 分支 | 用途 |
|---|---|
| `master` | 正式服，玩家實際下載的版本 |
| `ptr-12.1` | 12.1 改版工程（目前主力） |
| `beta` | 測試 |

## agent 資料在 `.claude/`

單一入口，全部跟著 git 走：

| 位置 | 內容 |
|---|---|
| [.claude/skills/](.claude/skills/) | 技能，會依情境自動觸發，附帶的腳本放各自的 `scripts/` |
| [.claude/notes/](.claude/notes/) | API 規則與各插件現況，索引在 [notes/README.md](.claude/notes/README.md) |

`.claude/*.local.json` 是個人設定，不進版控。

**動任何跟 12.1 相關的程式碼之前，先看 `wow-121-migration` 技能。** 12.1 把大量 Unit／光環
API 改成 secret value，照舊寫法會直接崩潰，而且錯誤訊息不會指向真正的原因。

## AddOns/ 的構成

第三方插件和自製插件混在同一層：

- **自製**：`MiliUI`、`MiliUI_*`
- **第三方**：其餘大多是上游原封不動的插件
- **本地分支**：少數（如 `Cell`）帶有不會回上游的修改

### 改第三方插件的優先順序

1. **首選：從 MiliUI 掛勾。** `MiliUI/Fix/<插件>_<問題>.lua` 修壞掉的行為，
   `MiliUI/Enhance/<目標>_<功能>.lua` 加功能。這樣上游插件更新時修改不會被蓋掉。
2. **次選：直接改插件檔案。** 只在掛不上勾的時候這樣做（例如要註解掉某段程式）。這種修改
   在下次更新該插件時會消失，心裡要有數。

## 慣例

- **`.toc` 的 Interface 版本號不要手改**，用 `wow-toc-interface-bump` 技能的腳本。
  正式服是 6 位數、經典服是 5 位數，手改很容易把多版本相容的插件弄壞。
- **改完用 `luac -p` 過一次語法**，這裡沒有測試可跑，語法錯誤要到遊戲裡才會炸。
- **commit 訊息**：`feat:` / `fix:` / `update:` / `chore:` 開頭，後面接中文或英文簡述，
  通常點名插件（例：`fix: Ayije_CDM 翻譯`、`update: Cell`）。
- **回報用語**：使用者用繁體中文，回覆也用繁體中文。
