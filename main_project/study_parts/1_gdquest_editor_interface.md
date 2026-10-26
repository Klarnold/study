## gdquest_editor_interface (res://addons/gdquest_editor_interface)

### На какие задачи направлены скрипты

`gdquest_editor_interface` (внутреннее сокращение — **EIA**, Editor Interface Access) — это статическая библиотека без `plugin.cfg` и без `EditorPlugin`. Её подключают через `preload()` из других аддонов (в проекте — `godot_tours`). Она решает одну проблему. Публичный API Godot (`EditorInterface`) даёт доступ лишь к немногим узлам редактора: базовому `Control`, инспектору, доку файловой системы, главному экрану и тостеру. Внутренние виджеты (кнопки тулбаров, доки, диалоги, вьюпорты, вкладки) не экспортированы, а многие их классы (`CanvasItemEditor`, `SceneTreeDock`, `EditorLog` и др.) вообще не доступны из скриптов. Поэтому EIA описывает каждый нужный элемент UI декларативно: от известной опорной точки к целевому узлу ведёт цепочка шагов поиска, а каждому элементу назначен постоянный идентификатор — значение перечисления `NodePoint`. Узел ищется по этому идентификатору по требованию, проверяется по ожидаемому классу и кэшируется.

Основные задачи:

- **Идентификаторы для элементов UI редактора.** Перечисление `Enums.NodePoint` содержит сотни точек, сгруппированных по числовым диапазонам: общие узлы, раскладка и слоты доков, меню, переключатель главных экранов, панель запуска, вкладки сцен, диалоги, доки, главные экраны 2D/3D/Script/Game/AssetLib, переиспользуемые компоненты.
- **Устойчивый поиск узлов во внутреннем дереве UI** по классу, индексу, пути, сигналам, иконкам темы, шорткатам и названиям вкладок. Поиск не должен ломаться при смене языка, раскладки доков, «плавающих» окон и отличиях между версиями Godot.
- **Каскадное разрешение зависимостей.** Одна точка строится от другой (`base_reference`), а некоторые требуют заранее разрешить и закэшировать набор других точек (`prefetch_references`).
- **Групповое разрешение.** Тулбары из десятков похожих кнопок разбираются за один проход (`MultiDefinition`), и все результаты кэшируются разом.
- **Относительное разрешение для переиспользуемых компонентов,** которые существуют во многих экземплярах: `ScriptTextEditor`, `TextEditor`, `EditorHelp`, `Node3DEditorViewport`, `EditorZoomWidget`, `CreateDialog`. Для них обязателен узел-контекст.
- **Вспомогательные функции для туров и оверлеев:** получить 3D-вьюпорт по индексу, проверить фокус редактора скриптов, получить вкладку редактора скриптов, найти `TabBar` и индекс вкладки дока, найти `EditorProperty` или секцию инспектора по имени свойства.
- **Самодиагностика.** `test_resolve()` прогоняет разрешение всех точек и выводит статистику по разделам.

### Взаимодействие с редактором Godot

**Используемые API редактора и движка:**

- Точки входа `EditorInterface`:
  - `get_base_control()` — корневой `Panel` GUI (`LAYOUT_ROOT`); через `.get_window()` получается главное окно (`EDITOR_MAIN_WINDOW`), через `.get_tree()` — `SceneTree` редактора;
  - `get_resource_filesystem()` (`EDITOR_FILE_SYSTEM`);
  - `get_editor_main_screen()` (`MAIN_VIEW_CONTAINER_BOX`);
  - `get_file_system_dock()`, `get_inspector()`, `get_editor_toaster()`, `get_selection()`;
  - `get_editor_theme()` — сравнение иконок в группе `"EditorIcons"`;
  - `get_editor_settings().get_shortcut()` — поиск пунктов `PopupMenu` по шорткату.
- Обход дерева: `get_children()`, `get_child(i)` (в том числе с отрицательным индексом), `find_children("", Class, recursive, owned=false)`, `find_child(name, false, false)`, `get_node_or_null(path)`, `get_parent()`.
- Проверка типов через `ClassDB.is_parent_class(node.get_class(), "Имя")`. Ожидаемые типы хранятся **строками**, потому что многие классы редактора (`CanvasItemEditor`, `EditorDock`, `SideDockTabContainer` и др.) недоступны как `GDScriptNativeClass`.
- Интроспекция сигналов: `Signal.get_connections()`, затем `Callable.get_object()` (кто подписан) или `Callable.get_method()` (имя внутреннего метода C++ вида `"EditorRunBar::play_main_scene"`).
- Переводы: `TranslationServer.get_or_add_domain("godot.editor").translate()`. Нужно для узлов и вкладок с локализуемыми именами ("Tiles", "Patterns", "Terrains", "Tile Sources").
- Прочее: `TabContainer.get_tab_bar()`, `get_tab_idx_from_control()`, `ConfirmationDialog.get_ok_button()` и `get_cancel_button()`, `MenuButton.get_popup()`, `Window.get_focused_window()`, синглтон `AudioServer`, скрытый метод `EditorInspectorSection.get_vbox()` через `call()`.

**Приёмы поиска узлов** (шаги из `utils/eia_resolver_types.gd`):

1. **По классу ребёнка** — `GetChildTypeStep(тип, индекс, exact)`: N-й прямой потомок данного класса или его наследника; отрицательный индекс считает с конца.
2. **По индексу** — `GetChildIndexStep(i)`: например, «корень раскладки» = `get_child(0)`.
3. **По классу потомка на любой глубине** — `FindNodeTypeStep`.
4. **По пути** — `GetNodePathStep(path, translate)`: например, `"DockVSplitMain/DockHSplitMain/DockVSplitLeftL/DockSlotLeftUL"`, а при `translate=true` повторная попытка с переведённым путём.
5. **Вверх по иерархии** — `GetParentCountStep(n)`.
6. **Через подписчиков сигнала** — `GetSignalTypeStep(signal, type)` и `Utils.object_get_signal_type()`. Скрытые синглтон-узлы ищутся по тому, кто подписан на известный сигнал. Например, `SceneTreeDock` подписан на `EditorSelection.selection_changed`, `AnimationPlayerEditor` — на `SceneTree.node_removed`, `EditorAudioBuses` — на `AudioServer.bus_layout_changed`, `InspectorDock` — на `FileSystemDock.files_moved`, `HistoryDock` — на `EditorNode.scene_changed`.
7. **Внутри** `WindowWrapper` — `GetWindowWrappedTypeStep`: узел может быть встроен в окно редактора или «выплывать» в отдельное `Window`; проверяются обе позиции.
8. **Пользовательская логика** — `DoCustomStep` и `DoCustomMultiStep` с `Callable`.
9. **Валидаторы** не меняют узел, а возвращают `null` при несоответствии:
   - `HasEditorIconStep` — иконка `Button` совпадает с иконкой темы;
   - `HasSignalCallableStep` — к сигналу подключён метод с указанным именем;
   - `HasTabsNamesStep` — названия вкладок `TabBar`/`TabContainer` совпадают (переведённые или исходные).

**Механизм resolver и порядок инициализации:**

