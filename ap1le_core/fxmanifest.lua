fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ap1le_core'
description 'Fundamentet under alle ap1le-scripts: fælles design og funktioner (notifikationer, menuer, dialoger, progress-bjælke, hjælpetekst, ID-kort, radar, plads til et speedometer, hænder op)'
version '1.6.0'

-- Filerne står i en fast rækkefølge: config og de fælles hjælpere skal indlæses før modulerne, der bruger dem
shared_scripts {
    'config.lua',
    'shared/text.lua',
    'shared/notify.lua',
    'shared/progress.lua',
}

client_scripts {
    'client/nui.lua', -- "klar"-signal og fokus, som de andre moduler bruger
    'client/notify.lua',
    'client/menu.lua',
    'client/dialog.lua',
    'client/progress.lua',
    'client/textui.lua',
    'client/card.lua',
    'client/radar.lua',
    'client/hud.lua', -- speedometeret fra et andet script (SetSpeedo), som radaren lægger sig om
    'client/handsup.lua', -- efter progress.lua: bruger IsProgressActive (X er også annuller-tasten)
    'client/test.lua',
}

server_scripts {
    '@ox_lib/init.lua', -- kun på serveren: bruges til test-kommandoerne (lib.addCommand)
    'server/notify.lua',
    'server/progress.lua',
    'server/test.lua',
}

-- Det gennemsigtige web-vindue, der tegner notifikationer, menuer og dialoger oven på spillet
ui_page 'html/index.html'

-- Kun vores egen side (ui_page) må sende svar til vores NUI-callbacks (menu:select, dialog:submit osv.).
-- Uden den kunne et andet scripts web-side sende falske svar
nui_callback_strict_mode 'true'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    -- Ikonerne (Font Awesome Free 6.7.2, samme som hjemmesiden). Kun .woff2 - det er dem, browseren bruger
    'html/vendor/fontawesome/css/all.min.css',
    'html/vendor/fontawesome/webfonts/*.woff2',
    -- Andre scripts indlæser denne fil med shared_script '@ap1le_core/imports.lua' (se README.md)
    'imports.lua',
}

dependencies {
    'ox_lib',
}
