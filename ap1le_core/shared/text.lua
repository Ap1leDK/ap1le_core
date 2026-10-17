-- Små teksthjælpere, som alle moduler i core bruger (notifikationer, menuer, dialoger).
-- Globale i dette script (hvert FiveM-script har sine egne globale variabler, så de lækker ikke ud til andre)

-- Kun tekst og tal kan vises. Alt andet (fx en tabel eller nil) bliver til tom tekst
function ToText(value)
    if type(value) == 'string' or type(value) == 'number' then return tostring(value) end
    return ''
end

-- Klipper en tekst, så den højst er max tegn lang (inkl. "…" til sidst, hvis den blev klippet).
-- utf8-funktionerne tæller rigtige tegn, så "æ", "ø" og "å" ikke bliver klippet midt over
-- (de fylder 2 bytes hver, og en almindelig :sub tæller bytes)
function CutText(text, max)
    local length = utf8.len(text)
    if not length then
        -- Ugyldig tekst (forkert kodning): klip på bytes, og fjern et halvt tegn, hvis der står et til sidst
        return (text:sub(1, max):gsub('[\192-\255][\128-\191]*$', ''))
    end
    if length <= max then return text end
    -- max - 1 tegn + "…" = max tegn i alt
    return text:sub(1, utf8.offset(text, max) - 1) .. '…'
end

-- Et Font Awesome-ikon som CSS-klasser. Man kan skrive det kort eller langt:
--   'car' / 'fa-car'  ->  'fa-solid fa-car'
--   'fa-brands fa-discord' bruges som det er
-- Kun bogstaver, tal, '-' og mellemrum er tilladt, så et ikon-navn aldrig kan lave rod i HTML'en. Ugyldigt = nil
function ToIcon(icon)
    if type(icon) ~= 'string' or icon == '' or #icon > 60 then return nil end
    if not icon:match('^[%w%- ]+$') then return nil end
    if not icon:find('fa%-') then return 'fa-solid fa-' .. icon end
    if not icon:find(' ') then return 'fa-solid ' .. icon end
    return icon
end
