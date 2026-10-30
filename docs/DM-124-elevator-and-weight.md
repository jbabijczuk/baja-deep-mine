# DM-124 — winda 30 s i spowolnienie z łupem

## Wniosek

Wjazd windą trwa 30 s, rozładunek 2 s, zjazd 8 s (pełny cykl 40 s). Łup trafia do skarbca dopiero po dojeździe. Jeśli faza aktywna skończy się w trakcie wjazdu, łup przepada. Górnik zwalnia od pierwszej bryłki: czas pola = `0,30 s × clamp(1 + 0,12 × kg, 1, 2,4)`. Stary próg 8 kg i mnożnik 1,6 usunięto, więc kary się nie nakładają. Runda zostaje 280 + 20 s. Ostateczną ocenę grywalności wydaje właściciel w ręcznym teście.

## Przed / po

| Parametr | Przed (PR #15) | Po (DM-124) |
|---|---|---|
| Wjazd na powierzchnię | animacja 1,6 s | **30,0 s**, płynny ruch klatki, pasek postępu i pozostały czas |
| Bankowanie łupu | natychmiast przy wejściu na windę | dokładnie raz, w chwili dojazdu (po 30 s); wtedy też zapis |
| Rozładunek | brak | **2,0 s**, panel „ROZŁADUNEK”, potem panel powierzchni |
| Zjazd | animacja 1,6 s | **8,0 s**, uruchamiany przyciskiem; w przerwie zablokowany |
| Koniec fazy aktywnej w trakcie wjazdu | nie dotyczyło (łup był już w skarbcu) | łup przepada, przejście do przerwy, nic nie trafia później do skarbca |
| Koniec fazy w trakcie rozładunku / zjazdu | — | skarbiec bez zmian / zjazd przerwany, górnik na powierzchni, kopanie zablokowane |
| Ostrzeżenie | brak | gdy do zawalenia zostało < 30 s: „Winda jedzie 30 s. Nie zdążysz przed zawaleniem!” |
| Czas pola, 0 kg | 0,300 s | 0,300 s (×1,00) |
| 1× węgiel, 2 kg | 0,300 s | 0,372 s (×1,24) |
| 3× węgiel, 6 kg | 0,300 s | 0,516 s (×1,72) |
| 2× złoto, 8 kg | 0,480 s (×1,6) | 0,588 s (×1,96) |
| 3× miedź, 9 kg | 0,480 s | 0,624 s (×2,08) |
| 3× złoto, 12 kg | 0,480 s | 0,720 s (×2,40, limit) |
| `dig_interval`, ziemia HP, kilof, sloty | 0,38 s, 2, 25 zł, 3 | bez zmian |

## Konfiguracja (`data/mine_prototype.json`)

```json
"player": { "move_time": 0.3, "slow_per_kg": 0.12, "max_slow_multiplier": 2.4, ... },
"elevator": { "up_seconds": 30, "unload_seconds": 2, "down_seconds": 8 }
```

- Usunięte klucze: `player.heavy_mass`, `player.slow_move_multiplier`. Test sprawdza, że nie wróciły.
- Jedno źródło prawdy: `mine_model.gd::move_time()` / `move_multiplier()`. Widok bierze z nich czas ruchu i animacji kroku. Zmiana masy (np. Q w trakcie kroku) nie zmienia bieżącego ruchu, tylko koszt następnego kroku.
- Próg ostrzeżenia to `elevator.up_seconds`, bez osobnego klucza. Przyszły upgrade silnika windy (np. 30→22→15 s) zmieni jedną wartość.

## Maszyna stanów

`mine → ascending (30 s) → unloading (2 s) → surface → descending (8 s) → mine`, a przy końcu fazy aktywnej `→ break (20 s) → surface` (nowa runda).

- Przejścia liczy wyłącznie `mine_model.gd::tick(delta)` według `round_time`. Nie zależą od FPS ani od tweenów. Koniec fazy windy jest zapisany jako czas bezwzględny (`elevator_until`). Jedna duża klatka (lag, RDP, powrót z tła) przechodzi po kolei przez wszystkie granice, które minęły, i każde przejście wykonuje raz. Test: jedna klatka 500 s daje dokładnie `arrived, unloaded, break, new_round`, a do skarbca trafia jedna dostawa.
- Granica: dojazd równo z końcem fazy aktywnej (`elevator_until == 280`) jest liczony jako depozyt, bo przejście windy jest sprawdzane przed zawaleniem.
- `round_time` rośnie w trakcie jazdy. Wielokrotne kursy w jednej rundzie działają jak wcześniej.
- Zapis w trakcie jazdy nie zawiera łupu z windy, a po wczytaniu plecak jest pusty. Skarbiec rośnie tylko w `_bank_backpack()`, wołanym raz przy dojeździe.
- Zakupy są możliwe tylko w stanach `surface` i `break`.
- Widok (`mine_prototype.gd::_update_ride`) ustawia klatkę i górnika co klatkę na podstawie `elevator_progress()`, na pełnych pikselach. Zastąpiło to tweeny 1,6 s.

## Koszt windy w rundzie 280 s

| Pełne cykle (40 s) | Czas windy | Udział w 280 s | Zostaje na kopanie i chodzenie |
|---:|---:|---:|---:|
| 1 | 40 s | 14,3% | 240 s |
| 2 | 80 s | 28,6% | 200 s |
| 3 | 120 s | 42,9% | 160 s |

Po ostatnim kursie zjazd nie jest potrzebny, więc *k* dostaw kosztuje w praktyce 30 + 40·(k−1) s: 30 / 70 / 110 s. Ostatni wjazd musi ruszyć najpóźniej przy 4:10 (zostało 30 s).

## Symulacja rundy przy znanych złożach

Narzędzie: `tests/round_sim.gd` (`RoundSim.simulate_round`). Uruchomienie: `"$GODOT_BIN" --headless --path . -s res://tests/round_sim.gd` (linie `ROUND`). Symulator zna całą mapę i chodzi najkrótszą drogą (Dijkstra) do najbliższej rudy. Kopie i chodzi z czasem pola zależnym od bieżącej masy. Po 3 bryłkach wraca do windy, a każdy kurs kosztuje 30 + 2 + 8 s. Kurs liczy się tylko wtedy, gdy dojazd mieści się w 280 s. Kilof podstawowy, plecak 3 sloty.

| Seed | Dostawy | Wartość | Uwagi |
|---|---:|---:|---|
| 20261029 (domyślny) | 4 | 60 zł | dojazdy: 39,2 / 99,1 / 168,7 / 228,6 s; chodzenie i kopanie na kurs: 9,2 / 19,9 / 29,6 / 20,0 s |
| 1 | 4 | 54 zł | |
| 2 | 5 | 45 zł | sam węgiel blisko szybu |
| 3 | 4 | 60 zł | |
| 4, 5, 6, 8 | 4 | 36 zł | sam węgiel |
| 7 | 4 | 60 zł | |
| 9 | 4 | 48 zł | |

Test `known-map round fits at least 2 elevator deliveries` wymaga co najmniej 2 dostaw na każdym z 10 seedów. Najgorszy wynik to 4.

**Zastrzeżenie:** to dolna granica czasu. Symulator nie szuka żył, nie błądzi, nie dostaje głazem i nie traci czasu na decyzje. Prawdziwa eksploracja (śledzenie przebarwień, ślepe korytarze, głazy) trwa wielokrotnie dłużej. Realnie spodziewamy się 2–3 kursów na rundę, a przy dalszych żyłach nawet 1–2. To trzeba sprawdzić w ręcznym teście. Przy 3 kursach winda zabiera 110–120 s, czyli ~40% rundy. To celowo silny koszt. Nie zmieniałem uzgodnionych 30 s.

## Zrzuty rzeczywistej sceny

`tools/capture_elevator.gd` (okno, nie headless; Godot 4.7.2, GL Compatibility, GTX 1660 Ti), 720×1280:

- `screenshots/dm-124/dm124_01_loaded_miner_slower.png` — HUD z masą i „WOLNIEJ ×2.20” (10 kg).
- `screenshots/dm-124/dm124_02_ascending_progress.png` — wjazd: klatka w szybie, pasek, „Na powierzchni za 19 s • łup 46 zł”, skarbiec nadal 0 zł.
- `screenshots/dm-124/dm124_03_unloading.png` — rozładunek: klatka przy wieży, skarbiec 46 zł.
- `screenshots/dm-124/dm124_04_surface_panel.png` — panel powierzchni po rozładunku.
- `screenshots/dm-124/dm124_05_warning_under_30s.png` — ostrzeżenie przy 0:18 do zawalenia.

Nagrania wideo nie zrobiono.

## Testy

`bash tests/run_tests.sh` → `RESULT: OK` (prototyp: 36 testów, 199 asercji; baza: 18 testów, 99 asercji). Nowe lub zmienione testy w `tests/test_mine_prototype.gd`:

- `_test_elevator_return`, `_test_elevator_banks_only_on_arrival` — brak banku i zapisu przy starcie i przed 30 s; zapis w trakcie jazdy nie daje banku; dokładnie jeden depozyt i zapis po 30 s; zjazd możliwy dopiero po 2 s; zjazd 8 s; `round_time` rośnie w jeździe; pełny cykl 40 s.
- `_test_elevator_round_boundaries` — wjazd przy 35 / 30 / 29,9 s do końca (depozyt / depozyt na granicy / ostrzeżenie i utrata), brak późniejszego księgowania po przerwie.
- `_test_round_ends_during_unload_and_descent` — koniec rundy w rozładunku (bank zostaje) i w zjeździe (powrót, kopanie zablokowane).
- `_test_elevator_lag_no_duplicate` — klatki 31 s i 500 s, powtórne sygnały wejścia i zjazdu.
- `_test_mass_slowdown_table` — 0/2/6/9/12 kg = 0,300/0,372/0,516/0,624/0,720 s, limit 2,4, monotoniczność na 200 losowych mieszankach, pełna prędkość po rozładunku.
- `_test_mass_change_keeps_current_move` (scena) — wyrzucenie łupu w trakcie kroku 0,72 s nie przerywa ruchu, a następny krok trwa 0,30 s.
- `_test_elevator_ride_whole_pixels` (scena, klatki 1/60 s) — panel, pasek i pozostały czas; klatka jedzie płynnie na pełnych pikselach bez cofania; depozyt dopiero na górze; panel rozładunku, potem panel powierzchni; zjazd kończy się w środku pola; ostrzeżenie < 30 s; klatki 12 s i 25 s nie dublują depozytu.
- `_test_round_sim_two_trips` — co najmniej 2 dostawy przy znanych złożach.
- Regresje bez zmian logiki: sterowanie, 10 pól bez przerw, zmiany kierunku, ogłuszenie, F3, żyły, plecak 3 sloty, upgrade kilofa, zapis i wczytanie, zawalenie.

## Pomiar ruchu w oknie (`tools/measure_motion.gd`)

Godot 4.7.2, GL Compatibility, vsync, okno 720×1061. Sesja Windows przez RDP (`rdp-tcp#1`, ekran raportuje 32 Hz), Godot renderuje lokalnie w 60 FPS. Każdy scenariusz przeszedł 3 razy, a wyniki były identyczne.

| Scenariusz | Klatki | Klatka śr. / max | Postoje | Ruch wstecz | Podpiksele |
|---|---:|---|---:|---:|---:|
| Marsz 12 pól (0 kg) | 248 | 16,67 / 17,2–17,3 ms | 0 | 0 | 0 |
| Obciążenie 8 kg (2× złoto, 0,588 s/pole), 12 pól | 455 (przed DM-124: 377 przy 0,48 s) | 16,65–16,66 / 17,3–17,6 ms | 0 | 0 | 0 |
| Winda: wejście, wjazd 30 s, rozładunek 2 s, zjazd 8 s, wyjście | 2451 (≈ 40,9 s) | 16,67 / 17,3–19,4 ms | 0 | 0 | 0 |
| Zmiany kierunku / kopanie / głaz | 320 / 576 / 332 | jak w DM-123 | 0 | 0 | 0 |

## Uwaga o testach przez RDP

Logika windy i masy liczy czas z `delta`, a nie z klatek. Długość jazdy, moment depozytu i granice rundy są więc takie same przy 60 FPS lokalnie, przy 30 Hz przez RDP i przy pojedynczych przycięciach (testy z dużym `delta`). Obraz to co innego: klatka jedzie ~17 px/s (518 px w 30 s), czyli przesuwa się o 1 px co 3–4 klatki Godot. Przez RDP (~32 Hz w poprzednim pomiarze) ruch może wyglądać na schodkowy, choć logika jest poprawna. Płynność i odczucie 30 s należy ocenić lokalnie albo na telefonie, a RDP traktować tylko jako kontrolę logiki.
