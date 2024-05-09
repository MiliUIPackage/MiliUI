do
    local addonId = ...
    local languageTable = DetailsFramework.Language.RegisterLanguage(addonId, "ptBR")
    local L = languageTable

------------------------------------------------------------
--[[Translation missing --]]
L["EXPORT"] = "Export"
--[[Translation missing --]]
L["EXPORT_CAST_COLORS"] = "Share Colors"
--[[Translation missing --]]
L["EXPORT_CAST_SOUNDS"] = "Share Sounds"
--[[Translation missing --]]
L["HIGHLIGHT_HOVEROVER"] = "Hover Over Highlight"
--[[Translation missing --]]
L["HIGHLIGHT_HOVEROVER_ALPHA"] = "Hover Over Highlight Alpha"
--[[Translation missing --]]
L["HIGHLIGHT_HOVEROVER_DESC"] = "Highlight effect when the mouse is over the nameplate."
--[[Translation missing --]]
L["IMPORT"] = "Import"
--[[Translation missing --]]
L["IMPORT_CAST_COLORS"] = "Import Colors"
--[[Translation missing --]]
L["IMPORT_CAST_SOUNDS"] = "Import Sounds"
L["OPTIONS_ALPHA"] = "Alpha"
L["OPTIONS_ALPHABYFRAME_ALPHAMULTIPLIER"] = "Multiplicador de transparência."
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_DEFAULT"] = "Default Transparency"
L["OPTIONS_ALPHABYFRAME_DEFAULT_DESC"] = "Quantidade de transparência aplicada a todos os componentes de uma única placa de identificação."
L["OPTIONS_ALPHABYFRAME_ENABLE_ENEMIES"] = "Ativar Para Inimigos"
L["OPTIONS_ALPHABYFRAME_ENABLE_ENEMIES_DESC"] = "Aplicar configurações de transparência para unidades inimigas."
L["OPTIONS_ALPHABYFRAME_ENABLE_FRIENDLY"] = "Habilitar para aliados"
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_ENABLE_FRIENDLY_DESC"] = "Apply Transparency settings to friendly units."
L["OPTIONS_ALPHABYFRAME_TARGET_INRANGE"] = "Alvo Alpha/Alcance"
L["OPTIONS_ALPHABYFRAME_TARGET_INRANGE_DESC"] = "Transparência para unidades que estão no alcance ou são o alvo."
L["OPTIONS_ALPHABYFRAME_TITLE_ENEMIES"] = "Quantidade de transparência por quadro (inimigos)"
L["OPTIONS_ALPHABYFRAME_TITLE_FRIENDLY"] = "Quantidade de Transparência por Quadro (amigável)"
L["OPTIONS_AMOUNT"] = "Quantidade"
L["OPTIONS_ANCHOR"] = "Fixar"
L["OPTIONS_ANCHOR_BOTTOM"] = "Inferior"
L["OPTIONS_ANCHOR_BOTTOMLEFT"] = "Inferior Esquerdo"
L["OPTIONS_ANCHOR_BOTTOMRIGHT"] = "Inferior Direito"
L["OPTIONS_ANCHOR_CENTER"] = "Centro"
L["OPTIONS_ANCHOR_INNERBOTTOM"] = "Interno Inferior"
L["OPTIONS_ANCHOR_INNERLEFT"] = "Interno Esquerdo"
L["OPTIONS_ANCHOR_INNERRIGHT"] = "Interno Direita"
L["OPTIONS_ANCHOR_INNERTOP"] = "Interno Superior"
L["OPTIONS_ANCHOR_LEFT"] = "Esquerda"
L["OPTIONS_ANCHOR_RIGHT"] = "Direita"
--[[Translation missing --]]
L["OPTIONS_ANCHOR_TARGET_SIDE"] = "Which side this widget is attach to."
L["OPTIONS_ANCHOR_TOP"] = "Superior"
L["OPTIONS_ANCHOR_TOPLEFT"] = "Superior Esquerdo"
L["OPTIONS_ANCHOR_TOPRIGHT"] = "Superior Direito"
L["OPTIONS_AURA_DEBUFF_HEIGHT"] = "Altura do Ícone de Debuff."
L["OPTIONS_AURA_DEBUFF_WITH"] = "Largura do ícone da penalidade."
--[[Translation missing --]]
L["OPTIONS_AURA_HEIGHT"] = "Debuff's icon height."
--[[Translation missing --]]
L["OPTIONS_AURA_SHOW_BUFFS"] = "Show Buffs"
--[[Translation missing --]]
L["OPTIONS_AURA_SHOW_BUFFS_DESC"] = "Show buffs on you on the Personal Bar."
--[[Translation missing --]]
L["OPTIONS_AURA_SHOW_DEBUFFS"] = "Show Debuffs"
--[[Translation missing --]]
L["OPTIONS_AURA_SHOW_DEBUFFS_DESC"] = "Show debuffs on you on the Personal Bar."
--[[Translation missing --]]
L["OPTIONS_AURA_WIDTH"] = "Debuff's icon width."
L["OPTIONS_AURAS_ENABLETEST"] = "Habilitar para ocultar as auras de teste mostradas durante a configuração."
L["OPTIONS_AURAS_SORT"] = "Classificar Auras"
L["OPTIONS_AURAS_SORT_DESC"] = "As auras são ordenadas pelo tempo restante (padrão)."
L["OPTIONS_BACKGROUND_ALWAYSSHOW"] = "Sempre Mostrar Fundo"
L["OPTIONS_BACKGROUND_ALWAYSSHOW_DESC"] = "Ativar um fundo que mostra a área da área clicável."
--[[Translation missing --]]
L["OPTIONS_BORDER_COLOR"] = "Border Color"
--[[Translation missing --]]
L["OPTIONS_BORDER_THICKNESS"] = "Border Thickness"
L["OPTIONS_BUFFFRAMES"] = "Quadros de Buff"
L["OPTIONS_CANCEL"] = "Cancelar"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_CHANNELING"] = "Channelled"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_INTERRUPTED"] = "Interrupted"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_REGULAR"] = "Regular"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_SUCCESS"] = "Success"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_UNINTERRUPTIBLE"] = "Uninterruptible"
--[[Translation missing --]]
L["OPTIONS_CAST_SHOW_TARGETNAME"] = "Show Target Name"
--[[Translation missing --]]
L["OPTIONS_CAST_SHOW_TARGETNAME_DESC"] = "Show who is the target of the current cast (if the target exists)"
--[[Translation missing --]]
L["OPTIONS_CAST_SHOW_TARGETNAME_TANK"] = "[Tank] Don't Show Your Name"
--[[Translation missing --]]
L["OPTIONS_CAST_SHOW_TARGETNAME_TANK_DESC"] = "If you are a tank don't show the target name if the cast is on you."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_APPEARANCE"] = "Cast Bar Appearance"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_BLIZZCASTBAR"] = "Blizzard Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_COLORS"] = "Cast Bar Colors"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_ENABLED"] = "Enable Fade Animations"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_ENABLED_DESC"] = "Enable fade animations when the cast starts and stop."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_END"] = "On Stop"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_END_DESC"] = "When a cast ends, this is the amount of time the cast bar takes to go from 100% transparency to not be visible at all."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_START"] = "On Start"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_START_DESC"] = "When a cast starts, this is the amount of time the cast bar takes to go from zero transparency to full opaque."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_HEIGHT"] = "Height of the cast bar."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_HIDE_ENEMY"] = "Hide Enemy Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_HIDE_FRIENDLY"] = "Hide Friendly Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_HIDEBLIZZARD"] = "Hide Blizzard Player Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_ICON_CUSTOM_ENABLE"] = "Enable Icon Customization"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_ICON_CUSTOM_ENABLE_DESC"] = "If this option is disabled, Plater won't modify the spell icon, leaving it for scripts to do."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_NO_SPELLNAME_LIMIT"] = "No Spell Name Length Limitation"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_NO_SPELLNAME_LIMIT_DESC"] = "Spell name text won't be cut to fit within the cast bar width."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_QUICKHIDE"] = "Quick Hide Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_QUICKHIDE_DESC"] = "After the cast finishes, immediately hide the cast bar."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPARK_HALF"] = "Half Spark"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPARK_HALF_DESC"] = "Show only half of the spark texture."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPARK_HIDE_INTERRUPT"] = "Hide Spark On Interrupt"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPARK_SETTINGS"] = "Spark Settings"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPELLICON"] = "Spell Icon"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_TOGGLE_TEST"] = "Toggle Cast Bar Test"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_TOGGLE_TEST_DESC"] = "Start cast bar test, press again to stop."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_WIDTH"] = "Width of the cast bar."
--[[Translation missing --]]
L["OPTIONS_CASTCOLORS_DISABLECOLORS"] = "Disable All Colors"
L["OPTIONS_CLICK_SPACE_HEIGHT"] = "A altura da área que aceita cliques do mouse para selecionar o alvo."
L["OPTIONS_CLICK_SPACE_WIDTH"] = "A largura da área que aceita cliques do mouse para selecionar o alvo"
L["OPTIONS_COLOR"] = "Cores"
--[[Translation missing --]]
L["OPTIONS_COLOR_BACKGROUND"] = "Background Color"
L["OPTIONS_CVAR_ENABLE_PERSONAL_BAR"] = "Barras de Vida e Mana Pessoais|cFFFF7700|r"
L["OPTIONS_CVAR_ENABLE_PERSONAL_BAR_DESC"] = [=[Mostra barras de saúde e mana miniaturas abaixo do seu personagem.

    |cFFFF7700[*]|r |cFFa0a0a0CVar, salvo dentro do perfil Plater e restaurado ao carregar o perfil.|r]=]
