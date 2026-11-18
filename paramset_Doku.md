# paramset.sh – Verwaltung der IDMC-Parameterdatei ps_Global.params

<!-- Confluence: Seite für Bereich "IDMC / Paramset" – Version 1.0 -->

## 1. Übersicht

`paramset.sh` pflegt die hardcodierte IDMC-Parameterdatei
`/home/Larve/IDMC/Paramsetcli/EDWH_Paramset-example/ps_Global.params`.

Die Datei verwaltet Parameter auf zwei Ebenen:

* **[GLOBAL]** – globale Parameter, die für alle Workflows gelten.
* **Taskflow-Sections** – parameter pro Taskflow. Der Section-Header folgt dem Schema
  `[Projekt].[Folder].[Taskflow]`, z. B. `[MIG_DWH].[DWH_KE].[tf_KE_Person]`.

Das Skript unterstützt genau zwei Aktionen:

* **`add`** – Parameter in einer Section hinzufügen oder überschreiben.
* **`delete`** – Parameter aus einer Section entfernen.

Wichtige Rahmenbedingungen:

* Es wird **nur die lokale Datei** gepflegt. Es finden **keine `paramsetcli`-Aufrufe** statt.
* Es wird **kein Logfile** geschrieben. Die Ausgabe erfolgt ausschließlich auf der Shell.
* Vor jeder tatsächlichen Änderung wird automatisch eine Sicherungskopie
  `ps_Global.params.bak` erstellt (überschreibt die vorherige Sicherung).
* Das `$`-Präfix des Parameternamens (`$$Name`) wird vom Skript automatisch ergänzt –
  im Aufruf wird der Name **ohne** `$$` übergeben.

---

## 2. Dateistruktur der Parameterdatei

```
[GLOBAL]
$$SOURCE_OWNER=ENTW100
$$ODS_OWNER=DW2EO
$$DBConnection_DWH=PWX_DB2390_DWH

[MIG_DWH].[DWH_KE].[tf_KE_Person]
$$DWH_EBENE=KE
$$TABELLE=K_PERSON
$$THEMENBLOCK=2
$$DATENSCHUTZ=11

[MIG_DWH].[DWH_KE].[tf_KE_MktgStatNutzung]
$$DWH_EBENE=KE
$$THEMENBLOCK=3
```

Regeln:

* Eine Parameterzeile hat das Format `$$Name=Value` (per Skript ohne Anführungszeichen).
* Sections sind durch Zeilen der Form `[...]` getrennt; zwischen den Sections steht eine Leerzeile.
* Existiert die Taskflow-Section noch nicht, legt `add` sie **am Dateiende** neu an.
* Ist nach einem `delete` der letzte Parameter einer Taskflow-Section gelöscht, wird die
  komplette Section inklusive Header entfernt. Die Section `[GLOBAL]` bleibt grundsätzlich bestehen.
* Windows-Zeilenumbrüche (CRLF) werden erkannt und beim Zurückschreiben beibehalten.
* **Hinweis:** Bei mehrfach vorhandenen Sections mit identischem Header wird immer die
  **erste** gefundenen Section bearbeitet.

---

## 3. Aufruf und Optionen

```
paramset.sh -a <add|delete> -s <Global|Taskflow> -pn <Parametername> -pv <Parameterwert>
            [-p <Projekt> -f <Folder> -tfn <Taskflowname>] [-force]
```

| Option | Langform | Beschreibung | Pflicht |
|--------|----------|--------------|---------|
| `-a` | `-action` | Aktion: `add` oder `delete` | immer |
| `-s` | – | Section-Typ: `Global` oder `Taskflow` (Groß-/Kleinschreibung egal) | immer |
| `-p` | – | Projekt in der IDMC | nur bei `-s Taskflow` |
| `-f` | – | Folder in der IDMC | nur bei `-s Taskflow` |
| `-tfn` | – | Vollständiger Taskflowname | nur bei `-s Taskflow` |
| `-pn` | – | Parametername, z. B. `DBConnection_DWH` (ohne `$$`) | immer |
| `-pv` | – | Parameterwert | immer |
| `-force` | – | Nur bei `-a add`: abweichenden Wert ohne Rückfrage überschreiben | optional |
| `-h` | `--help` | Hilfe anzeigen | – |

**Pflichtkombinationen:**

* `-s Global` → `-a`, `-s`, `-pn`, `-pv`
* `-s Taskflow` → `-a`, `-s`, `-p`, `-f`, `-tfn`, `-pn`, `-pv`
* `-force` ist nur in Kombination mit `-a add` erlaubt.

---

## 4. Verhalten der Aktion `add`

### 4.1 Neuer Parameter (Variante A)

Der Parameter existiert in der Section noch nicht. Er wird im Format
`$$Name=Value` an die Section angehängt, mit Erhalt der Leerzeile zwischen den Sections.

