local CDM = _G["Ayije_CDM"]
local L = CDM:NewLocale("ptBR")
if not L then return end

-----------------------------------------------------------------------
-- Init.lua
-----------------------------------------------------------------------

L["Callback error in '%s':"] = "Erro de callback em '%s':"

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "Você não pode abrir abrir as configs em combate!"
L["Could not load options: %s"] = "Falha ao abrir as opções: %s"
L["Enabled Blizzard Cooldown Manager."] = "Gerenciador de Cooldowns da Blizzard ativado."

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "Modo de Edição travado"
L["use /cdm"] = "use /cdm"
L["Edit Mode locked - use /cdm"] = "Modo de Edição travado - use /cdm"
L["Cooldown Viewer settings are managed by /cdm. Edit Mode changes are disabled to avoid taint."] = "As configs do Visualizador de Cooldowns são geridas pelo /cdm. As mudanças no Modo de Edição foram desativadas para evitar erros de interface."

-----------------------------------------------------------------------
-- Core/Layout/Containers.lua
-----------------------------------------------------------------------

L["Click and drag to move - /cdm > Positions to lock"] = "Clique e arraste para mover - /cdm > Posições para travar"

-----------------------------------------------------------------------
-- Modules/PlayerCastBar.lua
-----------------------------------------------------------------------

L["Preview Cast"] = "Teste de Lançamento"
L["Click and drag to move - /cdm > Cast Bar to lock"] = "Clique e arraste para mover - /cdm > Barra de Lançamennto para travar"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Init.lua
-----------------------------------------------------------------------

L["Copy this URL:"] = "Copie esta URL:"
L["Close"] = "Fechar"
L["Reset the current profile to default settings?"] = "Quer resetar o perfil atual para as configurações padrão?"
L["Reset"] = "Resetar"
L["Cancel"] = "Cancelar"
L["Copy"] = "Copiar"
L["Delete"] = "Excluir"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "Não dá pra %s em combate"
L["open CDM config"] = "abrir a config do CDM"
L["Display"] = "Visual"
L["Styling"] = "Estilo"
L["Buffs"] = "Buffs"
L["Features"] = "Funções"
L["Utility"] = "Utilitários"
L["Cooldown Manager"] = "Gerenciador de Cooldowns"
L["Settings"] = "Configurações"
L["rebuild CDM config"] = "Reconstruir config do CDM"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "Essenciais"
L["Row 1 Width"] = "Largura da Linha 1"
L["Row 1 Height"] = "Altura da Linha 1"
L["Row 2 Width"] = "Largura da Linha 2"
L["Row 2 Height"] = "Altura da Linha 2"
L["Width"] = "Largura"
L["Height"] = "Altura"
L["Buff"] = "Buff"
L["Secondary Buff"] = "Buff Secundário"
L["Tertiary Buff"] = "Buff Terciário"
L["Icon Sizes"] = "Tamanho dos Ícones"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Layout.lua
-----------------------------------------------------------------------

L["Layout Settings"] = "Ajustes de Layout"
L["Icon Spacing"] = "Espaçamento dos Ícones"
L["Max Icons Per Row"] = "Máximo de Ícones por Linha"
L["Utility Y Offset"] = "Ajuste Y (Vertical)"
L["Wrap Utility Bar"] = "Quebrar Linha da Barra de Utilitários"
L["Utility Max Icons Per Row"] = "Máximo de Ícones por Linha"
L["Unlock Utility Bar"] = "Destravar Barra de Utilitários"
L["Utility X Offset"] = "Ajuste X (Horizontal) dos Utilitários"
L["Display Vertical"] = "Exibir Verticalmente"
L["Buff Layout"] = "Layout dos Buffs"
L["Secondary Buffs Grow Horizontally (Centered)"] = "Buffs Secundários crescem pros lados (Centralizado)"
L["Tertiary Buffs Grow Horizontally (Centered)"] = "Buffs Terciários crescem pros lados (Centralizado)"
L["Layout"] = "Layout"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Positions.lua
-----------------------------------------------------------------------

