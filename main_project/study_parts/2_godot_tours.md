## godot_tours (res://addons/godot_tours)

### На какие задачи направлены скрипты

Аддон **GDTour** (GDQuest) превращает сам редактор Godot в интерактивную обучающую среду. Он работает только в редакторе (`@tool`, `EditorPlugin`). Аддон строит поверх интерфейса редактора отдельный слой: затемнение (dimmer) с «вырезами»-подсветками нужных элементов UI, плавающее окно-подсказку (bubble) с маскотом Gobot, анимированный «призрачный» курсор мыши. Пошаговый сценарий (тур) ведёт пользователя по реальному UI: открывает сцены, выделяет узлы, переключает главные экраны и вкладки доков. Затем тур ждёт, пока пользователь сам выполнит действие: нажмёт кнопку, выберет узел, изменит свойство, переместит 3D-объект в направляющий бокс и т.п. Основные задачи скриптов:

- **Регистрация и запуск серии туров:** поиск `res://godot_tours.gd` / `res://tours/godot_tours.gd` (наследник `GDTourMetadata`), меню выбора туров, кнопка «GDTour» в верхней панели редактора, переход к следующему туру, сохранение прогресса в `user://gdtour_progress.save`.
- **DSL для описания туров:** класс `tour.gd` с методом `_build()`. В нём автор тура вызывает команды (`bubble_*`, `highlight_*`, `mouse_*`, `scene_*`, `context_set_*`, `bubble_add_task_*`) и закрывает каждый шаг вызовом `complete_step()`.
- **Управление редактором:** открытие и перезагрузка сцен, выделение и блокировка узлов, переключение главного экрана (2D/3D/Script/Game/Asset Store), сброс раскладки доков, центрирование и зум 2D-вьюпорта, фокус и раскладка 3D-вьюпортов, раскрытие свойств-ресурсов в инспекторе, переключение вкладок TileSet/TileMap.
- **Визуальное направление внимания:** диммеры по окнам, подсветки (highlight) с объединением соседних прямоугольников, анимация «вспышки» (flash), подсветка строк кода, элементов `Tree`/`ItemList`/`TabBar`, свойств и секций инспектора, областей 2D/3D-вьюпорта.
- **Проверка действий пользователя:** задачи (tasks) с покадровым опросом состояния редактора (`_process` → `repeat_callable`), подсчёт нажатий через сигналы, проверка нажатия горячих клавиш редактора (`EditorSettings.is_shortcut`).
- **UI подсказки:** окно bubble с заголовком, текстом (BBCode с автоматической подстановкой иконок классов редактора), кодом, картинками, видео и списком задач. Окно можно перетаскивать и привязывать к контролу; есть подтверждения «закрыть», «помощь», «пропустить шаг».
- **Инфраструктура:** отладочный док (`Ctrl+F10`, флаг `--tour-debug`), режим отладки (`Ctrl+Shift+D`), лог-файл `user://tour.log`, домены переводов (`TranslationServer`), конвертер Markdown → тур, сброс файлов тура, масштабирование под `editor_scale`, платформенные обозначения горячих клавиш.

### Взаимодействие с редактором Godot

**Жизненный цикл плагина (`plugin.gd`, `extends EditorPlugin`).**
- `_enter_tree()` сначала проверяет версию движка через `_is_supported_version()` (сейчас поддерживается только 4.7). При несовпадении показывает `AcceptDialog` и прекращает загрузку.
- Затем подписывается на `get_tree().node_added` (`_handle_editor_node_added`): у контролов из групп `_gdtour_scaled_minsize` / `_gdtour_scaled_offsets` масштабирует `custom_minimum_size`/offset'ы на `EditorInterface.get_editor_scale()`.
- Загружает серию (`_load_tour_series()`), прогресс (`_load_progress_from_disk()`) и переводы (`Utils.load_plugin_translation`, `Utils.register_translation_pot_files`, которая пишет `internationalization/locale/translations_pot_files` в `ProjectSettings` и вызывает `ProjectSettings.save()`).
- Создаёт корневой узел `GDTour` и добавляет его в **`EditorInterface.get_base_control()`**. Внутрь кладёт `Overlays` (это значение также присваивается статическому полю `Tour.overlays`) и `ToursBubble` (меню туров).
- `_add_top_bar_button()` находит панель запуска через `EditorInterfaceAccess.get_node(EditorNodePoints.RUN_BAR)` и вставляет `gdtour_button.tscn` перед ней как соседний узел (`add_sibling` + `move_child`).
- `_ready()` вызывает отложенный `_finalize_plugin_load()`, чтобы не мешать запуску редактора.
  - Включает `interface/editor/single_window_mode` через `EditorInterface.get_editor_settings()`. Если пришлось изменить настройку, перезапускает редактор: `EditorInterface.restart_editor(false)`.
  - Через `EditorInterfaceAccess` находит диалоги редактора из `TOUR_MODE_WINDOW_POINTS` (сигналы, создание узла/скрипта/шейдера, настройки импорта сцены). `_toggle_window_tour_mode()` переводит их в «режим тура»: `transient = true`, `exclusive = false`, без закрытия по Esc. Только так затемнение и bubble остаются доступными поверх модальных окон.
  - Максимизирует окно редактора (`get_viewport().mode = Window.MODE_MAXIMIZED`).
  - Показывает меню туров (если `auto_open_tour_list`) или кнопку GDTour.
  - При флаге `--tour-debug` в `OS.get_cmdline_user_args()` добавляет отладочный док.
- `_input()` обрабатывает две горячие клавиши. `Ctrl+F10` показывает или убирает док `Debugger`: `add_control_to_dock(DOCK_SLOT_LEFT_UL, ...)` / `remove_control_from_docks`. `Ctrl+Shift+D` переключает режим отладки (сигнал `debug_mode_toggled`).
- `_exit_tree()` делает уборку: `_current_tour.clean_up()`, освобождает bubble, overlays и кнопку, убирает корневой узел из `get_base_control()`, удаляет док отладчика, выгружает домены переводов (`Utils.unload_all_translations()`) и возвращает исходные свойства окон-диалогов.
- Запуск тура (`_start_tour()`): загружает перевод тура, делает `load(script_path)` и `TourScript.new(metadata, skip_intro, is_last)`, добавляет тур в `GDTour`. Сигнал `closed` возвращает кнопку, `ended` вызывает `_on_tour_ended()`: тот сохраняет прогресс и вызывает `_continue_tour_series()` (следующий тур стартует без вступления).
- Сброс тура (`_reset_tour_files()`): копирует файлы из папки тура в `res://`, при этом в `.gd/.tscn/.tres` заменяет пути. Затем вызывает `EditorInterface.get_resource_filesystem().scan()` с busy-wait по `is_scanning()` и `EditorInterface.reload_scene_from_path()` для уже открытых сцен (список из `EditorInterface.get_open_scenes()`).

