local __Scripts = LibStub:GetLibrary("ovale/Scripts")
local OvaleScripts = __Scripts.OvaleScripts
do
    local name = "sc_pr_mage_arcane"
    local desc = "[8.0] Simulationcraft: PR_Mage_Arcane"
    local code = [[
# Based on SimulationCraft profile "PR_Mage_Arcane".
#	class=mage
#	spec=arcane
#	talents=2032021

Include(ovale_common)
Include(ovale_trinkets_mop)
Include(ovale_trinkets_wod)
Include(ovale_mage_spells)


AddFunction average_burn_length
{
 { 0 * total_burns() - 0 + GetStateDuration() } / total_burns()
}

AddFunction total_burns
{
 if not GetState(burn_phase) > 0 1
}

AddFunction conserve_mana
{
 60
}

AddCheckBox(opt_interrupt L(interrupt) default specialization=arcane)
AddCheckBox(opt_use_consumables L(opt_use_consumables) default specialization=arcane)
AddCheckBox(opt_arcane_mage_burn_phase L(arcane_mage_burn_phase) default specialization=arcane)
AddCheckBox(opt_time_warp SpellName(time_warp) specialization=arcane)

AddFunction ArcaneInterruptActions
{
 if CheckBoxOn(opt_interrupt) and not target.IsFriend() and target.Casting()
 {
  if target.InRange(quaking_palm) and not target.Classification(worldboss) Spell(quaking_palm)
  if target.InRange(counterspell) and target.IsInterruptible() Spell(counterspell)
 }
}

AddFunction ArcaneUseItemActions
{
 Item(Trinket0Slot text=13 usable=1)
 Item(Trinket1Slot text=14 usable=1)
}

### actions.precombat

AddFunction ArcanePrecombatMainActions
{
 #flask
 #food
 #augmentation
 #arcane_intellect
 Spell(arcane_intellect)
 #summon_arcane_familiar
 Spell(arcane_familiar)
 #arcane_blast
 if Mana() > ManaCost(arcane_blast) Spell(arcane_blast)
}

AddFunction ArcanePrecombatMainPostConditions
{
}

AddFunction ArcanePrecombatShortCdActions
{
}

AddFunction ArcanePrecombatShortCdPostConditions
{
 Spell(arcane_intellect) or Spell(arcane_familiar) or Mana() > ManaCost(arcane_blast) and Spell(arcane_blast)
}

AddFunction ArcanePrecombatCdActions
{
 unless Spell(arcane_intellect) or Spell(arcane_familiar)
 {
  #variable,name=conserve_mana,op=set,value=60
  #snapshot_stats
  #mirror_image
  Spell(mirror_image)
  #potion
  if CheckBoxOn(opt_use_consumables) and target.Classification(worldboss) Item(battle_potion_of_intellect usable=1)
 }
}

AddFunction ArcanePrecombatCdPostConditions
{
 Spell(arcane_intellect) or Spell(arcane_familiar) or Mana() > ManaCost(arcane_blast) and Spell(arcane_blast)
}

### actions.movement

AddFunction ArcaneMovementMainActions
{
 #shimmer,if=movement.distance>=10
 if target.Distance() >= 10 Spell(shimmer)
 #arcane_missiles
 Spell(arcane_missiles)
 #supernova
 Spell(supernova)
}

AddFunction ArcaneMovementMainPostConditions
{
}

AddFunction ArcaneMovementShortCdActions
{
 unless target.Distance() >= 10 and Spell(shimmer)
 {
  #blink,if=movement.distance>=10
  if target.Distance() >= 10 Spell(blink)
  #presence_of_mind
  Spell(presence_of_mind)

  unless Spell(arcane_missiles)
  {
   #arcane_orb
   Spell(arcane_orb)
  }
 }
}

AddFunction ArcaneMovementShortCdPostConditions
{
 target.Distance() >= 10 and Spell(shimmer) or Spell(arcane_missiles) or Spell(supernova)
}

AddFunction ArcaneMovementCdActions
{
}

AddFunction ArcaneMovementCdPostConditions
{
 target.Distance() >= 10 and Spell(shimmer) or target.Distance() >= 10 and Spell(blink) or Spell(presence_of_mind) or Spell(arcane_missiles) or Spell(arcane_orb) or Spell(supernova)
}

### actions.conserve

AddFunction ArcaneConserveMainActions
{
 #nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
 if { target.Refreshable(nether_tempest_debuff) or not target.DebuffPresent(nether_tempest_debuff) } and ArcaneCharges() == MaxArcaneCharges() and BuffExpires(rune_of_power_buff) and BuffExpires(arcane_power_buff) Spell(nether_tempest)
 #arcane_blast,if=buff.rule_of_threes.up&buff.arcane_charge.stack>3
 if DebuffPresent(rule_of_threes) and ArcaneCharges() > 3 and Mana() > ManaCost(arcane_blast) Spell(arcane_blast)
 #arcane_missiles,if=mana.pct<=95&buff.clearcasting.react,chain=1
 if ManaPercent() <= 95 and DebuffPresent(clearcasting) Spell(arcane_missiles)
 #arcane_barrage,if=((buff.arcane_charge.stack=buff.arcane_charge.max_stack)&(mana.pct<=variable.conserve_mana|(cooldown.arcane_power.remains>cooldown.rune_of_power.full_recharge_time&mana.pct<=variable.conserve_mana+25))|(talent.arcane_orb.enabled&cooldown.arcane_orb.remains<=gcd&cooldown.arcane_power.remains>10))|mana.pct<=(variable.conserve_mana-10)
 if ArcaneCharges() == MaxArcaneCharges() and { ManaPercent() <= conserve_mana() or SpellCooldown(arcane_power) > SpellCooldown(rune_of_power) and ManaPercent() <= conserve_mana() + 25 } or Talent(arcane_orb_talent) and SpellCooldown(arcane_orb) <= GCD() and SpellCooldown(arcane_power) > 10 or ManaPercent() <= conserve_mana() - 10 Spell(arcane_barrage)
 #supernova,if=mana.pct<=95
 if ManaPercent() <= 95 Spell(supernova)
 #arcane_explosion,if=active_enemies>=3&(mana.pct>=variable.conserve_mana|buff.arcane_charge.stack=3)
 if Enemies() >= 3 and { ManaPercent() >= conserve_mana() or ArcaneCharges() == 3 } Spell(arcane_explosion)
 #arcane_blast
 if Mana() > ManaCost(arcane_blast) Spell(arcane_blast)
 #arcane_barrage
 Spell(arcane_barrage)
}

AddFunction ArcaneConserveMainPostConditions
{
}

AddFunction ArcaneConserveShortCdActions
{
 #charged_up,if=buff.arcane_charge.stack=0
 if ArcaneCharges() == 0 Spell(charged_up)

 unless { target.Refreshable(nether_tempest_debuff) or not target.DebuffPresent(nether_tempest_debuff) } and ArcaneCharges() == MaxArcaneCharges() and BuffExpires(rune_of_power_buff) and BuffExpires(arcane_power_buff) and Spell(nether_tempest)
 {
  #arcane_orb,if=buff.arcane_charge.stack<=2&(cooldown.arcane_power.remains>10|active_enemies<=2)
  if ArcaneCharges() <= 2 and { SpellCooldown(arcane_power) > 10 or Enemies() <= 2 } Spell(arcane_orb)

  unless DebuffPresent(rule_of_threes) and ArcaneCharges() > 3 and Mana() > ManaCost(arcane_blast) and Spell(arcane_blast)
  {
   #rune_of_power,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&(full_recharge_time<=execute_time|full_recharge_time<=cooldown.arcane_power.remains|target.time_to_die<=cooldown.arcane_power.remains)
   if ArcaneCharges() == MaxArcaneCharges() and { SpellFullRecharge(rune_of_power) <= ExecuteTime(rune_of_power) or SpellFullRecharge(rune_of_power) <= SpellCooldown(arcane_power) or target.TimeToDie() <= SpellCooldown(arcane_power) } Spell(rune_of_power)
  }
 }
}

AddFunction ArcaneConserveShortCdPostConditions
{
 { target.Refreshable(nether_tempest_debuff) or not target.DebuffPresent(nether_tempest_debuff) } and ArcaneCharges() == MaxArcaneCharges() and BuffExpires(rune_of_power_buff) and BuffExpires(arcane_power_buff) and Spell(nether_tempest) or DebuffPresent(rule_of_threes) and ArcaneCharges() > 3 and Mana() > ManaCost(arcane_blast) and Spell(arcane_blast) or ManaPercent() <= 95 and DebuffPresent(clearcasting) and Spell(arcane_missiles) or { ArcaneCharges() == MaxArcaneCharges() and { ManaPercent() <= conserve_mana() or SpellCooldown(arcane_power) > SpellCooldown(rune_of_power) and ManaPercent() <= conserve_mana() + 25 } or Talent(arcane_orb_talent) and SpellCooldown(arcane_orb) <= GCD() and SpellCooldown(arcane_power) > 10 or ManaPercent() <= conserve_mana() - 10 } and Spell(arcane_barrage) or ManaPercent() <= 95 and Spell(supernova) or Enemies() >= 3 and { ManaPercent() >= conserve_mana() or ArcaneCharges() == 3 } and Spell(arcane_explosion) or Mana() > ManaCost(arcane_blast) and Spell(arcane_blast) or Spell(arcane_barrage)
}

AddFunction ArcaneConserveCdActions
{
 #mirror_image
 Spell(mirror_image)
}

AddFunction ArcaneConserveCdPostConditions
{
 ArcaneCharges() == 0 and Spell(charged_up) or { target.Refreshable(nether_tempest_debuff) or not target.DebuffPresent(nether_tempest_debuff) } and ArcaneCharges() == MaxArcaneCharges() and BuffExpires(rune_of_power_buff) and BuffExpires(arcane_power_buff) and Spell(nether_tempest) or ArcaneCharges() <= 2 and { SpellCooldown(arcane_power) > 10 or Enemies() <= 2 } and Spell(arcane_orb) or DebuffPresent(rule_of_threes) and ArcaneCharges() > 3 and Mana() > ManaCost(arcane_blast) and Spell(arcane_blast) or ArcaneCharges() == MaxArcaneCharges() and { SpellFullRecharge(rune_of_power) <= ExecuteTime(rune_of_power) or SpellFullRecharge(rune_of_power) <= SpellCooldown(arcane_power) or target.TimeToDie() <= SpellCooldown(arcane_power) } and Spell(rune_of_power) or ManaPercent() <= 95 and DebuffPresent(clearcasting) and Spell(arcane_missiles) or { ArcaneCharges() == MaxArcaneCharges() and { ManaPercent() <= conserve_mana() or SpellCooldown(arcane_power) > SpellCooldown(rune_of_power) and ManaPercent() <= conserve_mana() + 25 } or Talent(arcane_orb_talent) and SpellCooldown(arcane_orb) <= GCD() and SpellCooldown(arcane_power) > 10 or ManaPercent() <= conserve_mana() - 10 } and Spell(arcane_barrage) or ManaPercent() <= 95 and Spell(supernova) or Enemies() >= 3 and { ManaPercent() >= conserve_mana() or ArcaneCharges() == 3 } and Spell(arcane_explosion) or Mana() > ManaCost(arcane_blast) and Spell(arcane_blast) or Spell(arcane_barrage)
}

### actions.burn

AddFunction ArcaneBurnMainActions
{
 #variable,name=total_burns,op=add,value=1,if=!burn_phase
 #start_burn_phase,if=!burn_phase
 if not GetState(burn_phase) > 0 and not GetState(burn_phase) > 0 SetState(burn_phase 1)
 #stop_burn_phase,if=burn_phase&prev_gcd.1.evocation&target.time_to_die>variable.average_burn_length&burn_phase_duration>0
 if GetState(burn_phase) > 0 and PreviousGCDSpell(evocation) and target.TimeToDie() > average_burn_length() and GetStateDuration() > 0 and GetState(burn_phase) > 0 SetState(burn_phase 0)
 #nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
 if { target.Refreshable(nether_tempest_debuff) or not target.DebuffPresent(nether_tempest_debuff) } and ArcaneCharges() == MaxArcaneCharges() and BuffExpires(rune_of_power_buff) and BuffExpires(arcane_power_buff) Spell(nether_tempest)
 #arcane_blast,if=buff.rule_of_threes.up&talent.overpowered.enabled
 if DebuffPresent(rule_of_threes) and Talent(overpowered_talent) and Mana() > ManaCost(arcane_blast) Spell(arcane_blast)
 #arcane_barrage,if=active_enemies>=3&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
 if Enemies() >= 3 and ArcaneCharges() == MaxArcaneCharges() Spell(arcane_barrage)
 #arcane_explosion,if=active_enemies>=3
 if Enemies() >= 3 Spell(arcane_explosion)
 #arcane_missiles,if=buff.clearcasting.react&active_enemies<3&(talent.amplification.enabled|(!talent.overpowered.enabled&azerite.arcane_pummeling.rank>=2)|buff.arcane_power.down),chain=1
 if DebuffPresent(clearcasting) and Enemies() < 3 and { Talent(amplification_talent) or not Talent(overpowered_talent) and AzeriteTraitRank(arcane_pummeling_trait) >= 2 or BuffExpires(arcane_power_buff) } Spell(arcane_missiles)
 #arcane_blast
 if Mana() > ManaCost(arcane_blast) Spell(arcane_blast)
 #arcane_barrage
 Spell(arcane_barrage)
}

AddFunction ArcaneBurnMainPostConditions
{
}

AddFunction ArcaneBurnShortCdActions
{
 #variable,name=total_burns,op=add,value=1,if=!burn_phase
 #start_burn_phase,if=!burn_phase
 if not GetState(burn_phase) > 0 and not GetState(burn_phase) > 0 SetState(burn_phase 1)
 #stop_burn_phase,if=burn_phase&prev_gcd.1.evocation&target.time_to_die>variable.average_burn_length&burn_phase_duration>0
 if GetState(burn_phase) > 0 and PreviousGCDSpell(evocation) and target.TimeToDie() > average_burn_length() and GetStateDuration() > 0 and GetState(burn_phase) > 0 SetState(burn_phase 0)
 #charged_up,if=buff.arcane_charge.stack<=1
 if ArcaneCharges() <= 1 Spell(charged_up)

 unless { target.Refreshable(nether_tempest_debuff) or not target.DebuffPresent(nether_tempest_debuff) } and ArcaneCharges() == MaxArcaneCharges() and BuffExpires(rune_of_power_buff) and BuffExpires(arcane_power_buff) and Spell(nether_tempest) or DebuffPresent(rule_of_threes) and Talent(overpowered_talent) and Mana() > ManaCost(arcane_blast) and Spell(arcane_blast)
 {
  #rune_of_power,if=!buff.arcane_power.up&(mana.pct>=50|cooldown.arcane_power.remains=0)&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
  if not BuffPresent(arcane_power_buff) and { ManaPercent() >= 50 or not SpellCooldown(arcane_power) > 0 } and ArcaneCharges() == MaxArcaneCharges() Spell(rune_of_power)
  #presence_of_mind,if=buff.rune_of_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time|buff.arcane_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
  if TotemRemaining(rune_of_power) <= SpellData(presence_of_mind_buff max_stacks) * ExecuteTime(arcane_blast) or BuffRemaining(arcane_power_buff) <= SpellData(presence_of_mind_buff max_stacks) * ExecuteTime(arcane_blast) Spell(presence_of_mind)
  #arcane_orb,if=buff.arcane_charge.stack=0|(active_enemies<3|(active_enemies<2&talent.resonance.enabled))
  if ArcaneCharges() == 0 or Enemies() < 3 or Enemies() < 2 and Talent(resonance_talent) Spell(arcane_orb)
 }
}

AddFunction ArcaneBurnShortCdPostConditions
{
 { target.Refreshable(nether_tempest_debuff) or not target.DebuffPresent(nether_tempest_debuff) } and ArcaneCharges() == MaxArcaneCharges() and BuffExpires(rune_of_power_buff) and BuffExpires(arcane_power_buff) and Spell(nether_tempest) or DebuffPresent(rule_of_threes) and Talent(overpowered_talent) and Mana() > ManaCost(arcane_blast) and Spell(arcane_blast) or Enemies() >= 3 and ArcaneCharges() == MaxArcaneCharges() and Spell(arcane_barrage) or Enemies() >= 3 and Spell(arcane_explosion) or DebuffPresent(clearcasting) and Enemies() < 3 and { Talent(amplification_talent) or not Talent(overpowered_talent) and AzeriteTraitRank(arcane_pummeling_trait) >= 2 or BuffExpires(arcane_power_buff) } and Spell(arcane_missiles) or Mana() > ManaCost(arcane_blast) and Spell(arcane_blast) or Spell(arcane_barrage)
}

AddFunction ArcaneBurnCdActions
{
 #variable,name=total_burns,op=add,value=1,if=!burn_phase
 #start_burn_phase,if=!burn_phase
 if not GetState(burn_phase) > 0 and not GetState(burn_phase) > 0 SetState(burn_phase 1)
 #stop_burn_phase,if=burn_phase&prev_gcd.1.evocation&target.time_to_die>variable.average_burn_length&burn_phase_duration>0
 if GetState(burn_phase) > 0 and PreviousGCDSpell(evocation) and target.TimeToDie() > average_burn_length() and GetStateDuration() > 0 and GetState(burn_phase) > 0 SetState(burn_phase 0)
 #mirror_image
 Spell(mirror_image)

 unless ArcaneCharges() <= 1 and Spell(charged_up) or { target.Refreshable(nether_tempest_debuff) or not target.DebuffPresent(nether_tempest_debuff) } and ArcaneCharges() == MaxArcaneCharges() and BuffExpires(rune_of_power_buff) and BuffExpires(arcane_power_buff) and Spell(nether_tempest) or DebuffPresent(rule_of_threes) and Talent(overpowered_talent) and Mana() > ManaCost(arcane_blast) and Spell(arcane_blast)
 {
  #lights_judgment,if=buff.arcane_power.down
  if BuffExpires(arcane_power_buff) Spell(lights_judgment)

  unless not BuffPresent(arcane_power_buff) and { ManaPercent() >= 50 or not SpellCooldown(arcane_power) > 0 } and ArcaneCharges() == MaxArcaneCharges() and Spell(rune_of_power)
  {
   #arcane_power
   Spell(arcane_power)
   #use_items,if=buff.arcane_power.up|target.time_to_die<cooldown.arcane_power.remains
   if BuffPresent(arcane_power_buff) or target.TimeToDie() < SpellCooldown(arcane_power) ArcaneUseItemActions()
   #blood_fury
   Spell(blood_fury_sp)
   #berserking
   Spell(berserking)
   #fireblood
   Spell(fireblood)
   #ancestral_call
   Spell(ancestral_call)

   unless { TotemRemaining(rune_of_power) <= SpellData(presence_of_mind_buff max_stacks) * ExecuteTime(arcane_blast) or BuffRemaining(arcane_power_buff) <= SpellData(presence_of_mind_buff max_stacks) * ExecuteTime(arcane_blast) } and Spell(presence_of_mind)
   {
    #potion,if=buff.arcane_power.up&(buff.berserking.up|buff.blood_fury.up|!(race.troll|race.orc))
    if BuffPresent(arcane_power_buff) and { BuffPresent(berserking_buff) or BuffPresent(blood_fury_sp_buff) or not { Race(Troll) or Race(Orc) } } and CheckBoxOn(opt_use_consumables) and target.Classification(worldboss) Item(battle_potion_of_intellect usable=1)

    unless { ArcaneCharges() == 0 or Enemies() < 3 or Enemies() < 2 and Talent(resonance_talent) } and Spell(arcane_orb) or Enemies() >= 3 and ArcaneCharges() == MaxArcaneCharges() and Spell(arcane_barrage) or Enemies() >= 3 and Spell(arcane_explosion) or DebuffPresent(clearcasting) and Enemies() < 3 and { Talent(amplification_talent) or not Talent(overpowered_talent) and AzeriteTraitRank(arcane_pummeling_trait) >= 2 or BuffExpires(arcane_power_buff) } and Spell(arcane_missiles) or Mana() > ManaCost(arcane_blast) and Spell(arcane_blast)
    {
     #variable,name=average_burn_length,op=set,value=(variable.average_burn_length*variable.total_burns-variable.average_burn_length+(burn_phase_duration))%variable.total_burns
     #evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
     Spell(evocation)
    }
   }
  }
 }
}

AddFunction ArcaneBurnCdPostConditions
{
 ArcaneCharges() <= 1 and Spell(charged_up) or { target.Refreshable(nether_tempest_debuff) or not target.DebuffPresent(nether_tempest_debuff) } and ArcaneCharges() == MaxArcaneCharges() and BuffExpires(rune_of_power_buff) and BuffExpires(arcane_power_buff) and Spell(nether_tempest) or DebuffPresent(rule_of_threes) and Talent(overpowered_talent) and Mana() > ManaCost(arcane_blast) and Spell(arcane_blast) or not BuffPresent(arcane_power_buff) and { ManaPercent() >= 50 or not SpellCooldown(arcane_power) > 0 } and ArcaneCharges() == MaxArcaneCharges() and Spell(rune_of_power) or { TotemRemaining(rune_of_power) <= SpellData(presence_of_mind_buff max_stacks) * ExecuteTime(arcane_blast) or BuffRemaining(arcane_power_buff) <= SpellData(presence_of_mind_buff max_stacks) * ExecuteTime(arcane_blast) } and Spell(presence_of_mind) or { ArcaneCharges() == 0 or Enemies() < 3 or Enemies() < 2 and Talent(resonance_talent) } and Spell(arcane_orb) or Enemies() >= 3 and ArcaneCharges() == MaxArcaneCharges() and Spell(arcane_barrage) or Enemies() >= 3 and Spell(arcane_explosion) or DebuffPresent(clearcasting) and Enemies() < 3 and { Talent(amplification_talent) or not Talent(overpowered_talent) and AzeriteTraitRank(arcane_pummeling_trait) >= 2 or BuffExpires(arcane_power_buff) } and Spell(arcane_missiles) or Mana() > ManaCost(arcane_blast) and Spell(arcane_blast) or Spell(arcane_barrage)
}

### actions.default

AddFunction ArcaneDefaultMainActions
{
 #call_action_list,name=burn,if=burn_phase|target.time_to_die<variable.average_burn_length|(cooldown.arcane_power.remains=0&cooldown.evocation.remains<=variable.average_burn_length&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|(talent.charged_up.enabled&cooldown.charged_up.remains=0)))
 if { GetState(burn_phase) > 0 or target.TimeToDie() < average_burn_length() or not SpellCooldown(arcane_power) > 0 and SpellCooldown(evocation) <= average_burn_length() and { ArcaneCharges() == MaxArcaneCharges() or Talent(charged_up_talent) and not SpellCooldown(charged_up) > 0 } } and CheckBoxOn(opt_arcane_mage_burn_phase) ArcaneBurnMainActions()

 unless { GetState(burn_phase) > 0 or target.TimeToDie() < average_burn_length() or not SpellCooldown(arcane_power) > 0 and SpellCooldown(evocation) <= average_burn_length() and { ArcaneCharges() == MaxArcaneCharges() or Talent(charged_up_talent) and not SpellCooldown(charged_up) > 0 } } and CheckBoxOn(opt_arcane_mage_burn_phase) and ArcaneBurnMainPostConditions()
 {
  #call_action_list,name=conserve,if=!burn_phase
  if not GetState(burn_phase) > 0 ArcaneConserveMainActions()

  unless not GetState(burn_phase) > 0 and ArcaneConserveMainPostConditions()
  {
   #call_action_list,name=movement
   ArcaneMovementMainActions()
  }
 }
}

AddFunction ArcaneDefaultMainPostConditions
{
 { GetState(burn_phase) > 0 or target.TimeToDie() < average_burn_length() or not SpellCooldown(arcane_power) > 0 and SpellCooldown(evocation) <= average_burn_length() and { ArcaneCharges() == MaxArcaneCharges() or Talent(charged_up_talent) and not SpellCooldown(charged_up) > 0 } } and CheckBoxOn(opt_arcane_mage_burn_phase) and ArcaneBurnMainPostConditions() or not GetState(burn_phase) > 0 and ArcaneConserveMainPostConditions() or ArcaneMovementMainPostConditions()
}

AddFunction ArcaneDefaultShortCdActions
{
 #call_action_list,name=burn,if=burn_phase|target.time_to_die<variable.average_burn_length|(cooldown.arcane_power.remains=0&cooldown.evocation.remains<=variable.average_burn_length&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|(talent.charged_up.enabled&cooldown.charged_up.remains=0)))
 if { GetState(burn_phase) > 0 or target.TimeToDie() < average_burn_length() or not SpellCooldown(arcane_power) > 0 and SpellCooldown(evocation) <= average_burn_length() and { ArcaneCharges() == MaxArcaneCharges() or Talent(charged_up_talent) and not SpellCooldown(charged_up) > 0 } } and CheckBoxOn(opt_arcane_mage_burn_phase) ArcaneBurnShortCdActions()

 unless { GetState(burn_phase) > 0 or target.TimeToDie() < average_burn_length() or not SpellCooldown(arcane_power) > 0 and SpellCooldown(evocation) <= average_burn_length() and { ArcaneCharges() == MaxArcaneCharges() or Talent(charged_up_talent) and not SpellCooldown(charged_up) > 0 } } and CheckBoxOn(opt_arcane_mage_burn_phase) and ArcaneBurnShortCdPostConditions()
 {
  #call_action_list,name=conserve,if=!burn_phase
  if not GetState(burn_phase) > 0 ArcaneConserveShortCdActions()

  unless not GetState(burn_phase) > 0 and ArcaneConserveShortCdPostConditions()
  {
   #call_action_list,name=movement
   ArcaneMovementShortCdActions()
  }
 }
}

AddFunction ArcaneDefaultShortCdPostConditions
{
 { GetState(burn_phase) > 0 or target.TimeToDie() < average_burn_length() or not SpellCooldown(arcane_power) > 0 and SpellCooldown(evocation) <= average_burn_length() and { ArcaneCharges() == MaxArcaneCharges() or Talent(charged_up_talent) and not SpellCooldown(charged_up) > 0 } } and CheckBoxOn(opt_arcane_mage_burn_phase) and ArcaneBurnShortCdPostConditions() or not GetState(burn_phase) > 0 and ArcaneConserveShortCdPostConditions() or ArcaneMovementShortCdPostConditions()
}

AddFunction ArcaneDefaultCdActions
{
 #counterspell,if=target.debuff.casting.react
 if target.IsInterruptible() ArcaneInterruptActions()
 #time_warp,if=time=0&buff.bloodlust.down
 if TimeInCombat() == 0 and BuffExpires(burst_haste_buff any=1) and CheckBoxOn(opt_time_warp) and DebuffExpires(burst_haste_debuff any=1) Spell(time_warp)
 #call_action_list,name=burn,if=burn_phase|target.time_to_die<variable.average_burn_length|(cooldown.arcane_power.remains=0&cooldown.evocation.remains<=variable.average_burn_length&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|(talent.charged_up.enabled&cooldown.charged_up.remains=0)))
 if { GetState(burn_phase) > 0 or target.TimeToDie() < average_burn_length() or not SpellCooldown(arcane_power) > 0 and SpellCooldown(evocation) <= average_burn_length() and { ArcaneCharges() == MaxArcaneCharges() or Talent(charged_up_talent) and not SpellCooldown(charged_up) > 0 } } and CheckBoxOn(opt_arcane_mage_burn_phase) ArcaneBurnCdActions()

 unless { GetState(burn_phase) > 0 or target.TimeToDie() < average_burn_length() or not SpellCooldown(arcane_power) > 0 and SpellCooldown(evocation) <= average_burn_length() and { ArcaneCharges() == MaxArcaneCharges() or Talent(charged_up_talent) and not SpellCooldown(charged_up) > 0 } } and CheckBoxOn(opt_arcane_mage_burn_phase) and ArcaneBurnCdPostConditions()
 {
  #call_action_list,name=conserve,if=!burn_phase
  if not GetState(burn_phase) > 0 ArcaneConserveCdActions()

  unless not GetState(burn_phase) > 0 and ArcaneConserveCdPostConditions()
  {
   #call_action_list,name=movement
   ArcaneMovementCdActions()
  }
 }
}

AddFunction ArcaneDefaultCdPostConditions
{
 { GetState(burn_phase) > 0 or target.TimeToDie() < average_burn_length() or not SpellCooldown(arcane_power) > 0 and SpellCooldown(evocation) <= average_burn_length() and { ArcaneCharges() == MaxArcaneCharges() or Talent(charged_up_talent) and not SpellCooldown(charged_up) > 0 } } and CheckBoxOn(opt_arcane_mage_burn_phase) and ArcaneBurnCdPostConditions() or not GetState(burn_phase) > 0 and ArcaneConserveCdPostConditions() or ArcaneMovementCdPostConditions()
}

### Arcane icons.

AddCheckBox(opt_mage_arcane_aoe L(AOE) default specialization=arcane)

AddIcon checkbox=!opt_mage_arcane_aoe enemies=1 help=shortcd specialization=arcane
{
 if not InCombat() ArcanePrecombatShortCdActions()
 unless not InCombat() and ArcanePrecombatShortCdPostConditions()
 {
  ArcaneDefaultShortCdActions()
 }
}

AddIcon checkbox=opt_mage_arcane_aoe help=shortcd specialization=arcane
{
 if not InCombat() ArcanePrecombatShortCdActions()
 unless not InCombat() and ArcanePrecombatShortCdPostConditions()
 {
  ArcaneDefaultShortCdActions()
 }
}

AddIcon enemies=1 help=main specialization=arcane
{
 if not InCombat() ArcanePrecombatMainActions()
 unless not InCombat() and ArcanePrecombatMainPostConditions()
 {
  ArcaneDefaultMainActions()
 }
}

AddIcon checkbox=opt_mage_arcane_aoe help=aoe specialization=arcane
{
 if not InCombat() ArcanePrecombatMainActions()
 unless not InCombat() and ArcanePrecombatMainPostConditions()
 {
  ArcaneDefaultMainActions()
 }
}

AddIcon checkbox=!opt_mage_arcane_aoe enemies=1 help=cd specialization=arcane
{
 if not InCombat() ArcanePrecombatCdActions()
 unless not InCombat() and ArcanePrecombatCdPostConditions()
 {
  ArcaneDefaultCdActions()
 }
}

AddIcon checkbox=opt_mage_arcane_aoe help=cd specialization=arcane
{
 if not InCombat() ArcanePrecombatCdActions()
 unless not InCombat() and ArcanePrecombatCdPostConditions()
 {
  ArcaneDefaultCdActions()
 }
}

### Required symbols
# amplification_talent
# ancestral_call
# arcane_barrage
# arcane_blast
# arcane_explosion
# arcane_familiar
# arcane_intellect
# arcane_missiles
# arcane_orb
# arcane_orb_talent
# arcane_power
# arcane_power_buff
# arcane_pummeling_trait
# battle_potion_of_intellect
# berserking
# berserking_buff
# blink
# blood_fury_sp
# blood_fury_sp_buff
# charged_up
# charged_up_talent
# clearcasting
# counterspell
# evocation
# fireblood
# lights_judgment
# mirror_image
# nether_tempest
# nether_tempest_debuff
# overpowered_talent
# presence_of_mind
# presence_of_mind_buff
# quaking_palm
# resonance_talent
# rule_of_threes
# rune_of_power
# rune_of_power_buff
# shimmer
# supernova
# time_warp
]]
    OvaleScripts:RegisterScript("MAGE", "arcane", name, desc, code, "script")
