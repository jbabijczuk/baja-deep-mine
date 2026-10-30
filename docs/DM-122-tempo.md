# DM-122 — tempo chodzenia i kopania ziemi (Issue #12)

Korekta po ręcznym teście PR #11: „ludzik za szybko chodzi, za szybko przebija się przez ziemię”. Zmieniono wyłącznie tempo ruchu, HP ziemi i cooldown ostatniego ciosu; czas rundy (4:40) i gęstość żył bez zmian.

## Co zmieniono

| Parametr (`data/mine_prototype.json`) | Przed (PR #11) | Po |
|---|---|---|
| `player.move_time` | 0,16 s/pole | **0,30 s/pole** |
| `materials.dirt.hp` | 1 | **2** |
| `player.dig_interval` | 0,38 s | 0,38 s (bez zmian) |
| Cooldown po rozbiciu bloku | `dig_interval × 0,6` = 0,228 s (na sztywno w kodzie) | **pełny `dig_interval`** (mnożnik usunięty) |
| `player.slow_move_multiplier` (≥ 8 kg) | 1,6 | 1,6 (bez zmian) → 0,48 s/pole |

Widok (`scripts/mine_prototype/mine_prototype.gd`):
- Animacja chodzenia trwa dokładnie tyle co ruch o jedno pole (pełny cykl 4 klatek = jeden krok, także dla obciążonego górnika) — bez ślizgania.
- Uderzenie działa natychmiast po naciśnięciu (błysk, wstrząs, pęknięcie, pasek HP), a animacja kilofa biegnie od klatki trafienia do zamachu przez cały `dig_interval`. Blokada sterowania = czas animacji, nie dłużej.
- Po pierwszym ciosie ziemia (1/2 HP) pokazuje pęknięcie etapu 3 z 4 i pasek HP; drugi cios rozbija blok z odpryskami.

## Przed → po: tempo przy trzymanym kierunku

Czasy z modelu (`move_time`, `dig_interval`, HP). W grze każda akcja może się opóźnić o maks. 1 klatkę (≈ 17 ms przy 60 FPS), bo cooldown sprawdzany jest raz na klatkę.

| Scenariusz | Przed | Po |
|---|---|---|
| Ruch w pustym tunelu | 6,25 pola/s | **3,33 pola/s** |
| Ruch obciążony (≥ 8 kg) | 3,91 pola/s | **2,08 pola/s** |
| Uderzenia na ziemię — zwykły kilof (moc 1) | 1 | **2** |
| Uderzenia na ziemię — Hartowany kilof (moc 2) | 1 | **1** |
| 10 pól pustych | 1,6 s | **3,0 s** |
| 10 pól pustych, obciążony | 2,56 s | **4,8 s** |
| 10 pól ziemi (kop + wejście), zwykły kilof | 3,88 s (0,228 + 0,16 na pole) | **10,6 s** (2 × 0,38 + 0,30 na pole) |
| 10 pól ziemi, Hartowany kilof | 3,88 s | **6,8 s** (0,38 + 0,30) |
| 10 pól ziemi, zwykły kilof, obciążony | 4,84 s | **12,4 s** |

Uwaga do Issue: szacunek „0,7–0,8 s na pole ziemi” odpowiada samym dwóm uderzeniom (0,76 s). Z wejściem na rozkopane pole wychodzi 1,06 s/pole.

Ulepszony kilof daje odczuwalny skok (ziemia 10,6 → 6,8 s na 10 pól), ale nadal jest wolniejszy niż ziemia w PR #11 (3,88 s), więc nie „przenika” przez grunt. Twardsze rudy bez zmian: kilof 2 nadal potrzebuje 3 / 4 / 7 uderzeń na kamień / miedź / złoto.

## Test rundy 4:40 (symulacja, 10 seedów)

`tests/round_sim.gd` liczy najkrótszą trasę (Dijkstra) od startu przy szybie: koszt pola = ruch lub (uderzenia × `dig_interval` + ruch), omija głazy i pola pod głazami, po każdej bryłce liczy powrót do windy z uwzględnieniem ciężaru. Seedy: 20261029 i 1–9. Wartości: min / mediana / max w sekundach.

| Zwykły kilof | Przed | Po |
|---|---|---|
| Dotarcie do pierwszej rudy | 1,7 / 3,9 / 6,3 | 2,1 / 7,3 / 13,6 |
| 1 bryłka + powrót do windy | 1,8 / 5,7 / 8,4 | 2,4 / 10,8 / 18,4 |
| 3 bryłki + powrót | 5,2 / 8,8 / 11,8 | 6,7 / 14,7 / 22,7 |
| 1 miedź + powrót | 3,9 / 7,8 / 22,3 | 5,5 / 15,4 / 46,0 |
| 1 złoto + powrót | 19,5 / 24,5 / 55,3 | 34,1 / 43,2 / 94,2 |

| Hartowany kilof (po) | min / mediana / max |
|---|---|
| 3 bryłki + powrót | 4,4 / 11,3 / 16,6 |
| 1 miedź + powrót | 4,0 / 11,1 / 33,8 |
| 1 złoto + powrót | 22,7 / 30,1 / 64,5 |

Obserwacje (fakty z symulacji):
- Na każdym seedzie są 3 osiągalne bloki rudy; najbliższe to węgiel przy komorze startowej.
- Najgorszy przypadek 3 bryłek z powrotem: 22,7 s, czyli 8 % rundy. Najgorsza miedź: 46 s (16 %), najgorsze złoto: 94 s (34 %).

Ograniczenie: symulacja zakłada pełną wiedzę o mapie. Gracz widzi tylko w zasięgu lampy (~4–5 pól) i szuka po śladach, więc realny czas będzie dłuższy; tego narzutu nie zmierzono.

Rekomendacja (hipoteza do decyzji właściciela): zapas jest co najmniej 12× dla węgla i ok. 3× dla złota, więc nowe tempo nie wymusza zmiany czasu rundy ani gęstości żył. Wrócić do tego tematu dopiero wtedy, gdy ręczny test pokaże, że szukanie śladów zajmuje więcej niż ~2/3 rundy.

Testy w `tests/test_mine_prototype.gd` pilnują, że runda nadal trwa 280 s, 3 bryłki z powrotem mieszczą się w ¼ rundy, a miedź w ½ rundy na wszystkich 10 seedach.

## Ręczne strojenie

Wszystkie wartości są w `data/mine_prototype.json`; po zmianie wystarczy ponownie uruchomić scenę (F6 na `scenes/MinePrototype.tscn`), bez reimportu.

| Odczucie | Zmień | Efekt |
|---|---|---|
| Chodzenie za szybkie / za wolne | `player.move_time` (np. 0,26–0,36) | czas jednego pola; animacja dopasowuje się sama |
| Obciążony za lekki / za ciężki | `player.slow_move_multiplier`, `player.heavy_mass` | mnożnik czasu ruchu i próg kg |
| Uderzenia za częste / za rzadkie | `player.dig_interval` (np. 0,34–0,44) | rytm uderzeń i długość animacji kilofa |
| Ziemia za miękka / za twarda | `materials.dirt.hp` | 2 = dwa ciosy zwykłym kilofem, jeden hartowanym; 3 = trzy / dwa |
| Ulepszenie za mocne / za słabe | `upgrades.pick[0].power` | dzieli HP każdego materiału (zaokrąglenie w górę) |

Proponowana nastawa B do porównania A/B, jeśli 0,30 s / 2 HP nadal będzie za szybka (nietestowana ręcznie): `move_time` 0,34, `dig_interval` 0,42, `dirt.hp` 2 → 10 pustych pól 3,4 s, 10 pól ziemi 11,8 s (kilof 1) / 7,6 s (kilof 2).

Po zmianie wartości:
1. `bash tests/run_tests.sh <Godot 4.7.2 console>` — testy mają widełki (np. `move_time` 0,28–0,32, ziemia 2 HP); celowa zmiana poza widełki wymaga aktualizacji testów `_test_move_tempo_and_weight` i `_test_dig_balance`.
2. `<Godot 4.7.2 console> --headless --path . -s res://tests/round_sim.gd` — wypisuje linie `SIM` z czasami tras dla obu kilofów na 10 seedach.

## Weryfikacja

- `bash tests/run_tests.sh` → `RESULT: OK` (prototyp: 23 testy, 137 asercji).
- `tests/verify_runner.sh` → `SELFCHECK OK`.
- Ręczna gra klawiaturą i dotykiem **nie została wykonana przez agenta**; ocena odczucia należy do właściciela. Screenshoty nie powstały — HUD i grafika się nie zmieniły, zmienione jest tylko tempo.
