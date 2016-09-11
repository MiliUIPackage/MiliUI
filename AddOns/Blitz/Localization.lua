Blitz_Locals = {}
local L = Blitz_Locals
local Language = GetLocale()

-- Traditional Chinese -- 
if Language == 'zhTW' then
	L["AutomateQuest"] = "自動任務"
	L["MissingOptions"] = "由於插件%s導致\"Blitz Options\" 無法載入"
	
-- Simplified Chinese -- 
elseif Language == 'zhCN' then
L["AutomateQuest"] = "自动任务"
L["MissingOptions"] = "由于插件%s导致\"Blitz Options\" 无法加载"

-- Russian --
elseif Language =='ruRU' then
	L["AutomateQuest"] = "Автоматизировать задание"
	L["MissingOptions"] = "\"Blitz Options\" не загрузились, потому что аддон %s."

-- French --
elseif Language =='frFR' then
	L["AutomateQuest"] = "Automatiser Quête"
	L["MissingOptions"] = "\"Options Blitz\" n'a pas pu être chargé parce que l'addon est %s."
	

-- English -- 
else
	L.AutomateQuest = 'Automate Quest'
	L.MissingOptions = '"Blitz Options" could not be loaded because the addon is %s.'
end