end
do
    local name = "sc_pr_mage_fire"
    local desc = "[8.0] Simulationcraft: PR_Mage_Fire"
    local code = [[
# Based on SimulationCraft profile "PR_Mage_Fire".
#	class=mage
#	spec=fire
#	talents=1031023

Include(ovale_common)
Include(ovale_trinkets_mop)
Include(ovale_trinkets_wod)
Include(ovale_mage_spells)

AddCheckBox(opt_interrupt L(interrupt) default specialization=fire)
AddCheckBox(opt_use_consumables L(opt_use_consumables) default specialization=fire)
AddCheckBox(opt_time_warp SpellName(time_warp) specialization=fire)

AddFunction FireInterruptActions
{
 if CheckBoxOn(opt_interrupt) and not target.IsFriend() and target.Casting()
 {
  if target.InRange(quaking_palm) and not target.Classification(worldboss) Spell(quaking_palm)
  if target.InRange(counterspell) and target.IsInterruptible() Spell(counterspell)
 }
}

AddFunction FireUseItemActions
{
 Item(Trinket0Slot text=13 usable=1)
 Item(Trinket1Slot text=14 usable=1)
}

### actions.standard_rotation

AddFunction FireStandardrotationMainActions
{
 #flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>4)&buff.hot_streak.react
 if { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) Spell(flamestrike)
 #pyroblast,if=buff.hot_streak.react&buff.hot_streak.remains<action.fireball.execute_time
 if BuffPresent(hot_streak_buff) and BuffRemaining(hot_streak_buff) < ExecuteTime(fireball) Spell(pyroblast)
 #pyroblast,if=buff.hot_streak.react&firestarter.active&!talent.rune_of_power.enabled
 if BuffPresent(hot_streak_buff) and Talent(firestarter_talent) and target.HealthPercent() >= 90 and not Talent(rune_of_power_talent) Spell(pyroblast)
 #pyroblast,if=buff.hot_streak.react&(!prev_gcd.1.pyroblast|action.pyroblast.in_flight)
 if BuffPresent(hot_streak_buff) and { not PreviousGCDSpell(pyroblast) or InFlightToTarget(pyroblast) } Spell(pyroblast)
 #pyroblast,if=buff.hot_streak.react&target.health.pct<=30&talent.searing_touch.enabled
 if BuffPresent(hot_streak_buff) and target.HealthPercent() <= 30 and Talent(searing_touch_talent) Spell(pyroblast)
 #pyroblast,if=buff.pyroclasm.react&execute_time<buff.pyroclasm.remains
 if DebuffPresent(pyroclasm) and ExecuteTime(pyroblast) < DebuffRemaining(pyroclasm) Spell(pyroblast)
 #call_action_list,name=active_talents
 FireActivetalentsMainActions()

 unless FireActivetalentsMainPostConditions()
 {
  #fire_blast,if=!talent.kindling.enabled&buff.heating_up.react&(!talent.rune_of_power.enabled|charges_fractional>1.4|cooldown.combustion.remains<40)&(3-charges_fractional)*(12*spell_haste)<cooldown.combustion.remains+3|target.time_to_die<4
  if not Talent(kindling_talent) and BuffPresent(heating_up_buff) and { not Talent(rune_of_power_talent) or Charges(fire_blast count=0) > 1.4 or SpellCooldown(combustion) < 40 } and { 3 - Charges(fire_blast count=0) } * 12 * { 100 / { 100 + SpellCastSpeedPercent() } } < SpellCooldown(combustion) + 3 or target.TimeToDie() < 4 Spell(fire_blast)
  #fire_blast,if=talent.kindling.enabled&buff.heating_up.react&(!talent.rune_of_power.enabled|charges_fractional>1.5|cooldown.combustion.remains<40)&(3-charges_fractional)*(18*spell_haste)<cooldown.combustion.remains+3|target.time_to_die<4
  if Talent(kindling_talent) and BuffPresent(heating_up_buff) and { not Talent(rune_of_power_talent) or Charges(fire_blast count=0) > 1.5 or SpellCooldown(combustion) < 40 } and { 3 - Charges(fire_blast count=0) } * 18 * { 100 / { 100 + SpellCastSpeedPercent() } } < SpellCooldown(combustion) + 3 or target.TimeToDie() < 4 Spell(fire_blast)
  #scorch,if=(target.health.pct<=30&talent.searing_touch.enabled)|(azerite.preheat.enabled&debuff.preheat.down)
  if target.HealthPercent() <= 30 and Talent(searing_touch_talent) or HasAzeriteTrait(preheat_trait) and target.DebuffExpires(preheat) Spell(scorch)
  #fireball
  Spell(fireball)
  #scorch
  Spell(scorch)
 }
}

AddFunction FireStandardrotationMainPostConditions
{
 FireActivetalentsMainPostConditions()
}

AddFunction FireStandardrotationShortCdActions
{
 unless { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or BuffPresent(hot_streak_buff) and BuffRemaining(hot_streak_buff) < ExecuteTime(fireball) and Spell(pyroblast) or BuffPresent(hot_streak_buff) and Talent(firestarter_talent) and target.HealthPercent() >= 90 and not Talent(rune_of_power_talent) and Spell(pyroblast)
 {
  #phoenix_flames,if=charges_fractional>2.7&active_enemies>2
  if Charges(phoenix_flames count=0) > 2.7 and Enemies() > 2 Spell(phoenix_flames)

  unless BuffPresent(hot_streak_buff) and { not PreviousGCDSpell(pyroblast) or InFlightToTarget(pyroblast) } and Spell(pyroblast) or BuffPresent(hot_streak_buff) and target.HealthPercent() <= 30 and Talent(searing_touch_talent) and Spell(pyroblast) or DebuffPresent(pyroclasm) and ExecuteTime(pyroblast) < DebuffRemaining(pyroclasm) and Spell(pyroblast)
  {
   #call_action_list,name=active_talents
   FireActivetalentsShortCdActions()

   unless FireActivetalentsShortCdPostConditions() or { not Talent(kindling_talent) and BuffPresent(heating_up_buff) and { not Talent(rune_of_power_talent) or Charges(fire_blast count=0) > 1.4 or SpellCooldown(combustion) < 40 } and { 3 - Charges(fire_blast count=0) } * 12 * { 100 / { 100 + SpellCastSpeedPercent() } } < SpellCooldown(combustion) + 3 or target.TimeToDie() < 4 } and Spell(fire_blast) or { Talent(kindling_talent) and BuffPresent(heating_up_buff) and { not Talent(rune_of_power_talent) or Charges(fire_blast count=0) > 1.5 or SpellCooldown(combustion) < 40 } and { 3 - Charges(fire_blast count=0) } * 18 * { 100 / { 100 + SpellCastSpeedPercent() } } < SpellCooldown(combustion) + 3 or target.TimeToDie() < 4 } and Spell(fire_blast)
   {
    #phoenix_flames,if=(buff.combustion.up|buff.rune_of_power.up|buff.incanters_flow.stack>3|talent.mirror_image.enabled)&(4-charges_fractional)*13<cooldown.combustion.remains+5|target.time_to_die<10
    if { BuffPresent(combustion_buff) or BuffPresent(rune_of_power_buff) or BuffStacks(incanters_flow_buff) > 3 or Talent(mirror_image_talent) } and { 4 - Charges(phoenix_flames count=0) } * 13 < SpellCooldown(combustion) + 5 or target.TimeToDie() < 10 Spell(phoenix_flames)
    #phoenix_flames,if=(buff.combustion.up|buff.rune_of_power.up)&(4-charges_fractional)*30<cooldown.combustion.remains+5
    if { BuffPresent(combustion_buff) or BuffPresent(rune_of_power_buff) } and { 4 - Charges(phoenix_flames count=0) } * 30 < SpellCooldown(combustion) + 5 Spell(phoenix_flames)
    #phoenix_flames,if=charges_fractional>2.5&cooldown.combustion.remains>23
    if Charges(phoenix_flames count=0) > 2.5 and SpellCooldown(combustion) > 23 Spell(phoenix_flames)
   }
  }
 }
}

AddFunction FireStandardrotationShortCdPostConditions
{
 { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or BuffPresent(hot_streak_buff) and BuffRemaining(hot_streak_buff) < ExecuteTime(fireball) and Spell(pyroblast) or BuffPresent(hot_streak_buff) and Talent(firestarter_talent) and target.HealthPercent() >= 90 and not Talent(rune_of_power_talent) and Spell(pyroblast) or BuffPresent(hot_streak_buff) and { not PreviousGCDSpell(pyroblast) or InFlightToTarget(pyroblast) } and Spell(pyroblast) or BuffPresent(hot_streak_buff) and target.HealthPercent() <= 30 and Talent(searing_touch_talent) and Spell(pyroblast) or DebuffPresent(pyroclasm) and ExecuteTime(pyroblast) < DebuffRemaining(pyroclasm) and Spell(pyroblast) or FireActivetalentsShortCdPostConditions() or { not Talent(kindling_talent) and BuffPresent(heating_up_buff) and { not Talent(rune_of_power_talent) or Charges(fire_blast count=0) > 1.4 or SpellCooldown(combustion) < 40 } and { 3 - Charges(fire_blast count=0) } * 12 * { 100 / { 100 + SpellCastSpeedPercent() } } < SpellCooldown(combustion) + 3 or target.TimeToDie() < 4 } and Spell(fire_blast) or { Talent(kindling_talent) and BuffPresent(heating_up_buff) and { not Talent(rune_of_power_talent) or Charges(fire_blast count=0) > 1.5 or SpellCooldown(combustion) < 40 } and { 3 - Charges(fire_blast count=0) } * 18 * { 100 / { 100 + SpellCastSpeedPercent() } } < SpellCooldown(combustion) + 3 or target.TimeToDie() < 4 } and Spell(fire_blast) or { target.HealthPercent() <= 30 and Talent(searing_touch_talent) or HasAzeriteTrait(preheat_trait) and target.DebuffExpires(preheat) } and Spell(scorch) or Spell(fireball) or Spell(scorch)
}

AddFunction FireStandardrotationCdActions
{
 unless { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or BuffPresent(hot_streak_buff) and BuffRemaining(hot_streak_buff) < ExecuteTime(fireball) and Spell(pyroblast) or BuffPresent(hot_streak_buff) and Talent(firestarter_talent) and target.HealthPercent() >= 90 and not Talent(rune_of_power_talent) and Spell(pyroblast) or Charges(phoenix_flames count=0) > 2.7 and Enemies() > 2 and Spell(phoenix_flames) or BuffPresent(hot_streak_buff) and { not PreviousGCDSpell(pyroblast) or InFlightToTarget(pyroblast) } and Spell(pyroblast) or BuffPresent(hot_streak_buff) and target.HealthPercent() <= 30 and Talent(searing_touch_talent) and Spell(pyroblast) or DebuffPresent(pyroclasm) and ExecuteTime(pyroblast) < DebuffRemaining(pyroclasm) and Spell(pyroblast)
 {
  #call_action_list,name=active_talents
  FireActivetalentsCdActions()
 }
}

AddFunction FireStandardrotationCdPostConditions
{
 { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or BuffPresent(hot_streak_buff) and BuffRemaining(hot_streak_buff) < ExecuteTime(fireball) and Spell(pyroblast) or BuffPresent(hot_streak_buff) and Talent(firestarter_talent) and target.HealthPercent() >= 90 and not Talent(rune_of_power_talent) and Spell(pyroblast) or Charges(phoenix_flames count=0) > 2.7 and Enemies() > 2 and Spell(phoenix_flames) or BuffPresent(hot_streak_buff) and { not PreviousGCDSpell(pyroblast) or InFlightToTarget(pyroblast) } and Spell(pyroblast) or BuffPresent(hot_streak_buff) and target.HealthPercent() <= 30 and Talent(searing_touch_talent) and Spell(pyroblast) or DebuffPresent(pyroclasm) and ExecuteTime(pyroblast) < DebuffRemaining(pyroclasm) and Spell(pyroblast) or FireActivetalentsCdPostConditions() or { not Talent(kindling_talent) and BuffPresent(heating_up_buff) and { not Talent(rune_of_power_talent) or Charges(fire_blast count=0) > 1.4 or SpellCooldown(combustion) < 40 } and { 3 - Charges(fire_blast count=0) } * 12 * { 100 / { 100 + SpellCastSpeedPercent() } } < SpellCooldown(combustion) + 3 or target.TimeToDie() < 4 } and Spell(fire_blast) or { Talent(kindling_talent) and BuffPresent(heating_up_buff) and { not Talent(rune_of_power_talent) or Charges(fire_blast count=0) > 1.5 or SpellCooldown(combustion) < 40 } and { 3 - Charges(fire_blast count=0) } * 18 * { 100 / { 100 + SpellCastSpeedPercent() } } < SpellCooldown(combustion) + 3 or target.TimeToDie() < 4 } and Spell(fire_blast) or { { BuffPresent(combustion_buff) or BuffPresent(rune_of_power_buff) or BuffStacks(incanters_flow_buff) > 3 or Talent(mirror_image_talent) } and { 4 - Charges(phoenix_flames count=0) } * 13 < SpellCooldown(combustion) + 5 or target.TimeToDie() < 10 } and Spell(phoenix_flames) or { BuffPresent(combustion_buff) or BuffPresent(rune_of_power_buff) } and { 4 - Charges(phoenix_flames count=0) } * 30 < SpellCooldown(combustion) + 5 and Spell(phoenix_flames) or Charges(phoenix_flames count=0) > 2.5 and SpellCooldown(combustion) > 23 and Spell(phoenix_flames) or { target.HealthPercent() <= 30 and Talent(searing_touch_talent) or HasAzeriteTrait(preheat_trait) and target.DebuffExpires(preheat) } and Spell(scorch) or Spell(fireball) or Spell(scorch)
}

### actions.rop_phase

AddFunction FireRopphaseMainActions
{
 #flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>4)&buff.hot_streak.react
 if { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) Spell(flamestrike)
 #pyroblast,if=buff.hot_streak.react
 if BuffPresent(hot_streak_buff) Spell(pyroblast)
 #call_action_list,name=active_talents
 FireActivetalentsMainActions()

 unless FireActivetalentsMainPostConditions()
 {
  #pyroblast,if=buff.pyroclasm.react&execute_time<buff.pyroclasm.remains&buff.rune_of_power.remains>cast_time
  if DebuffPresent(pyroclasm) and ExecuteTime(pyroblast) < DebuffRemaining(pyroclasm) and TotemRemaining(rune_of_power) > CastTime(pyroblast) Spell(pyroblast)
  #fire_blast,if=!prev_off_gcd.fire_blast&buff.heating_up.react&firestarter.active&charges_fractional>1.7
  if not PreviousOffGCDSpell(fire_blast) and BuffPresent(heating_up_buff) and Talent(firestarter_talent) and target.HealthPercent() >= 90 and Charges(fire_blast count=0) > 1.7 Spell(fire_blast)
  #fire_blast,if=!prev_off_gcd.fire_blast&!firestarter.active
  if not PreviousOffGCDSpell(fire_blast) and not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } Spell(fire_blast)
  #scorch,if=target.health.pct<=30&talent.searing_touch.enabled
  if target.HealthPercent() <= 30 and Talent(searing_touch_talent) Spell(scorch)
  #flamestrike,if=(talent.flame_patch.enabled&active_enemies>2)|active_enemies>5
  if Talent(flame_patch_talent) and Enemies() > 2 or Enemies() > 5 Spell(flamestrike)
  #fireball
  Spell(fireball)
 }
}

AddFunction FireRopphaseMainPostConditions
{
 FireActivetalentsMainPostConditions()
}

AddFunction FireRopphaseShortCdActions
{
 #rune_of_power
 Spell(rune_of_power)

 unless { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or BuffPresent(hot_streak_buff) and Spell(pyroblast)
 {
  #call_action_list,name=active_talents
  FireActivetalentsShortCdActions()

  unless FireActivetalentsShortCdPostConditions() or DebuffPresent(pyroclasm) and ExecuteTime(pyroblast) < DebuffRemaining(pyroclasm) and TotemRemaining(rune_of_power) > CastTime(pyroblast) and Spell(pyroblast) or not PreviousOffGCDSpell(fire_blast) and BuffPresent(heating_up_buff) and Talent(firestarter_talent) and target.HealthPercent() >= 90 and Charges(fire_blast count=0) > 1.7 and Spell(fire_blast)
  {
   #phoenix_flames,if=!prev_gcd.1.phoenix_flames&charges_fractional>2.7&firestarter.active
   if not PreviousGCDSpell(phoenix_flames) and Charges(phoenix_flames count=0) > 2.7 and Talent(firestarter_talent) and target.HealthPercent() >= 90 Spell(phoenix_flames)

   unless not PreviousOffGCDSpell(fire_blast) and not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } and Spell(fire_blast)
   {
    #phoenix_flames,if=!prev_gcd.1.phoenix_flames
    if not PreviousGCDSpell(phoenix_flames) Spell(phoenix_flames)

    unless target.HealthPercent() <= 30 and Talent(searing_touch_talent) and Spell(scorch)
    {
     #dragons_breath,if=active_enemies>2
     if Enemies() > 2 and target.Distance(less 12) Spell(dragons_breath)
    }
   }
  }
 }
}

AddFunction FireRopphaseShortCdPostConditions
{
 { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or BuffPresent(hot_streak_buff) and Spell(pyroblast) or FireActivetalentsShortCdPostConditions() or DebuffPresent(pyroclasm) and ExecuteTime(pyroblast) < DebuffRemaining(pyroclasm) and TotemRemaining(rune_of_power) > CastTime(pyroblast) and Spell(pyroblast) or not PreviousOffGCDSpell(fire_blast) and BuffPresent(heating_up_buff) and Talent(firestarter_talent) and target.HealthPercent() >= 90 and Charges(fire_blast count=0) > 1.7 and Spell(fire_blast) or not PreviousOffGCDSpell(fire_blast) and not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } and Spell(fire_blast) or target.HealthPercent() <= 30 and Talent(searing_touch_talent) and Spell(scorch) or { Talent(flame_patch_talent) and Enemies() > 2 or Enemies() > 5 } and Spell(flamestrike) or Spell(fireball)
}

AddFunction FireRopphaseCdActions
{
 unless Spell(rune_of_power) or { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or BuffPresent(hot_streak_buff) and Spell(pyroblast)
 {
  #call_action_list,name=active_talents
  FireActivetalentsCdActions()
 }
}

AddFunction FireRopphaseCdPostConditions
{
 Spell(rune_of_power) or { Talent(flame_patch_talent) and Enemies() > 1 or Enemies() > 4 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or BuffPresent(hot_streak_buff) and Spell(pyroblast) or FireActivetalentsCdPostConditions() or DebuffPresent(pyroclasm) and ExecuteTime(pyroblast) < DebuffRemaining(pyroclasm) and TotemRemaining(rune_of_power) > CastTime(pyroblast) and Spell(pyroblast) or not PreviousOffGCDSpell(fire_blast) and BuffPresent(heating_up_buff) and Talent(firestarter_talent) and target.HealthPercent() >= 90 and Charges(fire_blast count=0) > 1.7 and Spell(fire_blast) or not PreviousGCDSpell(phoenix_flames) and Charges(phoenix_flames count=0) > 2.7 and Talent(firestarter_talent) and target.HealthPercent() >= 90 and Spell(phoenix_flames) or not PreviousOffGCDSpell(fire_blast) and not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } and Spell(fire_blast) or not PreviousGCDSpell(phoenix_flames) and Spell(phoenix_flames) or target.HealthPercent() <= 30 and Talent(searing_touch_talent) and Spell(scorch) or Enemies() > 2 and target.Distance(less 12) and Spell(dragons_breath) or { Talent(flame_patch_talent) and Enemies() > 2 or Enemies() > 5 } and Spell(flamestrike) or Spell(fireball)
}

### actions.precombat

AddFunction FirePrecombatMainActions
{
 #flask
 #food
 #augmentation
 #arcane_intellect
 Spell(arcane_intellect)
 #pyroblast
 Spell(pyroblast)
}

AddFunction FirePrecombatMainPostConditions
{
}

AddFunction FirePrecombatShortCdActions
{
}

AddFunction FirePrecombatShortCdPostConditions
{
 Spell(arcane_intellect) or Spell(pyroblast)
}

AddFunction FirePrecombatCdActions
{
 unless Spell(arcane_intellect)
 {
  #snapshot_stats
  #mirror_image
  Spell(mirror_image)
  #potion
  if CheckBoxOn(opt_use_consumables) and target.Classification(worldboss) Item(battle_potion_of_intellect usable=1)
 }
}

AddFunction FirePrecombatCdPostConditions
{
 Spell(arcane_intellect) or Spell(pyroblast)
}

### actions.combustion_phase

AddFunction FireCombustionphaseMainActions
{
 #call_action_list,name=active_talents
 FireActivetalentsMainActions()

 unless FireActivetalentsMainPostConditions()
 {
  #flamestrike,if=((talent.flame_patch.enabled&active_enemies>2)|active_enemies>6)&buff.hot_streak.react
  if { Talent(flame_patch_talent) and Enemies() > 2 or Enemies() > 6 } and BuffPresent(hot_streak_buff) Spell(flamestrike)
  #pyroblast,if=buff.pyroclasm.react&buff.combustion.remains>execute_time
  if DebuffPresent(pyroclasm) and BuffRemaining(combustion_buff) > ExecuteTime(pyroblast) Spell(pyroblast)
  #pyroblast,if=buff.hot_streak.react
  if BuffPresent(hot_streak_buff) Spell(pyroblast)
  #fire_blast,if=buff.heating_up.react
  if BuffPresent(heating_up_buff) Spell(fire_blast)
  #scorch,if=buff.combustion.remains>cast_time
  if BuffRemaining(combustion_buff) > CastTime(scorch) Spell(scorch)
  #scorch,if=target.health.pct<=30&talent.searing_touch.enabled
  if target.HealthPercent() <= 30 and Talent(searing_touch_talent) Spell(scorch)
 }
}

AddFunction FireCombustionphaseMainPostConditions
{
 FireActivetalentsMainPostConditions()
}

AddFunction FireCombustionphaseShortCdActions
{
 #rune_of_power,if=buff.combustion.down
 if BuffExpires(combustion_buff) Spell(rune_of_power)
 #call_action_list,name=active_talents
 FireActivetalentsShortCdActions()

 unless FireActivetalentsShortCdPostConditions() or { Talent(flame_patch_talent) and Enemies() > 2 or Enemies() > 6 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or DebuffPresent(pyroclasm) and BuffRemaining(combustion_buff) > ExecuteTime(pyroblast) and Spell(pyroblast) or BuffPresent(hot_streak_buff) and Spell(pyroblast) or BuffPresent(heating_up_buff) and Spell(fire_blast)
 {
  #phoenix_flames
  Spell(phoenix_flames)

  unless BuffRemaining(combustion_buff) > CastTime(scorch) and Spell(scorch)
  {
   #dragons_breath,if=!buff.hot_streak.react&action.fire_blast.charges<1
   if not BuffPresent(hot_streak_buff) and Charges(fire_blast) < 1 and target.Distance(less 12) Spell(dragons_breath)
  }
 }
}

AddFunction FireCombustionphaseShortCdPostConditions
{
 FireActivetalentsShortCdPostConditions() or { Talent(flame_patch_talent) and Enemies() > 2 or Enemies() > 6 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or DebuffPresent(pyroclasm) and BuffRemaining(combustion_buff) > ExecuteTime(pyroblast) and Spell(pyroblast) or BuffPresent(hot_streak_buff) and Spell(pyroblast) or BuffPresent(heating_up_buff) and Spell(fire_blast) or BuffRemaining(combustion_buff) > CastTime(scorch) and Spell(scorch) or target.HealthPercent() <= 30 and Talent(searing_touch_talent) and Spell(scorch)
}

AddFunction FireCombustionphaseCdActions
{
 #lights_judgment,if=buff.combustion.down
 if BuffExpires(combustion_buff) Spell(lights_judgment)

 unless BuffExpires(combustion_buff) and Spell(rune_of_power)
 {
  #call_action_list,name=active_talents
  FireActivetalentsCdActions()

  unless FireActivetalentsCdPostConditions()
  {
   #combustion
   Spell(combustion)
   #potion
   if CheckBoxOn(opt_use_consumables) and target.Classification(worldboss) Item(battle_potion_of_intellect usable=1)
   #blood_fury
   Spell(blood_fury_sp)
   #berserking
   Spell(berserking)
   #fireblood
   Spell(fireblood)
   #ancestral_call
   Spell(ancestral_call)
   #use_items
   FireUseItemActions()
  }
 }
}

AddFunction FireCombustionphaseCdPostConditions
{
 BuffExpires(combustion_buff) and Spell(rune_of_power) or FireActivetalentsCdPostConditions() or { Talent(flame_patch_talent) and Enemies() > 2 or Enemies() > 6 } and BuffPresent(hot_streak_buff) and Spell(flamestrike) or DebuffPresent(pyroclasm) and BuffRemaining(combustion_buff) > ExecuteTime(pyroblast) and Spell(pyroblast) or BuffPresent(hot_streak_buff) and Spell(pyroblast) or BuffPresent(heating_up_buff) and Spell(fire_blast) or Spell(phoenix_flames) or BuffRemaining(combustion_buff) > CastTime(scorch) and Spell(scorch) or not BuffPresent(hot_streak_buff) and Charges(fire_blast) < 1 and target.Distance(less 12) and Spell(dragons_breath) or target.HealthPercent() <= 30 and Talent(searing_touch_talent) and Spell(scorch)
}

### actions.active_talents

AddFunction FireActivetalentsMainActions
{
 #blast_wave,if=(buff.combustion.down)|(buff.combustion.up&action.fire_blast.charges<1)
 if { BuffExpires(combustion_buff) or BuffPresent(combustion_buff) and Charges(fire_blast) < 1 } and target.Distance(less 8) Spell(blast_wave)
 #living_bomb,if=active_enemies>1&buff.combustion.down
 if Enemies() > 1 and BuffExpires(combustion_buff) Spell(living_bomb)
}

AddFunction FireActivetalentsMainPostConditions
{
}

AddFunction FireActivetalentsShortCdActions
{
 unless { BuffExpires(combustion_buff) or BuffPresent(combustion_buff) and Charges(fire_blast) < 1 } and target.Distance(less 8) and Spell(blast_wave)
 {
  #meteor,if=cooldown.combustion.remains>40|(cooldown.combustion.remains>target.time_to_die)|buff.rune_of_power.up|firestarter.active
  if SpellCooldown(combustion) > 40 or SpellCooldown(combustion) > target.TimeToDie() or BuffPresent(rune_of_power_buff) or Talent(firestarter_talent) and target.HealthPercent() >= 90 Spell(meteor)
  #dragons_breath,if=talent.alexstraszas_fury.enabled&!buff.hot_streak.react
  if Talent(alexstraszas_fury_talent) and not BuffPresent(hot_streak_buff) and target.Distance(less 12) Spell(dragons_breath)
 }
}

AddFunction FireActivetalentsShortCdPostConditions
{
 { BuffExpires(combustion_buff) or BuffPresent(combustion_buff) and Charges(fire_blast) < 1 } and target.Distance(less 8) and Spell(blast_wave) or Enemies() > 1 and BuffExpires(combustion_buff) and Spell(living_bomb)
}

AddFunction FireActivetalentsCdActions
{
}

AddFunction FireActivetalentsCdPostConditions
{
 { BuffExpires(combustion_buff) or BuffPresent(combustion_buff) and Charges(fire_blast) < 1 } and target.Distance(less 8) and Spell(blast_wave) or { SpellCooldown(combustion) > 40 or SpellCooldown(combustion) > target.TimeToDie() or BuffPresent(rune_of_power_buff) or Talent(firestarter_talent) and target.HealthPercent() >= 90 } and Spell(meteor) or Talent(alexstraszas_fury_talent) and not BuffPresent(hot_streak_buff) and target.Distance(less 12) and Spell(dragons_breath) or Enemies() > 1 and BuffExpires(combustion_buff) and Spell(living_bomb)
}

### actions.default

AddFunction FireDefaultMainActions
{
 #call_action_list,name=combustion_phase,if=cooldown.combustion.remains<=action.rune_of_power.cast_time+(!talent.kindling.enabled*gcd)&(!talent.firestarter.enabled|!firestarter.active|active_enemies>=4|active_enemies>=2&talent.flame_patch.enabled)|buff.combustion.up
 if SpellCooldown(combustion) <= CastTime(rune_of_power) + Talent(kindling_talent no) * GCD() and { not Talent(firestarter_talent) or not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } or Enemies() >= 4 or Enemies() >= 2 and Talent(flame_patch_talent) } or BuffPresent(combustion_buff) FireCombustionphaseMainActions()

 unless { SpellCooldown(combustion) <= CastTime(rune_of_power) + Talent(kindling_talent no) * GCD() and { not Talent(firestarter_talent) or not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } or Enemies() >= 4 or Enemies() >= 2 and Talent(flame_patch_talent) } or BuffPresent(combustion_buff) } and FireCombustionphaseMainPostConditions()
 {
  #call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
  if BuffPresent(rune_of_power_buff) and BuffExpires(combustion_buff) FireRopphaseMainActions()

  unless BuffPresent(rune_of_power_buff) and BuffExpires(combustion_buff) and FireRopphaseMainPostConditions()
  {
   #call_action_list,name=standard_rotation
   FireStandardrotationMainActions()
  }
 }
}

AddFunction FireDefaultMainPostConditions
{
 { SpellCooldown(combustion) <= CastTime(rune_of_power) + Talent(kindling_talent no) * GCD() and { not Talent(firestarter_talent) or not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } or Enemies() >= 4 or Enemies() >= 2 and Talent(flame_patch_talent) } or BuffPresent(combustion_buff) } and FireCombustionphaseMainPostConditions() or BuffPresent(rune_of_power_buff) and BuffExpires(combustion_buff) and FireRopphaseMainPostConditions() or FireStandardrotationMainPostConditions()
}

AddFunction FireDefaultShortCdActions
{
 #rune_of_power,if=firestarter.active&action.rune_of_power.charges=2|cooldown.combustion.remains>40&buff.combustion.down&!talent.kindling.enabled|target.time_to_die<11|talent.kindling.enabled&(charges_fractional>1.8|time<40)&cooldown.combustion.remains>40
 if Talent(firestarter_talent) and target.HealthPercent() >= 90 and Charges(rune_of_power) == 2 or SpellCooldown(combustion) > 40 and BuffExpires(combustion_buff) and not Talent(kindling_talent) or target.TimeToDie() < 11 or Talent(kindling_talent) and { Charges(rune_of_power count=0) > 1.8 or TimeInCombat() < 40 } and SpellCooldown(combustion) > 40 Spell(rune_of_power)
 #rune_of_power,if=buff.pyroclasm.react&(cooldown.combustion.remains>40|action.rune_of_power.charges>1)
 if DebuffPresent(pyroclasm) and { SpellCooldown(combustion) > 40 or Charges(rune_of_power) > 1 } Spell(rune_of_power)
 #call_action_list,name=combustion_phase,if=cooldown.combustion.remains<=action.rune_of_power.cast_time+(!talent.kindling.enabled*gcd)&(!talent.firestarter.enabled|!firestarter.active|active_enemies>=4|active_enemies>=2&talent.flame_patch.enabled)|buff.combustion.up
 if SpellCooldown(combustion) <= CastTime(rune_of_power) + Talent(kindling_talent no) * GCD() and { not Talent(firestarter_talent) or not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } or Enemies() >= 4 or Enemies() >= 2 and Talent(flame_patch_talent) } or BuffPresent(combustion_buff) FireCombustionphaseShortCdActions()

 unless { SpellCooldown(combustion) <= CastTime(rune_of_power) + Talent(kindling_talent no) * GCD() and { not Talent(firestarter_talent) or not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } or Enemies() >= 4 or Enemies() >= 2 and Talent(flame_patch_talent) } or BuffPresent(combustion_buff) } and FireCombustionphaseShortCdPostConditions()
 {
  #call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
  if BuffPresent(rune_of_power_buff) and BuffExpires(combustion_buff) FireRopphaseShortCdActions()

  unless BuffPresent(rune_of_power_buff) and BuffExpires(combustion_buff) and FireRopphaseShortCdPostConditions()
  {
   #call_action_list,name=standard_rotation
   FireStandardrotationShortCdActions()
  }
 }
}

AddFunction FireDefaultShortCdPostConditions
{
 { SpellCooldown(combustion) <= CastTime(rune_of_power) + Talent(kindling_talent no) * GCD() and { not Talent(firestarter_talent) or not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } or Enemies() >= 4 or Enemies() >= 2 and Talent(flame_patch_talent) } or BuffPresent(combustion_buff) } and FireCombustionphaseShortCdPostConditions() or BuffPresent(rune_of_power_buff) and BuffExpires(combustion_buff) and FireRopphaseShortCdPostConditions() or FireStandardrotationShortCdPostConditions()
}

AddFunction FireDefaultCdActions
{
 #counterspell,if=target.debuff.casting.react
 if target.IsInterruptible() FireInterruptActions()
 #time_warp,if=time=0&buff.bloodlust.down
 if TimeInCombat() == 0 and BuffExpires(burst_haste_buff any=1) and CheckBoxOn(opt_time_warp) and DebuffExpires(burst_haste_debuff any=1) Spell(time_warp)
 #mirror_image,if=buff.combustion.down
 if BuffExpires(combustion_buff) Spell(mirror_image)

 unless { Talent(firestarter_talent) and target.HealthPercent() >= 90 and Charges(rune_of_power) == 2 or SpellCooldown(combustion) > 40 and BuffExpires(combustion_buff) and not Talent(kindling_talent) or target.TimeToDie() < 11 or Talent(kindling_talent) and { Charges(rune_of_power count=0) > 1.8 or TimeInCombat() < 40 } and SpellCooldown(combustion) > 40 } and Spell(rune_of_power) or DebuffPresent(pyroclasm) and { SpellCooldown(combustion) > 40 or Charges(rune_of_power) > 1 } and Spell(rune_of_power)
 {
  #call_action_list,name=combustion_phase,if=cooldown.combustion.remains<=action.rune_of_power.cast_time+(!talent.kindling.enabled*gcd)&(!talent.firestarter.enabled|!firestarter.active|active_enemies>=4|active_enemies>=2&talent.flame_patch.enabled)|buff.combustion.up
  if SpellCooldown(combustion) <= CastTime(rune_of_power) + Talent(kindling_talent no) * GCD() and { not Talent(firestarter_talent) or not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } or Enemies() >= 4 or Enemies() >= 2 and Talent(flame_patch_talent) } or BuffPresent(combustion_buff) FireCombustionphaseCdActions()

  unless { SpellCooldown(combustion) <= CastTime(rune_of_power) + Talent(kindling_talent no) * GCD() and { not Talent(firestarter_talent) or not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } or Enemies() >= 4 or Enemies() >= 2 and Talent(flame_patch_talent) } or BuffPresent(combustion_buff) } and FireCombustionphaseCdPostConditions()
  {
   #call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
   if BuffPresent(rune_of_power_buff) and BuffExpires(combustion_buff) FireRopphaseCdActions()

   unless BuffPresent(rune_of_power_buff) and BuffExpires(combustion_buff) and FireRopphaseCdPostConditions()
   {
    #call_action_list,name=standard_rotation
    FireStandardrotationCdActions()
   }
  }
 }
}

