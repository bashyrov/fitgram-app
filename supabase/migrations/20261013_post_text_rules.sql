-- Server-side copy of the post text rules.
--
-- The app checks titles and bodies in PostContentPolicy.swift (links,
-- control characters, repeated characters, profanity in PL / EN / UK / RU /
-- ES), but a direct API call skipped all of that. The same rules now run in
-- a trigger. They are never stricter than the app, so a post the composer
-- accepts is accepted here too. Keep the word lists in sync with
-- PostContentPolicy.swift.
--
-- Rejections raise "post text violates check constraint: <reason>", which
-- the app already maps to its "content rejected" message.
--
-- Run after 20261012_social_hardening.sql. Safe to re-run.

-- Lowercase, strip diacritics, undo leetspeak, drop non-letters and collapse
-- repeated letters ("fuuuck" → "fuck"). Mirrors PostContentPolicy.normalize.
create or replace function public.normalize_post_word(word text)
returns text language sql immutable as $$
    select regexp_replace(
        regexp_replace(
            translate(
                lower(word),
                'łąćęńóśźżáéíúüñàèìòùâêîôûäëïöçйёї013457@$!',
                'lacenoszzaeiuunaeiouaeiouaeiocиеіoieastasi'
            ),
            '[^a-zа-яієґ]', '', 'g'
        ),
        '(.)\1+', '\1', 'g'
    );
$$;

-- The first broken rule, or null when the text can be published.
create or replace function public.post_text_violation(p_title text, p_body text)
returns text language plpgsql stable as $$
declare
    title text := btrim(coalesce(p_title, ''), E' \t\n\r');
    body text := btrim(coalesce(p_body, ''), E' \t\n\r');
    combined text;
    lowered text;
    anywhere text[];
    prefixes text[];
    whole text[];
    allowed text[];
    token text;
    variant text;
    word text;
    stem text;
begin
    combined := title || E'\n' || body;
    lowered := lower(combined);

    if title ~ '[\n\r]' then
        return 'title_multiline';
    end if;
    if length(body) - length(replace(body, E'\n', '')) > 12 then
        return 'too_many_lines';
    end if;
    if combined ~ '[\x01-\x09\x0B-\x1F\x7F​‌‎‏‪-‮⁠-⁩﻿]' then
        return 'forbidden_characters';
    end if;
    if combined ~ '(\S)\1{6,}' then
        return 'repeated_characters';
    end if;
    if lowered ~ 'https?://|www\.'
        or lowered ~ '\m[a-z0-9-]{2,}\.(com|pl|net|org|io|ru|ua|es|eu|me|ly|gg|tv|app|xyz|info|shop)\M'
    then
        return 'links';
    end if;

    select array_agg(public.normalize_post_word(w)) into anywhere from unnest(array[
        -- Polish
        'kurw', 'chuj', 'pierdol', 'pierdal', 'jebac', 'jeban', 'jebie', 'jebn', 'zajeb', 'wyjeb', 'pojeb',
        'przejeb', 'odjeb', 'rozjeb', 'skurwy', 'skurwi', 'pizd', 'kutas', 'cipsk', 'dziwk', 'zjeb', 'huj',
        'sukinsyn',
        -- English
        'fuck', 'shit', 'bitch', 'cunt', 'asshol', 'motherf', 'nigg', 'fagot', 'whore', 'slut', 'bastard',
        'dickhead', 'wanker',
        -- Russian / Ukrainian (folded: й → и, ё → е)
        'хуи', 'хуе', 'хуя', 'пизд', 'заеб', 'выеб', 'проеб', 'наеб', 'доеб', 'отъеб', 'бляд', 'блят',
        'мудак', 'мудил', 'пидор', 'пидар', 'залуп', 'гандон', 'шлюх', 'дроч', 'пізд',
        -- Spanish
        'mierd', 'cabron', 'joder', 'gilipoll', 'pendej', 'chinga', 'culero'
    ]) w;
    -- Only at the start of a word: they hide inside innocent words otherwise.
    select array_agg(public.normalize_post_word(w)) into prefixes from unnest(array[
        'puta', 'puto', 'verga', 'cwel', 'ебат', 'ебан', 'ебал', 'ебло', 'ебу', 'уеб', 'сука', 'суки', 'хер',
        'педик'
    ]) w;
    select array_agg(public.normalize_post_word(w)) into whole from unnest(array[
        'dick', 'cock', 'fag', 'бля', 'еба', 'ебл'
    ]) w;
    -- Real words that start with a flagged prefix.
    select array_agg(public.normalize_post_word(w)) into allowed from unnest(array[
        'херсон', 'херсона', 'херсоні', 'херсоне', 'херес', 'херувим', 'сукин', 'сукно', 'scunthorpe', 'shitake',
        'verganza'
    ]) w;

    for token in select regexp_split_to_table(combined, '\s+') loop
        -- "f*ck" / "sh*t": try the masked letter as each vowel.
        for variant in
            select unnest(
                case when position('*' in token) > 0
                    then array[
                        replace(token, '*', 'a'), replace(token, '*', 'e'), replace(token, '*', 'i'),
                        replace(token, '*', 'o'), replace(token, '*', 'u')]
                    else array[token]
                end)
        loop
            word := public.normalize_post_word(variant);
            continue when word = '' or word = any(allowed);
            if word = any(whole) then
                return 'profanity';
            end if;
            foreach stem in array anywhere loop
                if position(stem in word) > 0 then
                    return 'profanity';
                end if;
            end loop;
            foreach stem in array prefixes loop
                if left(word, length(stem)) = stem then
                    return 'profanity';
                end if;
            end loop;
        end loop;
    end loop;
    return null;
end;
$$;

-- Inserts made from the SQL editor (no JWT) skip the check, like the other
-- post rules, so demo data can be seeded.
create or replace function public.enforce_post_text()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    reason text;
begin
    if auth.uid() is null then
        return new;
    end if;
    reason := public.post_text_violation(new.title, new.body);
    if reason is not null then
        raise exception 'post text violates check constraint: %', reason using errcode = 'P0001';
    end if;
    return new;
end;
$$;

drop trigger if exists posts_enforce_text on public.posts;
create trigger posts_enforce_text
    before insert on public.posts
    for each row execute function public.enforce_post_text();
