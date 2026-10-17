-- Fælles for klient og server: gør en notifikation "pæn og sikker", før den vises eller sendes.
-- Et script kan kalde Notify på to måder, og begge ender her:
--   Notify('Du fik 500 kr.', 'success')                                  (kort)
--   Notify({ title = 'Bank', description = 'Du fik 500 kr.', type = 'success', duration = 8000 })  (lang)
-- ToText og CutText ligger i shared/text.lua

local MAX_TITLE = 60
local MAX_DESCRIPTION = 300

-- Giver en færdig notifikation { title, description, type, duration } eller nil, hvis der ikke er noget at vise
function NormalizeNotify(data, notifyType, duration)
    if type(data) == 'string' or type(data) == 'number' then
        data = { description = data, type = notifyType, duration = duration }
    end
    if type(data) ~= 'table' then return nil end

    -- Ukendt type (eller stavefejl) bliver til 'info' i stedet for at fejle
    local kind = Config.Notify.Types[data.type] and data.type or 'info'

    local title = ToText(data.title)
    local description = ToText(data.description)
    if title == '' and description == '' then return nil end -- intet at vise

    -- Uden overskrift bruges typens navn, fx "Succes"
    title = title ~= '' and CutText(title, MAX_TITLE) or Config.Notify.Types[kind].title
    description = CutText(description, MAX_DESCRIPTION)

    -- Varighed i millisekunder, holdt inden for grænserne i config.lua
    local ms = math.floor(tonumber(data.duration) or Config.Notify.DefaultDuration)
    ms = math.max(Config.Notify.MinDuration, math.min(ms, Config.Notify.MaxDuration))

    return { title = title, description = description, type = kind, duration = ms }
end