L["OPTIONS_CVAR_NAMEPLATES_ALWAYSSHOW"] = "Mostrar Sempre Placas de Identificação|cFFFF7700|r"
L["OPTIONS_CVAR_NAMEPLATES_ALWAYSSHOW_DESC"] = [=[Mostra as placas de identificação para todas as unidades próximas. Se desativado, mostra apenas unidades relevantes quando você está em combate.

    |cFFFF7700[*]|r |cFFa0a0a0CVar, salvo no perfil do Plater e restaurado ao carregar o perfil.|r]=]
L["OPTIONS_ENABLED"] = "Habilitar"
L["OPTIONS_ERROR_CVARMODIFY"] = "cvars não podem ser alterados durante o combate."
L["OPTIONS_ERROR_EXPORTSTRINGERROR"] = "Falha ao exportar"
L["OPTIONS_EXECUTERANGE"] = "Alcance de Execução"
--[[Translation missing --]]
L["OPTIONS_EXECUTERANGE_DESC"] = [=[Show an indicator when the target unit is in 'execute' range.

If the detection does not work after a patch, communicate at Discord.]=]
L["OPTIONS_EXECUTERANGE_HIGH_HEALTH"] = "Alcance de Execução (alta cura)"
L["OPTIONS_EXECUTERANGE_HIGH_HEALTH_DESC"] = [=[Mostrar o indicador de execução para a parte alta da vida.

Se a detecção não funcionar após uma atualização, comunique no Discord.]=]
L["OPTIONS_FONT"] = "Fonte"
L["OPTIONS_FORMAT_NUMBER"] = "Formato de Número"
L["OPTIONS_FRIENDLY"] = "Amigável"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_ANCHOR_TITLE"] = "Aparência da Barra de Vida"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_BGCOLOR"] = "Barra de Vida: cor de fundo e Alpha"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_BGTEXTURE"] = "Barra de Vida: Textura de Fundo"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_TEXTURE"] = "Barra de Vida: Textura"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_ANCHOR_TITLE"] = "Transparência é Usada Para"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_RANGECHECK"] = "Verificação de Alcance"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_RANGECHECK_ALPHA"] = "Alpha"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_RANGECHECK_SPEC_DESC"] = "Feitiço para verificação de alcance nesta especialização."
L["OPTIONS_HEALTHBAR"] = "Barra de Vida"
L["OPTIONS_HEALTHBAR_HEIGHT"] = "Altura da Barra de Vida"
L["OPTIONS_HEALTHBAR_SIZE_GLOBAL_DESC"] = [=[Altere o tamanho das placas de identificação do inimigo e do amigável para jogadores e PNJs em combate e fora de combate.

    Cada uma dessas opções pode ser alterada individualmente nas guias NPC Inimigo e Jogador Inimigo.]=]