**Как строится и исполняется тур (`tour.gd`, `extends Node`).**
- **Сборка.** Конструктор `_init()` подписывается на `RUN_BAR.stop_pressed` (закрывает нижнюю панель) и `EDITOR_NODE.scene_changed` (`_update_scene_guides`). Затем вызывает пользовательский `_build()`, после него `_build_bookends()` (добавляет приветственный и финальный шаги) и `load_bubble()`.
- **Шаг и команды.** Шаг — это `Array[Command]`. `Command` — обёртка над `Callable` и его параметрами; `force()` делает `await callable.callv(...)`, поэтому команды могут быть асинхронными.
  - Публичные API-методы не выполняют действие сразу, а ставят команду в очередь через `queue_command()`.
  - Команда попадает в один из наборов по `CommandContext`: `TOUR_STEP`, `TOUR_RESET`, `WELCOME_BOOKEND`, `FINALE_BOOKEND`.
  - `complete_step()` добавляет в начало шага `_clean_up_step` и восстановление `BubbleState` (минимальный размер и позиция аватара), в конец — `play_mouse`, и кладёт шаг в `steps`.
- **Навигация.** `set_index()` логирует текст панели Output (`OUTPUT_DOCK_RICH_TEXT`), выполняет команды шага (`_execute_step`) и испускает `step_changed`. Bubble слушает этот сигнал через `set_current_step`. `next()` и `back()` перед переходом вызывают `EditorInterface.stop_playing_scene()`.
- **Очистка шага.** `_clean_up_step()` вызывает `overlays.clean_up()` и `ensure_control_window_dimmer(LAYOUT_ROOT)`: затемнение главного окна создаётся заново на каждом шаге. Также убираются курсор и 3D-гайды.

**Используемые API `EditorInterface`.**
- Сцены: `open_scene_from_path`, `reload_scene_from_path`, `get_open_scenes`, `get_edited_scene_root`.
- Выделение: `get_selection().add_node/clear/get_selected_nodes`.
- Главные экраны: `set_main_screen_editor` (в `context_set*`).
- Запуск сцен: `stop_playing_scene`.
- Настройки: `get_editor_settings()` (`get_shortcut`, `is_shortcut`, `has_shortcut`, `get/set_setting`).
- Тема и масштаб: `get_editor_theme()` (иконки `EditorIcons`), `get_editor_scale()`.
- UI-корень: `get_base_control()`.
- Файловая система: `get_resource_filesystem().scan()`.
- Перезапуск: `restart_editor`.

Блокировка узлов (`scene_toggle_lock_nodes_by_path`) ставит метаданные `_edit_lock_` напрямую. **Undo/redo (`EditorUndoRedoManager`) аддон не использует**: все изменения вносятся напрямую, без записи в историю.

**`gdquest_editor_interface` (`EditorInterfaceAccess`).** Это главный способ добраться до внутренних, неэкспортированных узлов UI редактора. Вызов `EditorInterfaceAccess.get_node(EditorNodePoints.X)` по перечислению `Enums.NodePoint` возвращает конкретный контрол. Используемые точки:
- общие узлы: `RUN_BAR`, `EDITOR_NODE`, `EDITOR_MAIN_WINDOW`, `LAYOUT_ROOT`;
- доки и раскладка: `LAYOUT_DOCK_*`, `SCENE_TREE_LOCAL_TREE`, `FILE_SYSTEM_TREE`, `INSPECTOR_DOCK_INSPECTOR`, `SIGNALS_EDITOR_TREE`, `SIGNALS_DIALOG`, `SCENE_TABS_TAB_BAR`, `OUTPUT_DOCK_RICH_TEXT`, `MENU_BAR_EDITOR_LAYOUT_MENU`;
- редакторы: `SCRIPT_EDITOR`, `CANVAS_ITEM_EDITOR(_VIEWPORT_OVERLAYS/_VIEWPORT_ZOOM_WIDGET)`, `NODE_3D_EDITOR`, `NODE_3D_EDITOR_MAIN_TOOLBAR_VIEW_OPTIONS_BUTTON`, `TILE_SET_*`, `TILE_MAP_*`;
- диалоги из `TOUR_MODE_WINDOW_POINTS`.

Также используются:
- `get_node_3d_viewport(i)` и `get_node_relative(viewport, NODE_3D_EDITOR_VIEWPORT_CAMERA / _SCENE_ROOT / _OVERLAYS / _VIEW_DISPLAY_MENU)` для работы с 3D-вьюпортами;
- `find_inspector_property_by_name()` и `find_inspector_section_by_first_property()` для поиска `EditorProperty` и секций инспектора.

Пункты меню редактора активируются без симуляции кликов: `Utils.activate_menu_option_by_shortcut()` ищет в `PopupMenu` пункт с тем же `Shortcut`, что у `EditorSettings.get_shortcut(name)`, и испускает `id_pressed`. Так работают раскладка по умолчанию (`layout/default`), фокус 3D (`spatial_editor/focus_selection`) и количество 3D-вьюпортов.

**`theme_utils`.** `utils.gd` в `_static_init()` вызывает `ThemeUtils.request_fallback_font(DEFAULT_THEME)` и `ThemeUtils.generate_scaled_theme(...)`: тема `assets/gdtour_theme.tres` получает fallback-шрифт и масштабируется под `editor_scale`. `Utils.get_default_theme()` применяется к `_bubble_anchor` (bubble) и к кнопке GDTour.

**Оверлеи, диммер и подсветка.**
- `Overlays.ensure_control_window_dimmer()` создаёт по одному `Dimmer` (`SubViewportContainer` на весь экран) на каждое `Window`, которому принадлежит контрол. Поэтому затемнение работает и в диалогах.
- Подсветки хранятся как `HighlightData` с ленивыми `rect_getter`/`clamp_getter`/`ref_control_getter`. Прямоугольники пересчитываются каждый кадр: `Dimmer._process` вызывает `Highlight.refresh`. Так подсветка следует за скроллом, ресайзом и перестройкой инспектора.
- `_update_dimmers()` группирует подсветки по окнам и объединяет выровненные соседние прямоугольники. В `Dimmer` каждая подсветка «вырезает» маску (`dimmer_mask.tscn`) в затемняющей плёнке `FilmColorRect`.
- Автоматическое ограничение области (`_create_auto_clamp_getter`) обрезает подсветку по инспектору или по `TabContainer` дока-владельца (`EditorDock`).

