---
name: wow-actionbar-text-overlay-level-500
description: 自訂 HUD 被快捷鍵文字蓋住的真正原因——ActionButton 的文字層在 MEDIUM level 500，按鈕本體只有 3
metadata:
  node_type: memory
  type: reference
---

自訂的 HUD 小工具列擺在快捷列附近，**按鍵文字與數量數字會直接印在上面**。

**成因**：`Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml` 把那兩種文字放在按鈕的
一個獨立子框裡，寫死 `frameLevel="500"` ＋ `setAllPoints="true"`：

```xml
<Frame parentKey="TextOverlayContainer" mixin="ActionButtonTextOverlayContainerMixin"
       frameLevel="500" setAllPoints="true">
```

按鈕本體與同層兄弟的 level 都很小（`/framestack` 實測 `MultiBar5Button5` 是 **3**，
`MultiBar5ButtonContainer5` 是 2、`MultiBar5` 是 1），`MainActionBar` 的 XML 是
`frameLevel="50"`、`EndCaps` / `ActionBarPageNumber` 是 100。**看那些數字會誤判**——
真正蓋上來的是那層 500，而且它跟按鈕等大。

**How to apply**：想蓋過快捷鍵文字的自訂框，`SetFrameLevel(600)` 之類即可，
**不要改 strata**。跳到 `HIGH` 會連暴雪的主面板一起蓋掉：天賦樹 `PlayerSpellsFrame`
的 XML **沒有設 frameStrata**（＝MEDIUM），它靠 `toplevel="true"` 把自己抬到同 strata
最上面，所以留在 MEDIUM 把 level 墊到 600 兩邊都對——越得過文字層，面板顯示時又照樣
壓得住我們。

**診斷工具**：`/framestack`（框架堆疊）滑過出問題的位置，它會依 strata ＋ level 由高到低
列出游標下的每一層，`<數字>` 就是 frame level。查層級問題先開它，不要用猜的看 XML。
相關：[[wow-frame-vs-texture-layering]]
