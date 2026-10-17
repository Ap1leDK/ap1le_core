-- Hænder op: spilleren trykker X (Config.HandsUp.Key) og løfter hænderne. Tryk igen for at tage dem ned.
-- Andre scripts kan spørge Ap1le.IsHandsUp() på klienten. Serveren (fx politiet, der vil visitere) kan læse
-- Player(id).state.ap1le_handsup.
--
-- OBS: state bag'en sættes af spillerens EGEN klient, så den er kun spillerens påstand. Det er fint til
-- "må politiet visitere mig" (en snyder kan kun gøre sig selv nemmere at visitere), men brug den ikke til
-- noget, der giver spilleren en fordel

local COMMAND = 'ap1le_handsup'
local STATE_KEY = 'ap1le_handsup'

-- Indstillingerne. Mangler Config.HandsUp (en gammel config.lua), bruges standarden i stedet for at fejle
local cfg = type(Config.HandsUp) == 'table' and Config.HandsUp or { Enabled = true, Key = 'X' }

-- Animationen (findes i spillet: missminuteman_1ig_2 har handsup_enter, handsup_base og handsup_exit).
-- 49 = 1 (gentag) + 16 (kun overkroppen) + 32 (man kan stadig gå)
local ANIM_DICT = 'missminuteman_1ig_2'
local ANIM_CLIP = 'handsup_base'
local ANIM_FLAG = 49

-- Mindst så lang tid mellem to tryk (millisekunder), så en spiller ikke kan spamme state bag'en over netværket
local TOGGLE_COOLDOWN = 500

-- Blev annuller-tasten (også X) trykket for så kort tid siden, tæller trykket ikke som "hænder op". Ellers kunne
-- det samme tryk både annullere en bjælke og løfte hænderne (de to kommandoer kører i vilkårlig rækkefølge)
local CANCEL_GRACE = 300

-- Animationen er ikke startet i samme frame, som TaskPlayAnim kaldes. Først efter denne tid tæller det som
-- "afbrudt", hvis den ikke kører
local ANIM_GRACE = 600

-- Taster, der er spærret, mens hænderne er oppe (kun imens - de skal kaldes hver frame).
-- Numrene står på docs.fivem.net/docs/game-references/controls
local CONTROLS = {
    24, 25, 257,               -- ATTACK, AIM, ATTACK2
    140, 141, 142, 143,        -- MELEE_ATTACK_LIGHT, MELEE_ATTACK_HEAVY, MELEE_ATTACK_ALTERNATE, MELEE_BLOCK
    263, 264,                  -- MELEE_ATTACK1, MELEE_ATTACK2
    45, 47, 58,                -- RELOAD, DETONATE, THROW_GRENADE
    37, 12, 13, 14, 15,        -- SELECT_WEAPON (våbenhjulet), WEAPON_WHEEL_UD/LR/NEXT/PREV
    16, 17, 261, 262,          -- SELECT_NEXT/PREV_WEAPON, PREV/NEXT_WEAPON
    157, 158, 159, 160, 161,   -- SELECT_WEAPON_UNARMED/MELEE/HANDGUN/SHOTGUN/SMG
    162, 163, 164, 165,        -- SELECT_WEAPON_AUTO_RIFLE/SNIPER/HEAVY/SPECIAL
    22, 44,                    -- JUMP, COVER (begge ville afbryde animationen)
}

local handsUp = false
local generation = 0 -- tælles op, hver gang hænderne kommer op, så der aldrig kører to watch-tråde
local lastToggle = 0

-- I håndjern via politiets state bag? ('soft'/'hard', sat af serveren - nil = ikke i håndjern).
-- Læses ikke hver frame: hver læsning henter hele værdien fra spillet
local function cuffedByState()
    return LocalPlayer.state.ap1le_cuffed and true or false
end

-- Er der noget, der gør, at hænderne ikke kan være oppe? (bruges både før de kommer op og hver frame)
local function blocked(ped)
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedCuffed(ped) then return true end
    if not IsPedOnFoot(ped) or IsPedInAnyVehicle(ped, true) or IsPedGettingIntoAVehicle(ped) then return true end
    return IsPedSwimming(ped) or IsPedFalling(ped)
end

