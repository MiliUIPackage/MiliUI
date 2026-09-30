------------------------------------------------------------
-- MiliUI_SoundPack：把一批音效註冊進 LibSharedMedia，給套組裡所有有音效下拉選單的插件用
--
-- 授權：GPL-2.0（見同資料夾的 LICENSE）。Sounds\ 底下的音檔與下面這張名稱對照表取自
-- WeakAuras 5.21.1（https://github.com/WeakAuras/WeakAuras2，GPL-2.0），音檔未經修改；
-- Sounds\PowerAuras\ 那批是它從更早的 Power Auras 繼承來的。出處與說明見 README.md。
--
-- 名稱沿用原本的註冊名：別的插件存檔裡記的是 LibSharedMedia 的名稱，同名才接得上。
-- 數字的那幾筆是暴雪自己的音效檔案編號，不帶檔案。
------------------------------------------------------------
local BASE = "Interface\\AddOns\\MiliUI_SoundPack\\Sounds\\"

local SOUNDS = {
    { "Heartbeat Single", BASE .. "WeakAuras\\HeartbeatSingle.ogg" },
    { "Batman Punch", BASE .. "WeakAuras\\BatmanPunch.ogg" },
    { "Bike Horn", BASE .. "WeakAuras\\BikeHorn.ogg" },
    { "Boxing Arena Gong", BASE .. "WeakAuras\\BoxingArenaSound.ogg" },
    { "Bleat", BASE .. "WeakAuras\\Bleat.ogg" },
    { "Cat Meow", BASE .. "WeakAuras\\CatMeow2.ogg" },
    { "Kitten Meow", BASE .. "WeakAuras\\KittenMeow.ogg" },
    { "Robot Blip", BASE .. "WeakAuras\\RobotBlip.ogg" },
    { "Sharp Punch", BASE .. "WeakAuras\\SharpPunch.ogg" },
    { "Water Drop", BASE .. "WeakAuras\\WaterDrop.ogg" },
    { "Air Horn", BASE .. "WeakAuras\\AirHorn.ogg" },
    { "Applause", BASE .. "WeakAuras\\Applause.ogg" },
    { "Banana Peel Slip", BASE .. "WeakAuras\\BananaPeelSlip.ogg" },
    { "Blast", BASE .. "WeakAuras\\Blast.ogg" },
    { "Cartoon Voice Baritone", BASE .. "WeakAuras\\CartoonVoiceBaritone.ogg" },
    { "Cartoon Walking", BASE .. "WeakAuras\\CartoonWalking.ogg" },
    { "Cow Mooing", BASE .. "WeakAuras\\CowMooing.ogg" },
    { "Ringing Phone", BASE .. "WeakAuras\\RingingPhone.ogg" },
    { "Roaring Lion", BASE .. "WeakAuras\\RoaringLion.ogg" },
    { "Shotgun", BASE .. "WeakAuras\\Shotgun.ogg" },
    { "Squish Fart", BASE .. "WeakAuras\\SquishFart.ogg" },
    { "Temple Bell", BASE .. "WeakAuras\\TempleBellHuge.ogg" },
    { "Torch", BASE .. "WeakAuras\\Torch.ogg" },
    { "Warning Siren", BASE .. "WeakAuras\\WarningSiren.ogg" },
    { "Lich King Apocalypse", 554003 },
    { "Sheep Blerping", BASE .. "WeakAuras\\SheepBleat.ogg" },
    { "Rooster Chicken Call", BASE .. "WeakAuras\\RoosterChickenCalls.ogg" },
    { "Goat Bleeting", BASE .. "WeakAuras\\GoatBleating.ogg" },
    { "Acoustic Guitar", BASE .. "WeakAuras\\AcousticGuitar.ogg" },
    { "Synth Chord", BASE .. "WeakAuras\\SynthChord.ogg" },
    { "Chicken Alarm", BASE .. "WeakAuras\\ChickenAlarm.ogg" },
    { "Xylophone", BASE .. "WeakAuras\\Xylophone.ogg" },
    { "Drums", BASE .. "WeakAuras\\Drums.ogg" },
    { "Tada Fanfare", BASE .. "WeakAuras\\TadaFanfare.ogg" },
    { "Squeaky Toy Short", BASE .. "WeakAuras\\SqueakyToyShort.ogg" },
    { "Error Beep", BASE .. "WeakAuras\\ErrorBeep.ogg" },
    { "Oh No", BASE .. "WeakAuras\\OhNo.ogg" },
    { "Double Whoosh", BASE .. "WeakAuras\\DoubleWhoosh.ogg" },
    { "Brass", BASE .. "WeakAuras\\Brass.mp3" },
    { "Glass", BASE .. "WeakAuras\\Glass.mp3" },
    { "Voice: Adds", BASE .. "WeakAuras\\Adds.ogg" },
    { "Voice: Boss", BASE .. "WeakAuras\\Boss.ogg" },
    { "Voice: Circle", BASE .. "WeakAuras\\Circle.ogg" },
    { "Voice: Cross", BASE .. "WeakAuras\\Cross.ogg" },
    { "Voice: Diamond", BASE .. "WeakAuras\\Diamond.ogg" },
    { "Voice: Don't Release", BASE .. "WeakAuras\\DontRelease.ogg" },
    { "Voice: Empowered", BASE .. "WeakAuras\\Empowered.ogg" },
    { "Voice: Focus", BASE .. "WeakAuras\\Focus.ogg" },
    { "Voice: Idiot", BASE .. "WeakAuras\\Idiot.ogg" },
    { "Voice: Left", BASE .. "WeakAuras\\Left.ogg" },
    { "Voice: Moon", BASE .. "WeakAuras\\Moon.ogg" },
    { "Voice: Next", BASE .. "WeakAuras\\Next.ogg" },
    { "Voice: Portal", BASE .. "WeakAuras\\Portal.ogg" },
    { "Voice: Protected", BASE .. "WeakAuras\\Protected.ogg" },
    { "Voice: Release", BASE .. "WeakAuras\\Release.ogg" },
    { "Voice: Right", BASE .. "WeakAuras\\Right.ogg" },
    { "Voice: Run Away", BASE .. "WeakAuras\\RunAway.ogg" },
    { "Voice: Skull", BASE .. "WeakAuras\\Skull.ogg" },
    { "Voice: Spread", BASE .. "WeakAuras\\Spread.ogg" },
    { "Voice: Square", BASE .. "WeakAuras\\Square.ogg" },
    { "Voice: Stack", BASE .. "WeakAuras\\Stack.ogg" },
    { "Voice: Star", BASE .. "WeakAuras\\Star.ogg" },
    { "Voice: Switch", BASE .. "WeakAuras\\Switch.ogg" },
    { "Voice: Taunt", BASE .. "WeakAuras\\Taunt.ogg" },
    { "Voice: Triangle", BASE .. "WeakAuras\\Triangle.ogg" },
    { "Aggro", BASE .. "PowerAuras\\aggro.ogg" },
    { "Arrow Swoosh", BASE .. "PowerAuras\\Arrow_Swoosh.ogg" },
    { "Bam", BASE .. "PowerAuras\\bam.ogg" },
    { "Polar Bear", BASE .. "PowerAuras\\bear_polar.ogg" },
    { "Big Kiss", BASE .. "PowerAuras\\bigkiss.ogg" },
    { "Bite", BASE .. "PowerAuras\\BITE.ogg" },
    { "Burp", BASE .. "PowerAuras\\burp4.ogg" },
    { "Cat", BASE .. "PowerAuras\\cat2.ogg" },
    { "Chant Major 2nd", BASE .. "PowerAuras\\chant2.ogg" },
    { "Chant Minor 3rd", BASE .. "PowerAuras\\chant4.ogg" },
    { "Chimes", BASE .. "PowerAuras\\chimes.ogg" },
    { "Cookie Monster", BASE .. "PowerAuras\\cookie.ogg" },
    { "Electrical Spark", BASE .. "PowerAuras\\ESPARK1.ogg" },
    { "Fireball", BASE .. "PowerAuras\\Fireball.ogg" },
    { "Gasp", BASE .. "PowerAuras\\Gasp.ogg" },
    { "Heartbeat", BASE .. "PowerAuras\\heartbeat.ogg" },
    { "Hiccup", BASE .. "PowerAuras\\hic3.ogg" },
    { "Huh?", BASE .. "PowerAuras\\huh_1.ogg" },
    { "Hurricane", BASE .. "PowerAuras\\hurricane.ogg" },
    { "Hyena", BASE .. "PowerAuras\\hyena.ogg" },
    { "Kaching", BASE .. "PowerAuras\\kaching.ogg" },
    { "Moan", BASE .. "PowerAuras\\moan.ogg" },
    { "Panther", BASE .. "PowerAuras\\panther1.ogg" },
    { "Phone", BASE .. "PowerAuras\\phone.ogg" },
    { "Punch", BASE .. "PowerAuras\\PUNCH.ogg" },
    { "Rain", BASE .. "PowerAuras\\rainroof.ogg" },
    { "Rocket", BASE .. "PowerAuras\\rocket.ogg" },
    { "Ship's Whistle", BASE .. "PowerAuras\\shipswhistle.ogg" },
    { "Gunshot", BASE .. "PowerAuras\\shot.ogg" },
    { "Snake Attack", BASE .. "PowerAuras\\snakeatt.ogg" },
    { "Sneeze", BASE .. "PowerAuras\\sneeze.ogg" },
    { "Sonar", BASE .. "PowerAuras\\sonar.ogg" },
    { "Splash", BASE .. "PowerAuras\\splash.ogg" },
    { "Squeaky Toy", BASE .. "PowerAuras\\Squeakypig.ogg" },
    { "Sword Ring", BASE .. "PowerAuras\\swordecho.ogg" },
    { "Throwing Knife", BASE .. "PowerAuras\\throwknife.ogg" },
    { "Thunder", BASE .. "PowerAuras\\thunder.ogg" },
    { "Wicked Male Laugh", BASE .. "PowerAuras\\wickedmalelaugh1.ogg" },
    { "Wilhelm Scream", BASE .. "PowerAuras\\wilhelm.ogg" },
    { "Wicked Female Laugh", BASE .. "PowerAuras\\wlaugh.ogg" },
    { "Wolf Howl", BASE .. "PowerAuras\\wolf5.ogg" },
    { "Yeehaw", BASE .. "PowerAuras\\yeehaw.ogg" },
}

local function Register()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM then return false end
    for i = 1, #SOUNDS do
        -- 已經有同名的（原插件自己也載入時）Register 會回 false，不覆蓋
        LSM:Register("sound", SOUNDS[i][1], SOUNDS[i][2])
    end
    return true
end

-- LibSharedMedia 可能比我們晚載入（它是別的插件內嵌的）：先試一次，登入時再補
if not Register() then
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        Register()
    end)
end
