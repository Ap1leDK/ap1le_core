// Radaren i politibilen. Lua (client/radar.lua) sender hele indholdet, hver gang noget ændrer sig (op til 5 gange
// i sekundet). DOM'en bygges ÉN gang, og derefter skiftes kun tekst og klasser - så intet blinker, og animationerne
// (ind-animationen, pulsen ved EFTERLYST) starter ikke forfra. Al tekst sættes med textContent.
// Har et andet script et speedometer nederst i midten (client/hud.lua, "hud:speedo"), lægger radaren sig som et
// bredt panel under cirklen (is-speedo, se nederst). onAction, onConfig og createIcon ligger i core.js

const radarElement = document.getElementById("radar");
const RADAR_POSITIONS = ["bottom-center", "top-center"];
const RADAR_STATUSES = ["wanted", "ok", "info", "muted", "checking"];
const RADAR_DIRECTIONS = { same: "fa-solid fa-arrow-up", opposite: "fa-solid fa-arrow-down" };
const RADAR_MAX_SLOTS = 2;
let radarPosition = "bottom-center";
let radarParts = null;    // elementerne, når DOM'en er bygget (første gang radaren vises)
let radarHideTimer = null;
let radarOpen = false;    // det, Lua siger (radar:show / radar:hide) - også mens ud-animationen kører
let radarSpeedo = null;   // speedometeret fra et andet script: { size, bottom, lift } i rem, eller null

onConfig((config) => {
    const settings = config.radar && typeof config.radar === "object" ? config.radar : {};
    if (RADAR_POSITIONS.includes(settings.position)) radarPosition = settings.position;
    updateRadarLayout();
});

// Små hjælpere: et nyt element, en tekst (kun hvis den er ændret) og en fart
function radarCreate(tag, className, parent) {
    const element = document.createElement(tag);
    element.className = className;
    if (parent) parent.append(element);
    return element;
}

function radarString(value, fallback = "") {
    return typeof value === "string" && value !== "" ? value : fallback;
}

function radarSetText(element, text) {
    if (element.textContent !== text) element.textContent = text;
}

// En fart: heltal 0-999, ellers "–" (ingen måling, vises dæmpet)
function radarSetSpeed(element, value) {
    const valid = Number.isInteger(value) && value >= 0 && value <= 999;
    radarSetText(element, valid ? String(value) : "–");
    element.classList.toggle("is-blank", !valid);
}

// ---------- DOM'en (bygges én gang) ----------

// Et køretøj: label + retning + nummerplade | fart | model | status · detalje. "Intet køretøj" ligger ovenpå
function buildRadarSlot() {
    const root = radarCreate("div", "radar-slot is-unused");

    const head = radarCreate("div", "radar-slot-head", root);
    const label = radarCreate("span", "radar-label", head);
    const direction = radarCreate("i", "radar-direction", head);
    direction.setAttribute("aria-hidden", "true");
    const plate = radarCreate("span", "radar-plate", head);

    const body = radarCreate("div", "radar-slot-body", root);
    const reading = radarCreate("div", "radar-reading", body);
    const speed = radarCreate("span", "radar-speed", reading);
    const unit = radarCreate("span", "radar-unit", reading);
    const model = radarCreate("div", "radar-model", body);
    const status = radarCreate("div", "radar-status", body);
    const statusText = radarCreate("span", "radar-status-text", status);
    const separator = radarCreate("span", "radar-status-sep", status);
    separator.textContent = "·";
    separator.setAttribute("aria-hidden", "true");
    const detail = radarCreate("span", "radar-status-detail", status);

    const empty = radarCreate("div", "radar-empty", root);

    return { root, label, direction, plate, speed, unit, model, statusText, separator, detail, empty };
}

function buildRadar() {
    const slots = [buildRadarSlot(), buildRadarSlot()];

    // Midten: titel, egen fart og "Låst"
    const center = radarCreate("div", "radar-center");
    const title = radarCreate("div", "radar-title", center);
    title.append(createIcon("fa-solid fa-satellite-dish"));
    const titleText = radarCreate("span", "radar-title-text", title);
    const own = radarCreate("div", "radar-own", center);
    const ownSpeed = radarCreate("span", "radar-own-speed", own);
    const ownUnit = radarCreate("span", "radar-own-unit", own);
    const ownLabel = radarCreate("div", "radar-own-label", center);
    const lock = radarCreate("div", "radar-lock", center);
    lock.append(createIcon("fa-solid fa-lock"));
    const lockText = radarCreate("span", "radar-lock-text", lock);

    radarElement.replaceChildren(slots[0].root, center, slots[1].root);
    return { slots, titleText, ownSpeed, ownUnit, ownLabel, lockText };
}

// ---------- Opdatering ----------

