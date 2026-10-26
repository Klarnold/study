## theme_utils (res://addons/theme_utils)

### На какие задачи направлены скрипты

`theme_utils` (GDQuest Theme Utils) — небольшая библиотека статических функций без собственного `plugin.cfg`. Она не регистрируется как плагин редактора и не добавляет узлов; её подключают через `preload()` другие аддоны, у которых есть свой UI внутри редактора Godot. Главная проблема, которую она решает: тема (`Theme`), свёрстанная автором аддона при масштабе редактора 100%, на HiDPI-мониторах или при другом `Editor Scale` выглядит слишком мелкой, потому что встроенные панели редактора масштабируются, а пользовательские `Theme`/`StyleBox`/константы — нет. Вторая задача — поддержать языки, глифов которых нет в шрифтах темы аддона (сейчас это японский). Для этого в аддоне лежат шрифты Noto Sans JP: `fallback/noto_sans_ja_regular.ttf` и `fallback/noto_sans_ja_bold.ttf`. По README, функции вынесены из инфраструктуры GDTour.

Конкретные задачи:
- масштабировать размер шрифта отдельного `Control` по масштабу редактора (`scale_font_size`);
- масштабировать отступы `MarginContainer`, при необходимости с дополнительным множителем для отдельных сторон (`scale_margin_container_margins`);
- создавать **глубокую копию** темы аддона со всеми масштабированными значениями: размерами шрифтов, константами, отступами, рамками, радиусами скругления, тенями и расширениями `StyleBox` (`generate_scaled_theme`). Исходный `.tres` при этом не меняется, поэтому масштабированные значения не попадут в файл, если автор аддона откроет и сохранит тему;
- учитывать не только `Editor Scale`, но и пользовательскую настройку основного размера шрифта редактора (`interface/editor/main_font_size`);
- подменять шрифты темы на запасные (Noto Sans JP), если язык интерфейса редактора — японский (`request_fallback_font`);
- обеспечивать единый, «родной» для редактора вид UI плагинов (окна туров, кнопки, «пузыри» подсказок в `godot_tours`).

### Взаимодействие с редактором Godot

Скрипт помечен `@tool` и работает только в контексте редактора: все функции обращаются к синглтону `EditorInterface`, который в экспортированной игре недоступен. Используемые API редактора:

- **`EditorInterface.get_editor_scale()`** — современный аналог `EDSCALE` из C++ и устаревшего `EditorPlugin.get_editor_interface().get_editor_scale()`. Возвращает множитель интерфейса (например, `1.0`, `1.5`, `2.0`), который выбирается в *Editor Settings → Interface → Editor → Display Scale* или определяется автоматически по DPI. Его вызывают все три функции масштабирования: `scale_font_size`, `scale_margin_container_margins` и `generate_scaled_theme`.
- **`EditorInterface.get_editor_settings()`** — доступ к `EditorSettings`. Из него читаются:
  - `interface/editor/main_font_size` в `generate_scaled_theme` — основной размер шрифта редактора. Если пользователь увеличил его относительно `default_font_size` темы, разница прибавляется ко всем размерам шрифтов темы до умножения на масштаб;
  - `interface/editor/editor_language` в `request_fallback_font` — язык интерфейса редактора, по которому решается, нужен ли запасной шрифт.
- **API ресурсов `Theme`**: `duplicate_deep()`, `get_font_size_type_list()`/`get_font_size_list()`/`set_font_size()`, `get_constant_type_list()`/`get_constant_list()`/`set_constant()`, `get_stylebox_type_list()`/`get_stylebox_list()`/`set_stylebox()`, `get_font_type_list()`/`get_font_list()`/`set_font()`, `default_font` и `default_font_size`.
- **Переопределения темы на уровне узла** (`Control.add_theme_font_size_override`, `add_theme_constant_override`) — используются при точечном масштабировании отдельных элементов.

Сама тема редактора (`EditorInterface.get_editor_theme()`) в `theme_utils.gd` **не используется**: скрипт масштабирует собственную тему аддона, а не берёт стили редактора. Тему редактора отдельно запрашивает потребитель — `godot_tours/utils.gd` в `precache_icon_image()`, чтобы брать иконки `EditorIcons`.

