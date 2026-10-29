# Automatyczna kolejka Issues (Orca)

Przepływ: Issue z etykietą `orca-ready` → automatyzacja Orca co 5 minut → koordynator Claude → Developer Claude Code (osobny worktree) → Reviewer Codex (bez edycji) → do 3 rund poprawek → komentarz z wynikiem, a przy `APPROVED` push gałęzi roboczej i PR do `main`. `main` nigdy nie jest pushowany ani merge'owany automatycznie.

## Elementy

| Element | Wartość |
|---|---|
| Automatyzacja | `BajaDeepMine issue queue`, ID `3f6117f2-1c36-4504-8ab0-41234e1ac826` |
| Harmonogram | `*/5 * * * *`, strefa `Europe/Warsaw`, nowa sesja przy każdym uruchomieniu |
| Workspace koordynatora | `C:/Users/jbabi/orca/workspaces/BajaDeepMine/dm-orca-issue-automation` |
| Precheck | `tools/orca/precheck.ps1` (kod 0 = jest zadanie, 1 = pusta kolejka, 2 = trwa zadanie, 3 = błąd `gh`) |
| Procedura koordynatora | `tools/orca/coordinator.md` |

## Jak zlecić pracę

Utwórz Issue w `jbabijczuk/baja-deep-mine` jako `jbabijczuk` i nadaj etykietę `orca-ready`. Issues innych autorów i bez etykiety są ignorowane. Naraz obsługiwane jest jedno Issue; kolejne czekają.

Etykiety: `orca-ready` → `orca-running` → `orca-approved` albo `orca-blocked`.

## Kontrola

```powershell
orca automations list --json
orca automations show 3f6117f2-1c36-4504-8ab0-41234e1ac826 --json
orca automations runs --id 3f6117f2-1c36-4504-8ab0-41234e1ac826 --limit 10 --json
gh issue list --repo jbabijczuk/baja-deep-mine --label orca-running
powershell -NoProfile -ExecutionPolicy Bypass -File tools/orca/precheck.ps1
```

## Zatrzymanie i wznowienie automatu

```powershell
orca automations edit 3f6117f2-1c36-4504-8ab0-41234e1ac826 --disabled --json
orca automations edit 3f6117f2-1c36-4504-8ab0-41234e1ac826 --enabled --json
```

Wyłączenie nie przerywa trwającej sesji; ją zamykasz w Orca po sprawdzeniu stanu jak niżej.

`orca automations run <id>` uruchamia agenta bez prechecku; koordynator sam kończy pracę przy pustej kolejce, ale sesja jest płatna.

## Zadanie zawieszone w `orca-running`

Dopóki jakiekolwiek Issue ma `orca-running`, precheck zwraca 2 i nic nowego nie startuje. Gdy stan trwa dłużej niż godzinę:

1. W komentarzach Issue znajdź ostatnią linię `ORCA-STATE run=... dispatch=... worktree=... branch=...`.
2. `orca orchestration worker-list --run <run> --include-remote --json` i `orca automations runs --id 3f6117f2-1c36-4504-8ab0-41234e1ac826 --limit 3 --json`.
3. Worker `live` lub sesja koordynatora aktywna: czekaj.
4. Wszystko zakończone lub `exited`, praca warta kontynuacji: usuń `orca-running`, nadaj `orca-ready`. Następny koordynator odczyta `ORCA-STATE`, wznowi ten sam Run i gałąź zamiast tworzyć duplikat.
5. Praca do porzucenia: usuń `orca-running`, nadaj `orca-blocked`, a terminale zwolnij `orca orchestration worker-release --dispatch <dispatch> --json`.

## Ograniczenia

- Komputer z Orca musi być włączony; po uśpieniu Orca nadrabia jedno pominięte uruchomienie.
- Testy wymagają Godot `C:/Users/jbabi/Desktop/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe` i `bash`. Build APK nie jest częścią pętli.
- Zużycie tokenów jest raportowane tylko po włączeniu śledzenia użycia Claude w Orca.
