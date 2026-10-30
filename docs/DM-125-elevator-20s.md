# DM-125 — wjazd windy 20 s zamiast 30 s

## Wynik

`elevator.up_seconds` w `data/mine_prototype.json` zmieniono z 30 na 20 s. Rozładunek (2 s) i zjazd (8 s) zostały bez zmian, więc pełny cykl trwa 30 s zamiast 40 s. Runda nadal ma 280 s fazy aktywnej i 20 s przerwy. Kod gry nie wymagał zmian, bo licznik, ostrzeżenie, pozostały czas, pasek i ruch klatki już czytały tę wartość z konfiguracji (DM-124). Zasady depozytu też są bez zmian. Łup trafia do skarbca raz, w chwili dojazdu. Jeśli runda skończy się przed dojazdem, łup przepada.

Nie zmieniono: `move_time=0.3`, spowolnienia `clamp(1 + 0,12 × kg, 1, 2,4)`, 3 slotów plecaka, ulepszeń, ziemi 2 HP, płynnego chodzenia (DM-123) ani diagnostyki F3.

## Propozycja A/B: 30/2/8 (A) vs 20/2/8 (B)

Udział pełnych cykli w 280 s:

| Pełne cykle | A: czas windy | A: udział | A: zostaje | B: czas windy | B: udział | B: zostaje |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 40 s | 14,3% | 240 s | 30 s | 10,7% | 250 s |
| 2 | 80 s | 28,6% | 200 s | 60 s | 21,4% | 220 s |
| 3 | 120 s | 42,9% | 160 s | 90 s | 32,1% | 190 s |

Po ostatnim kursie zjazd nie jest potrzebny, więc *k* dostaw kosztuje w praktyce:

| Dostawy | A: 30 + 40·(k−1) | B: 20 + 30·(k−1) | Zysk B |
|---:|---:|---:|---:|
| 1 | 30 s | 20 s | 10 s |
| 2 | 70 s | 50 s | 20 s |
| 3 | 110 s | 80 s | 30 s |

Ostatni wjazd musi ruszyć najpóźniej przy 4:20 (zostało 20 s), a nie przy 4:10. Ostrzeżenie „Winda jedzie 20 s. Nie zdążysz przed zawaleniem!” pojawia się, gdy do zawalenia zostaje mniej niż 20 s.

## Symulacja rundy przy znanych złożach

Narzędzie i założenia jak w DM-124: `"$GODOT_BIN" --headless --path . -s res://tests/round_sim.gd` (linie `ROUND`), kilof podstawowy, plecak 3 sloty, powrót po 3 bryłkach. Godot 4.7.2, 10 seedów.

| Seed | A: dostawy | A: wartość | B: dostawy | B: wartość |
|---|---:|---:|---:|---:|
| 20261029 | 4 | 60 zł | 5 | 69 zł |
| 1 | 4 | 54 zł | 5 | 69 zł |
| 2 | 5 | 45 zł | 6 | 54 zł |
| 3 | 4 | 60 zł | 5 | 81 zł |
| 4 | 4 | 36 zł | 5 | 45 zł |
| 5 | 4 | 36 zł | 5 | 45 zł |
| 6 | 4 | 36 zł | 5 | 45 zł |
| 7 | 4 | 60 zł | 5 | 69 zł |
| 8 | 4 | 36 zł | 5 | 45 zł |
| 9 | 4 | 48 zł | 5 | 57 zł |
| **Średnio** | **4,1** | **47,1 zł** | **5,1** | **57,9 zł** |

Kolumny A pochodzą z `docs/DM-124-elevator-and-weight.md`. Kolumny B to wynik po tej zmianie. Najgorszy seed ma 5 dostaw zamiast 4, czyli o jedną więcej na rundę (+23% wartości średnio).

**Ograniczenie: symulator zna całą mapę.** Idzie najkrótszą drogą do najbliższej rudy, nie szuka żył, nie błądzi, nie dostaje głazem i nie traci czasu na decyzje. To dolna granica czasu, a nie prognoza gry. Realny gracz zrobi mniej kursów. Szacujemy 2–3 przy B wobec 2 przy A, ale to hipoteza do sprawdzenia w ręcznym teście. Względny zysk B (10 s na kurs) nie zależy od znajomości mapy, bo dotyczy tylko czasu windy.

## Odczucie w UI

Klatka jedzie ~26 px/s (518 px w 20 s, wcześniej ~17 px/s), czyli przesuwa się o 1 px co 2–3 klatki przy 60 FPS. Panel „WINDA JEDZIE W GÓRĘ” pokazuje pasek i „Na powierzchni za N s”. Wjazd nadal jest wyraźnym kosztem decyzji o powrocie, ale trwa krócej niż typowy kurs kopania (15–30 s w symulacji). Czy 20 s jest „zauważalne, ale nie frustrujące”, rozstrzyga ręczny test właściciela. Zrzuty w `docs/screenshots/dm-124/` pokazują jeszcze tekst ostrzeżenia z 30 s. Nie regenerowano ich, bo `tools/capture_elevator.gd` wymaga okna.

## Testy

`tests/test_mine_prototype.gd` (214 asercji):

- Istniejące testy windy, granic rundy, lagów, wielu dostaw, zapisu i sceny czytają `up_seconds` (oraz `unload_seconds`, `down_seconds`) z konfiguracji zamiast stałej 30. Wartość 20,0 jest sprawdzana tylko jako wartość odczytana z konfiguracji.
- `_test_elevator_ascent_20s_regression`: 19,9 s to nadal wjazd bez depozytu, a 20,0 s i 20,1 s dają jeden depozyt (również po kolejnych 60 s). Dojazd 0,1 s przed końcem rundy zabezpiecza łup raz, a koniec rundy 0,1 s przed dojazdem oznacza utratę łupu.
- `_test_elevator_timing_fps_independent`: kroki delta 1/60, 1/20 i 0,25 s dają dojazd dokładnie po 20 s bez wcześniejszego bankowania, rozładunek 2 s i zjazd 8 s.
- Test sceny: brak ostrzeżenia przy dokładnie 20 s do końca, ostrzeżenie z tekstem „20 s” poniżej tej granicy.

## Następny krok (osobny Issue)

Ulepszenia wyciągu 20 → 14 → 9 → 6 s. W tym Issue ich nie zaimplementowano. Wizja jest w `docs/prototype-mine.md`.
