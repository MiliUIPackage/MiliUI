if Enum and Enum.VoiceTtsDestination then
    for k, v in pairs(Enum.VoiceTtsDestination) do
        print(k, v)
    end
else
    print("Enum.VoiceTtsDestination not found!")
end
