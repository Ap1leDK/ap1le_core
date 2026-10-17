-- Speedometer fra et andet script (fx ap1le_hud). Core tegner det IKKE selv, men skal vide, hvor det står:
-- radaren lægger sig så som et bredt panel under cirklen, og progress-bjælken og hjælpeteksten rykker op over det.
--   Ap1le.SetSpeedo({ size = 21, bottom = 1.2, lift = 2.2 })   -- i rem (samme rem som core's side, se GetScale)
--   Ap1le.SetSpeedo(false)                                     -- intet speedometer (fx når man stiger ud)
--   Ap1le.GetScale()                                           -- Config.Scale, som core's side bruger den
-- size = cirklens bredde, bottom = afstanden til skærmens bund, lift = hvor meget cirklen løftes, mens radaren
-- er åben (eventen 'ap1le_core:radarState' fra client/radar.lua). Tegnes af html/js/radar.js

local current = nil  -- det, der er sat: { owner, size, bottom, lift }
local sentText = nil -- det, siden sidst fik ('null' = intet speedometer). nil = intet sendt endnu

-- Grænserne (rem). Rækkefølgen er fast, så fejlbeskeden altid nævner det samme felt først
local FIELDS = { 'size', 'bottom', 'lift' }
local LIMITS = { size = { 10, 40 }, bottom = { 0, 10 }, lift = { 0, 10 } }

-- Fejl fra exports vises bedst med niveau 0 (uden en linje, der peger ind i FiveM's egen kode)
local function fail(message)
    error('ap1le_core: ' .. message, 0)
end

-- Scriptets tabel -> tre tal. Alt uden for grænserne (også tekst, NaN og uendelig) er en fejl
local function normalize(data)
    if type(data) ~= 'table' then
        fail('SetSpeedo skal have en tabel, fx { size = 21, bottom = 1.2, lift = 2.2 }, eller false')
    end

    local speedo = {}
    for _, name in ipairs(FIELDS) do
        local value, limit = data[name], LIMITS[name]
        -- NaN er aldrig >= noget, så den falder også her
        if type(value) ~= 'number' or not (value >= limit[1] and value <= limit[2]) then
            fail(('SetSpeedo: %s skal være et tal mellem %d og %d (rem)'):format(name, limit[1], limit[2]))
        end
        speedo[name] = value
    end
    return speedo
end

-- Sender kun, hvis siden ikke allerede har præcis det samme
local function send()
    if not NuiReady then return end -- sendes, når siden er klar (OnNuiReady nederst)
    local text = current and ('%s:%s:%s'):format(current.size, current.bottom, current.lift) or 'null'
    if text == sentText then return end
    sentText = text
    -- Uden speedometer mangler feltet helt (Lua kan ikke sende null) - siden læser det som "intet"
    SendNUIMessage({
        action = 'hud:speedo',
        speedo = current and { size = current.size, bottom = current.bottom, lift = current.lift } or nil,
    })
end

local function SetSpeedo(data)
    if data == nil or data == false then
        current = nil
    else
        local speedo = normalize(data)
        -- Hvem kaldte? (så speedometeret glemmes, hvis det script stoppes)
        speedo.owner = GetInvokingResource() or GetCurrentResourceName()
        current = speedo
    end
    send()
    return true
end

-- Størrelsen på core's brugerflade. Samme regel som html/js/core.js: et tal mellem 0,5 og 1,5, ellers
-- standarden i base.css (0,75). Så kan et andet NUI-vindue bruge præcis samme rem som core
local function GetScale()
    local scale = Config.Scale
    if type(scale) == 'number' and scale >= 0.5 and scale <= 1.5 then return scale end
    return 0.75
end

exports('SetSpeedo', SetSpeedo)
exports('GetScale', GetScale)

-- Siden starter uden speedometer. Blev et sat, før den var klar? Så send det nu
OnNuiReady(function()
    sentText = 'null'
    send()
end)

-- Stoppes det script, der satte speedometeret, glemmes det (ellers ville radaren blive ved med at lave plads)
AddEventHandler('onClientResourceStop', function(resource)
    if current and current.owner == resource and resource ~= GetCurrentResourceName() then
        current = nil
        send()
    end
end)

-- Stoppes core: glem speedometeret (siden forsvinder af sig selv). Scriptet skal kalde SetSpeedo igen,
-- når core starter igen
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    current = nil
    sentText = nil
end)