L["Lock Container"] = "Travar Painel"
L["Unlock to drag the container freely.\\nUse sliders below for precise positioning."] = "Destrave para arrastar livremente.\\nUse as barras abaixo para um ajuste fino."
L["Current: %s (%d, %d)"] = "Atual: %s (%d, %d)"
L["X Position"] = "Posição X"
L["Y Position"] = "Posição Y"
L["X Offset"] = "Ajuste X"
L["Y Offset"] = "Ajuste Y"
L["Essential Container Position"] = "Posição do Painel Essencial"
L["Main Buff Container Position"] = "Posição do Painel de Buffs Principal"
L["Secondary Buff Offset (relative to Main)"] = "Ajuste do Buff Secundário (relativo ao Principal)"
L["Tertiary Buff Offset (relative to Main)"] = "Ajuste do Buff Terciário (relativo ao Principal)"
L["Buff Bar Container Position"] = "Posição do Painel de Barras de Buffs"
L["Positions"] = "Posições"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "Configurações de Borda"
L["Border Texture"] = "Textura da Borda"
L["Select Border..."] = "Escolher Borda..."
L["Border Color"] = "Cor da Borda"
L["Border Size"] = "Tamanho da Borda"
L["Border Offset X"] = "Ajuste X da Borda"
L["Border Offset Y"] = "Ajuste Y da Borda"
L["Zoom Icons (Remove Borders & Overlay)"] = "Dar Zoom nos Ícones (Remove Bordas e Camadas)"
L["Visual Elements"] = "Elementos Visuais"
L["Hide Debuff Border (red outline on harmful effects)"] = "Esconder Borda de Debuff (contorno vermelho em efeitos negativos)"
L["Hide Pandemic Indicator (animated refresh window border)"] = "Esconder Indicador de Pandemia (borda animada para renovar o DOT)"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "Esconder Brilho de Recarga (o flash que dá quando o CD volta)"
L["* These options require /reload to take effect"] = "* Essas opções precisam de /reload para funcionar"
L["Borders"] = "Bordas"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Text.lua
-----------------------------------------------------------------------

L["Global Settings"] = "Configurações Gerais"
L["Font"] = "Fonte"
L["Font Outline"] = "Contorno da Fonte"
L["None"] = "Nenhum"
L["Outline"] = "Contorno"
L["Thick Outline"] = "Contorno Grosso"
L["Cooldown Timer"] = "Timer de Cooldown"
L["Font Size"] = "Tamanho da Fonte"
L["Color"] = "Cor"
L["Cooldown Stacks (Charges)"] = "Stacks do Cooldown (Cargas)"
L["Position"] = "Posição"
L["Buff Cooldown Timer"] = "Timer do Buff"
L["Buff Stacks"] = "Stacks do Buff"
L["Anchor"] = "Âncora"
L["Main Buff Bar Position"] = "Posição da Barra de Buff Principal"
L["Secondary Buff Bar Position"] = "Posição da Barra de Buff Secundária"
L["Tertiary Buff Bar Position"] = "Posição da Barra de Buff Terciária"
L["Buff Bars - Name Text"] = "Barras de Buff - Nome"
L["Buff Bars - Duration Text"] = "Barras de Buff - Duração"
L["Buff Bars - Stack Count Text"] = "Barras de Buff - Contagem de Stacks"
L["Text"] = "Texto"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Glow.lua
-----------------------------------------------------------------------