1. Внешний код выполняет `preload("res://addons/gdquest_editor_interface/editor_interface_access.gd")`. Этот файл предзагружает `utils/eia_enums.gd` и `utils/eia_resolver.gd`.
2. `Enums._static_init()` строит словарь «числовое значение → PascalCase-имя ключа» (`NODE_3D_EDITOR` → `"Node3dEditor"`).
3. `Resolver._static_init()` вызывает `_reload_node_point_definitions()`. Функция через `DirAccess` рекурсивно обходит папку `library/` (путь вычисляется относительно `resource_path` скрипта `Types`), загружает каждый `.gd` и через `get_script_constant_map()` собирает внутренние классы, которые наследуют `Types.Definition`. Имя класса без суффикса `Def` становится ключом `_library_definition_map`. Скрипты удерживаются в `_library_cache`, чтобы их не освободили.
4. При загрузке библиотечных скриптов подтягивается `utils/eia_resolver_utils.gd`. Его `_static_init()` подписывается на `EditorInterface.get_base_control().theme_changed` и строит список имён иконок темы.
5. Вызов `EIA.get_node(NodePoint.X)` передаётся в `Resolver.resolve_node()`. Порядок действий:
   - проверка кэша;
   - получение имени точки и экземпляра её определения;
   - валидация: есть шаги, `prefetch` не сочетается с `skip_cache`, контекст соответствует `relative_node_type`;
   - разрешение `prefetch_references` (всегда с кэшем);
   - рекурсивное разрешение `base_reference`;
   - последовательное применение `resolver_steps`;
   - проверка результата по `node_type`;
   - запись в кэш.

**Где сохраняются найденные элементы UI.** Узлы не пишутся в свойства объектов. Они хранятся в статических словарях резолвера:

- `_node_cache: Dictionary[NodePoint, Node]` — абсолютные точки;
- `_context_node_cache: Dictionary[instance_id, Dictionary[NodePoint, Node]]` — относительные точки по узлу-контексту.

Определения (`Definition`) хранят только описание поиска: `node_type`, `base_reference`, `prefetch_references`, `relative_node_type`, `resolver_steps`, а у `MultiDefinition` ещё `node_type_map`. Кэш доков нужен функции `Utils.dock_get_locations()`: она читает слоты доков через `Resolver.get_node_cached()`, поэтому определения доков перечисляют эти слоты в `prefetch_references`.

**Использование снаружи (godot_tours):**

- `addons/godot_tours/tour.gd`, `plugin.gd`, `overlays/overlays.gd`, `bubble/bubble_base.gd`, `bubble/tours_bubble.gd` и файлы туров (`tours/103_introduction_to_3d/...`) объявляют `const EditorInterfaceAccess := preload(...)` и `const EditorNodePoints := EditorInterfaceAccess.Enums.NodePoint`, а затем вызывают `get_node(...)`.
- Примеры из `tour.gd`:
  - подписка на `RUN_BAR.stop_pressed` и `EDITOR_NODE.scene_changed`;
  - сброс раскладки через `MENU_BAR_EDITOR_LAYOUT_MENU`, который активирует пункт по шорткату `layout/default`;
  - выбор первой вкладки у всех `LAYOUT_DOCK_*`;
  - управление камерой 2D через `CANVAS_ITEM_EDITOR.center_at()` и `CANVAS_ITEM_EDITOR_VIEWPORT_ZOOM_WIDGET.set_zoom()`;
  - доступ к 3D-камере через `get_node_3d_viewport(i)` и `get_node_relative(..., NODE_3D_EDITOR_VIEWPORT_CAMERA)`;
  - переключение вкладок `TILE_MAP_DOCK_TABS` и `TILE_SET_DOCK_TABS`.
- `overlays.gd` подсвечивает элементы по `NodePoint`, а свойства инспектора находит через `find_inspector_property_by_name()` и `find_inspector_section_by_first_property()`.
- `bubble_base.gd` привязывает «пузыри» к `LAYOUT_ROOT`.

**Замеченные особенности и возможные проблемы в коде:**

- `get_node()` и `get_node_relative()` печатают `LOG Got editor node: ...` при каждом вызове.
- `_get_node_point_definition()` при каждом разрешении без кэша создаёт новый экземпляр определения через `.new()`.
- В `_resolve_multi_node()` при наличии `context_node` все результаты пишутся под ключом запрошенной `node_point`, а не `expected_node_point`. Каждый следующий результат перезаписывает предыдущий.
- В `GetWindowWrappedTypeStep` первый `push_error` не подставляет аргументы в `%d`.
- В `HasTabsNamesStep` строка предупреждения содержит 3 плейсхолдера при 5 аргументах. Если вкладки не совпадут, форматирование, вероятно, завершится ошибкой.
- `_context_node_cache` никогда не очищается, поэтому записи для удалённых узлов-контекстов накапливаются.
- В `node_3d_editor.gd` есть определение `Node3dEditorMainToolbarCameraButtonDef` без соответствующего значения enum. Оно мёртвое.
- В `docks_audio.gd` переменная `st` вычисляется, но не используется.

### Скрипты

#### res://addons/gdquest_editor_interface/editor_interface_access.gd

- **Назначение:** публичный фасад библиотеки, через который внешний код получает узлы редактора. Также содержит хелперы для часто нужных элементов и тест разрешения.
- **Ключевые классы/функции:**
  - константы `Enums` и `Resolver`;
  - `get_node(node_point, skip_cache)` и `get_node_relative(base_node, node_point, skip_cache)` — делегируют работу в `Resolver.resolve_node()` и логируют путь найденного узла;
  - `get_node_class(node_point)` — имя ожидаемого класса;
  - `get_node_3d_viewport(index)`;
  - `is_script_editor_active()`;
  - `get_script_editor_tab(index)`;
  - `get_dock_tabs(dock: EditorDock)` и `get_dock_tab_index(dock)`;
  - `find_inspector_property_by_name(inspector, name)`;
  - `find_inspector_section_by_first_property(inspector, name)`;
  - `test_resolve(skip_cache)` и `_test_resolve_relative()`.
- **Взаимодействие с редактором:**
  - `get_node_3d_viewport()` берёт `NODE_3D_EDITOR_VIEWPORTS`, у его `get_child(0)` выбирает два `SplitContainer` и собирает в них `find_children("", "Node3DEditorViewport", false, false)`.
  - `is_script_editor_active()` сравнивает `SCRIPT_EDITOR.get_window()` с `get_tree().root`. Для встроенного редактора проверяется `is_visible_in_tree()`, для плавающего — совпадение с `Window.get_focused_window()`.
  - `get_script_editor_tab()` возвращает `get_tab_control(i)` у `SCRIPT_EDITOR_CONTAINER_TABS`.
  - Функции доков проверяют, что родитель дока — `TabContainer` (через `ClassDB.is_parent_class`), и возвращают его `get_tab_bar()` или `get_tab_idx_from_control()`.
  - Поиск в инспекторе выполняется перебором: `find_children("", "EditorProperty", true, false)` с проверкой `get_edited_property()`, а для секций — `find_children("", "EditorInspectorSection")`, затем скрытый `call("get_vbox")` и сравнение первого `EditorProperty`.
  - `test_resolve()` перебирает все ключи `NodePoint`. Для относительных точек тест подставляет контекст по диапазонам: `CreateDialog` из `SCENE_DOCK_CREATE_DIALOG`, `EditorZoomWidget` из `TILE_MAP_TILES_ATLAS_VIEW_ZOOM_WIDGET`, вкладки `EditorHelp`/`TextEditor`/`ScriptTextEditor` из `SCRIPT_EDITOR_CONTAINER_TABS`, первый `Node3DEditorViewport`.

#### res://addons/gdquest_editor_interface/utils/eia_enums.gd

