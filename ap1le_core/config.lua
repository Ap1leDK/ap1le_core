-- Indstillinger for ap1le_core. Ændringer kræver "ensure ap1le_core" (eller genstart af serveren)
Config = {}

-- Hovedfarven (samme røde som hjemmesiden). Bruges sparsomt, som Apples "accent": ikonet på den valgte linje i
-- menuer, hovedknappen i dialoger og afkrydsningsfelter. Pynt som progress-bjælken og tidslinjer er neutrale
Config.BrandColor = '#c72121'

-- Størrelsen på HELE brugerfladen (notifikationer, menuer, dialoger, progress-bjælke, hjælpetekst, ID-kort, radar).
-- 1.0 = fuld størrelse, 0.75 = 75 %. Mellem 0.5 og 1.5
Config.Scale = 0.75

-- ---------- Notifikationer ----------
Config.Notify = {
    -- Hvor på skærmen: 'top-right', 'top-left', 'top-center', 'bottom-right', 'bottom-left', 'bottom-center'
    -- (top-right er god, fordi minimappen sidder nede til venstre)
    Position = 'top-right',

    -- Hvor mange der højst vises på én gang. Kommer der flere, forsvinder den ældste
    MaxVisible = 5,

    -- Hvor længe en notifikation vises, hvis scriptet ikke selv siger det (millisekunder)
    DefaultDuration = 5000,

    -- Grænser, så et script ved en fejl ikke kan lave en notifikation, der står i en time
    MinDuration = 1500,
    MaxDuration = 30000,

    -- En lille lyd, når der kommer en notifikation (GTA's egne lyde, så der skal ikke downloades noget)
    Sound = true,
    SoundName = 'SELECT',
    SoundSet = 'HUD_FRONTEND_DEFAULT_SOUNDSET',

    -- Typerne: overskrift (hvis scriptet ikke giver en) og farve. Apples systemfarver (mørk, øget kontrast),
    -- de samme som i html/css/base.css
    Types = {
        success = { title = 'Succes', color = '#4ad968' },
        error   = { title = 'Fejl', color = '#ff6165' },
        warning = { title = 'Advarsel', color = '#fedf43' },
        info    = { title = 'Info', color = '#5cb8ff' },
    },
}

-- ---------- Menuer ----------
Config.Menu = {
    -- 'left' eller 'right'. Menuen står lodret i midten af den side.
    -- Venstre er standard, så den ikke kommer i vejen for notifikationerne øverst til højre
    Position = 'left',

    -- Højst så mange valgmuligheder i én menu (resten vises ikke). Brug undermenuer, hvis der er flere
    MaxOptions = 50,
}

-- ---------- Dialoger ----------
Config.Dialog = {
    -- Teksten på knapperne, hvis scriptet ikke selv vælger andre
    ConfirmLabel = 'Bekræft',
    CancelLabel = 'Annuller',
}

-- ---------- Progress-bjælke ----------
Config.Progress = {
    -- Tasten, der annullerer. Det er kun standarden, første gang en spiller kommer på serveren - derefter kan
    -- de selv ændre den i GTA: Indstillinger > Tastetildelinger > FiveM ("Annuller handling (ap1le)")
    CancelKey = 'X',

    -- Teksterne på bjælken
    CancelText = 'Annuller',
    CancelledText = 'Annulleret',

    -- Grænser, så et script ved en fejl ikke kan lave en bjælke på et halvt sekund eller en time (millisekunder)
    MinDuration = 500,
    MaxDuration = 120000,

    -- Højst så mange ting (props) i hænderne på én gang
    MaxProps = 2,
}

-- ---------- Hjælpetekst ("[E] Gå på vagt") ----------
Config.TextUI = {
    -- 'right-center', 'left-center', 'top-center' eller 'bottom-center'.
    -- Højre er standard, fordi menuen står til venstre og minimappen nede til venstre.
    -- Står den i samme side som menuen, skjules den, mens menuen er åben. Undgå at sætte den samme sted som
    -- notifikationerne (fx 'top-center' sammen med Config.Notify.Position = 'top-center')
    Position = 'right-center',
}

-- ---------- Hænder op ----------
Config.HandsUp = {
    -- false = slået fra (tasten gør ingenting). Andre scripts kan stadig spørge Ap1le.IsHandsUp() - den giver så false
    Enabled = true,

    -- Tasten. Det er kun standarden, første gang en spiller kommer på serveren - derefter kan de selv ændre den i
    -- GTA: Indstillinger > Tastetildelinger > FiveM ("Hænder op (ap1le)"). X er også progress-bjælkens
    -- annuller-tast: mens en bjælke kører, annullerer X kun bjælken (hænderne kommer ikke op)
    Key = 'X',
}

-- ---------- ID-kort ----------
Config.Card = {
    -- 'right', 'left' eller 'center'. Kortets top står 38 % nede på skærmen, så det ikke rammer
    -- notifikationerne øverst til højre eller hjælpeteksten (62 %). Står notifikationerne i samme side og fylder
    -- mere, rykker kortet ned under dem (og op igen, hvis det ellers ville gå ud over skærmens bund).
    -- Står det i samme side som en åben menu, skjules det, mens menuen er åben (tiden løber videre)
    Position = 'right',
}

-- ---------- Radar (politiets fartmåler i bilen) ----------
Config.Radar = {
    -- 'bottom-center' (standard, helt nederst i midten - hvor GTA's undertekster står, når der er nogen) eller 'top-center'.
    -- Nederst i midten rykker progress-bjælken og hjælpeteksten (bottom-center) op over radaren.
    -- Undgå notifikationerne i samme side (Config.Notify.Position 'bottom-center' / 'top-center') og hjælpeteksten
    -- øverst i midten sammen med 'top-center' (de ville stå oven i hinanden)
    Position = 'bottom-center',
}
