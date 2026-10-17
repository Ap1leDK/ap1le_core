-- Notifikationer på klienten (spillerens egen computer).
-- Selve tegningen sker i NUI-vinduet (html/js/notify.js), her sender vi bare beskeden derhen.

-- Notifikationer, der kommer før NUI-siden er klar, venter her (se client/nui.lua)
local queue = {}

-- Viser en notifikation. Se shared/notify.lua for de to måder at kalde den på
local function Notify(data, notifyType, duration)
    local notification = NormalizeNotify(data, notifyType, duration)
    if not notification then return end

    if not NuiReady then
        -- Samme regel som på skærmen: er der for mange, ryger den ældste
        if #queue >= Config.Notify.MaxVisible then table.remove(queue, 1) end
        queue[#queue + 1] = notification
        return
    end

    SendNUIMessage({ action = 'notify', notification = notification })

    if Config.Notify.Sound then
        -- -1 = lad spillet selv vælge et lyd-ID. Den sidste værdi er ikke dokumenteret af FiveM,
        -- men true er det, man normalt bruger. Frontend-lyde høres kun af spilleren selv
        PlaySoundFrontend(-1, Config.Notify.SoundName, Config.Notify.SoundSet, true)
    end
end

-- Når siden er klar: send dem, der ventede i køen
OnNuiReady(function()
    local waiting = queue
    queue = {}
    for _, notification in ipairs(waiting) do Notify(notification) end
end)

-- Andre scripts på klienten: exports.ap1le_core:Notify(...) (eller Ap1le.Notify via imports.lua)
exports('Notify', Notify)

-- Serveren sender notifikationer hertil (server/notify.lua). Kun serveren kan sende en net-event til en
-- bestemt spiller, så andre spillere kan ikke sende notifikationer til dig
RegisterNetEvent('ap1le_core:notify', function(data)
    Notify(data)
end)
