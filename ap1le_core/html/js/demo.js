// Demo i en almindelig browser, så designet kan ses uden spillet. Gør INGENTING i FiveM.
// Åbn html/index.html med en af disse endelser:
//   ?demo           notifikationer og en menu
//   ?demo=input     indtastnings-dialogen
//   ?demo=confirm   "Er du sikker?" (rød)
//   ?demo=sub       en undermenu med tilbage-knap
//   ?demo=progress  progress-bjælken (kører igen og igen, hver anden gang annulleret) og hjælpeteksten
//   ?demo=card      ID-kortet sammen med notifikationer og hjælpeteksten (så man kan se, at de ikke rammer hinanden)
//   ?demo=radar     radaren (låst, foran EFTERLYST, bagved registreret) med progress-bjælken og hjælpeteksten
//                   nederst i midten (så man kan se, at de ikke rammer hinanden). Farten skifter hver 200 ms
//   ?demo=radar-speedo  radaren under et speedometer (is-speedo), som ap1le_hud tegner i spillet. Her står en grå
//                   cirkel i stedet, så man kan se hullet i panelet. &locked=0 = ikke låst, &toggle = speedometeret
//                   kommer og går hvert 3. sek. (som når man stiger ind og ud)

window.addEventListener("DOMContentLoaded", () => {
    const params = new URLSearchParams(location.search);
    if (inGame || !params.has("demo")) return;

    document.body.style.background = "linear-gradient(135deg, #3a4a5a, #8a6a4a)"; // noget at se glasset mod
    const run = (action, data) => actionHandlers[action]({ action, ...data });
    const mode = params.get("demo");

    if (mode === "progress") {
        run("textui:show", { textui: { text: "Gå på vagt", key: "E", icon: "fa-solid fa-id-badge" } });
        let id = 0;
        const loop = () => {
            id += 1;
            const current = id;
            const cancel = current % 2 === 0;
            run("progress:show", { progress: {
                id: current, label: "Visiterer person...", icon: "fa-solid fa-magnifying-glass",
                duration: 4000, cancelKey: "X", cancelText: "Annuller",
            } });
            setTimeout(() => {
                run("progress:hide", { id: current, cancelled: cancel, cancelledText: "Annulleret" });
                setTimeout(loop, 1500);
            }, cancel ? 1800 : 4000);
        };
        loop();
        return;
    }

    if (mode === "radar") {
        // Hjælpeteksten nederst i midten (i spillet: Config.TextUI.Position = 'bottom-center')
        textuiPosition = "bottom-center";
        run("textui:show", { textui: { text: "Åbn bagagerummet", key: "E", icon: "fa-solid fa-car-rear" } });
        run("progress:show", { progress: {
            id: 1, label: "Skriver fartbøde...", icon: "fa-solid fa-pen", duration: 600000, cancelKey: "X", cancelText: "Annuller",
        } });
        // Ligesom i spillet: hele radaren sendes igen ~5 gange i sekundet, kun farten skifter
        let tick = 0;
        const update = () => {
            tick += 1;
            const wave = (offset, size) => Math.round(Math.sin(tick / 6 + offset) * size);
            run("radar:show", { radar: {
                title: "Radar", locked: true, lockedText: "Låst", speed: 84 + wave(0, 3), speedLabel: "Egen fart", unit: "km/t",
                slots: [
                    { label: "Foran", empty: false, plate: "ABC 123", model: "Karin Sultan", speed: 97, direction: "same",
                      status: "wanted", statusText: "EFTERLYST", detail: "Anders Christian Jensen" },
                    { label: "Bagved", empty: false, plate: "XY 98 765", model: "Pegasi Faggio", speed: 62 + wave(1, 9), direction: "opposite",
                      status: "ok", statusText: "Registreret", detail: "Mette Hansen" },
                ],
            } });
        };
        update();
        setInterval(update, 200);
        return;
    }

    if (mode === "radar-speedo") {
        const SPEEDO = { size: 21, bottom: 1.2, lift: 2.2 }; // de samme tal, som ap1le_hud sender med SetSpeedo
        const locked = params.get("locked") !== "0";

        // En stand-in for ap1le_hud's speedometer (kun i demoen): en cirkel med en mørk ring, løftet, mens radaren
        // er åben. I spillet er det et andet NUI-vindue. z-index 10: den ligger OVER radaren, så et overlap kunne ses
        const circle = document.createElement("div");
        Object.assign(circle.style, {
            position: "fixed", left: "50%", bottom: `${SPEEDO.bottom + SPEEDO.lift}rem`, zIndex: "10",
            width: `${SPEEDO.size}rem`, height: `${SPEEDO.size}rem`, transform: "translateX(-50%)", borderRadius: "50%",
            display: "flex", alignItems: "center", justifyContent: "center", flexDirection: "column",
            background: "radial-gradient(circle at 50% 35%, rgba(44,44,50,0.86) 0%, rgba(22,22,26,0.9) 70%)",
            border: "1px solid rgba(255,255,255,0.16)", boxShadow: "0 0 0 0.3rem rgba(14,14,18,0.55)",
        });
        const number = document.createElement("div");
        number.style.cssText = "font-size: 4.4rem; font-weight: 700; line-height: 0.95; font-variant-numeric: tabular-nums;";
        number.textContent = "84";
        const unit = document.createElement("div");
        unit.style.cssText = "font-size: 0.78rem; color: var(--text-muted);";
        unit.textContent = "km/t (ap1le_hud)";
        circle.append(number, unit);
        document.body.append(circle);

        run("hud:speedo", { speedo: SPEEDO });
        if (params.has("toggle")) {
            let on = true;
            setInterval(() => {
                on = !on;
                circle.style.display = on ? "flex" : "none";
                run("hud:speedo", on ? { speedo: SPEEDO } : {});
            }, 3000);
        }

        textuiPosition = "bottom-center";
        run("textui:show", { textui: { text: "Åbn bagagerummet", key: "E", icon: "fa-solid fa-car-rear" } });
        run("progress:show", { progress: {
            id: 1, label: "Skriver fartbøde...", icon: "fa-solid fa-pen", duration: 600000, cancelKey: "X", cancelText: "Annuller",
        } });
        let tick = 0;
        const update = () => {
            tick += 1;
            const wave = (offset, size) => Math.round(Math.sin(tick / 6 + offset) * size);
            const speed = 84 + wave(0, 3);
            number.textContent = String(speed);
            run("radar:show", { radar: {
                title: "Radar", locked, lockedText: "Låst", speed, speedLabel: "Egen fart", unit: "km/t",
                slots: [
                    { label: "Foran", empty: false, plate: "ABC 123", model: "Karin Sultan", speed: 97, direction: "same",
                      status: "wanted", statusText: "EFTERLYST", detail: "Anders Christian Jensen" },
                    { label: "Bagved", empty: false, plate: "XY 98 765", model: "Pegasi Faggio", speed: 62 + wave(1, 9), direction: "opposite",
                      status: "ok", statusText: "Registreret", detail: "Mette Hansen" },
                ],
            } });
        };
        update();
        setInterval(update, 200);
        return;
    }

    if (mode === "card") {
        const notify = (title, description, type) => run("notify", { notification: { title, description, type, duration: 600000 } });
        notify("Politiet er på vej", "Nogen har ringet 112 om et indbrud i nærheden.", "warning");
        notify("Betaling gennemført", "Du har betalt 2.500 kr. for reparationen.", "success");
        run("textui:show", { textui: { text: "Gå på vagt", key: "E", icon: "fa-solid fa-id-badge" } });
        run("card:show", { card: {
            id: 1, title: "Identitetskort", subtitle: "Kongeriget Danmark", icon: "fa-solid fa-id-card", photo: true,
            fields: [
                { label: "Navn", value: "Anders Christian Jensen" },
                { label: "Fødselsdato", value: "12-03-1994" },
                { label: "Køn", value: "Mand" },
                { label: "Højde", value: "182 cm" },
            ],
            tags: ["B", "A", "C", "Våben"], tagsLabel: "Kørekort og licenser", duration: 600000,
        } });
        // I en browser findes spillets foto ikke: efter "indlæser" vises ikonet i stedet (ligesom ved en timeout)
        setTimeout(() => run("card:photo", { id: 1 }), 1500);
        return;
    }

    if (mode === "input") {
        run("dialog:input", { dialog: {
            id: 1, title: "Ny bøde", allowCancel: true, confirmLabel: "Udsted bøde",
            fields: [
                { type: "input", label: "Navn", placeholder: "Fx Anders Jensen", required: true, minLength: 3, maxLength: 200, icon: "fa-solid fa-user" },
                { type: "number", label: "Beløb", description: "Mellem 100 og 50.000 kr.", min: 100, max: 50000, default: 500, required: true, icon: "fa-solid fa-money-bill" },
                { type: "select", label: "Grund", required: true, options: [{ value: "speed", label: "For høj fart" }, { value: "parking", label: "Ulovlig parkering" }] },
                { type: "textarea", label: "Note", placeholder: "Valgfri note", maxLength: 300, minLength: 0 },
                { type: "checkbox", label: "Send kopi til borgeren", checked: true },
            ],
        } });
        return;
    }

    if (mode === "confirm") {
        run("dialog:confirm", { dialog: {
            id: 1, title: "Slet køretøj?", content: "Køretøjet bliver slettet for altid.\nDet kan ikke fortrydes.", confirmLabel: "Slet", danger: true,
        } });
        return;
    }

    if (mode === "sub") {
        run("menu:show", { menu: { id: "sub", title: "Undermenu", hasParent: true, canClose: true, options: [
            { index: 1, title: "Kun information", description: "En mulighed uden handling", icon: "fa-solid fa-circle-info", readOnly: true },
            { index: 2, title: "Med args", description: "onSelect får args med", icon: "fa-solid fa-code" },
        ] } });
        return;
    }

    const notify = (title, description, type) => run("notify", { notification: { title, description, type, duration: 600000 } });
    notify("Betaling gennemført", "Du har betalt 2.500 kr. for reparationen.", "success");
    notify("Politiet er på vej", "Nogen har ringet 112 om et indbrud i nærheden.", "warning");

    run("menu:show", { menu: { id: "demo", title: "Politi", hasParent: false, canClose: true, options: [
        { index: 1, title: "Tjek ID", description: "Se personens ID-kort", icon: "fa-solid fa-id-card" },
        { index: 2, title: "Giv bøde", description: "Udsted en bøde til den nærmeste person", icon: "fa-solid fa-file-invoice-dollar" },
        { index: 3, title: "Beslaglæg", description: "Våben og ulovlige ting", icon: "fa-solid fa-box-archive", arrow: true },
        { index: 4, title: "Ring efter tow-truck", icon: "fa-solid fa-truck-pickup" },
        { index: 5, title: "Kan ikke vælges", description: "disabled = true", icon: "fa-solid fa-lock", disabled: true },
    ] } });
});
