------------------------------------------------------------
-- 韓文
-- key＝英文原文，改 key 的時候記得同步這裡，不然會退回英文
------------------------------------------------------------
local _, ns = ...
if GetLocale() ~= "koKR" then return end

local L = ns.L

L["[MiliUI CDM]"] = "[MiliUI CDM]"
L["%s and MiliUI Cooldown Manager both take over Blizzard's Cooldown Manager, so only one of them can be enabled."] = "%s 애드온과 MiliUI 재사용 대기시간 관리자는 둘 다 블리자드 재사용 대기시간 관리자를 대체하므로 하나만 사용할 수 있습니다."
L["Disable %s and reload"] = "%s 비활성화 후 리로드"
L["Disable this addon for now"] = "이 애드온 먼저 끄기"
L["MiliUI Cooldown Manager"] = "MiliUI 재사용 대기시간 관리자"
L["Not implemented yet."] = "아직 구현되지 않았습니다."
L["Essential Cooldowns"] = "핵심 재사용 대기시간"
L["Utility Cooldowns"] = "보조 재사용 대기시간"
L["Tracked Buffs"] = "추적 강화 효과"
L["Tracked Bars"] = "추적 막대"
L["Resource Bars"] = "자원 바"
L["Cast Bar"] = "시전 바"
L["Theme"] = "테마"
L["Profiles"] = "프로필"
L["About"] = "정보"
L["Rearranges and restyles Blizzard's Cooldown Manager."] = "블리자드 재사용 대기시간 관리자를 재배치하고 꾸밉니다."
L["|cffffd200/mcdm|r or |cffffd200/miliuicdm|r opens or closes this window."] = "|cffffd200/mcdm|r 또는 |cffffd200/miliuicdm|r 으로 이 창을 열고 닫습니다."
L["Author: Mili (MiliUI package)"] = "제작: Mili (MiliUI 패키지)"
L["Bars"] = "바"
L["Global"] = "전역"
L["+ New Group"] = "+ 새 그룹"
L["Custom groups are coming in a later version."] = "사용자 그룹은 이후 버전에서 추가됩니다."
L["Use /mcdm to open options"] = "/mcdm 으로 설정 열기"
L["Version: %s"] = "버전: %s"
L["Open options"] = "설정 열기"
L["Left-click"] = "좌클릭"
L["Toggle options"] = "설정 열기/닫기"
L["Options UI failed to load."] = "설정 창을 불러오지 못했습니다."
L["Minimap button shown."] = "미니맵 버튼을 표시합니다."
L["Minimap button hidden. Type /mcdm minimap to bring it back."] = "미니맵 버튼을 숨겼습니다. /mcdm minimap 으로 다시 표시할 수 있습니다."
L["Apply"] = "적용"
L["Okay"] = "확인"
L["Cancel"] = "취소"
L["Can't change settings during combat"] = "전투 중에는 설정을 변경할 수 없습니다"
-- 編輯模式
L["Open this bar's settings"] = "이 바의 설정 열기"
L["Dragging stops it following %s"] = "드래그하면 %s 따라가기가 해제됩니다"
L["Cooldown Manager settings are in /mcdm, or click the gear at the top right of the blue box."] = "재사용 대기시간 관리자 설정은 /mcdm 또는 파란 테두리 오른쪽 위의 톱니바퀴에서 열 수 있습니다."
