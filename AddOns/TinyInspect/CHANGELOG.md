# TinyInspect

## [12.0.1](https://github.com/Witnesscm/TinyInspect/tree/12.0.1) (2026-01-26)
[Full Changelog](https://github.com/Witnesscm/TinyInspect/compare/12.0.0...12.0.1) [Previous Releases](https://github.com/Witnesscm/TinyInspect/releases)

- fix: #18  
- Merge pull request #17 from xuhuanxxx/main  
    feat: Tooltip API重构与装备列表渐进加载  
- fix: Add SafeUnitAPI to protect unit API calls in secure execution  
    - Create SafeUnitAPI module for safe unit API wrapper  
    - Add UnitIsPlayer check to skip NPCs/mobs  
    - Replace all unit API calls in protected environments with SafeUnitAPI  
    Fixes:  
    - UnitHealthMax error when hovering over enemies in instances  
    - UnitGUID error in ProcessInfo hook  
    - NPCs/mobs should not show item level  
- feat: Enhance tooltip handling by prioritizing GameTooltip checks  
    - Added a new function to directly search for lines in GameTooltip, improving efficiency.  
    - Updated the AppendToGameTooltip function to first check GameTooltip before falling back to tooltipData, reducing redundancy in displayed lines.  
- fix：统一重置所有槽位透明度，清除加载态 0.6  
    将 SetAlpha(1) 移到 if/else 外，确保空槽位也能清除加载态的 0.6 透明度。  
    删除主手/副手特殊处理中的冗余 SetAlpha(1)。  
    保留空主手/副手的 0.4 特殊处理。  
- 恢复重复次数为2次，处理10.x版本GetInventoryItemLink可能返回nil的问题  
- feat: Refactor tooltip API and add progressive loading for equipment list  
    feat: Tooltip API重构与装备列表渐进加载  
    - 使用 tooltipData.lines 替代遗留全局对象访问  
    - 打开检查窗口时立即显示框架，支持缓存秒加载  
- fix: Prevent nil access when iterating tooltip lines by adding a null check.  