- **Назначение:** перечисление `NodePoint` — постоянные идентификаторы всех известных элементов UI — и сопоставление «значение → имя определения».
- **Ключевые классы/функции:** диапазоны `enum NodePoint`:
  - `1–16_xxx` — общие узлы, раскладка, слоты доков (`LAYOUT_DOCK_LEFT_LEFT_TOP` … `LAYOUT_DOCK_HIDDEN_CONTAINER`), меню, переключатель главных экранов, панель запуска, вкладки сцен, прочее;
  - `100_000+` — диалоги;
  - `200_000+` — доки (FileSystem, Inspector, Scene, Signals, Output, SpriteFrames, TileMap, TileSet и др.);
  - `1_000_000+` — `CanvasItemEditor`;
  - `2_000_000+` — `Node3DEditor`;
  - `3_000_000+` — `ScriptEditor`;
  - `4_000_000` — `GameView`;
  - `5_000_000` — `AssetStore`;
  - `100_000_000+` — переиспользуемые компоненты; «корневые» значения компонентов закомментированы, потому что они передаются как контекст.

  Также в файле: `_static_init()` строит `_node_point_name_map` через `key.to_pascal_case()`, а `get_node_point_name(value)` возвращает имя.
- **Взаимодействие с редактором:** напрямую не взаимодействует.

#### res://addons/gdquest_editor_interface/utils/eia_resolver.gd

- **Назначение:** ядро системы. Загружает библиотеку определений, разрешает точки в узлы и кэширует результат.
- **Ключевые классы/функции:**
  - `LIBRARY_ROOT = "../library"`;
  - статические `_library_cache`, `_library_definition_map`, `_node_cache`, `_context_node_cache`;
  - `_static_init()` и `_reload_node_point_definitions()`;
  - `resolve_node(node_point, context_node, skip_cache)`;
  - `_resolve_single_node()` и `_resolve_multi_node()`;
  - `get_node_cached()`, `get_node_class()`, `is_node_relative()`;
  - `_get_library_root()` — вычисляет путь через `(Types as Script).resource_path`;
  - `_get_node_point_definition(name)` — создаёт `.new()` определения;
  - `_is_node_point_definition(script)` — обходит `get_base_script()` до `Types.Definition`;
  - `_get_context_cache(node)`.
- **Взаимодействие с редактором:** сам не обращается к `EditorInterface`; применяет шаги определений к дереву UI редактора. Ведёт файловый обход `res://` через `DirAccess`. Проверяет типы через `ClassDB.is_parent_class()` и пишет ошибки `[EIA] ...` через `push_error`. В режиме `MultiDefinition` число результатов должно совпадать с `node_type_map`, каждый результат проверяется по своему типу и кэшируется под своей точкой.

#### res://addons/gdquest_editor_interface/utils/eia_resolver_types.gd

- **Назначение:** базовые типы определений и готовые шаги поиска и валидации, из которых строится вся библиотека.
- **Ключевые классы/функции:**
  - `Definition` — поля `node_type`, `prefetch_references`, `base_reference = -1`, `relative_node_type`, `resolver_steps`;
  - `MultiDefinition` — поле `node_type_map`;
  - `Step` с методами `resolve()` и `resolve_multi()`; базовая реализация `resolve_multi()` применяет `resolve()` поэлементно;
  - `DoCustomStep`, `DoCustomMultiStep`;
  - `GetChildTypeStep`, `GetChildIndexStep`, `FindNodeTypeStep`, `GetNodePathStep`, `GetParentCountStep`, `GetSignalTypeStep`, `GetWindowWrappedTypeStep`;
  - валидаторы `HasEditorIconStep`, `HasSignalCallableStep`, `HasTabsNamesStep`.
- **Взаимодействие с редактором:**
  - `GetNodePathStep` при неудаче переводит путь через `TranslationServer.get_or_add_domain("godot.editor")`.
  - `GetSignalTypeStep` ищет объект нужного класса среди `get_connections()` сигнала.
  - `GetWindowWrappedTypeStep` проверяет, что узел — `WindowWrapper`, и ищет цель среди прямых детей, затем в `get_child(0)` (окне), затем в его третьем ребёнке `MarginContainer`.
  - `HasEditorIconStep` сравнивает `Button.icon` с `EditorInterface.get_editor_theme().get_icon(name, "EditorIcons")`.
  - `HasTabsNamesStep` сравнивает `get_tab_title(i)` с исходной и переведённой строкой. Обе нужны, потому что редактор использует то `TTR()`, то `TTRC()`.

#### res://addons/gdquest_editor_interface/utils/eia_resolver_utils.gd

- **Назначение:** утилиты для пользовательских шагов: сигналы, шорткаты, иконки темы, обнаружение всех мест размещения доков.
- **Ключевые классы/функции:**
  - `_static_init()`, `_build_icon_list()`;
  - `object_get_signal_type()`;
  - `node_has_signal_callable()`, `node_has_any_signal_callable()`;
  - `popup_menu_has_shortcut_item()`;
  - `node_get_editor_icon()`, `node_has_editor_icon()`;
  - `dock_get_locations()`.
- **Взаимодействие с редактором:**
  - Подписывается на `EditorInterface.get_base_control().theme_changed`, чтобы пересобирать список иконок из `get_editor_theme().get_icon_list("EditorIcons")`. `node_get_editor_icon()` по этому списку определяет имя иконки кнопки.
  - `popup_menu_has_shortcut_item()` берёт `Shortcut` из `EditorInterface.get_editor_settings().get_shortcut()` и сравнивает с `get_item_shortcut(i)`.
  - `dock_get_locations()` собирает закэшированные 12 слотов доков (`LAYOUT_DOCK_*`, включая скрытый контейнер). Затем добавляет плавающие доки: `find_children("", "WindowWrapper")` у `LAYOUT_ROOT`; у каждого `get_child(0)` (Window) ровно 3 ребёнка, а третий — `MarginContainer`.

#### res://addons/gdquest_editor_interface/library/editor_general.gd

- **Назначение:** определения корневых и общих узлов редактора, слотов доков и кнопок раскладки.
- **Ключевые классы/функции:**
  - `EditorMainWindowDef`, `EditorNodeDef`, `EditorFileSystemDef`, `EditorExportDef`;
  - `LayoutRootDef`, `LayoutTitleBarDef`;
  - восемь `LayoutDock{Left|Right}{Left|Right}{Top|Bottom}Def`, `LayoutDockMiddleBottomDef`, `LayoutDockBottomLeftDef`, `LayoutDockBottomRightDef`, `LayoutDockHiddenContainerDef`;
  - `LayoutDistractionFreeButtonDef`, `LayoutExpandBottomButtonDef`, `LayoutPinBottomButtonDef`;
  - `RenderingModeButtonDef`, `EditorUpdateSpinnerDef`, `EditorToasterDef`, `EditorVersionButtonDef`.
- **Взаимодействие с редактором:**
  - Окно — `get_base_control().get_window()`; `EditorNode` — его ребёнок; `EditorExport` — ребёнок `EditorNode`.
  - `LAYOUT_ROOT` — `get_base_control()` (`Panel`); `EditorTitleBar` — в `get_child(0)`.
  - Боковые слоты (`SideDockTabContainer`) ищутся по путям `DockVSplitMain/DockHSplitMain/DockVSplit{LeftL|LeftR|RightL|RightR}/DockSlot{…}`.
  - Нижняя панель (`EditorBottomPanel`) ищется цепочкой `DockVSplitMain` → `DockHSplitMain` → `VBoxContainer` → `DockVSplitCenter`.
  - Нижние боковые слоты (`BottomSideDockTabContainer`) — `DockHSplitBottom/DockSlotBottom{L|R}`; скрытый контейнер — первый ребёнок точного класса `Control`.
  - Кнопка Distraction Free ищется среди соседей `SCENE_TABS_TAB_BAR` или кнопки разворота (точки предзагружены через `prefetch`) по подключённому `EditorNode::_toggle_distraction_free_mode` и иконке `DistractionFree`.
  - Кнопки разворота и закрепления нижней панели находятся рядом с её `TabBar` (`get_tab_bar()`, затем родитель, затем `HBoxContainer`). Признаки — методы `EditorBottomPanel::_expand_button_toggled` и `_pin_button_toggled`, иконки `ExpandBottomDock` и `Pin`.
  - `OptionButton` режима рендеринга и `MenuButton` спиннера — в последнем `HBoxContainer` заголовка.
  - Тостер — `EditorInterface.get_editor_toaster()`; `EditorVersionButton` — в `HBoxContainer` нижней панели.

