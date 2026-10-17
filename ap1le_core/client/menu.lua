-- Menuer (kontekstmenuer): en liste af valgmuligheder med ikon, tekst og evt. undermenuer.
-- Samme idé som ox_lib's registerContext/showContext, men i ap1le-designet. Tegnes af html/js/menu.js
--
-- Et script laver en menu sådan (se README.md for alle muligheder):
--   Ap1le.RegisterMenu({
--       id = 'politi_hoved',
--       title = 'Politi',
--       options = {
--           { title = 'Tjek ID', description = 'Se personens ID-kort', icon = 'id-card', onSelect = function() ... end },
--           { title = 'Beslaglæg', icon = 'box', menu = 'politi_beslag' },  -- åbner en undermenu
--       },
--   })
--   Ap1le.ShowMenu('politi_hoved')
--
-- OBS: menuen kopieres, når den registreres. Ændrer scriptet tabellen bagefter, skal den registreres igen.
-- Genstartes ap1le_core, er alle menuer væk, og scripts skal registrere dem igen

local menus = {}         -- alle registrerede menuer: id -> menu (med deres funktioner)
local openMenuId = nil   -- den menu, der er åben lige nu

-- Fejl fra exports vises bedst med niveau 0 (uden en linje, der peger ind i FiveM's egen kode)
local function fail(message)
    error('ap1le_core: ' .. message, 0)
end

-- Gemmer én menu. owner = det script, der lavede den, så den kan ryddes op, hvis scriptet stoppes
local function registerOne(menu, owner)
    if type(menu) ~= 'table' or type(menu.id) ~= 'string' or menu.id == '' then
        fail('en menu skal have et id (tekst), fx id = \'politi_hoved\'')
    end
    if type(menu.options) ~= 'table' then
        fail(('menuen "%s" mangler options = { ... }'):format(menu.id))
    end
    menu.owner = owner
    menus[menu.id] = menu
end

-- Én menu, eller flere på én gang: RegisterMenu({ menu1, menu2 })
local function RegisterMenu(menu)
    if type(menu) ~= 'table' then fail('RegisterMenu skal have en tabel') end
    -- GetInvokingResource = det script, der kaldte exporten (nil, hvis core selv kalder)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    if menu.id ~= nil then
        registerOne(menu, owner)
    else
        for _, item in ipairs(menu) do registerOne(item, owner) end
    end
end

-- Lukker menuen. runOnExit = true, når spilleren selv lukker den (så menuens onExit kaldes)
function HideMenu(runOnExit)
    if not openMenuId then return end
    local menu = menus[openMenuId]
    openMenuId = nil

    SendNUIMessage({ action = 'menu:hide' })
    ResetUiFocus()

    if runOnExit == true and menu and menu.onExit then
        local ok, err = pcall(menu.onExit)
        if not ok then print(('^1[ap1le_core] fejl i onExit for menuen "%s": %s^0'):format(menu.id, err)) end
    end
end

-- Hvad sker der, når en mulighed vælges? 'menu' (undermenu), 'action' (onSelect/event/serverEvent) eller nil
-- (kun information). Bruges BÅDE når menuen tegnes og når den vælges, så de to aldrig kan være uenige
local function getAction(option)
    if type(option.menu) == 'string' and menus[option.menu] then return 'menu' end
    if option.onSelect or type(option.event) == 'string' or type(option.serverEvent) == 'string' then return 'action' end
    return nil
end

-- Laver menuen om til ren tekst til NUI-siden. Funktionerne (onSelect osv.) bliver her i Lua -
-- siden får kun at vide, hvilket nummer der blev valgt
local function toNui(menu)
    local options = {}
    for index, option in ipairs(menu.options) do
        if index > Config.Menu.MaxOptions then break end
        if type(option) == 'table' then
            local action = getAction(option)
            options[#options + 1] = {
                index = index, -- nummeret i menuens egen liste (det, NUI sender tilbage)
                title = CutText(ToText(option.title), 80),
                description = CutText(ToText(option.description), 200),
                icon = ToIcon(option.icon),
                disabled = option.disabled == true,
                readOnly = action == nil, -- kun information: kan ikke klikkes
                arrow = action == 'menu' or option.arrow == true,
            }
        end
    end
    return {
        id = menu.id, -- sendes med tilbage ved hvert valg, så et svar til en anden menu kan afvises
        title = CutText(ToText(menu.title), 60),
        hasParent = type(menu.menu) == 'string' and menus[menu.menu] ~= nil,
        canClose = menu.canClose ~= false,
        options = options,
    }
end

-- Viser en menu, der er lavet med RegisterMenu
local function ShowMenu(id)
    local menu = menus[id]
    if not menu then fail(('menuen "%s" findes ikke (husk RegisterMenu først)'):format(tostring(id))) end
    -- Først vente på siden, SÅ tjekke for en dialog (der kan være åbnet en, mens vi ventede)
    if not AwaitNui() then return false end
    if IsDialogOpen() then return false end -- en dialog er åben: den skal besvares først

    openMenuId = id
    SetUiFocus()
    SendNUIMessage({ action = 'menu:show', menu = toNui(menu) })
    return true
end

-- Global (ikke local), fordi dialog.lua også bruger den: en åben menu lukkes, når en dialog åbnes
function GetOpenMenu()
    return openMenuId
end

exports('RegisterMenu', RegisterMenu)
exports('ShowMenu', ShowMenu)
exports('HideMenu', HideMenu)
exports('GetOpenMenu', GetOpenMenu)

-- ---------- Svar fra NUI-siden ----------

-- Kører en funktion fra et andet script sikkert: er scriptet stoppet, eller er der en fejl i funktionen,
-- skrives det i F8-konsollen i stedet for at ødelægge menuen
local function safeCall(fn, label, ...)
    local ok, err = pcall(fn, ...)
    if not ok then print(('^1[ap1le_core] fejl i %s: %s^0'):format(label, err)) end
end

-- Hører svaret til den menu, der er åben lige nu? (et gammelt klik må ikke ramme en ny menu)
local function isCurrent(data)
    return openMenuId ~= nil and type(data) == 'table' and data.id == openMenuId
end

-- Siden venter på svar efter hvert klik (menu.js). Afviser vi klikket, sender vi menuen igen, så siden
-- aldrig hænger med musen fanget
local function refresh()
    local menu = openMenuId and menus[openMenuId]
    if menu then
        SendNUIMessage({ action = 'menu:show', menu = toNui(menu) })
    else
        HideMenu(false)
    end
end

-- Spilleren valgte en mulighed. data.index = nummeret i menuens liste (fra toNui)
RegisterNUICallback('menu:select', function(data, cb)
    cb(1)
    if not isCurrent(data) then return end
    local menu = menus[openMenuId]
    local index = tonumber(data.index)
    index = index and math.tointeger(index)
    -- Kun de muligheder, der faktisk blev vist (MaxOptions), kan vælges
    local option = menu and index and index <= Config.Menu.MaxOptions and menu.options[index]
    if type(option) ~= 'table' or option.disabled == true then return refresh() end

    local action = getAction(option)
    if not action then return refresh() end -- kun information: gør ingenting

    -- Undermenu: vis den i stedet (menuen bliver åben)
    if action == 'menu' then return ShowMenu(option.menu) end

    -- Luk menuen FØR handlingen, så handlingen fx kan åbne en dialog eller en ny menu
    HideMenu(false)

    local label = ('menuen "%s"'):format(menu.id)
    if option.onSelect then safeCall(option.onSelect, label, option.args) end
    if type(option.event) == 'string' then TriggerEvent(option.event, option.args) end
    -- OBS: serveren skal altid selv tjekke, om spilleren må det her (job, afstand, penge osv.)
    if type(option.serverEvent) == 'string' then TriggerServerEvent(option.serverEvent, option.args) end
end)

-- Tilbage-knappen (eller Backspace): vis forældre-menuen
RegisterNUICallback('menu:back', function(data, cb)
    cb(1)
    if not isCurrent(data) then return end
    local menu = menus[openMenuId]
    if not menu or type(menu.menu) ~= 'string' or not menus[menu.menu] then return refresh() end
    if menu.onBack then safeCall(menu.onBack, ('onBack i menuen "%s"'):format(menu.id)) end
    ShowMenu(menu.menu)
end)

-- Luk-knappen (eller Escape)
RegisterNUICallback('menu:close', function(data, cb)
    cb(1)
    if not isCurrent(data) then return end
    local menu = menus[openMenuId]
    if menu and menu.canClose == false then return refresh() end
    HideMenu(true)
end)

-- Stoppes et script, fjernes dets menuer (deres funktioner virker ikke længere), og er en af dem åben, lukkes den
AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then return end
    if openMenuId and menus[openMenuId] and menus[openMenuId].owner == resource then HideMenu(false) end
    for id, menu in pairs(menus) do
        if menu.owner == resource then menus[id] = nil end
    end
end)
