Prat:AddModuleToLoad(function()
    local PRAT_MODULE = Prat:RequestModuleName("Search")

    if PRAT_MODULE == nil then
        return
    end

    local L = Prat:GetLocalizer({})

    --[===[@debug@
    L:AddLocale("enUS", {
        module_name = "Search",
        module_desc = "Adds the ability to search the chatframes.",
        module_info = "This module adds the /find and /findall commands to search the chat history\n\nUsage:\n\n /find <text> \n\n /findall <text>",
        err_tooshort = "Search term is too short",
        err_notfound = "Not Found",
        find_results = "Find Results:",
    })
    --@end-debug@]===]

    -- These Localizations are auto-generated. To help with localization
    -- please go to http://www.wowace.com/projects/prat-3-0/localization/


    --@non-debug@
    L:AddLocale("enUS",
    {
	err_notfound = "Not Found",
	err_tooshort = "Search term is too short",
	find_results = "Find Results:",
	module_desc = "Adds the ability to search the chatframes.",
	module_info = [=[This module adds the /find and /findall commands to search the chat history

Usage:

 /find <text> 

 /findall <text>]=],
	module_name = "Search",
}

    )
    L:AddLocale("frFR",
    {
	-- err_notfound = "",
	-- err_tooshort = "",
	-- find_results = "",
	-- module_desc = "",
	-- module_info = "",
	-- module_name = "",
}

    )
    L:AddLocale("deDE",
    {
	err_notfound = "Nicht gefunden",
	err_tooshort = "Suchbegriff zu kurz",
	find_results = "Gefundene Ergebnisse:",
	module_desc = [=[Aktiviert die Suchfunktion in Chatfenstern.

Suche]=],
	module_info = [=[Aktiviert die Textbefehle /find und /findall, um die Chathistorie zu durchsuchen

Benutzung:

/find <text>

/findall <text>

Suche]=],
	module_name = "Suchen",
}

    )
    L:AddLocale("koKR",
    {
	err_notfound = "찾을 수 없음",
	err_tooshort = "검색 구문이 너무 짧습니다",
	find_results = "검색 결과:",
	module_desc = "대화창 검색 기능을 추가합니다.",
	module_info = [=[이 모듈은 대화 기록을 검색하는 /find 와 /findall 명령어를 추가합니다

사용법:

/find <문자열>

/findall <문자열>]=],
	module_name = "검색",
}

    )
    L:AddLocale("esMX",
    {
	-- err_notfound = "",
	-- err_tooshort = "",
	-- find_results = "",
	-- module_desc = "",
	-- module_info = "",
	-- module_name = "",
}

    )
    L:AddLocale("ruRU",
    {
	err_notfound = "Не Найденно",
	err_tooshort = "Критерий поиска слишком короток",
	find_results = "Найти Результаты:",
	module_desc = "Добавляет возможность поиска текста в чате.",
	module_info = [=[Этот модуль добавляет команды /find и /findall для поиска в истории чата

Использование:

/find <текст>

/findall <текст>]=],
	module_name = "Поиск",
}

    )
    L:AddLocale("zhCN",
    {
	err_notfound = "没找到",
	err_tooshort = "搜索文字太短",
	find_results = "查找结果：",
	module_desc = "增加搜索聊天框的能力",
	module_info = [=[此模块增加 /find 和 /findall 命令搜索聊天历史

用法:

 /find <文字>

 /findall <文字>]=],
	module_name = "搜索",
}

    )
    L:AddLocale("esES",
    {
	-- err_notfound = "",
	-- err_tooshort = "",
	-- find_results = "",
	-- module_desc = "",
	-- module_info = "",
	-- module_name = "",
}

    )
    L:AddLocale("zhTW",
    {
	err_notfound = "找不到",
	err_tooshort = "尋找物品太短",
	find_results = "找到結果:",
	-- module_desc = "",
	-- module_info = "",
	module_name = "尋找",
}

    )
    --@end-non-debug@


    local module = Prat:NewModule(PRAT_MODULE)


    Prat:SetModuleDefaults(module.name, {
        profile = {
            on = true,
        }
    } )

    
    Prat:SetModuleOptions(module.name, {
        name = L.module_name,
        desc = L.module_desc,
        type = "group",
        args = {
            info = {
                name = L.module_info,
                type = "description",
            }
        }
    })


    SLASH_FIND1 = "/find"
    SlashCmdList["FIND"] = function(msg) module:Find(msg, false) end

    SLASH_FINDALL1 = "/findall"
    SlashCmdList["FINDALL"] = function(msg) module:Find(msg, true) end

    local MAX_SCRAPE_TIME = 30
    local foundlines = {}
    local scrapelines = {}

    local function out(frame, msg)
        Prat:Print(frame, msg)
    end

    function module:Find(word, all, frame)
        if not self.db.profile.on then
            return
        end

        if frame == nil then
            frame = SELECTED_CHAT_FRAME
        end

        if not word then return end

        if #word <= 1 then
            frame:ScrollToBottom()
            out(frame, L.err_tooshort)
            return
        end

        if frame:GetNumMessages() == 0 then
             out(frame, L.err_notfound)
             return
        end

        local starttime = time()
        local runtime = 0

        if not all and self.lastsearch == word then
            frame:PageUp()
        end

        if all then
            frame:ScrollToBottom()
        end

        self.lastsearch = word

        repeat
            self:ScrapeFrame(frame, nil, true)

            for i,v in ipairs(scrapelines) do
                if v:find(word) then
                    if all then
                        table.insert(foundlines, v)
                    else
                        return
                    end
                end
            end

            frame:PageUp()
            runtime = time() - starttime
            if runtime >= MAX_SCRAPE_TIME then
                out(frame, "Frame scraping timeout exceeded, results will be incomplete.")
                break;
            end

        until frame:AtTop() or runtime >= MAX_SCRAPE_TIME

        self.lastsearch = nil

        frame:ScrollToBottom()

        if all and #foundlines > 0 then
            out(frame, L.find_results)

            Prat.loading = true
            for i,v in ipairs(foundlines) do
                frame:AddMessage(v)
            end
            Prat.loading = nil

        else
            out(frame, L.err_notfound)
        end

        wipe(foundlines)
    end

    function module:ScrapeFrame(frame)
        wipe(scrapelines)

        self:AddLines(scrapelines, frame:GetRegions())
    end

    function module:AddLines(lines, ...)
        for i=select("#", ...),1,-1 do
            local x = select(i, ...)
            if x:GetObjectType() == "FontString" and not x:GetName() then
                table.insert(lines, x:GetText())
            end
        end
    end

    return
end) -- Prat:AddModuleToLoad