#### res://addons/gdquest_editor_interface/library/editor_main_view.gd

- **Назначение:** переключатель главных экранов (2D/3D/Script/Game/Asset Store) и контейнер главного экрана.
- **Ключевые классы/функции:**
  - `MainViewSwitcherDef`;
  - `MainViewSwitcher{2d|3d|Script|Game|AssetStore}ButtonDef`;
  - `MainViewContainerDef`, `MainViewContainerBoxDef`.
- **Взаимодействие с редактором:** переключатель — узел `EditorMainScreenButtons` внутри `LAYOUT_TITLE_BAR`. Кнопки берутся по именам узлов `"2D"`, `"3D"`, `"Script"`, `"Game"`, `"Asset Store"`. `MAIN_VIEW_CONTAINER_BOX` — `EditorInterface.get_editor_main_screen()` (`VBoxContainer`), а его родитель — `EditorMainScreen` (`MAIN_VIEW_CONTAINER`).

#### res://addons/gdquest_editor_interface/library/editor_menu_bar.gd

- **Назначение:** главное меню редактора и его подменю.
- **Ключевые классы/функции:**
  - `MenuBarDef`;
  - `MenuBarSceneMenuDef`, `MenuBarSceneOpenRecentMenuDef`, `MenuBarSceneExportAsMenuDef`;
  - `MenuBarProjectMenuDef`, `MenuBarProjectToolMenuDef`, `MenuBarProjectVersionControlMenuDef`;
  - `MenuBarDebugMenuDef`;
  - `MenuBarEditorMenuDef`, `MenuBarEditorDocksMenuDef`, `MenuBarEditorLayoutMenuDef`;
  - `MenuBarHelpMenuDef`.
- **Взаимодействие с редактором:**
  - `MenuBar` — ребёнок `EditorTitleBar`. Верхние `PopupMenu` берутся по именам узлов `"Scene"`, `"Project"`, `"Debug"`, `"Editor"`, `"Help"`.
  - Подменю — N-й дочерний `PopupMenu` с проверкой подключённого метода:
    - Open Recent — `EditorNode::_open_recent_scene` на `id_pressed`;
    - Export As — `EditorNode::_export_as_menu_option`;
    - Tools — `EditorNode::_tool_menu_option`;
    - Version Control — `EditorNode::_version_control_menu_option`;
    - Docks — `EditorDockManager::_docks_menu_option`;
    - Layout — `EditorNode::_layout_menu_option`.

#### res://addons/gdquest_editor_interface/library/editor_run_bar.gd

- **Назначение:** панель запуска проекта (Play/Pause/Stop/Play Current/Play Custom/Movie Maker).
- **Ключевые классы/функции:** `RunBarDef`; `RunBarButtonsDef` (`MultiDefinition`) и шесть пустых наследников `RunBar*ButtonDef`, которые нужны только для сопоставления имён enum.
- **Взаимодействие с редактором:** `EditorRunBar` — ребёнок `EditorTitleBar`. Кнопки собираются через `find_children("", "Button", true)` и распознаются по подключённым методам:
  - `EditorRunBar::play_main_scene`;
  - `EditorDebuggerNode::_paused`;
  - `EditorRunBar::stop_playing`;
  - `_play_current_pressed`;
  - `_play_custom_pressed`.

  У `MenuButton` проверяется `get_popup().id_pressed`: так находятся XR-варианты кнопок и Movie Maker (`_movie_maker_item_pressed`).

#### res://addons/gdquest_editor_interface/library/editor_scene_tabs.gd

- **Назначение:** вкладки открытых сцен.
- **Ключевые классы/функции:** `SceneTabsDef`, `SceneTabsTabBarDef`, `SceneTabsAddButtonDef`, `SceneTabsListButtonDef`.
- **Взаимодействие с редактором:** `EditorSceneTabs` ищется среди детей родителя `MAIN_VIEW_CONTAINER`; его `TabBar` — через `FindNodeTypeStep`. Кнопка «+» — `Button` внутри `TabBar` с иконкой `Add`. Кнопка списка — первая `Button` у родителя `TabBar` с иконкой `GuiTabMenuHl`.

#### res://addons/gdquest_editor_interface/library/editor_widgets.gd

- **Назначение:** кнопки переиспользуемого виджета масштаба `EditorZoomWidget`.
- **Ключевые классы/функции:** `EditorZoomWidgetZoomOutButtonDef`, `EditorZoomWidgetZoomInButtonDef`, `EditorZoomWidgetResetButtonDef`.
- **Взаимодействие с редактором:** относительные определения с `relative_node_type = "EditorZoomWidget"`. Кнопки — `Button` с индексами 0 (уменьшить), 2 (увеличить) и 1 (сброс) среди детей переданного виджета.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_about.gd

- **Назначение:** диалог «О Godot».
- **Ключевые классы/функции:** `EditorAboutDialogDef`.
- **Взаимодействие с редактором:** `GetChildTypeStep("EditorAbout")` среди детей `LAYOUT_ROOT`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_build_profiles.gd

- **Назначение:** менеджер профилей сборки движка.
- **Ключевые классы/функции:** `BuildProfileManagerDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `EditorBuildProfileManager`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_create_object.gd

- **Назначение:** элементы переиспользуемого диалога создания объекта/узла `CreateDialog`.
- **Ключевые классы/функции:**
  - `CreateObjectDialogOkButtonDef`, `CreateObjectDialogCancelButtonDef`, `CreateObjectDialogPanelsDef`;
  - `…FavoritesPanelDef`, `…FavoritesListDef`, `…RecentPanelDef`, `…RecentListDef`;
  - `…SearchPanelDef`, `…SearchTextFilterDef`, `…SearchFavoriteButtonDef`, `…SearchFilterMenuButtonDef`, `…SearchFilterResetButtonDef`, `…SearchMatchesListDef`;
  - `…DescriptionPanelDef`, `…DescriptionBitDef`.
- **Взаимодействие с редактором:** все определения относительные (`relative_node_type = "CreateDialog"`), контекст — например, `SCENE_DOCK_CREATE_DIALOG`.
  - OK/Cancel — `ConfirmationDialog.get_ok_button()` и `get_cancel_button()`.
  - Панели — `get_child(0)` (`HSplitContainer`): левая колонка — избранное (`VBoxContainer` 0, далее `MarginContainer`, далее `Tree`) и недавние (`VBoxContainer` 1, далее `ItemList`); правая — поиск (`FilterLineEdit` и `Button` в `MarginContainer`; `MenuButton` и кнопка сброса с иконкой `Reload` в `HBoxContainer`; `Tree` результатов) и описание (`EditorHelpBit`).

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_dependency_errors.gd

- **Назначение:** диалог ошибок зависимостей.
- **Ключевые классы/функции:** `DependencyErrorDialogDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `DependencyErrorDialog`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_editor_settings.gd

