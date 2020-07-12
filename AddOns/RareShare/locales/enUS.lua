local AddonName, Addon = ...

Addon.Loc = {
    Title = "Rare Share",
    Died = "died",
    AlreadyAnnounced = "was already announced recently",
    RareFound = "Rare found! Announcing to chat..",
    Enabled = "Enabled",
    Disabled = "Disabled",
    Config = {
        RareAnnounce = {
            "Enable Chat Announcements",
            "Enables/Disables announcing rares to general chat when targeted",
        },
        Sound = {
            "Enable Sounds",
            "Enables/Disables audible clues when rares are tagged",
        },
        TomTom = {
            "Enable TomTom Waypoints",
            "Enables/Disables automatic tomtom waypoints",
        },
        OnDeath = {
            "Enable On Death Announcements (Use at own risk)",
            "Enables/Disables announcing the death of rares to chat",
        },
        Duplicates = {
            "Enable Notifications For Already Completed Rares",
            "Enables/Disables reacting to rares that have already been completed today",
        }
    }
}