**Ожидание действий пользователя.**
- `bubble_add_task(description, repeat, repeat_callable, error_predicate, setup_callable)` создаёт `task_item`. Его `_process` каждый кадр вызывает `repeat_callable(task)` и сравнивает результат с `repeat`.
- Статус задачи меняется через `status_changed`, после чего `DefaultBubble.check_tasks()` делает кнопку «Next» активной (`StepActiveButton`) и заставляет Gobot подмигнуть.
- Готовые проверки:
  - нажатие кнопки: подсчёт через подключение к `button.pressed`; соединение регистрируется в `task.set_connected_callable` для автоотключения;
  - состояние toggle-кнопки, текущая вкладка `TabBar`;
  - выделение узлов: `EditorInterface.get_selection()`;
  - значения `Range`, свойство узла сцены (с `is_equal_approx` для векторных типов);
  - открытая сцена: `get_open_scenes()` и заголовок вкладки сцены;
  - раскрытое свойство-ресурс в инспекторе, инстанс сцены под родителем;
  - позиция 3D-узла относительно `Guide3D` (точное совпадение или попадание в AABB);
  - фокус камеры: `task.is_shortcut_pressed("spatial_editor/focus_selection")` и фокус на оверлее 3D-вьюпорта.
- Помимо опроса, тур реагирует на сигналы редактора: `RUN_BAR.stop_pressed`, `EDITOR_NODE.scene_changed`, `visibility_changed`/`draw` контролов для обновления подсветок.

**Курсор, bubble, отладчик, конвертация, горячие клавиши, метаданные.**
- **Курсор.** `Mouse` (`CanvasLayer`) добавляется в `EDITOR_MAIN_WINDOW` и проигрывает зацикленный `Tween` из накопленных операций (move/press/release/click/bounce). Позиции вычисляются через `Callable` на каждом кадре.
- **Bubble.** `BubbleBase` (`CanvasLayer`) привязывается к контролу редактора через `move_and_anchor()` и подписку на его `resized`. Окно ограничено размером `LAYOUT_ROOT`, его можно перетащить за края.
- **Отладчик.** `Debugger` — док с переключением диммеров и bubble, прозрачностью затемнения (`set_group("dimmer","modulate")`), списком туров и переходом на шаг. Скрипт тура перезагружается в обход кэша через `ResourceInvalidator`.
- **Конвертация.** `convert.gd` — отдельный `SceneTree`-скрипт, генерирует `.gd`-туры из `.md`.
- **Горячие клавиши.** `shortcuts.gd` хранит текстовые обозначения клавиш с учётом macOS.
- **Метаданные.** `gdtour_metadata.gd` — серия туров и вложенный класс `Tour`.

### Скрипты

#### res://addons/godot_tours/convert.gd
- **Назначение:** CLI-утилита: превращает Markdown-черновики туров (`res://tours/**/*.md`) в заготовки GDScript-туров. Запускается как `godot -s` (`extends SceneTree`).
- **Ключевые классы/функции:**
  - `_init()` обходит `.md` через `Utils.fs_find("*.md", "res://tours")` и вызывает `quit()`.
  - `convert_to_test(md_file_path)`: строки `##` становятся `bubble_set_title`, строки `>` — вызовами API (`to_call`), обычный текст — `bubble_add_text` с переводом `**жирного**` в `[b]` и `-` в `[ul]`. Каждый блок закрывается `complete_step()`. Существующий `.gd` не перезаписывается.
  - Константы `HEADER` и `CALLS` — шаблоны кода.
  - Вспомогательные: `to_bubble_title`, `call_gtr`, `join_lines`, `strip_lines_edges`, `sanitize`.
- **Взаимодействие с редактором:** напрямую не взаимодействует; работает только с файлами. В коде есть FIXME: шаблоны с `interface.*` устарели и несовместимы с `EditorInterfaceAccess`.

#### res://addons/godot_tours/gdtour_metadata.gd
- **Назначение:** базовый класс (`RefCounted`) для файла `godot_tours.gd` проекта. Описывает серию туров: заголовок, подзаголовок, описание, флаги `auto_open_tour_list` и `sample_mode`, список туров.
- **Ключевые классы/функции:**
  - `_init()` задаёт домен перевода `gdquest.gdtour.tour_` и вызывает виртуальный `_define()`.
  - `register_tour(id, title_key, title, step_count, script_path, is_locked)` проверяет уникальность id и существование скрипта (кроме заблокированных туров в sample mode).
  - `get_tour(id)`, `is_last_tour(tour)` (учитывает, что следующий тур может быть заблокирован), `get_next_tour(tour)`.
  - Вложенный класс `Tour`: `id`, `title`, `title_key`, `step_count`, `script_path`, `is_locked`, `is_completed`, `is_available()`, `_to_string()`.
- **Взаимодействие с редактором:** напрямую не взаимодействует. Использует `FileAccess.file_exists` и `set_translation_domain`; экземпляр создаётся и читается `plugin.gd`.

#### res://addons/godot_tours/log.gd
- **Назначение:** логгер тура: пишет сообщения с отметкой времени и уровнем в `user://tour.log`. При создании записывает сведения о системе, чтобы пользователь мог приложить лог к обращению в поддержку.
- **Ключевые классы/функции:**
  - `enum Level {DEBUG, INFO, WARN, ERROR, FATAL}`.
  - `debug/info/warn/error/fatal` → `write()` с `flush()`.
  - `reopen()` (дозапись), `clean_up()`, `get_log_full_path()` (`ProjectSettings.globalize_path`).
  - `get_info()`: ОС, драйвер видео, размер, DPI и масштаб экрана, число ядер, локаль.
- **Взаимодействие с редактором:** напрямую не взаимодействует. Тур на каждом шаге пишет сюда текст панели Output, а `Tour.request_log_file()` открывает папку с логом через `OS.shell_show_in_file_manager`.

#### res://addons/godot_tours/plugin.gd
- **Назначение:** точка входа аддона (`EditorPlugin`): проверка версии, загрузка серии туров и прогресса, создание UI GDTour внутри редактора, запуск, сброс и цепочка туров, отладочный док, горячие клавиши.
- **Ключевые классы/функции:**
  - Жизненный цикл: `_enter_tree`, `_ready` → `_finalize_plugin_load`, `_exit_tree`, `_input` (`Ctrl+F10`, `Ctrl+Shift+D`), `_is_supported_version`.
  - Серия туров: `_load_tour_series` (`TOUR_SCRIPT_PATHS`), `_update_tour_list`, `_show_tour_list`/`_hide_tour_list`, `_start_tour`, `_on_tour_ended`, `_continue_tour_series`.
  - Прогресс: `_load_progress_from_disk`/`_save_progress_to_disk` (`var_to_str` в `user://gdtour_progress.save`).
  - Сброс: `_reset_tour`, `_reset_tour_files`.
  - UI и окна: `_add_top_bar_button`, `_toggle_window_tour_mode`, `_toggle_debugger_dock_visible`, `_handle_editor_node_added`, `_scale_control_minsize`/`_scale_control_offsets`.
  - Сигнал `debug_mode_toggled`.
