# ap1le_core

Fundamentet under alle ap1le-scripts. Her ligger det, der skal være ens overalt (design og fælles funktioner),
så de andre scripts (politi, læge osv.) ikke skal lave det selv.

Moduler: **notifikationer**, **menuer**, **dialoger**, **progress-bjælke**, **hjælpetekst**, **ID-kort**, **radar**,
**plads til et speedometer** og **hænder op**.

## Installation

Mappen ligger i `resources/[ap1le]/`, som allerede startes af `ensure [ap1le]` i `server.cfg`.
Første gang: skriv `refresh` og derefter `ensure ap1le_core` i server-konsollen (eller genstart serveren).

Kræver `ox_lib` (bruges kun til test-kommandoerne).

## Brug i dine egne scripts

I det andet scripts `fxmanifest.lua`:

```lua
shared_script '@ap1le_core/imports.lua'
dependency 'ap1le_core'
```

Så findes tabellen `Ap1le` i scriptet, ligesom `ESX` med `@es_extended/imports.lua`.
Uden imports.lua kan man skrive `exports.ap1le_core:Funktion(...)` med de samme argumenter.

## Notifikationer

**På klienten** (vises hos spilleren selv):

```lua
Ap1le.Notify('Tryk på E for at åbne menuen.')                 -- type 'info'
Ap1le.Notify('Du fik 500 kr.', 'success')                     -- med type
Ap1le.Notify('Ikke nok penge', 'error', 8000)                 -- med type og varighed (ms)

Ap1le.Notify({
    title = 'Bank',
    description = 'Du fik 500 kr.\nNy saldo: 12.500 kr.',     -- \n = ny linje
    type = 'success',
    duration = 8000,
})
```

**På serveren** (sendes til en spiller; første argument er spillerens ID):

```lua
Ap1le.Notify(source, 'Du fik 500 kr.', 'success')
Ap1le.Notify(-1, { title = 'Server', description = 'Genstart om 5 minutter', type = 'warning' }) -- -1 = alle
```

| Felt | Betyder |
|---|---|
| `title` | Overskrift (højst 60 tegn, en længere klippes og får "…"). Udelades den, bruges typens navn, fx "Succes" |
| `description` | Teksten (højst 300 tegn, ellers klippes den på samme måde) |
| `type` | `success`, `error`, `warning` eller `info` (standard). Ukendt type bliver til `info` |
| `duration` | Millisekunder (1.500-30.000, standard 5.000) |

Kommer den samme notifikation igen, mens den stadig vises, bliver den til én med "×2", "×3" osv.

Der er fire typer med hver sit ikon. Man kan tilføje en ny type i `config.lua`, fx
`police = { title = 'Politi', color = '#3b82f6' }`. Den får info-ikonet, men sin egen farve. Navnet må kun
indeholde bogstaver (a-z), tal, `-` og `_`.

## Menuer (kun klienten)

En liste af valgmuligheder med ikon, tekst og evt. undermenuer. Styres med musen eller tastaturet
(↑↓ vælg, Enter bekræft, Backspace tilbage, Esc luk).

```lua
Ap1le.RegisterMenu({
    {
        id = 'politi_hoved',
        title = 'Politi',
        onExit = function() end,                     -- valgfri: når spilleren selv lukker menuen
        options = {
            { title = 'Tjek ID', description = 'Se personens ID-kort', icon = 'id-card',
              onSelect = function() ... end },
            { title = 'Beslaglæg', icon = 'box-archive', menu = 'politi_beslag' },   -- åbner en undermenu
            { title = 'Giv bøde', icon = 'file-invoice-dollar', serverEvent = 'ap1le_police:fine', args = { amount = 500 } },
            { title = 'Kun på vagt', icon = 'lock', disabled = true },
        },
    },
    {
        id = 'politi_beslag',
        title = 'Beslaglæg',
        menu = 'politi_hoved',                       -- forælderen: giver en tilbage-knap
        options = { ... },
    },
})

Ap1le.ShowMenu('politi_hoved')                       -- false, hvis en dialog er åben (eller siden ikke svarer)
Ap1le.HideMenu()                                     -- luk den fra koden (HideMenu(true) kører også onExit)
Ap1le.GetOpenMenu()                                  -- id'et på den åbne menu, eller nil
```