L["Pixel Glow"] = "Brilho de Pixel"
L["Autocast Glow"] = "Brilho de Autocast"
L["Button Glow"] = "Brilho de Botão"
L["Proc Glow"] = "Brilho de Proc"
L["Glow Settings"] = "Ajustes de Brilho"
L["Glow Type"] = "Tipo de Brilho"
L["Use Custom Color"] = "Usar Cor Personalizada"
L["Glow Color"] = "Cor do Brilho"
L["Pixel Glow Settings"] = "Ajustes do Brilho de Pixel"
L["Lines"] = "Linhas"
L["Frequency"] = "Frequência"
L["Length (0=auto)"] = "Comprimento (0=auto)"
L["Thickness"] = "Espessura"
L["Autocast Glow Settings"] = "Ajustes do Brilho de Autocast"
L["Particles"] = "Partículas"
L["Scale"] = "Escala"
L["Button Glow Settings"] = "Ajustes de Brilho do Botão"
L["Frequency (0=default)"] = "Frequência (0=padrão)"
L["Proc Glow Settings"] = "Ajustes do Brilho de Proc"
L["Duration (x10)"] = "Duração (x10)"
L["Glow"] = "Brilho"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "Transparência (Fade)"
L["Enable Fading"] = "Ativar Esmaecimento"
L["Fade Trigger"] = "Gatilho do Fade"
L["Fade when no target"] = "Sumir quando estiver sem alvo"
L["Fade out of combat"] = "Sumir fora de combate"
L["Faded Opacity"] = "Opacidade ao Sumir"
L["Apply Fading To"] = "Aplicar Fade em"
L["Buff Bars"] = "Barras de Buffs"
L["Racials"] = "Raciais"
L["Defensives"] = "Defensivos"
L["Trinkets"] = "Trinkets"
L["Resources"] = "Recursos"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Assist.lua
-----------------------------------------------------------------------

L["Assist"] = "Assistente"
L["Rotation Assist"] = "Assistente de Rotação"
L["Enable Rotation Assist"] = "Ativar Assistente de Rotação"
L["Highlight Size"] = "Tamanho do brilho"
L["Keybindings"] = "Teclas de atalho"
L["Enable Keybind Text"] = "Ativar Texto das Teclas de Atalho"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Icons.lua
-----------------------------------------------------------------------

L["Primary Buff Order"] = "Ordem dos Buffs Primários"
L["Press icon to color the border"] = "Clique no ícone para colorir a borda"
L["Click to change border color"] = "Clique para mudar a cor da borda"
L["Right-click to reset to default"] = "Botão direito para resetar"
L["Unknown"] = "Desconhecido"
L["Empty Slot %d"] = "Slot Vazio %d"
L["Spell ID..."] = "ID da Habilidade..."
L["Add"] = "Adicionar"
L["Secondary Group"] = "Grupo Secundário"
L["Tertiary Group"] = "Grupo Terciário"
L["Border:"] = "Borda:"
L["Enable Glow"] = "Ativar Brilho"
L["Glow Color:"] = "Cor do Brilho:"
L["No specialization detected!"] = "Nenhuma especialização detectada!"
L["Please enter a valid spell ID!"] = "Por favor, digite um ID deHabilidade válido!"
L["Spell ID %d does not exist!"] = "O ID da Habilidade %d não existe!"
L["Category full (max 7 spells)"] = "Categoria cheia (máx. 7 Habilidades)"
L["Icons"] = "Ícones"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ImportExport.lua
-----------------------------------------------------------------------

L["Serialization failed: %s"] = "Falha na serialização: %s"
L["Compression failed: %s"] = "Falha na compressão: %s"
L["Base64 encoding failed: %s"] = "Falha no encoding Base64: %s"
L["No import string provided"] = "Nenhuma string de importação fornecida"
L["Invalid Base64 encoding"] = "Encoding de Base64 inválido"
L["Decompression failed"] = "Falha na descompressão"
L["Invalid profile data"] = "Dados de perfil inválidos"
L["Missing profile metadata"] = "Metadados do perfil faltando"
L["Profile is for a different addon: %s"] = "O perfil é de outro addon: %s"
L["Invalid profile version"] = "Versão do perfil inválida"
L["Failed to import profile"] = "Erro ao importar perfil"
L["Imported %d settings as '%s'"] = "%d configurações importadas como '%s'"
L["Export Profile"] = "Exportar Perfil"
L["Select categories to include, then click Export."] = "Escolha as categorias e clique em Exportar."
L["Export"] = "Exportar"
L["Export String (Ctrl+C to copy):"] = "String de Exportação (Ctrl+C para copiar):"
L["Profile exported! Copy the string above."] = "Perfil exportado! Copie o código acima."
L["Export failed."] = "Falha ao exportar."
L["Import Profile"] = "Importar Perfil"
L["Paste an export string below and click Import."] = "Cole a string abaixo e clique em Importar."
L["Import"] = "Importar"
L["Clear"] = "Limpar"
L["Import/Export"] = "Importar/Exportar"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Profiles.lua
-----------------------------------------------------------------------