- **Взаимодействие с редактором:**
  - UI: `EditorInterface.get_base_control().add_child(GDTour)`; кнопка вставляется рядом с `EditorNodePoints.RUN_BAR`; док отладчика добавляется через `add_control_to_dock(DOCK_SLOT_LEFT_UL)`/`remove_control_from_docks`.
  - Настройки и окна: `single_window_mode` через `get_editor_settings()` с последующим `restart_editor(false)`; изменение свойств диалогов редактора, найденных через `EditorInterfaceAccess`; максимизация окна редактора.
  - Сцены и файлы: `get_open_scenes`, `reload_scene_from_path`, `get_resource_filesystem().scan()`.
  - Масштаб: `get_editor_scale()`.
  - Подписка на `SceneTree.node_added` (узлы самой редактируемой сцены пропускаются).

#### res://addons/godot_tours/shortcuts.gd
- **Назначение:** набор строковых обозначений горячих клавиш редактора для текста туров: `ctrl`, `context_2d/3d/script`, `run_project`, `run_current`, `stop`, `focus`, `select_mode`, `move_mode`, `rotate_mode`, `top_view`.
- **Ключевые классы/функции:** поля-строки; `_init()` на macOS подменяет `Ctrl` → `Cmd`, `Ctrl+F1..F3` → `Alt+1..3`, `run_current` → `Cmd+R`, `stop` → `Cmd+.`.
- **Взаимодействие с редактором:** напрямую не взаимодействует; это только текст. Доступен в туре как `shortcuts`.

#### res://addons/godot_tours/tour.gd
- **Назначение:** базовый класс любого тура и основной API для описания шагов. Наследник переопределяет `_build()` и вызывает команды. Класс хранит шаги, исполняет их, управляет bubble, курсором, подсветками и 3D-гайдами.
- **Ключевые классы/функции:**
  - **Типы и состояние:**
    - сигналы `step_changed(step_index)`, `ended`, `closed`;
    - классы `Command` (`callable`, `parameters`, `force()`), `BubbleState`, `Guide3DTaskParameters`;
    - перечисления `CommandContext`, `Direction`, `Guide3DCheckMode`, `ViewportLayouts`;
    - поля `steps`, `index` (сеттер `set_index`), `tour_metadata`, `tour_is_last`, `log`, `shortcuts`, `mouse`, `bubble`, статическое `overlays`.
  - **Жизненный цикл:** `_init`, виртуальный `_build`, `_build_bookends`, `_execute_step`, `clean_up`, `_clean_up_step`, `load_bubble(bubble_scene)` (подключает сигналы bubble к `back`, `next`, `close_tour`, `finish_tour`, `request_log_file`), `toggle_visible`.
  - **Навигация:** `set_index`, `back`, `next`, `auto_back`, `auto_next` (для автотестов), `close_tour`, `finish_tour`.
  - **Базовые команды:** `set_command_context`, `queue_command`, `delay_process_frame(frames)`, `complete_step`.
  - **Команды bubble:** `bubble_set_bookend_title`, `bubble_add_bookend_text`, `bubble_set_bookend_button_text`, `bubble_set_title`, `bubble_add_text`, `bubble_add_texture`, `bubble_add_code`, `bubble_add_video`, `bubble_move_and_anchor`, `bubble_set_avatar_at`, `bubble_set_minimum_size_scaled`.
  - **Задачи (tasks):** `bubble_add_task` (общая) и готовые:
    - кнопки и вкладки: `_press_button`, `_toggle_button`, `_set_tab_to_index`, `_set_tab_to_title`, `_set_tab_by_control`, `_set_tileset_tab_by_control`, `_set_tilemap_tab_by_control`;
    - сцена и узлы: `_select_nodes_by_path`, `_set_node_property`, `_open_scene`, `_instantiate_scene`, `_focus_node`;
    - значения и инспектор: `_set_ranges`, `_expand_inspector_property`;
    - 3D: `_node_to_guide` (добавляет `Guide3D` в корень `SubViewport` первого 3D-вьюпорта).
  - **Подсветка:**
    - элементы деревьев и списков: `highlight_scene_nodes_by_name`/`_by_path`, `highlight_filesystem_paths`, `highlight_signals`, `highlight_tilemap_list_item`;
    - инспектор: `highlight_inspector_properties`, `highlight_inspector_section_properties`, `highlight_material_preview`;
    - код: `highlight_code` (`ScriptEditor.goto_line`);
    - контролы и вкладки: `highlight_controls` (устаревает), `highlight_editor_nodes`, `highlight_tabs_index`, `highlight_tabs_title`;
    - вьюпорты: `highlight_canvas_item_editor_rect`, `highlight_spatial_editor_camera_region` (проекция 3D-точек через `Camera3D.unproject_position`).
  - **Курсор мыши:** `mouse_move_by_position`, `mouse_move_by_callable`, `mouse_click_drag_by_position`, `mouse_click_drag_by_callable`, `mouse_bounce`, `mouse_press`, `mouse_release`, `mouse_click`, `ensure_mouse`, `clear_mouse`, `play_mouse`.
  - **Глобальные команды редактора:** `editor_reset_layout`, `editor_reset_state(extra_callback)` (закрывает нижнюю панель, переключает доки на первую вкладку), `context_set(type)` и `context_set_2d/_3d/_script/_game/_asset_store`, `docks_make_visible(dock)`.
  - **Сцена:** `scene_open`, `scene_select_nodes_by_path`, `scene_toggle_lock_nodes_by_path`, `scene_deselect_all_nodes`, `_update_scene_guides`, `clear_guides`.
  - **Виджеты и редакторы:** `canvas_item_editor_center_at`, `canvas_item_editor_zoom_reset`, `canvas_item_editor_flash_area`, `spatial_editor_focus`, `spatial_editor_focus_node_by_paths`, `spatial_editor_change_viewport_layout`, `expand_inspector_resource`, `tileset_tabs_set_by_control`, `tilemap_tabs_set_by_control`.
  - **GUI-команды:** `tabs_set_to_index`, `tabs_set_to_title`, `tabs_set_by_control`, `tree_activate_by_prefix`.
  - **Хелперы:**
    - поиск узлов сцены: `get_scene_node_by_path`, `get_scene_nodes_by_path`, `get_scene_nodes_by_prefix`, `node_find_path`;
    - координаты для курсора: `get_tree_item_center_by_path`/`_by_name`, `get_tilemap_global_rect_pixels`, `get_inspector_property_center`, `get_control_global_center`;
    - вкладки: `find_tabs_title`, `find_tabs_control`;
    - BBCode: `bbcode_generate_icon_image_string`, `bbcode_generate_icon_image_by_name`, `bbcode_wrap_font_size`;
    - прочее: `_close_bottom_panel`, `sort_ascending_by_path`.
  - **Утилиты:** `ptr(resource_path)` (подменённый путь ресурса для текущей локали), `warn`, `request_log_file`.