function updateRadarSlot(parts, slot, unit) {
    const used = !!slot && typeof slot === "object";
    parts.root.classList.toggle("is-unused", !used); // usynlig, men fylder stadig, så midten bliver i midten
    if (!used) return;

    const empty = slot.empty === true;
    parts.root.classList.toggle("is-empty", empty);
    radarSetText(parts.label, radarString(slot.label));
    radarSetText(parts.empty, empty ? radarString(slot.emptyText, "Intet køretøj") : "");

    const status = empty || !RADAR_STATUSES.includes(slot.status) ? "muted" : slot.status;
    RADAR_STATUSES.forEach((name) => parts.root.classList.toggle(`is-${name}`, name === status));

    const direction = !empty && typeof slot.direction === "string" && has(RADAR_DIRECTIONS, slot.direction)
        ? `radar-direction ${RADAR_DIRECTIONS[slot.direction]}` : "radar-direction";
    if (parts.direction.className !== direction) parts.direction.className = direction;

    const plate = empty ? "" : radarString(slot.plate);
    radarSetText(parts.plate, plate);
    parts.plate.classList.toggle("is-blank", plate === "");
    radarSetSpeed(parts.speed, empty ? null : slot.speed);
    radarSetText(parts.unit, unit);
    radarSetText(parts.model, empty ? "" : radarString(slot.model));

    const detail = empty ? "" : radarString(slot.detail);
    radarSetText(parts.statusText, empty ? "" : radarString(slot.statusText));
    radarSetText(parts.detail, detail);
    parts.separator.hidden = detail === "" || parts.statusText.textContent === "";
}

onAction("radar:show", ({ radar }) => {
    if (!radar || typeof radar !== "object") return;
    if (!radarParts) radarParts = buildRadar();
    clearTimeout(radarHideTimer);
    if (!radarOpen) {
        radarOpen = true;
        updateSpeedoHeight(); // speedometeret løftes, mens radaren er åben
    }

    const parts = radarParts;
    const unit = radarString(radar.unit, "km/t");
    const title = radarString(radar.title, "Radar");
    radarSetText(parts.titleText, title);
    radarSetSpeed(parts.ownSpeed, radar.speed);
    radarSetText(parts.ownUnit, unit);
    radarSetText(parts.ownLabel, radarString(radar.speedLabel, "Egen fart"));
    radarSetText(parts.lockText, radarString(radar.lockedText, "Låst"));

    const slots = Array.isArray(radar.slots) ? radar.slots.slice(0, RADAR_MAX_SLOTS) : [];
    parts.slots.forEach((slotParts, index) => updateRadarSlot(slotParts, slots[index], unit));

    radarElement.classList.toggle("is-locked", radar.locked === true);
    RADAR_POSITIONS.forEach((position) => radarElement.classList.toggle(`is-${position}`, position === radarPosition));
    if (radarElement.getAttribute("aria-label") !== title) radarElement.setAttribute("aria-label", title);

    // Var den ved at forsvinde, glider den ind igen (animationen skifter tilbage). Var den skjult, starter
    // ind-animationen af sig selv, når den bliver synlig. Ellers sker der ingenting med animationerne
    const wasHidden = radarElement.hidden;
    // (kun når den står der: remove skriver ellers class-attributten ved hver opdatering)
    if (radarElement.classList.contains("is-leaving")) radarElement.classList.remove("is-leaving");
    radarElement.hidden = false;
    if (wasHidden) updateRadarHeight();
});

onAction("radar:hide", () => {
    if (radarOpen) {
        radarOpen = false;
        updateSpeedoHeight();
    }
    if (radarElement.hidden || radarElement.classList.contains("is-leaving")) return;
    clearTimeout(radarHideTimer);
    radarElement.classList.add("is-leaving");
    // Skjul, når ud-animationen er færdig (0,2 sek. i radar.css). DOM'en bliver liggende til næste gang
    radarHideTimer = setTimeout(() => {
        radarElement.hidden = true;
        radarElement.classList.remove("is-leaving");
        updateRadarHeight();
    }, 200);
});

// ---------- Ryk de andre op ----------
// Står radaren nederst i midten, skal progress-bjælken og hjælpeteksten (bottom-center) stå over den.
// progress.css og textui.css bruger --radar-h: radarens højde + afstanden til bunden + 0,75rem luft (0, når den
// ikke vises dér). offsetHeight bruges, så ind-animationens forskydning ikke tæller med
function updateRadarHeight() {
    let height = "0px";
    if (!radarElement.hidden && radarPosition === "bottom-center") {
        const rem = parseFloat(getComputedStyle(document.documentElement).fontSize);
        const bottom = parseFloat(getComputedStyle(radarElement).bottom) || 0;
        height = `${Math.ceil(radarElement.offsetHeight + bottom + rem * 0.75)}px`;
    }
    const root = document.documentElement.style;
    if (root.getPropertyValue("--radar-h") !== height) root.setProperty("--radar-h", height);
}

