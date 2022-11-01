local addonName = "TLDRMissions"
local addon = _G[addonName]

addon.Enums = {}

addon.Enums.TargetType = {
    closest_enemy = 1,
    all_enemies = 2,
    back_enemies = 3,
    front_enemies = 4,
    cleave_enemies = 5,
    line = 6,
    cone = 7,
    furthest_enemy = 8,
    pseudorandom_enemies_only = 9,
    pseudorandom_followers_only = 10,
    pseudorandom_everything = 11,
    random_enemy = 12, -- unused
    random_ally = 13, -- unused
    self = 14,
    all_allies = 15,
    closest_ally = 16,
    adjacent_allies = 17,
    adjacent_allies_or_all_allies = 18,
    other_allies = 19,
    front_allies_only = 20,
    back_allies_exclude_self = 21,
    nearby_ally_or_self = 22, 
}

addon.Enums.spellType = {
    attack = 1,
    heal = 2,
    passive = 3,
    buff = 4,
}