- **Взаимодействие с редактором:**
  - Основной потребитель `EditorInterfaceAccess` (десятки `NodePoint`, 3D-вьюпорты, `get_node_relative`).
  - `EditorInterface`: `open_scene_from_path`, `reload_scene_from_path`, `get_open_scenes`, `get_edited_scene_root`, `get_selection()`, `set_main_screen_editor`, `stop_playing_scene`, `get_editor_scale`, `get_base_control().get_tree()` (ожидание кадров).
  - Встроенные контролы редактора: `ScriptEditor.get_current_editor().get_base_editor()`, `EditorInspector`/`EditorProperty`, `TabContainer.current_tab` доков, `MenuButton.get_popup()` с `Utils.activate_menu_option_by_shortcut`, `CanvasItemEditor.center_at` и `set_zoom` у виджета зума, `EditorDock.make_visible`.
  - Сигналы: `stop_pressed` у RunBar, `scene_changed` у EditorNode, `pressed` у кнопок (в задачах).
  - Блокировка узлов через мету `_edit_lock_`. Undo/redo не используется.

#### res://addons/godot_tours/utils.gd
- **Назначение:** статические утилиты: файловая система, деревья узлов и `TreeItem`, меню по шорткатам, инспектор, переводы, тема и иконки редактора.
- **Ключевые классы/функции:**
  - Инициализация: `_static_init()` строит масштабированную тему через `ThemeUtils`.
  - Файлы и узлы: `fs_find(pattern, path)` (рекурсивный поиск), `find_children_by_path`, `get_control_dock_owner` (ищет `EditorDock`-предка).
  - Деревья: `get_tree_item_path`, `filter_tree_items`, `find_tree_item_by_name`, `unfold_tree_item`.
  - Меню: `find_menu_option_by_shortcut`, `activate_menu_option_by_shortcut`.
  - Инспектор: `expand_inspector_resource_property` (нажимает кнопку разворачивания у `EditorResourcePicker`).
  - Переводы: `load_plugin_translation`, `load_tour_translation`, `_load_translation` (`.po`/`.mo` из `locale/`), `unload_all_translations`, `register_translation_pot_files`, `set_plugin_translation_domain`, `set_tour_translation_domain`, `get_translation_remapped_path`.
  - Тема и иконки: `get_default_theme`, `precache_icon_image(icon_name)` (копирует иконку из `EditorIcons`, ставит `base_scale = 3.0` и регистрирует фиктивный путь `editor://theme_icons/<name>` через `take_over_path` для `[img]` в `RichTextLabel`).
- **Взаимодействие с редактором:**
  - `EditorInterface.get_editor_settings().get_shortcut()` для поиска пунктов меню; `EditorInterface.get_editor_theme()` для иконок.
  - Работа с классами редактора `EditorInspector`, `EditorProperty`, `EditorResourcePicker`, `EditorDock`.
  - `TranslationServer`: домены `gdquest.gdtour.*`; `ProjectSettings` (POT-файлы, `translation_remaps`).
  - `theme_utils`: `request_fallback_font`, `generate_scaled_theme`.

#### res://addons/godot_tours/assets/guide_3d.gd
- **Назначение:** полупрозрачный 3D-бокс (`Node3D` с дочерним `MeshInstance3D`), который показывает, куда пользователь должен переместить 3D-узел в задаче `bubble_add_task_node_to_guide`.
- **Ключевые классы/функции:** свойства `size`, `box_offset`, `alpha` с сеттерами (`set_size`, `set_box_offset`, `set_alpha` меняют меш, позицию и `albedo_color.a` материала); `get_aabb()` для проверки попадания.
- **Взаимодействие с редактором:** напрямую не взаимодействует. `tour.gd` добавляет его в корень `SubViewport` 3D-вьюпорта редактора (`NODE_3D_EDITOR_VIEWPORT_SCENE_ROOT`): бокс виден в 3D-мире, но не входит в редактируемую сцену. Видимость переключается по `scene_changed`.

#### res://addons/godot_tours/bubble/bubble_base.gd
- **Назначение:** абстрактный (`@abstract`) базовый класс плавающего окна-подсказки (`CanvasLayer`). Отвечает за позиционирование относительно контролов редактора, перетаскивание, анимацию перемещения окна и аватара; объявляет виртуальный контент-API.
- **Ключевые классы/функции:**
  - Сигналы: `prev_step_requested`, `next_step_requested`, `close_requested`, `finish_requested`, `log_requested`.
  - Перечисления: `At` (9 позиций привязки), `AvatarAt` (`LEFT`/`CENTER`/`RIGHT` и `PRIME_*`), `BookendTextStyle`, `State`; класс `StateData`.
  - Позиционирование и анимация: `setup(step_count)`, `move_and_anchor(control, at, margin, extra_offset)`, `_transition_bubble` (`Tween` с собственным интерполятором `_interpolate_position`), `_fit_anchor_position`, `_retransition_bubble`, `set_avatar_at`, `_transition_avatar`.
  - Перетаскивание и размеры: `_input`/`_panel_gui_input` (за край шириной `DRAG_MARGIN`), `_update_content_size`, `_queue_update_height_limits`.
  - Виртуальные методы: `clear` (абстрактный), `set_title`, `add_text`, `add_code`, `add_texture`, `add_video`, `add_custom_element`, `add_task`, `check_tasks`, `set_bookend_*`, `add_bookend_text`, `ensure_minimum_size`, `set_content_translation_domain`, `set_is_debug_mode`, `set_current_step`.
- **Взаимодействие с редактором:**
  - Привязка: по умолчанию к `EditorInterfaceAccess.get_node(LAYOUT_ROOT)`; окно ограничено его размером и следит за сигналом `resized` контрола привязки.
  - Масштаб: `EditorInterface.get_editor_scale()` для отступов и аватара.
  - `EditorInterface.get_edited_scene_root() == self` различает режим работы и правку самой сцены bubble.
  - Тема: `Utils.get_default_theme()`; домен перевода `bubble_ui`.

