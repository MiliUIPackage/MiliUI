# <DBM Mod> Dungeons (DF)

## [r102-40-g8db5f1a](https://github.com/DeadlyBossMods/DBM-Dungeons/tree/8db5f1a7a9098f59fbec24cc288dee0eed94b6dc) (2023-11-07)
[Full Changelog](https://github.com/DeadlyBossMods/DBM-Dungeons/compare/r102...8db5f1a7a9098f59fbec24cc288dee0eed94b6dc) [Previous Releases](https://github.com/DeadlyBossMods/DBM-Dungeons/releases)

- WA compat fixes  
- quit your bitching, those aren't even used  
- Dawn of the infinite part 2 updated for 10.2  
- fix typo  
- Dawn of infinte boss pass, part 1  
    NOTE: This sets timers to 10.2 version, if using alpha version on live, incorrect timers will appear until patch is live.  
- and fix missing spellid  
- fix typo  
- It wouldn't be DHT without the final boss also having spell queuing problems. zone is 4/4 for dumb horrible timers. Anyways, this boss also uses corrective timers after each cast on last as best it can to deal with issue, like all the other bosses.  
    Also updated for 10.2 obviously. DHT bosses done.  
- fix error  
- DHT boss review taking longer tan I'd like, 3/4 done, will do 4th tomorrow. two of these needed extra work due to severe variations and spell queuing problems. think they're mostly sorted by auto updating timer code though but may need adjustments as more data comes in.  
- Signficiant comment and unused code cleanup for dragonflight dungeons now that we're late dragonflight now and these dungeons have run their course for most part  
    DoTI will be cleaned up post 10.2 update, which is soon  
- Fix typo  
- Reviewed and updated all the bosses in Black Rook Hold for 10.2  
     - Almost all timers are now count timers  
     - Many accuracy improvements  
     - Few new alerts  
- fix an ID  
- Move trash mods to the nameplate timer objects  
- Fix missing spellids and lack of mod conventions  
- Fix bug  
- Finished waycrest manor boss pass  
     - Added to most timers and alerts were it seemed useful  
     - Timer improvements for 10.2  
     - Added anything that might have been missing that seemed useful for M+  
- Improve encounter detection for two old instances after confirming encounter events do fire in them on retail (and classic era hardcore too I guess with diff Ids. but not in wrath 🤷‍♂️)  
- fix conventions  
- Full pass on Atal'Dazar bosses  
     - Almost all timers now have counts  
     - Timer accuracy massively improved on yazma and rezan  
     - Add marking, announce and timer added on Alunza  
     - Pursuit personal/target alerts fixed for 10.2  
- no idea how that got there  
- Re-add support for legacy Scarlet dungeons to retail dungeon mods.  
    Scoped SM and scholo to have hard zone requirements particularly for retail so bosses that kept same CID in reworks don't engage both mods  
- update Atal Dazar spell keys to match LW  
- Some spellid/key fixes for dungeon weak aura compat for dawn of the infinite  
    couple warning additions for same reason  
- Upate Chronikar to actually use debuff with chat bubbles. Also changed spellkey for compat  
- 3 obvious bugfixes. Few more changes after I get home  
- Push updated Yalnu. nice easy one after last one :D  
- Forgot to scope that. that only happens if telu dies before gola  
- Er, how'd that get up there ?  
- Only one mod done so far tonight, but in my defense, this one was kinda BS. 30+ log craws to find 3 pulls that did bosses in non standard order just to desipher a solution to explain a seemingly unexplainable timer reset.  
    Anyways, ancient protectors is done, subject to my convoluted solution blowing up or breaking cause blizzard decides to change it after I did all that beauitful scratch work :D  
- Switch Hackclaws to HardStop method  
- fix bad copy paste  
- Begin work on everbloom rework. half done. Otherhalf likely after raid testing tomorrow. time for a sleep  
- Disable GroupSpells across the board on dungeon mods, since weak aura keys need precision anyways and it fixes a bug with panel rendering on on emod  
- Update koKR (#147)  
- fix bad copypaste  
- Push the full throne of tides boss rework for 10.2  
- fix last  
- template throne of tides to hybrid mod format compatible with retail and PTR, with forward planning for cataclysm classic (ie this likely isn't temporary but full fledged dual mod support for both old versions and new versions of fights)  
