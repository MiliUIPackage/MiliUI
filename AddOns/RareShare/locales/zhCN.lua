local AddonName, Addon = ...

if (GetLocale() == "zhCN") then
    Addon.Loc = {
        Title = "稀有分享",
        Died = "已被击杀",
        AlreadyAnnounced = "最近已经发布",
        RareFound = "找到稀有! 发布聊天..",
        Enabled = "启用",
        Disabled = "禁用",
        Config = {
            RareAnnounce = {
                "启用发布聊天",
                "启用/禁用在发现目标时发布稀有信息到本地聊天",
            },
            Sound = {
                "启用声音",
                "标记稀有时启用/禁用声音",
            },
            TomTom = {
                "开启TomTom",
                "启用/禁用tomtom",
            },
            OnDeath = {
                "启用死亡通知（使用风险自负）",
                "启用/禁用发布稀有死亡到聊天频道",
            },
            Duplicates = {
                "启用已完成的稀有通知",
                "启用/禁用对今天已经完成稀有通知",
            },
        }
    }
end