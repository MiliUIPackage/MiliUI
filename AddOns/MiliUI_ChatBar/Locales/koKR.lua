-- 한국어
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_ChatBar", "koKR")
if not L then return end

-- Addon Name
L["ADDON_NAME"] = "MiliUI 채팅바"

-- 密語回覆降級（見 Fix_ReplyTell.lua）
L["REPLY_FALLBACK_HINT"] = "12.1에서는 귓속말 대상의 이름이 보호된 데이터라 애드온이 대신 입력할 수 없습니다. |cffffd200/r|r 을 입력해 두었으니 띄어쓰기 후 메시지를 입력하세요."
L["ADDON_TITLE"] = "빠른 채팅 바"

-- Settings Categories
L["SETTINGS_CHANNELS"] = "채널 설정"
L["SETTINGS_MAIN_DESC"] = "빠른 채팅 바 애드온 설정"

-- Main Panel

-- General Settings
L["GENERAL_SETTINGS_TITLE"] = "일반 설정"
L["LOCK_UNLOCK"] = "잠금/해제"
L["LOCK_UNLOCK_DESC"] = "채팅 바 드래그 가능 여부 전환"
L["RESET_POSITION"] = "위치 초기화"
L["RESET_POSITION_DESC"] = "채팅 바를 기본 위치로 이동"
L["FONT_SIZE"] = "글꼴 크기"
L["BUTTON_WIDTH"] = "버튼 너비"
L["BUTTON_HEIGHT"] = "버튼 높이"
L["RESET_ALL"] = "모든 설정 초기화"
L["RESET_ALL_DESC"] = "모든 설정을 기본값으로 초기화"
L["CONFIRM_RESET_ALL"] = "모든 설정을 초기화하시겠습니까?"

-- Channel Settings
L["CHANNEL_SETTINGS_TITLE"] = "채널 설정"
L["CHANNEL_SETTINGS_DESC"] = "개별 채널 버튼 표시 또는 숨기기"

-- Context Menu
L["CONTEXT_OPEN_SETTINGS"] = "설정 열기"

-- Messages
L["MSG_LOCKED"] = "|cff00ff00MiliUI 채팅바:|r 잠금됨"
L["MSG_UNLOCKED"] = "|cff00ff00MiliUI 채팅바:|r 해제됨"
L["MSG_RESET"] = "|cff00ff00MiliUI 채팅바:|r 위치 초기화됨"

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

-- Short Labels (Button Text)
L["SHORT_SAY"] = "일"
L["SHORT_YELL"] = "외"
L["SHORT_PARTY"] = "파"
L["SHORT_INSTANCE"] = "인"
L["SHORT_RAID"] = "공"
L["SHORT_GUILD"] = "길"
L["SHORT_WHISPER"] = "귓"
L["SHORT_ROLL"] = "주"
L["SHORT_DBM"] = "풀"
L["SHORT_RESET"] = "초"

-- Tooltips
L["TIP_DBM"] = "좌클릭: 확인 | 휠클릭: 5초 카운트 | 우클릭: 10초 카운트"
L["TIP_DBM_FORMAT"] = "좌클릭: 확인 | 휠클릭: 5초 카운트 | 우클릭: %d초 카운트"
L["TIP_RESET"] = "좌클릭: 인스턴스 초기화 | 우클릭: 전투 기록"

-- Pull Timer (native countdown)
L["DBM_PULL_SECONDS"] = "풀 카운트다운 초"
L["DBM_PULL_SECONDS_DESC"] = "풀 타이머 카운트다운 초 설정 (우클릭)"
