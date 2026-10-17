// Notifikationer. Lua (client/notify.lua) sender dem hertil med SendNUIMessage({ action = 'notify', ... }).
// Teksterne sættes ALTID med textContent, så en notifikation aldrig kan indeholde HTML (fx fra en spillers navn).
// post, has, onAction og onConfig ligger i core.js

const stack = document.getElementById("notify-stack");
let maxVisible = 5;

// Ikonerne er vores egne, faste SVG-tegninger (ikke tekst fra et script), så innerHTML er sikkert her
const icons = {
    success: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
    error: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/></svg>',
    warning: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M12 5v9"/><path d="M12 19h.01"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M12 11v8"/><path d="M12 5.5h.01"/></svg>',
};

// Typerne fra config.lua (fyldes ud af onConfig herunder). En type, der ikke har sit eget ikon, får info-ikonet
const knownTypes = new Set(Object.keys(icons));

// De notifikationer, der vises lige nu. Nøglen er type + titel + tekst, så den samme besked, mens den
// stadig vises, ikke giver to bokse, men én med "×2". Et Map husker rækkefølgen: den første er den ældste
const active = new Map();

// ---------- Indstillinger fra config.lua ----------

const POSITIONS = ["top-right", "top-left", "top-center", "bottom-right", "bottom-left", "bottom-center"];

onConfig((config) => {
    const settings = config.notify && typeof config.notify === "object" ? config.notify : {};
    const position = POSITIONS.includes(settings.position) ? settings.position : "top-right";
    stack.className = `notify-stack ${position}`;
    if (Number.isInteger(settings.maxVisible) && settings.maxVisible > 0) maxVisible = settings.maxVisible;

    // Farverne som CSS-variabler, så css-filerne bruger dem fra config.lua.
    // Kun simple navne (bogstaver, tal, - og _), så et typenavn ikke kan lave rod i CSS'en
    const root = document.documentElement.style;
    for (const [kind, color] of Object.entries(settings.colors ?? {})) {
        if (!/^[\w-]+$/.test(kind) || typeof color !== "string") continue;
        knownTypes.add(kind);
        root.setProperty(`--type-${kind}`, color);
    }
});

// ---------- Vis en notifikation ----------

onAction("notify", (message) => show(message.notification));

// n = { title, description, type, duration } (allerede renset af Lua - men vi stoler ikke blindt på det)
function show(n) {
    if (!n || typeof n !== "object") return;
    const type = typeof n.type === "string" && knownTypes.has(n.type) ? n.type : "info";
    const title = String(n.title ?? "");
    const description = String(n.description ?? "");
    const duration = Number.isFinite(n.duration) && n.duration > 0 ? n.duration : 5000;
    const key = `${type}|${title}|${description}`;

    // Samme besked igen: tæl op, start tiden forfra, og gør den til den nyeste
    // (ellers ville den blive fjernet først, når der kommer for mange)
    const existing = active.get(key);
    if (existing) {
        existing.count += 1;
        existing.countBadge.textContent = `×${existing.count}`; // × = gangetegnet ×
        existing.countBadge.hidden = false;
        active.delete(key);
        active.set(key, existing);
        placeNewest(existing.element);
        restartTimer(key, existing, duration);
        return;
    }

    const element = document.createElement("div");
    // Kendte typer har deres egen klasse (is-success osv.). Egne typer fra config.lua får farven direkte
    element.className = `notify is-${has(icons, type) ? type : "custom"}`;
    if (!has(icons, type)) element.style.setProperty("--accent", `var(--type-${type})`);

    const icon = document.createElement("div");
    icon.className = "notify-icon";
    icon.setAttribute("aria-hidden", "true"); // ikonet er pynt - teksten siger det samme
    icon.innerHTML = icons[has(icons, type) ? type : "info"];

    const body = document.createElement("div");
    body.className = "notify-body";

    const titleRow = document.createElement("p");
    titleRow.className = "notify-title";
    const titleText = document.createElement("span");
    titleText.textContent = title;
    const countBadge = document.createElement("span");
    countBadge.className = "notify-count";
    countBadge.hidden = true;
    titleRow.append(titleText, countBadge);

    const text = document.createElement("p");
    text.className = "notify-text";
    text.textContent = description;

    const progress = document.createElement("div");
    progress.className = "notify-progress";

    body.append(titleRow, text);
    element.append(icon, body, progress);
    placeNewest(element);

    const entry = { element, progress, countBadge, count: 1, timer: null };
    active.set(key, entry);
    restartTimer(key, entry, duration);

    // For mange på én gang: fjern de ældste
    while (active.size > maxVisible) remove(active.keys().next().value);
    placeCard(); // et ID-kort i samme side rykker ned under notifikationerne (card.js)
}

// Øverst på skærmen står den nyeste øverst, nederst på skærmen står den nyeste nederst (tættest på kanten).
// Står den der allerede, flyttes den ikke: at flytte et element starter dets animation forfra (det ville blinke)
function placeNewest(element) {
    if (stack.className.includes("bottom")) {
        if (stack.lastElementChild !== element) stack.append(element);
    } else if (stack.firstElementChild !== element) {
        stack.prepend(element);
    }
}

// Starter nedtællingen (og tidslinjen) forfra
function restartTimer(key, entry, duration) {
    clearTimeout(entry.timer);
    entry.progress.style.setProperty("--duration", `${duration}ms`);
    // Animationen startes forfra ved at fjerne den, tvinge browseren til at "se" det (offsetWidth), og sætte den igen
    entry.progress.style.animation = "none";
    void entry.progress.offsetWidth;
    entry.progress.style.animation = "";
    entry.timer = setTimeout(() => remove(key), duration);
}

// Glider ud og fjernes
function remove(key) {
    const entry = active.get(key);
    if (!entry) return;
    active.delete(key);
    clearTimeout(entry.timer);
    entry.element.classList.add("is-leaving");
    // Fjern elementet, når ud-animationen er færdig. event.target: tidslinjens animation "bobler" også op hertil,
    // og den må ikke tælle. Sikkerhedsnet med setTimeout, hvis animationen ikke kører
    // Bagefter må et ID-kort i samme side rykke op igen (card.js). Kun første gang - remove() kan komme to gange
    const removeElement = () => {
        if (!entry.element.isConnected) return;
        entry.element.remove();
        placeCard();
    };
    entry.element.addEventListener("animationend", (event) => {
        if (event.target === entry.element) removeElement();
    });
    setTimeout(removeElement, 600);
}
