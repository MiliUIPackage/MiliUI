# Readme

Do you keep missing Bloodlust? Do you wish it would be a bit more... *eventful*?

This addon plays the famous song Power of the Horde (http://www.youtube.com/watch?v=ISA_nG5smy0) whenever you gain Bloodlust for that little extra kick. Whether or not you actually need the extra reminder, I recommend you try it out!

Oh, and it does work with Heroism as well, for all those Alliance shamans who wish they'd get to experience what the might of the Horde is all about.

Still not convinced? Watch this video (http://www.youtube.com/watch?v=TGXXso41v7o#t=85s) (mixed mode)! (Enhanced Bloodlust at 1:25, the link should take you directly there)

NOTE: Only enabled in combat. If you want to test, use the slash command or find a training dummy :)

## Features

Enhanced Bloodlust used to include a large number of features, such as shouts or on-screen messages. The AddOn is now rewritten for simplicity and awesomeness.

* Plays the song "The Power of the Horde" whenever you gain Bloodlust, cast by either yourself or someone else.
* Mutes in-game music during the duration of the track.
* Different modes available.

### Modes

* "Duration mode" (default) will only play a part from the song during the duration of Bloodlust
* "Short mode" will only play the first few seconds of the song ("Storm, Earth and Fire, heed my call!")
* "Mixed mode" will play both the sound file of Short mode and Duration mode at the same time.
* "Long mode" will play the entire song.

## Configuration

From version 60000 and onwards configuration is no longer done with slash commands. Instead, a separate config.lua file is used to configure how the AddOn behaves. It is recommended that you copy the file and name it myconfig.lua so that your configuration does not get overwritten when the AddOn is updated.

### Values

* config.spells - array of spellIDs for the auras that the AddOn should look for
* config.sound - array of sound files that should be played (all at once)
* config.length - the duration of the longest sound (the AddOn doesn't know how the duration of the sound files, so you need to tell it)

### Commands

* /EnhBL - play the sound(s) according to the current configuration

## Limitations (warning: technical)

Due to unknown reasons, PlayMusic() does not work reliably in certain situations (such as in many raid encounters). Therefore, PlaySoundFile() has to be used. This means that once the track begins to play, there is no way of stopping it. Because of that I have included a number of modes - hopefully everyone finds one they like (if you don't, why not leave me a comment?).

## Downloads

Release versions of Enhanced Bloodlust can be found on WoWInterface and Curse:

* http://www.wowinterface.com/downloads/info9548-EnhancedBloodlust.html
* http://www.curse.com/addons/wow/enhbloodlust

Development versions of Enhanced Bloodlust can be found on github:

* https://github.com/Vilkku/EnhBloodlust