AddFunction FireDefaultCdPostConditions
{
 { Talent(firestarter_talent) and target.HealthPercent() >= 90 and Charges(rune_of_power) == 2 or SpellCooldown(combustion) > 40 and BuffExpires(combustion_buff) and not Talent(kindling_talent) or target.TimeToDie() < 11 or Talent(kindling_talent) and { Charges(rune_of_power count=0) > 1.8 or TimeInCombat() < 40 } and SpellCooldown(combustion) > 40 } and Spell(rune_of_power) or DebuffPresent(pyroclasm) and { SpellCooldown(combustion) > 40 or Charges(rune_of_power) > 1 } and Spell(rune_of_power) or { SpellCooldown(combustion) <= CastTime(rune_of_power) + Talent(kindling_talent no) * GCD() and { not Talent(firestarter_talent) or not { Talent(firestarter_talent) and target.HealthPercent() >= 90 } or Enemies() >= 4 or Enemies() >= 2 and Talent(flame_patch_talent) } or BuffPresent(combustion_buff) } and FireCombustionphaseCdPostConditions() or BuffPresent(rune_of_power_buff) and BuffExpires(combustion_buff) and FireRopphaseCdPostConditions() or FireStandardrotationCdPostConditions()
}

### Fire icons.

AddCheckBox(opt_mage_fire_aoe L(AOE) default specialization=fire)

