-- JogaVia: Archivierte Datenbankfunktion
-- Holt Parkfotos von Wikimedia Commons und traegt sie mit Lizenzangabe ein.
-- Am 04.09.2026 aus der Datenbank entfernt, nachdem der Import abgeschlossen war
-- (2.307 Bilder zu 286 Plaetzen). Grund: Sie kann ins Netz, und ungenutzte
-- Netzfaehigkeit ist unnoetige Angriffsflaeche.
--
-- Zurueckholen: dieses SQL wieder ausfuehren. Danach die Rechte pruefen:
--   revoke all on function public.commons_holen(integer) from public, anon, authenticated;
--
-- Hinweis fuer spaeter: Wikimedia verlangt einen eigenen User-Agent, sonst kommt HTML
-- statt JSON zurueck. Umlaute vorher URL-kodieren.

CREATE OR REPLACE FUNCTION public.commons_holen(p_limit integer DEFAULT 30)
 RETURNS TABLE(verarbeitet integer, gefunden integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v record;
  antwort jsonb;
  s jsonb;
  n_v int := 0;
  n_f int := 0;
  ok int;
  bezirke text := '^(Innere Stadt|Leopoldstadt|Landstraße|Wieden|Margareten|Mariahilf|Neubau|Josefstadt|Alsergrund|Favoriten|Simmering|Meidling|Hietzing|Penzing|Rudolfsheim-Fünfhaus|Ottakring|Hernals|Währing|Döbling|Brigittenau|Floridsdorf|Donaustadt|Liesing)$';
begin
  for v in
    select venues.id,
      regexp_replace(regexp_replace(venues.name, '^(Käfig|Fußballplatz|Ballspielplatz|Halle|Sportplatz|Grünanlage|Parkanlage)\s+', ''), '\s+\d+$', '') as park,
      ST_Y(venues.geo::geometry) as lat, ST_X(venues.geo::geometry) as lon
    from public.venues
    where not exists (select 1 from public.commons_lauf c where c.venue_id = venues.id)
    order by venues.id
    limit p_limit
  loop
    n_v := n_v + 1;
    ok := 0;

    if char_length(v.park) >= 5 and v.park !~ bezirke then
      begin
        antwort := ((extensions.http((
          'GET',
          'https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=geosearch'
          || '&ggscoord=' || v.lat || '%7C' || v.lon
          || '&ggsradius=250&ggslimit=40&ggsnamespace=6'
          || '&prop=imageinfo&iiprop=url%7Cextmetadata&iiurlwidth=480'
          || '&iiextmetadatafilter=Artist%7CLicenseShortName%7CLicenseUrl',
          array[extensions.http_header('User-Agent','JogaVia/1.0 (https://esio1120.github.io/JogaVia/)')],
          null, null)::extensions.http_request)).content)::jsonb;
      exception when others then
        antwort := null;
      end;

      if antwort is not null and antwort ? 'query' then
        for s in select p.value from jsonb_each(antwort->'query'->'pages') p loop
          if (s->>'title') ilike '%' || v.park || '%'
             and (s->'imageinfo'->0->>'thumburl') is not null then
            insert into public.venue_bilder_extern
              (venue_id, titel, vorschau, gross, urheber, lizenz, lizenz_url, seite, sortierung)
            values (
              v.id,
              s->>'title',
              s->'imageinfo'->0->>'thumburl',
              s->'imageinfo'->0->>'url',
              nullif(btrim(regexp_replace(coalesce(s->'imageinfo'->0->'extmetadata'->'Artist'->>'value',''), '<[^>]+>', '', 'g')), ''),
              s->'imageinfo'->0->'extmetadata'->'LicenseShortName'->>'value',
              s->'imageinfo'->0->'extmetadata'->'LicenseUrl'->>'value',
              s->'imageinfo'->0->>'descriptionurl',
              coalesce((s->>'index')::int, 0)
            )
            on conflict (venue_id, titel) do nothing;
            ok := ok + 1;
          end if;
        end loop;
      end if;
    end if;

    insert into public.commons_lauf (venue_id, treffer) values (v.id, ok)
      on conflict (venue_id) do update set geholt_am = now(), treffer = excluded.treffer;
    n_f := n_f + ok;
  end loop;
  return query select n_v, n_f;
end
$function$
;
