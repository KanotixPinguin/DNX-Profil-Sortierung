# DNX Profil-Sortierung

<!-- DNX-DISCLAIMER-START -->
> **Wichtiger Hinweis / Vollständige Distanzierung (Hobby-Mod-Mode)**
>
> - **Vollständige Distanzierung:** Ich distanziere mich in jeder Hinsicht vollständig vom Projekt **OpenWebRX / OpenWebRX+** sowie dessen Entwicklern und Betreibern. Es besteht keinerlei Verbindung, Zusammenarbeit, Prüfung, Befürwortung oder Partnerschaft.
> - **Keine öffentlichen/offiziellen OpenWebRX-Plugins (nur Mod-Mode):** Bei diesem Projekt handelt es sich ausdrücklich **nicht** um ein öffentliches oder offizielles Plugin von OpenWebRX, sondern ausschließlich um einen privaten, inoffiziellen **Mod-Mode** (Eigenmodifikation).
> - **Kein öffentlicher Support & keine Haftung:** Es gibt **keinen öffentlichen Support**, keine Garantie und keine Haftung. Nutzung, Installation und Anpassung erfolgen vollständig auf eigene Gefahr (immer vorher Backups anlegen und zunächst im eigenen Testsystem prüfen).
> - **Reines Hobbyprojekt – frei nutzbar, änderbar & verbreitbar:** Dieses Projekt entsteht ausschließlich aus reinem Hobby und Interesse am gemeinsamen Funk-/SDR-Hobby. Es steht ausdrücklich frei zur Verfügung und darf frei genutzt, weiterverbreitet, verändert und verbessert werden.
<!-- DNX-DISCLAIMER-END -->

Bringt das **Profil-Aufklappmenü** des Receivers in eine Reihenfolge:
**von der niedrigsten zur höchsten Frequenz** (aufsteigend).

## Warum

OpenWebRX stellt die Profile so dar, wie sie in der Konfigurationsdatei stehen.
Kommt später ein zweites Gerät dazu, hängen dessen Profile hinten an – und die
Liste beginnt mitten im Spektrum. Auf einem Empfänger mit zwei RTL-Sticks sah das
so aus:

```
vorher:
   1. 🔴 📻 30-32 MHz      (31,0 MHz)   ← Liste beginnt hier
   2. 🔴 📻 32-34 MHz      (33,0 MHz)
   ...
 897. 🔴 📻 1748-1750 MHz  (1749 MHz)
 898. 🟢🎙️ CB-Funk         (27,0 MHz)   ← erst jetzt das HF-Gerät
 899. 🟡📡 HAM 10m         (28,85 MHz)  ← danach rein alphabetisch
 ...
 948. 🔴 ⚠ VLF 3-30 kHz   (0,125 MHz)  ← die tiefste Frequenz am Ende
```

```
nachher:
   1. 🔴 ⚠ ULF 0.3-3 kHz   (0,125 MHz)
   2. 🔴 ⚠ VLF 3-30 kHz    (0,125 MHz)
   3. 🔴 ⚠ LF 30-100 kHz   (0,125 MHz)
   4. 🔴 🌍 LF 100-150 kHz  (0,225 MHz)
   ...
 948. 🔴 📻 1748-1750 MHz  (1749 MHz)
```

## Was es tut

- liest die Frequenzen aus `static/plugins/wf_profiles.json` – derselben Datei,
  die auch die DNX-Profiltabelle (Knopf **☰ Profile**) nutzt
- ordnet die Einträge im Menü aufsteigend nach Frequenz
- Profile ohne bekannten Frequenz-Eintrag wandern ans Ende
- die gerade gewählte Auswahl bleibt erhalten
- wird neu sortiert, sobald der Receiver die Liste neu aufbaut

## Änderungen

**v1.0.1** – bei gleicher Mittenfrequenz wird nach der Unterkante sortiert (ULF 0,3–3 kHz
vor VLF 3–30 kHz vor LF 30–100 kHz; in den Profilen stehen alle drei auf 125 kHz).

## Was es nicht tut

- **keine** Änderung an `settings.json` oder an den Profilen selbst
- **kein** Eingriff in Rechte: ist das Menü für eine Rolle gesperrt, bleibt es gesperrt
- die **DNX-Profiltabelle** bleibt unberührt – sie sortiert selbst (Klick auf die
  Kopfzeile „Frequenz" schaltet zwischen ▲ aufsteigend und ▼ absteigend um)

## Installation

```bash
chmod +x install.sh
sudo ./install.sh install
```

Der Installer findet das Plugin-Verzeichnis auf drei Wegen – **Docker ist nicht nötig**:

```bash
sudo PLUGINS=/pfad/zu/plugins ./install.sh install   # direkt, ohne Docker
sudo CONTAINER=owrx-8013 ./install.sh install        # Mountpunkt aus Docker
sudo ./install.sh install                            # Standardsuche
sudo NORESTART=1 ./install.sh install                # ohne Neustart
```

Prüfen, aktualisieren, entfernen:

```bash
./install.sh status
sudo ./install.sh update
sudo ./install.sh uninstall
```

## Was wird verändert?

1. `<plugins>/receiver/dnx_profil_sort.js` – die Sortierung
2. `<plugins>/receiver/init.js` – ein eigener Loader-Block zwischen
   `/* DNX_PROFIL_SORT_START */` und `/* DNX_PROFIL_SORT_END */`
   (eigene Marke, damit das FT8-Paket unangetastet bleibt)

`init.js` wird vorher unter `/opt/dnx-profil-sortierung-backups/<Zeitpunkt>/`
gesichert. `uninstall` nimmt den Block heraus und löscht die Datei – restlos.

## Hinweise

- Die Sortierung gilt für **alle** Rollen; sie ändert nur die Reihenfolge, nicht
  die Bedienbarkeit.
- Neue Profile werden automatisch einsortiert, sobald sie in
  `wf_profiles.json` eine Frequenz haben. Fehlt dort ein Eintrag, landet das
  Profil am Ende – dann einfach einmal in der Profiltabelle umschalten, damit
  die Metadaten ergänzt werden.

## Hinweis

Private, inoffizielle Hobby-Anpassung; kein offizielles OpenWebRX-/OpenWebRX+-Projekt.
Nutzung auf eigene Gefahr; soweit gesetzlich zulässig keine Haftung. Vorher Backups erstellen.