L["Current Profile"] = "Perfil Atual"
L["New Profile"] = "Novo Perfil"
L["Create"] = "Criar"
L["Enter a name"] = "Dê um nome"
L["Already exists"] = "Já existe"
L["Copy From"] = "Copiar de"
L["Copy all settings from another profile into the current one."] = "Copia as configurações de outro perfil para o atual."
L["Select Source..."] = "Escolher Origem..."
L["Manage"] = "Gerenciar"
L["Rename"] = "Renomear"
L["Reset Profile"] = "Resetar Perfil"
L["Delete Profile..."] = "Excluir Perfil..."
L["Default Profile for New Characters"] = "Perfil Padrão para Novos Personagens"
L["Specialization Profiles"] = "Perfis por Especialização"
L["Auto-switch profile per specialization"] = "Trocar perfil automaticamente ao mudar de spec"
L["Spec %d"] = "Spec %d"
L["Profiles"] = "Perfis"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "Adicionar Habilidade ou Item Personalizado"
L["Spell"] = "Habilidade"
L["Item"] = "Item"
L["Enter a valid ID"] = "Insira um ID válido"
L["Loading item data, try again"] = "Carregando dados do item, tente de novo"
L["Unknown spell ID"] = "ID de Habilidade desconhecido"
L["Added: %s"] = "Adicionado: %s"
L["Already tracked"] = "Já está sendo rastreado"
L["Enable Racials"] = "Ativar Raciais"
L["Tracked Spells"] = "Habilidades Rastreadas"
L["Manage Spells"] = "Gerenciar Habilidades"
L["Icon Size"] = "Tamanho do Ícone"
L["Icon Width"] = "Largura do Ícone"
L["Icon Height"] = "Altura do Ícone"
L["Party Frame Anchoring"] = "Fixar no Quadro do grupo"
L["Anchor to Party Frame"] = "Fixar no Quadro do grupo"
L["Side (relative to Party Frame)"] = "Lado (relativo ao Quadro de Grupo)"
L["Party Frame X Offset"] = "Ajuste X do Quadro de grupo"
L["Party Frame Y Offset"] = "Ajuste Y do Quadro de grupo"
L["Anchor Position (relative to Player Frame)"] = "Âncora (relativo ao Quadro do Personagem)"
L["Cooldown"] = "Cooldown"
L["Stacks"] = "Stacks"
L["Text Position"] = "Posição do Texto"
L["Text X Offset"] = "Ajuste X do Texto"
L["Text Y Offset"] = "Ajuste Y do Texto"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Defensives.lua
-----------------------------------------------------------------------

L["Current Spec"] = "Especialização Atual"
L["Add Custom Spell"] = "Adicionar Habilidade Personalizada"
L["Spell ID"] = "ID da Habilidade"
L["Enter a valid spell ID"] = "Insira um ID de Habilidade válido"
L["Not available for spec"] = "Indisponível para esta especialização"
L["Enable Defensives"] = "Ativar Defensivos"
L["Hide tracked defensives from Essential/Utility viewers"] = "Esconder defensivos das abas Essencial/Utilitário"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Trinkets.lua
-----------------------------------------------------------------------

L["Independent"] = "Independente"
L["Append to Defensives"] = "Anexar aos Defensivos"
L["Append to Spells"] = "Anexar às Habilidades"
L["Row 1"] = "Linha 1"
L["Row 2"] = "Linha 2"
L["Start"] = "Início"
L["End"] = "Fim"
L["Enable Trinkets"] = "Ativar Trinkets"
L["Layout Mode"] = "Modo de Layout"
L["Display Mode"] = "Modo de Exibição"
L["Row"] = "Linha"
L["Position in Row"] = "Posição na Linha"
L["Show Passive Trinkets"] = "Mostrar Trinkets Passivos"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources.lua
-----------------------------------------------------------------------

