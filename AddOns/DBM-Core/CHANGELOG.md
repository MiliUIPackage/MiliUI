# Deadly Boss Mods Core

## [8.3.29](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/8.3.29) (2020-07-30)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/8.3.28...8.3.29) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Updated Shriekwing and Generals with changes made it todays build.  
    I just want to add, last minute changes that literally rework how parts of fight work, the day before testing, is pretty crappy thing to do. :\  
- Fix typo  
- Update koKR (#278)  
- - Updated core to support a new type of health reporting, highest seen during corse of fight. This will generally be used on "heal up the boss" fights (currenty 3 mods will use it right off the bat)  
    - Fixed a bug in core where timer text creation in object was doing pointless checks of trying to set a nil value to something that's not nil, using a nil value, which ended up setting that nil value, to nil.  
    - Moved two custom locals from hivemind into core common locales since they are now used by two mods and probably more in future.  
    - Added Dark Descent to Shriekwing, which was added after initial drycode.  
    - Added Stonequake to sludgefist and counts to pretty much all remaining timers, plus more timer notes.  
    - Full Stoneborne Generals drycode, minus the adds.  
    - Fixed a bug with hivemind where mod was reporting lowest % boss of the two, instead of highest boss of two, which is expected behavior for multi boss fights.  
- Few kael updates but adds timers still need work,I just don't want to do it right now because data is kind of a mess.  
- Update zhTW (#277)  
- Update Sludgefist post testing. Will wrap up Kael tomorrow or sunday.  
- Push quick fix to fact chain link spellId for targetting was removed from game  
- Fix typo  
- Added shared agony to necrotic wake trash  
- Putting foot down.  
    Guild syncs can now trigger the force disable  
    Code changed to prevent what's effectively "batching" from preventing code from running while at it.  
- Fixed bug from last where icon wouldn't clear from shared suffering  
- Push mod updates for Hungering Destroyer and Lady Inverva Darkvein from todays testing  
- Fixed volatile ejection warnings to use correct ID in whisper scanning. I was right though about it being a whisper and not in combat log. Predictable.  
    With whisper fixed, also enabled the icon option for it.  
- quick fix, moved Miamsa timer to a different event since cast event is hidden  
- Reworked Margrave Stradama from transcriptor log  
- Fix it so Castle Nathria isn't flagged as trivial content and not logged by default filter options  
- Luacheck updated for 9.x deprecations (#276)  
- Added Altimor drycode  
- If i could make this button combo z+q+p+alt at same time, I would  
- Also add a basic soul infusor cast/detector to at least have some preliminary spawn notice for them, until better one is durived after testing  
- Fixed bug where Hungering Destroyer boss health % wouldn't be reported (do to missing creature ID)  
    Fixed bug where Lady Inerva's mod wouldn't show used icons in header  
    Fixed bug where Lady Inerva's mod Shared Suffering spell would be called "paranoia" instead do to copy and paste mistake  
    Fixed bug where Lady Inerva's mod Warped desires features (taunt warning, run out warning, countdown yell for Change of Heart) would not work correctly  
    Improved readability of Sun King's Redemption timers in DBM GUI options.  
- And that solves that  
- Probably gonna spit out a lot of errors, just seeing what phasing out LE_ looks like  
