# Deep Mine — standard autonomicznej realizacji

## Priorytet

Celem jest szybkie dostarczenie gry na Androida, która łączy kopanie, bezpieczny powrót z rdzeniem, wzrost dochodu złota/s i rozwój postaci. Nie buduj dodatkowych systemów bez uzasadnienia retencją, monetyzacją lub usunięciem krytycznego defektu.

## Przebieg

1. Poznaj istniejący kod i `data/balance.json`.
2. Samodzielnie wybierz najbliższe zadanie z `docs/ROADMAP.md`, jeśli użytkownik nie podał konkretnego.
3. Implementuj komplet funkcji w jednym przyroście, wykonaj test techniczny i regresję najważniejszych ścieżek.
4. Jeśli środowisko nie pozwala uruchomić Godot, jasno oznacz stan jako „nieuruchomiony” zamiast deklarować sukces.
5. Nie pytaj o akceptację kolejnych kroków, chyba że decyzja wymaga dostępu do konta, wydatku, zmiany nieodwracalnej lub opublikowania treści w imieniu użytkownika.
6. Zapisz wynik, zmienione pliki, testy, blocker i następne zadanie. Nie ukrywaj nieukończonej funkcji.

## Testy lokalne

- Wymagany Godot 4.7.x. Binarium wskazuje zmienna `GODOT_BIN` (wersja konsolowa `*_console.exe`); runner nie ma domyślnej ścieżki ani zapasowej wersji.
- Uruchomienie: `bash tests/run_tests.sh` (albo `bash tests/run_tests.sh "<ścieżka Godot 4.7.x>"`); sukces = kod 0 i linia `RESULT: OK`. Brak `GODOT_BIN` lub inna wersja niż 4.7.x = `SETUP ERROR` i kod 2.
- Przykład z PowerShell 5.1: `$env:GODOT_BIN = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe'; & 'C:\Program Files\Git\bin\bash.exe' tests/run_tests.sh` (w PowerShell `bash` zwykle nie jest w PATH). Z Git Bash: `GODOT_BIN=/c/Godot/Godot_v4.7.2-stable_win64_console.exe bash tests/run_tests.sh`.
- Kontrola samego runnera: `bash tests/verify_runner.sh` z tym samym `GODOT_BIN`.

## Język

- Wszystkie raporty, plany i odpowiedzi agentów po polsku.
- Identyfikatory w kodzie i nazwy API po angielsku.
- Bez komentarzy w kodzie źródłowym.

## Kryteria jakości

- Dane balansu poza logiką widoków.
- Brak duplikowania łupów, złota, generatorów i nagród reklamowych.
- Każde zdarzenie zakupowe musi być zweryfikowane przed przyznaniem przedmiotu.
- Android target API co najmniej 36 przy publikacji nowych aplikacji w 2026.
- Nie dodawaj multiplayera real-time, gildii i handlu przed działającą wersją w Play.
- Wykonuj smoke-test zapisu/wczytywania, walki, odwrotu i odblokowania generatora przy każdej zmianie logiki.

## Ograniczenie iteracji agentów

Review może zwrócić zmianę do poprawy maksymalnie 5 razy. Po limicie zakończ automatyczną pętlę i przedstaw konkretną diagnozę, bez dalszego zużywania tokenów.