AddIcon checkbox=!opt_mage_fire_aoe enemies=1 help=shortcd specialization=fire
{
 if not InCombat() FirePrecombatShortCdActions()
 unless not InCombat() and FirePrecombatShortCdPostConditions()
 {
  FireDefaultShortCdActions()
 }
}

AddIcon checkbox=opt_mage_fire_aoe help=shortcd specialization=fire
{
 if not InCombat() FirePrecombatShortCdActions()
 unless not InCombat() and FirePrecombatShortCdPostConditions()
 {
  FireDefaultShortCdActions()
 }
}

AddIcon enemies=1 help=main specialization=fire
{
 if not InCombat() FirePrecombatMainActions()
 unless not InCombat() and FirePrecombatMainPostConditions()
 {
  FireDefaultMainActions()
 }
}

AddIcon checkbox=opt_mage_fire_aoe help=aoe specialization=fire
{
 if not InCombat() FirePrecombatMainActions()
 unless not InCombat() and FirePrecombatMainPostConditions()
 {
  FireDefaultMainActions()
 }
}

AddIcon checkbox=!opt_mage_fire_aoe enemies=1 help=cd specialization=fire
{
 if not InCombat() FirePrecombatCdActions()
 unless not InCombat() and FirePrecombatCdPostConditions()
 {
  FireDefaultCdActions()
 }
}