```
$ paramset.sh -a add -s Global -pn DBConnection_NEU -pv PWX_DB2390_NEU
Sicherungskopie '/home/Larve/IDMC/Paramsetcli/EDWH_Paramset-example/ps_Global.params.bak' erstellt.
Parameter '$$DBConnection_NEU=PWX_DB2390_NEU' wurde an Section [GLOBAL] angehängt.
```

Existiert die Taskflow-Section noch nicht:

```
$ paramset.sh -a add -s Taskflow -p NEU_PROJ -f NEU_FLD -tfn tf_NEU -pn W1 -pv X1
Sicherungskopie '...' erstellt.
Section [NEU_PROJ].[NEU_FLD].[tf_NEU] existierte nicht und wurde am Ende der Datei angelegt.
Parameter '$$W1=X1' wurde in Section [NEU_PROJ].[NEU_FLD].[tf_NEU] angehängt.
```

### 4.2 Parameter vorhanden, abweichender Wert (Variante B)

Der Parameter existiert in der Section, aber mit anderem Wert:

* **Ohne `-force`** – Abbruch mit Fehler (Exit 1), keine Dateiänderung:

```
Der Parameter -pn "$$DBConnection_DWH" existiert in der angegebenen Section [GLOBAL] bereits,
weist aber den Wert -pv "PWX_DB2390_DWH" auf und nicht den Wert "PWX_DB2390_NEU" wie im Aufruf beschrieben.
Wenn Sie diesen überschreiben möchten, fügen Sie Ihrem letzten Command bitte ein -force hinzu
und führen Sie ihn erneut aus.
```

* **Mit `-force`** – Wert wird direkt überschrieben:

```
$ paramset.sh -a add -s Taskflow -p MIG_DWH -f DWH_KE -tfn tf_KE_Person -pn TABELLE -pv K_ADRESSE -force
Parameter '$$TABELLE' wurde in Section [MIG_DWH].[DWH_KE].[tf_KE_Person] mit -force von 'K_PERSON' auf 'K_ADRESSE' überschrieben.
```

### 4.3 Parameter vorhanden, identischer Wert (Variante C)

Es wird nichts geändert (Exit 0), auch **kein Backup** erstellt:

```
Der Parameter '$$DBConnection_DWH' existiert in Section [GLOBAL] bereits genau so wie angegeben, es wurde nichts geändert.
```

---

## 5. Verhalten der Aktion `delete`

Der Aufruf folgt demselben Schema wie `add`; `-pv` ist auch hier Pflicht.
`-force` ist bei `delete` nicht erlaubt.

### 5.1 Parameter existiert exakt (Variante A)

Name **und** Wert stimmen überein → Zeile wird aus der Datei gelöscht.
Bleibt die Section danach leer (nur bei Taskflow-Sections), wird sie komplett entfernt:

```
$ paramset.sh -a delete -s Taskflow -p MIG_DWH -f DWH_KE -tfn tf_KE_Person -pn TABELLE -pv K_PERSON
Sicherungskopie '...' erstellt.
Parameter '$$TABELLE=K_PERSON' wurde aus Section [MIG_DWH].[DWH_KE].[tf_KE_Person] gelöscht.
```

### 5.2 Parameter existiert mit anderem Wert (Variante B)

Abbruch mit Fehler (Exit 1), keine Dateiänderung:

```
Fehler: Der Parameter '$$TABELLE' existiert in der angegebenen Section [MIG_DWH].[DWH_KE].[tf_KE_Person],
weist aber einen anderen Value ('K_ADRESSE') auf. Bitte kontrollieren Sie den Aufruf.
```

### 5.3 Parameter existiert nicht (Variante C)

Es wird nichts geändert (Exit 0), auch kein Backup:

```
Der Parameter '$$TABELLE' existiert nicht, keine Aktion wird durchgeführt.
```

Das gilt auch, wenn die Section (insbesondere der Taskflow) gar nicht existiert.

---

## 6. Wichtig: Quoting von `-pn` und `-pv`

`-pn` und `-pv` müssen **immer in Anführungszeichen** übergeben werden.
Die Shell entfernt die Quotes vor dem Skriptstart; erkennbar sind nur ihre Folgen.

### 6.1 Das `$$`-Problem

Ein **unquotiertes** `$$` wird von der Shell durch ihre Prozess-ID ersetzt:

```
$ paramset.sh -a add -s Global -pn $$DBConnection_DWH -pv PWX_DB2390_DWH
Fehler: Ungültiger Parametername '2048DBConnection_DWH' - -pn wurde vermutlich nicht quotiert übergeben.
Ursache: Ein unquotiertes $$ in -pn wird von der Shell durch ihre Prozess-ID ersetzt,
aus -pn $$DBConnection_DWH wird so -pn 2048DBConnection_DWH.
```

