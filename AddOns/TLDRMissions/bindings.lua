local addonName = ...
local addon = _G[addonName]
local LibStub = addon.LibStub
local L = LibStub("AceLocale-3.0"):GetLocale("TLDRMissions")

BINDING_HEADER_TLDRMISSIONS = addonName
BINDING_NAME_TLDRMISSIONS_CALCULATE = L["Calculate"]
BINDING_NAME_TLDRMISSIONS_CANCEL = CANCEL
BINDING_NAME_TLDRMISSIONS_SKIP = L["Skip"]
BINDING_NAME_TLDRMISSIONS_START = GARRISON_START_MISSION
BINDING_NAME_TLDRMISSIONS_SKIPSEND = L["Skip"]
BINDING_NAME_TLDRMISSIONS_COMPLETE = L["CompleteMissionButtonText"]