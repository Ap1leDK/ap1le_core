-- ID-kort: et kort med foto, felter og små mærker (fx kørekort-klasser), der vises et par sekunder.
--   Ap1le.ShowCard({
--       title = 'Identitetskort', subtitle = 'Kongeriget Danmark', icon = 'id-card',
--       ped = targetPed,                                          -- valgfri: personen på fotoet
--       fields = { { label = 'Navn', value = 'Anders Jensen' }, { label = 'Født', value = '12-03-1994' } },
--       tags = { 'B', 'A' }, tagsLabel = 'Kørekort',              -- valgfri
--       duration = 8000,
--   })
--   Ap1le.HideCard()
-- Kun til at se på: kortet tager ikke musen eller tastaturet. Ét kort ad gangen - et nyt erstatter det gamle.
-- Tiden styres her i Lua (fotoet skal ryddes op, når kortet forsvinder). Tegnes af html/js/card.js

local current = nil -- kortet, der vises: { id, owner, payload, handle, photo, photoDone }
local lastId = 0

local MAX_FIELDS = 8
local MAX_TAGS = 8
local MIN_DURATION, MAX_DURATION, DEFAULT_DURATION = 2000, 30000, 8000

-- Så længe venter vi højst på fotoet (det tager normalt under et sekund). Derefter vises et ikon i stedet
local PHOTO_TIMEOUT = 4000

