# Flip 7 Counter

Kleine Mac-App zum Mitzählen bei [Flip 7](https://www.kosmos.de/de/flip-7_1685430_4002051685430). Rundenpunkte werden angesagt statt im Kopf addiert.

## Bedienung

- **Neues Spiel:** Namen tippen oder Leertaste halten und sie ansagen („Martin Max Florian Christian“).
- **Runde erfassen:** Leertaste halten und sagen: „Max 5, Paul 0, Lisa 26“. Die Werte erscheinen als Entwurf und lassen sich per Klick korrigieren. **↩** bucht die Runde. Wer nicht genannt wurde, bekommt `–` (0 Punkte).
  - „Paul und Lisa 26“ gibt beiden 26 Punkte.
  - „null“, „verzockt“ und „raus“ zählen als 0.
- **Spielende:** Hat am Ende einer Runde jemand die Zielpunktzahl (Standard 200) erreicht, gewinnt die höchste Summe. Bei Gleichstand auf Platz 1 folgt eine Extrarunde.
- **Korrektur:** Gebuchte Zellen lassen sich anklicken. **⌘Z** nimmt die letzte Runde zurück, auch nach dem Sieg.
- **Historie:** Rangliste mit Siegen, bester Runde, Ø pro Runde und Verzockt-Quote, dazu alle Spiele mit kompletter Tabelle.
- **Einstellungen (⌘,):** Sprechtaste, Zielpunktzahl, Sounds, Startanimation.

Die Spracherkennung läuft lokal über Apple Speech (Deutsch). Die Spielstände liegen in `~/Library/Application Support/Flip7Counter/library.json`.

## Bauen

```sh
./scripts/build-app.sh            # baut build/Flip 7.app
./scripts/build-app.sh --install  # und kopiert nach /Applications
swift test                        # Domain- und Parser-Tests
```

Voraussetzung: macOS 14+, Xcode 16+.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `Sources/Flip7Core` | Domain: `Game`, `Round`, `Points`, `PlayerName`, Ansage-Parser, Historie und Speicherung |
| `Sources/Flip7` | SwiftUI-App: Views, Spracherkennung, Hotkey, Einstellungen |
| `scripts/` | App-Bundle und Icon erzeugen |
