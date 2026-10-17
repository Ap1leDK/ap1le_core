-- Fælles for klient og server: tjekker én prop til progress-bjælken (fx en notesblok i hånden).
-- Serveren tjekker props, før de lægges i spillerens state bag (server/progress.lua). Klienterne tjekker dem
-- IGEN, før de laves (client/progress.lua): en snydeklient kan skrive direkte i sin egen state bag uden om
-- serveren, så ingen klient må stole på det, der står dér

local MAX_OFFSET = 5.0 -- en prop må højst sidde 5 meter fra knoglen

local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

-- { x, y, z } med rene tal, eller nil. wrap = true: vinkler lægges ind i -360..360 i stedet for at blive afvist
local function cleanVector(value, limit, wrap)
    if type(value) ~= 'table' and type(value) ~= 'vector3' then return nil end
    local x, y, z = value.x, value.y, value.z
    if not (isFinite(x) and isFinite(y) and isFinite(z)) then return nil end
    if wrap then
        x, y, z = math.fmod(x, 360.0), math.fmod(y, 360.0), math.fmod(z, 360.0)
    elseif math.abs(x) > limit or math.abs(y) > limit or math.abs(z) > limit then
        return nil
    end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

-- Én prop -> { model, bone, pos, rot } med rene værdier, eller nil hvis noget er galt
function CleanProgressProp(prop)
    if type(prop) ~= 'table' then return nil end
    local model = prop.model
    -- Modelnavn (kun bogstaver, tal og _) eller en hash (et heltal)
    if type(model) == 'string' then
        if model == '' or #model > 64 or not model:match('^[%w_]+$') then return nil end
    elseif math.type(model) ~= 'integer' then
        return nil
    end
    local bone = math.type(prop.bone) == 'integer' and prop.bone or nil
    if not bone or bone < 0 or bone > 65535 then return nil end
    local pos = cleanVector(prop.pos, MAX_OFFSET, false)
    local rot = cleanVector(prop.rot, nil, true)
    if not pos or not rot then return nil end
    return { model = model, bone = bone, pos = pos, rot = rot }
end
