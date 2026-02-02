-- 한국어
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_ChatBar", "koKR")
if not L then return end

-- Addon Name
L["ADDON_NAME"] = "MiliUI 채팅바"
L["ADDON_TITLE"] = "빠른 채팅 바"

-- Settings Categories
L["SETTINGS_MAIN"] = "빠른 채팅 바"
L["SETTINGS_GENERAL"] = "일반 설정"
L["SETTINGS_CHANNELS"] = "채널 설정"
L["SETTINGS_MAIN_DESC"] = "빠른 채팅 바 애드온 설정"

-- Main Panel
L["SELECT_SUBCATEGORY"] = "왼쪽에서 하위 카테고리를 선택하세요:"
L["GENERAL_DESC"] = "잠금, 위치, 방향"
L["CHANNELS_DESC"] = "채널 버튼 표시/숨기기"

-- General Settings
L["GENERAL_SETTINGS_TITLE"] = "일반 설정"
L["GENERAL_SETTINGS_DESC"] = "채팅 바의 외관과 위치 설정"
L["LOCK_UNLOCK"] = "잠금/해제"
L["LOCK_UNLOCK_DESC"] = "채팅 바 드래그 가능 여부 전환"
L["RESET_POSITION"] = "위치 초기화"
L["RESET_POSITION_DESC"] = "채팅 바를 기본 위치로 이동"
L["TOGGLE_ORIENTATION"] = "세로/가로 전환"
L["TOGGLE_ORIENTATION_DESC"] = "세로 및 가로 레이아웃 간 전환"

-- Channel Settings
L["CHANNEL_SETTINGS_TITLE"] = "채널 설정"
L["CHANNEL_SETTINGS_DESC"] = "개별 채널 버튼 표시 또는 숨기기"

-- Context Menu
L["CONTEXT_LOCK_UNLOCK"] = "잠금/해제"
L["CONTEXT_RESET_POSITION"] = "위치 초기화"
L["CONTEXT_TOGGLE_ORIENTATION"] = "방향 전환"
L["CONTEXT_OPEN_SETTINGS"] = "설정 열기"

-- Messages
L["MSG_LOCKED"] = "|cff00ff00MiliUI 채팅바:|r 잠금됨"
L["MSG_UNLOCKED"] = "|cff00ff00MiliUI 채팅바:|r 해제됨"
L["MSG_RESET"] = "|cff00ff00MiliUI 채팅바:|r 위치 초기화됨"
L["MSG_HORIZONTAL"] = "|cff00ff00MiliUI 채팅바:|r 가로 모드"
L["MSG_VERTICAL"] = "|cff00ff00MiliUI 채팅바:|r 세로 모드"

-- Channel Names
L["CHANNEL_SAY"] = "일반"
L["CHANNEL_YELL"] = "외침"
L["CHANNEL_PARTY"] = "파티"
L["CHANNEL_INSTANCE"] = "인스턴스"
L["CHANNEL_RAID"] = "공격대"
L["CHANNEL_RAID_WARNING"] = "공격대 경고"
L["CHANNEL_GUILD"] = "길드"
L["CHANNEL_WHISPER"] = "귓속말"
L["CHANNEL_EMOTE"] = "감정표현"
L["CHANNEL_ROLL"] = "주사위"
L["CHANNEL_DBM"] = "DBM 풀"
L["CHANNEL_RESET"] = "인스턴스 초기화"
L["CHANNEL_COMBATLOG"] = "전투 기록"
