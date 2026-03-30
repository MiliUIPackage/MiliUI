local AddOnName, KeystonePolaris = ...

-- Define which dungeons are in the current season
-- start_date: YYYY-MM-DD (required) or table keyed by portal (US/EU)
-- end_date: YYYY-MM-DD (optional) or table keyed by portal (US/EU)
-- is_remix: true for bonus remix seasons (excluded from current/next logic)
KeystonePolaris.TWW_LEGION_REMIX_1_DUNGEONS = {
    expansion = "7_Legion",
    is_remix = true,
    start_date = "2025-10-07",
    end_date = {
        US = "2026-01-19",
        EU = "2026-01-20",
        default = "2026-01-20"
    },
    -- Legion Dungeons
    [199] = true, -- BRH (Black Rook Hold)
    [233] = true, -- CoEN (Cathedral of Eternal Night)
    [210] = true, -- CoS (Court of Stars)
    [198] = true, -- DHT (Darkheart Thicket)
    [197] = true, -- EoA (Eye of Azshara)
    [200] = true, -- HoV (Halls of Valor)
    [208] = true, -- MoS (Maw of Souls)
    [206] = true, -- NL (Neltharion's Lair)
    [227] = true, -- KZLO (Return to Karazhan: Lower)
    [234] = true, -- KZUP (Return to Karazhan: Upper)
    [239] = true, -- SotT (Seat of the Triumvirate)
    [209] = true, -- ARCW (The Arcway)
    [207] = true, -- VotW (Vault of the Wardens)
}