- **Назначение:** окно настроек редактора.
- **Ключевые классы/функции:** `EditorSettingsDialogDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `EditorSettingsDialog`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_export_templates.gd

- **Назначение:** менеджер шаблонов экспорта.
- **Ключевые классы/функции:** `ExportTemplateManagerDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `ExportTemplateManager`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_fbx_importer.gd

- **Назначение:** менеджер FBX-импортёра (отсутствует в сборках для Android и Web).
- **Ключевые классы/функции:** `FbxImporterManagerDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `FBXImporterManager`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_feature_profiles.gd

- **Назначение:** менеджер профилей возможностей редактора.
- **Ключевые классы/функции:** `FeatureProfileManagerDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `EditorFeatureProfileManager`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_import_audio.gd

- **Назначение:** диалог расширенных настроек импорта аудио.
- **Ключевые классы/функции:** `ImportAudioStreamSettingsDialogDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `AudioStreamImportSettingsDialog`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_import_font.gd

- **Назначение:** диалог расширенных настроек импорта шрифтов.
- **Ключевые классы/функции:** `ImportDynamicFontSettingsDialogDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `DynamicFontImportSettingsDialog`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_import_scene.gd

- **Назначение:** диалог расширенных настроек импорта 3D-сцен и его кнопки.
- **Ключевые классы/функции:** `ImportSceneSettingsDialogDef`, `ImportSceneSettingsDialogOkButtonDef`, `ImportSceneSettingsDialogCancelButtonDef`, `ImportSceneSettingsDialogPanelsDef`.
- **Взаимодействие с редактором:** диалог — ребёнок `LAYOUT_ROOT` класса `SceneImportSettingsDialog`. Кнопки — `get_ok_button()` и `get_cancel_button()` у `ConfirmationDialog`. Панели — `get_child(0)` (`VBoxContainer`).

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_orphan_resources.gd

- **Назначение:** обозреватель ресурсов-сирот.
- **Ключевые классы/функции:** `OrphanResourcesDialogDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `OrphanResourcesDialog`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_project_export.gd

- **Назначение:** диалог экспорта проекта.
- **Ключевые классы/функции:** `ProjectExportDialogDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `ProjectExportDialog`.

#### res://addons/gdquest_editor_interface/library/dialogs/dialogs_project_settings.gd

- **Назначение:** окно настроек проекта.
- **Ключевые классы/функции:** `ProjectSettingsDialogDef`.
- **Взаимодействие с редактором:** ребёнок `LAYOUT_ROOT` класса `ProjectSettingsEditor`.

#### res://addons/gdquest_editor_interface/library/docks/docks_animation.gd

- **Назначение:** нижняя панель Animation.
- **Ключевые классы/функции:** `AnimationDockDef`.
- **Взаимодействие с редактором:** `AnimationPlayerEditor` находится как подписчик сигнала `node_removed` у `EditorInterface.get_base_control().get_tree()` (через `Utils.object_get_signal_type`).

#### res://addons/gdquest_editor_interface/library/docks/docks_animation_tree.gd

- **Назначение:** нижняя панель AnimationTree.
- **Ключевые классы/функции:** `AnimationTreeDockDef`.
- **Взаимодействие с редактором:** `AnimationTreeEditor` — подписчик `SceneTree.node_removed`.

#### res://addons/gdquest_editor_interface/library/docks/docks_audio.gd

- **Назначение:** панель аудиошин (Audio).
- **Ключевые классы/функции:** `AudioDockDef`.
- **Взаимодействие с редактором:** `EditorAudioBuses` — подписчик сигнала `bus_layout_changed` синглтона `AudioServer`. Переменная `st` вычисляется, но не используется.

#### res://addons/gdquest_editor_interface/library/docks/docks_debugger.gd

- **Назначение:** панель отладчика.
- **Ключевые классы/функции:** `DebuggerDockDef`.
- **Взаимодействие с редактором:** от `SCENE_DOCK` через `GetSignalTypeStep("remote_tree_selected", "EditorDebuggerNode")` находит `EditorDebuggerNode`, подписанный на этот сигнал дока сцены.

#### res://addons/gdquest_editor_interface/library/docks/docks_filesystem.gd

- **Назначение:** док файловой системы, его дерево и список файлов.
- **Ключевые классы/функции:** `FileSystemDockDef`, `FileSystemTreeDef`, `FileSystemListDef`.
- **Взаимодействие с редактором:** док — `EditorInterface.get_file_system_dock()`. Дерево — `get_child(0)`, далее `SplitContainer`, далее `get_child(0)`, далее `Tree`. Список — тот же `SplitContainer`, далее `get_child(1)`, далее `MarginContainer`, далее `FileSystemList`.

#### res://addons/gdquest_editor_interface/library/docks/docks_gridmap.gd

- **Назначение:** док редактора GridMap.
- **Ключевые классы/функции:** `GridMapDockDef`.
- **Взаимодействие с редактором:** предзагружает `LAYOUT_ROOT` и все 12 слотов доков, затем перебирает `Utils.dock_get_locations()` (включая плавающие окна) и ищет `find_child("GridMap", false, false)`. Ожидаемый класс — `GridMapEditor`.

#### res://addons/gdquest_editor_interface/library/docks/docks_groups.gd

- **Назначение:** док групп и редактор групп внутри него.
- **Ключевые классы/функции:** `GroupsDockDef`, `GroupsEditorDef`.
- **Взаимодействие с редактором:** док (`GroupsDock`) ищется по имени `"Groups"` во всех местах размещения доков (с `prefetch` слотов). `GroupsEditor` — его прямой ребёнок.

#### res://addons/gdquest_editor_interface/library/docks/docks_history.gd

- **Назначение:** док истории отмены (History).
- **Ключевые классы/функции:** `HistoryDockDef`.
- **Взаимодействие с редактором:** от `EDITOR_NODE` через `GetSignalTypeStep("scene_changed", "HistoryDock")`.

#### res://addons/gdquest_editor_interface/library/docks/docks_import.gd

- **Назначение:** док Import.
- **Ключевые классы/функции:** `ImportDockDef`.
- **Взаимодействие с редактором:** по имени узла `"Import"` среди `Utils.dock_get_locations()`, с `prefetch` слотов. Тип — `EditorDock`.

#### res://addons/gdquest_editor_interface/library/docks/docks_inspector.gd

- **Назначение:** док инспектора и основные контейнеры самого `EditorInspector`.
- **Ключевые классы/функции:** `InspectorDockDef`, `InspectorDockInspectorDef`, `InspectorDockInspectorBeginBoxDef`, `InspectorDockInspectorFavoritesDef`, `InspectorDockInspectorPropertiesDef`.
- **Взаимодействие с редактором:** `InspectorDock` — подписчик сигнала `files_moved` у `FILE_SYSTEM_DOCK`. Инспектор — `EditorInterface.get_inspector()`. Внутри его `get_child(0)` три `VBoxContainer`: 0 — начальный блок, 1 — избранные свойства, 2 — основной список свойств.

#### res://addons/gdquest_editor_interface/library/docks/docks_output.gd

- **Назначение:** панель вывода (Output): текст лога и кнопки тулбара.
- **Ключевые классы/функции:**
  - `OutputDockDef`, `OutputDockRichTextDef`, `OutputDockToolbarDef`;
  - `OutputDockToolbarTextFilterDef`, `…ClearOutputButtonDef`, `…CollapseDuplicatesButtonDef`;
  - `…ToggleStandardLogsButtonDef`, `…ToggleErrorsButtonDef`, `…ToggleWarningsButtonDef`, `…ToggleEditorLogsButtonDef`.