L["Background"] = "Fundo"
L["Rage"] = "Raiva"
L["Energy"] = "Energia"
L["Focus"] = "Foco"
L["Astral Power"] = "Poder Astral"
L["Maelstrom"] = "Maelstrom"
L["Insanity"] = "Insanidade"
L["Fury"] = "Fúria"
L["Mana"] = "Mana"
L["Essence"] = "Essência"
L["Essence Recharging"] = "Essência Recarregando"
L["Combo Points"] = "Pontos de Combo"
L["Holy Power"] = "Poder Sagrado"
L["Soul Shards"] = "Fragmentos de Alma"
L["Soul Shards Partial"] = "Fragmentos de Alma Parciais"
L["Arcane Charges"] = "Cargas Arcanas"
L["Chi"] = "Chi"
L["Runic Power"] = "Poder Rúnico"
L["Runes Ready"] = "Runas Prontas"
L["Runes Recharging"] = "Runas Recarregando"
L["Soul Fragments"] = "Fragmentos de Alma"
L["Light (<30%)"] = "Leve (<30%)"
L["Moderate (30-60%)"] = "Moderado (30-60%)"
L["Heavy (>60%)"] = "Pesado (>60%)"
L["Enable Resources"] = "Ativar Recursos"
L["Bar Dimensions"] = "Dimensões da Barra"
L["Bar 1 Height"] = "Altura da Barra 1"
L["Bar 2 Height"] = "Altura da Barra 2"
L["Bar Width (0 = Auto)"] = "Largura da Barra (0 = Auto)"
L["Bar Spacing (Vertical)"] = "Espaçamento Vertical"
L["Unified Border (wrap all bars)"] = "Borda Unificada (envolve tudo)"
L["Move buffs down dynamically"] = "Mover buffs para baixo dinamicamente"
L["Show Mana Bar"] = "Mostrar Barra de Mana"
L["Display Mana as %"] = "Mostrar Mana em %"
L["Bar Texture:"] = "Textura da Barra:"
L["Select Texture..."] = "Escolher Textura..."
L["Background Texture:"] = "Textura de Fundo:"
L["Position Offsets"] = "Ajustes de Posição"
L["Power Type Colors"] = "Cores por Tipo de Poder"
L["Show All Colors"] = "Mostrar Todas as Cores"
L["Stagger uses threshold colors: "] = "Stagger usa cores de limite: "
L["Light"] = "Leve"
L["Moderate"] = "Moderado"
L["Heavy"] = "Pesado"
L["Warrior"] = "Guerreiro"
L["Paladin"] = "Paladino"
L["Hunter"] = "Caçador"
L["Rogue"] = "Ladino"
L["Priest"] = "Sacerdote"
L["Death Knight"] = "Cavaleiro da Morte"
L["Shaman"] = "Xamã"
L["Mage"] = "Mago"
L["Warlock"] = "Bruxo"
L["Monk"] = "Monge"
L["Druid"] = "Druida"
L["Demon Hunter"] = "Caçador de Demônios"
L["Evoker"] = "Evocador"
L["Tags (Power Value Text)"] = "Tags (Texto do Valor)"
L["Left"] = "Esquerda"
L["Center"] = "Centro"
L["Right"] = "Direita"
L["Bar %s"] = "Barra %s"
L["Enable %s Tag (current value)"] = "Ativar Tag %s (valor atual)"
L["%s Font Size"] = "Tamanho da Fonte %s"
L["%s Anchor:"] = "Âncora %s:"
L["%s Offset X"] = "Ajuste X %s"
L["%s Offset Y"] = "Ajuste Y %s"
L["%s Text Color"] = "Cor do Texto %s"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CustomBuffs.lua
-----------------------------------------------------------------------

