# Paramset.sh

Werkzeuge zur Verwaltung von Parameterdateien und Parametersets für **IDMC**
(Informatica Intelligent Data Management Cloud).

Das Repository enthält aktuell das Pflege-Skript `paramset.sh` und soll künftig um ein
Commandline-Tool erweitert werden, das die Nutzung von Parametersets und deren lokale
Handhabung weiter vereinfacht.

---

## Aktueller Stand

### `paramset.sh` – Pflege der Parameterdatei `ps_Global.params`

Shell-Skript zur Verwaltung der hardcodierten IDMC-Parameterdatei

```
/home/Larve/IDMC/Paramsetcli/EDWH_Paramset-example/ps_Global.params
```

Die Datei verwaltet Parameter auf zwei Ebenen:

| Section | Aufbau | Zweck |
|---------|--------|-------|
| `[GLOBAL]` | Liste von `$$Name=Value` | globale Parameter für alle Workflows |
| `[Projekt].[Folder].[Taskflow]` | Liste von `$$Name=Value` | Parameter pro Taskflow |

Das Skript unterstützt zwei Aktionen:

* **`add`** – Parameter hinzufügen; bei abweichendem bestehenden Wert überschreiben
  (nur mit `-force`), sonst kontrollierter Abbruch mit Fehlermeldung.
* **`delete`** – Parameter entfernen; nur bei exakter Übereinstimmung von Name **und** Wert,
  sonst Abbruch mit Fehler bzw. Hinweis ohne Änderung.

Eckdaten:

* Lokale Dateipflege mit automatischem IDMC-Upload: nach jeder Änderung wird das
  Parameterset per `paramsetcli` (`-a upload -f`) hochgeladen; kein Logfile.
* Das `$$`-Präfix des Parameternamens wird automatisch ergänzt.
* Vor jeder tatsächlichen Änderung wird eine Sicherungskopie `ps_Global.params.bak` erstellt.
* CRLF/LF-Zeilenenden werden erkannt und beim Zurückschreiben beibehalten

Kurzübersicht:

```
paramset.sh -a <add|delete> -s <Global|Taskflow> -pn <Parametername> -pv <Parameterwert>
            [-p <Projekt> -f <Folder> -tfn <Taskflowname>] [-force]
```

> **Wichtig:** `-pn` und `-pv` immer quotiert übergeben. Ein unquotiertes `$$` wird von der
> Shell durch ihre Prozess-ID ersetzt (aus `-pn $$Name` wird `-pn 2048Name`) und führt zu
> ungültigen Parameternamen.

---

## Dokumentation

Ausführliche Anleitungen liegen im Repository:

* [`paramset_Doku.md`](paramset_Doku.md) – Markdown-Fassung (GitHub)
* [`paramset_Doku_wiki.txt`](paramset_Doku_wiki.txt) – Confluence Wiki Markup
  (Confluence: *Einfügen → Markup → Confluence Wiki*), deckt Optionen, alle add/delete-Varianten,
  Quoting-Regeln, Backup-Verhalten, Exit-Codes und Fehlermeldungen ab.

Beispiel-Parameterdateien liegen unter [`EDWH_Paramset-example/`](EDWH_Paramset-example/).

---

## Geplant: Commandline Tool

Ziel ist ein eigenständiges Commandline-Tool, das die Nutzung von Parametersets und deren
lokale Handhabung vereinfacht und `paramset.sh` langfristig ablöst bzw. ergänzt.

Gedachte Funktionen:

* Verwaltung **mehrerer** `.params`-Dateien statt nur einer hardcodierten Datei
* Anlegen, Ändern, Löschen und Vergleichen (Diff) von Parametern über Sections hinweg
* Validierung von Parameterdateien (Namenskonventionen, Duplikate, Struktur)
* Erweiterte IDMC-Anbindung via `paramsetcli` (Update/List/Sync; der automatische
  Upload nach Änderung ist in `paramset.sh` bereits umgesetzt)
* Einheitliche Hilfe, Exit-Codes und Fehlerausgaben

Status: **geplant** – Vorschläge und Anforderungen willkommen.

---

## Repository-Struktur

```
.
├── paramset.sh                    # Pflege-Skript für ps_Global.params
├── paramset_Doku.md               # Benutzerdokumentation (Markdown)
├── paramset_Doku_wiki.txt         # Benutzerdokumentation (Confluence Wiki Markup)
└── EDWH_Paramset-example/         # Beispiel-Parameterdateien
    └── ps_Global.params
```

---

## Mitwirken

Änderungen bitte über Issues oder Pull Requests vorschlagen. Vor dem Einreichen:

1. Skript mit `bash -n paramset.sh` syntax-prüfen.
2. Verhalten an einer Kopie der Parameterdatei testen – nicht direkt an den Beispieldateien.
