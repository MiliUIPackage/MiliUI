[![Donate to the author of Garrison Mission Manager](https://www.paypal.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cn=Add+special+instructions+to+the+addon+author%28s%29&business=rowaasr13%40gmail.com&bn=PP-DonationsBF%3Abtn_donateCC_LG.gif%3ANonHosted&lc=US&cmd=_donations&rm=1&no_shipping=1&currency_code=USD&return=https%3A%2F%2Fwww.curse.com%2Faddons%2Fwow%2Fgarrison-mission-manager&cancel_return=https%3A%2F%2Fwww.curse.com%2Faddons%2Fwow%2Fgarrison-mission-manager&item_name=Garrison+Mission+Manager+%28from+Curse.com%29) [![Support author of Garrison Mission Manager on Patreon](https://media-elerium.cursecdn.com/attachments/192/602/support-on-patreon26.png)](https://www.patreon.com/rowaasr13)

Garrison Mission Manager, v58

* http://www.curse.com/addons/wow/garrison-mission-manager
* http://www.wowinterface.com/downloads/info23375-GarrisonMissionManager.html

## Change log

### 2018-08-23 v58
 * Battle for Azeroth mission table support enabled.
 * Lots of internal changes to make adding new tables faster and simplier and make code more universal. Check your old tables to make sure they work correctly!

### 2018-08-18 v57
 * Remove Artifact Research tracker from code/docs - research is not available for quite some time already.
 * Prepare placeholder for upcoming BfA mission table code.

### 2018-08-14 v56
 * TBD. Mostly fixes and temporary workarounds for Battle for Azeroth changes.

### 2017-02-04 v55
 For detailed release notes [click here](https://www.patreon.com/posts/garrison-mission-7993798).

 * Improve full maxed party calculation in some more places in optimizer.
 * Special optimization for Class Hall XP missions: try to reach 100% first, then maximize amount of champions that need XP in team, and only then go for 100%+ reward.
 * Prepare upgrade items code from Garrison to be reused with Class Hall items.
 * Replace method used to target follower with upgrade items - may help with problems with other addons that taint follower equipment-related functions.
 * Fix and finally upgrade party saving for Class Hall to Legion API.
 * Aggressively update on follower list changes instead of relying on Blizzard's UI updates.

### 2016-11-07 v54
 * Disable minor debug left in AR notes tracker.
 * Docs typo cleanup commit.

### 2016-11-06 v53
 * Artifact Research Notes tracker.
 * Typo fixing in the code. Side-effect: ignored followers list will reset.
 * Another pass at code unifying/preparing for sharing.

### 2016-10-26 v52
 * TOC update for 7.1.

### 2016-10-25 v51
 * Fix similar team detection - it skipped pretty much most of non-busy followers, but should be fine now.
 * Mission cost optimization. It comes after success chance so it should be most visible on those 200% teams that many players should have by now.

### 2016-10-19 v50
 * Similar teams that only have different instance of same troop type (e.g. Calia + Zabra + Accolyte1 vs. Calia + Zabra + Accolyte2) are now skipped, only one group will be shown. Right now preference is given to highest durability troops, special handling for lethal mission will be added later.

### 2016-10-01 v49
 * Hook Class Hall mission list with code previously available for garrison, adding there all previously available features: best team button directly in list, mission expiration time and ilevel display.

### 2016-10-01 v48
 * Mostly internal changes: lots of garrison code is adapted to be shared with Class Hall. Next version will activate mission list buttons/expiration timers and rest of features previously available in garrison.
 * Mission page display is now shared with garrison too: mission level will now display only level or only ilevel as appropriate, just like it worked in garrison.
 * Artifact Power rewards now have amount of AP shown directly on item icons in mission list. This requires [[https://www.curse.com/addons/wow/libttscan-1|LibTTScan-1.0]] to work.

### 2016-09-21 v47
 * Party for missions without bonus loot will be optimized to have as little "extra" success over 100% as possible.

### 2016-09-16 v46
 * Always send at least one champion on Class Hall missions.
 * Support and optimize for teams that don't fill all slots on Class Hall missions in case you don't have enough free followers or if it would be simply a waste to send more than necessary.
 * Internal clean-up and preparations for troop count and unnecessary overmax (yeah, that's how Blizzard calls it) optimization.

### 2016-09-08 v45
 * Consider salvage yard level only when calculating party for WoD followers - fixes long standing "misfeature" of showing salvage crates in shipyard and any possible future problems with Class Hall.
 * Reliably detect max level followers in party calculation.
 * Right-clicking minimap button AFTER GMM was loaded (i.e. after you've seen mission table or already opened landing page at least once) will show WoD garrison lading page even if you have Class Hall.

### 2016-09-05 v44
 * Only calculate parties on mission page, fixes error on Combat Ally page.

### 2016-09-04 v43
 * Update/fix ignoring followers in WoD garrison and updating their list after that to use new API.

### 2016-09-02 v42
 * Handle cases when API returns nothing, not even empty list for followers - it seems this happens when you skip WoD garrison/shipyard and go directly to Legion.

### 2016-08-31 v41
 * Class Hall support: buttons on individual mission's page.
 * Show loot items in shipyard on small attachment to button on naval map.

### 2016-08-02 v40
 * Update to Legion API changes; cleanup some old compatibility stuff.
 (Known minor UI problem: shipyard mission buttons are sticking through debriefing screen.)

### 2015-11-13 v39
 * Show fleet summary in chat on accessing ship building NPC. [[http://legacy.curseforge.com/media/images/86/641/GMM_FleetSummary.png|(screenshot)]]

### 2015-07-15 v38
 * Treat blockade ship mission status as non-XP reward too, allowing full epic teams to be deployed even if you still have ships to level up.
 * Expose /run GMM_Click("StartShipyardMission").

### 2015-07-15 v37
 * Follower upgrade items' buttons/summary. [[http://legacy.curseforge.com/thumbman/images/84/465/600x184/GMM_FollowerUpgrades1.png.-m1.png|(screenshot)]]

### 2015-07-08 v36
 * Treat legendary ship mission status as non-XP reward, allowing full epic teams to be deployed even if you still have ships to level up.
 * Extend currency multiplier handling to Oil and Apexis. In case they ever appear on same mission priority is Apexis > Oil > GR.

### 2015-06-30 v35
 * Show item level and quality on mission rewards.
 * Show expiration timer on all rare missions, including XP ones (previously was: on all non-XP missions) - their huge boost for leveling is worth watching.

### 2015-06-28 v34
 * Best team buttons on naval map for each mission.

### 2015-06-26 v33
 * Add team buttons to ship mission pages.

### 2015-06-24 v32
 * TOC update for 6.2.
 * Fix v6.2 compatibility problem that could affect users with some other addon pre-filling party before GMM's analysis.

### 2015-06-23 v31
 * v6.2 compatibility. Runs on both 6.2 and pre-6.2, so you can safely upgrade before maintenance.

### 2015-05-15 v30
 * Don't show "level 100" indicator in mission list on missions that require ilevel. Instead just show mission ilevel in same big font and with slightly brighter color to make the easier to see at a glance.
 * Always show ilevel under follower portrait regardless if mission requires it or not to make it easier to see training of followers you're about to send on mission.
 * Color maxed follower ilevel (675) in green to make it easier to see who you still need to upgrade.

### 2015-03-26 v29
 * Mission list now shows expiration time on all non-XP missions in lower left corner of each button.
 * Warning for follower that have matching building slot under party portrait on mission page now warns in yellow for buildings without active work orders too.
 * Clicking red button in mission list now automatically sets best party on mission page.
 * Some optimizations to try to use less important followers (i.e. leveled/traited) that could be used on other missions.
 * Copy Wowhead mission link to chat button to the left of mission name on mission page.
 * Silently skip LDB loading if no LDB is available.

### 2015-03-06 v28
 * Gold yield mode: same as already available GR yield mode - it will prefer bigger gold bonus to any other optimizations and will risk lower chance if "Treasure Hunter" trait compensates lower success chance in the long run. Gold yield teams are shown on same set of buttons where GR yield appears on GR missions.

### 2015-02-28 v27
 * "Unavailable" team buttons will show non-GR boosted teams on GR reward missions too.
 * Updated follower work orders warning to 6.1 changes: it now shows when order is currently in progress and show time to next order and amount of remaining orders.
 * Some runtime/memory optimizations.

### 2015-02-28 v26
 * Fix team tooltips causing errors on some configurations.

### 2015-02-28 v25
 * New set of suggestions considering all followers, including currently unavailable.
 * Team button tooltips showing team composition and follower status on currently unavailable followers.
 * Minor performance and best team selection improvements.

### 2015-02-26 v24
 * TOC Interface version bump.

### 2015-02-18 v23
 * Fix some more minor building detection problem caused by early load and expand detection to buildings that have slots but no followers.
 * Show on assign button and LDB module tooltips buildings that have slots but no followers in red, change busy followers color to orange.

### 2015-02-03 v22
 * Add support for detecting buildings if some other addon (e.g. Broker Garrison) forced Blizzard's Garrison UI to start on game load. Otherwise GMM would disable features that depend on knowing what buildings you have in your garrison - i.e salvage mode and auto-assign/remove.
 * /run GMM_Click("StartMission") shortcut for macros.

### 2015-02-02 v21
 * LDB module to show currently working followers.
 * Fix some more auto-assign errors with incorrect detection of free or busy best follower candidates.

### 2015-01-22 v20
 * Fix auto-assign incorrectly preferring busy follower if it had lower ilevel and was further down in list.

### 2015-01-18 v19
 * Fix auto-assign button didn't noticing changes in follower status in realtime like tooltip does - it would refuse to auto-assign back followers that were working when you opened architect table.
 * When several followers of same level available to be assigned to building, select lowest ilevel among free followers.
 * Allow fully maxed teams on XP missions when player have Salvage Yard and all unmaxed followers are busy.

### 2015-01-12 v18
 * Fix tooltip errors on mass assign/remove buttons.

### 2015-01-12 v17
 * Mass assign/remove buttons on garrison architect table screen.
 * Prefer lowest level/ilevel followers among otherwise identical results.

### 2014-12-23 v16
 * Use special ilvl border for portrait and force abbreviated text - helps Chinese client against ilevel string overflowing out of frame.
 * Save/restore followers set in party on mission page for better compatibility with addons that pre-seed party (like MP).

### 2014-12-23 v15
 * Show iLevel instead of maxed level directly on follower portrait in all lists, just like it works in party on mission page.

### 2014-12-17 v14
 * Refresh shipment data when calculating alert about followers for orders, or it'd be stuck on info you've last seen on garrison landing page.

### 2014-12-16 v13
 * Detect and alert below follower's party portrait on mission page if there are orders ready in building that this follower could boost.
 * GR yield mode - add a second set of buttons with best average GR yield on relevant missions.
 * Dim missions if you don't have enough GR to start as well.

### 2014-12-05 v12
 * Fix forgotten settings save - ignored followers are now remembered.

### 2014-12-05 v11
 * Remove XP bonus icons from buttons with maxed out parties.
 * Follower ignore support.

### 2014-12-02 v10
 * Fix all event handling related lags.

### 2014-11-30 v9
 * Fix stop in mission list when you only have free maxed out followers and all missions after first XP-only reward is not calculated.

### 2014-11-29 v8
 * Fix dimming spilling over to active missions
 * Add global unregistering support for AceEvent-3.0. Removes lag while working with Gear Grinder and any other Ace3 addon.

### 2014-11-28 v7
 * Add top team to each mission on mission list screen
 * Dim missions that require more followers than you really have

### 2014-11-25 v6
 * Deprioritize maxed out followers on follower XP reward missions, less - better; full maxed teams completely disallowed
 * Expose support for macroing button clicks
 * Add support for unregistering events in FollowerLocationInfo addon - otherwise it'd cause GMM to lag just as Blizzard UI did

### 2014-11-23 v5
 * Fix performance: stop Blizzard UI from following follower move in/out party and try to re-process/re-draw entire followers list on each. Keep in mind that 3 followers mission analyze could easy produce up to thousand moves.

### 2014-11-23 v4
 * Fix problem with material multiplier priority/icon shown on money reward missions

### 2014-11-23 v3
 * Add XP/GR/time bonus icons to buttons
 * On-demand loading with Garrison UI

### 2014-11-22 v2
 * Fix problem with successive setting of parties that have same follower in different position leaving an empty slot until you press button second time.

### 2014-11-21 v1
 * Initial implementation: suggestions at mission page.