// Fælles for hele NUI-siden: snak med Lua, indstillinger fra config.lua og fordeling af beskeder.
// Indlæses før notify.js, menu.js og dialog.js (se index.html), som bruger funktionerne herfra.
//
// Lua sender beskeder med SendNUIMessage({ action = 'menu:show', ... }). Hvert modul siger med onAction,
// hvilke actions det tager sig af. Svar går den anden vej med post('navn', data) til RegisterNUICallback i Lua

// Kører siden i FiveM? GetParentResourceName findes kun dér. Åbner man index.html i en almindelig
// browser (fx for at se designet), virker siden alligevel, og ?demo i adressen viser eksempler (demo.js)
const inGame = typeof GetParentResourceName === "function";

// Sender data til Lua (RegisterNUICallback). Giver svaret, eller null hvis det ikke lykkedes
async function post(name, data = {}, { timeout = 0 } = {}) {
    if (!inGame) return null;
    const controller = new AbortController();
    const timer = timeout ? setTimeout(() => controller.abort(), timeout) : null;
    try {
        const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data),
            signal: controller.signal,
        });
        return await response.json();
    } catch {
        return null;
    } finally {
        clearTimeout(timer);
    }
}

// hasOwnProperty: "objekt[navn]" alene ville også give noget for indbyggede navne som "constructor"
const has = (object, key) => Object.prototype.hasOwnProperty.call(object, key);

// Et ikon-navn fra Lua (allerede renset af ToIcon) som Font Awesome-klasser. Tjekkes igen her, så
// kun bogstaver, tal, '-' og mellemrum kan komme ind i className
function iconClass(icon) {
    return typeof icon === "string" && /^[a-z0-9 -]{1,60}$/i.test(icon) ? icon : null;
}

// Laver et <i>-ikon, eller null hvis ikonet er ugyldigt
function createIcon(icon) {
    const className = iconClass(icon);
    if (!className) return null;
    const element = document.createElement("i");
    element.className = className;
    element.setAttribute("aria-hidden", "true");
    return element;
}

// ---------- Enter holdt nede ----------
// Holder spilleren Enter nede, må det ikke vælge noget i den næste (under)menu eller bekræfte en dialog,
// der lige er åbnet. FiveM fortæller aldrig browseren, at en tast er holdt nede (event.repeat er altid false),
// så vi ser selv efter: et nyt Enter-tryk uden at tasten er sluppet imellem = tasten er holdt nede.
// "true" = vi hører tasten FØR menu.js og dialog.js, så vi kan stoppe den, inden de reagerer
let enterDownAt = 0;
document.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    const now = performance.now();
    // 1,2 sek.: længere end Windows' længste ventetid, før en holdt tast gentages (1 sek.)
    if (event.repeat || (enterDownAt && now - enterDownAt < 1200)) {
        event.preventDefault();
        event.stopImmediatePropagation();
    }
    enterDownAt = now;
}, true);
document.addEventListener("keyup", (event) => {
    if (event.key === "Enter") enterDownAt = 0;
}, true);

// ---------- Beskeder fra Lua ----------

const actionHandlers = {};
function onAction(action, handler) {
    actionHandlers[action] = handler;
}

// Beskeder, der kommer, før indstillingerne er hentet, venter her (så fx notifikationer står det rigtige sted)
let configured = false;
const pendingMessages = [];

window.addEventListener("message", (event) => {
    const message = event.data;
    if (!message || typeof message.action !== "string" || !has(actionHandlers, message.action)) return;
    if (configured) runAction(message);
    else pendingMessages.push(message);
});

function runAction(message) {
    try {
        actionHandlers[message.action](message);
    } catch (error) {
        console.error("[ap1le_core]", message.action, error);
    }
}

// ---------- Indstillinger fra config.lua ----------

const configHandlers = [];
function onConfig(handler) {
    configHandlers.push(handler);
}

function applyConfig(config) {
    config = config && typeof config === "object" ? config : {};
    if (typeof config.brandColor === "string") document.documentElement.style.setProperty("--brand", config.brandColor);
    // Størrelsen på hele brugerfladen. Kun et fornuftigt tal (0,5-1,5), ellers bruges standarden i base.css
    if (Number.isFinite(config.scale) && config.scale >= 0.5 && config.scale <= 1.5) {
        document.documentElement.style.setProperty("--ui-scale", String(config.scale));
    }
    // try/catch om hver enkelt: en fejl i ét modul må ikke stoppe de andre (så ville alt hænge i køen)
    configHandlers.forEach((handler) => {
        try { handler(config); } catch (error) { console.error("[ap1le_core]", error); }
    });

    configured = true;
    pendingMessages.splice(0).forEach(runAction);
}

// Når alle scripts er indlæst: spørg Lua om indstillingerne (RegisterNUICallback('ready') i client/nui.lua).
// Svarer Lua ikke inden for 5 sekunder, bruges standarden fra css-filerne
window.addEventListener("DOMContentLoaded", async () => {
    if (!inGame) return applyConfig({});
    const config = await post("ready", {}, { timeout: 5000 });
    if (!config) console.warn("[ap1le_core] kunne ikke hente indstillinger, bruger standarden");
    applyConfig(config);
});
