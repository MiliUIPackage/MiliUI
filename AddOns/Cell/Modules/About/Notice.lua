local _, Cell = ...

-- ============================================================
-- MAINTAINER NOTICES  (MiliUI)
--
-- Announcements shown in Cell's About > Changelogs window, which now shows nothing else.
-- Every translation of every notice lives
-- here, in one fork-owned file, and NOT in Locales/*.lua. Three reasons:
--
--   * Locales/*.lua is a translation TABLE -- durable UI strings referenced by key.
--     A release announcement is content with a lifespan, not a UI string.
--   * Those eleven files are upstream's. Injecting fork content into all of them
--     maximises the merge conflict surface for every future upstream pull, for text
--     upstream will never have.
--   * Adding a notice means editing one file instead of eleven, and the eleven
--     translations of the same paragraph sit next to each other where they can
--     actually be compared.
--
-- TO ADD A NOTICE: insert a new entry at the TOP of Cell.notices. The list is ordered
-- newest first and `id` is what gets remembered as "seen" -- any string works as long
-- as it changes, so a date is the obvious choice. Nothing else needs touching; the
-- window pops once for the new id and the previous notices stay readable via the
-- "past notices" link.
--
-- ⚠ The popup is keyed to the notice id, NOT to Cell.version. That version number is
-- bumped for every Revise migration gate, and throwing this window at players over a
-- data migration they cannot see is exactly why the automatic changelog popup was
-- turned off in this fork to begin with.
-- ============================================================

-- SimpleHTML understands <h1>/<h2>/<p>/<br/>/<a href="..."> only, and source line
-- breaks are NOT preserved -- every paragraph needs its own <p>.
Cell.notices = {
{
    id = "2026-08-12",
    text = {

["enUS"] = [[
        <h1>A note from the maintainer</h1>
        <p>Since 12.0 there have been a great many API changes, especially around health bars and auras. enderneko, Cell's original author, could no longer keep pace with them alongside a demanding job, and for a while we lost Cell.</p>
        <br/>
        <p>12.1 is almost here, and it brings an even larger change to the aura API. Cell has always been one of my favourite addons - for how its interface feels to use, and for the quiet elegance of its architecture and design.</p>
        <br/>
        <p>So that Cell can keep working in 12.1 and beyond, I have rewritten the aura-related code. And to keep it maintainable in the years ahead, I have made a trade-off: I am dropping support for Classic realms. The Cell I maintain will target Retail World of Warcraft only.</p>
        <br/>
        <p>To all World of Warcraft players,</p>
        <p>Mili</p>
]],

["zhTW"] = [[
        <h1>維護者的話</h1>
        <p>12.0 之後有許多 API 變動，尤其是血條與光環。Cell 的原作者 enderneko 因為工作繁忙無法持續更新，我們一度失去了 Cell。</p>
        <br/>
        <p>12.1 即將到來，這次的光環 API 變動更為劇烈。Cell 一直是我最喜歡的插件之一 —— 無論是 UI/UX 帶給人的感受，或是它優美的程式架構與設計。</p>
        <br/>
        <p>為了讓 Cell 在 12.1 以及之後還能繼續使用，我重寫了光環相關的程式碼；也為了取捨未來的維護難度，我捨棄了對經典伺服器的支援。我維護的 Cell 將只支援現行版本（正式服）的魔獸世界。</p>
        <br/>
        <p>敬所有魔獸世界玩家</p>
        <p>Mili</p>
]],

["zhCN"] = [[
        <h1>维护者的话</h1>
        <p>12.0 之后有许多 API 变动，尤其是血条与光环。Cell 的原作者 enderneko 因为工作繁忙无法持续更新，我们一度失去了 Cell。</p>
        <br/>
        <p>12.1 即将到来，这次的光环 API 变动更为剧烈。Cell 一直是我最喜欢的插件之一 —— 无论是 UI/UX 带给人的感受，或是它优美的程序架构与设计。</p>
        <br/>
        <p>为了让 Cell 在 12.1 以及之后还能继续使用，我重写了光环相关的代码；也为了取舍未来的维护难度，我舍弃了对经典服务器的支持。我维护的 Cell 将只支持现行版本（正式服）的魔兽世界。</p>
        <br/>
        <p>敬所有魔兽世界玩家</p>
        <p>Mili</p>
]],

["deDE"] = [[
        <h1>Ein Wort vom Betreuer</h1>
        <p>Seit 12.0 gab es sehr viele API-Änderungen, besonders bei Lebensbalken und Auren. enderneko, der ursprüngliche Autor von Cell, konnte neben einem fordernden Beruf nicht mehr Schritt halten, und eine Zeit lang hatten wir Cell verloren.</p>
        <br/>
        <p>12.1 steht kurz bevor und bringt eine noch größere Änderung der Auren-API mit sich. Cell war schon immer eines meiner Lieblings-Addons - für das Gefühl, das seine Oberfläche vermittelt, und für die stille Eleganz seiner Architektur.</p>
        <br/>
        <p>Damit Cell in 12.1 und darüber hinaus weiter funktioniert, habe ich den auren-bezogenen Code neu geschrieben. Und damit es auf Dauer wartbar bleibt, habe ich eine Abwägung getroffen: Ich lasse die Unterstützung für Classic-Realms fallen. Das von mir gepflegte Cell richtet sich ausschließlich an Retail-World-of-Warcraft.</p>
        <br/>
        <p>An alle World-of-Warcraft-Spieler,</p>
        <p>Mili</p>
]],

["frFR"] = [[
        <h1>Un mot du mainteneur</h1>
        <p>Depuis la 12.0, les changements d'API ont été nombreux, en particulier pour les barres de vie et les auras. enderneko, l'auteur original de Cell, n'a plus pu suivre le rythme en parallèle d'un travail exigeant, et nous avons un temps perdu Cell.</p>
        <br/>
        <p>La 12.1 approche, et elle apporte une refonte encore plus profonde de l'API des auras. Cell a toujours été l'un de mes addons préférés - pour ce que son interface donne à ressentir, et pour l'élégance discrète de son architecture.</p>
        <br/>
        <p>Pour que Cell continue de fonctionner en 12.1 et au-delà, j'ai réécrit tout le code lié aux auras. Et pour qu'il reste maintenable dans la durée, j'ai fait un choix : j'abandonne la prise en charge des royaumes Classic. Le Cell que je maintiens ne visera que World of Warcraft Retail.</p>
        <br/>
        <p>À tous les joueurs de World of Warcraft,</p>
        <p>Mili</p>
]],

["esES"] = [[
        <h1>Unas palabras del mantenedor</h1>
        <p>Desde la 12.0 ha habido muchísimos cambios de API, sobre todo en las barras de vida y en las auras. enderneko, el autor original de Cell, no pudo seguir el ritmo junto a un trabajo exigente, y durante un tiempo perdimos Cell.</p>
        <br/>
        <p>La 12.1 está a punto de llegar, y trae un cambio aún mayor en la API de auras. Cell siempre ha sido uno de mis addons favoritos, tanto por lo que transmite su interfaz como por la elegancia discreta de su arquitectura y su diseño.</p>
        <br/>
        <p>Para que Cell siga funcionando en la 12.1 y más allá, he reescrito todo el código relacionado con las auras. Y para poder mantenerlo con el tiempo, he tomado una decisión de compromiso: abandono el soporte para los reinos Classic. El Cell que yo mantengo será solo para World of Warcraft Retail.</p>
        <br/>
        <p>A todos los jugadores de World of Warcraft,</p>
        <p>Mili</p>
]],

["itIT"] = [[
        <h1>Due parole dal manutentore</h1>
        <p>Dalla 12.0 ci sono stati moltissimi cambiamenti alle API, soprattutto per le barre della salute e per le aure. enderneko, l'autore originale di Cell, non è più riuscito a starci dietro accanto a un lavoro impegnativo, e per un periodo abbiamo perso Cell.</p>
        <br/>
        <p>La 12.1 è alle porte e porta con sé un cambiamento ancora più profondo alle API delle aure. Cell è sempre stato uno dei miei addon preferiti - per come la sua interfaccia si fa sentire all'uso, e per la sobria eleganza della sua architettura.</p>
        <br/>
        <p>Perché Cell continui a funzionare in 12.1 e oltre, ho riscritto tutto il codice legato alle aure. E per poterlo mantenere nel tempo, ho fatto una scelta: rinuncio al supporto per i reami Classic. Il Cell che mantengo io sarà solo per World of Warcraft Retail.</p>
        <br/>
        <p>A tutti i giocatori di World of Warcraft,</p>
        <p>Mili</p>
]],

["koKR"] = [[
        <h1>관리자의 말</h1>
        <p>12.0 이후 API가 아주 많이 바뀌었습니다. 특히 생명력 바와 오라가 그렇습니다. Cell의 원작자 enderneko는 바쁜 본업과 병행하며 그 속도를 따라갈 수 없었고, 우리는 한동안 Cell을 잃었습니다.</p>
        <br/>
        <p>12.1이 곧 다가옵니다. 이번에는 오라 API가 훨씬 더 크게 바뀝니다. Cell은 언제나 제가 가장 좋아하는 애드온 중 하나였습니다. UI와 UX가 주는 느낌도, 그 단정하고 아름다운 구조와 설계도요.</p>
        <br/>
        <p>12.1 이후에도 Cell을 계속 쓸 수 있도록 오라 관련 코드를 다시 작성했습니다. 그리고 앞으로의 유지보수를 위해 하나를 내려놓기로 했습니다. 클래식 서버 지원을 포기합니다. 제가 관리하는 Cell은 현행 버전(정식 서버)만 지원합니다.</p>
        <br/>
        <p>모든 월드 오브 워크래프트 플레이어에게,</p>
        <p>Mili</p>
]],

["ptBR"] = [[
        <h1>Uma palavra do mantenedor</h1>
        <p>Desde a 12.0 houve muitas mudanças de API, especialmente nas barras de vida e nas auras. enderneko, o autor original do Cell, não conseguiu acompanhar esse ritmo junto a um trabalho exigente, e por um tempo perdemos o Cell.</p>
        <br/>
        <p>A 12.1 está chegando, e traz uma mudança ainda maior na API de auras. O Cell sempre foi um dos meus addons favoritos - pelo que a sua interface transmite ao ser usada, e pela elegância discreta da sua arquitetura e do seu design.</p>
        <br/>
        <p>Para que o Cell continue funcionando na 12.1 e depois dela, reescrevi todo o código relacionado a auras. E para mantê-lo sustentável daqui para frente, fiz uma escolha: vou abandonar o suporte aos reinos Classic. O Cell que eu mantenho será apenas para o World of Warcraft Retail.</p>
        <br/>
        <p>A todos os jogadores de World of Warcraft,</p>
        <p>Mili</p>
]],

["ruRU"] = [[
        <h1>Слово от сопровождающего</h1>
        <p>После 12.0 в API произошло очень много изменений, особенно в полосах здоровья и аурах. enderneko, оригинальный автор Cell, не смог за ними успевать вместе с основной работой, и на какое-то время мы потеряли Cell.</p>
        <br/>
        <p>12.1 уже на пороге, и в ней API аур меняется ещё сильнее. Cell всегда был одним из моих любимых аддонов - и по ощущению от интерфейса, и по тихой красоте его архитектуры и устройства.</p>
        <br/>
        <p>Чтобы Cell продолжал работать в 12.1 и дальше, я переписал весь код, связанный с аурами. И чтобы его можно было поддерживать и впредь, я пошёл на компромисс: отказываюсь от поддержки серверов Classic. Cell, который поддерживаю я, будет только для актуальной версии World of Warcraft.</p>
        <br/>
        <p>Всем игрокам World of Warcraft,</p>
        <p>Mili</p>
]],

    },
},
}

-- esMX shares the Spanish text of every notice.
for _, notice in ipairs(Cell.notices) do
    notice.text["esMX"] = notice.text["esMX"] or notice.text["esES"]
end

-- The two navigation links, here rather than in Locales/*.lua so that everything a notice
-- needs lives in one file.
local LINKS = {
    ["enUS"] = { past = "Click to view past notices",     notice = "Back to the latest notice" },
    ["zhTW"] = { past = "點此查看過去的公告",             notice = "回到最新公告" },
    ["zhCN"] = { past = "点此查看过去的公告",             notice = "回到最新公告" },
    ["deDE"] = { past = "Frühere Mitteilungen ansehen",   notice = "Zurück zur neuesten Mitteilung" },
    ["frFR"] = { past = "Voir les annonces précédentes",  notice = "Retour à la dernière annonce" },
    ["esES"] = { past = "Ver los avisos anteriores",      notice = "Volver al aviso más reciente" },
    ["esMX"] = { past = "Ver los avisos anteriores",      notice = "Volver al aviso más reciente" },
    ["itIT"] = { past = "Vedi gli avvisi precedenti",     notice = "Torna all'avviso più recente" },
    ["koKR"] = { past = "지난 공지 보기",                 notice = "최신 공지로 돌아가기" },
    ["ptBR"] = { past = "Ver os avisos anteriores",       notice = "Voltar ao aviso mais recente" },
    ["ruRU"] = { past = "Посмотреть прошлые объявления",  notice = "Вернуться к последнему объявлению" },
}

local function Localized(notice)
    local t = notice.text
    return t[GetLocale()] or t["enUS"] or ""
end

local function Links()
    return LINKS[GetLocale()] or LINKS["enUS"]
end

-- Empty string, never nil: callers concatenate these straight into the HTML body.
function Cell.GetLatestNotice()
    local newest = Cell.notices[1]
    if not newest then return "" end

    local html = Localized(newest) .. "<br/>"
    if #Cell.notices > 1 then
        html = html .. '<p><a href="notices">' .. Links().past .. "</a></p><br/>"
    end
    return html
end

-- Every notice, newest first, each datelined by its id.
function Cell.GetAllNotices()
    local parts = {}
    for _, notice in ipairs(Cell.notices) do
        parts[#parts + 1] = "<p>" .. notice.id .. "</p>" .. Localized(notice) .. "<br/>"
    end
    parts[#parts + 1] = '<p><a href="notice">' .. Links().notice .. "</a></p><br/>"
    return table.concat(parts)
end

function Cell.HasNotice()
    return Cell.notices[1] ~= nil
end

-- ⚠ Compares ids, so a CellDB carrying the old numeric revision simply fails to match
-- and the newest notice shows once more before being replaced by its id. No migration.
function Cell.HasUnreadNotice()
    local newest = Cell.notices[1]
    return newest ~= nil and CellDB["noticeViewed"] ~= newest.id
end

function Cell.MarkNoticesRead()
    local newest = Cell.notices[1]
    if newest then CellDB["noticeViewed"] = newest.id end
end
