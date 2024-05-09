do
    local addonId = ...
    local languageTable = DetailsFramework.Language.RegisterLanguage(addonId, "esES")
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
L["HIGHLIGHT_HOVEROVER_DESC"] = "Efecto de resaltado cuando el ratón está sobre la placa."
--[[Translation missing --]]
L["IMPORT"] = "Import"
--[[Translation missing --]]
L["IMPORT_CAST_COLORS"] = "Import Colors"
--[[Translation missing --]]
L["IMPORT_CAST_SOUNDS"] = "Import Sounds"
L["OPTIONS_ALPHA"] = "Alfa"
L["OPTIONS_ALPHABYFRAME_ALPHAMULTIPLIER"] = "Multiplicador de transparencia."
L["OPTIONS_ALPHABYFRAME_DEFAULT"] = "Transparencia por defecto"
L["OPTIONS_ALPHABYFRAME_DEFAULT_DESC"] = "Cantidad de transparencia aplicada a todos los componentes de una misma placa."
L["OPTIONS_ALPHABYFRAME_ENABLE_ENEMIES"] = "Activar para enemigos"
L["OPTIONS_ALPHABYFRAME_ENABLE_ENEMIES_DESC"] = "Aplica ajustes de transparencia a las unidades enemigas."
L["OPTIONS_ALPHABYFRAME_ENABLE_FRIENDLY"] = "Activar para amistosos"
L["OPTIONS_ALPHABYFRAME_ENABLE_FRIENDLY_DESC"] = "Aplica los ajustes de transparencia a las unidades amistosas."
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_TARGET_INRANGE"] = "Target Alpha/In-Range"
L["OPTIONS_ALPHABYFRAME_TARGET_INRANGE_DESC"] = "Transparencia para objetivos o unidades al alcance."
L["OPTIONS_ALPHABYFRAME_TITLE_ENEMIES"] = "Cantidad de transparencia por fotograma (enemigos)"
L["OPTIONS_ALPHABYFRAME_TITLE_FRIENDLY"] = "Cantidad de transparencia por fotograma (amistosos)"
L["OPTIONS_AMOUNT"] = "Cantidad"
L["OPTIONS_ANCHOR"] = "Anclaje"
L["OPTIONS_ANCHOR_BOTTOM"] = "Abajo"
L["OPTIONS_ANCHOR_BOTTOMLEFT"] = "Abajo a la izquierda"
L["OPTIONS_ANCHOR_BOTTOMRIGHT"] = "Abajo a la derecha"
L["OPTIONS_ANCHOR_CENTER"] = "Centro"
L["OPTIONS_ANCHOR_INNERBOTTOM"] = "Abajo por dentro"
L["OPTIONS_ANCHOR_INNERLEFT"] = "Izquierda por dentro"
L["OPTIONS_ANCHOR_INNERRIGHT"] = "Derecha por dentro"
L["OPTIONS_ANCHOR_INNERTOP"] = "Arriba por dentro"
L["OPTIONS_ANCHOR_LEFT"] = "Izquierda"
L["OPTIONS_ANCHOR_RIGHT"] = "Derecha"
L["OPTIONS_ANCHOR_TARGET_SIDE"] = "A qué lado se coloca este widget."
L["OPTIONS_ANCHOR_TOP"] = "Arriba"
L["OPTIONS_ANCHOR_TOPLEFT"] = "Arriba a la izquierda"
L["OPTIONS_ANCHOR_TOPRIGHT"] = "Arriba a la derecha"
L["OPTIONS_AURA_DEBUFF_HEIGHT"] = "Altura del icono del perjuicio."
L["OPTIONS_AURA_DEBUFF_WITH"] = "Anchura del icono del perjuicio."
L["OPTIONS_AURA_HEIGHT"] = "Altura del icono del perjuicio."
L["OPTIONS_AURA_SHOW_BUFFS"] = "Mostrar beneficios"
L["OPTIONS_AURA_SHOW_BUFFS_DESC"] = "Mostrar beneficios que te afectan en la barra personal."
L["OPTIONS_AURA_SHOW_DEBUFFS"] = "Mostrar perjuicios"
L["OPTIONS_AURA_SHOW_DEBUFFS_DESC"] = "Mostrar perjuicios que te afectan en la barra personal."
L["OPTIONS_AURA_WIDTH"] = "Anchura del icono del perjuicio."
L["OPTIONS_AURAS_ENABLETEST"] = "Activa esta opción para ocultar las auras de prueba que se muestran al configurar."
L["OPTIONS_AURAS_SORT"] = "Ordenar auras"
L["OPTIONS_AURAS_SORT_DESC"] = "Las auras se ordenan por tiempo restante (por defecto)."
L["OPTIONS_BACKGROUND_ALWAYSSHOW"] = "Mostrar siempre el fondo"
L["OPTIONS_BACKGROUND_ALWAYSSHOW_DESC"] = "Activa un fondo que muestra la zona del área clicable."
L["OPTIONS_BORDER_COLOR"] = "Color del borde"
L["OPTIONS_BORDER_THICKNESS"] = "Grosor del borde"
L["OPTIONS_BUFFFRAMES"] = "Marcos de beneficios"
L["OPTIONS_CANCEL"] = "Cancelar"
L["OPTIONS_CAST_COLOR_CHANNELING"] = "Canalizado"
L["OPTIONS_CAST_COLOR_INTERRUPTED"] = "Interrumpido"
L["OPTIONS_CAST_COLOR_REGULAR"] = "Normal"
L["OPTIONS_CAST_COLOR_SUCCESS"] = "Exitoso"
L["OPTIONS_CAST_COLOR_UNINTERRUPTIBLE"] = "Ininterrumpible"
L["OPTIONS_CAST_SHOW_TARGETNAME"] = "Mostrar nombre del objetivo"
L["OPTIONS_CAST_SHOW_TARGETNAME_DESC"] = "Muestra quién es el objetivo del lanzamiento actual (si el objetivo existe)"
L["OPTIONS_CAST_SHOW_TARGETNAME_TANK"] = "[Tanque] No muestres tu nombre"
L["OPTIONS_CAST_SHOW_TARGETNAME_TANK_DESC"] = "Si eres un tanque no muestres el nombre del objetivo si el lanzamiento es sobre ti."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_APPEARANCE"] = "Cast Bar Appearance"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_BLIZZCASTBAR"] = "Blizzard Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_COLORS"] = "Cast Bar Colors"
L["OPTIONS_CASTBAR_FADE_ANIM_ENABLED"] = "Activar animaciones de fundido"
L["OPTIONS_CASTBAR_FADE_ANIM_ENABLED_DESC"] = "Activa las animaciones de fundido cuando el lanzamiento se inicia y se detiene."
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_END"] = "Al parar"
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_END_DESC"] = "Cuando finaliza un lanzamiento, este es el tiempo que tarda la barra de lanzamiento en pasar del 100% de transparencia a no ser visible en absoluto."
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_START"] = "Al empezar"
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_START_DESC"] = "Cuando se inicia un lanzamiento, este es el tiempo que tarda la barra de lanzamiento en pasar de transparencia cero a totalmente opaca."
L["OPTIONS_CASTBAR_HEIGHT"] = "Altura de la barra de lanzamiento."
L["OPTIONS_CASTBAR_HIDE_ENEMY"] = "Ocultar la barra de lanzamiento de enemigos"
L["OPTIONS_CASTBAR_HIDE_FRIENDLY"] = "Ocultar la barra de lanzamiento de amistosos"
L["OPTIONS_CASTBAR_HIDEBLIZZARD"] = "Ocultar la barra de lanzamiento del jugador de Blizzard"
L["OPTIONS_CASTBAR_ICON_CUSTOM_ENABLE"] = "Activar la personalización de iconos"
L["OPTIONS_CASTBAR_ICON_CUSTOM_ENABLE_DESC"] = "Si esta opción está desactivada, Plater no modificará el icono del hechizo, dejando que lo hagan los scripts."
L["OPTIONS_CASTBAR_NO_SPELLNAME_LIMIT"] = "Sin límite de longitud del nombre del hechizo"
L["OPTIONS_CASTBAR_NO_SPELLNAME_LIMIT_DESC"] = "El texto del nombre del hechizo no se cortará para que quepa en el ancho de la barra de lanzamiento."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_QUICKHIDE"] = "Quick Hide Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_QUICKHIDE_DESC"] = "After the cast finishes, immediately hide the cast bar."
L["OPTIONS_CASTBAR_SPARK_HALF"] = "Media chispa"
L["OPTIONS_CASTBAR_SPARK_HALF_DESC"] = "Muestra solo la mitad de la textura de la chispa."
L["OPTIONS_CASTBAR_SPARK_HIDE_INTERRUPT"] = "Ocultar chispa al interrumpir"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPARK_SETTINGS"] = "Spark Settings"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPELLICON"] = "Spell Icon"
L["OPTIONS_CASTBAR_TOGGLE_TEST"] = "Activar la barra de lanzamiento de prueba"
L["OPTIONS_CASTBAR_TOGGLE_TEST_DESC"] = "Inicia la prueba de la barra de lanzamiento, pulsa de nuevo para detenerla."
L["OPTIONS_CASTBAR_WIDTH"] = "Anchura de la barra de lanzamiento."
--[[Translation missing --]]
L["OPTIONS_CASTCOLORS_DISABLECOLORS"] = "Disable All Colors"
L["OPTIONS_CLICK_SPACE_HEIGHT"] = "La altura del área que acepta clics del ratón para seleccionar al objetivo"
L["OPTIONS_CLICK_SPACE_WIDTH"] = "La anchura del área que acepta clics del ratón para seleccionar al objetivo"
L["OPTIONS_COLOR"] = "Color"
L["OPTIONS_COLOR_BACKGROUND"] = "Color de fondo"
L["OPTIONS_CVAR_ENABLE_PERSONAL_BAR"] = "Barras personales de salud y maná|cFFFF7700*|r"
L["OPTIONS_CVAR_ENABLE_PERSONAL_BAR_DESC"] = "Muestra una mini barra de salud y maná debajo de tu personaje. |cFFFF7700[*]|r |cFFa0a0a0CVar, guardada dentro del perfil de Plater y restaurada al cargar el perfil.|r"
L["OPTIONS_CVAR_NAMEPLATES_ALWAYSSHOW"] = "Mostrar siempre las placas|cFFFF7700*|r"
L["OPTIONS_CVAR_NAMEPLATES_ALWAYSSHOW_DESC"] = "Muestra las placas de todas las unidades cercanas. Si se desactiva, solo muestra las unidades relevantes cuando estás en combate. |cFFFF7700[*]|r |cFFa0a0CVar, guardada dentro del perfil de Plater y restaurada cuando se carga el perfil.|r"
L["OPTIONS_ENABLED"] = "Activadas"
L["OPTIONS_ERROR_CVARMODIFY"] = "Los cvars no se pueden cambiar en combate."
L["OPTIONS_ERROR_EXPORTSTRINGERROR"] = "error al exportar"
L["OPTIONS_EXECUTERANGE"] = "Rango de ejecución"
L["OPTIONS_EXECUTERANGE_DESC"] = "Mostrar un indicador cuando la unidad objetivo está en el rango de \"ejecución\". Si la detección no funciona tras un parche, comunícalo en Discord."
--[[Translation missing --]]
L["OPTIONS_EXECUTERANGE_HIGH_HEALTH"] = "Execute Range (high heal)"
--[[Translation missing --]]
L["OPTIONS_EXECUTERANGE_HIGH_HEALTH_DESC"] = [=[Show the execute indicator for the high portion of the health.

If the detection does not work after a patch, communicate at Discord.]=]
L["OPTIONS_FONT"] = "Fuente"
--[[Translation missing --]]
L["OPTIONS_FORMAT_NUMBER"] = "Number Format"
L["OPTIONS_FRIENDLY"] = "Amistoso"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_ANCHOR_TITLE"] = "Apariencia de barra de salud"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_BGCOLOR"] = "Color de fondo y Alfa de Barra de salud "
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_BGTEXTURE"] = "Textura de fondo de barra de salud"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_TEXTURE"] = "Textura de barra de salud"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_ANCHOR_TITLE"] = "La transparencia se utiliza para"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_RANGECHECK"] = "Comprobación de rango"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_RANGECHECK_ALPHA"] = "Alfa"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_RANGECHECK_SPEC_DESC"] = "Hechizo para comprobar el alcance de esta especialización."
--[[Translation missing --]]
L["OPTIONS_HEALTHBAR"] = "Health Bar"
--[[Translation missing --]]
L["OPTIONS_HEALTHBAR_HEIGHT"] = "Health Bar Height"
--[[Translation missing --]]
L["OPTIONS_HEALTHBAR_SIZE_GLOBAL_DESC"] = [=[Change the size of Enemy and Friendly nameplates for players and npcs in combat and out of combat.

Each one of these options can be changed individually on Enemy Npc, Enemy Player tabs.]=]
--[[Translation missing --]]
L["OPTIONS_HEALTHBAR_WIDTH"] = "Health Bar Width"
--[[Translation missing --]]
L["OPTIONS_HEIGHT"] = "Height"
L["OPTIONS_HOSTILE"] = "Hostil"
--[[Translation missing --]]
L["OPTIONS_ICON_ELITE"] = "Elite Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_ENEMYCLASS"] = "Enemy Class Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_ENEMYFACTION"] = "Enemy Faction Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_ENEMYSPEC"] = "Enemy Spec Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_FRIENDLY_SPEC"] = "Friendly Spec Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_FRIENDLYCLASS"] = "Friendly Class"
--[[Translation missing --]]
L["OPTIONS_ICON_FRIENDLYFACTION"] = "Friendly Faction Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_PET"] = "Pet Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_QUEST"] = "Quest Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_RARE"] = "Rare Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_SHOW"] = "Show Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_SIDE"] = "Show Side"
--[[Translation missing --]]
L["OPTIONS_ICON_SIZE"] = "Show Size"
--[[Translation missing --]]
L["OPTIONS_ICON_WORLDBOSS"] = "World Boss Icon"
--[[Translation missing --]]
L["OPTIONS_ICONROWSPACING"] = "Icon Row Spacing"
--[[Translation missing --]]
L["OPTIONS_ICONSPACING"] = "Icon Spacing"
--[[Translation missing --]]
L["OPTIONS_INDICATORS"] = "Indicators"
--[[Translation missing --]]
L["OPTIONS_INTERRUPT_FILLBAR"] = "Fill Cast Bar On Interrupt"
--[[Translation missing --]]
L["OPTIONS_INTERRUPT_SHOW_ANIM"] = "Play Interrupt Animation"
--[[Translation missing --]]
L["OPTIONS_INTERRUPT_SHOW_AUTHOR"] = "Show Interrupt Author"
--[[Translation missing --]]
L["OPTIONS_MINOR_SCALE_DESC"] = "Slightly adjust the size of nameplates when showing a minor unit (these units has a smaller nameplate by default)."
--[[Translation missing --]]
L["OPTIONS_MINOR_SCALE_HEIGHT"] = "Minor Unit Height Scale"
--[[Translation missing --]]
L["OPTIONS_MINOR_SCALE_WIDTH"] = "Minor Unit Width Scale"
--[[Translation missing --]]
L["OPTIONS_MOVE_HORIZONTAL"] = "Move horizontally."
--[[Translation missing --]]
L["OPTIONS_MOVE_VERTICAL"] = "Move vertically."
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_HIDE_FRIENDLY_HEALTH"] = "Hide Blizzard Health Bars|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_HIDE_FRIENDLY_HEALTH_DESC"] = [=[While in dungeons or raids, if friendly nameplates are enabled it'll show only the player name.
If any Plater module is disabled, this will affect these nameplates as well.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r