AddIcon checkbox=opt_mage_fire_aoe help=cd specialization=fire
{
 if not InCombat() FirePrecombatCdActions()
 unless not InCombat() and FirePrecombatCdPostConditions()
 {
  FireDefaultCdActions()
 }
}

### Required symbols
# alexstraszas_fury_talent
# ancestral_call
# arcane_intellect
# battle_potion_of_intellect
# berserking
# blast_wave
# blood_fury_sp
# combustion
# combustion_buff
# counterspell
# dragons_breath
# fire_blast
# fireball
# fireblood
# firestarter_talent
# flame_patch_talent
# flamestrike
# heating_up_buff
# hot_streak_buff
# incanters_flow_buff
# kindling_talent
# lights_judgment
# living_bomb
# meteor
# mirror_image
# mirror_image_talent
# phoenix_flames
# preheat
# preheat_trait
# pyroblast
# pyroclasm
# quaking_palm
# rune_of_power
# rune_of_power_buff
# rune_of_power_talent
# scorch
# searing_touch_talent
# time_warp
]]
    OvaleScripts:RegisterScript("MAGE", "fire", name, desc, code, "script")
end
do
    local name = "sc_pr_mage_frost"
    local desc = "[8.0] Simulationcraft: PR_Mage_Frost"
    local code = [[
# Based on SimulationCraft profile "PR_Mage_Frost".
#	class=mage
#	spec=frost
#	talents=1013033

Include(ovale_common)
Include(ovale_trinkets_mop)
Include(ovale_trinkets_wod)
Include(ovale_mage_spells)

AddCheckBox(opt_interrupt L(interrupt) default specialization=frost)
AddCheckBox(opt_use_consumables L(opt_use_consumables) default specialization=frost)
AddCheckBox(opt_time_warp SpellName(time_warp) specialization=frost)

AddFunction FrostInterruptActions
{
 if CheckBoxOn(opt_interrupt) and not target.IsFriend() and target.Casting()
 {
  if target.InRange(quaking_palm) and not target.Classification(worldboss) Spell(quaking_palm)
  if target.InRange(counterspell) and target.IsInterruptible() Spell(counterspell)
 }
}

AddFunction FrostUseItemActions
{
 Item(Trinket0Slot text=13 usable=1)
 Item(Trinket1Slot text=14 usable=1)
}

### actions.talent_rop

AddFunction FrostTalentropMainActions
{
}

AddFunction FrostTalentropMainPostConditions
{
}

AddFunction FrostTalentropShortCdActions
{
 #rune_of_power,if=talent.glacial_spike.enabled&buff.icicles.stack=5&(buff.brain_freeze.react|talent.ebonbolt.enabled&cooldown.ebonbolt.remains<cast_time)
 if Talent(glacial_spike_talent) and BuffStacks(icicles_buff) == 5 and { BuffPresent(brain_freeze_buff) or Talent(ebonbolt_talent) and SpellCooldown(ebonbolt) < CastTime(rune_of_power) } Spell(rune_of_power)
 #rune_of_power,if=!talent.glacial_spike.enabled&(talent.ebonbolt.enabled&cooldown.ebonbolt.remains<cast_time|talent.comet_storm.enabled&cooldown.comet_storm.remains<cast_time|talent.ray_of_frost.enabled&cooldown.ray_of_frost.remains<cast_time|charges_fractional>1.9)
 if not Talent(glacial_spike_talent) and { Talent(ebonbolt_talent) and SpellCooldown(ebonbolt) < CastTime(rune_of_power) or Talent(comet_storm_talent) and SpellCooldown(comet_storm) < CastTime(rune_of_power) or Talent(ray_of_frost_talent) and SpellCooldown(ray_of_frost) < CastTime(rune_of_power) or Charges(rune_of_power count=0) > 1.9 } Spell(rune_of_power)
}

AddFunction FrostTalentropShortCdPostConditions
{
}

AddFunction FrostTalentropCdActions
{
}

AddFunction FrostTalentropCdPostConditions
{
 Talent(glacial_spike_talent) and BuffStacks(icicles_buff) == 5 and { BuffPresent(brain_freeze_buff) or Talent(ebonbolt_talent) and SpellCooldown(ebonbolt) < CastTime(rune_of_power) } and Spell(rune_of_power) or not Talent(glacial_spike_talent) and { Talent(ebonbolt_talent) and SpellCooldown(ebonbolt) < CastTime(rune_of_power) or Talent(comet_storm_talent) and SpellCooldown(comet_storm) < CastTime(rune_of_power) or Talent(ray_of_frost_talent) and SpellCooldown(ray_of_frost) < CastTime(rune_of_power) or Charges(rune_of_power count=0) > 1.9 } and Spell(rune_of_power)
}

### actions.single

AddFunction FrostSingleMainActions
{
 #ice_nova,if=cooldown.ice_nova.ready&debuff.winters_chill.up
 if SpellCooldown(ice_nova) == 0 and target.DebuffPresent(winters_chill_debuff) Spell(ice_nova)
 #flurry,if=!talent.glacial_spike.enabled&(prev_gcd.1.ebonbolt|buff.brain_freeze.react&prev_gcd.1.frostbolt)
 if not Talent(glacial_spike_talent) and { PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and PreviousGCDSpell(frostbolt) } Spell(flurry)
 #flurry,if=talent.glacial_spike.enabled&buff.brain_freeze.react&(prev_gcd.1.frostbolt&buff.icicles.stack<4|prev_gcd.1.glacial_spike|prev_gcd.1.ebonbolt)
 if Talent(glacial_spike_talent) and BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and BuffStacks(icicles_buff) < 4 or PreviousGCDSpell(glacial_spike) or PreviousGCDSpell(ebonbolt) } Spell(flurry)
 #blizzard,if=active_enemies>2|active_enemies>1&cast_time=0&buff.fingers_of_frost.react<2
 if Enemies() > 2 or Enemies() > 1 and CastTime(blizzard) == 0 and BuffStacks(fingers_of_frost_buff) < 2 Spell(blizzard)
 #ice_lance,if=buff.fingers_of_frost.react
 if BuffPresent(fingers_of_frost_buff) Spell(ice_lance)
 #ebonbolt,if=!talent.glacial_spike.enabled|buff.icicles.stack=5&!buff.brain_freeze.react
 if not Talent(glacial_spike_talent) or BuffStacks(icicles_buff) == 5 and not BuffPresent(brain_freeze_buff) Spell(ebonbolt)
 #ray_of_frost,if=!action.frozen_orb.in_flight&ground_aoe.frozen_orb.remains=0
 if not InFlightToTarget(frozen_orb) and not DebuffRemaining(frozen_orb_debuff) > 0 Spell(ray_of_frost)
 #blizzard,if=cast_time=0|active_enemies>1
 if CastTime(blizzard) == 0 or Enemies() > 1 Spell(blizzard)
 #glacial_spike,if=buff.brain_freeze.react|prev_gcd.1.ebonbolt|active_enemies>1&talent.splitting_ice.enabled
 if BuffPresent(brain_freeze_buff) or PreviousGCDSpell(ebonbolt) or Enemies() > 1 and Talent(splitting_ice_talent) Spell(glacial_spike)
 #ice_nova
 Spell(ice_nova)
 #flurry,if=azerite.winters_reach.enabled&!buff.brain_freeze.react&buff.winters_reach.react
 if HasAzeriteTrait(winters_reach_trait) and not BuffPresent(brain_freeze_buff) and DebuffPresent(winters_reach) Spell(flurry)
 #frostbolt
 Spell(frostbolt)
 #call_action_list,name=movement
 FrostMovementMainActions()

 unless FrostMovementMainPostConditions()
 {
  #ice_lance
  Spell(ice_lance)
 }
}

AddFunction FrostSingleMainPostConditions
{
 FrostMovementMainPostConditions()
}

AddFunction FrostSingleShortCdActions
{
 unless SpellCooldown(ice_nova) == 0 and target.DebuffPresent(winters_chill_debuff) and Spell(ice_nova) or not Talent(glacial_spike_talent) and { PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and PreviousGCDSpell(frostbolt) } and Spell(flurry) or Talent(glacial_spike_talent) and BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and BuffStacks(icicles_buff) < 4 or PreviousGCDSpell(glacial_spike) or PreviousGCDSpell(ebonbolt) } and Spell(flurry)
 {
  #frozen_orb
  Spell(frozen_orb)

  unless { Enemies() > 2 or Enemies() > 1 and CastTime(blizzard) == 0 and BuffStacks(fingers_of_frost_buff) < 2 } and Spell(blizzard) or BuffPresent(fingers_of_frost_buff) and Spell(ice_lance)
  {
   #comet_storm
   Spell(comet_storm)

   unless { not Talent(glacial_spike_talent) or BuffStacks(icicles_buff) == 5 and not BuffPresent(brain_freeze_buff) } and Spell(ebonbolt) or not InFlightToTarget(frozen_orb) and not DebuffRemaining(frozen_orb_debuff) > 0 and Spell(ray_of_frost) or { CastTime(blizzard) == 0 or Enemies() > 1 } and Spell(blizzard) or { BuffPresent(brain_freeze_buff) or PreviousGCDSpell(ebonbolt) or Enemies() > 1 and Talent(splitting_ice_talent) } and Spell(glacial_spike) or Spell(ice_nova) or HasAzeriteTrait(winters_reach_trait) and not BuffPresent(brain_freeze_buff) and DebuffPresent(winters_reach) and Spell(flurry) or Spell(frostbolt)
   {
    #call_action_list,name=movement
    FrostMovementShortCdActions()
   }
  }
 }
}