L["OPTIONS_HEALTHBAR_WIDTH"] = "Largura da Barra de Vida"
--[[Translation missing --]]
L["OPTIONS_HEIGHT"] = "Height"
L["OPTIONS_HOSTILE"] = "Hostil"
L["OPTIONS_ICON_ELITE"] = "Ícone de Elite"
L["OPTIONS_ICON_ENEMYCLASS"] = "Ícone de Classe do Inimigo"
L["OPTIONS_ICON_ENEMYFACTION"] = "Ícone de Facção Inimiga"
L["OPTIONS_ICON_ENEMYSPEC"] = "Ícone de Especialização do Inimigo"
L["OPTIONS_ICON_FRIENDLY_SPEC"] = "Ícone de Especialização Amigável"
--[[Translation missing --]]
L["OPTIONS_ICON_FRIENDLYCLASS"] = "Friendly Class"
L["OPTIONS_ICON_FRIENDLYFACTION"] = "Ícone de Facção Amigável"
L["OPTIONS_ICON_PET"] = "Ícone de Mascote"
L["OPTIONS_ICON_QUEST"] = "Ícone de Missão"
L["OPTIONS_ICON_RARE"] = "Ícone de Raro"
--[[Translation missing --]]
L["OPTIONS_ICON_SHOW"] = "Show Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_SIDE"] = "Show Side"
--[[Translation missing --]]
L["OPTIONS_ICON_SIZE"] = "Show Size"
L["OPTIONS_ICON_WORLDBOSS"] = "Ícone de Chefe Mundial"
--[[Translation missing --]]
L["OPTIONS_ICONROWSPACING"] = "Icon Row Spacing"
L["OPTIONS_ICONSPACING"] = "Espaçamento do Ícone"
L["OPTIONS_INDICATORS"] = "Indicadores"
--[[Translation missing --]]
L["OPTIONS_INTERRUPT_FILLBAR"] = "Fill Cast Bar On Interrupt"
--[[Translation missing --]]
L["OPTIONS_INTERRUPT_SHOW_ANIM"] = "Play Interrupt Animation"
--[[Translation missing --]]
L["OPTIONS_INTERRUPT_SHOW_AUTHOR"] = "Show Interrupt Author"
--[[Translation missing --]]
L["OPTIONS_MINOR_SCALE_DESC"] = "Slightly adjust the size of nameplates when showing a minor unit (these units has a smaller nameplate by default)."
L["OPTIONS_MINOR_SCALE_HEIGHT"] = "Escala de Altura de Unidades Menores"
L["OPTIONS_MINOR_SCALE_WIDTH"] = "Escala de Largura de Unidades Menores"
L["OPTIONS_MOVE_HORIZONTAL"] = "Mover horizontalmente."
L["OPTIONS_MOVE_VERTICAL"] = "Mover verticalmente."
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_HIDE_FRIENDLY_HEALTH"] = "Hide Blizzard Health Bars|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_HIDE_FRIENDLY_HEALTH_DESC"] = [=[While in dungeons or raids, if friendly nameplates are enabled it'll show only the player name.
If any Plater module is disabled, this will affect these nameplates as well.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r

