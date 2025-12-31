local AllScript = {
    [18687417158] = function()
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/talahodaodethuong/Daylabancaocap/refs/heads/main/FSK-Premium.lua"
        ))()
    end,

    [83645629621104] = function()
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/talahodaodethuong/Daylabancaocap/refs/heads/main/FSK-Premium.lua"
        ))()
    end,

    [126509999114328] = function()
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/talahodaodethuong/Daylakichban/refs/heads/main/99NITF.lua"
        ))()
    end,

    [2753915549] = function()
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/htzgamingssr/Hutao-V3/refs/heads/main/Blox-Fruit-Script.lua"
        ))()
    end,

    [4442272183] = function()
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/htzgamingssr/Hutao-V3/refs/heads/main/Blox-Fruit-Script.lua"
        ))()
    end,

    [7449423635] = function()
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/htzgamingssr/Hutao-V3/refs/heads/main/Blox-Fruit-Script.lua"
        ))()
    end,
}

local currentPlaceId = game.PlaceId
local runScript = AllScript[currentPlaceId]

if runScript then
    runScript()
else
    warn("This Script Is Not Supported This Game: " .. currentPlaceId)
end
