-- Progress-bjælke: "Visiterer...", "Bryder op..." osv. med en evt. animation og en ting i hånden (prop).
--   local ok = Ap1le.Progress({ label = 'Visiterer...', duration = 5000, canCancel = true })
--   ok = true: bjælken blev færdig. false: annulleret, afbrudt (fx død) eller en anden bjælke kørte allerede
-- Den VENTER, til bjælken er færdig, så den skal kaldes inde i en tråd (events, kommandoer, onSelect i menuer,
-- CreateThread). Tiden styres her i Lua - NUI-siden (html/js/progress.js) viser den bare.
--
-- VIGTIGT: bjælken er kun for spillerens øjne. Giver serveren noget bagefter (fx en visitering), skal
-- serveren selv tjekke, at der er gået lang nok tid, og at spilleren stadig er tæt på

local active = nil -- bjælken, der kører: { id, owner, canCancel, cancelled, anim }
local lastId = 0

-- Kommandoen bag annuller-tasten. RegisterKeyMapping (nederst) gør, at spilleren selv kan ændre tasten
local CANCEL_COMMAND = 'ap1le_cancelprogress'

-- Navnet på state bag'en med props (sættes af server/progress.lua)
local PROPS_KEY = 'ap1le_progressProps'

-- Fejl fra exports vises bedst med niveau 0 (uden en linje, der peger ind i FiveM's egen kode)
local function fail(message)
    error('ap1le_core: ' .. message, 0)
end

-- Taster, der kan spærres imens (disable = { move = true, ... }).
-- Numrene står på docs.fivem.net/docs/game-references/controls
local CONTROLS = {
    mouse = { 1, 2, 106 },             -- INPUT_LOOK_LR, INPUT_LOOK_UD, INPUT_VEH_MOUSE_CONTROL_OVERRIDE
    move = { 21, 22, 30, 31, 36, 44 }, -- SPRINT, JUMP, MOVE_LR, MOVE_UD, DUCK, COVER
    sprint = { 21 },                   -- SPRINT
    car = { 63, 64, 71, 72, 75 },      -- VEH_MOVE_LEFT_ONLY, VEH_MOVE_RIGHT_ONLY, VEH_ACCELERATE, VEH_BRAKE, VEH_EXIT
    -- ATTACK, AIM, SELECT_WEAPON, DETONATE, VEH_ATTACK, VEH_ATTACK2, THROW_GRENADE, VEH_PASSENGER_ATTACK,
    -- MELEE_ATTACK_LIGHT, MELEE_ATTACK_HEAVY, MELEE_ATTACK_ALTERNATE, MELEE_BLOCK, ATTACK2, MELEE_ATTACK1, MELEE_ATTACK2
    combat = { 24, 25, 37, 47, 69, 70, 58, 92, 140, 141, 142, 143, 257, 263, 264 },
}

-- Et almindeligt tal (ikke uendelig eller NaN), ellers nil
local function finite(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
    return number
end

-- Et punkt { x, y, z } fra en vector3 eller en tabel. Sendes til serveren, så det skal være rene tal
local function toVector(value)
    if type(value) ~= 'table' and type(value) ~= 'vector3' then return { x = 0.0, y = 0.0, z = 0.0 } end
    return { x = finite(value.x) or 0.0, y = finite(value.y) or 0.0, z = finite(value.z) or 0.0 }
end

-- Én prop: { model = 'prop_notepad_01', bone = 18905, pos = vec3(...), rot = vec3(...) }.
-- Manglende knogle/pos/rot får en standard, og resten tjekkes af CleanProgressProp (shared/progress.lua),
-- så scriptet får en advarsel med det samme i stedet for en prop, der stille og roligt ikke dukker op
local function normalizeProp(prop)
    if type(prop) ~= 'table' then return nil end
    local clean = CleanProgressProp({
        model = prop.model,
        bone = math.tointeger(finite(prop.bone)) or 60309, -- 60309 = venstre hånd (samme standard som ox_lib)
        pos = toVector(prop.pos),
        rot = toVector(prop.rot),
    })
    if not clean then
        print(('^3[ap1le_core] Progress: prop "%s" er ugyldig og bliver ikke vist (model, eller pos over 5 meter)^0')
            :format(tostring(prop.model)))
    end
    return clean
end

-- Scriptets tabel -> en ren tabel, vi kan stole på i resten af filen
local function normalize(data)
    if type(data) ~= 'table' then
        fail('Progress skal have en tabel, fx { label = \'Visiterer...\', duration = 5000 }')
    end
    local duration = finite(data.duration)
    if not duration then fail('Progress skal have duration = millisekunder, fx duration = 5000') end

    local progress = {
        label = CutText(ToText(data.label), 60),
        icon = ToIcon(data.icon),
        duration = math.floor(math.max(Config.Progress.MinDuration, math.min(duration, Config.Progress.MaxDuration))),
        canCancel = data.canCancel ~= false, -- standard: man kan annullere
        useWhileDead = data.useWhileDead == true,
        allowRagdoll = data.allowRagdoll == true,
        allowCuffed = data.allowCuffed == true,
        allowFalling = data.allowFalling == true,
        allowSwimming = data.allowSwimming == true,
        disable = {},
    }

    if type(data.disable) == 'table' then
        for kind in pairs(CONTROLS) do progress.disable[kind] = data.disable[kind] == true end
    end

    local anim = data.anim
    if type(anim) == 'table' then
        if type(anim.scenario) == 'string' and anim.scenario ~= '' then
            progress.anim = { scenario = anim.scenario, playEnter = anim.playEnter ~= false }
        elseif type(anim.dict) == 'string' and type(anim.clip) == 'string' then
            progress.anim = {
                dict = anim.dict,
                clip = anim.clip,
                flag = math.tointeger(finite(anim.flag)) or 49, -- 49 = gentag + kun overkroppen + man kan gå
                blendIn = finite(anim.blendIn) or 3.0,
                blendOut = finite(anim.blendOut) or 1.0,
                duration = math.tointeger(finite(anim.duration)) or -1,
                playbackRate = finite(anim.playbackRate) or 0.0,
                lockX = anim.lockX == true,
                lockY = anim.lockY == true,
                lockZ = anim.lockZ == true,
            }
        end
    end

    -- prop kan være én prop eller en liste af dem
    local props = {}
    if type(data.prop) == 'table' then
        -- Én prop har nøgler som model/bone/pos; en liste har kun 1, 2, ... (en prop uden model giver en advarsel)
        local list = data.prop[1] == nil and { data.prop } or data.prop
        for _, prop in ipairs(list) do
            if #props >= Config.Progress.MaxProps then break end
            props[#props + 1] = normalizeProp(prop)
        end
    end
    progress.props = #props > 0 and props or nil

    return progress
end

-- Skal bjælken stoppes? (død, ragdoll, håndjern osv. - medmindre scriptet har tilladt det)
local function interrupted(progress, ped)
    if not progress.useWhileDead and IsEntityDead(ped) then return true end
    if not progress.allowRagdoll and IsPedRagdoll(ped) then return true end
    if not progress.allowCuffed and IsPedCuffed(ped) then return true end
    if not progress.allowFalling and IsPedFalling(ped) then return true end
    if not progress.allowSwimming and IsPedSwimming(ped) then return true end
    return false
end

-- Indlæser en animation. Giver false, hvis den ikke findes eller ikke blev indlæst inden for 5 sekunder
local function loadAnimDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return true
end

-- Den tast, spilleren har valgt til at annullere (fx "X"). GetControlInstructionalButton giver "t_X" for en
-- almindelig tast. Andre (fx en museknap) giver noget andet - så bruges tasten fra config.lua
local function cancelKeyLabel()
    local button = GetControlInstructionalButton(0, joaat(CANCEL_COMMAND) | 0x80000000, true)
    if type(button) == 'string' and button:sub(1, 2) == 't_' and #button > 2 then return button:sub(3) end
    return Config.Progress.CancelKey
end

-- ox_inventory åbner ikke inventaret, mens invBusy er true (man kan ikke visitere og flytte ting samtidig).
-- Var den allerede true (sat af et andet script), rører vi den slet ikke - ellers kunne vi sætte den
-- tilbage til en gammel værdi, efter det andet script har ændret den
local setInvBusyOurselves = false

local function setInvBusy(busy)
    if busy then
        setInvBusyOurselves = LocalPlayer.state.invBusy ~= true
        if setInvBusyOurselves then LocalPlayer.state.invBusy = true end
    elseif setInvBusyOurselves then
        setInvBusyOurselves = false
        LocalPlayer.state.invBusy = false
    end
end

-- Et åbent inventar lukkes, når bjælken starter (invBusy stopper kun, at det ÅBNES)
local function closeInventory()
    if GetResourceState('ox_inventory') ~= 'started' then return end
    pcall(function() exports.ox_inventory:closeInventory() end)
end

local function startAnim(ped, anim)
    if anim.scenario then
        TaskStartScenarioInPlace(ped, anim.scenario, 0, anim.playEnter)
    elseif anim.loaded then
        TaskPlayAnim(ped, anim.dict, anim.clip, anim.blendIn, anim.blendOut, anim.duration, anim.flag,
            anim.playbackRate, anim.lockX, anim.lockY, anim.lockZ)
        RemoveAnimDict(anim.dict) -- animationen kører videre; vi siger bare, at vi ikke selv skal bruge den mere
    end
end

local function stopAnim(ped, anim)
    if anim.scenario then
        ClearPedTasks(ped)
    elseif anim.loaded then
        StopAnimTask(ped, anim.dict, anim.clip, 1.0)
        -- Uden en frame her kan stoppet blive "slugt", hvis scriptet starter en ny animation lige bagefter
        -- (samme fund som i ox_lib)
        Wait(0)
    end
end

local function Progress(data)
    -- Hvem kaldte? Skal aflæses FØR der ventes (bagefter ved FiveM det ikke længere)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    local progress = normalize(data)
    if active then return false end -- der kører allerede en bjælke

    if interrupted(progress, PlayerPedId()) then return false end

    lastId = lastId + 1
    local current = { id = lastId, owner = owner, canCancel = progress.canCancel, cancelled = false, anim = progress.anim }
    active = current
    setInvBusy(true)
    closeInventory()

    -- Vent på det, der kan tage tid, FØR bjælken vises og tiden starter - ellers ville bjælken på skærmen nå
    -- 100 %, mens Lua stadig venter. NUI-siden (kun lige efter start) og animationen (første gang den bruges)
    AwaitNui()
    if progress.anim and progress.anim.dict then
        progress.anim.loaded = loadAnimDict(progress.anim.dict)
        if not progress.anim.loaded then
            print(('^3[ap1le_core] Progress: animationen "%s" findes ikke eller kunne ikke indlæses^0'):format(progress.anim.dict))
        end
    end

    -- Blev den annulleret eller afbrudt, mens vi ventede?
    if active ~= current or current.cancelled or interrupted(progress, PlayerPedId()) then
        if progress.anim and progress.anim.loaded then RemoveAnimDict(progress.anim.dict) end
        setInvBusy(false)
        if active == current then active = nil end
        return false
    end

    local ped = PlayerPedId()
    if NuiReady then
        SendNUIMessage({
            action = 'progress:show',
            progress = {
                id = current.id,
                label = progress.label,
                icon = progress.icon,
                duration = progress.duration,
                cancelKey = progress.canCancel and cancelKeyLabel() or nil,
                cancelText = Config.Progress.CancelText,
            },
        })
    end

    if progress.anim then startAnim(ped, progress.anim) end
    if progress.props then TriggerServerEvent('ap1le_core:progressProps', progress.props) end

    local disable = progress.disable
    local endTime = GetGameTimer() + progress.duration
    local completed = false

    while active == current and not current.cancelled do
        if GetGameTimer() >= endTime then
            completed = true
            break
        end

        ped = PlayerPedId()
        if interrupted(progress, ped) then break end

        for kind, controls in pairs(CONTROLS) do
            if disable[kind] then
                for i = 1, #controls do DisableControlAction(0, controls[i], true) end
            end
        end
        if disable.combat then DisablePlayerFiring(PlayerId(), true) end

        Wait(0)
    end

    -- Ryd op: props, animation og "optaget"
    if progress.props then TriggerServerEvent('ap1le_core:progressProps', nil) end
    if progress.anim then stopAnim(PlayerPedId(), progress.anim) end
    setInvBusy(false)

    if active == current then active = nil end
    if NuiReady then
        SendNUIMessage({
            action = 'progress:hide',
            id = current.id,
            cancelled = not completed,
            cancelledText = Config.Progress.CancelledText,
        })
    end
    return completed
end

-- Stopper bjælken fra koden (fx hvis spilleren bliver lagt i håndjern). Den ventende kode får false
local function CancelProgress()
    if active then active.cancelled = true end
end

-- Global (ikke local), fordi handsup.lua også bruger den: X er både "annuller" og "hænder op"
function IsProgressActive()
    return active ~= nil
end

exports('Progress', Progress)
exports('CancelProgress', CancelProgress)
exports('IsProgressActive', IsProgressActive)

-- ---------- Annuller-tasten ----------
-- Spilleren kan ændre tasten i GTA: Indstillinger > Tastetildelinger > FiveM. OBS: tasten i config.lua er kun
-- standarden FØRSTE gang, en spiller kommer på serveren - FiveM husker derefter spillerens eget valg
-- Hvornår annuller-tasten sidst blev trykket, mens en bjælke kørte. Global, fordi handsup.lua bruger den:
-- X er også "hænder op", og samme tryk må ikke både annullere bjælken og løfte hænderne
ProgressCancelPressedAt = 0

RegisterCommand(CANCEL_COMMAND, function()
    if active then ProgressCancelPressedAt = GetGameTimer() end
    if active and active.canCancel then active.cancelled = true end
end, false)
RegisterKeyMapping(CANCEL_COMMAND, 'Annuller handling (ap1le)', 'keyboard', Config.Progress.CancelKey)

-- ---------- Props ----------
-- Serveren sætter listen af props i spillerens state bag (server/progress.lua). ALLE klienter, der kan se
-- spilleren, laver dem her på hans ped - så alle ser fx notesblokken i hånden.
-- Hver klient laver sine egne (ikke-netværks) objekter, så der ikke skal sendes entities over netværket

local createdProps = {} -- serverId -> liste af objekter
local propVersion = {}  -- serverId -> tæller, så et gammelt "lav props" ikke vinder over et nyere "fjern dem"

local function deleteProps(serverId)
    local props = createdProps[serverId]
    createdProps[serverId] = nil
    if not props then return end
    for _, object in ipairs(props) do
        if DoesEntityExist(object) then DeleteEntity(object) end
    end
end

-- Indlæser en model. Giver hashen, eller nil hvis den ikke findes eller ikke blev indlæst inden for 5 sekunder
local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(0)
    end
    return hash
end

-- prop er allerede tjekket med CleanProgressProp. Giver objektet, eller nil
local function createProp(ped, prop)
    local hash = loadModel(prop.model)
    if not hash then return nil end
    local coords = GetEntityCoords(ped)
    -- false, false, false = kun på denne klient, ikke et script-host-objekt, ingen dør
    local object = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if object == 0 then return nil end
    -- Parametrene efter rot: p9 (true), useSoftPinning, collision, isPed, rotationOrder (0), syncRot
    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, prop.bone), prop.pos.x, prop.pos.y, prop.pos.z,
        prop.rot.x, prop.rot.y, prop.rot.z, true, true, false, true, 0, true)
    return object
end

AddStateBagChangeHandler(PROPS_KEY, nil, function(bagName, _, value)
    local player = GetPlayerFromStateBagName(bagName)
    if player == 0 then return end -- spilleren er ikke i nærheden af os
    local serverId = GetPlayerServerId(player)

    local version = (propVersion[serverId] or 0) + 1
    propVersion[serverId] = version
    deleteProps(serverId)
    if type(value) ~= 'table' then return end

    -- Tjek props IGEN her: en snydeklient kan skrive direkte i sin state bag uden om serverens tjek
    local props = {}
    for i, prop in ipairs(value) do
        if i > Config.Progress.MaxProps then break end
        props[#props + 1] = CleanProgressProp(prop)
    end
    if #props == 0 then return end

    -- I en ny tråd: modellerne skal indlæses, og det tager tid
    CreateThread(function()
        local isCurrent = function() return propVersion[serverId] == version end

        -- Kommer spilleren lige ind i vores nærhed, kan hans ped mangle et øjeblik (den sendes for sig selv)
        local timeout = GetGameTimer() + 5000
        while not DoesEntityExist(GetPlayerPed(player)) do
            if not isCurrent() or GetGameTimer() > timeout then return end
            Wait(100)
        end

        local objects = {}
        for _, prop in ipairs(props) do
            -- pcall: en fejl i én prop må ikke efterlade de andre uden oprydning
            local ok, object = pcall(createProp, GetPlayerPed(player), prop)
            if ok and object then objects[#objects + 1] = object end
        end

        -- Er de blevet fjernet (eller skiftet ud), mens vi indlæste? Så skal de nye ikke blive stående
        if not isCurrent() then
            for _, object in ipairs(objects) do DeleteEntity(object) end
            return
        end
        deleteProps(serverId) -- en sikkerhed: aldrig to sæt props på samme spiller
        createdProps[serverId] = objects
    end)
end)

-- En spiller logger af eller går ud af vores nærhed (FiveM sender det i begge tilfælde): fjern hans props.
-- Tælleren tælles OP (ikke nulstilles), så en tråd, der stadig indlæser, kan se, at den er forældet
RegisterNetEvent('onPlayerDropped', function(serverId)
    deleteProps(serverId)
    propVersion[serverId] = (propVersion[serverId] or 0) + 1
end)

-- Stoppes et script midt i en bjælke, stoppes bjælken (tråden ryder selv op)
AddEventHandler('onClientResourceStop', function(resource)
    if active and active.owner == resource and resource ~= GetCurrentResourceName() then active.cancelled = true end
end)

-- Stoppes core: fjern alle props og animationen, så intet bliver hængende
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for serverId in pairs(createdProps) do deleteProps(serverId) end
    if active then
        -- Uden stopAnim's Wait: her må der ikke ventes, scriptet er ved at stoppe
        local anim = active.anim
        if anim and anim.scenario then
            ClearPedTasks(PlayerPedId())
        elseif anim and anim.loaded then
            StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 1.0)
        end
        setInvBusy(false)
    end
end)