**Кто и как использует скрипт.** Поиск по `main_project/addons` нашёл одного потребителя — `res://addons/godot_tours/utils.gd`:

```gdscript
const ThemeUtils := preload("res://addons/theme_utils/theme_utils.gd")
const DEFAULT_THEME := preload("assets/gdtour_theme.tres")
static var _scaled_theme: Theme = null

static func _static_init() -> void:
	_scaled_theme = ThemeUtils.request_fallback_font(DEFAULT_THEME)
	_scaled_theme = ThemeUtils.generate_scaled_theme(_scaled_theme)
```

Порядок такой: при первой загрузке класса `Utils` (в `_static_init`) берётся тема GDTour `gdtour_theme.tres`. Сначала в ней при необходимости подменяются шрифты под язык редактора, затем получается масштабированная копия. Она кэшируется в статической переменной и отдаётся через `Utils.get_default_theme()`. Эту тему назначают UI-элементам туров:
- `godot_tours/editor/gdtour_button.gd` — `theme = Utils.get_default_theme()` (кнопка GDTour в интерфейсе редактора);
- `godot_tours/bubble/bubble_base.gd` — `_bubble_anchor.theme = Utils.get_default_theme()` (корень «пузыря» с подсказками тура, от которого тему наследуют все дочерние `Control`).

Функции `scale_font_size` и `scale_margin_container_margins` в текущем проекте нигде не вызываются: это вспомогательный API для точечного масштабирования узлов, если не нужно копировать всю тему.

Масштаб вычисляется один раз при инициализации класса, поэтому после смены `Display Scale`, размера шрифта или языка редактора новые значения применятся только после перезапуска редактора (смена масштаба и так требует перезапуска).

### Скрипты

#### res://addons/theme_utils/theme_utils.gd

- **Назначение:** набор статических функций (`static func`) для обработки свойств UI-тем. Главное — масштабировать тему, шрифты, константы и `StyleBox` по масштабу редактора и подставлять запасные шрифты для японского интерфейса. Скрипт не наследует `EditorPlugin`/`Node` и не создаёт экземпляров: его загружают через `preload()` как «пространство имён» утилит. Есть аннотация `@tool`.

- **Константы:**
  - `FALLBACK_FONT_LANGUAGES := ["ja"]` — языки редактора, для которых нужен запасной шрифт;
  - `FALLBACK_FONT_FMT := "res://addons/theme_utils/fallback/noto_sans%s_%s.ttf"` — шаблон пути к шрифту: суффикс языка (`_ja`) и начертание (`regular`, `bold`, …);
  - `FALLBACK_FONT_MAP` — соответствие имени шрифтового свойства темы и начертания: `bold_font → bold`, `italics_font → italic`, `mono_font → mono`, `normal_font → regular`, `font → regular`. Ключи `bold_font`/`italics_font`/`mono_font`/`normal_font` соответствуют свойствам `RichTextLabel`, ключ `font` — обычным контролам.

