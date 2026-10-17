-- Test-kommandoer, så man kan se, hvordan core ser ud og virker i spillet.
-- Kun for admins: 'group.admin' er en "ace"-tilladelse, som ESX giver spillere med admin-gruppen.
-- Notify er exporten fra server/notify.lua - her kalder vi den via exports, ligesom andre scripts ville

-- /testnotify: én notifikation af hver type
lib.addCommand('testnotify', {
    help = 'Vis en test-notifikation af hver type (ap1le_core)',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return print('[ap1le_core] /testnotify skal køres inde fra spillet') end

    local core = exports.ap1le_core
    core:Notify(source, { title = 'Betaling gennemført', description = 'Du har betalt 2.500 kr. for reparationen.', type = 'success' })
    SetTimeout(600, function()
        core:Notify(source, { title = 'Ikke nok penge', description = 'Du mangler 750 kr. på din bankkonto.', type = 'error' })
    end)
    SetTimeout(1200, function()
        core:Notify(source, { title = 'Politiet er på vej', description = 'Nogen har ringet 112 om et indbrud i nærheden.', type = 'warning' })
    end)
    SetTimeout(1800, function()
        core:Notify(source, 'Tryk på E for at åbne menuen.', 'info')
    end)
end)

-- /testmenu: en eksempel-menu med undermenu og dialoger (selve menuen laves på klienten, client/test.lua)
lib.addCommand('testmenu', {
    help = 'Vis en test-menu med dialoger (ap1le_core)',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return print('[ap1le_core] /testmenu skal køres inde fra spillet') end
    TriggerClientEvent('ap1le_core:test:menu', source)
end)

-- /testprogress: en progress-bjælke med animation og props (client/test.lua)
lib.addCommand('testprogress', {
    help = 'Vis en test-progress-bjælke (ap1le_core)',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return print('[ap1le_core] /testprogress skal køres inde fra spillet') end
    TriggerClientEvent('ap1le_core:test:progress', source)
end)

-- /testcard: dit eget ID-kort med foto og falske oplysninger (client/test.lua)
lib.addCommand('testcard', {
    help = 'Vis et test-ID-kort med dit eget foto (ap1le_core)',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return print('[ap1le_core] /testcard skal køres inde fra spillet') end
    TriggerClientEvent('ap1le_core:test:card', source)
end)

-- /testtextui: hjælpeteksten "[E] ..." (client/test.lua)
lib.addCommand('testtextui', {
    help = 'Vis en test-hjælpetekst (ap1le_core)',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return print('[ap1le_core] /testtextui skal køres inde fra spillet') end
    TriggerClientEvent('ap1le_core:test:textui', source)
end)

-- /testradar: politiets radar med falske data i 10 sekunder (client/test.lua)
lib.addCommand('testradar', {
    help = 'Vis en test-radar i 10 sekunder (ap1le_core)',
    restricted = 'group.admin',
}, function(source)
    if source == 0 then return print('[ap1le_core] /testradar skal køres inde fra spillet') end
    TriggerClientEvent('ap1le_core:test:radar', source)
end)
