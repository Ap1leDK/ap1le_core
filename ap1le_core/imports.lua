-- Genvej til ap1le_core fra dine andre scripts.
-- Skriv i det andet scripts fxmanifest.lua:
--     shared_script '@ap1le_core/imports.lua'
--     dependency 'ap1le_core'
-- Så findes tabellen "Ap1le" i scriptet (ligesom "ESX" med @es_extended/imports.lua), fx
--     Ap1le.Notify('Hej', 'success')               (på klienten)
--     Ap1le.Notify(source, 'Hej', 'success')       (på serveren)
-- i stedet for exports.ap1le_core:Notify(...). Se README.md for alle funktioner.

Ap1le = Ap1le or {}

local core = exports.ap1le_core

-- IsDuplicityVersion() er true på serveren og false på klienten
if IsDuplicityVersion() then
    -- ---------- Server ----------
    function Ap1le.Notify(target, data, notifyType, duration)
        return core:Notify(target, data, notifyType, duration)
    end
else
    -- ---------- Klient ----------
    function Ap1le.Notify(data, notifyType, duration)
        return core:Notify(data, notifyType, duration)
    end

    -- Menuer
    function Ap1le.RegisterMenu(menu) return core:RegisterMenu(menu) end
    function Ap1le.ShowMenu(id) return core:ShowMenu(id) end
    function Ap1le.HideMenu(runOnExit) return core:HideMenu(runOnExit) end
    function Ap1le.GetOpenMenu() return core:GetOpenMenu() end

    -- Dialoger. De venter på spillerens svar, så de skal kaldes inde i en tråd
    -- (det er alle events, kommandoer, onSelect i menuer og CreateThread)
    function Ap1le.InputDialog(title, fields, options) return core:InputDialog(title, fields, options) end
    function Ap1le.Confirm(data) return core:Confirm(data) end
    function Ap1le.CloseDialog() return core:CloseDialog() end

    -- Progress-bjælke. Venter, til den er færdig, så den skal også kaldes inde i en tråd
    function Ap1le.Progress(data) return core:Progress(data) end
    function Ap1le.CancelProgress() return core:CancelProgress() end
    function Ap1le.IsProgressActive() return core:IsProgressActive() end

    -- Hjælpetekst ("[E] Gå på vagt")
    function Ap1le.ShowTextUI(text, options) return core:ShowTextUI(text, options) end
    function Ap1le.HideTextUI() return core:HideTextUI() end
    function Ap1le.IsTextUIOpen() return core:IsTextUIOpen() end

    -- ID-kort med foto, felter og mærker (kun til at se på, forsvinder af sig selv)
    function Ap1le.ShowCard(data) return core:ShowCard(data) end
    function Ap1le.HideCard() return core:HideCard() end

    -- Radar i politibilen: egen fart og køretøjerne foran og bagved (kun til at se på). Kald ShowRadar igen for at
    -- opdatere - der sendes kun noget til skærmen, når indholdet har ændret sig
    function Ap1le.ShowRadar(data) return core:ShowRadar(data) end
    function Ap1le.HideRadar() return core:HideRadar() end
    function Ap1le.IsRadarOpen() return core:IsRadarOpen() end

    -- Speedometer fra et andet script (fx ap1le_hud): { size, bottom, lift } i rem, eller false = intet.
    -- Radaren lægger sig så under cirklen, og progress-bjælken og hjælpeteksten rykker op over den.
    -- Eventen 'ap1le_core:radarState' (open = true/false) fortæller, når radaren åbnes og lukkes
    function Ap1le.SetSpeedo(data) return core:SetSpeedo(data) end
    -- Størrelsen på core's brugerflade (Config.Scale, 0,5-1,5), så et andet NUI-vindue kan bruge samme rem
    function Ap1le.GetScale() return core:GetScale() end

    -- Har spilleren hænderne oppe? (X som standard)
    function Ap1le.IsHandsUp() return core:IsHandsUp() end
end