- **Взаимодействие с редактором:**
  - `EditorLog` ищется по имени `"Output"` среди мест размещения доков (с `prefetch`).
  - `RichTextLabel` и тулбар (`HFlowContainer`) — по пути `HBoxContainer` → `VBoxContainer`.
  - Фильтр — `LineEdit` тулбара.
  - Кнопки проверяются по методу и иконке:
    - очистка — `EditorLog::_clear_request` и `Clear`;
    - свёртка дублей — `_set_collapse` и `CombineLines`;
    - четыре фильтра во вложенном `HBoxContainer` — `_set_filter_active` и иконки `Popup`, `StatusError`, `StatusWarning`, `Edit`.

#### res://addons/gdquest_editor_interface/library/docks/docks_polygon.gd

- **Назначение:** док редактора полигонов (Polygon2D UV).
- **Ключевые классы/функции:** `PolygonDockDef`.
- **Взаимодействие с редактором:** по имени `"Polygon"` среди `Utils.dock_get_locations()`, с `prefetch` слотов. Тип — `EditorDock`.

#### res://addons/gdquest_editor_interface/library/docks/docks_replication.gd

- **Назначение:** док сетевой репликации.
- **Ключевые классы/функции:** `ReplicationDockDef`.
- **Взаимодействие с редактором:** по имени `"Replication"` среди мест размещения доков. Тип — `ReplicationEditor`.

#### res://addons/gdquest_editor_interface/library/docks/docks_resource_preloader.gd

- **Назначение:** док ResourcePreloader.
- **Ключевые классы/функции:** `ResourcePreloaderDockDef`.
- **Взаимодействие с редактором:** по имени `"ResourcePreloader"` среди мест размещения доков. Тип — `ResourcePreloaderEditor`.

#### res://addons/gdquest_editor_interface/library/docks/docks_scene.gd

- **Назначение:** док сцены: диалоги, тулбар, панель создания корня, локальное и удалённое деревья.
- **Ключевые классы/функции:**
  - `SceneDockDef`;
  - `SceneDock{Create|Rename|Reparent|ScriptCreate|ShaderCreate}DialogDef`;
  - `SceneTreeToolbarDef`, `SceneTreeToolbarButtonsDef` (multi) и шесть наследников, `SceneTreeTextFilterDef`;
  - `SceneTreeCreatePanelDef`, `SceneTreeCreateButtonsDef` (multi) и пять наследников, `SceneTreeCreateFavoritesButtonDef`, `SceneTreeCreateFavoritesListDef`;
  - `SceneTreeEditorDef`, `SceneTreeLocalTreeDef`, `SceneTreeRemoteTreeDef`, `SceneTreeLocalToggleDef`, `SceneTreeRemoteToggleDef`.
- **Взаимодействие с редактором:**
  - `SceneTreeDock` и `SceneTreeEditor` — подписчики `EditorInterface.get_selection().selection_changed`. Диалоги — прямые дети дока по классу.
  - Кнопки тулбара (`get_child(0)` → `HBoxContainer`) распознаются по иконкам темы: `Add`, `Instance`, `ScriptCreate`, `ScriptRemove`, `ScriptExtend`, `GuiTabMenuHl`. Фильтр — `LineEdit`.
  - На панели создания корня (`MarginContainer` → `VBoxContainer`, далее `ScrollContainer`) кнопки распознаются по иконкам `Node2D`, `Node3D`, `Control`, `Add`, `ActionPaste`. Кнопки избранного отбрасываются по методу `SceneTreeDock::_favorite_root_selected`. Кнопка «Избранное» — иконка `Favorites`.
  - Локальное дерево — `Tree` внутри `SceneTreeEditor`; удалённое — `EditorDebuggerTree` у его родителя.
  - Переключатели Local/Remote — `PanelContainer` → `HBoxContainer` → `Button`, с проверкой методов `_local_tree_selected` и `_remote_tree_selected`.

#### res://addons/gdquest_editor_interface/library/docks/docks_search.gd

- **Назначение:** панель результатов «Найти в файлах».
- **Ключевые классы/функции:** `SearchResultsDockDef`.
- **Взаимодействие с редактором:** от `LAYOUT_ROOT` через `GetSignalTypeStep("theme_changed", "FindInFilesContainer")`. По комментарию в коде, этот приём хрупкий. Сами панели результатов — переиспользуемые компоненты и статически не разрешаются.

#### res://addons/gdquest_editor_interface/library/docks/docks_shader.gd

- **Назначение:** док редактора шейдеров.
- **Ключевые классы/функции:** `ShaderDockDef`.
- **Взаимодействие с редактором:** по имени `"Shader Editor"` среди `Utils.dock_get_locations()`, с `prefetch` слотов. Тип — `EditorDock`.

#### res://addons/gdquest_editor_interface/library/docks/docks_shader_file.gd

- **Назначение:** док для импортированных GLSL-файлов.
- **Ключевые классы/функции:** `ShaderFileDockDef`.
- **Взаимодействие с редактором:** по имени `"ShaderFile"` среди мест размещения доков. Тип — `ShaderFileEditor`.

#### res://addons/gdquest_editor_interface/library/docks/docks_signals.gd

- **Назначение:** док сигналов (`ConnectionsDock`) и диалог подключения сигнала (`ConnectDialog`).
- **Ключевые классы/функции:**
  - `SignalsDockDef`, `SignalsEditorDef`, `SignalsEditorTextFilterDef`, `SignalsEditorTreeDef`, `SignalsEditorConnectButtonDef`;
  - `SignalsDialogDef`, `SignalsDialogOkButtonDef`, `SignalsDialogCancelButtonDef`, `SignalsDialogPanelsDef`, `SignalsDialogBasicPanelDef`, `SignalsDialogAdvancedPanelDef`;
  - `SignalsDialogSignalEditDef`, `SignalsDialogMethodEditDef`, `SignalsDialogMethodEditPickButtonDef`, `SignalsDialogNodeTreeDef`, `SignalsDialogNodeTextFilterDef`, `SignalsDialogNodeToSourceButtonDef`, `SignalsDialogAdvancedCheckDef`.
- **Взаимодействие с редактором:**
  - `SignalsDock` ищется по имени `"Signals"` в местах размещения доков; `ConnectionsDock` — его ребёнок.
  - Фильтр и `Tree` находятся в `VBoxContainer` (`Tree` — через `MarginContainer`). Кнопка Connect — последний `HBoxContainer` → `Button`, проверка по методу `ConnectionsDock::_connect_pressed`, потому что иконка у неё меняется.
  - `ConnectDialog` — в `VBoxContainer` редактора; OK/Cancel — через `get_ok_button()` и `get_cancel_button()`.
  - Панели — `get_child(0)` (`HBoxContainer`) с двумя `VBoxContainer`.
  - На базовой панели: поля сигнала и метода (`LineEdit` в `MarginContainer`, первом и последнем), кнопка выбора метода (иконка `Edit`), `SceneTreeEditor` → `Tree`, фильтр узлов и кнопка «к источнику» во втором `MarginContainer`, `CheckButton` «Advanced».

#### res://addons/gdquest_editor_interface/library/docks/docks_spriteframes.gd

- **Назначение:** нижняя панель SpriteFrames: список анимаций, кадры и их тулбары.
- **Ключевые классы/функции:**
  - `SpriteFramesDockDef`, `SpriteFramesAnimationsPanelDef`, `SpriteFramesFramesPanelDef`;
  - `SpriteFramesAnimationsToolbarDef`, `SpriteFramesAnimationsToolbarButtonsDef` (multi, 7 наследников), `…SpeedEditDef`, `…AnimationsTextFilterDef`, `…AnimationsListDef`;
  - `SpriteFramesFramesToolbarDef`, `SpriteFramesFramesToolbarButtonsDef` (multi, 14 наследников), `…FrameDurationEditDef`;
  - `…FramesZoomBoxDef` и три кнопки масштаба, `…FramesListDef`.
