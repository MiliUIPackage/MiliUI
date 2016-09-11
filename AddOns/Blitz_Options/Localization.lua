local L = Blitz_Locals
local Language = GetLocale()

-- Traditional Chinese -- 
if Language == 'zhTW' then
	L["Accept"] = "接受任務"
	L["AcceptTip"] = "接受所有任務"
	L["AutomateKey"] = "自動鍵"
	L["AutomateKeyTip"] = "按住輔助鍵以自動接受任務"
	L["Deliver"] = "繳交任務"
	L["DeliverTip"] = "繳交所有完成任務"
	L["Description"] = "Blitz預設僅接受每日或重複任務，此選項可以調整設定。"
	L["Manual"] = "需要手動鍵"
	L["ManualTip"] = "按住輔助鍵以自動接受任務"
	L["ManualKey"] = "手動鍵"
	L["ManualKeyTip"] = "按住輔助鍵改為手動交接任務"
	L["SelectReward"] = "選擇獎勵"
	L["SelectRewardTip"] = "讓Blitz自動選擇最有價值的任務獎勵"
	L["Tutorial1"] = "您正在使用由 |cffffd200Jaliborc|r 創作的 |cffffd200Blitz|r 插件|n|n 在預設情況下 |cffffd200Blitz|r 僅自動接受每日任務、每週任務或重複任務，您可在任務給予者畫面點擊 |cffffd200自動任務|r 按鈕來開啟功能。"
	L["Tutorial2"] = "您可以在 |cffffd200Interface Options|r 找到 |cffffd200Game Menu|r 進行設定來改變交接任務或獎勵選項。"
	L["Welcome"] = "歡迎使用Blitz!"

-- Simplified Chinese -- 
elseif Language == 'zhCN' then
	L["Accept"] = "接受任务"
	L["AcceptTip"] = "接受所有任务"
	L["AutomateKey"] = "自动键"
	L["AutomateKeyTip"] = "按住辅助键以自动接受任务"
	L["Deliver"] = "缴交任务"
	L["DeliverTip"] = "缴交所有完成任务"
	L["Description"] = "Blitz预设仅接受每日或重复任务，此选项可以调整设定。"
	L["Manual"] = "需要手动键"
	L["ManualTip"] = "按住辅助键以自动接受任务"
	L["ManualKey"] = "手动键"
	L["ManualKeyTip"] = "按住辅助键改为手动交接任务"
	L["SelectReward"] = "选择奖励"
	L["SelectRewardTip"] = "让Blitz自动选择最有价值的任务奖励"
	L["Tutorial1"] = "您正在使用由 |cffffd200Jaliborc|r 创作的 |cffffd200Blitz|r 插件|n|n 在预设情况下 |cffffd200Blitz|r 仅自动接受日常任务、周常任务或重复任务，您可在任务给予者画面点击 |cffffd200自动任务|r 按钮来开启功能。"
	L["Tutorial2"] = "您可以在 |cffffd200Interface Options|r 找到 |cffffd200Game Menu|r 进行设定来改变交接任务或奖励选项。"
	L["Welcome"] = "欢迎使用Blitz!"
	
-- Russian --
elseif Language =='ruRU' then
	L["Accept"] = "Принимать задания"
	L["AcceptTip"] = "Если включено, Блиц будет принимать любые доступные задания"
	L["AutomateKey"] = "Клавиша автоматизации"
	L["AutomateKeyTip"] = "Зажмите, чтобы задания были автоматизированы"
	L["AutomateQuest"] = "Автоматизировать задание"
	L["Deliver"] = "Сдавать задания"
	L["DeliverTip"] = "Если включено, Блиц будет сдавать любые завершенные задания"
	L["Description"] = "По умолчанию, Блиц только автоматизирует каждодневные и повторяющиеся задания. Эти настройки позволяют Вам изменить поведение Блица - когда и какие задания он будет автоматизировать."
	L["Manual"] = "Необходима клавиша"
	L["ManualTip"] = "Если включено, задания будут автоматизированы только когда Вы зажмете клавишу, указанную ниже."
	L["ManualKey"] = "Клавиша вручную"
	L["ManualKeyTip"] = "Зажмите для того, чтобы задания не были автоматизированы."
	L["MissingOptions"] = "\"Blitz Options\" не загрузились, потому что аддон %s."
	L["SelectReward"] = "Выберите награду"
	L["SelectRewardTip"] = "Если включено, Блиц выберет самую дорогостоящую награду при сдаче задания."
	L["Tutorial1"] = "Теперь Вы используете |cffffd200Блиц|r, от |cffffd200Jaliborc|r, аддон, который автоматически получает и сдает задания за Вас.|n|nПо умолчанию, |cffffd200Блиц|r автоматизирует только ежедневные, еженедельные и повторяющиеся задания по Вашему выбору. Вы можете выбирать их, кликнув на кнопке |cffffd200Автоматизировать задание|r, когда разговариваете с квестодателем."
	L["Tutorial2"] = "Что, если Вы хотите, чтобы Блиц сдавал все завершенные задания за Вас? Или автоматически выбирал самую дорогую награду?|n|nЭти и многие другие настройки Вы можете найти в |cffffd200Игровом меню|r в |cffffd200Настройках интерфейса|r."
	L["Welcome"] = "Добро пожаловать в Блиц!"
	