-- Fejl fra exports vises bedst med niveau 0 (uden en linje, der peger ind i FiveM's egen kode)
local function fail(message)
    error('ap1le_core: ' .. message, 0)
end

-- Et almindeligt tal (ikke uendelig eller NaN), ellers nil
local function finite(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
    return number
end

-- Scriptets tabel -> ren tekst til NUI-siden. Funktioner, entities osv. bliver her i Lua
local function normalize(data)
    if type(data) ~= 'table' then
        fail('ShowCard skal have en tabel, fx { title = \'Identitetskort\', fields = { { label = \'Navn\', value = \'Anders\' } } }')
    end

    local title = CutText(ToText(data.title), 40)
    local card = {
        title = title ~= '' and title or 'Identitetskort',
        subtitle = CutText(ToText(data.subtitle), 60),
        icon = ToIcon(data.icon) or 'fa-solid fa-id-card',
        fields = {},
        tags = {},
        tagsLabel = CutText(ToText(data.tagsLabel), 40),
    }

    if type(data.fields) == 'table' then
        for _, field in ipairs(data.fields) do
            if #card.fields >= MAX_FIELDS then break end
            if type(field) == 'table' then
                local label = CutText(ToText(field.label), 30)
                local value = CutText(ToText(field.value), 60)
                -- Et felt uden både overskrift og værdi viser ingenting - spring det over
                if label ~= '' or value ~= '' then card.fields[#card.fields + 1] = { label = label, value = value } end
            end
        end
    end

    if type(data.tags) == 'table' then
        for _, tag in ipairs(data.tags) do
            if #card.tags >= MAX_TAGS then break end
            local text = CutText(ToText(tag), 16)
            if text ~= '' then card.tags[#card.tags + 1] = text end
        end
    end
    -- Ingen mærker: så heller ingen overskrift til dem
    if #card.tags == 0 then card.tagsLabel = '' end

    local duration = math.floor(finite(data.duration) or DEFAULT_DURATION)
    card.duration = math.max(MIN_DURATION, math.min(duration, MAX_DURATION))
    return card
end

-- En ped, vi kan tage et foto af? (et heltal, der findes og er en ped). Ellers nil
local function toPed(value)
    local ped = math.tointeger(value)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not IsEntityAPed(ped) then return nil end
    return ped
end

-- Giver fotoet tilbage til spillet. Der kan kun være et begrænset antal på én gang, så det skal altid ske,
-- når kortet forsvinder eller bliver erstattet
local function releasePhoto(card)
    if card and card.handle then
        UnregisterPedheadshot(card.handle)
        card.handle = nil
    end
end

local function sendPhoto(card)
    if not NuiReady or current ~= card then return end
    -- photo = nil: intet foto (siden viser et ikon i stedet)
    SendNUIMessage({ action = 'card:photo', id = card.id, photo = card.photo })
end

-- Tager fotoet i en tråd, så ShowCard ikke skal vente. Kortet vises med det samme med en "indlæser"-flade,
-- og fotoet kommer, når det er klar
local function loadPhoto(card, ped)
    CreateThread(function()
        if current ~= card then return end -- allerede erstattet
        if not DoesEntityExist(ped) then -- personen er væk (fx gået ud af vores nærhed): vis ikonet
            card.photoDone = true
            return sendPhoto(card)
        end

        -- Den gennemsigtige udgave (uden sort baggrund), så kortets egen baggrund ses bag personen
        local handle = RegisterPedheadshotTransparent(ped)
        card.handle = handle

        local timeout = GetGameTimer() + PHOTO_TIMEOUT
        while not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) do
            -- Kortet er væk (skjult eller erstattet): giv fotoet tilbage (gør ingenting, hvis det allerede er sket)
            if current ~= card then return releasePhoto(card) end
            if GetGameTimer() > timeout then break end
            Wait(50)
        end
        if current ~= card then return releasePhoto(card) end

        local txd = IsPedheadshotReady(handle) and IsPedheadshotValid(handle) and GetPedheadshotTxdString(handle)
        if type(txd) == 'string' and txd:match('^[%w_]+$') then
            -- FiveM viser spillets teksturer i NUI på https://nui-img/<ordbog>/<tekstur>. Navnet genbruges af spillet
            -- (fx "pedmugshot_01"), og FiveM beder browseren huske billedet i 2 timer - derfor ?v=<tid>-<kortets id>,
            -- så et nyt kort aldrig viser et gammelt foto. Tiden er med, fordi kortenes id starter forfra, når core
            -- genstartes, mens browseren stadig husker de gamle billeder
            card.photo = ('https://nui-img/%s/%s?v=%d-%d'):format(txd, txd, GetGameTimer(), card.id)
        else
            releasePhoto(card) -- intet foto inden for tiden: ryd op og vis ikonet
        end
        card.photoDone = true
        sendPhoto(card)
    end)
end

local function sendShow(card)
    if not NuiReady then return end -- sendes, når siden er klar (OnNuiReady nederst)
    SendNUIMessage({ action = 'card:show', card = card.payload })
    if card.photoDone and card.payload.photo then sendPhoto(card) end -- uden ped står ikonet der allerede
end

local function HideCard()
    if not current then return end
    local card = current
    current = nil
    releasePhoto(card)
    if NuiReady then SendNUIMessage({ action = 'card:hide', id = card.id }) end
end

local function ShowCard(data)
    -- Hvem kaldte? (så kortet kan skjules, hvis det script stoppes)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    local payload = normalize(data)
    local ped = toPed(data.ped)

    -- Et nyt kort erstatter det gamle (og det gamle foto gives tilbage)
    if current then releasePhoto(current) end

    lastId = lastId + 1
    payload.id = lastId
    payload.photo = ped ~= nil -- true = der kommer et foto (siden viser "indlæser" imens)
    local card = { id = lastId, owner = owner, payload = payload, photoDone = ped == nil }
    current = card
    sendShow(card)
    if ped then loadPhoto(card, ped) end

    -- Skjul efter tiden - men kun, hvis det stadig er DETTE kort
    SetTimeout(payload.duration, function()
        if current == card then HideCard() end
    end)
    return true
end

exports('ShowCard', ShowCard)
exports('HideCard', HideCard)

-- Blev et kort vist, før NUI-siden var klar? Så send det nu
OnNuiReady(function()
    if current then sendShow(current) end
end)

-- Stoppes det script, der viste kortet, skjules det
AddEventHandler('onClientResourceStop', function(resource)
    if current and current.owner == resource and resource ~= GetCurrentResourceName() then HideCard() end
end)

-- Stoppes core: giv fotoet tilbage til spillet (siden forsvinder af sig selv)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not current then return end
    releasePhoto(current)
    current = nil
end)