// Højden kan skifte (fx en lang tekst, der ombrydes, eller en ny opløsning, der ændrer rem)
if (typeof ResizeObserver === "function") new ResizeObserver(updateRadarHeight).observe(radarElement);
window.addEventListener("resize", updateRadarHeight);

// ---------- Under et speedometer (is-speedo) ----------
// Et andet script (fx ap1le_hud) tegner et rundt speedometer nederst i midten i sit EGET NUI-vindue og fortæller
// core, hvor det står (Lua: SetSpeedo). Står radaren også nederst i midten, bliver den et bredt panel, som cirklen
// sidder ned i: Foran til venstre, Bagved til højre, "Låst" nederst i midten. Man ved ikke, hvilket NUI-vindue der
// ligger øverst, så panelet får et rundt hul (maske i radar.css), hvor cirklen står - de overlapper aldrig.
// Uden speedometer (eller med radaren øverst) er det præcis det gamle layout
const SPEEDO_LIMITS = { size: [10, 40], bottom: [0, 10], lift: [0, 10] }; // rem, samme grænser som client/hud.lua
const RADAR_SPEEDO_HEIGHT = 7.4; // panelets højde (rem, samme som radar.css)
const RADAR_SPEEDO_GAP = 0.3;    // luft mellem cirklen og panelet (rem)
const RADAR_SPEEDO_SIDES = 33;   // panelets bredde uden midterkolonnen: 2 x 15,9rem til pladserne + 2 x 0,6rem luft

// Et tal med højst 3 decimaler som tekst (så der ikke står 25.150000000000002rem)
function radarRem(value) {
    return `${Math.round(value * 1000) / 1000}rem`;
}

// Sætter en css-variabel, kun hvis den er ændret
function radarSetVar(style, name, value) {
    if (style.getPropertyValue(name) !== value) style.setProperty(name, value);
}

// { size, bottom, lift } med tal inden for grænserne, ellers null (= intet speedometer)
function radarReadSpeedo(data) {
    if (!data || typeof data !== "object") return null;
    const speedo = {};
    for (const [name, [min, max]] of Object.entries(SPEEDO_LIMITS)) {
        const value = data[name];
        if (!Number.isFinite(value) || value < min || value > max) return null;
        speedo[name] = value;
    }
    return speedo;
}

// Skifter mellem det gamle layout og is-speedo og regner panelets mål ud fra speedometeret
function updateRadarLayout() {
    const on = radarSpeedo !== null && radarPosition === "bottom-center";
    radarElement.classList.toggle("is-speedo", on);
    if (!on) return;

    const { size, bottom, lift } = radarSpeedo;
    // Cirklen står "lift" over panelets bund, mens radaren er åben. Hullets centrum målt fra panelets top
    // (negativt = over panelet) og radius
    const radius = size / 2 + RADAR_SPEEDO_GAP;
    const centerY = RADAR_SPEEDO_HEIGHT - lift - size / 2;
    // Midterkolonnen er mindst så bred som hullet ved panelets top, så hullet aldrig skærer i pladserne
    // (med size 21 og lift 2,2: hullet er 18,9rem, kolonnen 19rem)
    const half = centerY >= 0 ? radius : Math.sqrt(Math.max(0, radius * radius - centerY * centerY));
    const middle = Math.max(size - 2, Math.ceil(half * 20) / 10);

    const style = radarElement.style;
    radarSetVar(style, "--radar-bottom", radarRem(bottom));
    radarSetVar(style, "--radar-mid", radarRem(middle));
    radarSetVar(style, "--radar-width", radarRem(middle + RADAR_SPEEDO_SIDES));
    radarSetVar(style, "--radar-hole-y", radarRem(centerY));
    radarSetVar(style, "--radar-hole-r", radarRem(radius));
}

// progress.css og textui.css bruger --speedo-h: speedometerets top + 0,75rem luft (0, når der intet er).
// Mens radaren er åben, er speedometeret løftet "lift" (det gør scriptet, der tegner det)
function updateSpeedoHeight() {
    const speedo = radarSpeedo;
    const lifted = radarOpen && radarPosition === "bottom-center";
    const height = speedo ? radarRem(speedo.bottom + speedo.size + (lifted ? speedo.lift : 0) + 0.75) : "0px";
    radarSetVar(document.documentElement.style, "--speedo-h", height);
}

onAction("hud:speedo", ({ speedo }) => {
    radarSpeedo = radarReadSpeedo(speedo);
    updateRadarLayout();
    updateSpeedoHeight();
    // Radarens størrelse og afstand til bunden kan have skiftet (ResizeObserver ser kun størrelsen)
    updateRadarHeight();
});
