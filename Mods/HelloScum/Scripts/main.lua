local ModName = "HelloScum"

print(string.format("[%s] main.lua loaded\n", ModName))

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context)
    print(string.format("[%s] ClientRestart fired -- player spawned in world\n", ModName))
end)

RegisterConsoleCommandHandler("hello", function(FullCommand, Parameters, OutputDevice)
    OutputDevice:Log(string.format("Hello from %s!", ModName))
    return true
end)
