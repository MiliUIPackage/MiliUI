if GetLocale() ~= "zhTW" then return end
local L

-----------------------
--Murder Row Trash
-----------------------
L = DBM:GetModLocalization("MurderRowTrash")

L:SetGeneralLocalization({
	name =	"兇殺路小怪"
})
