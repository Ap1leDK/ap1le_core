// Dialoger: indtastning (InputDialog) og "Er du sikker?" (Confirm). Lua (client/dialog.lua) venter på svaret.
// Felterne tjekkes her, så spilleren får en fejlbesked med det samme. Lua tjekker typen og grænserne igen
// (tal, valgmuligheder, længde), og serveren skal altid selv tjekke det, den får. Al tekst sættes med textContent

const dialogRoot = document.getElementById("dialog-root");
let currentDialog = null; // { id, kind, allowCancel, sent }
const dialogLabels = { confirm: "Bekræft", cancel: "Annuller" };

onConfig((config) => {
    if (typeof config.dialog?.confirmLabel === "string" && config.dialog.confirmLabel) dialogLabels.confirm = config.dialog.confirmLabel;
    if (typeof config.dialog?.cancelLabel === "string" && config.dialog.cancelLabel) dialogLabels.cancel = config.dialog.cancelLabel;
});

onAction("dialog:input", (message) => showInputDialog(message.dialog));
onAction("dialog:confirm", (message) => showConfirmDialog(message.dialog));
onAction("dialog:hide", hideDialog);

// Bruges af menu.js: tasterne skal gå til dialogen, ikke til menuen bag den
function isDialogOpen() {
    return currentDialog !== null;
}

function hideDialog() {
    currentDialog = null;
    dialogRoot.hidden = true;
    dialogRoot.replaceChildren();
}

// Sender svaret til Lua - kun én gang pr. dialog (et dobbeltklik må ikke sende to svar)
function answer(data) {
    if (!currentDialog || currentDialog.sent) return;
    currentDialog.sent = true;
    post("dialog:submit", { ...data, id: currentDialog.id });
}

// Rammen: den mørke baggrund, boksen og titlen. Giver boksen tilbage, så resten kan sættes ind i den
function createFrame(dialog, kind) {
    currentDialog = { id: dialog.id, kind, allowCancel: dialog.allowCancel !== false, sent: false };

    const box = document.createElement("div");
    box.className = "dialog";
    box.setAttribute("role", "dialog");
    box.setAttribute("aria-modal", "true");
    if (dialog.danger) box.classList.add("is-danger");

    if (dialog.title) {
        const title = document.createElement("h2");
        title.className = "dialog-title";
        title.id = "dialog-title";
        title.textContent = String(dialog.title);
        box.setAttribute("aria-labelledby", title.id);
        box.append(title);
    }

    const backdrop = document.createElement("div");
    backdrop.className = "dialog-backdrop";
    backdrop.append(box);
    dialogRoot.replaceChildren(backdrop);
    dialogRoot.hidden = false;
    return box;
}

function createButton(text, className, type = "button") {
    const button = document.createElement("button");
    button.type = type;
    button.className = `dialog-button ${className}`;
    button.textContent = text;
    return button;
}

// ---------- "Er du sikker?" ----------

function showConfirmDialog(dialog) {
    if (!dialog || typeof dialog !== "object") return;
    const box = createFrame(dialog, "confirm");

    const body = document.createElement("div");
    body.className = "dialog-body";
    const content = document.createElement("p");
    content.className = "dialog-content";
    content.id = "dialog-content";
    content.textContent = String(dialog.content ?? "");
    body.append(content);
    box.setAttribute("aria-describedby", content.id); // skærmlæsere læser teksten op sammen med titlen

    const actions = document.createElement("div");
    actions.className = "dialog-actions";
    const cancel = createButton(dialog.cancelLabel || dialogLabels.cancel, "is-secondary");
    const confirm = createButton(dialog.confirmLabel || dialogLabels.confirm, dialog.danger ? "is-primary is-danger" : "is-primary");
    cancel.addEventListener("click", () => answer({ confirmed: false }));
    confirm.addEventListener("click", () => answer({ confirmed: true }));
    actions.append(cancel, confirm);

    box.append(body, actions);
    // Ved en farlig handling (danger) har "Annuller" fokus, så et hurtigt tryk på Enter ikke sletter noget
    (dialog.danger ? cancel : confirm).focus();
}

// ---------- Indtastning ----------

function showInputDialog(dialog) {
    if (!dialog || typeof dialog !== "object") return;
    const box = createFrame(dialog, "input");
    const fields = (Array.isArray(dialog.fields) ? dialog.fields : []).map(createField);

    // En rigtig <form>, så Enter i et tekstfelt sender den (det gør browseren selv)
    const form = document.createElement("form");
    form.className = "dialog-form";
    form.noValidate = true; // vi viser selv fejlene (browserens egne bobler passer ikke til designet)

    const body = document.createElement("div");
    body.className = "dialog-body";
    fields.forEach((field) => body.append(field.element));

    const actions = document.createElement("div");
    actions.className = "dialog-actions";
    if (currentDialog.allowCancel) {
        const cancel = createButton(dialog.cancelLabel || dialogLabels.cancel, "is-secondary");
        cancel.addEventListener("click", () => answer({ cancelled: true }));
        actions.append(cancel);
    }
    actions.append(createButton(dialog.confirmLabel || dialogLabels.confirm, "is-primary", "submit"));

    form.append(body, actions);
    form.addEventListener("submit", (event) => {
        event.preventDefault(); // browseren må ikke selv sende formularen (så genindlæses siden)
        let firstInvalid = null;
        fields.forEach((field) => {
            const error = field.validate();
            field.showError(error);
            if (error && !firstInvalid) firstInvalid = field;
        });
        if (firstInvalid) return firstInvalid.focus();
        // Svarene i samme rækkefølge som felterne
        answer({ values: fields.map((field) => field.read()) });
    });

    box.append(form);
    fields[0]?.focus();
}

