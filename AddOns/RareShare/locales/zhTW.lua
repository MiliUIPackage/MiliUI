local AddonName, Addon = ...

if (GetLocale() == "zhTW") then
    Addon.Loc = {
        Title = "稀有怪-分享",
        Died = "已被擊殺",
        AlreadyAnnounced = "最近已經發佈",
        RareFound = "找到稀有怪! 發佈到聊天頻道...",
		RareFoundPrefix = "發現稀有怪: ",
        Enabled = "啟用",
        Disabled = "停用",
        Config = {
            RareAnnounce = {
                "發佈到聊天頻道",
                "啟用/停用在發現目標時發佈稀有怪資訊到本地聊天頻道",
            },
            Sound = {
                "音效",
                "標記稀有怪時啟用/停用音效",
            },
            TomTom = {
                "TomTom 導航箭頭",
                "啟用/停用 Tomtom 導航箭頭",
            },
            OnDeath = {
                "死亡通告（使用後風險自負）",
                "啟用/停用發佈稀有怪死亡到聊天頻道",
            },
            Duplicates = {
                "已完成的稀有怪通知",
                "啟用/停用對今天已經完成的稀有怪的通知",
            },
        }
    }
end