|cFFFF2200[*]|r |cFFa0a0a0A /reload may be required to take effect.|r]=]
L["OPTIONS_NAMEPLATE_OFFSET"] = "Ajuste levemente toda a placa de identificação."
L["OPTIONS_NAMEPLATE_SHOW_ENEMY"] = "Mostrar placas de identificação do Inimigo|cFFFF7700*|r"
L["OPTIONS_NAMEPLATE_SHOW_ENEMY_DESC"] = [=[Mostrar placa de identificação para unidades inimigas e neutras.

|cFFFF7700[]|r |cFFa0a0a0CVar, salva dentro do perfil do Plater e restaurada ao carregar o perfil.|r]=]
L["OPTIONS_NAMEPLATE_SHOW_FRIENDLY"] = "Mostrar placas de identificação Amigáveis|cFFFF7700*|r"
L["OPTIONS_NAMEPLATE_SHOW_FRIENDLY_DESC"] = [=[Mostrar placa de identificação para jogadores amigáveis.

|cFFFF7700[]|r |cFFa0a0a0CVar, salva dentro do perfil do Plater e restaurada ao carregar o perfil.|r]=]
L["OPTIONS_NAMEPLATES_OVERLAP"] = "Sobreposição de Placas de Identificação (V)|cFFFF7700*|r"
L["OPTIONS_NAMEPLATES_OVERLAP_DESC"] = [=[O espaço entre cada placa de identificação verticalmente quando as pilhas estão habilitadas.

|cFFFFFFFFPadrão: 1.10|r

|cFFFF7700[]|r |cFFa0a0a0CVar, salva dentro do perfil do Plater e restaurada ao carregar o perfil.|r

|cFFFFFF00Importante|r: Se você encontrar problemas com essa configuração, use:
|cFFFFFFFF/run SetCVar('nameplateOverlapV', '1.6')|r]=]
L["OPTIONS_NAMEPLATES_STACKING"] = "Pilhas de Placas de Identificação|cFFFF7700*|r"
L["OPTIONS_NAMEPLATES_STACKING_DESC"] = [=[Se ativado, as placas de identificação não se sobrepõem umas às outras.

    |cFFFF7700[*]|r |cFFa0a0a0CVar, salvo dentro do perfil do Plater e restaurado ao carregar o perfil.|r

    |cFFFFFF00Importante |r: para definir a quantidade de espaço entre cada placa de identificação, veja a opção '|cFFFFFFFFPreenchimento Vertical da Placa de Identificação|r' abaixo.
    Verifique as configurações da guia 'Auto' para configurar a alternância automática dessa opção.]=]