// Laver ét felt. Giver { element, read(), validate(), showError(), focus() } tilbage
function createField(field, index) {
    field = field && typeof field === "object" ? field : { type: "input", label: "" };
    const id = `dialog-field-${index}`;
    const element = document.createElement("div");
    element.className = "dialog-field";

    const error = document.createElement("p");
    error.className = "dialog-error";
    error.id = `${id}-error`;

    let control;

    if (field.type === "checkbox") {
        const label = document.createElement("label");
        label.className = "dialog-check";
        control = document.createElement("input");
        control.type = "checkbox";
        control.id = id;
        control.checked = field.checked === true;
        const text = document.createElement("span");
        text.textContent = String(field.label ?? "");
        label.append(control, text);
        if (field.required) label.append(createRequiredMark());
        element.append(label);
    } else {
        const label = document.createElement("label");
        label.className = "dialog-label";
        label.htmlFor = id;
        label.textContent = String(field.label ?? "");
        if (field.required) label.append(createRequiredMark());
        element.append(label);

        if (field.description) {
            const description = document.createElement("p");
            description.className = "dialog-description";
            description.id = `${id}-desc`;
            description.textContent = String(field.description);
            element.append(description);
        }

        if (field.type === "textarea") {
            control = document.createElement("textarea");
            control.rows = 4;
        } else if (field.type === "select") {
            control = document.createElement("select");
            // Tom mulighed først, så spilleren selv skal vælge (medmindre der er en standard)
            control.append(new Option(field.placeholder || "Vælg …", ""));
            (Array.isArray(field.options) ? field.options : []).forEach((option) => {
                control.append(new Option(String(option.label ?? option.value), String(option.value)));
            });
        } else {
            control = document.createElement("input");
            control.type = field.type === "number" ? "number" : "text";
            control.autocomplete = "off";
        }
        control.id = id;

        if (field.type === "number") {
            if (Number.isFinite(field.min)) control.min = field.min;
            if (Number.isFinite(field.max)) control.max = field.max;
            control.step = Number.isFinite(field.step) ? field.step : "any";
        }
        if (Number.isInteger(field.maxLength) && field.type !== "select" && field.type !== "number") control.maxLength = field.maxLength;
        if (field.placeholder && field.type !== "select") control.placeholder = String(field.placeholder);
        if (field.default !== undefined && field.default !== null) control.value = String(field.default);
        // En standard, der ikke er en af mulighederne, ville give en tom boks - vis så "Vælg …"
        if (control.tagName === "SELECT" && control.selectedIndex === -1) control.selectedIndex = 0;

        // Ikon inde i feltet (ikke ved tekstbokse, de er for høje)
        const wrap = document.createElement("div");
        wrap.className = "dialog-input-wrap";
        const icon = field.type === "textarea" ? null : createIcon(field.icon);
        if (icon) {
            icon.classList.add("dialog-input-icon");
            wrap.classList.add("has-icon");
            wrap.append(icon);
        }
        wrap.append(control);
        element.append(wrap);
    }

    // Skærmlæsere: beskrivelsen og en evt. fejl læses op sammen med feltet, og påkrævede felter siges som påkrævede
    control.setAttribute("aria-describedby", field.description && field.type !== "checkbox" ? `${id}-desc ${error.id}` : error.id);
    if (field.required) control.setAttribute("aria-required", "true");
    element.append(error);

    return {
        element,
        focus: () => control.focus(),

        // Værdien, som den sendes til Lua
        read() {
            if (field.type === "checkbox") return control.checked;
            if (field.type === "number") return control.value === "" ? null : Number(control.value);
            const value = control.value.trim();
            return value === "" ? null : value;
        },

        // En fejlbesked, eller null hvis feltet er i orden
        validate() {
            if (field.type === "checkbox") return field.required && !control.checked ? "Skal være sat kryds" : null;
            if (field.type === "select") return field.required && !control.value ? "Vælg en mulighed" : null;
            // Et talfelt med noget, der ikke er et tal (fx "1e" eller "-"), har value "" - det må ikke
            // ligne et tomt felt
            if (field.type === "number" && control.validity.badInput) return "Skriv et tal";

            const raw = control.value.trim();
            if (raw === "") return field.required ? "Skal udfyldes" : null;

            if (field.type === "number") {
                const number = Number(raw);
                if (!Number.isFinite(number)) return "Skriv et tal";
                if (Number.isFinite(field.min) && number < field.min) return `Mindst ${field.min}`;
                if (Number.isFinite(field.max) && number > field.max) return `Højst ${field.max}`;
                return null;
            }

            if (Number.isInteger(field.minLength) && raw.length < field.minLength) {
                return `Mindst ${field.minLength} tegn (du har ${raw.length})`;
            }
            return null;
        },

        showError(text) {
            error.textContent = text ?? "";
            if (text) control.setAttribute("aria-invalid", "true");
            else control.removeAttribute("aria-invalid");
        },
    };
}

function createRequiredMark() {
    const mark = document.createElement("span");
    mark.className = "dialog-required";
    mark.textContent = "*";
    mark.setAttribute("aria-hidden", "true");
    return mark;
}

// ---------- Tastaturet ----------

// Escape annullerer (hvis det er tilladt). Enter klarer browseren selv: den sender formularen eller klikker knappen
document.addEventListener("keydown", (event) => {
    if (!currentDialog || event.key !== "Escape") return;
    event.preventDefault();
    if (currentDialog.kind === "confirm") answer({ confirmed: false });
    else if (currentDialog.allowCancel) answer({ cancelled: true });
});
