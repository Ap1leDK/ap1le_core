-- Dialoger: en popup midt på skærmen, der venter på spillerens svar.
--   Ap1le.InputDialog(titel, felter, indstillinger) -> liste med svarene (i samme rækkefølge som felterne), eller nil
--   Ap1le.Confirm({ title, content, ... })          -> true (bekræftet) eller false (annulleret)
-- Begge "venter": koden efter kaldet kører først, når spilleren har svaret. Tegnes af html/js/dialog.js
--
-- VIGTIGT: alt, hvad spilleren skriver, kan være snyd. Sendes svaret til serveren, skal serveren tjekke det igen

local active = nil -- den åbne dialog: { id, kind, fields, promise, owner }
local lastId = 0

local FIELD_TYPES = { input = true, number = true, textarea = true, select = true, checkbox = true }

-- Fejl fra exports vises bedst med niveau 0 (uden en linje, der peger ind i FiveM's egen kode)
local function fail(message)
    error('ap1le_core: ' .. message, 0)
end
local DEFAULT_MAX_LENGTH = { input = 200, textarea = 1000 }

-- Et tal, der kan sendes til NUI-siden: kun almindelige tal (ikke uendelig eller NaN), ellers nil
local function finite(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
    return number
end

function IsDialogOpen()
    return active ~= nil
end

-- Et felt fra scriptet -> rent felt til NUI-siden. Et felt kan også bare være en tekst: 'Navn' = tekstfelt
local function normalizeField(field)
    if type(field) == 'string' then field = { type = 'input', label = field } end
    if type(field) ~= 'table' then return { type = 'input', label = '' } end

    local kind = FIELD_TYPES[field.type] and field.type or 'input'
    local out = {
        type = kind,
        label = CutText(ToText(field.label), 60),
        description = CutText(ToText(field.description), 150),
        placeholder = CutText(ToText(field.placeholder), 80),
        required = field.required == true,
        icon = ToIcon(field.icon),
    }

    if kind == 'number' then
        out.min = finite(field.min)
        out.max = finite(field.max)
        -- min større end max kan aldrig udfyldes - så bytter vi dem om
        if out.min and out.max and out.min > out.max then out.min, out.max = out.max, out.min end
        out.step = finite(field.step)
        out.default = finite(field.default)
    elseif kind == 'checkbox' then
        out.checked = field.checked == true
    elseif kind == 'select' then
        out.options = {}
        for _, option in ipairs(type(field.options) == 'table' and field.options or {}) do
            -- En mulighed kan være en tekst ('Bil') eller { value = 'car', label = 'Bil' }
            local value = type(option) == 'table' and ToText(option.value) or ToText(option)
            local label = type(option) == 'table' and option.label ~= nil and ToText(option.label) or value
            if value ~= '' then out.options[#out.options + 1] = { value = value, label = CutText(label, 60) } end
        end
        out.default = field.default ~= nil and ToText(field.default) or nil
        -- Ingen gyldige muligheder: så kan feltet ikke være påkrævet (ellers kunne dialogen aldrig besvares)
        if #out.options == 0 then out.required = false end
    else -- input og textarea
        local maxLength = math.floor(finite(field.maxLength) or DEFAULT_MAX_LENGTH[kind])
        out.maxLength = math.max(1, math.min(maxLength, 4000))
        out.minLength = math.max(0, math.min(math.floor(finite(field.minLength) or 0), out.maxLength))
        out.default = field.default ~= nil and CutText(ToText(field.default), out.maxLength) or nil
    end
    return out
end

-- Tjekker ét svar fra NUI-siden igen her i Lua (siden kunne være ændret). Ugyldigt = nil
local function readValue(field, value)
    if field.type == 'checkbox' then return value == true end

    if field.type == 'number' then
        local number = finite(value) -- ikke uendelig (fx "1e999") eller NaN
        if not number then return nil end
        if field.min and number < field.min then return nil end
        if field.max and number > field.max then return nil end
        return number
    end

    local text = ToText(value)
    if text == '' then return nil end

    if field.type == 'select' then
        for _, option in ipairs(field.options) do
            if option.value == text then return text end
        end
        return nil
    end

    return CutText(text, field.maxLength)
end

-- Lukker dialogen og giver svaret til den kode, der venter
local function finish(result)
    if not active then return end
    local dialog = active
    active = nil
    SendNUIMessage({ action = 'dialog:hide' })
    ResetUiFocus()
    dialog.promise:resolve(result)
end

-- Åbner en dialog og venter på svaret. message = det, NUI-siden skal vise.
-- owner = det script, der åbnede den. Det skal aflæses FØR der ventes (efter en ventetid ved FiveM ikke
-- længere, hvem der kaldte), så det gør InputDialog og Confirm og giver det med hertil
local function open(kind, message, fields, owner)
    if active then return nil, 'busy' end
    if not AwaitNui() then return nil, 'no-nui' end
    if active then return nil, 'busy' end -- en anden dialog kan være åbnet, mens vi ventede
    if GetOpenMenu() then HideMenu(false) end -- en åben menu lukkes, så de ikke står oven i hinanden

    lastId = lastId + 1
    active = {
        id = lastId,
        kind = kind,
        fields = fields,
        promise = promise.new(),
        owner = owner,
    }
    message.id = lastId

    SetUiFocus()
    SendNUIMessage({ action = 'dialog:' .. kind, dialog = message })
    return Citizen.Await(active.promise)
end

-- titel = overskrift, fields = liste af felter, options = { allowCancel = false, confirmLabel = '...', cancelLabel = '...' }
local function InputDialog(title, fields, options)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    if type(fields) ~= 'table' then fail('InputDialog skal have en liste af felter') end
    options = type(options) == 'table' and options or {}

    local list = {}
    for index, field in ipairs(fields) do list[index] = normalizeField(field) end
    if #list == 0 then fail('InputDialog skal have mindst ét felt') end

    if active then return nil end -- der er allerede en dialog: den skal besvares først
    return open('input', {
        title = CutText(ToText(title), 80),
        fields = list,
        allowCancel = options.allowCancel ~= false,
        confirmLabel = CutText(ToText(options.confirmLabel), 30),
        cancelLabel = CutText(ToText(options.cancelLabel), 30),
    }, list, owner)
end

-- data = { title, content, confirmLabel, cancelLabel, danger = true (rød knap, fx ved sletning) }
local function Confirm(data)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    if type(data) == 'string' then data = { content = data } end
    if type(data) ~= 'table' then fail('Confirm skal have en tekst eller en tabel') end

    if active then return false end
    return open('confirm', {
        title = CutText(ToText(data.title), 80),
        content = CutText(ToText(data.content), 600),
        confirmLabel = CutText(ToText(data.confirmLabel), 30),
        cancelLabel = CutText(ToText(data.cancelLabel), 30),
        danger = data.danger == true,
    }, nil, owner) == true
end

-- Lukker en åben dialog udefra (fx hvis spilleren dør). Den ventende kode får nil (input) eller false (confirm)
local function CloseDialog()
    if not active then return end
    if active.kind == 'confirm' then finish(false) else finish(nil) end
end

exports('InputDialog', InputDialog)
exports('Confirm', Confirm)
exports('CloseDialog', CloseDialog)

-- ---------- Svar fra NUI-siden ----------

-- data = { id, cancelled = true } eller { id, values = { ... } } (input) / { id, confirmed = true/false } (confirm)
RegisterNUICallback('dialog:submit', function(data, cb)
    cb(1)
    -- id'et skal passe: et gammelt svar fra en dialog, der allerede er lukket, må ikke besvare en ny
    if not active or type(data) ~= 'table' or tonumber(data.id) ~= active.id then return end

    if active.kind == 'confirm' then return finish(data.confirmed == true) end
    -- allowCancel = false skjuler kun knappen og Escape. Det er spillerens egen skærm, så det er ikke en
    -- sikkerhedsgrænse - og afviste vi svaret her, ville dialogen hænge
    if data.cancelled == true then return finish(nil) end

    local values = type(data.values) == 'table' and data.values or {}
    local result = {}
    for index, field in ipairs(active.fields) do result[index] = readValue(field, values[index]) end
    finish(result)
end)

-- Stoppes det script, der åbnede dialogen, lukkes den (ellers ville spilleren sidde fast med musen)
AddEventHandler('onClientResourceStop', function(resource)
    if active and active.owner == resource and resource ~= GetCurrentResourceName() then CloseDialog() end
end)