-- Indlæser animationen. Giver false, hvis den ikke findes eller ikke blev indlæst inden for 5 sekunder
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

local function setState(value)
    -- true = sendes til serveren, så politiet kan se det
    LocalPlayer.state:set(STATE_KEY, value, true)
end

-- Tager hænderne ned. StopAnimTask stopper kun netop denne animation, så det er ufarligt at kalde, også
-- hvis noget andet (fx håndjern) allerede har taget over
local function lower()
    if not handsUp then return end
    handsUp = false
    setState(false)
    StopAnimTask(PlayerPedId(), ANIM_DICT, ANIM_CLIP, 2.0)
end

-- Kører hver frame, KUN mens hænderne er oppe: spærrer taster og tager hænderne ned, hvis noget sker
local function watch(myGeneration)
    local startedAt = GetGameTimer()
    local nextStateCheck = 0
    while handsUp and generation == myGeneration do
        local ped = PlayerPedId()
        if blocked(ped) then break end
        local now = GetGameTimer()
        if now >= nextStateCheck then
            if cuffedByState() then break end
            nextStateCheck = now + 250
        end
        -- Animationen er stoppet af noget andet (fx en anden animation eller ClearPedTasks): så er hænderne
        -- heller ikke oppe længere, og state bag'en må ikke sige det
        if now - startedAt > ANIM_GRACE and not IsEntityPlayingAnim(ped, ANIM_DICT, ANIM_CLIP, 3) then break end

        for i = 1, #CONTROLS do DisableControlAction(0, CONTROLS[i], true) end
        DisablePlayerFiring(PlayerId(), true)
        Wait(0)
    end
    if generation == myGeneration then lower() end
end

local function raise()
    -- X er også progress-bjælkens annuller-tast: mens en bjælke kører, gør vi ingenting
    if IsProgressActive() then return end
    if blocked(PlayerPedId()) or cuffedByState() then return end
    if not loadAnimDict(ANIM_DICT) then
        return print(('^3[ap1le_core] Hænder op: animationen "%s" kunne ikke indlæses^0'):format(ANIM_DICT))
    end

    -- Indlæsningen kan tage et par frames: tjek igen
    local ped = PlayerPedId()
    if handsUp or IsProgressActive() or blocked(ped) or cuffedByState() then return RemoveAnimDict(ANIM_DICT) end

    TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 4.0, 2.0, -1, ANIM_FLAG, 0.0, false, false, false)
    RemoveAnimDict(ANIM_DICT) -- animationen kører videre; vi siger bare, at vi ikke selv skal bruge den mere

    handsUp = true
    generation = generation + 1
    local myGeneration = generation
    setState(true)
    CreateThread(function() watch(myGeneration) end)
end

-- Andre scripts: exports.ap1le_core:IsHandsUp() (eller Ap1le.IsHandsUp via imports.lua)
local function IsHandsUp()
    return handsUp
end

exports('IsHandsUp', IsHandsUp)

-- Blev core genstartet, mens hænderne var oppe, står state bag'en måske stadig på true
if LocalPlayer.state[STATE_KEY] then setState(false) end

-- Stoppes core: hænderne ned og state bag'en tilbage (her må der ikke ventes)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not handsUp then return end
    handsUp = false
    setState(false)
    StopAnimTask(PlayerPedId(), ANIM_DICT, ANIM_CLIP, 2.0)
end)

if cfg.Enabled == false then return end

-- ---------- Tasten ----------
-- Spilleren kan ændre tasten i GTA: Indstillinger > Tastetildelinger > FiveM. OBS: tasten i config.lua er kun
-- standarden FØRSTE gang, en spiller kommer på serveren - FiveM husker derefter spillerens eget valg
RegisterCommand(COMMAND, function()
    -- Mens en bjælke kører (eller lige er annulleret), er X "annuller" - så tæller trykket slet ikke
    local now = GetGameTimer()
    if IsProgressActive() or now - ProgressCancelPressedAt < CANCEL_GRACE then return end
    if now - lastToggle < TOGGLE_COOLDOWN then return end
    lastToggle = now

    if handsUp then lower() else raise() end
end, false)
RegisterKeyMapping(COMMAND, 'Hænder op (ap1le)', 'keyboard', type(cfg.Key) == 'string' and cfg.Key or 'X')
