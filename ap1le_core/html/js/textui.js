// Hjælpeteksten "[E] Gå på vagt". Lua (client/textui.lua) siger, hvornår den skal vises og skjules.
// Teksterne sættes med textContent, så de aldrig kan indeholde HTML. onAction, onConfig og createIcon ligger i core.js

const textuiElement = document.getElementById("textui");
const TEXTUI_POSITIONS = ["right-center", "left-center", "top-center", "bottom-center"];
let textuiPosition = "right-center";
let textuiHideTimer = null;

onConfig((config) => {
    const settings = config.textui && typeof config.textui === "object" ? config.textui : {};
    if (TEXTUI_POSITIONS.includes(settings.position)) textuiPosition = settings.position;
});

// Står hjælpeteksten nederst i midten, skal progress-bjælken stå over den (progress.css bruger --textui-h)
function updateTextuiHeight() {
    const visible = textuiPosition === "bottom-center" && !textuiElement.hidden;
    // + 0,75rem luft mellem de to (i rem, så luften også følger Config.Scale)
    const gap = parseFloat(getComputedStyle(document.documentElement).fontSize) * 0.75;
    const height = visible ? `${textuiElement.offsetHeight + gap}px` : "0px";
    document.documentElement.style.setProperty("--textui-h", height);
}

// Skifter spillet opløsning, mens hjælpeteksten vises, ændres dens højde i pixels (skriften følger skærmhøjden)
window.addEventListener("resize", updateTextuiHeight);

onAction("textui:show", ({ textui }) => {
    if (!textui || typeof textui !== "object") return;
    clearTimeout(textuiHideTimer);

    const children = [];
    const hasKey = typeof textui.key === "string" && textui.key !== "";
    if (hasKey) {
        const key = document.createElement("kbd");
        key.className = "keycap";
        key.textContent = textui.key;
        children.push(key);
    }
    const icon = createIcon(textui.icon);
    if (icon) {
        icon.classList.add("textui-icon");
        children.push(icon);
    }
    const text = document.createElement("span");
    text.className = "textui-text";
    text.textContent = String(textui.text ?? "");
    children.push(text);

    // Er den allerede synlig, skifter kun indholdet (klassenavnet er det samme, så den glider ikke ind igen).
    // Var den ved at forsvinde (is-leaving), fjerner det nye klassenavn det, og den glider ind igen
    textuiElement.replaceChildren(...children);
    textuiElement.className = `textui ${textuiPosition}${hasKey ? "" : " no-key"}`;
    textuiElement.hidden = false;
    updateTextuiHeight();
});

onAction("textui:hide", () => {
    if (textuiElement.hidden) return;
    clearTimeout(textuiHideTimer);
    textuiElement.classList.add("is-leaving");
    // Skjul, når ud-animationen er færdig (0,15 sek. i textui.css)
    textuiHideTimer = setTimeout(() => {
        textuiElement.hidden = true;
        textuiElement.replaceChildren();
        updateTextuiHeight();
    }, 150);
});