Wichtig: Auch wenn der Befehl „falsch" aussieht, kann die Shell `$$DBConnection_DWH`
**vor** der Ausführung zu `2048DBConnection_DWH` auflösen – genau dieser Fall wird vom
Skript abgefangen, damit kein verfälschter Parameter wie `2048DBConnection_DWH` in der
Datei landet.

### 6.2 Korrekte Aufrufe

Richtig ist eine der beiden Varianten:

```
paramset.sh -a add -s Global -pn DBConnection_DWH -pv PWX_DB2390_DWH          # ohne $$, empfohlen
paramset.sh -a add -s Global -pn '$$DBConnection_DWH' -pv PWX_DB2390_DWH      # $$ in einfachen Quotes
```

Falsch:

```
paramset.sh -a add -s Global -pn $$DBConnection_DWH -pv PWX_DB2390_DWH        # $$ → Prozess-ID
```

### 6.3 Werte mit Leerzeichen oder Sonderzeichen

Werte, die Leerzeichen, `=`-Zeichen oder Shell-Sonderzeichen enthalten, müssen ebenfalls
quotiert werden, sonst zerfällt der Wert in mehrere Argumente:

```
paramset.sh -a add -s Global -pn DB_DEBUG_FLATFILE_OUTPUT -pv '1=0'
```

---

## 7. Backup-Verhalten

* Vor **jeder tatsächlichen Änderung** der Datei wird `ps_Global.params.bak` angelegt
  (eine bereits vorhandene `.bak` wird überschrieben).
* Bei `add` (identisch) und `delete` (nicht gefunden) – also wenn nichts geändert wird –
  wird **kein** Backup erstellt.
* Die `.bak`-Datei erlaubt es, eine versehentliche Änderung einfach zurückzuspielen:
  `cp ps_Global.params.bak ps_Global.params`

---

## 8. Exit-Codes

| Code | Bedeutung |
|------|-----------|
| 0 | Aktion erfolgreich (auch „nichts zu tun" bei identischem Parameter bzw. nicht vorhandenem Parameter) |
| 1 | Fehler (z. B. fehlende Optionen, abweichender Wert ohne `-force`, ungültiger Parametername, Datei nicht gefunden) |

---

## 9. Beispiele

### Globalen Parameter hinzufügen

```
paramset.sh -a add -s Global -pn DBConnection_NEU -pv PWX_DB2390_NEU
```

### Taskflow-Parameter hinzufügen (Section wird bei Bedarf neu angelegt)

```
paramset.sh -a add -s Taskflow -p MIG_DWH -f DWH_KE -tfn tf_KE_Person -pn TABELLE -pv K_PERSON
```

### Taskflow-Parameter überschreiben

```
paramset.sh -a add -s Taskflow -p MIG_DWH -f DWH_KE -tfn tf_KE_Person -pn TABELLE -pv K_ADRESSE -force
```

### Globalen Parameter löschen

```
paramset.sh -a delete -s Global -pn DBConnection_NEU -pv PWX_DB2390_NEU
```

### Taskflow-Parameter löschen

```
paramset.sh -a delete -s Taskflow -p MIG_DWH -f DWH_KE -tfn tf_KE_Person -pn TABELLE -pv K_PERSON
```

### Hilfe anzeigen

```
paramset.sh -h
```

---

## 10. Fehlermeldungen im Überblick

| Situation | Verhalten |
|-----------|-----------|
| Option fehlt (z. B. `-pn` leer) | Fehler + Hinweis (Exit 1) |
| Ungültiger Parametername (z. B. `2048DBConnection_DWH` durch unquotiertes `$$`) | Fehler mit Ursachen-Hinweis (Exit 1) |
| `-a` nicht `add`/`delete` | Fehler (Exit 1) |
| `-s` nicht `Global`/`Taskflow` | Fehler (Exit 1) |
| `-s Taskflow` ohne `-p`/`-f`/`-tfn` | Fehler (Exit 1) |
| `-force` mit `-a delete` | Fehler (Exit 1) |
| `add`: Parameter vorhanden, abweichender Wert, ohne `-force` | Fehler mit Hinweis auf `-force` (Exit 1) |
| `add`: Parameter vorhanden, identisch | Info, nichts geändert (Exit 0) |
| `add`: Section `[GLOBAL]` fehlt | Fehler (Exit 1) |
| `add`: Taskflow-Section fehlt | Section wird am Dateiende neu angelegt (Exit 0) |
| `delete`: Parameter mit anderem Wert vorhanden | Fehler mit Hinweis (Exit 1) |
| `delete`: Parameter nicht vorhanden | Info, nichts geändert (Exit 0) |
| Parameterdatei nicht gefunden | Fehler (Exit 1) |
