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

Dopóki jakiekolwiek Issue ma `orca-running`, precheck zwraca 2 i nic nowego nie startuje. Koordynator sam pozostawia `orca-running` i zapisuje `phase=stuck`, gdy któregoś workera nie da się rozliczyć. Gdy stan trwa dłużej niż godzinę:

1. W komentarzach Issue znajdź ostatnią linię `ORCA-STATE run=... phase=... dispatch=...`.
2. `orca automations runs --id 3f6117f2-1c36-4504-8ab0-41234e1ac826 --limit 3 --json` — sesja koordynatora nadal aktywna: czekaj.
3. `orca orchestration worker-list --run <run> --include-remote --json` i dla każdego wiersza `projection.liveness`:
   - `live`: czekaj.
   - `unverifiable`: nie zwalniaj, nie zatrzymuj i nie kolejkuj ponownie; sprawdź `orca orchestration worker-show --dispatch <dispatch> --json` i czekaj na `live` albo `exited`.
   - `exited` bez rozliczenia: wykonaj dokładnie `projection.nextAction`; gdy wskazuje zakończenie, `orca orchestration worker-stop --dispatch <dispatch> --json` (albo `worker-abandon`, gdy procesu nie da się potwierdzić).
4. Dopiero gdy każdy Dispatch Runu jest rozliczony:
   - kontynuacja: dodaj komentarz `ORCA-REQUEUE`, usuń `orca-running`, nadaj `orca-ready`; następny koordynator wznowi ten sam Run, gałąź i licznik rund zamiast tworzyć duplikat;
   - porzucenie: `orca orchestration worker-release --dispatch <dispatch> --json` dla rozliczonych workerów, usuń `orca-running`, nadaj `orca-blocked`.

## Ograniczenia

- Komputer z Orca musi być włączony; po uśpieniu Orca nadrabia jedno pominięte uruchomienie.
- Testy wymagają Godot `C:/Users/jbabi/Desktop/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe` i `bash`. Build APK nie jest częścią pętli.
- Zużycie tokenów jest raportowane tylko po włączeniu śledzenia użycia Claude w Orca.