- **Взаимодействие с редактором:**
  - `SpriteFramesEditor` — подписчик `SceneTree.node_removed`; виден только при выбранном `AnimatedSprite2D`/`AnimatedSprite3D` или открытом ресурсе `SpriteFrames`.
  - Панели — `SplitContainer` → `VBoxContainer` 0 и 1.
  - Кнопки анимаций распознаются по иконкам `New`, `ActionCut`, `ActionCopy`, `ActionPaste`, `Remove`, `AutoPlay`, `Loop`.
  - Кнопки кадров — по иконкам `Play`, `PlayStart`, `PlayBackwards`, `PlayStartBackwards`, `Load`, `SpriteSheet`, `ActionCopy`, `ActionPaste`, `InsertBefore`, `InsertAfter`, `MoveLeft`, `MoveRight`, `Remove`. Кнопка Stop — по методу `SpriteFramesEditor::_stop_pressed`.
  - Длительность кадра — первый `SpinBox` в любом месте тулбара (`FindNodeTypeStep`).
  - Блок масштаба — последний `HBoxContainer` с иконками `ZoomLess`, `ZoomReset`, `ZoomMore`.
  - Списки — `Tree` (анимации) и `ItemList` (кадры) в `MarginContainer`.

#### res://addons/gdquest_editor_interface/library/docks/docks_theme.gd

- **Назначение:** нижняя панель редактора темы.
- **Ключевые классы/функции:** `ThemeDockDef`.
- **Взаимодействие с редактором:** от `EDITOR_NODE` через `GetSignalTypeStep("scene_closed", "ThemeEditor")`.

#### res://addons/gdquest_editor_interface/library/docks/docks_tilemap.gd

- **Назначение:** нижняя панель TileMap (редактор `TileMapLayer`): вкладки, все тулбары, вкладки Tiles/Patterns/Terrains.
- **Ключевые классы/функции:**
  - `TileMapDockDef`, `TileMapDockTabsDef`;
  - `TileMapToolbarsDef` (multi на 27 кнопок) и наследники `TileMapCommonToolbar*`, `TileMapTilesToolbar*`, `TileMapTerrainsToolbar*`;
  - `TileMapTilesPanelDef`, `TileMapPatternsPanelDef`, `TileMapTerrainsPanelDef`;
  - `TileMapTilesSourcesListDef`, `…SortButtonDef`, `TileMapTilesAtlasViewDef`, `…ZoomWidgetDef`, `…CenterButtonDef`, `TileMapTilesScenesListDef`;
  - `TileMapPatternsListDef`, `TileMapTerrainsSetsListDef`, `TileMapTerrainsTilesListDef`.
- **Взаимодействие с редактором:**
  - `TileMapLayerEditor` — подписчик `SceneTree.node_removed`.
  - Вкладки — `TabBar` в `FlowContainer` с проверкой `HasTabsNamesStep(["Tiles","Patterns","Terrains"], strict)`.
  - Тулбары разбираются в один проход по всем `Button` внутри `FlowContainer`. Ключ кнопки — имя иконки (`CheckBox` → `"Contiguous"`, `OptionButton` → `"SelectLayer"`). Контекст задаёт класс объекта-подписчика сигналов `pressed`, `toggled`, `item_selected`, `id_pressed`, начинающийся с `TileMap`: `TileMapLayerEditor`, `…TilesPlugin` или `…TerrainsPlugin`. Контекст переходит на следующие кнопки.
  - Панели вкладок — по локализуемым именам узлов `"Tiles"`, `"Patterns"`, `"Terrains"` (`GetNodePathStep(..., true)`).
  - Далее `SplitContainer`/`BoxContainer` содержат `TileSetSourceItemList`, `TileAtlasView` (с `EditorZoomWidget` и кнопкой `CenterView`), `ItemList` и `Tree`.

#### res://addons/gdquest_editor_interface/library/docks/docks_tileset.gd

- **Назначение:** нижняя панель TileSet: источники, атлас-редактор, редактор коллекции сцен, паттерны, вспомогательные диалоги.
- **Ключевые классы/функции:**
  - `TileSetDockDef`, `TileSetDockTabsDef`, `TileSetTilesPanelDef`, `TileSetPatternsPanelDef`;
  - `TileSetAtlasMergingDialogDef`, `TileSetTileProxiesManagerDef`;
  - `TileSetTilesSourcesList{,Buttons,DeleteButton,AddButton,MenuButton,SortButton}Def`;
  - `TileSetTilesAtlasEditor{,Tabs,SetupButton,SelectButton,PaintButton,SetupPanel,SelectPanel,PaintPanel,Toolbars,SetupToolbarEraseButton,SetupToolbarMenuButton,PaintToolbars,AtlasView,AtlasViewZoomWidget,AtlasViewCenterButton}Def`;
  - `TileSetTilesScenesCollectionEditor{,Properties,PropertiesScene,PropertiesTile,Scenes,ScenesList,ScenesButtons,ScenesAddButton,ScenesDeleteButton}Def`;
  - `TileSetPatternsListDef`.
- **Взаимодействие с редактором:**
  - `TileSetEditor` ищется по имени `"TileSet"` в местах размещения доков (с `prefetch`).
  - Вкладки — `VBoxContainer` → `HBoxContainer` → `PanelContainer` → `TabBar`, проверка `["Tile Sources","Patterns"]`. Панель Tiles — по локализуемому имени `"Tiles"`.
  - Кнопки источников — `Button` с индексами 0–3 в `HBoxContainer`.
  - Атлас-редактор (`TileSetAtlasSourceEditor`) — `get_child(1)` панели. Его вкладки Setup/Select/Paint — дети 0/1/2 с иконками `Tools`, `ToolSelect`, `Paint`.
  - Панели свойств — `EditorInspector` 1 и 0, а также `ScrollContainer`. Тулбары — `HBoxContainer`. `TileAtlasView` — с `EditorZoomWidget` и кнопкой `CenterView`.
  - Редактор коллекции сцен — `HSplitContainer` с двумя `EditorInspector`, а также `ItemList` и кнопки по индексу.
  - Диалоги `AtlasMergingDialog` и `TileProxiesManagerDialog` — дети дока.

#### res://addons/gdquest_editor_interface/library/main_views/asset_library.gd

- **Назначение:** главный экран AssetLib.
- **Ключевые классы/функции:** `AssetStoreDef`.
- **Взаимодействие с редактором:** ребёнок `MAIN_VIEW_CONTAINER_BOX` (`get_editor_main_screen()`) класса `EditorAssetLibrary`.

#### res://addons/gdquest_editor_interface/library/main_views/canvas_item_editor.gd

- **Назначение:** 2D-редактор: главный тулбар, контекстные тулбары, вьюпорт с оверлеями, диалог настроек привязки.
- **Ключевые классы/функции:**
  - `CanvasItemEditorDef`, `CanvasItemEditorMainToolbarDef`, `CanvasItemEditorMainToolbarButtonsDef` (multi, 18 наследников), `CanvasItemEditorContextualToolbarsDef`;
  - `CanvasItemEditorViewportDef`, `…ViewportSceneRootDef`, `…ViewportOverlaysDef`, `…ViewportZoomWidgetDef`, `…ViewportCenterButtonDef`, `…ViewportTranslationPreviewButtonDef`;
  - `CanvasItemEditorSnapDialog{,OkButton,CancelButton,Options,GridOptions,GridOffsetX/Y,GridStepX/Y,GridPrimaryX/Y,RotationOptions,RotationOffset,RotationStep,ScaleOptions,ScaleStep}Def`.
