# Flip 7 Counter

Kleine Mac-App zum Mitzählen bei [Flip 7](https://www.kosmos.de/de/flip-7_1685430_4002051685430). Rundenpunkte werden angesagt statt im Kopf addiert.

## Herunterladen & Updates

**App laden:** Die fertige App liegt auf der [Releases-Seite](https://github.com/MaxBroda/flip-7-counter/releases). Dort beim neuesten Eintrag die ZIP-Datei (`Flip-7-vN.zip`) herunterladen, entpacken und `Flip 7.app` in den Ordner *Programme* ziehen. Beim allerersten Start meldet macOS, dass die App nicht aus dem App Store kommt: einmal unter Systemeinstellungen → *Datenschutz & Sicherheit* nach unten scrollen und auf *Trotzdem öffnen* klicken. Danach startet sie wie jede andere App. Voraussetzung: Mac mit Apple-Chip und macOS 27.

**Aktualisieren:** Die App hält sich selbst aktuell. In den Einstellungen (⌘,) unter *Updates* auf **Nach Updates suchen** klicken. Gibt es eine neuere Version, zeigt **Jetzt updaten** kurz, was neu ist, lädt die Version nach einer Rückfrage selbst herunter, ersetzt die App und startet neu. Spielstände und Einstellungen bleiben erhalten – nichts muss von Hand gelöscht oder neu heruntergeladen werden.

> Wer die App über einen Release vor diesem Update-Feature geladen hat, lädt die nächste Version einmalig noch von Hand über die Releases-Seite. Ab dann läuft es automatisch.

Hast du das Repository stattdessen geklont, aktualisiert derselbe Knopf über `git pull` und einen Neubau – die App erkennt selbst, welcher Weg passt.

## Bedienung

Spieler ansagen oder tippen, dann die Sprechtaste (Standard: Leertaste) halten und die Punkte sagen: „Max 5, Oskar 0, Mila 26“. Die Werte erscheinen als Entwurf, lassen sich per Klick korrigieren, **↩** bucht die Runde. Wer die Zielpunktzahl (Standard 200) zuerst knackt, gewinnt. **⌘Z** nimmt die letzte Runde zurück, **⌘,** öffnet die Einstellungen.

Die Spracherkennung läuft komplett auf dem Mac; die App braucht dafür nur den Mikrofonzugriff, den sie beim ersten Start anfragt.

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
./scripts/release.sh v2           # schneidet ein Release (bauen, zippen, auf GitHub laden)
swift test                        # Domain- und Parser-Tests
```

Voraussetzung: macOS 27, Xcode 27.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `Sources/Flip7Core` | Domain: `Game`, `Round`, `Points`, `PlayerName`, Ansage-Parser, Historie, Speicherung und Supabase-Abgleich |
| `Sources/Flip7` | SwiftUI-App: Views, Spracherkennung, Hotkey, Einstellungen |
| `scripts/` | App-Bundle und Icon erzeugen, Release schneiden |
| `supabase/` | SQL-Schema für die geteilte Historie |