Menuen **kopieres**, når den registreres. Ændrer du tabellen bagefter (fx `disabled`), så kald `RegisterMenu`
igen før `ShowMenu`. Genstartes ap1le_core, er alle menuer væk, så registrér dem lige før du viser dem
(fx inde i den kommando eller det event, der åbner menuen) - så virker det altid.

**Menuen**

| Felt | Betyder |
|---|---|
| `id` | Menuens navn (påkrævet). Brug scriptets navn foran, fx `politi_...`, så to scripts ikke bruger samme id |
| `title` | Overskriften |
| `options` | Listen af muligheder (højst 50, se `config.lua`) |
| `menu` | Forældre-menuens id: giver en tilbage-knap |
| `canClose` | `false` = kan ikke lukkes med Esc/kryds (husk så selv at give en vej ud) |
| `onExit` / `onBack` | Funktioner, når spilleren lukker menuen / går tilbage |

**En mulighed**

| Felt | Betyder |
|---|---|
| `title`, `description` | Tekst (80 / 200 tegn) |
| `icon` | Font Awesome-ikon: `'car'`, `'fa-car'` eller `'fa-brands fa-discord'` (se fontawesome.com/icons, gratis ikoner) |
| `onSelect` | Funktion, der kører, når den vælges. Får `args` med |
| `event` / `serverEvent` | Et event på klienten / serveren, der sendes med `args` |
| `args` | Data til `onSelect` / eventet |
| `menu` | Åbner en anden menu (undermenu). Findes den ikke, bruges `onSelect`/`event` i stedet |
| `arrow` | `true` = vis en pil til højre (sker automatisk ved `menu`) |
| `disabled` | `true` = grå og kan ikke vælges |

En mulighed uden `onSelect`, `event`, `serverEvent` og `menu` er kun information og kan ikke klikkes.
Menuen lukkes, *før* handlingen kører, så `onSelect` fx kan åbne en dialog.

## Dialoger (kun klienten)

Dialogerne **venter** på spillerens svar: koden efter kaldet kører først, når der er svaret. Kald dem inde i en
tråd (det er alle events, kommandoer, `onSelect` i menuer og `CreateThread`).

### Indtastning

```lua
local result = Ap1le.InputDialog('Ny bøde', {
    { type = 'input', label = 'Navn', required = true, minLength = 3, icon = 'user' },
    { type = 'number', label = 'Beløb', min = 100, max = 50000, default = 500, required = true },
    { type = 'select', label = 'Grund', required = true, options = {
        { value = 'speed', label = 'For høj fart' },
        'Andet',                                     -- en tekst er både value og label
    } },
    { type = 'textarea', label = 'Note', maxLength = 300 },
    { type = 'checkbox', label = 'Send kopi', checked = true },
}, { confirmLabel = 'Udsted bøde' })

if not result then return end                       -- nil = annulleret (eller en anden dialog var allerede åben)
local name, amount, reason, note, copy = result[1], result[2], result[3], result[4], result[5]
```

Svarene står i **samme rækkefølge** som felterne. Et tomt felt giver `nil`, et afkrydsningsfelt `true`/`false`,
et tal-felt et tal, og en `select` altid en **tekst** (også hvis `value` var et tal: `5` kommer tilbage som `'5'`).
Brug `result[1]`, `result[2]` osv. - ikke `#result` eller `table.unpack`, for der kan være huller (`nil`).

`InputDialog` giver også `nil` (og `Confirm` giver `false`), hvis der allerede er en dialog åben, eller hvis
NUI-siden ikke svarer (fx lige efter en genstart af core).