#### res://addons/godot_tours/bubble/default_bubble.gd
- **Назначение:** стандартная реализация bubble для шагов тура. Два вида: «bookend» (приветствие и финал) и «step» (заголовок, контент, задачи, навигация). Нижняя панель-«ящик» показывает подтверждения закрыть / помощь / пропустить шаг.
- **Ключевые классы/функции:**
  - Навигация: `set_current_step`, `_update_step_controls`, `_update_step_count_display`, `_proceed_bookend_step`, `_try_request_next_step` (в режиме отладки задачи пропускаются; иначе при невыполненных задачах предлагается пропустить шаг), `_try_close_tour`.
  - Контент: `clear`, `set_title`, `add_text`/`add_bookend_text` (регулярка `_class_name_regex` по `ClassDB.get_class_list()` заменяет `[b]ИмяКласса[/b]` на иконку класса редактора), `add_code`, `add_texture`, `add_video` (зацикленный `VideoStreamPlayer`), `add_custom_element`.
  - Задачи: `add_task` → `TasksContainer.create_task`, `check_tasks` (меняет вариацию темы кнопки Next, `_avatar.do_wink()`).
  - Размеры: `ensure_minimum_size`, `_update_height_limits` (расчёт максимальной высоты прокручиваемого контента).
  - Сообщения: `_show_drawer_message`/`_hide_drawer_messages`, `_handle_get_help_meta_clicked` (mailto, лог).
  - Отладка: `set_is_debug_mode` назначает шорткаты `Ctrl+Alt+N` / `Ctrl+B` кнопкам Next/Back.
  - Инструменты дизайнера: `_initialize_editor_tools`/`_destroy_editor_tools`/`_create_editor_toolbar`.
- **Взаимодействие с редактором:**
  - Масштаб и размеры: `EditorInterface.get_editor_scale()`, `get_base_control().size`.
  - Иконки: `Utils.precache_icon_image` (иконки из темы редактора).
  - Тестовая панель для дизайна сцены bubble: если открыть `default_bubble.tscn` в редакторе, создаётся временный `EditorPlugin.new()`, который через `add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, ...)` добавляет панель тестовых кнопок над 2D-вьюпортом.

#### res://addons/godot_tours/bubble/tours_bubble.gd
- **Назначение:** bubble-меню выбора туров («Welcome»). Показывает заголовок и подзаголовок серии, описание и список туров. Есть промо-панель для заблокированных туров (sample mode) и сообщения сброса прогресса (подтверждение, успех, ошибка).
- **Ключевые классы/функции:**
  - Сигналы `tour_start_requested(tour_id)`, `tour_reset_requested(tour_id)`.
  - Контент: `clear`, `set_title`, `set_subtitle`, `add_text`, `add_custom_element`, `add_tour(tour_metadata, sample_mode)`.
  - Выбор и запуск: `_update_selected_tour`, `_try_start_tour`, `_try_reset_tour`.
  - Сообщения и промо: `_show_reset_tour_message`, `show_reset_success_message`, `show_reset_failure_message`, `_show_promo_panel`/`_hide_promo_panel`.
  - Размеры и инструменты: `_update_height_limits`, тестовая панель `_create_editor_toolbar`.
- **Взаимодействие с редактором:** при показе сообщения центрируется на `EditorInterfaceAccess.get_node(LAYOUT_ROOT)`. Использует `EditorInterface.get_editor_scale()` и `get_base_control()`. При открытой сцене `tours_bubble.tscn` добавляет тестовую панель через временный `EditorPlugin`. Методами управляет `plugin.gd`.

#### res://addons/godot_tours/bubble/content/big_title.gd
- **Назначение:** `RichTextLabel` для крупного заголовка меню туров с необязательным подзаголовком.
- **Ключевые классы/функции:** `@export title_text`, `subtitle_text` с сеттерами; `_update_text()` собирает BBCode (`[center]`, цвет и размер подзаголовка из `subtitle_color`/`subtitle_font_size` темы); обновляется при `NOTIFICATION_THEME_CHANGED`.
- **Взаимодействие с редактором:** напрямую не взаимодействует.

#### res://addons/godot_tours/bubble/content/rich_text_label.gd
- **Назначение:** `RichTextLabel` для текста в bubble: ссылки `[url]` открываются в браузере, при наведении курсор меняется на «руку».
- **Ключевые классы/функции:** `_ready()` подключает `meta_clicked` → `OS.shell_open`, `meta_hover_started/ended` → `Input.set_default_cursor_shape`.
- **Взаимодействие с редактором:** напрямую не взаимодействует; меняет глобальную форму курсора.

#### res://addons/godot_tours/bubble/content/texture_rect.gd
- **Назначение:** `TextureRect` для изображений в bubble с ограничением высоты.
- **Ключевые классы/функции:** `max_height` (по умолчанию `300 * editor_scale`), `set_max_height()` после кадра выставляет `custom_minimum_size` по меньшему из лимита и высоты текстуры.
- **Взаимодействие с редактором:** использует только `EditorInterface.get_editor_scale()`.

#### res://addons/godot_tours/bubble/gobot/gobot.gd
- **Назначение:** анимированный маскот Gobot (аватар bubble): выражения лица, подмигивание, наклон и «взгляд» на курсор.
- **Ключевые классы/функции:** `enum Expressions {NEUTRAL, HAPPY, SURPRISED}`; `@export tilt_x/tilt_y` (сдвиг и масштаб глаз, носа, челюсти, рогов, болтов), `expression` (переход в `AnimationTree`), `look_at_cursor`; `do_wink()` (OneShot), `set_scale_multiplier`, `_process` (слежение за мышью).
- **Взаимодействие с редактором:** в `_ready()` масштабирует себя на `EditorInterface.get_editor_scale()`, если не открыт как редактируемая сцена.

#### res://addons/godot_tours/bubble/layout/confirm_drawer.gd
- **Назначение:** сообщение-«ящик» с двумя кнопками (подтверждение или отмена). Используется для «закрыть тур», «помощь», «пропустить шаг», «сбросить тур».
- **Ключевые классы/функции:** наследует `message_drawer.gd`; сигналы `left_button_pressed`, `right_button_pressed`; `@export left_button_text`/`right_button_text` с сеттерами.
- **Взаимодействие с редактором:** напрямую не взаимодействует; проверка `get_edited_scene_root() == self` отключает логику при правке сцены.

#### res://addons/godot_tours/bubble/layout/content_container.gd
- **Назначение:** вертикальный контейнер элементов контента bubble (текст, код, картинки, видео).
- **Ключевые классы/функции:** `@export paragraph_separation` (масштабируется на `editor_scale`), `add_element`, `fit_element_to_width(element, aspect_ratio)` (для видео), `clear_elements`.
- **Взаимодействие с редактором:** только `EditorInterface.get_editor_scale()`.

#### res://addons/godot_tours/bubble/layout/inform_drawer.gd
- **Назначение:** информационное сообщение с одной кнопкой «OK» (успешный или неудачный сброс тура).
- **Ключевые классы/функции:** наследует `message_drawer.gd`; сигнал `accept_button_pressed`; `@export accept_button_text`.
- **Взаимодействие с редактором:** напрямую не взаимодействует.

