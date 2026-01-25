# TinyInspect

## [12.0.0](https://github.com/Witnesscm/TinyInspect/tree/12.0.0) (2026-01-24)
[Full Changelog](https://github.com/Witnesscm/TinyInspect/compare/11.2.2...12.0.0) [Previous Releases](https://github.com/Witnesscm/TinyInspect/releases)

- toc: bump version  
- feat: update enchant data  
- chore: update script  
- fix: fix tier set in pre-patch  
- chore: cleanup  
- Merge pull request #16 from xuhuanxxx/main  
    Fix: 修复装备列表因等待宝石数据导致显示不全的问题  
- Perf: 优化团队装等列表的刷新频率  
    InspectRaid.lua 模块原先会在每次收到单个队友的观察数据 (RAID\_INSPECT\_READY) 时立即刷新UI。在大型团队中，高频的数据返回会导致界面在短时间内几十次重绘。  
    本次修改引入了节流机制：  
    1. 收到数据更新事件时，不再立即重绘。  
    2. 使用 LibSchedule 延迟 0.2 秒统合批量执行 SortAndShowMembersList。  
    这能显著减少团本场景下的无关CPU占用。  
- Fix: 修复装备列表因等待宝石数据由于导致显示不全的问题  
    libs/LibItemInfo.lua 中的 HasLocalCached 函数此前不仅检查物品本身，还会强制检查前3颗宝石的缓存状态。这导致在刷新时，如果宝石数据尚未到达（异步加载中），整个装备条目就会被主检查逻辑判定为“未就绪”而被隐藏。  
    本次修改放宽了该检查条件：  
    1. HasLocalCached 现仅检查主物品 ID 的缓存状态。  
    2. 确保 InspectUnit.lua 能立即渲染出装备与基础信息。  
    3. 宝石与附魔图标仍由 InspectUnitGemAndEnchant.lua 通过异步回调自动加载，不会影响主列表显示。  
- fix: equipment flyout ilvl  
- feat: improve db initialization  
