// ID-kortet. Lua (client/card.lua) styrer tiden og fotoet og siger, hvornår kortet skal vises og skjules -
// siden tegner det bare. Al tekst sættes med textContent, så den aldrig kan indeholde HTML.
// onAction, onConfig og createIcon ligger i core.js

const cardElement = document.getElementById("card");
const CARD_POSITIONS = ["right", "left", "center"];
let cardPosition = "right";
let cardId = null;        // id'et på kortet, der vises (et "skjul" eller foto til et gammelt kort ignoreres)
let cardHideTimer = null;

// Kun billeder fra spillets egne teksturer (https://nui-img/<ordbog>/<tekstur>?v=<tid>-<kort>), sat af client/card.lua
const CARD_PHOTO_URL = /^https:\/\/nui-img\/[A-Za-z0-9_]{1,64}\/[A-Za-z0-9_]{1,64}(\?v=\d{1,15}-\d{1,10})?$/;

// Kortets top står normalt 38 % nede (samme tal som card.css)
const CARD_TOP = 0.38;

onConfig((config) => {
    const settings = config.card && typeof config.card === "object" ? config.card : {};
    if (CARD_POSITIONS.includes(settings.position)) cardPosition = settings.position;
});

// Ikonet, der står i stedet for et foto (ingen person, eller fotoet kom ikke)
function setCardPhotoFallback(photo) {
    photo.className = "card-photo is-empty";
    photo.replaceChildren(createIcon("fa-solid fa-user"));
}

function createCardField(field) {
    const row = document.createElement("div");
    row.className = "card-field";
    const label = document.createElement("dt");
    label.className = "card-label";
    label.textContent = String(field.label ?? "");
    const value = document.createElement("dd");
    value.className = "card-value";
    value.textContent = String(field.value ?? "");
    // Lange værdier (fx et langt navn) får hele bredden i stedet for at blive klemt ind i én kolonne
    if (value.textContent.length > 17 || label.textContent.length > 18) row.classList.add("is-wide");
    row.append(label, value);
    return row;
}

onAction("card:show", ({ card }) => {
    if (!card || typeof card !== "object") return;
    clearTimeout(cardHideTimer);
    cardId = card.id;

    // ---------- Toppen: ikon | titel og undertitel ----------
    const head = document.createElement("div");
    head.className = "card-head";
    const emblem = document.createElement("span");
    emblem.className = "card-emblem";
    const icon = createIcon(card.icon) ?? createIcon("fa-solid fa-id-card");
    emblem.append(icon);
    const heading = document.createElement("div");
    heading.className = "card-heading";
    const title = document.createElement("p");
    title.className = "card-title";
    title.textContent = String(card.title ?? "");
    heading.append(title);
    if (card.subtitle) {
        const subtitle = document.createElement("p");
        subtitle.className = "card-subtitle";
        subtitle.textContent = String(card.subtitle);
        heading.append(subtitle);
    }
    head.append(emblem, heading);

    // ---------- Midten: foto | felter ----------
    const body = document.createElement("div");
    body.className = "card-body";

    const photo = document.createElement("div");
    photo.setAttribute("aria-hidden", "true"); // fotoet er pynt for skærmlæsere - felterne siger, hvem det er
    if (card.photo === true) photo.className = "card-photo is-loading"; // Lua sender fotoet om lidt
    else setCardPhotoFallback(photo);

    const fields = document.createElement("dl");
    fields.className = "card-fields";
    // Står et kort felt alene i venstre kolonne, fordi det næste er bredt, får det også hele bredden -
    // så er der aldrig et hul i rækkefølgen (Navn, Født, Køn, ... står i den orden, scriptet gav dem)
    let alone = null;
    (Array.isArray(card.fields) ? card.fields : []).forEach((field) => {
        if (!field || typeof field !== "object") return;
        const row = createCardField(field);
        if (row.classList.contains("is-wide")) {
            alone?.classList.add("is-wide");
            alone = null;
        } else {
            alone = alone ? null : row;
        }
        fields.append(row);
    });
    body.append(photo, fields);

    const children = [head, body];

    // ---------- Bunden: mærker (fx kørekort-klasser) ----------
    const tags = Array.isArray(card.tags) ? card.tags.filter((tag) => typeof tag === "string" && tag !== "") : [];
    if (tags.length > 0) {
        const tagRow = document.createElement("div");
        tagRow.className = "card-tags";
        if (card.tagsLabel) {
            const tagsLabel = document.createElement("span");
            tagsLabel.className = "card-tags-label";
            tagsLabel.textContent = String(card.tagsLabel);
            tagRow.append(tagsLabel);
        }
        const list = document.createElement("span");
        list.className = "card-tag-list";
        tags.forEach((text) => {
            const tag = document.createElement("span");
            tag.className = "card-tag";
            tag.textContent = text;
            list.append(tag);
        });
        tagRow.append(list);
        children.push(tagRow);
    }

    // Tidslinjen nederst, ligesom på notifikationerne. Lua skjuler kortet, når tiden er gået
    const timer = document.createElement("div");
    timer.className = "card-timer";
    const duration = Number.isFinite(card.duration) && card.duration > 0 ? card.duration : 8000;
    timer.style.setProperty("--duration", `${duration}ms`);
    children.push(timer);

    // Nye elementer og et nyt klassenavn hver gang, så ind-animationen spilles forfra (også når et kort erstatter et andet)
    cardElement.replaceChildren(...children);
    cardElement.className = `card is-${cardPosition}`;
    cardElement.setAttribute("aria-label", title.textContent);
    cardElement.style.animation = "none";
    void cardElement.offsetWidth;
    cardElement.style.animation = "";
    cardElement.hidden = false;
    placeCard();
});

