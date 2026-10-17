-- Hjælpetekst: en lille boks med en tast og en tekst, fx "[E] Gå på vagt", mens man står et bestemt sted.
--   Ap1le.ShowTextUI('Gå på vagt', 'E')                               -- tekst og tast
--   Ap1le.ShowTextUI('Omklædning', { key = 'E', icon = 'shirt' })     -- med ikon
--   Ap1le.ShowTextUI('Du er i håndjern')                              -- uden tast
--   Ap1le.HideTextUI()
-- Den viser KUN teksten - scriptet skal selv lytte efter tasten (fx IsControlJustReleased(0, 38) for E).
-- Tegnes af html/js/textui.js

local current = nil -- det, der vises: { text, key, icon, owner }

-- Fejl fra exports vises bedst med niveau 0 (uden en linje, der peger ind i FiveM's egen kode)
local function fail(message)
    error('ap1le_core: ' .. message, 0)
end

local function send()
    if not NuiReady then return end -- sendes, når siden er klar (OnNuiReady nederst)
    if current then
        SendNUIMessage({ action = 'textui:show', textui = { text = current.text, key = current.key, icon = current.icon } })
    else
        SendNUIMessage({ action = 'textui:hide' })
    end
end

-- options kan være en tekst (tasten) eller { key = 'E', icon = 'shirt' }
local function ShowTextUI(text, options)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    text = CutText(ToText(text), 120)
    if text == '' then fail('ShowTextUI skal have en tekst, fx ShowTextUI(\'Gå på vagt\', \'E\')') end

    if type(options) ~= 'table' then options = { key = options } end
    local key = CutText(ToText(options.key), 12)
    if key == '' then key = nil end -- ingen tast
    local icon = ToIcon(options.icon)

    -- Det samme igen (fx kaldt hver frame): gør ingenting, så den ikke blinker
    if current and current.text == text and current.key == key and current.icon == icon then
        current.owner = owner
        return
    end

    current = { text = text, key = key, icon = icon, owner = owner }
    send()
end

local function HideTextUI()
    if not current then return end
    current = nil
    send()
end

-- Giver true og teksten, hvis der vises en hjælpetekst
local function IsTextUIOpen()
    return current ~= nil, current and current.text or nil
end

exports('ShowTextUI', ShowTextUI)
exports('HideTextUI', HideTextUI)
exports('IsTextUIOpen', IsTextUIOpen)

-- Blev en vist, før NUI-siden var klar? Så send den nu
OnNuiReady(function()
    if current then send() end
end)

-- Stoppes det script, der viste teksten, skjules den (ellers ville den stå der for evigt)
AddEventHandler('onClientResourceStop', function(resource)
    if current and current.owner == resource and resource ~= GetCurrentResourceName() then HideTextUI() end
end)
