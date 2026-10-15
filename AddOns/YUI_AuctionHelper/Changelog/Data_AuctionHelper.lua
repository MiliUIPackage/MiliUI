do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.productEnabled then
        return
    end
end
-- Generated from Docs/Products/YUI_AuctionHelper/CHANGELOG.md; do not edit. Latest 10 versions per client.
local CL = _G.YUI.Changelog
CL:Register("auction_helper", {
-- YUI-Notes-Record: yah-121|mainline|7a4723d755be13fe2b3c0df99ff7eeae0f46e1ab73cdce56df88cce9fe626598
    {
        version = "yah-121",
        date = "2026-10-15",
        clients = { "Retail" },
        content = {
            zhCN = {
                "修复 12.1.5 下的物品数量读取兼容问题。",
                "同步共享核心，保持与新版 YUI 系列插件的兼容。",
            },
            enUS = {
                "Fixed item count compatibility with 12.1.5.",
                "Updated the shared core for compatibility with newer YUI addons.",
            },
        },
    },
-- YUI-Notes-Record: yah-120|mainline|9860266b5c5e1eb5e655ca6c6f99565825f6b3c3e34cc6a6f98e219150856e6d
    {
        version = "yah-120",
        date = "2026-10-12",
        clients = { "Retail" },
        content = {
            zhCN = {
                "同步共享核心，保持与新版 YUI 系列插件的兼容。",
            },
            enUS = {
                "Updated the shared core for compatibility with newer YUI addons.",
            },
        },
    },
-- YUI-Notes-Record: yah-119|mainline|d4ab158813ed1798aa856f3b7baaf5231bc31a785f6659bb4ff1827dd6a6949a
    {
        version = "yah-119",
        date = "2026-10-11",
        clients = { "Retail" },
        content = {
            zhCN = {
                "同步共享核心，保持与新版 YUI 系列插件的兼容。",
            },
            enUS = {
                "Updated the shared core for compatibility with newer YUI addons.",
            },
        },
    },
-- YUI-Notes-Record: yah-118|mainline|aa4e924069605d52656ad75f62c9115efd9bca76ed95592f636a86af7ee6a385
    {
        version = "yah-118",
        date = "2026-10-09",
        clients = { "Retail" },
        content = {
            zhCN = {
                "同步核心版本，避免与新版 YUI 插件共同加载时的版本冲突。",
            },
            enUS = {
                "Updated the shared core to avoid version conflicts when loaded alongside newer YUI addons.",
            },
        },
    },
-- YUI-Notes-Record: yah-117|mainline|c9aaadcfb132e370d28f7b04a0ba86b07519280a67a159e21c98c55dd5e37eb9
    {
        version = "yah-117",
        date = "2026-10-09",
        clients = { "Retail" },
        content = {
            zhCN = {
                "优化物品数量刷新，减少过图及面板隐藏时的额外开销。",
            },
            enUS = {
                "Optimized item count updates to reduce unnecessary work during zone transitions and while hidden.",
            },
        },
    },
-- YUI-Notes-Record: yah-116|mainline|7a3daabad962cb939b169db24d1061009400208424630723ed19abc21948cfe8
    {
        version = "yah-116",
        date = "2026-10-06",
        clients = { "Retail" },
        content = {
            zhCN = {
                "更新插件图标，统一系列外观。",
                "随插件提供中英文更新日志。",
            },
            enUS = {
                "Updated the addon icon to match the YUI series.",
                "Included bilingual release notes with the addon package.",
            },
        },
    },
-- YUI-Notes-Record: yah-115|mainline|25c1979a2e7e355a4ae56d06d6b9d63730c11a3d186e3531bca6286c2c4b2e1b
    {
        version = "yah-115",
        date = "2026-09-28",
        clients = { "Retail" },
        content = {
            zhCN = {
                "拍卖助手、编辑器与配方追踪面板遵循拍卖行皮肤设置。",
                "新增颜色选择器，支持收藏、最近颜色与恢复默认。",
                "完善按钮与字体显示。",
            },
            enUS = {
                "Helper, editor and recipe tracker panels now follow the auction house skin setting.",
                "Added a color picker with favorites, recent colors and default color restore.",
                "Improved buttons and font rendering.",
            },
        },
    },
-- YUI-Notes-Record: yah-114|mainline|27806f02d2c0723f2fff1dde185dccf7b18b3c09a60d09fa224d47f8e88fdb1e
    {
        version = "yah-114",
        date = "2026-09-23",
        clients = { "Retail" },
        content = {
            zhCN = {
                "更新共享核心，适配新版 Nova 与 Orbit。",
                "请同步更新已安装的 YUI 系列插件。",
            },
            enUS = {
                "Updated shared Core for compatibility with the latest Nova and Orbit.",
                "Please update all installed YUI addons together.",
            },
        },
    },
-- YUI-Notes-Record: yah-113|mainline|362f2e34e85a550303a721396eb24646112db40dfe94464cdbd1cc27073b23a0
    {
        version = "yah-113",
        date = "2026-09-19",
        clients = { "Retail" },
        content = {
            zhCN = {
                "更新共享 Core，请同步更新已安装的 YUI 插件。",
            },
            enUS = {
                "Updated shared Core. Please update all installed YUI addons together.",
            },
        },
    },
-- YUI-Notes-Record: yah-112|mainline|2ebdcfd3288ebbf302553723725e33797c9405fdc31cc64a5e82dcf48dff5a52
    {
        version = "yah-112",
        date = "2026-09-19",
        clients = { "Retail" },
        content = {
            zhCN = {
                "同步内嵌 Core 修复，保持与新版 Nova、Orbit 的共存兼容；请同步更新所有已安装的 YUI 插件。",
            },
            enUS = {
                "Updated embedded Core fixes for compatibility with the latest Nova and Orbit releases. Please update all installed YUI addons together.",
            },
        },
    },
})
