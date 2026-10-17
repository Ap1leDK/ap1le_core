-- Fælles for NUI-vinduet (html/): "klar"-signalet, indstillingerne til siden og fokus (mus og tastatur).
-- Bruges af notifikationer, menuer og dialoger. Skal indlæses før dem (se fxmanifest.lua)

-- NUI-siden indlæses, lidt efter at scriptet er startet. Indtil den siger "ready", går beskeder tabt.
-- NuiReady = notifikationer må sendes (også efter sikkerhedsnettet på 10 sek.).
-- NuiAnswered = siden har RIGTIGT svaret. Menuer og dialoger venter på den, for de fanger musen - på en
-- side, der ikke virker, ville spilleren sidde fast
NuiReady = false
NuiAnswered = false
local readyHandlers = {}

-- Kører fn, når NUI-siden er klar (med det samme, hvis den allerede er det)
function OnNuiReady(fn)
    if NuiReady then return fn() end
    readyHandlers[#readyHandlers + 1] = fn
end

local function markReady()
    if NuiReady then return end
    NuiReady = true
    local handlers = readyHandlers
    readyHandlers = {}
    for _, fn in ipairs(handlers) do fn() end
end

-- Venter højst 5 sekunder på, at NUI-siden har svaret. Menuer og dialoger bruger den, så de virker, selv hvis
-- et script åbner dem lige efter start. Skal kaldes inde i en tråd (det er alle events, kommandoer og exports)
function AwaitNui()
    local timeout = GetGameTimer() + 5000
    while not NuiAnswered and GetGameTimer() < timeout do Wait(50) end
    return NuiAnswered
end

-- NUI-siden spørger, når den er klar, om indstillingerne fra config.lua
-- En del af config.lua, eller en tom tabel, hvis den mangler. En gammel config.lua (fra før et modul fandtes)
-- må aldrig få dette svar til at fejle: så ville siden aldrig blive klar, og ingen menuer eller dialoger virke.
-- Det, der mangler, bliver nil, og siden bruger så sin egen standard (css- og js-filerne)
local function section(name)
    return type(Config[name]) == 'table' and Config[name] or {}
end

RegisterNUICallback('ready', function(_, cb)
    local notify, menu, dialog = section('Notify'), section('Menu'), section('Dialog')
    local colors = {}
    for kind, info in pairs(type(notify.Types) == 'table' and notify.Types or {}) do
        if type(info) == 'table' then colors[kind] = info.color end
    end

    cb({
        brandColor = Config.BrandColor,
        scale = Config.Scale,
        notify = {
            position = notify.Position,
            maxVisible = notify.MaxVisible,
            colors = colors,
        },
        menu = { position = menu.Position },
        dialog = { confirmLabel = dialog.ConfirmLabel, cancelLabel = dialog.CancelLabel },
        textui = { position = section('TextUI').Position },
        card = { position = section('Card').Position or 'right' },
        radar = { position = section('Radar').Position or 'bottom-center' },
    })

    NuiAnswered = true
    markReady()
end)

-- Sikkerhedsnet: svarer siden aldrig (fx en fejl i html-filerne), regnes den for klar efter 10 sekunder,
-- så notifikationer i køen ikke bliver hængende for evigt
SetTimeout(10000, markReady)

-- ---------- Fokus ----------
-- Når en menu eller dialog er åben, skal musen og tastaturet gå til NUI-siden i stedet for til spillet

local hasFocus = false
local savedKeepInput = false

function SetUiFocus()
    -- Kun første gang: skifter man fra en menu til en undermenu, har vi allerede fokus, og så ville vi
    -- ellers gemme vores EGEN indstilling som den "oprindelige"
    if not hasFocus then savedKeepInput = IsNuiFocusKeepingInput() end
    hasFocus = true
    SetNuiFocus(true, true)     -- tastatur og mus til siden
    SetNuiFocusKeepInput(false) -- spillet får ingen taster imens (man kan ikke gå eller skyde)
end

-- Tid, hvor pausemenuen er blokeret efter lukning (se ResetUiFocus)
local blockPauseUntil = 0

function ResetUiFocus()
    if not hasFocus then return end
    hasFocus = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(savedKeepInput)

    -- Lukkede spilleren med Escape, holder de måske stadig tasten nede, når spillet får tastaturet igen.
    -- Så ville GTA's pausemenu åbne. Derfor blokeres pausemenuen (Escape og P) et halvt sekund.
    -- DisableControlAction skal kaldes hver frame, så det er en kort tråd, der stopper af sig selv
    local alreadyRunning = GetGameTimer() < blockPauseUntil
    blockPauseUntil = GetGameTimer() + 500
    if alreadyRunning then return end
    CreateThread(function()
        while GetGameTimer() < blockPauseUntil do
            DisableControlAction(0, 199, true) -- INPUT_FRONTEND_PAUSE (P)
            DisableControlAction(0, 200, true) -- INPUT_FRONTEND_PAUSE_ALTERNATE (Escape)
            Wait(0)
        end
    end)
end

-- Stoppes core (fx "ensure ap1le_core"), må spilleren aldrig sidde fast med musen fanget af siden
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
