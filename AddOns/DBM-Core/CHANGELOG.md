# DBM - Core

## [10.2.46](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/10.2.46) (2024-05-30)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/10.2.45...10.2.46) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Ready the tag  
- Fix bug causing all cata journal based spells in RAID to show invalid classic support message, make this a force update  
    Also force update for retail since this core update also has the disconnect workaround for long character names on long realm names that blizzard has taken longer than a month to fix themselves  
- Work around blizzard whisper disconnect bug (for the second time in recent years) with addon comms  
- Tests: enforce minimum real FPS to avoid lags  
    This also enables a "run as fast as possible" mode just by setting the  
    factor to a very huge value.  
- UI/Tests: small UI fixes  
    Correctly handle tests named like "a/b/c" and "a/b" at the same time.  
    (But please don't create tests named like that)  
- UI/Tests: Add big "Run all" button  
- Tests: clean up use of DBM.Options for timewarp setting  
- UI/Tests: make time warp slider exponential  
- Split tocs and cleanup tocs  
- Add UI for tests  
- Make UpdateReminder frame more flexible  
    Automatically set height to allow for more than 3 lines of text and  
    avoid odd frame size for short texts (e.g., URL copy frames).  
    Also allow user to configure width and text alignment.  
- Clean up combat state on DBM:Disable()  
- Tests: simulate a consistent frame rate of 30 fps  
    Previously the simulated frame rate was the same as the real frame rate,  
    so if you set a high replay speed and your game got laggy you simulated  
    fewer OnUpdate calls, which can make logs less deterministic.  
    The diff in Diurna shows such a case; it now consistently unschedules  
    the scheduled announce before the event gets processed.  
- Tests: correctly hook OnUpdate of frames created during the test  
- Tests: fix rewiring args.destName to real player name  
- Diurna: update test with new feature  
    GetTime() global is now overriden in mods when tests are running, no  
    more ugly self:GetTime() :)  
- Tests: add a way to acknowledge/ignore warnings  
- Tests: report deltas between Show/Start calls  
- Tests: track and report calls to :Schedule() properly  
    Potential problem: recursive schedule calls will look a bit ugly in the  
    test report, but so far I haven't seen a mod that uses this excessively.  
- Tests: fix error on importing test results if you have other files in target dir  
- Tests: Replay UNIT_* events without implying they are _UNFILTERED  
- Tests: make it easier to inject mocks into mods by changing the mod's environment  
- Tests: add mock for UnitGUID  
- Fix some potential nil index errors  
    Not a problem in every instance of this because usually there is some  
    check on the Unit that would never pass if it doesn't exist.  
- Scheduler: clean up  
    I'm not sure why I wrote it that way 🤷‍♂️  
    unpack() takes parameters to handle exactly this case.  
- Fix https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1109 by actually canceling seeds timer on intermission  
- bump alpha  