| Felt-type | Ekstra felter |
|---|---|
| `input` (tekst) | `placeholder`, `default`, `minLength`, `maxLength` (standard 200), `icon` |
| `textarea` | `placeholder`, `default`, `minLength`, `maxLength` (standard 1.000) |
| `number` | `min`, `max`, `step`, `default`, `icon` |
| `select` | `options` (liste), `default`, `placeholder`, `icon` |
| `checkbox` | `checked` |

Alle felter kan have `label` og `required = true`, og alle undtagen `checkbox` kan have `description`.
Tredje argument (valgfrit): `{ allowCancel = false, confirmLabel = '...', cancelLabel = '...' }`.

### Er du sikker?

```lua
if Ap1le.Confirm({ title = 'Slet køretøj?', content = 'Det kan ikke fortrydes.', confirmLabel = 'Slet', danger = true }) then
    -- spilleren bekræftede
end
```

Giver `true` (bekræftet) eller `false` (annulleret). `danger = true` giver en rød knap, og "Annuller" har fokus,
så et hurtigt tryk på Enter ikke gør noget farligt. `Ap1le.CloseDialog()` lukker en åben dialog fra koden.

> **Sikkerhed:** alt, hvad spilleren vælger eller skriver i en menu eller dialog, kan være snyd. Når det sendes
> til serveren, skal serveren altid selv tjekke det (job, afstand, beløb, penge osv.).

## Progress-bjælke (kun klienten)

En bjælke nederst på skærmen, fx "Visiterer...", evt. med en animation og ting i hænderne. Den **venter** ligesom
dialogerne, så kald den inde i en tråd.

```lua
local ok = Ap1le.Progress({
    label = 'Visiterer...',
    duration = 5000,                                   -- millisekunder (0,5-120 sek., se config.lua)
    icon = 'magnifying-glass',                         -- valgfri
    canCancel = true,                                  -- standard: man kan annullere med X
    disable = { move = true, car = true, combat = true },
    anim = { dict = 'missheistdockssetup1clipboard@base', clip = 'base' },   -- eller { scenario = 'WORLD_HUMAN_CLIPBOARD' }
    prop = { model = 'prop_notepad_01', bone = 18905, pos = vec3(0.1, 0.02, 0.05), rot = vec3(10.0, 0.0, 0.0) },
})

if not ok then return end                              -- annulleret eller afbrudt
```

Giver `true`, når bjælken er færdig, og `false`, hvis den blev annulleret, afbrudt, eller hvis der allerede kørte en.
Den afbrydes af sig selv, hvis spilleren dør, ragdoller, falder, svømmer eller er i håndjern (`IsPedCuffed`),
medmindre scriptet tillader det. Mens den kører, kan ox_inventory ikke åbnes (et åbent inventar lukkes).

| Felt | Betyder |
|---|---|
| `label`, `icon` | Teksten (60 tegn) og et Font Awesome-ikon |
| `duration` | Millisekunder (påkrævet) |
| `canCancel` | `false` = kan ikke annulleres af spilleren |
| `disable` | Spær taster imens: `move` (gå, løbe, hoppe), `sprint`, `car` (køre), `combat` (skyde, slå), `mouse` (kigge) |
| `anim` | `{ dict, clip, flag = 49, blendIn, blendOut, duration, playbackRate, lockX, lockY, lockZ }` eller `{ scenario, playEnter }` |
| `prop` | Én prop eller en liste (højst 2): `{ model, bone, pos, rot }`. `pos` højst 5 meter fra knoglen. Andre spillere kan også se dem |
| `useWhileDead`, `allowRagdoll`, `allowCuffed`, `allowFalling`, `allowSwimming` | `true` = bliv ved, selvom det sker |

`Ap1le.CancelProgress()` stopper bjælken fra koden, og `Ap1le.IsProgressActive()` siger, om der kører en.

Spilleren kan ændre annuller-tasten i GTA: *Indstillinger > Tastetildelinger > FiveM* ("Annuller handling (ap1le)").

