-- Eksempel-menuen til /testmenu (server/test.lua). Viser alle muligheder i menuer og dialoger,
-- så man kan se dem i spillet - og kopiere fra koden, når man laver sine egne.
-- Her bruges exports - præcis som et andet script ville (med imports.lua skriver man bare Ap1le.RegisterMenu osv.)

local core = exports.ap1le_core

local function testInputDialog()
    -- InputDialog venter, til spilleren har svaret. result er nil, hvis de annullerede
    local result = core:InputDialog('Ny bøde', {
        { type = 'input', label = 'Navn', placeholder = 'Fx Anders Jensen', required = true, minLength = 3, icon = 'user' },
        { type = 'number', label = 'Beløb', description = 'Mellem 100 og 50.000 kr.', min = 100, max = 50000, default = 500, required = true, icon = 'money-bill' },
        { type = 'select', label = 'Grund', required = true, options = {
            { value = 'speed', label = 'For høj fart' },
            { value = 'parking', label = 'Ulovlig parkering' },
            'Andet',
        } },
        { type = 'textarea', label = 'Note', placeholder = 'Valgfri note', maxLength = 300 },
        { type = 'checkbox', label = 'Send kopi til borgeren', checked = true },
    }, { confirmLabel = 'Udsted bøde' })

    if not result then return core:Notify('Du annullerede dialogen.', 'info') end

    -- Svarene står i samme rækkefølge som felterne
    core:Notify({
        title = 'Bøde udstedt',
        description = ('%s: %s kr. (%s)\nKopi: %s'):format(result[1], result[2], result[3], result[5] and 'ja' or 'nej'),
        type = 'success',
    })
end

local function testConfirm()
    local confirmed = core:Confirm({
        title = 'Slet køretøj?',
        content = 'Køretøjet bliver slettet for altid.\nDet kan ikke fortrydes.',
        confirmLabel = 'Slet',
        danger = true,
    })
    core:Notify(confirmed and 'Du bekræftede.' or 'Du annullerede.', confirmed and 'success' or 'warning')
end

RegisterNetEvent('ap1le_core:test:menu', function()
    core:RegisterMenu({
        {
            id = 'ap1le_test',
            title = 'Test-menu',
            onExit = function() core:Notify('Menuen blev lukket.', 'info', 2000) end,
            options = {
                { title = 'Vis en notifikation', description = 'Lukker menuen og viser en succes-besked', icon = 'bell',
                  onSelect = function() core:Notify('Det virker!', 'success') end },
                { title = 'Indtastnings-dialog', description = 'Alle felttyper: tekst, tal, valg, tekstboks og afkrydsning', icon = 'keyboard',
                  onSelect = testInputDialog },
                { title = 'Bekræft-dialog', description = 'En rød "Er du sikker?"-dialog', icon = 'triangle-exclamation',
                  onSelect = testConfirm },
                { title = 'Undermenu', description = 'Åbner en ny menu med en tilbage-knap', icon = 'folder-open',
                  menu = 'ap1le_test_sub' },
                { title = 'Kan ikke vælges', description = 'disabled = true', icon = 'lock', disabled = true },
            },
        },
        {
            id = 'ap1le_test_sub',
            title = 'Undermenu',
            menu = 'ap1le_test', -- forælderen: giver en tilbage-knap (og Backspace)
            options = {
                { title = 'Kun information', description = 'En mulighed uden handling gør ingenting', icon = 'circle-info' },
                { title = 'Med args', description = 'onSelect får args med', icon = 'code',
                  args = { besked = 'Hej fra args' },
                  onSelect = function(args) core:Notify(args.besked, 'success') end },
            },
        },
    })
    core:ShowMenu('ap1le_test')
end)

-- /testprogress: en bjælke med animation og to props (notesblok og blyant), som andre spillere også kan se
RegisterNetEvent('ap1le_core:test:progress', function()
    local ok = core:Progress({
        label = 'Skriver rapport...',
        icon = 'pen',
        duration = 6000,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 49 },
        prop = {
            { model = 'prop_notepad_01', bone = 18905, pos = vec3(0.1, 0.02, 0.05), rot = vec3(10.0, 0.0, 0.0) },
            { model = 'prop_pencil_01', bone = 58866, pos = vec3(0.11, -0.02, 0.001), rot = vec3(-120.0, 0.0, 0.0) },
        },
    })
    core:Notify(ok and 'Rapporten er skrevet.' or 'Du annullerede.', ok and 'success' or 'warning')
end)

-- /testcard: dit eget ID-kort med foto af dig selv og falske oplysninger
RegisterNetEvent('ap1le_core:test:card', function()
    core:ShowCard({
        title = 'Identitetskort',
        subtitle = 'Kongeriget Danmark',
        icon = 'id-card',
        ped = PlayerPedId(),
        fields = {
            { label = 'Navn', value = 'Anders Jensen' },
            { label = 'Fødselsdato', value = '12-03-1994' },
            { label = 'Køn', value = 'Mand' },
            { label = 'Højde', value = '182 cm' },
        },
        tags = { 'B', 'A', 'Våben' },
        tagsLabel = 'Kørekort og licenser',
        duration = 10000,
    })
end)

-- /testtextui: viser "[E] Tryk for at teste" i 10 sekunder, eller til man trykker E
RegisterNetEvent('ap1le_core:test:textui', function()
    core:ShowTextUI('Tryk for at teste', { key = 'E', icon = 'hand-pointer' })
    local stopAt = GetGameTimer() + 10000
    while GetGameTimer() < stopAt do
        if IsControlJustReleased(0, 38) then -- 38 = INPUT_PICKUP (E)
            core:Notify('Du trykkede på E.', 'success')
            break
        end
        Wait(0)
    end
    core:HideTextUI()
end)

-- /testradar: radaren med falske data i 10 sekunder. Farten skifter hver 200 ms (ligesom politiets rigtige radar).
-- Først "Slår op …", efter 2 sek. svarene, og efter 3 sek. låser den, fordi bilen foran er efterlyst
local testRadarRun = 0
RegisterNetEvent('ap1le_core:test:radar', function()
    -- Køres kommandoen igen, mens testen kører, starter den forfra (den gamle tråd stopper sig selv)
    testRadarRun = testRadarRun + 1
    local run = testRadarRun

    CreateThread(function()
        local startedAt = GetGameTimer()
        local stopAt = startedAt + 10000
        while GetGameTimer() < stopAt do
            if run ~= testRadarRun then return end
            local elapsed = GetGameTimer() - startedAt
            local answered = elapsed >= 2000
            local wave = math.sin(elapsed / 1200)

            core:ShowRadar({
                locked = elapsed >= 3000,
                speed = 84 + wave * 3,
                slots = {
                    answered
                        and { label = 'Foran', plate = 'ABC 123', model = 'Sultan', speed = 97 + wave * 4, direction = 'same',
                              status = 'wanted', statusText = 'EFTERLYST', detail = 'Anders Jensen' }
                        or { label = 'Foran', plate = 'ABC 123', model = 'Sultan', speed = 97 + wave * 4, direction = 'same',
                             status = 'checking', statusText = 'Slår op …' },
                    answered
                        and { label = 'Bagved', plate = 'XY 98 765', model = 'Faggio', speed = 62 - wave * 9, direction = 'opposite',
                              status = 'ok', statusText = 'Registreret', detail = 'Mette Hansen' }
                        or { label = 'Bagved', empty = true },
                },
            })
            Wait(200)
        end
        if run == testRadarRun then core:HideRadar() end
    end)
end)
