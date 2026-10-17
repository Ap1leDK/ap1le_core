-- Radar: politiets fartmåler i bilen. Viser egen fart i midten og op til to køretøjer (foran og bagved) med fart,
-- retning, nummerplade, model og en statuslinje (fx "EFTERLYST · Anders Jensen").
--   Ap1le.ShowRadar({
--       locked = false, speed = 54,
--       slots = {
--           { label = 'Foran', plate = 'ABC 123', model = 'Sultan', speed = 87, direction = 'same',
--             status = 'wanted', statusText = 'EFTERLYST', detail = 'Anders Jensen' },
--           { label = 'Bagved', empty = true },
--       },
--   })
--   Ap1le.HideRadar()
--   Ap1le.IsRadarOpen()
--   AddEventHandler('ap1le_core:radarState', function(open, position) ... end)   -- lokal event, når radaren åbnes/lukkes (position = Config.Radar.Position)
-- ShowRadar både viser og opdaterer. Den må gerne kaldes flere gange i sekundet: der sendes kun noget til siden,
-- når indholdet har ændret sig. Kun til at se på: tager ikke musen eller tastaturet. Tegnes af html/js/radar.js

local current = nil  -- det, der vises: { owner, payload, text }
local sentText = nil -- teksten (json), siden sidst fik. nil = intet sendt endnu

local MAX_SLOTS = 2
local STATUSES = { wanted = true, ok = true, info = true, muted = true, checking = true }
local DIRECTIONS = { same = true, opposite = true }

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

-- En fart som heltal 0-999, eller nil (siden viser så "–")
local function toSpeed(value)
    local number = finite(value)
    if not number then return nil end
    number = math.max(0, math.min(number, 999))
    return math.floor(number + 0.5)
end

-- Tekst klippet til max tegn. Tom tekst giver standarden (eller tom tekst, hvis der ingen er)
local function text(value, max, default)
    local result = CutText(ToText(value), max)
    if result == '' then return default or '' end
    return result
end

local function normalizeSlot(slot)
    local label = text(slot.label, 12)
    if slot.empty == true then
        return { label = label, empty = true, emptyText = text(slot.emptyText, 30, 'Intet køretøj') }
    end

    local status = slot.status
    if type(status) ~= 'string' or not STATUSES[status] then status = 'muted' end
    return {
        label = label,
        empty = false,
        plate = text(slot.plate, 10),
        model = text(slot.model, 24),
        speed = toSpeed(slot.speed),
        direction = DIRECTIONS[slot.direction] and slot.direction or nil,
        status = status,
        statusText = text(slot.statusText, 24),
        detail = text(slot.detail, 40),
    }
end

-- Scriptets tabel -> ren tekst og tal til NUI-siden
local function normalize(data)
    if type(data) ~= 'table' then
        fail('ShowRadar skal have en tabel, fx { speed = 54, slots = { { label = \'Foran\', empty = true } } }')
    end

    local radar = {
        title = text(data.title, 24, 'Radar'),
        locked = data.locked == true,
        lockedText = text(data.lockedText, 16, 'Låst'),
        speed = toSpeed(data.speed),
        speedLabel = text(data.speedLabel, 16, 'Egen fart'),
        unit = text(data.unit, 8, 'km/t'),
        slots = {},
    }

    if type(data.slots) == 'table' then
        for _, slot in ipairs(data.slots) do
            if #radar.slots >= MAX_SLOTS then break end
            if type(slot) == 'table' then radar.slots[#radar.slots + 1] = normalizeSlot(slot) end
        end
    end
    return radar
end

-- Sender kun, hvis siden ikke allerede viser præcis det samme (ShowRadar kaldes ~5 gange i sekundet)
local function send()
    if not NuiReady or not current or current.text == sentText then return end
    sentText = current.text
    SendNUIMessage({ action = 'radar:show', radar = current.payload })
end

-- Fortæller andre scripts på klienten (fx ap1le_hud, der løfter speedometeret), at radaren er åbnet eller
-- lukket. Kun ved en ændring - ikke ved hver opdatering. Andet argument er Config.Radar.Position (speedometeret
-- skal kun løftes, når radaren står nederst i midten)
local function radarState(open)
    TriggerEvent('ap1le_core:radarState', open, Config.Radar.Position)
end

local function ShowRadar(data)
    -- Hvem kaldte? (så radaren kan skjules, hvis det script stoppes)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    local payload = normalize(data)
    local wasOpen = current ~= nil
    current = { owner = owner, payload = payload, text = json.encode(payload) }
    send()
    if not wasOpen then radarState(true) end
    return true
end

local function HideRadar()
    if not current then return end
    current = nil
    sentText = nil
    if NuiReady then SendNUIMessage({ action = 'radar:hide' }) end
    radarState(false)
end

local function IsRadarOpen()
    return current ~= nil
end

exports('ShowRadar', ShowRadar)
exports('HideRadar', HideRadar)
exports('IsRadarOpen', IsRadarOpen)

-- Blev radaren vist, før NUI-siden var klar? Så send den nu
OnNuiReady(function()
    sentText = nil
    send()
end)

-- Stoppes det script, der viste radaren, skjules den (ellers ville den stå der for evigt)
AddEventHandler('onClientResourceStop', function(resource)
    if current and current.owner == resource and resource ~= GetCurrentResourceName() then HideRadar() end
end)

-- Stoppes core: glem radaren (siden forsvinder af sig selv), og sig det til de andre scripts
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local wasOpen = current ~= nil
    current = nil
    sentText = nil
    if wasOpen then radarState(false) end
end)
