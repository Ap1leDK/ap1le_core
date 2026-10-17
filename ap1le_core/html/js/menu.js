// Menuer. Lua (client/menu.lua) sender menuen som ren tekst - funktionerne (onSelect osv.) bliver i Lua.
// Her tegner vi den og sender bare nummeret på det valgte tilbage. Al tekst sættes med textContent.
// Styres med musen eller tastaturet: piletaster, Enter, Backspace (tilbage) og Escape (luk)

const menuElement = document.getElementById("menu");
let currentMenu = null; // menuen, der vises lige nu: { title, hasParent, canClose, options }

onConfig((config) => {
    const position = config.menu?.position === "right" ? "right" : "left";
    menuElement.className = `menu is-${position}`;
});

onAction("menu:show", (message) => showMenu(message.menu));
onAction("menu:hide", hideMenu);

function showMenu(menu) {
    if (!menu || typeof menu !== "object") return;
    currentMenu = menu;
    const options = Array.isArray(menu.options) ? menu.options : [];

    // ---------- Toppen ----------
    const header = document.createElement("div");
    header.className = "menu-header";

    if (menu.hasParent) header.append(createIconButton("fa-solid fa-chevron-left", "Tilbage", () => send("menu:back")));

    const title = document.createElement("h2");
    title.className = "menu-title";
    title.textContent = String(menu.title ?? "");
    header.append(title);

    if (menu.canClose !== false) header.append(createIconButton("fa-solid fa-xmark", "Luk", () => send("menu:close")));

    // ---------- Listen ----------
    const list = document.createElement("div");
    list.className = "menu-list";
    list.setAttribute("role", "menu");
    title.id = "menu-title";
    list.setAttribute("aria-labelledby", title.id);
    options.forEach((option) => list.append(createOption(option)));
    if (options.length === 0) {
        const empty = document.createElement("p");
        empty.className = "menu-empty";
        empty.textContent = "Ingen muligheder.";
        list.append(empty);
    }

    // ---------- Bunden: tastatur-hjælp ----------
    const footer = document.createElement("div");
    footer.className = "menu-footer";
    footer.append(createHint("↑↓", "Vælg"), createHint("Enter", "Bekræft"));
    if (menu.hasParent) footer.append(createHint("⌫", "Tilbage"));
    if (menu.canClose !== false) footer.append(createHint("Esc", "Luk"));

    menuElement.replaceChildren(header, list, footer);
    menuElement.hidden = false;

    // Animationen spilles forfra, også når man skifter til en undermenu
    menuElement.style.animation = "none";
    void menuElement.offsetWidth;
    menuElement.style.animation = "";

    // Den første mulighed, der kan vælges, får fokus, så tastaturet virker med det samme
    list.querySelector(".menu-option:not(:disabled)")?.focus();
}

function hideMenu() {
    currentMenu = null;
    menuElement.hidden = true;
    menuElement.replaceChildren();
}

// Sender et valg til Lua - kun ét ad gangen. Et hurtigt dobbeltklik på en undermenu ville ellers ramme
// en mulighed i den NYE menu. id'et sendes med, så Lua også selv kan afvise et svar til en forkert menu.
// "Luk" kommer altid igennem, og spærringen ophæves efter et halvt sekund, hvis Lua ikke har svaret (fx hvis
// valget blev afvist) - spilleren må aldrig sidde fast i en menu med musen fanget
function send(name, data = {}) {
    const menu = currentMenu;
    if (!menu || (menu.sent && name !== "menu:close")) return;
    menu.sent = true;
    post(name, { ...data, id: menu.id });
    setTimeout(() => { if (currentMenu === menu) menu.sent = false; }, 500);
}

// Én mulighed: ikon | titel og beskrivelse | pil
function createOption(option) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "menu-option";
    button.setAttribute("role", "menuitem");
    button.disabled = option.disabled === true;

    // Ikonet i en rund flade - kun hvis der er et (ellers ville der stå en tom cirkel)
    const icon = createIcon(option.icon);
    let iconBox = null;
    if (icon) {
        iconBox = document.createElement("span");
        iconBox.className = "menu-option-icon";
        iconBox.append(icon);
    }

    const text = document.createElement("span");
    text.className = "menu-option-text";
    const title = document.createElement("span");
    title.className = "menu-option-title";
    title.textContent = String(option.title ?? "");
    text.append(title);
    if (option.description) {
        const description = document.createElement("span");
        description.className = "menu-option-description";
        description.textContent = String(option.description);
        text.append(description);
    }

    if (iconBox) button.append(iconBox);
    button.append(text);
    if (option.arrow) button.append(createIcon("fa-solid fa-chevron-right menu-option-arrow"));

    // Kun information (ingen handling i Lua): kan ikke klikkes, men kan stadig læses og vælges med piletasterne
    if (option.readOnly) {
        button.classList.add("is-readonly");
        button.setAttribute("aria-disabled", "true");
    } else {
        // index = nummeret i menuens egen liste i Lua (det er det, Lua skal bruge)
        button.addEventListener("click", () => send("menu:select", { index: option.index }));
    }
    // Når musen BEVÆGES over en mulighed, flyttes tastatur-fokus derhen, så piletasterne fortsætter derfra.
    // mousemove (ikke mouseenter): ruller listen under en musemarkør, der står stille, må fokus ikke hoppe
    button.addEventListener("mousemove", () => {
        if (!button.disabled && document.activeElement !== button) button.focus({ preventScroll: true });
    });
    return button;
}

function createIconButton(icon, label, onClick) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "menu-icon-button";
    button.setAttribute("aria-label", label);
    button.append(createIcon(icon));
    button.addEventListener("click", onClick);
    return button;
}

function createHint(key, label) {
    const hint = document.createElement("span");
    const kbd = document.createElement("kbd");
    kbd.textContent = key;
    hint.append(kbd, label);
    return hint;
}

// ---------- Tastaturet ----------

document.addEventListener("keydown", (event) => {
    // Kun når en menu er åben, og ikke når en dialog står ovenpå (dialog.js tager sig af tasterne dér)
    if (!currentMenu || menuElement.hidden || isDialogOpen()) return;

    // (Enter holdt nede stoppes allerede i core.js)
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault(); // ellers ruller listen også
        moveFocus(event.key === "ArrowDown" ? 1 : -1);
    } else if (event.key === "Escape") {
        event.preventDefault();
        if (currentMenu.canClose !== false) send("menu:close");
    } else if (event.key === "Backspace") {
        event.preventDefault();
        if (currentMenu.hasParent) send("menu:back");
    }
    // Enter og mellemrum klikker selv på den knap, der har fokus (det gør browseren)
});

// Flytter fokus op eller ned blandt de muligheder, der kan vælges. Fra bunden hopper den til toppen og omvendt
function moveFocus(step) {
    const buttons = [...menuElement.querySelectorAll(".menu-option:not(:disabled)")];
    if (buttons.length === 0) return;
    const current = buttons.indexOf(document.activeElement);
    const next = current === -1 ? 0 : (current + step + buttons.length) % buttons.length;
    // preventScroll + "nearest": listen ruller kun så lidt som muligt, i stedet for at centrere den valgte
    buttons[next].focus({ preventScroll: true });
    buttons[next].scrollIntoView({ block: "nearest" });
}