> **Sikkerhed:** bjælken er kun på spillerens skærm. Giver serveren noget bagefter, skal serveren selv tjekke,
> at der er gået lang nok tid, og at spilleren stadig er tæt på.

## Hjælpetekst (kun klienten)

En lille boks med en tast og en tekst, fx **[E] Gå på vagt**, mens spilleren står et bestemt sted.

```lua
Ap1le.ShowTextUI('Gå på vagt', 'E')                                -- tekst og tast
Ap1le.ShowTextUI('Omklædning', { key = 'E', icon = 'shirt' })      -- med ikon
Ap1le.ShowTextUI('Du er i håndjern')                               -- uden tast
Ap1le.HideTextUI()
local open, text = Ap1le.IsTextUIOpen()
```

Den viser **kun** teksten: scriptet skal selv lytte efter tasten (fx `IsControlJustReleased(0, 38)` for E).
Det er fint at kalde `ShowTextUI` igen med den samme tekst, den blinker ikke. Stoppes scriptet, der viste den,
forsvinder den af sig selv. Står den i samme side som en åben menu, skjules den, til menuen lukker.

## ID-kort (kun klienten)

Et kort med foto, oplysninger og små mærker (fx kørekort-klasser), der vises et par sekunder i højre side.
Det er kun til at se på: det tager ikke musen eller tastaturet, og spilleren kan gå videre imens.

```lua
Ap1le.ShowCard({
    title = 'Identitetskort',
    subtitle = 'Kongeriget Danmark',
    icon = 'id-card',
    ped = targetPed,                                   -- valgfri: personen på fotoet (en ped i nærheden)
    fields = {
        { label = 'Navn', value = 'Anders Jensen' },
        { label = 'Fødselsdato', value = '12-03-1994' },
        { label = 'Køn', value = 'Mand' },
        { label = 'Højde', value = '182 cm' },
    },
    tags = { 'B', 'A' },                               -- valgfri: små mærker
    tagsLabel = 'Kørekort',                            -- valgfri: overskrift til mærkerne
    duration = 8000,
})

Ap1le.HideCard()                                       -- skjul det før tid
```

| Felt | Betyder |
|---|---|
| `title`, `subtitle` | Overskrift (40 tegn, standard "Identitetskort") og en lille linje under den (60 tegn) |
| `icon` | Font Awesome-ikon øverst til venstre (standard `id-card`) |
| `ped` | En ped (fx en anden spillers `GetPlayerPed(...)`). Kortet viser et foto af personens ansigt. Uden `ped`, eller hvis fotoet ikke er klar inden for 4 sekunder, vises et ikon i stedet |
| `fields` | Højst 8 felter `{ label, value }` (30 / 60 tegn). De står i to kolonner, i den rækkefølge du giver dem. En lang værdi (fx et langt navn) får hele bredden |
| `tags`, `tagsLabel` | Højst 8 korte tekster (16 tegn) som små mærker nederst, og en overskrift til dem (40 tegn) |
| `duration` | Millisekunder (2.000-30.000, standard 8.000). En streg nederst viser, hvor lang tid der er tilbage |

Der er ét kort ad gangen: et nyt kort erstatter det gamle med det samme. `ShowCard` venter ikke - kortet vises
med det samme, og fotoet kommer, når spillet har taget det (normalt under et sekund). Stoppes scriptet, der viste
kortet, forsvinder det. Er en menu åben i samme side, skjules kortet imens, og er kortet så højt, at det når ned
til hjælpeteksten (kun med mange felter), skjules hjælpeteksten, mens kortet vises.

Placeringen (`right`, `left` eller `center`) står i `config.lua` (`Config.Card.Position`).

> **Sikkerhed:** kortet viser bare det, scriptet giver det. Oplysningerne om en anden spiller skal komme fra
> serveren (fx et `lib.callback`, der tjekker job og afstand), ikke fra klienten selv.

## Radar (kun klienten)

