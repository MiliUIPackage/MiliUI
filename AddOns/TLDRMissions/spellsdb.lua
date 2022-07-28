local addonName = "TLDRMissions"
local addon = _G[addonName]

addon.spellsDB = {
    [4] = { -- Nadjia strikes the closest enemy twice, dealing a $s1 and then $s2 Physical damage.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 75,
            affectedByTaunt = true,
        },
        [2] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 50,
            affectedByTaunt = true,
        },
    },
    [5] = { -- Draven sweeps his wings, dealing $s1 Physical damage to all enemies.
        target = "all_enemies",
        type = "attack",
        attackPercent = 10,
    },
    [6] = { -- Theotar pulses with shadow, dealing $s1 Shadow damage to all enemies at range.
      target = "back_enemies",
      type = "attack",
      attackPercent = 60,
    },
    [7] = { -- Deals $s1 Physical damage to the closest enemy.
      target = "closest_enemy",
      type = "attack",
      attackPercent = 10,
    },
    [8] = { --  Eli strikes as swiftly as a hawk, dealing damage to the closest enemy.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 100, -- appears to be unobtainable
    },
    [9] = { -- Heal all allies for $s1% of their maximum health.
      target = "all_allies",
      type = "heal",
      healTargetHPPercent = 5,
      skipIfFull = true,
    },
    [10] = { -- Smashes the closest enemy for $s1% of their maximum hit points. Each turn, heals for $s3% of maximum health and deals $s2% maximum health Frost damage to all enemies.
      [1] = {
          target = "closest_enemy",
          type = "attack",
          damageTargetHPPercent = 20,
        },
      [2] = {
          type = "buff",
          target = "all_enemies",
          duration = 3,
          damageTargetHPPercent = 3,
          event = "beforeAttack",
          buffName = "Starbranch Crush (AOE)",
        },
      [3] = {
          type = "buff",
          target = "self",
          duration = 3,
          healTargetHPPercent = 1,
          event = "beforeAttack",
          buffName = "Starbranch Crush (Heal)",
        },
    },
    [11] = { -- Deal attack damage to the closest enemy.
      target = "closest_enemy",
      type = "attack",
      attackPercent = 100,
    },
    [12] = { -- Heals all allies for $s1.
      target = "all_allies",
      type = "heal",
      healPercent = 20,
    },
    [14] = { -- Anjali heals all allies for $s1.
        target = "all_allies",
        type = "heal",
        healPercent = 20, -- appears to be unobtainable
    },
    [15] = { -- Deal damage to an enemy at range.
      target = "furthest_enemy",
      type = "attack",
      attackPercent = 100,
    },
    [16] = { -- Thela rips a memory from the farthest enemy, dealing $s1 Shadow damage.
      target = "furthest_enemy",
      type = "attack",
      attackPercent = 75,
    },
    [17] = { -- Dug tosses a shovelful of Grave Dirt at all enemies, dealing $s1 Frost damage and healing himself for $s2.
        [1] = {
            target = "all_enemies",
            type = "attack",
            attackPercent = 10,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 100,
        },
    }, -- Nerith strikes all enemies in melee range three times, each strike dealing $s1 Shadow damage.
    [18] = {
        [1] = {
            target = "front_enemies",
            type = "attack",
            attackPercent = 20,
        },
        [2] = {
            target = "front_enemies",
            type = "attack",
            attackPercent = 20,
        },
        [3] = {
            target = "front_enemies",
            type = "attack",
            attackPercent = 20,
        },
    },
    [19] = { --  Bite the closest enemy with jaws of flame, dealing $s1 Fire damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [20] = { -- Stonehuck hurls a Sinstone which shatters and deals $s1 Physical damage to all enemies at range.
        target = "back_enemies",
        type = "attack",
        attackPercent = 70,
    },
    [21] = { -- Kaletar heals all allies for $s1.
        type = "buff",
        target = "all_allies",
        duration = 4,
        event = "beforeAttack",
        healPercent = 25,
        buffName = "Spirits of Rejuvenation",
        stackLimit = 1,

        skipIfFull = true,
    },
    [22] = { -- Ayeleth drains the anima from all adjacent enemies, dealing $s1 Shadow damage and an additional $s2 damage each round.
        [1] = {
            type = "attack",
            target = "cleave_enemies",
            attackPercent = 90,
            affectedByTaunt = true,
        },
        [2] = {
            type = "buff",
            target = "cleave_enemies",
            attackPercent = 10,
            duration = 2,
            event = "beforeAttack",
            buffName = "Unrelenting Hunger",
            affectedByTaunt = true,

        }
    },
    [24] = { -- Teliah empowers her spear, dealing $s1 Holy damage to the farthest enemy and healing the closest ally for $s2.
      [1] = {
          target = "furthest_enemy",
          type = "attack",
          attackPercent = 180,
        },
      [2] = {
          target = "closest_ally",
          type = "heal",
          healPercent = 20,
        },
    },
    [25] = { -- Kythekios punches all enemies in melee in rapid succession, dealing $s1 Holy damage to them and empowering himself to deal $s2% additional damage.
      [1] = {
          target = "front_enemies",
          type = "attack",
          attackPercent = 50,
        },
      [2] = {
          type = "buff",
          target = "self",
          duration = 3,
          changeDamageDealtPercent = 20,
          buffName = "Whirling Fists",
        },
    },
    [26] = { -- Telethakas pours a potion down the throat of the closest ally, healing them for $s1 and increasing their maximum health by $s2.
      [1] = {
            target = "nearby_ally_or_self",
            type = "heal",
            healPercent = 100,
        },
      [2] = {
            target = "nearby_ally_or_self",
            type = "buff",
            changeMaxHPUsingAttack = 20,
            duration = 2,
            buffName = "Physiker's Potion",
        },
    },
    [43] = { -- Siphons anima from the farthest enemy into yourself, dealing $s1 Shadow damage and healing for $s2.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 25,
            cancelIfNoTargets = true,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 20,
        },
    },
    [44] = { -- Stabs the closest enemy twice, dealing $s1 Physical damage with the first knife and and $s2 with the second.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 50,
            continueIfCasterDies = true,
            affectedByTaunt = true,
        },
        [2] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 25,
            affectedByTaunt = true,
        },
    },
    [45] = { -- Deals $s1 Arcane damage to the farthest enemy and heals themself for $s2.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 75,
            affectedByTaunt = true,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 25,
        },
    },
    [46] = { -- The Phalanx takes 10% reduced damage and protects all ranged allies in the same way.
        [1] = {
            target = "self",
            type = "buff",
            duration = 1,
            changeDamageTakenPercent = -10,
            buffName = "Shield of Tomorrow (Main)",
        },
        [2] = {
            target = "back_allies_exclude_self",
            type = "buff",
            duration = 1,
            changeDamageTakenPercent = -10,
            buffName = "Shield of Tomorrow (Alt)",

        },
    },
    [47] = { -- Draven's wingspan shields himself and all allies, reducing all damage taken by 20%.
        target = "all_allies",
        type = "passive",
        changeDamageTakenPercent = -20,
        buffName = "Protective Aura",
        roundFirst = true,
    },
    [48] = { -- Nadjia becomes untargetable and heals herself for $s2.
        [1] = {
            target = "self",
            type = "buff",
            shroud = true,
            duration = 1,
            buffName = "Shadow Walk",
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 20,
        },
    },
    [49] = { -- Theotar rips the blood from all enemies at range, increasing the damage they take by $s1%.
        target = "back_enemies",
        type = "buff",
        duration = 4,
        changeDamageTakenPercent = 33,
        buffName = "Exsanguination",

    },
    [50] = { -- The Halberdier slices their weapon at the farthest enemy, dealing $s1 Physical damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 120,
        affectedByTaunt = true,
    },
    [51] = { -- Whirls in place, dealing $s1 Shadow damage to all enemies in melee.
      target = "front_enemies",
      type = "attack",
      attackPercent = 75,
    },
    [52] = { -- Scream at enemies at range, inflicting $s1 Nature damage each round for 4 rounds.
        target = "back_enemies",
        type = "attack",
        attackPercent = 30,
    },
    [53] = { -- Winding tendrils ensnare all enemies, dealing $s1 Nature damage and reducing their damage by 20% every other round.
        [1] = {
            type = "attack",
            target = "all_enemies",
            attackPercent = 10,
        },
        [2] = {
            type = "buff",
            target = "all_enemies",
            changeDamageDealtPercent = -20,
            duration = 6,
            buffName = "Winding Tendrils",
            alternateTurns = true,
            event = "endTurn",
        },
    },
    [54] = { -- Rahel cheerfully slices the closest enemy and hurls a dagger at the farthest enemy, dealing $s1 Shadow damage to both.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 90,
            affectedByTaunt = true,
            continueIfCasterDies = true,
        },
        [2] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 90,
            affectedByTaunt = true,
        },
    },
    [55] = { -- Stonehead smiles and politely smashes all enemies in melee for $s1 Physical damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 150,
    },
    [56] = { -- Simone wields her mirror with precision, dealing $s1 Arcane damage to the farthest enemy.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 125,
        affectedByTaunt = true,
    },
    [57] = { -- Bogdan reminds the nearest enemy of their manners, dealing $s1 Shadow damage for the next three turns.
        type = "buff",
        attackPercent = 100,
        target = "closest_enemy",
        duration = 3,
        event = "beforeAttack",
        buffName = "Etiquette Lesson",

    },
    [58] = { -- Lost Sybille smashes the heads of all adjacent enemies together, dealing $s1 Physical damage.
        target = "cleave_enemies",
        type = "attack",
        attackPercent = 70,
        affectedByTaunt = true,
    },
    [59] = { -- Vulca invokes the power of loss, dealing $s1 Arcane damage to all enemies at range.
        target = "back_enemies",
        type = "attack",
        attackPercent = 50,
    },
    [60] = { -- Spits acid at the farthest enemy, dealing $s1 Nature damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 40,
    },
    [61] = { -- Smashes the closest enemy, dealing $s1 Nature damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 75,
    },
    [62] = { -- Stabs all enemies in melee with their antlers, dealing $s1 Nature damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 30,
    },
    [63] = { -- Shrieks loudly, dealing $s1 Nature damage to all enemies and causing them to deal $s2% less damage for two rounds.
        [1] = {
            type = "attack",
            target = "all_enemies",
            attackPercent = 60,
        },
        [2] = {
            type = "buff",
            target = "all_enemies",
            duration = 2,
            changeDamageDealtPercent = -20,
            buffName = "Sonic Shriek",

        },
    },
    [64] = { -- Slams his carapace into the ground, dealing $s1 Nature damage to all enemies.
        target = "all_enemies",
        type = "attack",
        attackPercent = 150,
    },
    [65] = { -- Gnaws at the closest enemy, dealing $s1 Shadow damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 75, -- UNCONFIRMED
    },
    [66] = { -- Slams a nearby enemy, dealing $s1 Shadow damage to them and an enemy behind them.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [67] = { -- Leap in the air and strike the farthest enemy with a spear of shadow, dealing $s1 Shadow damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 75, -- UNCONFIRMED
    },
    [68] = { -- Strike all enemies in melee, dealing $s1 Holy damage and reducing their damage by $s2%.
        target = "front_enemies",
        type = "attack",
        attackPercent = 20, -- UNCONFIRMED
    },
    [71] = { -- Heals the closest ally for $s1.
        target = "nearby_ally_or_self",
        type = "heal",
        healPercent = 100,
        skipIfFull = true,
    },
    [72] = { -- Hala strikes the closest enemy for $s1 Holy damage. The force of the blow generates a secondary shockwave, dealing $s2 Holy damage to all enemies at range.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 200,
        },
        [2] = {
            target = "back_enemies",
            type = "attack",
            attackPercent = 40,
        },
    },
    [73] = { -- Molako purifies all enemies in a line, dealing $s1 Holy damage.
        target = "line",
        type = "attack",
        attackPercent = 100,
    },
    [74] = { -- Ispiron reconfigures, reallocating resources to protect himself, reducing all damage taken and dealt by 40% for 3 rounds.
        [1] = {
            type = "buff",
            changeDamageTakenPercent = -40,
            target = "self",
            duration = 3,
            buffName = "Ispiron (damage taken)",
        },
        [2] = {
            type = "buff",
            target = "self",
            duration = 3,
            buffName = "Ispiron (damage dealt)",
            changeDamageDealtPercent = -40,
        },
    },
    [75] = { -- Nemea enlists a Larion friend to leap into battle, dealing $s1 Physical damage to the farthest enemy.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [76] = { -- Pelodis enlists a Phalynx to charge into battle, dealing $s1 Holy damage to the farthest enemy.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 225,
    },
    [77] = { -- Sika dishes out potions to the party, increasing their Damage by $s1 Holy for 3 rounds.
        target = "all_allies",
        type = "buff",
        changeDamageDealtUsingAttack = 20,
        duration = 3,
        buffName = "Potions of Penultimate Power",

    },
    [78] = { -- Clora cleaves all enemies in melee, dealing $s1 Holy damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 30,
        affectedByTaunt = true,
    },
    [79] = { -- Kosmas erupts in light, dealing $s1 Holy damage to all enemies and healing allies for $s2.
        [1] = {
            target = "all_enemies",
            type = "attack",
            attackPercent = 20,
            continueIfCasterDies = true,
        },
        [2] = {
            target = "all_allies",
            type = "heal",
            healPercent = 20,
        },
    },
    [80] = { -- Apolon's light ignites the farthest enemy, dealing $s1 Fire damage and $s2 Fire damage for the next 2 rounds.
        [1] = {
            type = "attack",
            target = "furthest_enemy",
            attackPercent = 120,
        },
        [2] = {
            type = "buff",
            target = "furthest_enemy",
            duration = 2,
            attackPercent = 40,
            event = "beforeAttack",
            buffName = "Dawnshock",

        },
    },
    [81] = { -- Bron reconfigures, wreathing himself in bands of light that deal $s1 Holy damage to all who attack him for the next 3 rounds.
        target = "self",
        type = "buff",
        duration = 3,
        thorns = 100,
        buffName = "Reconfiguration: Reflect",

    },
    [82] = { -- Kleia's determination (and mace) make enemies pay dearly, dealing $s1 Physical damage to any who attack her.
        target = "self",
        type = "passive",
        thorns = 25,
        buffName = "Mace to Hand",
    },
    [83] = { -- Kleia charges into battle, dealing $s1 Physical damage to all adjacent enemies.
        target = "cleave_enemies",
        type = "attack",
        attackPercent = 120,
        affectedByTaunt = true,
    },
    [84] = { -- Mikanikos dazzles all enemies for two rounds, reducing their damage by 100%. Does not cast at the start of battle.
        type = "buff",
        firstTurn = 3,
        target = "all_enemies",
        duration = 2,
        changeDamageDealtPercent = -100,
        buffName = "Sparkling Driftglobe Core",
    },
    [85] = { -- Mikanikos enhances the durability of the closest ally, reducing the damage they take by 50% for two rounds.
        type = "buff",
        firstTurn = 2,
        target = "nearby_ally_or_self",
        duration = 2,
        changeDamageTakenPercent = -50,
        buffName = "Resilient Plumage",
        makeImmuneMathErrors = true,
    },
    [87] = { -- Pelagos faces his fears and hurls light in the face of his foes, dealing $s1 Holy damage to all enemies at range.
        target = "back_enemies",
        type = "attack",
        attackPercent = 60,
    },
    [88] = { -- Pelagos meditates, increasing his damage by 30% and inflicting a Sorrowful Memory on all enemies, dealing $s2 Holy damage.
        [1] = {
            target = "self",
            type = "buff",
            duration = 3,
            changeDamageDealtPercent = 30,
            buffName = "Combat Meditation",
        },
        [2] = {
            target = "all_enemies",
            type = "attack",
            attackPercent = 40,
        },
    },
    [89] = { -- Niya's Burr Trap deals $s1 Nature damage to the furthest enemy each turn for 2 turns.
        [2] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 40,
            ignoreThorns = true,
        },
        [1] = {
            type = "buff",
            attackPercent = 40,
            target = "furthest_enemy",
            duration = 2,
            buffName = "Spiked Burr Trap",
            event = "beforeAttack",

        },
    },
    [90] = { -- Niya invigorates adjacent allies, increasing all damage they deal by 20%.
        target = "adjacent_allies",
        type = "passive",
        changeDamageDealtPercent = 20,
        buffName = "Invigorating Herbs",
    },
    [91] = { -- Blisswing modifies the damage of the furthest enemy by $s1 for 3 rounds.
        target = "furthest_enemy",
        type = "buff",
        changeDamageDealtUsingAttack = -60,
        duration = 3,
        buffName = "Dazzledust",

    },
    [92] = { -- Duskleaf deals $s1 Shadow damage to all enemies at range for 2 rounds.
        [2] = {
            type = "attack",
            target = "back_enemies",
            attackPercent = 50,
            ignoreThorns = true,
        },
        [1] = { -- switching order to match combatlog, even though this shouldnt functionally change anything
            type = "buff",
            attackPercent = 50,
            target = "back_enemies",
            duration = 2,
            event = "beforeAttack",
            buffName = "Trickster's Torment",

        },
    },
    [93] = { -- Karynmwylyann draws strength from the closest enemy, dealing $s1 Nature damage and healing himself for $s2.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 20,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 80,
        },
    },
    [94] = { -- Chalkyth slashes all enemies in melee with his spear and implants an Icespore, dealing $s1 Frost damage each round for 3 rounds.
        type = "buff",
        attackPercent = 30,
        target = "front_enemies",
        duration = 3,
        event = "beforeAttack",
        buffName = "Icespore Spear",

    },
    [95] = { -- Lloth'wellyn calls upon the stars, dealing $s1 Arcane damage to the farthest enemy, and $s2 Arcane damage to all enemies at range.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 150,
            affectedByTaunt = true,
        },
        [2] = {
            target = "back_enemies",
            type = "attack",
            attackPercent = 40,
        },
    },
    [96] = { -- Yira'lya summons a swarm of insects to torment the farthest enemy, dealing $s1 Nature damage and reducing their damage by 30% for two rounds.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 60,
            continueIfCasterDies = true,
        },
        [2] = {
            target = "furthest_enemy",
            type = "buff",
            changeDamageDealtPercent = -30,
            duration = 2,
            buffName = "Insect Swarm",

        },
    },
    [97] = { -- Kota unleashes a flurry of arrows, dealing $s1 Physical damage in a cone emanating from her closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 90,
    },
    [98] = { -- Sha'lor blasts the furthest enemy with shaped Anima, dealing $s1 Arcane damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 120,
    },
    [99] = { -- Tez'an rips and tears with his teeth, dealing $s1 Nature damage to all enemies in melee.
        target = "front_enemies",
        type = "attack",
        attackPercent = 140,
        affectedByTaunt = true,
    },
    [100] = { -- Qadarin heals himself for $s1 Nature.
        target = "self",
        type = "heal",
        healPercent = 60,
        skipIfFull = true,
    },
    [101] = { -- Watcher Vesperbloom implants a seed into the nearest enemy, dealing $s1 Nature damage and increasing damage taken by 20% for three rounds.
        [1] = {
            type = "attack",
            target = "closest_enemy",
            attackPercent = 60,
            continueIfCasterDies = true,
        },
        [2] = {
            type = "buff",
            target = "closest_enemy",
            duration = 3,
            changeDamageTakenPercent = 20,
            buffName = "Strangleheart Seed",

        },
    },
    [102] = { -- Groonoomcrooek's branches lash in the wind, dealing $s1 Nature damage to all enemies in a line.
        target = "line",
        type = "attack",
        attackPercent = 30,
    },
    [103] = { -- Dreamweaver doubles the damage of all allies for 2 rounds.
        target = "other_allies",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 100,
        buffName = "Social Butterfly",

    },
    [104] = { -- Heal an adjacent ally for $s1, but reduce their damage by 10% for the next round.
        [1] = {
            target = "nearby_ally_or_self",
            type = "heal",
            healPercent = 100,
        },
        [2] = {
            target = "nearby_ally_or_self",
            type = "buff",
            duration = 1,
            changeDamageDealtPercent = -10, -- Did Blizzard fix the rounding error or is something else going on here? See https://github.com/TLDRMissions/TLDRMissions/issues/373 previously the buff was preventing 1 extra damage.
            buffName = "Podtender",

        },
    },
    [105] = { -- Korayn and allies take 10% less damage.
        target = "all_allies",
        type = "passive",
        changeDamageTakenPercent = -10,
        buffName = "Hold the Line",
        --roundFirst = true, -- conflicts internal log 9
    },
    [106] = { -- Korayn steels her resolve and slices her opposition, dealing $s1 Physical damage to all adjacent enemies.
        target = "cleave_enemies",
        type = "attack",
        attackPercent = 40,
    },
    [107] = { -- Marileth douses the nearest enemy, dealing $s1 Shadow damage and inflicting an additional $s2 Shadow damage when the target is struck for three rounds.
        [1] = {
            target = "closest_enemy",
            type = "buff",
            duration = 3,
            attackPercent = 150,
            buffName = "Volatile Solvent (dot)",
            event = "beforeAttack",

        },
        [2] = {
            type = "attack",
            attackPercent = 150,
            target = "closest_enemy",
            ignoreThorns = true,
        },
        [3] = {
            target = "closest_enemy",
            type = "buff",
            duration = 3,
            changeDamageTakenUsingAttack = 50,
            buffName = "Volatile Solvent (vuln)",

        },
    },
    [108] = { -- Marileth heals a nearby ally for $s1 and increases their maximum health by 10%.
        [1] = {
            target = "nearby_ally_or_self",
            type = "heal",
            healPercent = 40,
        },
        [2] = {
            target = "nearby_ally_or_self",
            type = "buff",
            duration = 2,
            changeMaxHPPercent = 10,
            buffName = "Ooz's Frictionless Coating",

        },
    },
    [109] = { -- Enemies attacking Heirmir take $s1 Physical damage.
        target = "self",
        type = "passive",
        thorns = 60,
        buffName = "Serrated Shoulder Blades",
    },
    [110] = { -- Heirmir's brooch heals her for $s1.
        target = "self",
        type = "heal",
        healPercent = 40,
        skipIfFull = true,
    },
    [111] = { -- Emeni's fumes deal $s1 Nature damage to all enemies in melee range.
        target = "front_enemies",
        type = "attack",
        attackPercent = 100,
        affectedByTaunt = true,
    },
    [112] = { -- Emeni's marvelous mastication inspires all adjacent allies, increasing their damage by $s1 Shadow.
        target = "adjacent_allies",
        type = "buff",
        changeDamageDealtUsingAttack = 30,
        duration = 3,
        buffName = "Gnashing Chompers",

    },
    [113] = { -- Mevix judges his opponent wanting, dealing $s1 Shadowfrost damage to all enemies in a cone in front of him.
        target = "cone",
        type = "attack",
        attackPercent = 120,
    },
    [114] = { -- Every round, Gunn heals herself for $s1.
        target = "self",
        type = "heal",
        healPercent = 100,
        skipIfFull = true,
    },
    [115] = { -- Rencissa lashes out, dealing $s1 Shadow damage to adjacent enemies.
        target = "cleave_enemies",
        type = "attack",
        attackPercent = 70,
        affectedByTaunt = true,
    },
    [116] = { -- The Juvenile Miredeer lowers its horns and charges, dealing $s1 Nature damage to the closest enemy.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 120,
    },
    [117] = { -- Slashes at the front rank of enemies, dealing $s1 Nature damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 40,
    },
    [118] = { -- Blasts the furthest foe with $s1 Nature damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 200,
        firstTurn = 3,
    },
    [119] = { -- Jabs out with a corrosive cone attack, dealing $s1 Nature damage in a cone emitting from the closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 100,
    },
    [120] = { -- The Trickster goads a random ally into trying harder.
        target = "pseudorandom_mawswornstrength", -- seems to always target bottom right minion on the first turn, after that seems random. targets enemies despite description
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 50,
        buffName = "Goading Motivation",

    },
    [121] = { -- The Trickster blows a glittering distracting dust across all enemies.
        target = "all_enemies",
        type = "buff",
        duration = 1,
        changeDamageDealtPercent = -50,
        buffName = "Mesmeric Dust",

    },
    [122] = { -- Chaos and fire! This attack deals $s1 Fire damage over three turns to a random enemy.
    --    type = "buff",
                target = "self",      -- ability seems bugged, never triggered
    --    target = "random_enemy",
    --    attackPercent = 30,
    --    event = "endTurn",
    --    duration = 2,
    --    firstTurn = 1,
    --    buffName = "Humorous Flame",
    },
    [123] = { -- The Trickster heals front line allies for $s1.
        target = "front_allies_only",
        type = "heal",
        healPercent = 30,
        skipIfFull = true,
    },
    [124] = { -- Kicks all adjacent enemies in melee with their powerful hooves, dealing $s1 Nature damage.
        target = "cleave_enemies",
        type = "attack",
        attackPercent = 60,
    },
    [125] = { -- The Scavenger lashes out at a random enemy, dealing $s1 Nature damage, and reducing the targets damage by $s2% for one turn.
        [1] = {
            type = "attack",
            target = "pseudorandom_mawswornstrength",
            attackPercent = 60,
            continueIfCasterDies = true,
        },
        [2] = {
            type = "buff",
            target = "pseudorandom_mawswornstrength",
            changeDamageDealtPercent = -50,
            duration = 1,
            buffName = "Deranged Gouge",

        }
    },
    [126] = { -- The Grovetender uses their knowledge of nurturing magics, healing their front line allies for $s1.
        target = "front_allies_only",
        type = "heal",
        healPercent = 20,
        skipIfFull = true,
    },
    [127] = { -- The Gormling gets a taste for all the enemies in melee, dealing $s1 Nature damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 60,
    },
    [128] = { -- The Gormling regurgitates a massive stream of acidic liquid at all enemies at range, dealing $s1 Nature damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 75,
    },
    [129] = { -- The Queen commands her minions to do better, healing them for $s1, and buffing their damage by $s2% for one turn.
        [1] = {
            target = "other_allies",
            type = "heal",
            healPercent = 10,
        },
        [2] = {
            target = "other_allies",
            type = "buff",
            duration = 1,
            changeDamageDealtPercent = 10,
            buffName = "Queen's Command",
        },
    },
    [130] = { -- The Gormling forms a protective, thorny, shield, which deals $s1 Nature damage to anyone attacking it for three turns.
        target = "self",
        type = "buff",
        duration = 3,
        thorns = 100,
        buffName = "Carapace Thorns",

    },
    [131] = { -- Arcane bolts shoot from the Runestag's antlers, dealing $s1 Arcane damage to all enemies at range.
        target = "back_enemies",
        type = "attack",
        attackPercent = 150,
    },
    [132] = { -- This attack explodes with the force of a falling tree, dealing $s1 Nature damage to all enemies in melee, and reducing their damage by $s2% for one turn.
        [1] = {
            type = "attack",
            target = "front_enemies",
            attackPercent = 50,
        },
        [2] = {
            type = "buff",
            target = "front_enemies",
            duration = 1,
            changeDamageDealtPercent = -25,
            buffName = "Arbor Eruption",

        }
    },
    [133] = { -- The manifestation draws on ancient power to deal $s1 Arcane damage to all enemies at range, and heal themselves for some of the damage.
        [1] = {
            target = "back_enemies",
            type = "attack",
            attackPercent = 100,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 75,
        },
    },
    [134] = { -- Curses all enemies, increasing the damange they take by 25% for two turns.
        target = "all_enemies",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = 25,
        buffName = "Curse of the Dark Forest",

    },
    [135] = { -- A fiery wave of projectiles is spewed across the battlefield, dealing $s1 Fire damage to all enemies at range.
        target = "back_enemies",
        type = "attack",
        attackPercent = 300,
    },
    [136] = { -- Bite the closest enemy with jaws of flame, dealing $s1 Fire damage over three turns.
        type = "buff",
        attackPercent = 150,
        target = "closest_enemy",
        duration = 3,
        buffName = "Searing Jaws",

        event = "onRemove",
    },
    [137] = { -- A hearty battlecry that increases damage done by $s1% for two turns.
        target = "self",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 25,
        buffName = "Hearty Shout",
    },
    [138] = { -- Lashes out against all adjacent enemies in melee, dealing $s1 Arcane damage.
        target = "cleave_enemies",
        type = "attack",
        attackPercent = 30,
    },
    [139] = { -- Starts on Cooldown. The creature goes into a frenzy, lashing out at all enemies at range, dealing $s1 Arcane damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 400,
        firstTurn = 5,
    },
    [140] = { -- Khaliiq hurls energized daggers at all enemies at range, dealing $s1 Shadow damage and reducing their damage by 10% for 2 rounds.
        [1] = {
            type = "attack",
            target = "back_enemies",
            attackPercent = 60,
        },
        [2] = {
            type = "buff",
            target = "back_enemies",
            duration = 2,
            changeDamageDealtPercent = -10,
            buffName = "Fan of Knives",

        }
    },
    [141] = { -- The creature shares some of its remaining anima to protect its herd. All allies gain $s1% damage mitigation for two turns.
        target = "all_allies",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = -50,
        buffName = "Herd Immunity",

    },
    [142] = { -- The creature pulses out waves of concentrated anima, healing in a cone from the closest ally for $s1.
        target = "closest_ally",
        type = "heal",
        healPercent = 30,
    },
    [143] = { -- The manifestation exclaims belief in their own ability, increasing damage done by $s1% for two turns.
        target = "self",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 25,
        buffName = "Arrogant Boast",
    },
    [144] = { -- The manifestation defends their position, reducing the damage their allies take by $s1% for two turns.
        type = "buff",
        changeDamageTakenPercent = -75,
        target = "other_allies",
        duration = 2,
        firstTurn = 3,
        buffName = "Ardent Defense",

    },
    [145] = { -- Smashes the closest enemy, dealing $s1 Shadow damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 75,
    },
    [146] = { -- Hurls a javelin at the farthest enemy, dealing $s1 Shadow damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 75,
    },
    [147] = { -- The praetor inspires the Forsworn, reducing the damage allies take by $s1% for two turns.
        target = "other_allies",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = -50,
        buffName = "Close Ranks",

    },
    [148] = { -- Release restorative anima, healing front line allies for $s1.
        target = "front_allies_only",
        type = "heal",
        healPercent = 125,
    },
    [149] = { -- Slashes at the front rank of enemies, dealing $s1 Shadow damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 75,
    },
    [150] = { -- A furious flurry of claws, dealing $s1 Shadow damage in a cone from the closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 50,
    },
    [151] = { -- Swoops down on the closest enemy dealing $s1 Physical damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 20,
    },
    [152] = { -- The Matriarch sends out a wave of pure anima, healing all allies for $s1, and buffing their damage by $s2% for one turn.
        firstTurn = 4,
        [1] = {
            target = "other_allies",
            type = "heal",
            healPercent = 200,
        },
        [2] = {
            target = "other_allies",
            type = "buff",
            changeDamageDealtPercent = 50,
            duration = 1,
            buffName = "Anima Wave",

        }
    },
    [153] = { -- Projects a condensed stream of anima, dealing $s1 Shadow damage in a cone from the closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 75,
    },
    [154] = { -- Forms a reflective shield, which deals $s1 Shadow damage to anyone attacking it for three turns.
        target = "self",
        type = "buff",
        duration = 3,
        thorns = 100,
        buffName = "Stolen Wards",

    },
    [155] = { -- A concussive roar that shakes all enemies and reduces their damage done by $s1% for one turn.
        target = "all_enemies",
        type = "buff",
        duration = 1,
        stackLimit = 2,
        changeDamageDealtPercent = -75,
        buffName = "Concussive Roar",
    },
    [156] = { -- Curses all enemies, increasing the damage they take by $s1% for two turns.
        target = "all_enemies",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = 40,
        buffName = "Cursed Knowledge",

    },
    [157] = { -- A frantic flap of sharp wings, striking all adjacent enemies in melee, dealing $s1 damage.
        target = "cleave_enemies",
        type = "attack",
        attackPercent = 80,
    },
    [158] = { -- Starts on Cooldown. Blasts all enemies at range with $s1 Shadow damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 300,
        firstTurn = 2,
    },
    [159] = { -- The creature makes all enemies doubt themselves, decreasing damage done by $s1% for two turns.
        target = "all_enemies",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = -25,
        buffName = "Proclamation of Doubt",
    },
    [160] = { -- Slams his massive fists into the ground, dealing $s1 Nature damage to all enemies.
        target = "all_enemies",
        type = "attack",
        attackPercent = 200,
    },
    [161] = { -- The Overseer marshalls his troops, healing them for $s1, and buffing their damage by $s2% for one turn.
        [1] = {
            target = "all_allies",
            type = "heal",
            healPercent = 100,
        },
        [2] = {
            target = "all_allies",
            type = "buff",
            duration = 1,
            changeDamageDealtPercent = 25,
            buffName = "Dark Command",

        },
    },
    [162] = { -- Curses all enemies, decreasing the damange they do by $s1% for two turns.
        target = "all_enemies",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = -50,
        buffName = "Curse of Darkness",

    },
    [163] = { -- Starts on Cooldown. Sends out a powerful wave of anima, dealing $s1 Shadow damage to all enemies.
        target = "all_enemies",
        type = "attack",
        attackPercent = 400,
        firstTurn = 5,
    },
    [164] = { -- Breathes a dark flame, dealing $s1 Shadow damage over three turns in a cone emitting from the closest enemy.
        -- on the first turn, applies the debuff, then instantly deals damage. did not deal damage on the following two turns but unsure what happens after that
        [1] = {
            type = "buff",
            attackPercent = 200,
            target = "cone",
            duration = 3,
            buffName = "Dark Flame",
            event = "onRemove",

            -- ignoreThorns = true, -- needs confirmation
        },
        [2] = {
            type = "attack",
            attackPercent = 200,
            target = "cone",
            ignoreThorns = true,
        },
    },
    [165] = { -- Slashes at the closest enemy, dealing $s1 Shadow damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 300,
    },
    [166] = { -- Bites at a random enemy, dealing $s1 Shadow damage and healing itself for $s2.
        [1] = {
            target = "pseudorandom_ritualfervor", -- have only seen logs of it attacking itsself / its own allies.
            type = "attack",
            attackPercent = 100,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 50,
        }
    },
    [167] = { -- Casts a series of sharp, stone, shards at all enemies at range, dealing $s1 Nature damage.
        target = "furthest_enemy", -- despite description, seems to only hit furthest enemy
        type = "attack",
        attackPercent = 150,
    },
    [168] = { -- Lets loose a vicious howl that strikes fear into the nearest enemy, reducing their damage by $s1% for two turns.
        target = "closest_enemy",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = -50,
        buffName = "Howl from Beyond",

    },
    [169] = { -- Strikes at the closest enemy, dealing $s1 Shadow damage, and causing a damage over time effect for $s2 over three turns.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 65,
        },
        [2] = {
            target = "closest_enemy",
            type = "buff",
            attackPercent = 50,
            duration = 3,
            buffName = "Consuming Strike",
            event = "onRemove",

        },
        [3] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 50,
            ignoreThorns = true,
        }
    },
    [170] = { -- Flying fists of stone deal $s1 Nature damage to all enemies in melee.
        target = "front_enemies",
        type = "attack",
        attackPercent = 60,
    },
    [171] = { -- Hurls a massive boulder, dealing $s1 Nature damage to all enemies at range.
        target = "furthest_enemy", -- despite description, only hit one target. Callous Peacekeeper[10][855HP] cast Pitched Boulder at Ardenweald Grovetender[1][1058HP] for 122 Nature damage.
        type = "attack",
        attackPercent = 100,
    },
    [172] = { -- Strike all enemies in melee, dealing $s1 Shadow damage and reducing their damage by $s2%.
        firstTurn = 2,
        [1] = {
            type = "attack",
            target = "front_enemies",
            attackPercent = 20,
        },
        [2] = {
            target = "front_enemies",
            type = "buff",
            duration = 1,
            buffName = "Viscous Slash",
            changeDamageDealtPercent = -50,

        }
    },
    [173] = { -- Blasts the furthest foe with $s1 Frost damage, reducing their damage by $s2%.
        [1] = {
            type = "attack",
            target = "furthest_enemy",
            attackPercent = 75,
        },
        [2] = {
            type = "buff",
            target = "furthest_enemy",
            duration = 2,
            changeDamageDealtPercent = -25,
            buffName = "Icy Blast",

        }
    },
    [174] = { -- A frozen reflective shield forms which deals $s1 Frost damage to anyone attacking it for three turns.
        target = "self",
        type = "buff",
        duration = 3,
        thorns = 40,
        buffName = "Polished Ice Barrier",

    },
    [175] = { -- The party animal is lost in the moment and lashes out at a random target, dealing $s1 Shadow damage.
        target = "pseudorandom_lashout",
        type = "attack",
        attackPercent = 120,
    },
    [176] = { -- The noble launches into a passionate defense of the aristocracy, distracting all enemies and increasing damage taken by $s1%.
        target = "all_enemies",
        type = "buff",
        duration = 1,
        changeDamageTakenPercent = 25,
        buffName = "Arrogant Denial",
        --roundFirst = true,
    },
    [177] = { -- Slams into the closest enemy, dealing $s1 damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 50,
    },
    [178] = { -- Draws anima from the furthest enemy, dealing $s1 Shadow damage and healing itself for $s2.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 100,
        },
        [2] = {
            healPercent = 50,
            target = "self",
            type = "heal",
        },
    },
    [179] = { -- Emits a healing mist, healing all allies for $s1, and increases their damage by $s2% for two turns.
        [1] = {
            target = "all_allies",
            type = "heal",
            healPercent = 100,
        },
        [2] = {
            target = "all_allies",
            type = "buff",
            duration = 2,
            changeDamageDealtPercent = 50,
            buffName = "Medical Advice",

            dontRound = true,
        },
    },
    [180] = { -- Targets a random enemy with visions of doom, dealing $s1 Shadow damage.
        target = "pseudorandom_mawswornstrength",
        type = "attack",
        attackPercent = 75,
    },
    [181] = { -- Starts on Cooldown. Blasts all enemies at range with $s1 Shadow damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 150,
        firstTurn = 5,
    },
    [182] = { -- Confuses all enemies with mirror reflections, decreasing the damage they do by $s1% for two turns.
        target = "all_enemies",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = -50,
        buffName = "Deceptive Practice",

    },
    [183] = { -- Slashes at all enemies in melee with their claws, dealing $s1 Shadow damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 50,
    },
    [184] = { -- Blasts out a cone of anima from the closest enemy, dealing $s1 Shadow damage.
        target = "cone",
        type = "attack",
        attackPercent = 75,
    },
    [185] = { -- Stacka lashes out with all his strength, dealing $s1 Shadow damage to all enemies.
        target = "all_enemies",
        type = "attack",
        attackPercent = 100,
    },
    [186] = { -- Starts on Cooldown. Claws and bites wildly at all enemies in melee, dealing $s1 Shadow damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 200,
        firstTurn = 4,
    },
    [187] = { -- Emits a wave of toxic magic across all enemies, causing a damage over time effect for $s1 over two turns.
        -- applies, deals the damage, then 2 turns later deals the damage again and removes
        [1] = {
            type = "buff",
            attackPercent = 50,
            target = "all_enemies",
            buffName = "Toxic Miasma",
            duration = 2,
            event = "onRemove",
        },
        [2] = {
            type = "attack",
            attackPercent = 50,
            target = "all_enemies",
            ignoreThorns = true,
        },
    },
    [188] = { -- Big Shiny lashes out at the closest enemy, dealing $s1 damage, and reducing the targets damage by $s2% for one turn.
        [1] = {
            type = "attack",
            target = "closest_enemy",
            attackPercent = 50,
        },
        [2] = {
            type = "buff",
            target = "closest_enemy",
            duration = 2,
            changeDamageDealtPercent = -50,
            buffName = "Angry Smash",
        }
    },
    [189] = { -- Bashes into the closest enemy, dealing $s1 damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 200,
    },
    [190] = { -- Blasts all enemies in melee with $s1 Shadow damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 150,
    },
    [191] = { -- Deals $s1 Nature damage each round to all enemies and heals all allies for $s2.
        [1] = {
          target = "all_enemies",
          type = "attack",
          attackPercent = 100,
          continueIfCasterDies = true,
        },
        [2] = {
          target = "all_allies",
          type = "heal",
          healPercent = 100,
          reacquireTargets = true,
        },
    },
    [192] = { -- Rathan blasts the furthest enemy, dealing $s1 Shadow damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 160,
    },
    [193] = { -- Gorgelimb sacrifices his own flesh, dealing $s1 Physical damage to enemies in melee and $s2 damage to himself.
        [1] = {
          target = "front_enemies",
          type = "attack",
          attackPercent = 300,
        },
        [2] = {
          target = "self",
          type = "attack",
          attackPercent = 50,
        },
    },
    [194] = { -- Ashraka empowers an adjacent ally at the cost of her own health, increasing their damage by $s1 Shadow and modifying incoming damage by $s2 for 2 turns.
        [1] = {
            type = "buff",
            changeDamageTakenPercent = -20,
            target = "closest_ally",
            duration = 2,
            buffName = "Potentiated Power (shield)",

        },
        [2] = {
            type = "buff",
            target = "closest_ally",
            duration = 2,
            changeDamageDealtUsingAttack = 40,
            buffName = "Potentiated Power (attack)",

        },
        [3] = {
            target = "self",
            type = "attack",
            attackPercent = 20,
        },
    },
    [195] = { -- Talethi deals $s1 Frost damage each turn for 2 turns to enemies in a cone in front of him.
        [1] = {
            type = "buff",
            attackPercent = 80,
            target = "cone",
            duration = 2,
            buffName = "Creeping Chill",

            event = "beforeAttack",
        },
        [2] = {
            type = "attack",
            target = "cone",
            attackPercent = 80,
            ignoreThorns = true,
        },
    },
    [196] = { -- Velkein strikes an adjacent enemy multiple times, dealing $s1 Physical damage, then $s2, then $s3, then $s4.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 120,
        },
        [2] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 90,
        },
        [3] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 60,
        },
        [4] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 30,
        },
    },
    [197] = { -- Assembler Xertora reconstructs all adjacent allies, healing them for $s1.
        target = "adjacent_allies",
        type = "heal",
        healPercent = 55,
        skipIfFull = true,
    },
    [198] = { -- Rattlebag encases himself in whirling bones, reducing damage taken by $s1 and inflicting $s2 Shadow damage to enemies that strike him.
        [1] = {
            type = "buff",
            thorns = 60,
            target = "self",
            duration = 2,
            buffName = "Bone Shield (thorns)",

        },
        [2] = {
            changeDamageTakenUsingAttack = -60,
            buffName = "Bone Shield (shield)",
            type = "buff",
            target = "self",
            duration = 2,
        }
    },
    [199] = { -- A wild swing that strikes all enemies in melee, dealing $s1 damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 100,
    },
    [200] = { -- Lashes out dealing $s1 Nature damage to all enemies in melee, and decreasing their damage by $s2% for one turn.
        [1] = {
            type = "attack",
            attackPercent = 100,
            target = "front_enemies",
            continueIfCasterDies = true,
        },
        [2] = {
            type = "buff",
            target = "front_enemies",
            duration = 1,
            changeDamageDealtPercent = -50,
            buffName = "Stunning Swipe",

        }
    },
    [201] = { -- Flies into a frenzy, assaulting all enemies at range, dealing $s1 Nature damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 200,
    },
    [202] = { -- Attracts the attention of all enemies, focusing their attention on itself.
        target = "all_enemies",
        type = "buff",
        taunt = true,
        duration = 2,
        buffName = "Taunt",
    },
    [203] = { -- Deadly winds of anima infused magic tear through all enemies in melee, dealing $s1 Nature damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 100,
    },
    [204] = { -- Blasts the closest enemy with $s1 Shadow damage, reducing their damage by $s2% for two turns.
        [1] = {
            type = "attack",
            target = "closest_enemy",
            attackPercent = 150,
        },
        [2] = {
            type = "buff",
            target = "closest_enemy",
            duration = 2,
            changeDamageDealtPercent = -50,
            buffName = "Death Blast",

        }
    },
    [205] = { -- Necromantic energy pulses forth, healing front line allies for $s1.
        target = "front_allies_only", 
        type = "heal",
        healPercent = 75,
        skipIfFull = true,
    },
    [206] = { -- Is it a foot? Is it a hoof? Hard to tell, but it hits hard, dealing $s1 damage to the closest enemy.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [207] = { -- Lunges into their foes with tooth and claw, dealing $s1 damage to all enemies in a line.
        target = "closest_enemy", -- despite the description, seems to only hit closest enemy
        type = "attack",
        attackPercent = 30,
    },
    [208] = { -- Roars out a spine chilling challenge to a random enemy, focusing their attention on itself.
        -- from testing, never saw this ability actually activate. bugged?
        type = "passive",
        bugged = true,
        target = "self",
        --type = "buff",
        --target = "random_enemy",
        --taunt = true,
        --duration = 2,
        --buffName = "Intimidating Roar",
    },
    [209] = { -- Inspires a random ally to greater sacrifice. Buffing their damage by $s1% for one turn.
        target = "pseudorandom_ritualfervor",
        type = "buff",
        duration = 1,
        changeDamageDealtPercent = 50,
        buffName = "Ritual Fervor",

    },
    [210] = { -- Emits a wave of death magic, dealing $s1 Shadow damage to all enemies.
        target = "all_enemies",
        type = "attack",
        attackPercent = 200,
    },
    [211] = { -- Spits out a stream of toxic material, dealing $s1 Nature damage in a cone emitting from the closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 150,
    },
    [212] = { -- The paniced beast strikes out at a random target, dealing $s1 damage.
        target = "pseudorandom_lashout",
        type = "attack",
        attackPercent = 200,
    },
    [213] = { -- The ancient creature emits waves of beneficial spores, healing in a cone from the closest ally for $s1.
        target = "closest_ally",
        type = "heal",
        healPercent = 100,
        skipIfFull = true,
    },
    [214] = { -- Lashes out with necrotic energy in a cone from the closest enemy, dealing $s1 Shadow damage.
        target = "cone",
        type = "attack",
        attackPercent = 100,
    },
    [215] = { -- Strikes out with massive fists, dealing $s1 Nature damage to the closest enemy.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 300,
    },
    [216] = { -- Hisses loudly. Stay away! Prevents itself from being a target for two turns.
        target = "self",
        type = "buff",
        shroud = true,
        duration = 2,
        buffName = "Threatening Hiss",
    },
    [217] = { -- Lashes out with Necrotic energy, assaulting all enemies at range, dealing $s1 Shadow damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 200,
    },
    [218] = { -- Spins a protective sheath of bone. Mitigating damage taken by $s1% for two turns.
        buffName = "Ritual of Bone",
        target = "self",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = -50,
    },
    [219] = { -- Draws upon death to empower their necrotic energy, healing the closest ally for $s1, and decreases their damage taken by $s2% for two turns.
        [1] = {
            target = "closest_ally",
            type = "heal",
            healPercent = 200,
        },
        [2] = {
            target = "closest_ally",
            type = "buff",
            duration = 2,
            changeDamageTakenPercent = -50,
            buffName = "Necrotic Healing",
        },
    },
    [220] = { -- Deadly claws tear through all enemies in melee, dealing $s1 damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 100,
    },
    [221] = { -- Digs underground, avoiding being targeted for two turns.
        buffName = "Burrow",
        target = "self",
        type = "buff",
        duration = 2,
        shroud = true,
    },
    [222] = { -- Strikes with poison laden teeth, dealing $s1 Nature damage to the closest enemy, and inflicting $s2 Nature damage over two turns.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 30,
        },
        [2] = {
            duration = 2,
            type = "buff",
            attackPercent = 30,
            target = "closest_enemy",
            buffName = "Poisonous Bite",
            event = "onRemove",

        },
        [3] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 30,
            ignoreThorns = true,
        },
    },
    [223] = { -- Powerful death magic rolls across the Planes of Torment, causing a stacking damage over time effect to all of your party.
        buffName = "Wave of Eternal Death",
        type = "buff",
        attackPercent = 18,
        target = "all_enemies",
        duration = 10,
        stackLimit = 5,
    },
    [224] = { -- Deadly claws tear through all enemies in melee, dealing $s1 damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 50,
    },
    [225] = { -- Spews forth a cloud of screams, dealing $s1 Shadow damage in a cone emitting from the closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 50,
    },
    [226] = { -- Lashes out with their spear in a cone from the closest enemy, dealing $s1 shadow damage.
        target = "cone",
        type = "attack",
        attackPercent = 50,
    },
    [227] = { -- The Jailer sends a bombardment of missles across Calcis, dealing $s1% of their Health as Shadow damage to a random enemy every turn.
        target = "pseudorandom_mawswornstrength",
        type = "attack",
        damageTargetHPPercent = 30,
    },
    [228] = { -- After ten turns a wave of absolute destruction flows through the The Tremaculum, dealing $s1 damage to your party.
        type = "attack",
        attackPercent = 6200,
        firstTurn = 9,
        doOnce = true,
        target = "all_enemies",
    },
    [229] = { -- Ancient rites and runes protect a random ally, reducing their damage taken by $s1% for two turns.
        target = "pseudorandom_ritualfervor",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = -50,
        buffName = "Mawsworn Ritual",
    },
    [230] = { -- The Altar of Domination provides a locus of faith for the Mawsworn, healing them for $s1.
        type = "heal",
        target = "all_allies",
        healPercent = 91,
    },
    [231] = { -- Intimidates a random enemy, causing them to take $s1% more damage for two turns.
        target = "pseudorandom_mawswornstrength",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = 100,
        buffName = "Mawsworn Strength (231)",

    },
    [232] = { -- Focuses a feeling of dread upon a random enemy, reducing their damage done by $s1% for three turns.
        target = "pseudorandom_mawswornstrength",
        type = "buff",
        duration = 3,
        changeDamageDealtPercent = -50,
        buffName = "Aura of Death",
    },
    [233] = { -- Fires a manifestation of pure doom at the closest enemy, dealing $s1 Shadow Damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [234] = { -- Inspires their allies through fear, causing them to do $s1% more damage for two turns.
        buffName = "Power of Anguish",
        target = "pseudorandom_ritualfervor",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 50,

    },
    [235] = { -- Targets enemies at range, calling down missles of pure maw anima, dealing $s1 Shadow damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 50,
    },
    [236] = { -- Draws upon the maw itself to empower their allies, decreases their damage taken by $s1% for two turns.
        buffName = "Empowered Minions",
        target = "all_allies",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = -50,
    },
    [237] = { -- Sweeps down with precision, slashing deeply at all enemies in melee, dealing $s1 Shadow Damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 50,
    },
    [238] = { -- Attracts the attention of all enemies for two turns.
        buffName = "Death Shield",
        target = "all_enemies",
        type = "buff",
        duration = 2,
        taunt = true,
    },
    [239] = { -- Fires a manifestation of pure doom at enemies at range, dealing $s1 Shadow Damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 50,
    },
    [240] = { -- Surges into the enemy ranks, dealing $s1 Shadow damage to all enemies in a line.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 25,
    },
    [241] = { -- A spiral of maw anima surges towards a random enemy, dealing $s1 Shadow damage and reducing their damage done by $s2% for two turns.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 75,
        },
        [2] = {
            target = "furthest_enemy",
            type = "buff",
            duration = 2,
            changeDamageDealtPercent = -50,
            buffName = "Pain Spike",
        },
    },
    [242] = { -- Heals the closest ally for $s1, and decreases their damage taken by $s2% for two turns.
        [1] = {
            target = "closest_ally",
            type = "heal",
            healPercent = 50,
        },
        [2] = {
            target = "closest_ally",
            type = "buff",
            duration = 2,
            changeDamageTakenPercent = 75,
            buffName = "Dark Healing",

        },
    },
    [243] = { -- Stares into the Abyss, taunting all enemies and reducing their damage taken by $s2% for two turns.
        [1] = {
            target = "all_enemies",
            type = "buff",
            taunt = true,
            duration = 2,
            buffName = "Baleful Stare (taunt)",
        },
        [2] = {
            target = "self",
            type = "buff",
            duration = 2,
            changeDamageTakenPercent = -50,
            buffName = "Baleful Stare (shield)",
        },
    },
    [244] = { -- Meatball increases his damage dealt by $s1 and damage taken by $s2 for 2 rounds. Deals $s3 Physical damage to the nearest enemy. This ability does not immediately activate. Meatball MAD!
        firstTurn = 1,
        [1] = {
            type = "buff",
            target = "self",
            duration = 2,
            changeDamageDealtUsingAttack = 200,
            buffName = "Meatball Mad! (attack)",
        },
        [2] = {
            changeDamageTakenUsingAttack = 30,
            type = "buff",
            target = "self",
            duration = 2,
            buffName = "Meatball Mad! (vuln)",
        },
        [3] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 30,
            affectedByTaunt = true,
        },
    },
    [245] = { -- Croman deals $s1 Holy damage to the nearest enemy.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 120,
    },
    [246] = { -- Strikes the closest adjacent enemy, dealing $s1 Physical damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [247] = { -- Strikes an enemy with its horn, dealing $s1 Holy damage and healing itself for $s2.
        firstTurn = 3,
        [1] = {
            type = "attack",
            attackPercent = 10,
            target = "closest_enemy",
        },
        [2] = {
            healPercent = 20,
            type = "heal",
            target = "self",
        }
    },
    [248] = { -- Bites the closest enemy, dealing $s1 Shadow damage and an additional $s2 Shadow damage each round for 4 rounds.
        [1] = {
            attackPercent = 30,
            target = "closest_enemy",
            type = "attack",
        },
        [2] = {
            attackPercent = 15,
            target = "closest_enemy",
            type = "buff",
            duration = 4,
            buffName = "Infectious Soulbite",
            event = "beforeAttack",

        },
    },
    [249] = { -- Slams the closest enemy in melee with their shield, dealing $s1 damage and reducing their damage by $s2% for one turn.
        [1] = {
            attackPercent = 60,
            target = "closest_enemy",
            type = "attack",
            continueIfCasterDies = true,
        },
        [2] = {
            type = "buff",
            target = "closest_enemy",
            duration = 1,
            changeDamageDealtPercent = -50,
            buffName = "Shield Bash",

        }  
    },
    [250] = { -- Fires a thorny projectile at the furthest foe, hitting them for $s1 Nature damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 80,
        firstTurn = 3,
    },
    [251] = { -- Lukir uses strange Drust magic to weaken all enemies, reducing their damage done by $s1 for two turns.
        target = "all_enemies",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = -20,
        buffName = "Doom of the Drust",

    },
    [252] = { -- Sweeps wildly with their Drust Blade, dealing $s1 Shadow damage to all adjacent enemies, and increasing their damage taken by $s2% for two turns.
        [1] = {
            attackPercent = 60,
            target = "cleave_enemies",
            type = "attack",
        },
        [2] = {
            target = "cleave_enemies",
            type = "buff",
            changeDamageTakenPercent = 25,
            duration = 2,
            buffName = "Viscous Sweep",
        
        }
    },
    [253] = { -- Claws at the front rank of enemies, dealing $s1 Shadow damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 75,
    },
    [254] = { -- Starts on Cooldown. Drust magic forms a sharp edged barrier around all allies, which deals $s1 Nature damage to anyone attacking them for three turns.
        type = "buff",
        firstTurn = 2,
        target = "other_allies",
        duration = 3,
        thorns = 100,

        buffName = "Drust Thorns",
    },
    [255] = { -- Shields an adjacent friendly target, reducing their damage taken by $s1% for one turn.
        target = "nearby_ally_or_self",
        type = "buff",
        duration = 1,
        changeDamageTakenPercent = -50,
        buffName = "Defense of the Drust",

    },
    [256] = { -- Fires Drust magic out in a cone attack, dealing $s1 Shadow damage in a cone emitting from the closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 100,
    },
    [257] = { -- The Brute emits a dread roar, chilling enemies to the bone, making them fearful to attack the brute for two turns.
        target = "self",
        type = "buff",
        shroud = true,
        duration = 2,
        buffName = "Dread Roar",
    },
    [258] = { -- Bites into the closest enemy, dealing $s1 Shadow damage, and causing the target to bleed for $s2 for three turns.
        [1] = {
            attackPercent = 100,
            type = "attack",
            target = "closest_enemy",
            continueIfCasterDies = true,  
        },
        [2] = { -- seems to be bugged. The debuff applies, but does its damage straight away, but nothing on the next two turns, then does its damage right before being removed
            duration = 3,
            type = "buff",
            attackPercent = 50,
            target = "closest_enemy",
            event = "onRemove",

            buffName = "Dark Gouge",
            continueIfCasterDies = true,
        },
        [3] = {
            attackPercent = 50,
            type = "attack",
            target = "closest_enemy",
            ignoreThorns = true, -- only takes thorns damage from the first part
        },
    },
    [259] = { -- This attack deals $s1 Arcane damage over two turns to the closest enemy.
        duration = 3,
        type = "buff",
        attackPercent = 30,
        target = "closest_enemy",
        buffName = "Anima Flame",

        event = "onRemove", -- despite description, only does its damage on the last turn before being removed
    },
    [260] = { -- A concentrated blast of stolen anima deals $s1 Arcane damage to the furthest enemy.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [261] = { -- Infuses an adjacent ally with increased power, buffing their damage by $s1% for two turns.
        target = "closest_ally",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 50,
        buffName = "Surgical Advances",

    },
    [262] = { -- The construct stomps the ground, unleashing a wave of acid that strikes all enemies in melee, dealing $s1 Nature damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 100,
    },
    [263] = { -- Spews out an acidic stream in a cone from the closest enemy, dealing $s1 Nature damage.
        target = "cone",
        type = "attack",
        attackPercent = 100,
    },
    [264] = { -- Baron Halis lashes out with his hook, damaging the furthest enemy at range with a mighy blast of $s1 damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 300,
    },
    [265] = { -- Toxic claws tear in a line from the closest enemy, dealing $s1 Nature damage.
        target = "closest_enemy", -- despite description, doesn't seem to actually attack in a line. closest enemy only
        type = "attack",
        attackPercent = 100,
    },
    [266] = { -- Genghis strikes down with both arm blades, damaging an adjacent enemy for a colossal $s1 damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 1000,
    },
    [267] = { -- Fires an acidic bolt at the furthest enemy, dealing $s1 Nature damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [268] = { -- Sprays all enemies in melee with a viscous acid, reducing their damage done by $s1% for three turns.
        target = "front_enemies",
        type = "buff",
        duration = 3,
        changeDamageDealtPercent = -30,
        buffName = "Acidic Spray",

    },
    [269] = { -- The Feaster launches itself in the air, coming down and splashing up a wave of acid that strikes all enemies in melee, dealing $s1 Nature damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 120,
    },
    [270] = { -- Fires out a stream of spidersilk that webs the closest enemy, reducing their damage done by $s1 % for two turns.
        target = "closest_enemy",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = -50,
        buffName = "Spidersong Webbing",
    },
    [271] = { -- Ambushes the furthest enemy at range, damaging them for $s1 Nature damage for three turns.
        type = "buff",
        attackPercent = 100,
        target = "furthest_enemy",
        duration = 3,
        event = "beforeAttack",
        buffName = "Ambush",
 -- yup, this actually keeps doing damage after the caster dies. Wow. Ardenweald Grovetender[3][548HP] killed Boneweave Ambusher[9][275HP]., Boneweave Ambusher[9][275HP]'s Ambush dealt 158 Nature to Ardenweald Grovetender[3][548HP]. Boneweave Ambusher[9][0HP]'s Ambush dealt 158 Nature to Ardenweald Grovetender[3][390HP].
    },
    [272] = { -- Fires an icy bolt at the furthest enemy, dealing $s1 Nature damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    -- Curses an adjacent enemy. Reducing their damage by $s1% for one turn.
    --[273] = function() print("Error: 273 not set") end,
    [274] = { -- Decadious slams down, sending chunks of Flesh in every direction, striking all enemies in melee, dealing $s1 Nature damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 120,
    },
    [275] = { -- Infuses an adjacent ally with increased power, buffing their damage by $s1% for two turns.
        target = "closest_ally",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 75,
        buffName = "Necromantic Infusion",

    },
    [276] = { -- Fires a necromatic bolt at the furthest enemy, dealing $s1 Shadow damage instantly, and a further $s2 Shadow damage over three turns.
        [1] = {
            attackPercent = 25,
            type = "attack",
            target = "furthest_enemy",
            continueIfCasterDies = true,
        },
        [2] = {
            duration = 3, -- deals its damage, applies the dot, and then deals the first dot tick straight away
            type = "buff",
            target = "furthest_enemy",
            attackPercent = 50,
            buffName = "Rot Volley",
            event = "onRemove", -- further testing found it only deals its tick on the final turn
        },
        [3] = {
            type = "attack",
            attackPercent = 50,
            target = "furthest_enemy",
            ignoreThorns = true,
        },
    },
    [277] = { -- The Stitched Vanguard enrages, boosting their own damage by $s1% for two turns.
        target = "self",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 100,
        buffName = "Enrage",
    },
    [278] = { -- Inspires doubt in the mind of an enemy at range, increasing the damage they take by $s1% for two turns.
        target = "furthest_enemy",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = 50,
        buffName = "Memory Displacement",
    },
    [279] = { -- Creates an aura of mental anguish that deals $s1 Arcane damage to all enemies at range.
        target = "back_enemies",
        type = "attack",
        attackPercent = 50,
    },
    [280] = { -- Fires out a a cascade of razor sharp quills that deal $s1 damage to all enemies in Melee.
        target = "front_enemies",
        type = "attack",
        attackPercent = 250,
    },
    [281] = { -- Vyrm spits out a concentrated globule of anima, dealing $s1 Arcane damage to the furthest enemy.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [282] = { -- Starts on Cooldown. Aella charges her divine Javelin, damaging an adjacent enemy for a colossal $s1 damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 1000,
        firstTurn = 4,
    },
    [283] = { -- Claws laden with Anima tear in a line from the closest enemy, dealing $s1 Arcane damage.
        target = "closest_enemy", -- despite the description, doesn't seem to actually attack in a line
        type = "attack",
        attackPercent = 75,
    },
    [284] = { -- Releases an aura of anima that infuses its allies with improved reflexes, reducing damage taken by $s1% for one turn.
        target = "other_allies",
        type = "buff",
        duration = 1,
        changeDamageTakenPercent = -50,
        buffName = "Empyreal Reflexes",
    },
    [285] = { -- Starts on Cooldown. Curses all their enemies, causing them to take $s1% extra damage for two turns.
        type = "buff",
        firstTurn = 3,
        target = "all_enemies",
        duration = 2,
        changeDamageTakenPercent = 50,
        buffName = "Forsworn's Wrath",
    },
    [286] = { -- Commands an adjacent ally to try harder, boosting their damage by $s1% for two turns.
        target = "nearby_ally_or_self",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 50,
        buffName = "CHARGE!",
    },
    [287] = { -- The footman takes a defensive stance, reducing the damage they take by $s1% for one turn.
        target = "self",
        type = "buff",
        duration = 1,
        changeDamageTakenPercent = -50,
        buffName = "Elusive Duelist",
    },
    [288] = { -- The Bladewing sweeps down, raking claws of stone across all enemies at range for $s1 Nature damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 60,
    },
    [289] = { -- Fires a bolt laced with poison at an enemy at range, causing a damage over time effect for $s1 Shadow damage over three turns.
        [1] = {
            duration = 3, -- according to logs I've seen, seems to deal its damage instantly on the first turn, then again on the last turn before removal
            type = "buff",
            attackPercent = 100,
            target = "furthest_enemy",
            event = "onRemove",
            buffName = "Toxic Bolt",
        },
        [2] = {
            type = "attack",
            target = "furthest_enemy",
            attackPercent = 100,
            ignoreThorns = true,
        },
    },
    [290] = { -- Launches a bolt of elemental ash, dealing $s1 Arcane damage to the furthest enemy.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [291] = { -- Fires a torrent of elemental ash, dealing $s1 Arcane damage to all enemies in melee.
        target = "front_enemies",
        type = "attack",
        attackPercent = 100,
    },
    [292] = { -- Duelmaster Rowyn uses an ancient bladed technique, striking at the heart of the closest enemy, dealing $s2 damage, and exposing them to $s1% more damage for two turns.
        -- testing found this one applies the debuff first, then does the damage, counting the debuff for its own damage
        [1] = {
            target = "closest_enemy",
            type = "buff",
            duration = 2,
            changeDamageTakenPercent = 50,
            buffName = "Master's Surprise",
            roundFirst = true,
        },
        [2] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 75,
        },
    },    
    --[293] = {}, -- The Sinstone hurls a large rock, hitting all enemies in melee for $s1 damage.
    [294] = { -- Bashes into the closest enemy, dealing $s1 damage.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 200,
    },
    [295] = { -- The closest enemy gets caught in a torrent of released sin, exposing them to $s1% more damage for two turns.
        target = "closest_enemy",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = 50,
        buffName = "Dreadful Exhaust",
    },
    [296] = { -- Blasts all enemies at range with $s1 Shadow damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 100,
        firstTurn = 2,
    },
    [297] = { -- Draws anima from the furthest enemy, dealing $s1 Shadow damage and healing itself for $s2.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 100,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 30,
        },
    },
    [298] = { -- Bites at a random enemy, dealing $s1 Shadow damage and healing itself for some of the damage.
        [1] = {
            target = "pseudorandom_ritualfervor",
            type = "attack",
            attackPercent = 100,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 30,
        },
    },
    [299] = { -- Deals $s1 Shadow damage to the farthest enemy.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 200,
    },
    [300] = { -- Powerful death magic rolls across the Planes of Torment, causing a stacking damage over time effect to all of your party.
        type = "buff",
        attackPercent = 2,
        target = "all_enemies",
        duration = 3,
        stackLimit = 4,
        buffName = "Wave of Eternal Death (300)",
    },
    [301] = { -- The Jailer sends a bombardment of missles across Calcis, dealing $s1% of their Health as Shadow damage to a random enemy every turn.
        type = "passive",
        target = "pseudorandom_mawswornstrength",
        damageTargetHPPercent = 10,
        buffName = "Bombardment of Dread",
    },
    [302] = { -- Winding tendrils ensnare all enemies, dealing $s1 Nature damage and reducing their damage by 20% for this round.
        [1] = {
            type = "attack",
            attackPercent = 20,
            target = "all_enemies",
            continueIfCasterDies = true,
        },
        [2] = {
            type = "buff",
            target = "all_enemies",
            duration = 1,
            changeDamageDealtPercent = -20,
            buffName = "Bramble Trap",
        }
    },
    [303] = { -- Scream at enemies at range, inflicting $s1 Nature damage each round.
        target = "back_enemies",
        type = "attack",
        attackPercent = 25,
        affectedByTaunt = true,
    }, 
    [305] = { -- Roots strike all enemies at range, inflicting $s1 Nature damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 120,
        affectedByTaunt = true,
    },
    [306] = { -- Increases the damage of the closest ally by $s1 Arcane and their maximum health by $s2 for 3 rounds.
        [1] = {
            type = "buff",
            changeDamageDealtUsingAttack = 40,
            target = "nearby_ally_or_self",
            duration = 3,
            buffName = "Arcane Empowerment (damage)",
        },
        [2] = {
            changeMaxHPUsingAttack = 60,
            target = "nearby_ally_or_self",
            duration = 3,
            type = "buff",
            buffName = "Arcane Empowerment (health)",
        }
    },
    [307] = { -- Smashes the ground, dealing $s1 Nature damage to enemies in a cone emitting from the closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 160,
    },
    [308] = { -- Every 3 rounds, deals $s1 Nature damage to the farthest enemy. This ability does not immediately activate.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 350,
        firstTurn = 2,
        affectedByTaunt = true,
    },
    [309] = { -- Heals all allies for $s1 Nature and increases their damage by 30% for 1 round.
        [1] = {
            target = "all_allies",
            type = "heal",
            healPercent = 200,
        },
        [2] = {
            target = "all_allies",
            type = "buff",
            duration = 1,
            changeDamageDealtPercent = 29.999,
            buffName = "Threads of Fate",
        },
    },
    [310] = { -- Deals $s1 Holy damage to the closest enemy and increases his damage by 20% for 1 round.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 140,
        },
        [2] = {
            target = "self",
            type = "buff",
            duration = 2,
            changeDamageDealtPercent = 20,
            buffName = "Axe of Determination",
        },
    },
    [311] = { -- Heals the closest ally for $s1 and increases their maximum health for $s2 for 2 rounds.
        [1] = {
            target = "closest_ally",
            type = "heal",
            healPercent = 120,
        },
        [2] = {
            target = "closest_ally",
            type = "buff",
            changeMaxHPUsingAttack = 40,
            duration = 2,
            buffName = "Wings of Mending",
        },
    },
    [312] = { -- Deals $s1 Holy damage to enemies in a cone emanating from the closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 180,
        affectedByTaunt = true,
    },
    [313] = { -- Heals all allies for $s1 each round. 
        target = "all_allies",
        type = "heal",
        healPercent = 70,
        skipIfFull = true,
    },
    [314] = { -- Heals the closest ally for $s1 and increases their damage by $s2 Holy for 2 rounds.
        [1] = {
            target = "nearby_ally_or_self",
            type = "heal",
            healPercent = 130,
        },
        [2] = {
            target = "nearby_ally_or_self",
            type = "buff",
            changeDamageDealtUsingAttack = 50,
            duration = 2,
            buffName = "Purifying Light",
        },
    },
    [315] = { -- Blasts the furthest enemy for $s1 Fire damage and reduces their damage dealt by 30% for 2 rounds.
        [1] = {
            target = "furthest_enemy",
            attackPercent = 150,
            type = "attack",
        },
        [2] = {
            type = "buff",
            target = "furthest_enemy",
            duration = 2,
            changeDamageDealtPercent = -30,
            buffName = "Resounding Message",
        }
    },
    [316] = { -- Deals $s1 Shadow damage to the closest enemy and heals for $s2.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 100,
            affectedByTaunt = true,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 30,
        },
    },
    [317] = { -- Deals $s1 Nature damage to all enemies in melee and increases the damage they take this round by $s2.
        [1] = {
            target = "front_enemies",
            type = "attack",
            attackPercent = 150,
        },
        [2] = {
            changeDamageTakenUsingAttack = 30,
            type = "buff",
            target = "front_enemies",
            duration = 1,
            buffName = "Shocking Fist",
        }
    },
    [318] = { -- Increases the damage all allies deal by $s1 Physical for 3 rounds.
        target = "all_allies",
        type = "buff",
        changeDamageDealtUsingAttack = 50,
        duration = 3,
        buffName = "Inspiring Howl",
    },
    [319] = { -- Shatters the armor of enemies in melee range, dealing $s1 Shadow damage and an additional $s2 Shadow damage each round for 3 rounds.
        [1] = {
            type = "attack",
            target = "front_enemies",
            attackPercent = 80,
        },
        [2] = {
            type = "buff",
            target = "front_enemies",
            duration = 3,
            attackPercent = 50,
            event = "beforeAttack",
            buffName = "Shattering Blows",
        }
    },
    [320] = { -- Blasts all enemies at range with $s1 Frost damage.
        target = "back_enemies",
        type = "attack",
        attackPercent = 100,
    },
    [321] = { -- Heals the closest ally for $s1.
        target = "nearby_ally_or_self",
        type = "heal",
        healPercent = 200,
        skipIfFull = true,
    },
    [322] = { -- Deals $s1 Shadow damage, heals himself for $s2, and increases his maximum health by $s3 for 1 round.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 80,
        },
        [2] = {
            target = "self",
            type = "heal",
            healPercent = 80,
        },
        [3] = {
            target = "self",
            type = "buff",
            changeMaxHPUsingAttack = 80,
            duration = 1,
            buffName = "Balance In All Things",
        },
    },
    [323] = { -- Deals $s1 Shadow damage to all enemies at range and reduces the damage they deal by 10% for 2 rounds.
        [1] = {
            target = "back_enemies",
            type = "attack",
            attackPercent = 40,
            continueIfCasterDies = true,
        },
        [2] = {
            target = "back_enemies",
            type = "buff",
            duration = 2,
            changeDamageDealtPercent = -10,
            buffName = "Anima Shatter",
        },
    },
    [324] = { -- Heals all adjacent allies for $s1.
        target = "adjacent_allies_or_all_allies",
        type = "heal",
        healPercent = 120,
        skipIfFull = true,
    },
    [325] = { -- All adjacent allies deal an additional 60% damage for 2 rounds.
        target = "adjacent_allies",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 60,
        buffName = "Vision of Beauty",
    },
    [326] = { -- Deals $s1 Frost damage to all adjacent enemies.
        target = "cleave_enemies",
        type = "attack",
        attackPercent = 25,
    },
    [327] = { -- Increases the damage of all other allies by $s1 Shadow for 3 rounds.
        target = "other_allies",
        type = "buff",
        changeDamageDealtUsingAttack = 20,
        duration = 3,
        buffName = "Inspirational Teachings",
    },
    [328] = { -- Deals $s1 Shadow damage to the closest enemy.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 30,
    },
    [329] = { -- Reduces all damage taken by 50% for 3 rounds.
        target = "self",
        type = "buff",
        duration = 3,
        changeDamageTakenPercent = -50,
        buffName = "Muscle Up",
    },
    [330] = { -- Increases damage dealt by $s1 Fire for 2 rounds.
        target = "all_allies",
        type = "buff",
        changeDamageDealtUsingAttack = 20,
        duration = 2,
        buffName = "Oversight",
    },
    [331] = { -- Allies deal an additional $s1 Fire damage.
        target = "other_allies",
        type = "buff",
        changeDamageDealtUsingAttack = 20,
        duration = 3,
        buffName = "Supporting Fire",
    },
    [332] = { -- Thunk!  Deals $s1 Shadow damage to the furthest enemy.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 150,
    },
    [333] = { -- Increases damage dealt by $s1 for 3 rounds.
        target = "self",
        type = "buff",
        duration = 3,
        changeDamageDealtUsingAttack = 40,
        buffName = "Ogerlode",
    },
    [334] = { -- Deals $s1 Shadow Damage to the closest enemy. Oof, packages this heavy are Evil.
        target = "closest_enemy",
        type = "attack",
        attackPercent = 90,
    },
    [335] = { -- Deals $s1 Arcane damage to all enemies at range.
        target = "back_enemies",
        type = "attack",
        attackPercent = 40,
    },
    [336] = { -- Heal an adjacent ally for $s1.
        target = "nearby_ally_or_self", -- unsure if this spell just behaves differently or do all "cloest_ally" spells behave like this. will treat it as a special case until further info is known
        type = "heal",
        healPercent = 80,
        skipIfFull = true,
    },
    [337] = { -- Deals $s1 Frost damage to the furthest enemy, and an additional $s2 Frost damage each round for 3 rounds.
        [1] = {
            attackPercent = 200,
            target = "furthest_enemy",
            type = "attack",
        },
        [2] = {
            type = "buff",
            target = "furthest_enemy",
            duration = 3,
            attackPercent = 40,
            event = "beforeAttack",
            buffName = "Wavebender's Tide",
        }
    },
    [338] = { -- Deals $s1 Physical damage to the closest enemy.
        type = "attack", 
        target = "closest_enemy", 
        attackPercent = 50,
    },
    [339] = { -- Deals $s1 Fire damage to all enemies. Does not cast immediately.
        target = "all_enemies",
        type = "attack",
        attackPercent = 120,
        firstTurn = 2,
    },
    [340] = { -- Deals $s1 Fire damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 60,
    },
    [341] = { -- Deals $s1 Shadow damage to the furthest enemy and increases their damage taken by $s2 for 3 rounds.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 120,
            continueIfCasterDies = true,
        },
        [2] = {
            changeDamageTakenUsingAttack = 20,
            type = "buff",
            target = "furthest_enemy",
            duration = 3,
            buffName = "Tainted Bite (341)",
        }
    },
    [342] = { -- Deals $s1 Nature damage to the closest enemy each round and reduces their damage dealt by $s2 for the next round.
        [1] = {
            target = "closest_enemy",
            type = "attack",
            attackPercent = 100,
        },
        [2] = {
            target = "closest_enemy",
            type = "buff",
            changeDamageDealtUsingAttack = -70,
            duration = 1,
            buffName = "Regurgitated Meal",
        },
    },
    [343] = { -- Deals $s1 Arcane damage to enemies in melee and increases all damage dealt by 20% for 1 round.
        [1] = {
            target = "front_enemies",
            type = "attack",
            attackPercent = 80,
        },
        [2] = {
            target = "self",
            type = "buff",
            duration = 1,
            changeDamageDealtPercent = 20,
            buffName = "Sharptooth Snarl",
        },
    },
    [344] = { -- Smashes all enemies with ice, dealing $s1 Frost damage.
        target = "all_enemies",
        type = "attack",
        attackPercent = 30,
    },
    [345] = { -- Modifies the damage all allies take by $s1 for 3 rounds.
        target = "all_allies",
        type = "buff",
        changeDamageTakenUsingAttack = -30,
        duration = 3,
        buffName = "Protective Wings",
    },
    [346] = { -- Deals $s1 Nature damage to the closest enemy and reduces their damage by $s2 for 2 rounds.
        [1] = {
            type = "attack",
            target = "closest_enemy",
            attackPercent = 30,
        },
        [2] = {
            type = "buff",
            target = "closest_enemy",
            duration = 2,
            changeDamageDealtUsingAttack = 1, -- apparently the spell is bugged; this should be -1
            buffName = "Heel Bite",
        }
    },
    [347] = { -- Deals $s1 Shadow damage to all enemies in a cone emitting from the closest enemy.
        target = "cone",
        type = "attack",
        attackPercent = 100,
    },
    [348] = { -- Deals $s1 Shadow damage to the furthest enemy and increases their damage taken by $s2 for 3 rounds.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 120,
        },
        [2] = {
            target = "furthest_enemy",
            type = "buff",
            changeDamageTakenUsingAttack = 20,
            duration = 3,
            buffName = "Tainted Bite",
        },
    },
    [349] = { -- Deals $s1 Arcane damage to all enemies
        target = "all_enemies",
        type = "attack",
        attackPercent = 10,
    },
    [350] = { -- Deals $s1 Arcane damage to all adjacent enemies.
        target = "cleave_enemies",
        type = "attack",
        attackPercent = 25,
    },
    [351] = { -- Deals a powerful burst of $s1 Arcane damage to an enemy at range. This ability starts on cooldown.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 75,
        firstTurn = 3,
    },
    [352] = { -- Activates a shield that prevents $s1% damage for two turns.
        type = "passive",
        bugged = true,
        target = "self",
        --type = "buff",
        --target = "self",
        --changeDamageTakenPercent = -53,
        --duration = 2,
        --buffName = "Active Shielding",
    },
    [353] = { -- Projects a disruption field that reduces damage done by an enemy at range for $s1% damage for two turns.
        type = "passive",
        bugged = true,
        target = "self",
        --type = "buff",
        --target = "furthest_enemy",
        --duration = 2,
        --buffName = "Disruptive Field",
        --changeDamageDealtPercent = -46,
    },
    [354] = { -- Deals a powerful burst of $s1 Arcane damage to all enemies in melee. This ability starts on cooldown.
        target = "front_enemies",
        type = "attack",
        attackPercent = 400,
        firstTurn = 4,
    },
    [355] = { -- The Automa projects an aura that disrupts it's opponents. Reducing the damage done by the furthest enemy at range by $s1%.
        target = "furthest_enemy",
        type = "passive",
        changeDamageDealtPercent = -25,
        buffName = "Mitigation Aura (355)",
    },
    [356] = { -- Hidden allies shoot bone shards at all enemies at range, dealing $s1 Physical damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 100,
    },
    [357] = { -- The Worldeater projects an aura that disrupts it's opponents. Reducing the damage done by the closest enemy by $s1%.
        target = "closest_enemy",
        type = "passive",
        changeDamageDealtPercent = -50,
        buffName = "Mitigation Aura (357)",
    },
    [358] = { -- The Worldeater slams the ground, sending out a powerful seismic wave. Dealing $s1 damage to all enemies in melee. This ability starts on cooldown.
        target = "front_enemies",
        type = "attack",
        attackPercent = 400,
        firstTurn = 4,
    },
    [359] = { -- A projection of mental pain that deals  $s1 % Shadow damage for three turns.
        type = "buff",
        attackPercent = 50,
        target = "furthest_enemy",
        duration = 3, -- despite description, only seems to do its damage on the last turn before the buff is removed
        event = "onRemove",
        buffName = "Pain Projection",
    },
    [360] = { -- A violent attempt to draw anima directly from their foe, dealing $s1 Arcane damage to all enemies in melee.
        target = "front_enemies",
        type = "attack",
        attackPercent = 50,
    },
    [361] = { -- Whips up a viscious sandstorm that damages all enemies in melee for $s1 damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 75,
    },
    [362] = { -- Strikes out with their stinger, dealing $s1 Arcane damage to the furthest enemy.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 120,
    },
    [363] = { -- Lets out a snarling howl, inspiring their pack mates, increasing their damage by $s1% for two turns.
        target = "front_allies_only",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = 10,
        buffName = "Pack Instincts",
    },
    [364] = { -- The Orb Smasher looms ominously, forcing all enemies to target them for two turns.
        target = "all_enemies",
        type = "buff",
        taunt = true,
        duration = 2,
        buffName = "Intimidating Presence",
    },
    [365] = { -- Intimidates the closest enemy, causing them to take $s1% more damage for one turn.
        target = "closest_enemy",
        type = "buff",
        duration = 1,
        changeDamageTakenPercent = 50,
        buffName = "Mawsworn Strength",
    },
    [366] = { -- Lashes out with Domination magic, striking at all enemies in melee for $s1 Shadow Damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 50,
    },
    [367] = { -- Lashes out with their spear in a cone from the closest enemy, dealing $s1 shadow damage.
        target = "cone",
        type = "attack",
        attackPercent = 75,
    },
    [368] = { -- Targets enemies at range, calling down a storm of Domination magic, dealing $s1 Shadow damage.
        target = "furthest_enemy",
        type = "attack",
        attackPercent = 60,
    },
    [369] = { -- Stomps on the ground causing a wave of destructive force to ripple outwards, dealing $s1 damage over two turns to all enemies.
        duration = 2,
        type = "buff",
        target = "all_enemies",
        attackPercent = 50,
        event = "onRemove",
        buffName = "Power of Domination",
    },
    [370] = { -- Strikes fear in it's opponents, causing them to do $s1% less damage for two turns.
        target = "all_enemies",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = -50,
        buffName = "Dominating Presence",
    },
    [371] = { -- Releases an aura of anima that infuses its allies with improved reflexes, reducing damage taken by $s1% for two turns.
        target = "other_allies",
        type = "buff",
        duration = 2,
        changeDamageTakenPercent = -25,
        buffName = "Acceleration Field",
    },
    [372] = { -- Makes a powerful swing with their mace, striking all enemies in melee for $s1 damage.
        target = "front_enemies",
        type = "attack",
        attackPercent = 40, -- needs confirmation
    },
    [373] = { -- Draws anima from the furthest enemy, dealing $s1 Arcane damage and healing itself for $s2.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 100,
        },
        [2] = {
            healPercent = 100,
            type = "heal",
            target = "self",
        },
    },
    [374] = { -- Draws anima from the furthest enemy, dealing $s1 Shadow damage and healing itself for $s2.
        [1] = {
            target = "furthest_enemy",
            type = "attack",
            attackPercent = 100,
        },
        [2] = {
            healPercent = 40,
            type = "heal",
            target = "self",
        },
    },
    [375] = { -- The overgrowth impedes all enemies, reducing their damage by $s1 for two turns.
        target = "all_enemies",
        type = "buff",
        duration = 2,
        changeDamageDealtPercent = -20,
        buffName = "Tangling Roots",
    },
}