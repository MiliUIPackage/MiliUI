local addonName = ... ---@type string 'Falcon'
local ns = select(2,...) ---@class (partial) namespace

ns.Flags = {
  BarBehaviour = {
    HIDE_CHARGES = 1,
    HIDE_SPEED = 2,
    HIDE_GROUNDED = 4,
    HIDE_FULL_GROUNDED = 8,
  }
}