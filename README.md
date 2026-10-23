# Flip 7 Counter

Kleine Mac-App zum Mitzählen bei [Flip 7](https://www.kosmos.de/de/flip-7_1685430_4002051685430). Rundenpunkte werden angesagt statt im Kopf addiert.

## Bedienung

- **Neues Spiel:** Die Spieler der letzten Partie sind vorausgewählt. Mit einem Klick auf einen Namen fliegt er raus. Weitere Namen tippen oder Leertaste halten und ansagen, z. B. „Kasimir und Bruno hinzufügen, Mathilda raus“. Füllwörter werden ignoriert, neue Namen nur übernommen, wenn die Erkennung sie großschreibt.
- **Runde erfassen:** Leertaste halten und sagen: „Max 5, Oskar 0, Mila 26“. Die Werte erscheinen als Entwurf und lassen sich per Klick korrigieren. **↩** bucht die Runde. Wer nicht genannt wurde, bekommt `–` (0 Punkte).
  - Namen und Zahlen dürfen verschiedene Leute sagen: „Mila“ – Mila antwortet „26“.
  - „Oskar und Mila 26“ gibt beiden 26 Punkte. Ohne „und“ bekommt nur der letzte Name die Zahl.
  - „null“, „verzockt“ und „raus“ zählen als 0.
- **Spielende:** Hat am Ende einer Runde jemand die Zielpunktzahl (Standard 200) erreicht, gewinnt die höchste Summe. Bei Gleichstand auf Platz 1 folgt eine Extrarunde.
- **Spieler nachträglich:** Über das Personen-Symbol oben im Spiel steigt jemand mitten im Spiel ein. Er startet mit 0 Punkten, frühere Runden zählen für ihn nicht in die Statistik.
- **Korrektur:** Gebuchte Zellen lassen sich anklicken. **⌘Z** nimmt die letzte Runde zurück, auch nach dem Sieg.
- **Historie:** Rangliste mit Siegen, höchstem Sieg, bester Runde, Ø pro Runde und Verzockt-Quote, dazu alle Spiele mit kompletter Tabelle. Über das ⋯-Menü lässt sich ein Spieler zurücksetzen oder aus der Rangliste entfernen, ein einzelnes Spiel über den Mülleimer löschen.
- **Geteilt / Privat:** Der Schalter oben links legt fest, in welche Statistik die Spiele zählen. *Geteilt* wird über Supabase abgeglichen, *Privat* bleibt auf diesem Mac und hat eigene Rangliste und Namensvorschläge. Ein laufendes Spiel wandert beim Umschalten mit, beendete bleiben, wo sie gezählt wurden. Die Auswahl gilt pro Mac.
- **Einstellungen (⌘,):** Namensliste für die Spracherkennung (z. B. „Pratiksha“, „Jafar“), Sprechtaste, Zielpunktzahl, Sounds, Startanimation, geteilte Historie, Historie löschen.

Die Spracherkennung (`SpeechAnalyzer` mit `DictationTranscriber`) läuft komplett auf dem Mac. Dafür braucht die App nur den Mikrofonzugriff, den sie beim ersten Start anfragt. Die Spielstände liegen in `~/Library/Application Support/Flip7Counter/library.json` (geteilt) und `library-private.json` (privat).

## Geteilte Historie

Mehrere Macs können Spiele und Rangliste über ein Supabase-Projekt teilen:

1. Projekt auf [supabase.com](https://supabase.com) anlegen.
2. Im SQL Editor [`supabase/schema.sql`](supabase/schema.sql) ausführen.
3. Unter *Project Settings → API Keys* den **publishable key** (oder den alten `anon` key) kopieren, dazu die Project URL.
4. In der App unter Einstellungen → *Geteilte Historie* beides eintragen und *Verbinden* klicken.

Geteilt werden nur beendete Spiele und Spieler-Resets aus der Statistik *Geteilt*. Laufende Partien bleiben auf dem Mac, an dem gespielt wird. Abgeglichen wird beim Start, nach jedem Sieg, beim Öffnen der Historie und nach Löschen oder Zurücksetzen. Ohne Netz läuft die App lokal weiter, offene Änderungen liegen in `outbox.json` und gehen beim nächsten Abgleich raus. Gelöschte Spiele werden in Supabase nur markiert (`deleted_at`), damit die Löschung auch Macs erreicht, die gerade offline waren. *Historie löschen* ist gesperrt, solange die Verbindung steht.

Der Key ist für Apps gedacht und kein Geheimnis. Was er darf, regeln die Policies im Schema: lesen, anlegen, ändern, aber nicht löschen. Den `secret`/`service_role` key nie eintragen.

## Bauen

```sh
./scripts/build-app.sh            # baut build/Flip 7.app
./scripts/build-app.sh --install  # und kopiert nach /Applications
swift test                        # Domain- und Parser-Tests
```

Voraussetzung: macOS 27, Xcode 27.

## Updates

In den Einstellungen unter *Updates* prüft **Nach Updates suchen**, ob auf GitHub neue Commits liegen, und listet sie auf. **Jetzt updaten** führt nach einer Rückfrage `git pull --ff-only` und `scripts/build-app.sh` im Projektordner aus, ersetzt die installierte App und startet sie neu. Schlägt ein Schritt fehl, läuft die alte Version weiter.

Den Projektordner und den Commit schreibt `build-app.sh` in die `Info.plist` der App. Eine App, die vor dieser Funktion gebaut wurde, muss deshalb einmal von Hand neu gebaut werden. Eigene Änderungen im Projektordner blockieren das Update.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `Sources/Flip7Core` | Domain: `Game`, `Round`, `Points`, `PlayerName`, Ansage-Parser, Historie, Speicherung und Supabase-Abgleich |
| `Sources/Flip7` | SwiftUI-App: Views, Spracherkennung, Hotkey, Einstellungen |
| `scripts/` | App-Bundle und Icon erzeugen |
| `supabase/` | SQL-Schema für die geteilte Historie |