AddFunction FrostSingleShortCdPostConditions
{
 SpellCooldown(ice_nova) == 0 and target.DebuffPresent(winters_chill_debuff) and Spell(ice_nova) or not Talent(glacial_spike_talent) and { PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and PreviousGCDSpell(frostbolt) } and Spell(flurry) or Talent(glacial_spike_talent) and BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and BuffStacks(icicles_buff) < 4 or PreviousGCDSpell(glacial_spike) or PreviousGCDSpell(ebonbolt) } and Spell(flurry) or { Enemies() > 2 or Enemies() > 1 and CastTime(blizzard) == 0 and BuffStacks(fingers_of_frost_buff) < 2 } and Spell(blizzard) or BuffPresent(fingers_of_frost_buff) and Spell(ice_lance) or { not Talent(glacial_spike_talent) or BuffStacks(icicles_buff) == 5 and not BuffPresent(brain_freeze_buff) } and Spell(ebonbolt) or not InFlightToTarget(frozen_orb) and not DebuffRemaining(frozen_orb_debuff) > 0 and Spell(ray_of_frost) or { CastTime(blizzard) == 0 or Enemies() > 1 } and Spell(blizzard) or { BuffPresent(brain_freeze_buff) or PreviousGCDSpell(ebonbolt) or Enemies() > 1 and Talent(splitting_ice_talent) } and Spell(glacial_spike) or Spell(ice_nova) or HasAzeriteTrait(winters_reach_trait) and not BuffPresent(brain_freeze_buff) and DebuffPresent(winters_reach) and Spell(flurry) or Spell(frostbolt) or FrostMovementShortCdPostConditions() or Spell(ice_lance)
}