L["OPTIONS_NEUTRAL"] = "Neutro"
--[[Translation missing --]]
L["OPTIONS_NOCOMBATALPHA_AMOUNT_DESC"] = "Amount of transparency for 'No Combat Alpha'."
--[[Translation missing --]]
L["OPTIONS_NOCOMBATALPHA_ENABLED"] = "Use No Combat Alpha"
--[[Translation missing --]]
L["OPTIONS_NOCOMBATALPHA_ENABLED_DESC"] = [=[Changes the nameplate alpha when you are in combat and the unit isn't.

|cFFFFFF00 Important |r:If the unit isn't in combat, it overrides the alpha from the range check.]=]
--[[Translation missing --]]
L["OPTIONS_NOESSENTIAL_DESC"] = [=[On updating Plater, it is common for the new version to also update scripts from the scripts tab.
This may sometimes overwrite changes made by the creator of the profile. The option below prevents Plater from modifying scripts when the addon receives an update.

Note: During major patches and bug fixes, Plater may still update scripts.]=]
--[[Translation missing --]]
L["OPTIONS_NOESSENTIAL_NAME"] = "Disable non-essential script updates during Plater version upgrades."
--[[Translation missing --]]
L["OPTIONS_NOESSENTIAL_SKIP_ALERT"] = "Skipped non-essential patch:"
--[[Translation missing --]]
L["OPTIONS_NOESSENTIAL_TITLE"] = "Skip Non Essential Script Patches"
--[[Translation missing --]]
L["OPTIONS_NOTHING_TO_EXPORT"] = "There's nothing to export."
L["OPTIONS_OKAY"] = "OK"
L["OPTIONS_OUTLINE"] = "Contorno"
--[[Translation missing --]]
L["OPTIONS_PERSONAL_HEALTHBAR_HEIGHT"] = "Height of the health bar."
--[[Translation missing --]]
L["OPTIONS_PERSONAL_HEALTHBAR_WIDTH"] = "Width of the health bar."
--[[Translation missing --]]
L["OPTIONS_PERSONAL_SHOW_HEALTHBAR"] = "Show health bar."
L["OPTIONS_PET_SCALE_DESC"] = "Ajustar ligeiramente o tamanho das placas de identificação ao exibir um mascote"
L["OPTIONS_PET_SCALE_HEIGHT"] = "Escala de Altura do Pet"
L["OPTIONS_PET_SCALE_WIDTH"] = "Escala de Largura do Pet"
L["OPTIONS_PLEASEWAIT"] = "Isso pode levar alguns segundos"
L["OPTIONS_POWERBAR"] = "Barra de Poder"
--[[Translation missing --]]
L["OPTIONS_POWERBAR_HEIGHT"] = "Height of the power bar."
--[[Translation missing --]]
L["OPTIONS_POWERBAR_WIDTH"] = "Width of the power bar."
L["OPTIONS_PROFILE_CONFIG_EXPORTINGTASK"] = "Plater está exportando o perfil atual"
L["OPTIONS_PROFILE_CONFIG_EXPORTPROFILE"] = "Exportar Perfil"
L["OPTIONS_PROFILE_CONFIG_IMPORTPROFILE"] = "Importar Perfil"
L["OPTIONS_PROFILE_CONFIG_MOREPROFILES"] = "Obtenha mais perfis no Wago.io"
L["OPTIONS_PROFILE_CONFIG_OPENSETTINGS"] = "Abrir configurações de perfil"
L["OPTIONS_PROFILE_CONFIG_PROFILENAME"] = "Novo nome do perfil"
L["OPTIONS_PROFILE_CONFIG_PROFILENAME_DESC"] = "Um novo perfil é criado com a String importada.  Inserir o nome de um perfil que já existe o substituirá."
L["OPTIONS_PROFILE_ERROR_PROFILENAME"] = "Nome de perfil inválido"
L["OPTIONS_PROFILE_ERROR_STRINGINVALID"] = "Arquivo de perfil inválido."
L["OPTIONS_PROFILE_ERROR_WRONGTAB"] = "Arquivo de perfil inválido. Importe scripts ou mods na guia de scripts/mods."
L["OPTIONS_PROFILE_IMPORT_OVERWRITE"] = "O perfil '%s' já existe, Deseja substituir?"
L["OPTIONS_RANGECHECK_NONE"] = "Nada"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NONE_DESC"] = "No alpha modifications is applyed."
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGET"] = "Units Which Isn't Your Target"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGET_DESC"] = "When a nameplate isn't your current target, alpha is reduced."
L["OPTIONS_RANGECHECK_NOTMYTARGETOUTOFRANGE"] = "Fora do Alcance + Não é Seu Alvo"
L["OPTIONS_RANGECHECK_NOTMYTARGETOUTOFRANGE_DESC"] = [=[Reduz a transparência das unidades que não são seu alvo.
Reduz ainda mais se a unidade estiver fora de alcance.]=]
L["OPTIONS_RANGECHECK_OUTOFRANGE"] = "Unidades Fora do Seu Alcance"
L["OPTIONS_RANGECHECK_OUTOFRANGE_DESC"] = "Quando uma placa de identificação está fora de alcance, a transparência é reduzida."
L["OPTIONS_RESOURCES_TARGET"] = "Mostrar Recursos no Alvo"
L["OPTIONS_RESOURCES_TARGET_DESC"] = [=[Mostra seus recursos, como pontos de combo, acima do seu alvo atual.
    Usa os recursos padrão do Blizzard e desativa os recursos do Plater.

    Configuração específica do personagem!]=]
L["OPTIONS_SCALE"] = "Escala"
--[[Translation missing --]]
L["OPTIONS_SCRIPTING_REAPPLY"] = "Re-Apply Default Values"
L["OPTIONS_SETTINGS_COPIED"] = "configurações copiadas."
L["OPTIONS_SETTINGS_FAIL_COPIED"] = "falha ao obter as configurações da guia selecionada."
L["OPTIONS_SHADOWCOLOR"] = "Cor da Sombra"
L["OPTIONS_SHIELD_BAR"] = "Barra de Escudo"
--[[Translation missing --]]
L["OPTIONS_SHOW_CASTBAR"] = "Show cast bar"
--[[Translation missing --]]
L["OPTIONS_SHOW_POWERBAR"] = "Show power bar"
--[[Translation missing --]]
L["OPTIONS_SHOWOPTIONS"] = "Show Options"
--[[Translation missing --]]
L["OPTIONS_SHOWSCRIPTS"] = "Show Scripts"
--[[Translation missing --]]
L["OPTIONS_SHOWTOOLTIP"] = "Show Tooltip"
--[[Translation missing --]]
L["OPTIONS_SHOWTOOLTIP_DESC"] = "Show tooltip when hovering over the aura icon."
L["OPTIONS_SIZE"] = "Tamanho."
L["OPTIONS_STACK_AURATIME"] = "Mostrar o tempo mais curto das auras empilhadas"
L["OPTIONS_STACK_AURATIME_DESC"] = "Mostra o tempo mais curto das auras empilhadas ou o tempo mais longo, quando desativado."
L["OPTIONS_STACK_SIMILAR_AURAS"] = "Agrupar Auras Semelhantes"
--[[Translation missing --]]
L["OPTIONS_STACK_SIMILAR_AURAS_DESC"] = "Auras with the same name (e.g. warlock's unstable affliction debuff) get stacked together."
L["OPTIONS_STATUSBAR_TEXT"] = "Agora você pode importar perfis, mods, scripts, animações e tabelas de cores de |cFFFFAA00http://wago.io|r"
L["OPTIONS_TABNAME_ADVANCED"] = "Avançado"
L["OPTIONS_TABNAME_ANIMATIONS"] = "Feedback de feitiços"
L["OPTIONS_TABNAME_AUTO"] = "Automatizações"
L["OPTIONS_TABNAME_BUFF_LIST"] = "Lista de Feitiços"
L["OPTIONS_TABNAME_BUFF_SETTINGS"] = "Buff Config"
L["OPTIONS_TABNAME_BUFF_SPECIAL"] = "Buff Especiais"
L["OPTIONS_TABNAME_BUFF_TRACKING"] = "Rastreamento de Buff"
L["OPTIONS_TABNAME_CASTBAR"] = "Barra de Lançamento"
L["OPTIONS_TABNAME_CASTCOLORS"] = "Nomes e Cores de Cast"
L["OPTIONS_TABNAME_COMBOPOINTS"] = "Pontos de Combo"
L["OPTIONS_TABNAME_GENERALSETTINGS"] = "Config Gerais"
L["OPTIONS_TABNAME_MODDING"] = "Mods"
L["OPTIONS_TABNAME_NPC_COLORNAME"] = "Nomes e Cores de NPCs"
L["OPTIONS_TABNAME_NPCENEMY"] = "NPC Inimigo"
L["OPTIONS_TABNAME_NPCFRIENDLY"] = "NPC Amigo"
L["OPTIONS_TABNAME_PERSONAL"] = "Barra pessoal"
L["OPTIONS_TABNAME_PLAYERENEMY"] = "Jogador Inimigo"
L["OPTIONS_TABNAME_PLAYERFRIENDLY"] = "Jogador Amigo"
L["OPTIONS_TABNAME_PROFILES"] = "Perfis "
L["OPTIONS_TABNAME_SCRIPTING"] = "Scripts"
L["OPTIONS_TABNAME_SEARCH"] = "Pesquisar"
L["OPTIONS_TABNAME_STRATA"] = "Nível e estratos"
L["OPTIONS_TABNAME_TARGET"] = "Alvo"
L["OPTIONS_TABNAME_THREAT"] = "Cores / Aggro"
--[[Translation missing --]]
L["OPTIONS_TEXT_COLOR"] = "The color of the text."
--[[Translation missing --]]
L["OPTIONS_TEXT_FONT"] = "Font of the text."
--[[Translation missing --]]
L["OPTIONS_TEXT_SIZE"] = "Size of the text."
L["OPTIONS_TEXTURE"] = "Textura"
--[[Translation missing --]]
L["OPTIONS_TEXTURE_BACKGROUND"] = "Background Texture"
L["OPTIONS_THREAT_AGGROSTATE_ANOTHERTANK"] = "Aggro em outro Tank"
L["OPTIONS_THREAT_AGGROSTATE_HIGHTHREAT"] = "Ameaça alta"
L["OPTIONS_THREAT_AGGROSTATE_NOAGGRO"] = "Sem Aggro"
L["OPTIONS_THREAT_AGGROSTATE_NOTANK"] = "Sem Aggro nos Tanks"
L["OPTIONS_THREAT_AGGROSTATE_NOTINCOMBAT"] = "Unidade fora de combate"
L["OPTIONS_THREAT_AGGROSTATE_ONYOU_LOWAGGRO"] = "Aggro em você, mas é baixo"
L["OPTIONS_THREAT_AGGROSTATE_ONYOU_LOWAGGRO_DESC"] = "a unidade está atacando você, mas outros podem tomar o Aggro."
L["OPTIONS_THREAT_AGGROSTATE_ONYOU_SOLID"] = "Aggro em Você"
L["OPTIONS_THREAT_AGGROSTATE_TAPPED"] = "Unidade Perdida"
--[[Translation missing --]]
L["OPTIONS_THREAT_CLASSIC_USE_TANK_COLORS"] = "Use Tank Threat Colors"
L["OPTIONS_THREAT_COLOR_DPS_ANCHOR_TITLE"] = "Cor ao Jogar como DPS ou HEALER"
L["OPTIONS_THREAT_COLOR_DPS_HIGHTHREAT_DESC"] = "A unidade começa a atacar você."
L["OPTIONS_THREAT_COLOR_DPS_NOAGGRO_DESC"] = "A unidade não está atacando você."
L["OPTIONS_THREAT_COLOR_DPS_NOTANK_DESC"] = "A unidade não está atacando você ou outro tank e provavelmente está atacando o Healer ou dps do seu grupo."
L["OPTIONS_THREAT_COLOR_DPS_ONYOU_SOLID_DESC"] = "A unidade está atacando você."
L["OPTIONS_THREAT_COLOR_OVERRIDE_ANCHOR_TITLE"] = "Substituir cores padrão"
L["OPTIONS_THREAT_COLOR_OVERRIDE_DESC"] = "Modifique as cores padrão definidas pelo jogo para unidades neutras, hostis e amigáveis. Durante o combate, essas cores serão substituídas também se as cores de ameaça puderem mudar a cor da barra de saúde."
L["OPTIONS_THREAT_COLOR_TANK_ANCHOR_TITLE"] = "Cor ao Jogar como TANK"
L["OPTIONS_THREAT_COLOR_TANK_ANOTHERTANK_DESC"] = "A unidade está com outro tank do seu grupo."
L["OPTIONS_THREAT_COLOR_TANK_NOAGGRO_DESC"] = "A unidade não tem Aggro em você"
L["OPTIONS_THREAT_COLOR_TANK_NOTINCOMBAT_DESC"] = "A unidade não está em combate."
L["OPTIONS_THREAT_COLOR_TANK_ONYOU_SOLID_DESC"] = "A unidade está atacando você e você tem um aggro sólido."
L["OPTIONS_THREAT_COLOR_TAPPED_DESC"] = "Quando alguém reivindicou a unidade (quando você não recebe experiência ou pilhagem por matá-la)."
L["OPTIONS_THREAT_DPS_CANCHECKNOTANK"] = "Marque para Unidade sem Aggro no Tank"
L["OPTIONS_THREAT_DPS_CANCHECKNOTANK_DESC"] = "Quando você não tem aggro como curandeiro ou dps, verifique se o inimigo está atacando outra unidade que não é um tank."
L["OPTIONS_THREAT_MODIFIERS_ANCHOR_TITLE"] = "Modificações de Aggro"
L["OPTIONS_THREAT_MODIFIERS_BORDERCOLOR"] = "Cor de Borda"
L["OPTIONS_THREAT_MODIFIERS_HEALTHBARCOLOR"] = "Cor da Barra de Vida"
L["OPTIONS_THREAT_MODIFIERS_NAMECOLOR"] = "Cor do Nome"
--[[Translation missing --]]
L["OPTIONS_THREAT_PULL_FROM_ANOTHER_TANK"] = "Pulling From Another Tank"
--[[Translation missing --]]
L["OPTIONS_THREAT_PULL_FROM_ANOTHER_TANK_TANK"] = "The unit has aggro on another tank and you're about to pull it."
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_AGGRO_FLASH"] = "Enable aggro flash"
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_AGGRO_FLASH_DESC"] = "Enables the -AGGRO- flash animation on the nameplates when gaining aggro as dps."
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_AGGRO_GLOW"] = "Enable aggro glow"
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_AGGRO_GLOW_DESC"] = "Enables the healthbar glow on the nameplates when gaining aggro as dps or losing aggro as tank."
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_SOLO_COLOR"] = "Solo Color"
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_SOLO_COLOR_DESC"] = "Use the 'Solo' color when not in a group."
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_SOLO_COLOR_ENABLE"] = "Use 'Solo' color"
--[[Translation missing --]]
L["OPTIONS_TOGGLE_TO_CHANGE"] = "|cFFFFFF00 Important |r: hide and show nameplates to see changes."
--[[Translation missing --]]
L["OPTIONS_WIDTH"] = "Width"
L["OPTIONS_XOFFSET"] = "Deslocamento horizontal"
--[[Translation missing --]]
L["OPTIONS_XOFFSET_DESC"] = [=[Adjust the position on the X axis.

*right click to type the value.]=]
L["OPTIONS_YOFFSET"] = "Deslocamento vertical"
--[[Translation missing --]]
L["OPTIONS_YOFFSET_DESC"] = [=[Adjust the position on the Y axis.

*right click to type the value.]=]
--[[Translation missing --]]
L["TARGET_CVAR_ALWAYSONSCREEN"] = "Target Always on the Screen|cFFFF7700*|r"
--[[Translation missing --]]
L["TARGET_CVAR_ALWAYSONSCREEN_DESC"] = [=[When enabled, the nameplate of your target is always shown even when the enemy isn't in the screen.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
--[[Translation missing --]]
L["TARGET_CVAR_LOCKTOSCREEN"] = "Lock to Screen (Top Side)|cFFFF7700*|r"
--[[Translation missing --]]
L["TARGET_CVAR_LOCKTOSCREEN_DESC"] = [=[Min space between the nameplate and the top of the screen. Increase this if some part of the nameplate are going out of the screen.

|cFFFFFFFFDefault: 0.065|r

|cFFFFFF00 Important |r: if you're having issue, manually set using these macros:
/run SetCVar ('nameplateOtherTopInset', '0.065')
/run SetCVar ('nameplateLargeTopInset', '0.065')

|cFFFFFF00 Important |r: setting to 0 disables this feature.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
--[[Translation missing --]]
L["TARGET_HIGHLIGHT"] = "Target Highlight"
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_ALPHA"] = "Target Highlight Alpha"
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_COLOR"] = "Target Highlight Color"
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_DESC"] = "Highlight effect on the nameplate of your current target."
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_SIZE"] = "Target Highlight Size"
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_TEXTURE"] = "Target Highlight Texture"
--[[Translation missing --]]
L["TARGET_OVERLAY_ALPHA"] = "Target Overlay Alpha"
--[[Translation missing --]]
L["TARGET_OVERLAY_TEXTURE"] = "Target Overlay Texture"
--[[Translation missing --]]
L["TARGET_OVERLAY_TEXTURE_DESC"] = "Used above the health bar when it is the current target."

end