#### res://addons/godot_tours/bubble/layout/message_drawer.gd
- **Назначение:** базовая панель сообщения с текстом (`RichTextLabel`), блоком кнопок и ограничением высоты текста, чтобы bubble не вылезал за экран.
- **Ключевые классы/функции:** сигнал `message_meta_clicked`; `@export message`, `maximum_message_height`; `get_base_height`, `get_content_height`, `_update_message_height`/`_check_message_height` (по сигналам `finished`/`draw` с защитой от зацикливания).
- **Взаимодействие с редактором:** напрямую не взаимодействует.

#### res://addons/godot_tours/bubble/layout/shrinkable_container.gd
- **Назначение:** контейнер, который сжимает содержимое до `maximum_height` и показывает прокрутку (`ScrollContainer`), когда контент шага слишком высокий.
- **Ключевые классы/функции:** `maximum_height`, `_get_minimum_size()` (минимальная высота ограничивается сверху), `_sort_children()` (`fit_child_in_rect`), `get_content_height()`.
- **Взаимодействие с редактором:** напрямую не взаимодействует.

#### res://addons/godot_tours/bubble/lists/task_item.gd
- **Назначение:** элемент задачи в bubble. Главный механизм ожидания действий пользователя: каждый кадр опрашивает условие выполнения и отображает статус и прогресс.
- **Ключевые классы/функции:**
  - `enum Status {NOT_DONE, DONE, ERROR}`; сигнал `status_changed`; свойства `description`, `error`, `repeat`.
  - Опрос: `set_repeat_callable`, `set_error_predicate`, `_process()` (вызывает `repeat_callable(self)` и `error_predicate(self)`, выставляет статус).
  - Шорткаты: `_input()` копит нажатые клавиши за кадр; `is_shortcut_pressed(shortcut_name)` проверяет их.
  - Управление: `set_current_status`, `is_done`; `set_connected_callable(signal, callable)` автоматически отключает соединения в `NOTIFICATION_PREDELETE`.
- **Взаимодействие с редактором:** `is_shortcut_pressed` использует `EditorInterface.get_editor_settings().has_shortcut()/is_shortcut()` для проверки, что пользователь нажал именно шорткат редактора (например, `spatial_editor/focus_selection`). При правке сцены опрос отключается.

#### res://addons/godot_tours/bubble/lists/tasks_container.gd
- **Назначение:** список задач текущего шага.
- **Ключевые классы/функции:** `create_task(description, repeat, repeat_callable, error_predicate, setup_callable)` (инстанцирует `task_item.tscn` и вызывает `setup_callable(task)`, например для подписки на `button.pressed`), `has_tasks`, `check_tasks` (все ли выполнены), `clear_tasks`.
- **Взаимодействие с редактором:** напрямую не взаимодействует; условия задач обращаются к редактору сами.

#### res://addons/godot_tours/bubble/lists/tour_item.gd
- **Назначение:** строка тура в меню: номер, название, «шаги N / N», галочка завершения, замок (sample mode), иконка сброса прогресса.
- **Ключевые классы/функции:** сигналы `pressed`, `reset_pressed`; свойства `tour_metadata`, `tour_progress` (пока не используется), `sample_mode`; `set_selected`; отрисовка состояний выделения и наведения (`_content_draw` со styleboxes `selected_overlay`/`hover_overlay`); `_update_checkbox`, `_update_labels`, `_update_lock`, `_update_reset_icon`.
- **Взаимодействие с редактором:** напрямую не взаимодействует.

#### res://addons/godot_tours/bubble/lists/tours_container.gd
- **Назначение:** список туров с выбором одного элемента.
- **Ключевые классы/функции:** сигналы `tour_selected`, `reset_requested(tour)`; `create_tour(tour_metadata, sample_mode)`, `has_tours`, `clear_tours`, `_select_tour`, `_reset_tour`, `get_selected_tour`.
- **Взаимодействие с редактором:** напрямую не взаимодействует.

#### res://addons/godot_tours/debugger/debugger.gd
- **Назначение:** отладочный док для авторов туров. Включается по `Ctrl+F10` или флагу `--tour-debug`.
- **Ключевые классы/функции:**
  - Константы и настройка: `CLI_OPTION_DEBUG = "--tour-debug"`, `DIMMER_GROUP`; `setup(plugin_path, overlays, series_metadata, tour, debug_mode_toggled_signal)`.
  - Управление туром: `populate_tours_item_list` (UID → путь через `ResourceUID`), `_start_selected_tour` (перезагружает скрипт тура через `ResourceInvalidator` и создаёт тур), `_jump_to_step` (`tour.index = ...`), `_update_spinbox_step_count`.
  - Оверлеи: `_on_overlay_alpha_h_slider_value_changed` (`get_tree().set_group("dimmer", "modulate", ...)`).
  - Отладка: `set_is_debug_mode`.
  - Переключатели видимости диммеров, bubble и тура.
- **Взаимодействие с редактором:** `plugin.gd` встраивает его в док редактора (`add_control_to_dock(DOCK_SLOT_LEFT_UL)`). Сам док подсвечивается в оверлеях: `overlays.add_highlight_to_control(self)` и повторная подсветка по сигналу `cleaned_up`, чтобы оставаться доступным под затемнением. Использует `EditorInterface.get_edited_scene_root()`.

#### res://addons/godot_tours/debugger/resource_invalidator.gd
- **Назначение:** принудительная перезагрузка кэшированного ресурса (скрипта тура) без перезапуска редактора, чтобы правки тура применялись сразу.
- **Ключевые классы/функции:** статическая `resource_force_editor_reload(resource_path)`: копирует файл во временный `<path>_temp_<rand>.<ext>`, загружает с `ResourceLoader.CACHE_MODE_REPLACE`, делает `take_over_path(resource_path)` и удаляет временный файл.
- **Взаимодействие с редактором:** косвенно, через кэш ресурсов редактора (`ResourceLoader`, `take_over_path`).

#### res://addons/godot_tours/editor/gdtour_button.gd
- **Назначение:** кнопка «GDTour» в верхней панели редактора, открывает меню туров.
- **Ключевые классы/функции:** `_ready()` назначает `theme = Utils.get_default_theme()`, если сцена не редактируется.
- **Взаимодействие с редактором:** `plugin.gd` вставляет её рядом с `EditorNodePoints.RUN_BAR` и подключает `pressed` к `_show_tour_list`; использует тему из `theme_utils`.

