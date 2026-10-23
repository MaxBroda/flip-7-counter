# Hinweise für Coding-Agents

## Commit-Nachrichten sind Update-Notizen

Der Button *Einstellungen → Updates → Nach Updates suchen* zeigt den Nutzern die Subject-Zeilen aller Commits, die auf `origin/main` neu sind (`git log --format=%s HEAD..@{u}` in `Sources/Flip7/Updater.swift`). Die Nutzer sind keine Entwickler.

- Subject auf Deutsch, aus Sicht der Nutzer: was sich in der App ändert, nicht was im Code passiert.
  - gut: „Mülleimer statt Rechtsklick zum Löschen eines Spiels“
  - schlecht: „Refactor HistoryView“, „fix typo“, „WIP“
- Nur eine Subject-Zeile, kein Body.
- Reine Interna (Tests, README, Refactoring) trotzdem verständlich benennen, z. B. „Anleitung zum Bauen ergänzt“.

## Bauen und testen

```sh
swift build                       # schneller Compile-Check
swift test                        # Domain- und Parser-Tests (Flip7Core)
./scripts/build-app.sh --install  # App bauen und nach /Applications kopieren
```

`build-app.sh` schreibt `Flip7SourceDirectory` und `Flip7Commit` in die `Info.plist` des Bundles. Davon hängt der Update-Button ab: Die Schlüssel nicht entfernen und das Skript nicht umbenennen.

## Regeln, die man im Code leicht übersieht

- **Geteilt / Privat:** Es gibt zwei Statistiken (`HistorySpace`). Nur *Geteilt* geht an Supabase. Änderungen an der Historie in `AppModel` laufen über `share { … }`, nie direkt über `sharing`, sonst landen private Spiele auf den anderen Macs.
- **Keine nativen macOS-Dialoge:** Menüs und Rückfragen nutzen `MenuPopover`/`MenuRow` und `themedConfirmation` aus `Theme.swift`, nicht `Menu`, `contextMenu`, `alert` oder `confirmationDialog`.
- **Spalten im Spiel:** Spielstand-Karten und Tabellenspalten nutzen beide das `Columns`-Layout. Nur so steht die Punktzahl eines Spielers genau unter seiner Karte. Bei Änderungen an einem von beiden das andere mitziehen.
