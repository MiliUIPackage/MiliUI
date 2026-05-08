if GetLocale() ~= "koKR" then
    return
end

local _, ns = ...
local L = ns.L

L.ADDON_NAME = "미드나이트 - 수도"
L.ADDON_DESCRIPTION = "WoW: Midnight의 실버문 시티를 위한 HandyNotes 플러그인입니다."

L.FILTERS = "필터"
L.SHOW_WORLD_MAP_BUTTON = "세계 지도 버튼 표시"
L.SHOW_WORLD_MAP_BUTTON_DESC = "미드나이트 수도 지도에 빠른 옵션 버튼을 추가합니다."
L.MINIMAP_ICON_SCALE = "미니맵 아이콘 크기"
L.MINIMAP_ICON_SCALE_DESC = "미니맵 아이콘 크기입니다."
L.MAP_ICON_SCALE = "지도 아이콘 크기"
L.MAP_ICON_SCALE_DESC = "세계 지도 아이콘 크기입니다."
L.ICON_ALPHA = "아이콘 투명도"
L.ICON_ALPHA_DESC = "아이콘의 투명도입니다."
L.SHOW_SERVICES = "서비스 표시"
L.SHOW_PROFESSIONS = "전문 기술 표시"
L.SHOW_ACTIVITIES = "활동 표시"
L.SHOW_TRAVEL = "이동 표시"
L.SHOW_PORTALS = "차원문 표시"
L.RESET_TO_DEFAULTS = "기본값으로 초기화"
L.RESET_TO_DEFAULTS_DESC = "미드나이트 - 수도 옵션을 기본값으로 복원합니다."
L.RESET_CONFIRM = "미드나이트 - 수도 옵션을 모두 기본값으로 초기화하시겠습니까?"
L.CLICK_TO_SET_WAYPOINT = "클릭하여 길찾기 지점을 설정합니다."
L.QUICK_OPTIONS_DESCRIPTION = "이 지도용 HandyNotes 빠른 옵션입니다."
L.LEFT_CLICK_OPTIONS_DESCRIPTION = "왼쪽 클릭으로 필터와 아이콘 표시 설정을 변경합니다."
L.SHOW_ALL = "모두 표시"
L.HIDE_ALL = "모두 숨기기"
L.WORLD_MAP_SCALE_FORMAT = "세계 지도 크기 (%sx)"
L.MINIMAP_SCALE_FORMAT = "미니맵 크기 (%sx)"
L.ICON_ALPHA_FORMAT = "아이콘 투명도 (%s)"
L.OPEN_FULL_SETTINGS = "전체 설정 열기"

L.CATEGORY_SERVICES = "서비스"
L.CATEGORY_PROFESSIONS = "전문 기술"
L.CATEGORY_ACTIVITIES = "활동"
L.CATEGORY_TRAVEL = "이동"
L.CATEGORY_PORTALS = "차원문"

L.NODE_BANK_TITLE = "은행 및 위대한 금고"
L.NODE_BANK_DESC = "보관한 아이템과 주간 보상을 이용합니다."
L.NPC_VAULT_KEEPER = "금고지기"

L.NODE_BAZAAR_TITLE = "경매장"
L.NODE_BAZAAR_DESC = "다른 플레이어와 물품을 거래합니다."
L.NPC_AUCTIONEER = "경매인"

L.NODE_MAIN_INN_TITLE = "중앙 여관"
L.NODE_MAIN_INN_DESC = "휴식 지역 및 귀환석 귀속 지점입니다."
L.NPC_INNKEEPER = "여관주인"

L.NODE_GEAR_UPGRADES_TITLE = "장비 강화"
L.NODE_GEAR_UPGRADES_DESC = "장비를 강화합니다."
L.NPC_VASKARN_CUZOLTH = "Vaskarn & Cuzolth"

L.NODE_CATALYST_TITLE = "촉매 콘솔"
L.NODE_CATALYST_DESC = "아이템을 티어 장비로 변환합니다."
L.NPC_CATALYST = "촉매"

L.NODE_BLACK_MARKET_TITLE = "암시장 경매장"
L.NODE_BLACK_MARKET_DESC = "희귀하거나 획득할 수 없는 아이템에 입찰합니다."
L.NPC_MADAM_GOYA = "마담 고야"

L.NODE_TRANSMOG_TITLE = "형상변환"
L.NODE_TRANSMOG_DESC = "외형을 바꾸고 공허 보관함을 이용합니다."
L.NPC_WARPWEAVER = "형상변환사"

L.NODE_BARBER_TITLE = "미용실"
L.NODE_BARBER_DESC = "캐릭터 외형을 꾸밉니다."
L.NPC_TRIM_AND_DYE_EXPERT = "염색 및 커트 전문가"

L.NODE_SILVERMOON_INN_TITLE = "실버문 여관"
L.NODE_SILVERMOON_INN_DESC = "호드 전용 휴식 지역 및 귀환석 귀속 지점입니다."

L.NODE_SILVERMOON_BANK_TITLE = "금고와 은행"
L.NODE_SILVERMOON_BANK_DESC = "호드 전용 은행 및 위대한 금고 이용 장소입니다."

L.NODE_SILVERMOON_AUCTION_HOUSE_TITLE = "경매장"
L.NODE_SILVERMOON_AUCTION_HOUSE_DESC = "호드 전용 경매장 이용 장소입니다."

L.NODE_SILVERMOON_CATALYST_TITLE = "촉매"
L.NODE_SILVERMOON_CATALYST_DESC = "호드 전용 촉매 이용 장소입니다."

L.NODE_TIMEWAYS_TITLE = "시간의 길"
L.NODE_TIMEWAYS_DESC = "시간여행 캠페인에 접근합니다."
L.NPC_LINDORMI = "린도르미"

L.NODE_DELVERS_TITLE = "탐험가 본부"
L.NODE_DELVERS_DESC = "구렁 진행도와 풍요로운 구렁을 확인합니다."
L.NPC_VALEERA_ASTRANDIS = "발리라 생귀나르 & 순간이동술사 아스트란디스"

L.NODE_PVP_TITLE = "PvP 거점"
L.NODE_PVP_DESC = "명예 및 정복 상인입니다."
L.NPC_GLADIATOR_VENDORS = "검투사 상인"

L.NODE_TRAINING_DUMMIES_TITLE = "훈련용 허수아비"
L.NODE_TRAINING_DUMMIES_DESC = "DPS, 탱커, 치유 능력을 시험합니다."
L.NPC_TARGET_DUMMIES = "훈련용 허수아비"

L.NODE_CRAFTING_ORDERS_TITLE = "제작 의뢰"
L.NODE_CRAFTING_ORDERS_DESC = "제작 의뢰와 전문 기술 지식을 다룹니다."
L.NPC_CONSORTIUM_CLERK = "컨소시엄 서기"

L.NODE_FISHING_TITLE = "낚시 숙련사"
L.NODE_FISHING_DESC = "낚시 전문 기술을 배웁니다."
L.NPC_FISHING_MASTER = "낚시의 대가"

L.NODE_COOKING_TITLE = "요리 숙련사"
L.NODE_COOKING_DESC = "미드나이트 요리를 배우고 훈련합니다."
L.NPC_SYLANN = "실란 <요리 숙련사>"
