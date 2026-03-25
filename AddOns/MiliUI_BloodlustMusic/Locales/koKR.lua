-- 한국어
local L = LibStub("AceLocale-3.0"):NewLocale("MiliUI_BloodlustMusic", "koKR")
if not L then return end

-- Addon
L["ADDON_NAME"] = "MiliUI 영웅심 음악"
L["ADDON_TITLE"] = "영웅심/피의 욕망 카운트다운"
L["LOADED_MSG"] = "|cff00ff00MiliUI 영웅심 음악:|r 로드됨 — /blm 설정 열기"

-- Settings Categories
L["SETTINGS_MAIN"] = "영웅심 음악"
L["SETTINGS_MUSIC"] = "음악 설정"
L["SETTINGS_BAR"] = "카운트다운 바"
L["SETTINGS_MAIN_DESC"] = "영웅심/피의 욕망 음악 재생 및 카운트다운 바"
L["SELECT_SUBCATEGORY"] = "왼쪽에서 하위 카테고리를 선택하세요:"
L["MUSIC_DESC"] = "음악 재생, 트랙 선택, 채널"
L["BAR_DESC"] = "카운트다운 바 외관 및 위치"

-- Music Settings
L["MUSIC_SETTINGS_TITLE"] = "음악 설정"
L["MUSIC_SETTINGS_DESC"] = "영웅심 음악 재생 옵션 설정"
L["ENABLE_MUSIC"] = "음악 활성화"
L["ENABLE_MUSIC_DESC"] = "영웅심 감지 시 음악 재생"
L["PLAY_MODE"] = "재생 모드"
L["PLAY_MODE_RANDOM"] = "랜덤 재생"
L["PLAY_MODE_SEQUENTIAL"] = "순차 재생"
L["PLAY_MODE_DESC"] = "랜덤 재생과 순차 재생 사이 전환"
L["CHANNEL"] = "오디오 채널"
L["CHANNEL_DESC"] = "음악 재생에 사용할 오디오 채널 선택"
L["CHANNEL_MASTER_DESC"] = "마스터 볼륨으로 제어됩니다. 음악/효과음이 꺼져 있어도 항상 들립니다."
L["CHANNEL_SFX_DESC"] = "효과음 볼륨으로 제어됩니다. 영웅심 음악 볼륨이 효과음 슬라이더를 따릅니다."
L["PREVIEW"] = "미리 듣기"
L["STOP_PREVIEW"] = "중지"
L["TRACK_ENABLED"] = "활성화"

-- Bar Settings
L["BAR_SETTINGS_TITLE"] = "카운트다운 바 설정"
L["BAR_SETTINGS_DESC"] = "영웅심 카운트다운 바 외관 및 위치 설정"
L["ENABLE_BAR"] = "카운트다운 바 활성화"
L["ENABLE_BAR_DESC"] = "영웅심 활성 시 카운트다운 바 표시"
L["BAR_WIDTH"] = "너비"
L["BAR_HEIGHT"] = "높이"
L["RESET_POSITION"] = "위치 초기화"
L["RESET_POSITION_DESC"] = "카운트다운 바를 기본 위치로 초기화"
L["TEST_BAR"] = "테스트 바"
L["TEST_BAR_DESC"] = "테스트 카운트다운 바 표시"
L["HIDE_BAR"] = "바 숨기기"

-- Messages
L["MSG_MUSIC_PLAYING"] = "|cff00ff00영웅심 음악:|r 재생 중: %s"
L["MSG_POSITION_RESET"] = "|cff00ff00영웅심 음악:|r 바 위치 초기화됨"