Politiets fartmåler i bilen: egen fart i midten og op til to køretøjer (foran og bagved) med fart, retning,
nummerplade, model og en statuslinje (fx **EFTERLYST · Anders Jensen**). Den står nederst i midten og er kun til
at se på: den tager ikke musen eller tastaturet. Selve målingen (hvilke biler, opslag af pladen) laver det script,
der viser radaren, fx ap1le_police.

```lua
Ap1le.ShowRadar({
    title = 'Radar',                                   -- valgfri
    locked = false,                                    -- true = vis "Låst" (og en svag gul kant)
    speed = 54,                                        -- egen fart, eller nil = "–"
    slots = {                                          -- højst 2, i den rækkefølge du giver dem
        { label = 'Foran', plate = 'ABC 123', model = 'Sultan', speed = 87, direction = 'same',
          status = 'wanted', statusText = 'EFTERLYST', detail = 'Anders Jensen' },
        { label = 'Bagved', empty = true },            -- intet køretøj
    },
})

Ap1le.HideRadar()
Ap1le.IsRadarOpen()                                    -- true/false

-- Andre scripts på klienten kan høre, når radaren åbnes og lukkes (kun ved en ændring, ikke ved hver opdatering)
AddEventHandler('ap1le_core:radarState', function(open, position) end)   -- open = true/false, position = Config.Radar.Position
```

`ShowRadar` både viser og opdaterer: kald den bare igen med de nye tal (fx 5 gange i sekundet). Der sendes kun
noget til skærmen, når indholdet har ændret sig, og intet blinker eller glider ind igen, mens den vises.
Stoppes scriptet, der viste radaren, forsvinder den.

**Radaren**

| Felt | Betyder |
|---|---|
| `title` | Overskriften i midten (24 tegn, standard "Radar") |
| `locked`, `lockedText` | `true` = vis mærket "Låst" (16 tegn) og en svag gul kant om radaren |
| `speed`, `speedLabel`, `unit` | Egen fart (heltal 0-999, et kommatal afrundes; `nil` = "–"), teksten under den (16 tegn, standard "Egen fart") og enheden (8 tegn, standard "km/t") |
| `slots` | Højst 2 køretøjer: den første står til venstre, den anden til højre. Gives kun én, er højre side tom |

**Et køretøj (slot)**

| Felt | Betyder |
|---|---|
| `label` | Fx "Foran" eller "Bagved" (12 tegn) |
| `empty`, `emptyText` | `true` = intet køretøj: viser kun `label` og `emptyText` (30 tegn, standard "Intet køretøj") |
| `plate`, `model` | Nummerpladen (10 tegn, vises som en lille lys plade) og modellen (24 tegn) |
| `speed` | Køretøjets fart (som `speed` ovenfor) |
| `direction` | `'same'` = kører samme vej (pil op), `'opposite'` = modkørende (pil ned), `nil` = ingen pil |
| `status` | Farven på statuslinjen: `'wanted'` (rød, og pladsen pulserer), `'ok'` (grøn), `'info'` (blå), `'muted'` (grå, standard) eller `'checking'` (grå, mens der slås op) |
| `statusText`, `detail` | Statusteksten (24 tegn, fx "EFTERLYST") og en detalje efter en "·" (40 tegn, fx ejerens navn) |

Placeringen står i `config.lua` (`Config.Radar.Position`): `bottom-center` (standard) eller `top-center`. Nederst i
midten rykker progress-bjælken og hjælpeteksten (når den også står nederst i midten) op over radaren.

`ap1le_core:radarState` er en lokal event på klienten (`TriggerEvent`). Den sendes med `true`, når radaren vises
første gang, og med `false`, når den skjules, også når scriptet, der viste den, eller core selv stoppes.
Har et andet script sat et speedometer med `SetSpeedo` (se næste afsnit), lægger radaren sig under det.

> **Sikkerhed:** radaren viser bare det, scriptet giver den. Oplysninger om ejeren og efterlysninger skal komme fra
> serveren (et `lib.callback`, der tjekker job, vagt og afstand), ikke fra klienten selv.

## Speedometer (kun klienten)

