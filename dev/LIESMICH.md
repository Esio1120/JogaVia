# Entwicklungswerkzeuge

`werkzeuge.tgz.b64` ist ein Basis64-kodiertes tar.gz mit den Werkzeugen, die zum Weiterbauen
an JogaVia gebraucht werden. Es gehoert nicht zur App und wird von der Seite nicht geladen.

## Wiederherstellen

```bash
mkdir -p /home/claude/app && cd /home/claude/app
curl -sS -o index.html https://raw.githubusercontent.com/Esio1120/JogaVia/main/index.html
cp index.html deployed.html
curl -sS https://raw.githubusercontent.com/Esio1120/JogaVia/main/dev/werkzeuge.tgz.b64 \
  | base64 -d | tar xz
```

Pruefsumme des entpackten Archivs: `29d3bbd13793cd7b8e00d42572320089`

## Inhalt

| Datei | Zweck |
|---|---|
| `stubs.js` | nachgebautes MapLibre und nachgebauter Supabase-Client fuer die Tests |
| `gensql.py` | erzeugt aus `deployed.html` und `index.html` die minimalen Ersetzungen |
| `tabtest.js` … `teamtest.js` | elf Playwright-Tests, alle gruen am 4.9.2026 |
| `smoke.js` | ueberholt, stammt aus der Zeit vor der Reiterleiste |

Die Testskripte erwarten die App unter `file:///home/claude/app/index.html`.

Dieselben Dateien liegen auch in der Datenbanktabelle `dev_files`.
Vollstaendige Anleitung: Projektdokument `claude/jogavia-uebergabe.md`.