|cFFFF2200[*]|r |cFFa0a0a0A /reload may be required to take effect.|r]=]
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_OFFSET"] = "Slightly adjust the entire nameplate."
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_SHOW_ENEMY"] = "Show Enemy Nameplates|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_SHOW_ENEMY_DESC"] = [=[Show nameplate for enemy and neutral units.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_SHOW_FRIENDLY"] = "Show Friendly Nameplates|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_SHOW_FRIENDLY_DESC"] = [=[Show nameplate for friendly players.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
--[[Translation missing --]]
L["OPTIONS_NAMEPLATES_OVERLAP"] = "Nameplate Overlap (V)|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATES_OVERLAP_DESC"] = [=[The space between each nameplate vertically when stacking is enabled.

|cFFFFFFFFDefault: 1.10|r

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r

|cFFFFFF00Important |r: if you find issues with this setting, use:
|cFFFFFFFF/run SetCVar ('nameplateOverlapV', '1.6')|r]=]
--[[Translation missing --]]
L["OPTIONS_NAMEPLATES_STACKING"] = "Stacking Nameplates|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATES_STACKING_DESC"] = [=[If enabled, nameplates won't overlap with each other.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r

|cFFFFFF00Important |r: to set the amount of space between each nameplate see '|cFFFFFFFFNameplate Vertical Padding|r' option below.
Please check the Auto tab settings to setup automatic toggling of this option.]=]
L["OPTIONS_NEUTRAL"] = "Neutral"
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
L["OPTIONS_OKAY"] = "Okay"
L["OPTIONS_OUTLINE"] = "Contorno"
--[[Translation missing --]]
L["OPTIONS_PERSONAL_HEALTHBAR_HEIGHT"] = "Height of the health bar."
--[[Translation missing --]]
L["OPTIONS_PERSONAL_HEALTHBAR_WIDTH"] = "Width of the health bar."
--[[Translation missing --]]
L["OPTIONS_PERSONAL_SHOW_HEALTHBAR"] = "Show health bar."
--[[Translation missing --]]
L["OPTIONS_PET_SCALE_DESC"] = "Slightly adjust the size of nameplates when showing a pet"
--[[Translation missing --]]
L["OPTIONS_PET_SCALE_HEIGHT"] = "Pet Height Scale"
--[[Translation missing --]]
L["OPTIONS_PET_SCALE_WIDTH"] = "Pet Width Scale"
L["OPTIONS_PLEASEWAIT"] = "Esto puede tomar solo unos segundos"
--[[Translation missing --]]
L["OPTIONS_POWERBAR"] = "Power Bar"
--[[Translation missing --]]
L["OPTIONS_POWERBAR_HEIGHT"] = "Height of the power bar."
--[[Translation missing --]]
L["OPTIONS_POWERBAR_WIDTH"] = "Width of the power bar."
L["OPTIONS_PROFILE_CONFIG_EXPORTINGTASK"] = "Plater está exportando el perfil actual"
L["OPTIONS_PROFILE_CONFIG_EXPORTPROFILE"] = "Exportar Perfil"
L["OPTIONS_PROFILE_CONFIG_IMPORTPROFILE"] = "Importar Perfil"
L["OPTIONS_PROFILE_CONFIG_MOREPROFILES"] = "Obtenga más perfiles en Wago.io"
L["OPTIONS_PROFILE_CONFIG_OPENSETTINGS"] = "Abrir configuración de Perfil"
L["OPTIONS_PROFILE_CONFIG_PROFILENAME"] = "Nuevo nombre de perfil"
L["OPTIONS_PROFILE_CONFIG_PROFILENAME_DESC"] = "Un nuevo perfil se creó con la cadena importada. Insertar el nombre de un perfil que ya existe lo sobrescribirá."
L["OPTIONS_PROFILE_ERROR_PROFILENAME"] = "Nombre de perfil inválido"
L["OPTIONS_PROFILE_ERROR_STRINGINVALID"] = "Archivo de perfil inválido."
L["OPTIONS_PROFILE_ERROR_WRONGTAB"] = "Archivo de perfil inválido. Importa scripts o mods en la pestaña de scripts."
L["OPTIONS_PROFILE_IMPORT_OVERWRITE"] = "El perfil '%s' ya existe, ¿sobrescribirlo?"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NONE"] = "Nothing"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NONE_DESC"] = "No alpha modifications is applyed."
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGET"] = "Units Which Isn't Your Target"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGET_DESC"] = "When a nameplate isn't your current target, alpha is reduced."
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGETOUTOFRANGE"] = "Out of Range + Isn't Your Target"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGETOUTOFRANGE_DESC"] = [=[Reduces the alpha of units which isn't your target.
Reduces even more if the unit is out of range.]=]
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_OUTOFRANGE"] = "Units Out of Your Range"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_OUTOFRANGE_DESC"] = "When a nameplate is out of range, alpha is reduced."
--[[Translation missing --]]
L["OPTIONS_RESOURCES_TARGET"] = "Show Resources on Target"
--[[Translation missing --]]
L["OPTIONS_RESOURCES_TARGET_DESC"] = [=[Shows your resource such as combo points above your current target.
Uses Blizzard default resources and disables Platers own resources.

Character specific setting!]=]
--[[Translation missing --]]
L["OPTIONS_SCALE"] = "Scale"
--[[Translation missing --]]
L["OPTIONS_SCRIPTING_REAPPLY"] = "Re-Apply Default Values"
L["OPTIONS_SETTINGS_COPIED"] = "ajustes copiados."
L["OPTIONS_SETTINGS_FAIL_COPIED"] = "no se pudo obtener la configuración de la pestaña seleccionada actual."
L["OPTIONS_SHADOWCOLOR"] = "Color de la sombra"
--[[Translation missing --]]
L["OPTIONS_SHIELD_BAR"] = "Shield Bar"
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
L["OPTIONS_SIZE"] = "Tamaño"
--[[Translation missing --]]
L["OPTIONS_STACK_AURATIME"] = "Show shortest time of stacked auras"
--[[Translation missing --]]
L["OPTIONS_STACK_AURATIME_DESC"] = "Show shortest time of stacked auras or the longes time, when disabled."
--[[Translation missing --]]
L["OPTIONS_STACK_SIMILAR_AURAS"] = "Stack Similar Auras"
--[[Translation missing --]]
L["OPTIONS_STACK_SIMILAR_AURAS_DESC"] = "Auras with the same name (e.g. warlock's unstable affliction debuff) get stacked together."
L["OPTIONS_STATUSBAR_TEXT"] = "Ahora puede importar perfiles, modificaciones, scripts, animaciones y tablas de colores desde |cFFFFAA00http://wago.io|r"
L["OPTIONS_TABNAME_ADVANCED"] = "Avanzado"
L["OPTIONS_TABNAME_ANIMATIONS"] = "Animaciones"
L["OPTIONS_TABNAME_AUTO"] = "Automático"
L["OPTIONS_TABNAME_BUFF_LIST"] = "Lista de beneficios"
L["OPTIONS_TABNAME_BUFF_SETTINGS"] = "Configuración de beneficios"
L["OPTIONS_TABNAME_BUFF_SPECIAL"] = "Beneficios Especiales"
L["OPTIONS_TABNAME_BUFF_TRACKING"] = "Seguimiento de beneficios"
L["OPTIONS_TABNAME_CASTBAR"] = "Barra de lanzamiento"
L["OPTIONS_TABNAME_CASTCOLORS"] = "Colores y nombres de lanzamientos"
L["OPTIONS_TABNAME_COMBOPOINTS"] = "Puntos de Combo"
L["OPTIONS_TABNAME_GENERALSETTINGS"] = "Configuración general"
L["OPTIONS_TABNAME_MODDING"] = "Modding"
L["OPTIONS_TABNAME_NPC_COLORNAME"] = "Colores y Nombres de NPC"
L["OPTIONS_TABNAME_NPCENEMY"] = "PNJ Enemigo"
L["OPTIONS_TABNAME_NPCFRIENDLY"] = "PNJ Amistoso"
L["OPTIONS_TABNAME_PERSONAL"] = "Barra Personal"
L["OPTIONS_TABNAME_PLAYERENEMY"] = "Jugador Enemigo"
L["OPTIONS_TABNAME_PLAYERFRIENDLY"] = "Jugador Amistoso"
L["OPTIONS_TABNAME_PROFILES"] = "Perfiles"
L["OPTIONS_TABNAME_SCRIPTING"] = "Scripting"
L["OPTIONS_TABNAME_SEARCH"] = "Buscar"
L["OPTIONS_TABNAME_STRATA"] = "Nivel y Capas"
L["OPTIONS_TABNAME_TARGET"] = "Objetivo"
L["OPTIONS_TABNAME_THREAT"] = "Amenaza / Aggro"
--[[Translation missing --]]
L["OPTIONS_TEXT_COLOR"] = "The color of the text."
--[[Translation missing --]]
L["OPTIONS_TEXT_FONT"] = "Font of the text."
--[[Translation missing --]]
L["OPTIONS_TEXT_SIZE"] = "Size of the text."
L["OPTIONS_TEXTURE"] = "Textura"
--[[Translation missing --]]
L["OPTIONS_TEXTURE_BACKGROUND"] = "Background Texture"
L["OPTIONS_THREAT_AGGROSTATE_ANOTHERTANK"] = "Aggro en Otro Tanque"
L["OPTIONS_THREAT_AGGROSTATE_HIGHTHREAT"] = "Amenaza alta"
L["OPTIONS_THREAT_AGGROSTATE_NOAGGRO"] = "Sin Aggro"
L["OPTIONS_THREAT_AGGROSTATE_NOTANK"] = "Sin Aggro de Tanque"
L["OPTIONS_THREAT_AGGROSTATE_NOTINCOMBAT"] = "Unidad sin combate"
L["OPTIONS_THREAT_AGGROSTATE_ONYOU_LOWAGGRO"] = "Aggro en ti pero es bajo"
L["OPTIONS_THREAT_AGGROSTATE_ONYOU_LOWAGGRO_DESC"] = "La unidad te está atacando, pero otros están a punto de pasar de aggro."
L["OPTIONS_THREAT_AGGROSTATE_ONYOU_SOLID"] = "Aggro en Tí"
L["OPTIONS_THREAT_AGGROSTATE_TAPPED"] = "Unidad Golpeada"
--[[Translation missing --]]
L["OPTIONS_THREAT_CLASSIC_USE_TANK_COLORS"] = "Use Tank Threat Colors"
L["OPTIONS_THREAT_COLOR_DPS_ANCHOR_TITLE"] = "Color al jugar como DPS o HEALER"
L["OPTIONS_THREAT_COLOR_DPS_HIGHTHREAT_DESC"] = "La unidad está por comenzar a atacarte."
L["OPTIONS_THREAT_COLOR_DPS_NOAGGRO_DESC"] = "La unidad no te está atacando."
L["OPTIONS_THREAT_COLOR_DPS_NOTANK_DESC"] = "La unidad no te está atacando a ti ni a un tanque y lo más probable es que esté atacando a otro sanador o dps de tu grupo."
L["OPTIONS_THREAT_COLOR_DPS_ONYOU_SOLID_DESC"] = "La unidad te está atacando."
L["OPTIONS_THREAT_COLOR_OVERRIDE_ANCHOR_TITLE"] = "Anular colores predeterminados"
L["OPTIONS_THREAT_COLOR_OVERRIDE_DESC"] = "Modifique los colores predeterminados establecidos por el juego para unidades neutrales, hostiles y amistosas. Durante el combate, estos colores también se anularán si se permite que los colores de amenaza cambien el color de la barra de salud."
L["OPTIONS_THREAT_COLOR_TANK_ANCHOR_TITLE"] = "Color al jugar como TANQUE"
L["OPTIONS_THREAT_COLOR_TANK_ANOTHERTANK_DESC"] = "La unidad está siendo tanqueada por otro tanque en su grupo."
L["OPTIONS_THREAT_COLOR_TANK_NOAGGRO_DESC"] = "La unidad no tiene aggro en tí."
L["OPTIONS_THREAT_COLOR_TANK_NOTINCOMBAT_DESC"] = "La unidad no está en combate."
L["OPTIONS_THREAT_COLOR_TANK_ONYOU_SOLID_DESC"] = "La unidad te está atacando y tienes un aggro sólido."
L["OPTIONS_THREAT_COLOR_TAPPED_DESC"] = "Cuando alguien más ha reclamado la unidad (cuando no recibes experiencia o botín por matarla)."
L["OPTIONS_THREAT_DPS_CANCHECKNOTANK"] = "Comprobar si no hay aggro de tanque"
L["OPTIONS_THREAT_DPS_CANCHECKNOTANK_DESC"] = "Cuando no tienes aggro como sanador o dps, verifica si el enemigo está atacando a otra unidad que no es un tanque."
L["OPTIONS_THREAT_MODIFIERS_ANCHOR_TITLE"] = "Modificadores de Amenaza"
L["OPTIONS_THREAT_MODIFIERS_BORDERCOLOR"] = "Color del borde"
L["OPTIONS_THREAT_MODIFIERS_HEALTHBARCOLOR"] = "Color de barra de salud"
L["OPTIONS_THREAT_MODIFIERS_NAMECOLOR"] = "Nombre de color"
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
L["OPTIONS_XOFFSET"] = "Vértice X"
--[[Translation missing --]]
L["OPTIONS_XOFFSET_DESC"] = [=[Adjust the position on the X axis.

*right click to type the value.]=]
L["OPTIONS_YOFFSET"] = "Vértice Y"
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