AddFunction FrostSingleCdActions
{
 unless SpellCooldown(ice_nova) == 0 and target.DebuffPresent(winters_chill_debuff) and Spell(ice_nova) or not Talent(glacial_spike_talent) and { PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and PreviousGCDSpell(frostbolt) } and Spell(flurry) or Talent(glacial_spike_talent) and BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and BuffStacks(icicles_buff) < 4 or PreviousGCDSpell(glacial_spike) or PreviousGCDSpell(ebonbolt) } and Spell(flurry) or Spell(frozen_orb) or { Enemies() > 2 or Enemies() > 1 and CastTime(blizzard) == 0 and BuffStacks(fingers_of_frost_buff) < 2 } and Spell(blizzard) or BuffPresent(fingers_of_frost_buff) and Spell(ice_lance) or Spell(comet_storm) or { not Talent(glacial_spike_talent) or BuffStacks(icicles_buff) == 5 and not BuffPresent(brain_freeze_buff) } and Spell(ebonbolt) or not InFlightToTarget(frozen_orb) and not DebuffRemaining(frozen_orb_debuff) > 0 and Spell(ray_of_frost) or { CastTime(blizzard) == 0 or Enemies() > 1 } and Spell(blizzard) or { BuffPresent(brain_freeze_buff) or PreviousGCDSpell(ebonbolt) or Enemies() > 1 and Talent(splitting_ice_talent) } and Spell(glacial_spike) or Spell(ice_nova) or HasAzeriteTrait(winters_reach_trait) and not BuffPresent(brain_freeze_buff) and DebuffPresent(winters_reach) and Spell(flurry) or Spell(frostbolt)
 {
  #call_action_list,name=movement
  FrostMovementCdActions()
 }
}

AddFunction FrostSingleCdPostConditions
{
 SpellCooldown(ice_nova) == 0 and target.DebuffPresent(winters_chill_debuff) and Spell(ice_nova) or not Talent(glacial_spike_talent) and { PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and PreviousGCDSpell(frostbolt) } and Spell(flurry) or Talent(glacial_spike_talent) and BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and BuffStacks(icicles_buff) < 4 or PreviousGCDSpell(glacial_spike) or PreviousGCDSpell(ebonbolt) } and Spell(flurry) or Spell(frozen_orb) or { Enemies() > 2 or Enemies() > 1 and CastTime(blizzard) == 0 and BuffStacks(fingers_of_frost_buff) < 2 } and Spell(blizzard) or BuffPresent(fingers_of_frost_buff) and Spell(ice_lance) or Spell(comet_storm) or { not Talent(glacial_spike_talent) or BuffStacks(icicles_buff) == 5 and not BuffPresent(brain_freeze_buff) } and Spell(ebonbolt) or not InFlightToTarget(frozen_orb) and not DebuffRemaining(frozen_orb_debuff) > 0 and Spell(ray_of_frost) or { CastTime(blizzard) == 0 or Enemies() > 1 } and Spell(blizzard) or { BuffPresent(brain_freeze_buff) or PreviousGCDSpell(ebonbolt) or Enemies() > 1 and Talent(splitting_ice_talent) } and Spell(glacial_spike) or Spell(ice_nova) or HasAzeriteTrait(winters_reach_trait) and not BuffPresent(brain_freeze_buff) and DebuffPresent(winters_reach) and Spell(flurry) or Spell(frostbolt) or FrostMovementCdPostConditions() or Spell(ice_lance)
}

### actions.precombat

AddFunction FrostPrecombatMainActions
{
 #flask
 #food
 #augmentation
 #arcane_intellect
 Spell(arcane_intellect)
 #frostbolt
 Spell(frostbolt)
}

AddFunction FrostPrecombatMainPostConditions
{
}

AddFunction FrostPrecombatShortCdActions
{
 unless Spell(arcane_intellect)
 {
  #water_elemental
  if not pet.Present() Spell(summon_water_elemental)
 }
}

AddFunction FrostPrecombatShortCdPostConditions
{
 Spell(arcane_intellect) or Spell(frostbolt)
}

AddFunction FrostPrecombatCdActions
{
 unless Spell(arcane_intellect) or not pet.Present() and Spell(summon_water_elemental)
 {
  #snapshot_stats
  #mirror_image
  Spell(mirror_image)
  #potion
  if CheckBoxOn(opt_use_consumables) and target.Classification(worldboss) Item(rising_death usable=1)
 }
}

AddFunction FrostPrecombatCdPostConditions
{
 Spell(arcane_intellect) or not pet.Present() and Spell(summon_water_elemental) or Spell(frostbolt)
}

### actions.movement

AddFunction FrostMovementMainActions
{
}

AddFunction FrostMovementMainPostConditions
{
}

AddFunction FrostMovementShortCdActions
{
 #blink,if=movement.distance>10
 if target.Distance() > 10 Spell(blink)
 #ice_floes,if=buff.ice_floes.down
 if BuffExpires(ice_floes_buff) and Speed() > 0 Spell(ice_floes)
}

AddFunction FrostMovementShortCdPostConditions
{
}

AddFunction FrostMovementCdActions
{
}

AddFunction FrostMovementCdPostConditions
{
 target.Distance() > 10 and Spell(blink) or BuffExpires(ice_floes_buff) and Speed() > 0 and Spell(ice_floes)
}

### actions.cooldowns

AddFunction FrostCooldownsMainActions
{
 #call_action_list,name=talent_rop,if=talent.rune_of_power.enabled&active_enemies=1&cooldown.rune_of_power.full_recharge_time<cooldown.frozen_orb.remains
 if Talent(rune_of_power_talent) and Enemies() == 1 and SpellCooldown(rune_of_power) < SpellCooldown(frozen_orb) FrostTalentropMainActions()
}

AddFunction FrostCooldownsMainPostConditions
{
 Talent(rune_of_power_talent) and Enemies() == 1 and SpellCooldown(rune_of_power) < SpellCooldown(frozen_orb) and FrostTalentropMainPostConditions()
}

AddFunction FrostCooldownsShortCdActions
{
 #rune_of_power,if=prev_gcd.1.frozen_orb|time_to_die>10+cast_time&time_to_die<20
 if PreviousGCDSpell(frozen_orb) or target.TimeToDie() > 10 + CastTime(rune_of_power) and target.TimeToDie() < 20 Spell(rune_of_power)
 #call_action_list,name=talent_rop,if=talent.rune_of_power.enabled&active_enemies=1&cooldown.rune_of_power.full_recharge_time<cooldown.frozen_orb.remains
 if Talent(rune_of_power_talent) and Enemies() == 1 and SpellCooldown(rune_of_power) < SpellCooldown(frozen_orb) FrostTalentropShortCdActions()
}

