-- Props under en progress-bjælke (fx en notesblok i hånden). Klienten beder om dem her, serveren tjekker
-- listen (CleanProgressProp i shared/progress.lua) og lægger den i spillerens state bag. Så laver ALLE klienter,
-- der kan se spilleren, de samme props (client/progress.lua).
-- OBS: en snydeklient kan skrive direkte i sin egen state bag uden om serveren. Derfor tjekker klienterne også
-- props, før de laves - serverens tjek er for de ærlige klienter, så der ikke sendes rod rundt

local PROPS_KEY = 'ap1le_progressProps'
local MIN_INTERVAL = 200 -- millisekunder mellem to "sæt props" i træk fra samme spiller

local lastSet = {}

RegisterNetEvent('ap1le_core:progressProps', function(props)
    local src = source
    local state = Player(src).state

    -- Fjern: altid tilladt (ellers kunne props blive hængende). Bagefter må en ny bjælke sætte props med det
    -- samme (fx annulleret og startet igen)
    if props == nil then
        lastSet[src] = nil
        state:set(PROPS_KEY, nil, true)
        return
    end
    if type(props) ~= 'table' then return end

    local now = GetGameTimer()
    if lastSet[src] and now - lastSet[src] < MIN_INTERVAL then return end
    lastSet[src] = now

    local clean = {}
    for i, prop in ipairs(props) do
        if i > Config.Progress.MaxProps then break end
        clean[#clean + 1] = CleanProgressProp(prop)
    end
    state:set(PROPS_KEY, #clean > 0 and clean or nil, true)
end)

AddEventHandler('playerDropped', function()
    lastSet[source] = nil
end)

-- Genstartes core midt i en bjælke, står de gamle props stadig i state bag'en - ryd dem
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, playerId in ipairs(GetPlayers()) do
        Player(playerId).state:set(PROPS_KEY, nil, true)
    end
end)