// Placerer kortet lodret. Kaldes, når kortet vises, og af notify.js, når en notifikation kommer eller forsvinder.
// 1. Står notifikationerne øverst i samme side, rykkes kortet ned under dem (dog mindst 38 % nede).
// 2. Når kortet så ud over skærmens bund (stor Config.Scale, mange felter, lille skærm), rykkes det op igen -
//    det vinder over 1., så kortet altid kan ses. Kun hvis der slet ikke er plads, dækker det notifikationerne.
// offsetHeight og innerHeight bruges (ikke getBoundingClientRect), så ind-animationens forskydning ikke tæller med
function placeCard() {
    if (cardElement.hidden) return;
    const rem = parseFloat(getComputedStyle(document.documentElement).fontSize);
    let top = window.innerHeight * CARD_TOP;

    const notifyStack = document.getElementById("notify-stack");
    if (notifyStack && cardPosition !== "center" && notifyStack.classList.contains(`top-${cardPosition}`)) {
        // Uden notifikationer er stakken 0 høj og slutter øverst - så vinder de 38 %
        top = Math.max(top, notifyStack.getBoundingClientRect().bottom + rem * 0.75);
    }

    const height = cardElement.offsetHeight;
    if (top + height > window.innerHeight - rem) top = Math.max(rem, window.innerHeight - height - rem);
    cardElement.style.top = `${Math.round(top)}px`;

    // Når kortet når ned, hvor hjælpeteksten står (62 %, i samme side), skjuler textui.css hjælpeteksten, mens
    // kortet vises. Et almindeligt kort når ikke så langt, og så bliver hjælpeteksten stående
    const textuiTop = window.innerHeight * 0.62 - rem * 2;
    cardElement.classList.toggle("is-tall", top + height > textuiTop);
}

// Skifter spillet opløsning (eller vinduesstørrelse), mens kortet vises, passer pixel-toppen ikke længere
window.addEventListener("resize", placeCard);

// Fotoet er klar (eller kom ikke). photo = adressen på billedet, eller ingenting = vis ikonet
onAction("card:photo", ({ id, photo }) => {
    if (id !== cardId) return;
    const box = cardElement.querySelector(".card-photo");
    if (!box) return;
    if (typeof photo !== "string" || !CARD_PHOTO_URL.test(photo)) return setCardPhotoFallback(box);

    const image = document.createElement("img");
    image.alt = "";
    image.decoding = "async";
    // Vis først billedet, når det er hentet - indtil da bliver "indlæser"-fladen stående
    image.addEventListener("load", () => {
        if (id !== cardId) return;
        box.className = "card-photo has-photo";
        box.replaceChildren(image);
    });
    image.addEventListener("error", () => {
        if (id === cardId) setCardPhotoFallback(box);
    });
    image.src = photo;
});

onAction("card:hide", ({ id }) => {
    if (id !== cardId || cardElement.hidden) return;
    cardId = null;
    clearTimeout(cardHideTimer);
    cardElement.classList.add("is-leaving");
    // Skjul, når ud-animationen er færdig (0,2 sek. i card.css)
    cardHideTimer = setTimeout(() => {
        cardElement.hidden = true;
        cardElement.replaceChildren();
    }, 200);
});