#### res://addons/godot_tours/mouse/mouse.gd
- **Назначение:** анимированный «призрачный» курсор (`CanvasLayer`). Показывает, куда кликнуть или что перетащить: зацикленная последовательность операций на `Tween`.
- **Ключевые классы/функции:** поля `first_from`, `last_to`, `operations`, `tween`; `play()` (появление, операции, пауза, исчезновение, `set_loops()`); `add_move_operation(from, to)` (скорость зависит от расстояния и ширины `base_control`; позиции пересчитываются каждый кадр, чтобы учесть скролл и ресайз), `add_press_operation(texture)`, `add_release_operation()`, `add_click_operation(loops)`, `add_bounce_operation(loops, at)`.
- **Взаимодействие с редактором:** `tour.gd` добавляет его в `EDITOR_MAIN_WINDOW` (через `EditorInterfaceAccess`). Использует `EditorInterface.get_editor_scale()` и `get_base_control()`.

#### res://addons/godot_tours/overlays/overlays.gd
- **Назначение:** менеджер затемнения и подсветок поверх UI редактора: диммеры по окнам, учёт подсветок, их объединение, автоматическое ограничение области и набор специальных подсветок для элементов редактора.
- **Ключевые классы/функции:**
  - Сигнал и класс: `cleaned_up`; класс `HighlightData` (`ref_control`/`ref_control_getter`, `rect_getter`, `clamp_getter`, `play_flash`, `do_grow`, `get_area`, `connect_updater`).
  - Диммеры: `clean_up`, `ensure_control_window_dimmer`, `toggle_dimmers`, `queue_update_dimmers`/`_update_dimmers` (группировка по окнам и объединение выровненных соседних прямоугольников).
  - Добавление и удаление подсветок: `add_highlight_to_control`, `add_highlight_to_dynamic_control`, `remove_highlights_from_control`/`_dynamic_control`, `_create_auto_clamp_getter`.
  - Общие подсветки: `highlight_controls`, `highlight_editor_nodes`, `flash_control_area`, `flash_editor_node_area`.
  - Стандартные контролы: `highlight_tab_index` (учитывает прокрутку вкладок и кнопки смещения), `highlight_tab_title`, `highlight_list_item`, `highlight_tree_items` (раскрывает узлы и прокручивает к элементу), `highlight_code` (фокус, центрирование, каретка).
  - Инспектор: `highlight_inspector_property` (раскрывает `EditorInspectorSection`, скроллит инспектор), `highlight_inspector_section_property`.
- **Взаимодействие с редактором:**
  - `EditorInterfaceAccess`: `get_node(INSPECTOR_DOCK_INSPECTOR / LAYOUT_ROOT / SCENE_TABS_TAB_BAR)`, `find_inspector_property_by_name`, `find_inspector_section_by_first_property`.
  - Прямая работа с контролами редактора: `Tree.scroll_to_item`, `TreeItem.collapsed`, `CodeEdit.set_line_as_center_visible`/`set_caret_line`, `EditorInspector.scroll_vertical`/`ensure_control_visible`.
  - Диммеры добавляются как дочерние к `Window` редактора, в том числе к диалогам.
  - Учитываются `EditorDock`, `editor_scale`, сигналы `visibility_changed` и `draw` контролов.

#### res://addons/godot_tours/overlays/dimmer/dimmer.gd
- **Назначение:** полноэкранное затемнение одного окна (`SubViewportContainer`). Подсветки «вырезают» в плёнке `FilmColorRect` прозрачные маски; здесь же создаются вспышки.
- **Ключевые классы/функции:** `_enter_tree` (`PRESET_FULL_RECT`), `_process` (каждый кадр `highlight.refresh()`), `add_highlight(getters, play_flash)`, `clear_highlights`, `_refresh_highlight_mask`, `add_mask`, `add_flash_area(control, rect)`; пулы `Highlight`, `FlashArea`, масок для повторного использования.
- **Взаимодействие с редактором:** косвенно: `Overlays` добавляет его в окно редактора; поверх него рисуются подсветки, привязанные к контролам редактора.

#### res://addons/godot_tours/overlays/flash_area/flash_area.gd
- **Назначение:** мигающий прямоугольник (`ColorRect` с анимацией `flash`) над областью редактируемой сцены в вьюпорте (например, `canvas_item_editor_flash_area`).
- **Ключевые классы/функции:** `setup(ref_control, target_rect)` (подписка на `ref_control.draw`), `refresh()` переводит `target_rect` в экранные координаты через `scene_root.get_viewport().get_screen_transform()` и обрезает по контролу.
- **Взаимодействие с редактором:** использует `EditorInterface.get_edited_scene_root()` и трансформ вьюпорта редактируемой сцены, чтобы вспышка совпадала с объектами в 2D-редакторе.

#### res://addons/godot_tours/overlays/highlight/highlight.gd
- **Назначение:** рамка подсветки (`Panel` со стилем `highlight.tres`) вокруг кликабельной области. Объединяет прямоугольники от нескольких геттеров и может проиграть вспышку.
- **Ключевые классы/функции:** сигнал `rect_changed`; статический `_highlight_style_scaled` и `_scale_stylebox_with_editor` (толщина рамки, радиусы и отступы умножаются на `editor_scale`); `setup(rect_getters)`, `flash()`, `refresh()` (объединяет прямоугольники, задаёт позицию, размер и видимость).
- **Взаимодействие с редактором:** `EditorInterface.get_editor_scale()`, проверка `get_edited_scene_root()`; геттеры прямоугольников указывают на контролы редактора.

#### res://addons/godot_tours/promo/content/course_box.gd
- **Назначение:** промо-блок курса (обложка и кнопка-ссылка) в промо-панели меню туров для заблокированных туров в sample mode.
- **Ключевые классы/функции:** `@export course_cover`, `course_cta`, `course_link` с сеттерами; `_update_cover`, `_update_link` (задаёт `text`/`uri` у `LinkButton` и вызывает `_update_text_buffer()`).
- **Взаимодействие с редактором:** масштабирует `icon_size`/`icon_separation` кнопки на `EditorInterface.get_editor_scale()`.

#### res://addons/godot_tours/promo/content/course_button.gd
- **Назначение:** `LinkButton` с иконкой справа от текста; минимальный размер считается по тексту.
- **Ключевые классы/функции:** `@export icon`, `icon_size`, `icon_separation`; `_draw()` (рисует иконку), `_update_text_buffer()` (`TextLine` со шрифтом темы), `_update_custom_size()`.
- **Взаимодействие с редактором:** только `get_editor_scale()` при правке сцены.

#### res://addons/godot_tours/promo/content/quote_box.gd
- **Назначение:** блок цитаты или отзыва (текст, автор, должность, аватар) для промо-панели.
- **Ключевые классы/функции:** `@export quote_text`, `quote_author`, `quote_author_icon`, `quote_author_title` с сеттерами; `_update_quote`, `_update_author`.
- **Взаимодействие с редактором:** напрямую не взаимодействует.
