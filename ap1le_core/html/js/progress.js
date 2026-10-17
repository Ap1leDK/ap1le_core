// Progress-bjælken. Lua (client/progress.lua) styrer tiden og siger, hvornår den er færdig eller annulleret -
// siden viser den bare. Teksterne sættes med textContent, så de aldrig kan indeholde HTML.
// onAction og createIcon ligger i core.js

const progressElement = document.getElementById("progress");
let progressId = null;       // id'et på den bjælke, der vises (et "skjul" til en gammel bjælke ignoreres)
let progressHideTimer = null;
let progressFrame = null;    // requestAnimationFrame til procent-tallet

onAction("progress:show", ({ progress }) => {
    if (!progress || typeof progress !== "object") return;
    const duration = Number.isFinite(progress.duration) && progress.duration > 0 ? progress.duration : 1000;

    clearTimeout(progressHideTimer);
    cancelAnimationFrame(progressFrame);
    progressId = progress.id;

    const head = document.createElement("div");
    head.className = "progress-head";
    const icon = createIcon(progress.icon);
    if (icon) {
        icon.classList.add("progress-icon");
        head.append(icon);
    }
    const label = document.createElement("span");
    label.className = "progress-label";
    label.textContent = String(progress.label ?? "");
    const percent = document.createElement("span");
    percent.className = "progress-percent";
    percent.textContent = "0%";
    head.append(label, percent);

    const track = document.createElement("div");
    track.className = "progress-track";
    const fill = document.createElement("div");
    fill.className = "progress-fill";
    track.append(fill);

    // Nye elementer hver gang, så både ind-animationen og bjælken starter forfra
    progressElement.replaceChildren(head, track);

    if (typeof progress.cancelKey === "string" && progress.cancelKey !== "") {
        const hint = document.createElement("div");
        hint.className = "progress-hint";
        const key = document.createElement("kbd");
        key.className = "keycap";
        key.textContent = progress.cancelKey;
        hint.append(key, String(progress.cancelText ?? "Annuller"));
        progressElement.append(hint);
    }

    progressElement.className = "progress";
    progressElement.style.setProperty("--duration", `${duration}ms`);
    if (label.textContent) progressElement.setAttribute("aria-label", label.textContent);
    else progressElement.removeAttribute("aria-label");
    progressElement.setAttribute("aria-valuenow", "0");
    progressElement.hidden = false;

    // Procent-tallet: regnes ud fra tiden, så det passer med bjælken (der kører som CSS-animation).
    // Starttiden tages fra første frame: rammens tidsstempel kan ligge FØR performance.now() her (så gav det -1%).
    // Teksten skrives kun, når tallet ændrer sig
    let start = null;
    let last = 0;
    const tick = (now) => {
        if (start === null) start = now;
        const value = Math.max(0, Math.min(100, Math.floor(((now - start) / duration) * 100)));
        if (value !== last) {
            last = value;
            percent.textContent = `${value}%`;
            progressElement.setAttribute("aria-valuenow", String(value));
        }
        if (value < 100) progressFrame = requestAnimationFrame(tick);
    };
    progressFrame = requestAnimationFrame(tick);
});

onAction("progress:hide", ({ id, cancelled, cancelledText }) => {
    if (id !== progressId) return;
    progressId = null;
    cancelAnimationFrame(progressFrame);

    let wait = 0;
    if (cancelled) {
        // Vis kort, at den blev annulleret (rød og stoppet), før den forsvinder
        progressElement.classList.add("is-cancelled");
        const percent = progressElement.querySelector(".progress-percent");
        if (percent) percent.textContent = String(cancelledText ?? "Annulleret");
        wait = 700;
    } else {
        // Færdig: vis den helt fuld, mens den forsvinder (CSS-animationen kan mangle et par procent)
        progressElement.classList.add("is-done");
        progressElement.setAttribute("aria-valuenow", "100");
        const percent = progressElement.querySelector(".progress-percent");
        if (percent) percent.textContent = "100%";
    }

    progressHideTimer = setTimeout(() => {
        progressElement.classList.add("is-leaving");
        // Skjul, når ud-animationen er færdig (0,2 sek. i progress.css)
        progressHideTimer = setTimeout(() => {
            progressElement.hidden = true;
            progressElement.replaceChildren();
        }, 200);
    }, wait);
});