AddFunction FrostCooldownsShortCdPostConditions
{
 Talent(rune_of_power_talent) and Enemies() == 1 and SpellCooldown(rune_of_power) < SpellCooldown(frozen_orb) and FrostTalentropShortCdPostConditions()
}

AddFunction FrostCooldownsCdActions
{
 #time_warp
 if CheckBoxOn(opt_time_warp) and DebuffExpires(burst_haste_debuff any=1) Spell(time_warp)
 #icy_veins
 Spell(icy_veins)
 #mirror_image
 Spell(mirror_image)

 unless { PreviousGCDSpell(frozen_orb) or target.TimeToDie() > 10 + CastTime(rune_of_power) and target.TimeToDie() < 20 } and Spell(rune_of_power)
 {
  #call_action_list,name=talent_rop,if=talent.rune_of_power.enabled&active_enemies=1&cooldown.rune_of_power.full_recharge_time<cooldown.frozen_orb.remains
  if Talent(rune_of_power_talent) and Enemies() == 1 and SpellCooldown(rune_of_power) < SpellCooldown(frozen_orb) FrostTalentropCdActions()

  unless Talent(rune_of_power_talent) and Enemies() == 1 and SpellCooldown(rune_of_power) < SpellCooldown(frozen_orb) and FrostTalentropCdPostConditions()
  {
   #potion,if=prev_gcd.1.icy_veins|target.time_to_die<70
   if { PreviousGCDSpell(icy_veins) or target.TimeToDie() < 70 } and CheckBoxOn(opt_use_consumables) and target.Classification(worldboss) Item(rising_death usable=1)
   #use_items
   FrostUseItemActions()
   #blood_fury
   Spell(blood_fury_sp)
   #berserking
   Spell(berserking)
   #lights_judgment
   Spell(lights_judgment)
   #fireblood
   Spell(fireblood)
   #ancestral_call
   Spell(ancestral_call)
  }
 }
}

AddFunction FrostCooldownsCdPostConditions
{
 { PreviousGCDSpell(frozen_orb) or target.TimeToDie() > 10 + CastTime(rune_of_power) and target.TimeToDie() < 20 } and Spell(rune_of_power) or Talent(rune_of_power_talent) and Enemies() == 1 and SpellCooldown(rune_of_power) < SpellCooldown(frozen_orb) and FrostTalentropCdPostConditions()
}

### actions.aoe

AddFunction FrostAoeMainActions
{
 #blizzard
 Spell(blizzard)
 #ice_nova
 Spell(ice_nova)
 #flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.frostbolt&(buff.icicles.stack<4|!talent.glacial_spike.enabled)|prev_gcd.1.glacial_spike)
 if PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and { BuffStacks(icicles_buff) < 4 or not Talent(glacial_spike_talent) } or PreviousGCDSpell(glacial_spike) } Spell(flurry)
 #ice_lance,if=buff.fingers_of_frost.react
 if BuffPresent(fingers_of_frost_buff) Spell(ice_lance)
 #ray_of_frost
 Spell(ray_of_frost)
 #ebonbolt
 Spell(ebonbolt)
 #glacial_spike
 Spell(glacial_spike)
 #frostbolt
 Spell(frostbolt)
 #call_action_list,name=movement
 FrostMovementMainActions()

 unless FrostMovementMainPostConditions()
 {
  #ice_lance
  Spell(ice_lance)
 }
}

AddFunction FrostAoeMainPostConditions
{
 FrostMovementMainPostConditions()
}

AddFunction FrostAoeShortCdActions
{
 #frozen_orb
 Spell(frozen_orb)

 unless Spell(blizzard)
 {
  #comet_storm
  Spell(comet_storm)

  unless Spell(ice_nova) or { PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and { BuffStacks(icicles_buff) < 4 or not Talent(glacial_spike_talent) } or PreviousGCDSpell(glacial_spike) } } and Spell(flurry) or BuffPresent(fingers_of_frost_buff) and Spell(ice_lance) or Spell(ray_of_frost) or Spell(ebonbolt) or Spell(glacial_spike)
  {
   #cone_of_cold
   Spell(cone_of_cold)

   unless Spell(frostbolt)
   {
    #call_action_list,name=movement
    FrostMovementShortCdActions()
   }
  }
 }
}

AddFunction FrostAoeShortCdPostConditions
{
 Spell(blizzard) or Spell(ice_nova) or { PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and { BuffStacks(icicles_buff) < 4 or not Talent(glacial_spike_talent) } or PreviousGCDSpell(glacial_spike) } } and Spell(flurry) or BuffPresent(fingers_of_frost_buff) and Spell(ice_lance) or Spell(ray_of_frost) or Spell(ebonbolt) or Spell(glacial_spike) or Spell(frostbolt) or FrostMovementShortCdPostConditions() or Spell(ice_lance)
}

AddFunction FrostAoeCdActions
{
 unless Spell(frozen_orb) or Spell(blizzard) or Spell(comet_storm) or Spell(ice_nova) or { PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and { BuffStacks(icicles_buff) < 4 or not Talent(glacial_spike_talent) } or PreviousGCDSpell(glacial_spike) } } and Spell(flurry) or BuffPresent(fingers_of_frost_buff) and Spell(ice_lance) or Spell(ray_of_frost) or Spell(ebonbolt) or Spell(glacial_spike) or Spell(cone_of_cold) or Spell(frostbolt)
 {
  #call_action_list,name=movement
  FrostMovementCdActions()
 }
}

AddFunction FrostAoeCdPostConditions
{
 Spell(frozen_orb) or Spell(blizzard) or Spell(comet_storm) or Spell(ice_nova) or { PreviousGCDSpell(ebonbolt) or BuffPresent(brain_freeze_buff) and { PreviousGCDSpell(frostbolt) and { BuffStacks(icicles_buff) < 4 or not Talent(glacial_spike_talent) } or PreviousGCDSpell(glacial_spike) } } and Spell(flurry) or BuffPresent(fingers_of_frost_buff) and Spell(ice_lance) or Spell(ray_of_frost) or Spell(ebonbolt) or Spell(glacial_spike) or Spell(cone_of_cold) or Spell(frostbolt) or FrostMovementCdPostConditions() or Spell(ice_lance)
}

### actions.default

AddFunction FrostDefaultMainActions
{
 #ice_lance,if=prev_gcd.1.flurry&brain_freeze_active&!buff.fingers_of_frost.react
 if PreviousGCDSpell(flurry) and target.DebuffPresent(winters_chill_debuff) and not BuffPresent(fingers_of_frost_buff) Spell(ice_lance)
 #call_action_list,name=cooldowns
 FrostCooldownsMainActions()

 unless FrostCooldownsMainPostConditions()
 {
  #call_action_list,name=aoe,if=active_enemies>3&talent.freezing_rain.enabled|active_enemies>4
  if Enemies() > 3 and Talent(freezing_rain_talent) or Enemies() > 4 FrostAoeMainActions()

  unless { Enemies() > 3 and Talent(freezing_rain_talent) or Enemies() > 4 } and FrostAoeMainPostConditions()
  {
   #call_action_list,name=single
   FrostSingleMainActions()
  }
 }
}

AddFunction FrostDefaultMainPostConditions
{
 FrostCooldownsMainPostConditions() or { Enemies() > 3 and Talent(freezing_rain_talent) or Enemies() > 4 } and FrostAoeMainPostConditions() or FrostSingleMainPostConditions()
}

AddFunction FrostDefaultShortCdActions
{
 unless PreviousGCDSpell(flurry) and target.DebuffPresent(winters_chill_debuff) and not BuffPresent(fingers_of_frost_buff) and Spell(ice_lance)
 {
  #call_action_list,name=cooldowns
  FrostCooldownsShortCdActions()

  unless FrostCooldownsShortCdPostConditions()
  {
   #call_action_list,name=aoe,if=active_enemies>3&talent.freezing_rain.enabled|active_enemies>4
   if Enemies() > 3 and Talent(freezing_rain_talent) or Enemies() > 4 FrostAoeShortCdActions()

   unless { Enemies() > 3 and Talent(freezing_rain_talent) or Enemies() > 4 } and FrostAoeShortCdPostConditions()
   {
    #call_action_list,name=single
    FrostSingleShortCdActions()
   }
  }
 }
}

AddFunction FrostDefaultShortCdPostConditions
{
 PreviousGCDSpell(flurry) and target.DebuffPresent(winters_chill_debuff) and not BuffPresent(fingers_of_frost_buff) and Spell(ice_lance) or FrostCooldownsShortCdPostConditions() or { Enemies() > 3 and Talent(freezing_rain_talent) or Enemies() > 4 } and FrostAoeShortCdPostConditions() or FrostSingleShortCdPostConditions()
}

AddFunction FrostDefaultCdActions
{
 #counterspell
 FrostInterruptActions()

 unless PreviousGCDSpell(flurry) and target.DebuffPresent(winters_chill_debuff) and not BuffPresent(fingers_of_frost_buff) and Spell(ice_lance)
 {
  #call_action_list,name=cooldowns
  FrostCooldownsCdActions()

  unless FrostCooldownsCdPostConditions()
  {
   #call_action_list,name=aoe,if=active_enemies>3&talent.freezing_rain.enabled|active_enemies>4
   if Enemies() > 3 and Talent(freezing_rain_talent) or Enemies() > 4 FrostAoeCdActions()

   unless { Enemies() > 3 and Talent(freezing_rain_talent) or Enemies() > 4 } and FrostAoeCdPostConditions()
   {
    #call_action_list,name=single
    FrostSingleCdActions()
   }
  }
 }
}

AddFunction FrostDefaultCdPostConditions
{
 PreviousGCDSpell(flurry) and target.DebuffPresent(winters_chill_debuff) and not BuffPresent(fingers_of_frost_buff) and Spell(ice_lance) or FrostCooldownsCdPostConditions() or { Enemies() > 3 and Talent(freezing_rain_talent) or Enemies() > 4 } and FrostAoeCdPostConditions() or FrostSingleCdPostConditions()
}

### Frost icons.

AddCheckBox(opt_mage_frost_aoe L(AOE) default specialization=frost)

AddIcon checkbox=!opt_mage_frost_aoe enemies=1 help=shortcd specialization=frost
{
 if not InCombat() FrostPrecombatShortCdActions()
 unless not InCombat() and FrostPrecombatShortCdPostConditions()
 {
  FrostDefaultShortCdActions()
 }
}

AddIcon checkbox=opt_mage_frost_aoe help=shortcd specialization=frost
{
 if not InCombat() FrostPrecombatShortCdActions()
 unless not InCombat() and FrostPrecombatShortCdPostConditions()
 {
  FrostDefaultShortCdActions()
 }
}

AddIcon enemies=1 help=main specialization=frost
{
 if not InCombat() FrostPrecombatMainActions()
 unless not InCombat() and FrostPrecombatMainPostConditions()
 {
  FrostDefaultMainActions()
 }
}

AddIcon checkbox=opt_mage_frost_aoe help=aoe specialization=frost
{
 if not InCombat() FrostPrecombatMainActions()
 unless not InCombat() and FrostPrecombatMainPostConditions()
 {
  FrostDefaultMainActions()
 }
}

AddIcon checkbox=!opt_mage_frost_aoe enemies=1 help=cd specialization=frost
{
 if not InCombat() FrostPrecombatCdActions()
 unless not InCombat() and FrostPrecombatCdPostConditions()
 {
  FrostDefaultCdActions()
 }
}

AddIcon checkbox=opt_mage_frost_aoe help=cd specialization=frost
{
 if not InCombat() FrostPrecombatCdActions()
 unless not InCombat() and FrostPrecombatCdPostConditions()
 {
  FrostDefaultCdActions()
 }
}

### Required symbols
# ancestral_call
# arcane_intellect
# berserking
# blink
# blizzard
# blood_fury_sp
# brain_freeze_buff
# comet_storm
# comet_storm_talent
# cone_of_cold
# counterspell
# ebonbolt
# ebonbolt_talent
# fingers_of_frost_buff
# fireblood
# flurry
# freezing_rain_talent
# frostbolt
# frozen_orb
# frozen_orb_debuff
# glacial_spike
# glacial_spike_talent
# ice_floes
# ice_floes_buff
# ice_lance
# ice_nova
# icicles_buff
# icy_veins
# lights_judgment
# mirror_image
# quaking_palm
# ray_of_frost
# ray_of_frost_talent
# rising_death
# rune_of_power
# rune_of_power_talent
# splitting_ice_talent
# summon_water_elemental
# time_warp
# winters_chill_debuff
# winters_reach
# winters_reach_trait
]]
    OvaleScripts:RegisterScript("MAGE", "frost", name, desc, code, "script")
end