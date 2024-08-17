
local _, ns = ...

BINDING_HEADER_TinyInspect = "TinyInspect"

if (GetLocale() ~= "zhTW") then return end

ns.L = {
    ShowItemBorder              = "物品直角邊框",
    EnableItemLevel             = "顯示物品等級",
    ShowColoredItemLevelString  = "裝等文字使用品質顏色",
    ShowCorruptedMark           = "腐蝕裝備星星標記",
    ShowItemSlotString          = "顯示物品部位文字",
    ShowInspectAngularBorder    = "觀察面板直角邊框",
    ShowInspectColoredLabel     = "觀察面板顯著標示橘裝",
    ShowCharacterItemSheet      = "顯示玩家自己裝備列表",
    ShowInspectItemSheet        = "顯示觀察面板裝備列表",
    ShowOwnFrameWhenInspecting  = "觀察同時顯示自己裝備列表",
    ShowItemStats               = "顯示裝備屬性統計",
    DisplayPercentageStats      = "裝備屬性換算成百分比數值",
    EnablePartyItemLevel        = "啟用小隊隊友裝等",
    SendPartyItemLevelToSelf    = "發送隊友裝等到自己面板",
    SendPartyItemLevelToParty   = "發送隊友裝等到隊伍頻道",
    ShowPartySpecialization     = "顯示隊友專精",
    EnableRaidItemLevel         = "啟用團隊成員裝等",
    EnableMouseItemLevel        = "滑鼠提示中顯示裝等",
    EnableMouseSpecialization   = "顯示專精",
    EnableMouseWeaponLevel      = "顯示武器等級",
	ShowPluginGreenState        = "顯示副屬性前綴文字 |cffcccc33(需要重新載入 /reload)|r",
    Bag                         = "背包",
    Bank                        = "銀行",
    Merchant                    = "商人",
    Trade                       = "交易",
    Auction                     = "拍賣行",
    AltEquipment                = "ALT換裝",
    GuildBank                   = "公會銀行",
    GuildNews                   = "公會新聞",
    PaperDoll                   = "角色視窗",
    Chat                        = "聊天",
    Loot                        = "拾取",
	Other                       = "其他",
    ShowGemAndEnchant           = "顯示寶石和附魔訊息",
    HidePaperdollSlotString     = "隱藏人物界面部位文字",
}

BINDING_NAME_InspectRaidFrame = "顯示團隊觀察面板"