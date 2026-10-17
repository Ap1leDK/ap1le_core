-- Notifikationer fra serveren til én spiller (eller alle).
-- Bruges fx når serveren har tjekket noget og skal fortælle spilleren resultatet:
--   exports.ap1le_core:Notify(source, 'Du fik 500 kr.', 'success')
--   exports.ap1le_core:Notify(-1, { title = 'Server', description = 'Genstart om 5 minutter', type = 'warning' })  -- -1 = alle

-- Giver true, hvis den blev sendt, ellers false (fx hvis spilleren er logget af)
local function Notify(target, data, notifyType, duration)
    target = tonumber(target)
    if not target then return false end

    -- Et spiller-ID skal høre til en, der er online (-1 = alle spillere)
    if target ~= -1 and not DoesPlayerExist(target) then return false end

    -- Rens den HER, så der aldrig sendes en kæmpe tekst over netværket
    local notification = NormalizeNotify(data, notifyType, duration)
    if not notification then return false end

    TriggerClientEvent('ap1le_core:notify', target, notification)
    return true
end

exports('Notify', Notify)
