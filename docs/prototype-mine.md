# Prototyp kopalni 2D (DM-120, Issue #8)

Pionowy wycinek: górnik chodzi w 4 kierunkach po siatce, kopie teren, zbiera rudy do plecaka z masą, unika głazów i wynosi łup windą przed zawaleniem.

## Uruchomienie (Godot 4.7.2)

- Edytor: otwórz projekt, `F6` na `scenes/MinePrototype.tscn`, albo `F5` → przycisk **NOWA KOPALNIA — PROTOTYP** w bazie. Przycisk **BAZA** wraca do starej bazy (zapis bazy jest zapisywany przed przejściem).
- Z linii poleceń: `Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/MinePrototype.tscn`.
- Sterowanie: WASD / strzałki albo dotykowy krzyżak w prawym dolnym rogu. Wejście w materiał kopie go, wejście do klatki windy wynosi łup na powierzchnię. **DEBUG: KONIEC RUNDY** przestawia zegar na 0:10 przed zawaleniem.

## Zasady prototypu

- Mapa 48×64 z seeda (`data/mine_prototype.json`), szyb z windą przy kolumnie 14, 3 lampy przy stacji, komora startowa i korytarz zawsze otwarte.
- Materiały: ziemia (1 HP), węgiel (2), kamień (3), miedź (3), złoto (5). Węgiel/miedź/złoto dają 1–3 jednostki surowca; plecak 40 kg, powyżej 70% górnik zwalnia.
- Głazy leżą na podporze. Po wykopaniu podpory spadają; spadający głaz ogłusza górnika na 1,6 s. Głaz o wadze ≤ siła (2) można przepchnąć w bok na wolne pole. Bezpieczny test: głaz demonstracyjny nad korytarzem, 5 pól na prawo od startu — stań pod nim i kop w górę.
- Zegar: 4:40 kopania, potem zawalenie (utrata niewyniesionego łupu, powrót na powierzchnię) i 0:20 przerwy, po której mapa regeneruje się z nowym seedem. Wyniesiony łup zostaje.
- Łup prototypu nie trafia do zapisu starej bazy (bez zmian ekonomii).

## Architektura

| Plik | Rola |
|---|---|
| `data/mine_prototype.json` | balans: mapa, HP, dropy, masa, siła, czasy rundy |
| `scripts/mine_prototype/mine_model.gd` | czysta logika (bez węzłów): generowanie, kopanie, ruch, głazy, winda, zegar |
| `scripts/mine_prototype/mine_art.gd` | proceduralne tekstury pixel art (32×32, skala 2) i klatki górnika |
| `scripts/mine_prototype/mine_world.gd` | rysowanie tylko widocznych komórek, obrysy tuneli, cienie, pęknięcia |
| `scripts/mine_prototype/surface_backdrop.gd` | niebo, wzgórza, wieża wyciągowa, budynek |
| `scripts/mine_prototype/mine_prototype.gd` | sterowanie, kamera, światła (`CanvasModulate` + `PointLight2D`), efekty, HUD |

## Weryfikacja

- `bash tests/run_tests.sh <Godot 4.7.2 console>` uruchamia też `tests/test_mine_prototype.gd` (11 testów, 62 asercje: seed i droga do windy, kopanie, wejście w wykopaną komórkę, ruch w górę bez grawitacji, plecak, głaz spada/ogłusza/przepychanie, winda, zawalenie traci łup, debug, smoke sceny, przycisk w bazie).
- Screenshoty z prawdziwego renderera (OpenGL 3.3, GTX 1660 Ti) w `docs/screenshots/prototype/` generuje `Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/capture_prototype.gd` (bez `--headless`). Skrypt przechodzi trasę wywołując te same akcje co klawisze, renderuje `SubViewport` 720×1280 do PNG.
- Weryfikacja interaktywna: sceny `MinePrototype.tscn` i `Main.tscn` uruchomione w oknie bez błędów; ręczne granie klawiaturą i dotykiem **nie zostało wykonane przez agenta** — wymaga oceny właściciela.

## Pochodzenie i licencja assetów

Wszystkie grafiki są autorskie, generowane w kodzie (`mine_art.gd`, `surface_backdrop.gd`) w czasie uruchomienia; brak plików z zewnątrz i z innych gier. Proponowana licencja: CC0 1.0 (decyzja właściciela repozytorium). Czcionka: domyślna czcionka wbudowana w Godot, dostarczana z silnikiem.