-- French --
elseif Language =='frFR' then
	L["Accept"] = "Accepter les quêtes"
	L["AcceptTip"] = "Si activée, Blitz acceptera toute quête disponible."
	L["AutomateKey"] = "Touche Automatisation"
	L["AutomateKeyTip"] = "Maintenir pour permettre aux quêtes d'être automatisées."
	L["Deliver"] = "Rendre les quêtes"
	L["DeliverTip"] = "Si activée, Blitz rendra toute quête terminée."
	L["Description"] = "Par défaut, Blitz n'automatise que les quêtes journalières et répétables de votre choix. Ces options vous permettent de changer quelles quêtes et quand il les automatise."
	L["Manual"] = "Mode Manuel / Touche requise"
	L["ManualTip"] = "Si activée, les quêtes ne seront automatisées que si vous maintenez la touche ci-dessous."
	L["ManualKey"] = "Touche Manuelle"
	L["ManualKeyTip"] = "Maintenir pour éviter que les quêtes ne soient automatisées."
	L["SelectReward"] = "Sélectionner une récompense"
	L["SelectRewardTip"] = "Si activée, Blitz choisira la récompense de plus grande valeur en rendant les quêtes."
	L["Tutorial1"] = "Vous utilisez désormais |cffffd200Blitz|r, de |cffffd200Jaliborc|r, un addon qui accepte et rend automatiquement les quêtes pour vous.|n|nPar défaut, |cffffd200Blitz|r n'automatise que les quêtes journalières, hebdomadaires et répétables de votre choix. Vous pouves les sélectionner en cliquant sur le bouton |cffffd200Automatiser Quête|r en parlant au donneur de quête."
	L["Tutorial2"] = "Si vous souhaitez que Blitz rende toutes vos quêtes, pas seulement les journalières? Ou qu'il sélectionne automatiquement l'objet de plus grande valeur?|n|nCes options et bien d'autres sont disponibles dans le |cffffd200Menu de jeu|r dans les |cffffd200Options d'Interface|r."
	L["Welcome"] = "Bienvenue dans Blitz!"

-- English -- 
else
	L.Description = 'By default, Blitz only automates daily and repeatable quests of your choice. These options allow you to change just that: when and which quests it automates.'
	L.Tutorial1 = 'You are now using |cffffd200Blitz|r, by |cffffd200Jaliborc|r, an addon which automatically accepts and delivers quests for you.|n|nBy default, |cffffd200Blitz|r only automates daily, weekly and repeatable quests of your choice. You can select them by clicking on the |cffffd200Automate Quest|r button when talking to the quest giver.'
	L.Tutorial2 = 'What if you want Blitz to deliver all completed quests for you, not only the daily ones? Or to automatically select the most valuable reward?|n|nThese and many other options are available at the |cffffd200Game Menu|r at the |cffffd200Interface Options|r.'
	L.Welcome = 'Welcome to Blitz!'
	
	L.Accept = 'Accept Quests'
	L.AcceptTip = 'If enabled, Blitz will accept any available quest.'
	L.Deliver = 'Deliver Quests'
	L.DeliverTip = 'If enabled, Blitz will deliver any completed quest you have.'
	L.SelectReward = 'Select Reward'
	L.SelectRewardTip = 'If enabled, Blitz will automatically choose the most valuable reward when delivering quests.'
	
	L.Manual = 'Require Key'
	L.ManualTip = 'If enabled, quests will only be automated if you hold the key below.'
	L.AutomateKey = 'Automate Key'
	L.AutomateKeyTip = 'Hold to allow quests to be automated.'
	L.ManualKey = 'Manual Key'
	L.ManualKeyTip = 'Hold to prevent quests from being automated.'
end