- **Взаимодействие с редактором:**
  - `CanvasItemEditor` — ребёнок главного экрана. Тулбар — `MarginContainer` → `FlowContainer` → `HBoxContainer`; кнопки распознаются по иконкам:
    - инструменты: `ToolSelect`, `ToolMove`, `ToolRotate`, `ToolScale`, `ListSelect`, `EditPivot`, `ToolPan`, `Ruler`;
    - пространство и привязка: `Object`, `Snap`, `SnapGrid`, `GuiTabMenuHl`;
    - блокировка и группировка: `Lock`, `Unlock`, `Group`, `Ungroup`, `Bone`;
    - меню View распознаётся по методу `CanvasItemEditor::_prepare_view_menu` на `about_to_popup` у popup.
  - Контекстные тулбары — `PanelContainer` → `get_child(0)`.
  - Вьюпорт — три вложенных `SplitContainer`, затем `Control`. В нём `SubViewportContainer` → `SubViewport` (корень сцены) и узел `CanvasItemEditorViewport`, который здесь назван «оверлеями». В оверлеях находятся `EditorZoomWidget`, кнопка `CenterView` и `EditorTranslationPreviewButton`.
  - `SnapDialog` — ребёнок редактора. В нём три `GridContainer` (сетка, поворот, масштаб) и `SpinBox` по индексам.

#### res://addons/gdquest_editor_interface/library/main_views/game_view.gd

- **Назначение:** главный экран Game (встроенный запуск игры).
- **Ключевые классы/функции:** `GameViewDef`.
- **Взаимодействие с редактором:** второй `WindowWrapper` (индекс 1) главного экрана, затем `GetWindowWrappedTypeStep("GameView")` — экран может быть встроен или вынесен в отдельное окно. Узел присутствует, даже если экран отключён профилем возможностей.

#### res://addons/gdquest_editor_interface/library/main_views/node_3d_editor.gd

- **Назначение:** 3D-редактор: главный тулбар, контекстные тулбары, контейнер вьюпортов и элементы отдельного вьюпорта.
- **Ключевые классы/функции:**
  - `Node3dEditorDef`, `Node3dEditorMainToolbarDef`, `Node3dEditorMainToolbarButtonsDef` (multi, 18 точек; есть также лишний `Node3dEditorMainToolbarCameraButtonDef` без значения enum);
  - `Node3dEditorContextualToolbarsDef`, `Node3dEditorViewportsDef`;
  - относительные `Node3dEditorViewport{SceneRoot,Camera,Overlays,ViewDisplayMenu,TranslationPreviewButton,CameraPreviewCheck,RotationGizmo}Def`.
- **Взаимодействие с редактором:**
  - `Node3DEditor` — ребёнок главного экрана. Тулбар — `MarginContainer` → `FlowContainer` → `HBoxContainer`; кнопки распознаются по иконкам:
    - инструменты: `ToolTransform`, `ToolMove`, `ToolRotate`, `ToolScale`, `ToolSelect`, `ListSelect`;
    - блокировка и группировка: `Lock`, `Unlock`, `Group`, `Ungroup`;
    - прочее: `Ruler`, `Object`, `Snap`, `PreviewSun`, `PreviewEnvironment`; настройки солнца и окружения — иконка `GuiTabMenuHl`;
    - меню Transform и View — по наличию пунктов с шорткатами `spatial_editor/transform_dialog` и `spatial_editor/1_viewport` (`popup_menu_has_shortcut_item`).
  - `Node3DEditorViewportContainer` — за тремя вложенными `SplitContainer`; эти контейнеры служат для боковых панелей плагинов.
  - Внутри `Node3DEditorViewport` (контекст):
    - `SubViewportContainer` → `SubViewport` → `Camera3D`;
    - оверлеи — `Control` с индексом 1;
    - меню вида — `MenuButton` с иконкой `GuiTabMenuHlDarkBackground`;
    - `EditorTranslationPreviewButton`;
    - `CheckBox` превью камеры — иконка `Camera3DDarkBackground`;
    - `ViewportRotationControl` — в последнем `VBoxContainer`.

#### res://addons/gdquest_editor_interface/library/main_views/script_editor.gd

- **Назначение:** редактор скриптов и справки: тулбар и меню, боковая панель, вкладки, панель поиска и замены, а также внутренности переиспользуемых `ScriptTextEditor`, `TextEditor` и `EditorHelp`.
- **Ключевые классы/функции:**
  - `ScriptEditorDef`;
  - тулбар: `ScriptEditorToolbarDef`, `…FileMenuButtonDef`, `…SearchMenuButtonDef`, `…DebugMenuButtonDef`, `…CurrentButtonDef`, `…OnlineDocsButtonDef`, `…SearchHelpButtonDef`, `…NavigateBackButtonDef`, `…NavigateForwardButtonDef`, `…MakeFloatingButtonDef`;
  - дополнительные меню: `ScriptEditorTextToolbar{,Edit,Search,Goto}…Def` (`EditMenus`) и `ScriptEditorScriptToolbar{…}Def` (`EditMenusSTE`);
  - боковая панель: `ScriptEditorSidebarDef`, `…ScriptListDef`, `…ScriptListFilterDef`, `…CurrentScriptIndexDef`, `…FilterDef`, `…SortButtonDef`, `…CurrentDocsIndexDef`;
  - контейнер: `ScriptEditorContainerDef`, `…TabsDef`, `…FindReplaceBarDef`;
  - относительные: `ScriptTextEditorCodeEditor{,CodeEdit,FooterBar}Def`, `TextEditorCodeEditor{…}Def`, `EditorHelp{RichText,FindBar,FooterBar,FooterSidebarButton}Def`.
- **Взаимодействие с редактором:**
  - `ScriptEditor` — первый `WindowWrapper` главного экрана, затем `GetWindowWrappedTypeStep`; учитывается плавающий режим.
  - Тулбар — `get_child(0)` → `HBoxContainer`. Меню File/Search/Debug — `MenuButton` 0/1/2. Дополнительные наборы меню — дочерние `EditMenus` и `EditMenusSTE`; они появляются только после открытия редактора соответствующего типа.
  - Кнопки тулбара:
    - «текущий скрипт» — в `HBoxContainer` точного типа;
    - онлайн-документация — иконка `ExternalLink`;
    - поиск в справке — иконка `HelpSearch`;
    - «назад» и «вперёд» — по методам `ScriptEditor::_history_back` и `_history_forward`, потому что в RTL иконки зеркалятся;
    - `ScreenSelect` — вынос в отдельное окно.
  - Боковая панель — `HSplitContainer` → `VSplitContainer`; содержит списки скриптов, методов и документации (`ItemList`), фильтры (`LineEdit`) и кнопку сортировки.
  - Контент — `VBoxContainer`, в котором `TabContainer` вкладок и `FindReplaceBar`.
  - В переиспользуемых компонентах:
    - `ScriptTextEditor` → `VSplitContainer` → `CodeTextEditor` → `CodeEdit` и `HBoxContainer`-футер;
    - `TextEditor` → `CodeTextEditor` напрямую;
    - `EditorHelp` → `RichTextLabel`, `FindBar`, последний `HBoxContainer` и кнопка боковой панели (метод `EditorHelp::_toggle_files_pressed`).