Core tegner ikke selv et speedometer, men et andet script (fx ap1le_hud) kan fortælle, hvor dets runde
speedometer står nederst i midten. Så lægger radaren sig som et bredt panel under cirklen, og progress-bjælken og
hjælpeteksten (nederst i midten) rykker op over speedometeret.

```lua
Ap1le.SetSpeedo({ size = 21, bottom = 1.2, lift = 2.2 })   -- når man stiger ind
Ap1le.SetSpeedo(false)                                     -- når man stiger ud (nil virker også)
local scale = Ap1le.GetScale()                             -- Config.Scale, fx 0.75
```

| Felt | Betyder |
|---|---|
| `size` | Cirklens bredde og højde i rem (10-40) |
| `bottom` | Afstanden fra skærmens bund til cirklen i rem (0-10) |
| `lift` | Hvor meget scriptet selv løfter cirklen, mens radaren er åben, i rem (0-10) |

Er et tal ugyldigt (eller ikke et tal), giver `SetSpeedo` en fejl. Tallene er i **rem fra core's side**: brug
samme skriftstørrelse som `html/css/base.css` med `--ui-scale` = `Ap1le.GetScale()`, så måler de to sider det
samme. `GetScale` giver `Config.Scale`, hvis det er et tal mellem 0,5 og 1,5, ellers 0,75 (præcis som core's side).

Scriptet løfter selv sit speedometer `lift` rem, når `ap1le_core:radarState` siger `true`, og sænker det igen ved
`false`. Kun når `position` er `'bottom-center'` (radaren står under cirklen); står radaren øverst, løftes cirklen ikke. Stoppes scriptet, der satte
speedometeret, glemmer core det. Genstartes ap1le_core, glemmer den det også: kald `SetSpeedo` igen (fx ved
`onClientResourceStart` for `ap1le_core`).

**Radaren under speedometeret** (kun når radaren står nederst i midten): et panel på 52 × 7,4 rem, 1,2 rem fra
bunden (med standardtallene ovenfor). Foran til venstre, Bagved til højre og en tom midterkolonne på 19 rem, hvor
cirklen står. Egen fart og titlen vises ikke (farten står på speedometeret), og "Låst" er en gul kapsel nederst i
midten under cirklen. Panelet har et rundt hul (radius `size / 2 + 0,3` rem) lige der, hvor cirklen står. Hullet er
der, fordi speedometeret er et andet NUI-vindue, og man ved ikke, hvilket af dem der ligger øverst. Så overlapper de
aldrig. Uden speedometer, eller med radaren øverst, er radaren præcis som før. Den skifter med det samme, hvis
speedometeret kommer eller går, mens radaren er åben.

## Hænder op

Alle spillere kan løfte hænderne med **X** og tage dem ned igen med X. Det virker kun til fods, i live og uden
håndjern. Mens hænderne er oppe, kan man ikke skyde, slå, sigte, skifte våben eller hoppe. Hænderne kommer ned af
sig selv, hvis man sætter sig ind i et køretøj, dør, ragdoller, falder, svømmer eller får håndjern på.
X er også progress-bjælkens annuller-tast: mens en bjælke kører, annullerer X kun bjælken.

Spilleren kan ændre tasten i GTA: *Indstillinger > Tastetildelinger > FiveM* ("Hænder op (ap1le)").
Det kan slås helt fra med `Config.HandsUp.Enabled = false`.

```lua
-- Klienten
if Ap1le.IsHandsUp() then ... end

-- Serveren (fx politiet, før en visitering)
if Player(targetId).state.ap1le_handsup == true then ... end
```

State bag'en `ap1le_handsup` (`true`/`false`) sættes af spillerens **egen** klient. Den er altså kun spillerens
påstand: brug den kun til noget, der gør det *nemmere* for andre at gøre noget ved spilleren (fx visitere),
aldrig til noget, der giver spilleren selv en fordel. Kræver, at `sv_stateBagStrictMode` ikke er slået til.
Hænderne kommer heller ikke op, hvis `Player(id).state.ap1le_cuffed` er sat (politiets håndjern).

## Test

| Kommando | Viser |
|---|---|
| `/testnotify` | Én notifikation af hver type |
| `/testmenu` | En menu med undermenu, indtastnings-dialog og "Er du sikker?" (koden står i `client/test.lua`) |
| `/testprogress` | En progress-bjælke med animation, notesblok og blyant |
| `/testtextui` | Hjælpeteksten "[E] Tryk for at teste" i 10 sekunder |
| `/testcard` | Et ID-kort med dit eget foto og falske oplysninger i 10 sekunder |
| `/testradar` | Radaren med falske data i 10 sekunder: først "Slår op …", så en efterlyst foran (låser) og en registreret bagved |

Kun for admins med ESX-gruppen `admin`. Er din gruppe `owner`, så tilføj `add_principal group.owner group.admin`
i `server.cfg`.

## Design

Designet følger Apples Human Interface Guidelines (Liquid Glass, 2025). Alle værdier står som variabler i
`html/css/base.css`, som også ap1le_policetablet henter:

- **Glas**: mørk, halvgennemsigtig flade med lys kant og blød skygge. Ægte sløring kan ikke laves i FiveM.
  Store flader som menuer, dialoger og ID-kort er mere dækkende end små.
- **Former**: bløde, koncentriske hjørner (`--radius-panel`, `--radius-banner`, `--radius-control`). Knapper,
  mærker, tidslinjer og hjælpeteksten er kapsler (`--radius-capsule`).
- **Farver**: Apples systemfarver i mørk tilstand med øget kontrast (`--type-*`), tekst og flader som Apples
  `label`, `secondaryLabel` og `fill` (`--text`, `--text-muted`, `--fill*`). Farve bruges kun til status og den
  vigtigste handling: hovedfarven kun på hovedknappen, ikonet på den valgte menulinje og afkrydsningsfelter;
  progress-bjælken, tidslinjer og ikoner er neutrale.
- **Skrift**: SF Pro på Mac, ellers Segoe UI Variable eller Segoe UI. SF Pro må ikke lægges i resourcen.
  Hierarkiet vises med vægt og størrelse. Core bruger ingen versaler; kun "EFTERLYST" står med store bogstaver
  i selve teksten.
- **Bevægelse**: kort, uden hop, med Apples kurve (`--ease-out`). Glasset vokser en smule frem.
- **Radar under et speedometer** (`is-speedo` i `radar.css`): panelet får et rundt hul med `-webkit-mask-image`.
  Masken klipper også glassets ydre skygge, men den ville næsten kun falde uden for skærmen her. Målene regnes af
  `js/radar.js` (`--radar-bottom`, `--radar-width`, `--radar-mid`, `--radar-hole-y`, `--radar-hole-r`).
  Progress-bjælken og hjælpeteksten bruger `max(12vh, --radar-h, --speedo-h)`.

Designet kan også ses uden spillet. Åbn `html/index.html` i en browser med en af disse endelser:
`?demo` (notifikationer og menu), `?demo=input`, `?demo=confirm`, `?demo=sub`, `?demo=progress`, `?demo=card`
(i en browser er der intet foto, så kortet viser ikonet), `?demo=radar` (radaren med progress-bjælken og
hjælpeteksten nederst i midten) eller `?demo=radar-speedo` (radaren under et speedometer; i demoen står en grå cirkel
i stedet for ap1le_hud's speedometer. `&locked=0` = ikke låst, `&toggle` = speedometeret kommer og går hvert 3. sek.).

## Indstillinger

Alt står i `config.lua`: hovedfarven, størrelsen på hele brugerfladen (`Config.Scale`, standard 75 %), notifikationernes placering, antal, varighed og lyd, menuens side,
knappernes tekst i dialogerne, progress-bjælkens annuller-tast og tekster, hjælpetekstens, ID-kortets og radarens placering
og tasten til hænder op.