- **Ключевые функции:**
  - `scale_font_size(text_node: Control) -> void` — читает текущий эффективный размер шрифта узла `text_node.get_theme_font_size("font_size")` (с учётом наследования темы), умножает на `EditorInterface.get_editor_scale()` и записывает результат как локальное переопределение `add_theme_font_size_override("font_size", …)`. Проверки на масштаб `1.0` нет, а повторный вызов умножит уже увеличенный размер ещё раз, поэтому функцию нужно вызывать для узла один раз (обычно в `_ready`). Предназначена для заголовков и отдельных надписей.
  - `scale_margin_container_margins(margin_container: MarginContainer, extra_scale: Dictionary[String, float] = {}) -> void` — при масштабе, примерно равном `1.0` (`is_equal_approx`), сразу выходит. Иначе для каждой из констант `margin_left`, `margin_right`, `margin_top`, `margin_bottom` берёт текущее значение `get_theme_constant(property)`, умножает на масштаб редактора и на дополнительный множитель из `extra_scale` (по умолчанию `1.0`), и задаёт результат через `add_theme_constant_override`. С помощью `extra_scale` можно, например, сделать верхний отступ больше остальных.
  - `generate_scaled_theme(theme_resource: Theme) -> Theme` — основная функция. Возвращает новую тему, глубокую копию (`duplicate_deep()`) исходной, со значениями, умноженными на `editor_scale`. Глубокая копия гарантирует, что масштабирование не затронет исходный ресурс и не сохранится в `.tres` при работе над UI аддона. Шаги:
    1. **Шрифты.** Читает `interface/editor/main_font_size` из настроек редактора. Базовый размер = `max(theme.default_font_size, main_font_size)`, прибавка `size_difference = max(main_font_size - default_font_size, 0)`. Новый `default_font_size = base_font_size * editor_scale`. Затем для каждого типа из `get_font_size_type_list()` плюс принудительно добавленной вариации `"TitleLabel"` каждый размер шрифта становится `(size + size_difference) * editor_scale`. Так учитывается и масштаб интерфейса, и увеличенный пользователем основной шрифт редактора.
    2. **Константы** (отступы, разделение, ширина элементов и т. п.). Для всех типов из `get_constant_type_list()` каждая константа умножается на масштаб.
    3. **StyleBox.** Для всех стилей из `get_stylebox_type_list()`/`get_stylebox_list()`: если `StyleBox` — внешний ресурс (непустой `resource_path`), он дополнительно дублируется и записывается в тему через `set_stylebox`, чтобы не изменить общий файл стиля. Затем масштабируются:
       - у любого `StyleBox` — `content_margin_left/right/top/bottom`;
       - у `StyleBoxFlat` — `border_width_*`, `corner_radius_*`, `shadow_offset`, `shadow_size`;
       - у `StyleBoxFlat` и `StyleBoxTexture` — `expand_margin_*`.

    Значения шрифтов и констант приводятся к `int` (дробная часть отбрасывается). Цвета, иконки, сами шрифты и `StyleBoxLine` (кроме общих content margins) не меняются.
  - `request_fallback_font(theme: Theme) -> Theme` — читает язык интерфейса редактора `interface/editor/editor_language`. Если его нет в `FALLBACK_FONT_LANGUAGES`, возвращает исходную тему без изменений (без копирования). Иначе делает `duplicate_deep()` темы и:
    - задаёт `default_font` = `noto_sans_ja_regular.ttf`;
    - для каждого шрифтового свойства каждого типа (`get_font_type_list()`/`get_font_list()`) строит путь по `FALLBACK_FONT_MAP` и, если файл существует (`FileAccess.file_exists`), подставляет его через `set_font`. Реально есть только `regular` и `bold`, поэтому `italics_font` и `mono_font` остаются исходными.

    Особенности: функция выводит отладочную строку `prints(font, path, exists)` в консоль; имя шрифтового свойства, которого нет в `FALLBACK_FONT_MAP`, вызовет ошибку обращения к словарю; язык сравнивается точно (`"ja"`), региональные варианты вида `ja_JP` не распознаются.

- **Взаимодействие с редактором:** все функции работают через синглтон `EditorInterface`. `get_editor_scale()` (аналог `EDSCALE`) — множитель для шрифтов, констант, отступов и `StyleBox`. `get_editor_settings()` — чтение `interface/editor/main_font_size` (подстройка под размер шрифта редактора) и `interface/editor/editor_language` (выбор запасного шрифта). Результат применяется к UI плагинов двумя способами: локальными переопределениями темы на конкретных `Control` (`add_theme_*_override`) или готовой масштабированной темой `Theme`, которую плагин назначает корневому контролу своего интерфейса. Так делает `godot_tours`: `Utils._static_init()` вызывает сначала `request_fallback_font()`, затем `generate_scaled_theme()` для `gdtour_theme.tres`, а `Utils.get_default_theme()` отдаёт результат кнопке GDTour (`gdtour_button.gd`) и «пузырям» тура (`bubble_base.gd`). Поскольку скрипт зависит от `EditorInterface`, он рассчитан только на редактор и не должен загружаться в экспортированной игре.