L["ID: %s  |  Duration: %ss"] = "ID: %s  |  Duração: %ss"
L["Remove"] = "Remover"
L["Custom Timers"] = "Timers Personalizados"
L["Track spell casts and display custom buff icons alongside native buffs. Icons appear in the main buff container."] = "Rastreia Lançamentos e mostra ícones de buffs personalizados junto aos nativos no painel principal."
L["Add Tracked Spell"] = "Adicionar Habilidade rastreada"
L["Spell ID:"] = "ID da Habilidade:"
L["Duration (sec):"] = "Duração (seg):"
L["Add Spell"] = "Adicionar Habilidade"
L["Invalid spell ID"] = "ID de Habilidade inválido"
L["Enter a valid duration"] = "Dê uma duração válida"
L["Limit reached (9 max)"] = "Limite máximo (9)"
L["Added!"] = "Adicionado!"
L["Failed - invalid spell ID"] = "Falhou - ID da Habilidade inválido"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "Dimensões"
L["Bar Height"] = "Altura da Barra"
L["Bar Spacing"] = "Espaçamento das Barras"
L["Appearance"] = "Aparência"
L["Bar Color"] = "Cor da Barra"
L["Background Color"] = "Cor do Fundo"
L["Growth Direction:"] = "Direção de Crescimento:"
L["Down"] = "Para Baixo"
L["Up"] = "Para Cima"
L["Icon Position:"] = "Posição do Ícone:"
L["Hidden"] = "Oculto"
L["Icon-Bar Gap"] = "Espaço Ícone-Barra"
L["Dual Bar Mode (2 bars per row)"] = "Modo Barra Dupla (2 por linha)"
L["Show Buff Name"] = "Mostrar Nome do Buff"
L["Show Duration Text"] = "Mostrar Duração"
L["Show Stack Count"] = "Mostrar Stacks"
L["Notes"] = "Notas"
L["Border settings: see Borders tab"] = "Ajustes de borda: veja na aba Bordas"
L["Text styling (font size, color, offsets): see Text tab"] = "Estilo de texto (fonte, cor, posição): veja na aba Texto"
L["Position lock and X/Y controls: see Positions tab"] = "Trava de posição e ajustes X/Y: veja na aba Posições"
L["Bars"] = "Barras"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CastBar.lua
-----------------------------------------------------------------------

L["Enable Cast Bar"] = "Ativar Barra de Lançamento"
L["Hide Blizzard Cast Bar"] = "Esconder Barra de Lançamento da Blizzard"
L["Width (0 = Auto)"] = "Largura (0 = Auto)"
L["Spell Icon"] = "Ícone da Habilidade"
L["Show Spell Icon"] = "Mostrar Ícone da Habilidade"
L["Bar Texture"] = "Textura da Barra"
L["Use Blizzard Atlas Textures"] = "Usar Texturas Oficiais (Blizzard Atlas)"
L["Cast Color"] = "Cor do Lançamento"
L["Channel Color"] = "Cor do Canal"
L["Uninterruptible Color"] = "Cor de Habilidade ininterrupta"
L["Anchor to Resource Bars"] = "Fixar nas Barras de Recursos"
L["Y Spacing"] = "Espaçamento Y"
L["Lock Position"] = "Travar Posição"
L["Show Spell Name"] = "Mostrar Nome da Habilidade"
L["Name X Offset"] = "Ajuste X do Nome"
L["Name Y Offset"] = "Ajuste Y do Nome"
L["Show Timer"] = "Mostrar Temporizador "
L["Timer X Offset"] = "Ajuste X do Temporizador"
L["Timer Y Offset"] = "Ajuste Y do Temporizador"
L["Show Spark"] = "Mostrar Faísca (Spark)"
L["Empowered Stages"] = "Estágios Empoderados"
L["Wind Up Color"] = "Cor de Preparação"
L["Stage 1 Color"] = "Cor Estágio 1"
L["Stage 2 Color"] = "Cor Estágio 2"
L["Stage 3 Color"] = "Cor Estágio 3"
L["Stage 4 Color"] = "Cor Estágio 4"
L["Cast Bar"] = "Barra de Lançamento"