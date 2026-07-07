# smooth_dropdown

**Dropdown, select, and picker widgets for Flutter where the open/close motion _is_ the product.**

One wavy morphing edge, a soft glow, a sheen sweep, a squash‑and‑stretch, a rising content reveal, and a chevron turn — every channel driven from **one** animation value, entirely on the **render layer**. No `setState`, no `AnimatedBuilder`, and zero frames spent while at rest.

![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.27-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%5E3.9-0175C2?logo=dart&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%C2%B7%20Android%20%C2%B7%20Web%20%C2%B7%20macOS%20%C2%B7%20Windows%20%C2%B7%20Linux-informational)
![License](https://img.shields.io/badge/license-MIT-3DA639)

> 🎬 **See it move.** The real widgets, recorded on device — every frame is the render layer, not a mockup. Each clip loops inline; the first (poster) frame shows while it loads.

|  🔵 Select  |  🟢 Reveal  |  🟠 Panel  |
|:---:|:---:|:---:|
| <img src="https://raw.githubusercontent.com/nkalahanov/smooth_dropdown/main/assets/demo-select.webp" alt="SmoothSelect opening in place: the option list unfolds beneath the header and a glowing highlight springs onto the chosen scene, carrying its checkmark."> | <img src="https://raw.githubusercontent.com/nkalahanov/smooth_dropdown/main/assets/demo-reveal.webp" alt="A SmoothExpansionTile opening: body text wells up behind a morphing wavy edge as the card grows, under a soft glow and a sheen sweep."> | <img src="https://raw.githubusercontent.com/nkalahanov/smooth_dropdown/main/assets/demo-panel.webp" alt="A SmoothExpansionTile revealing a live SmoothSelect nested inside it — a dropdown within a dropdown, fully interactive."> |
| Open in place, then **drag, fling, or arrow** the highlight. | Text **wells up** behind a rising, morphing edge. | The reveal holds **any** widget — even another dropdown. |

<!-- Demo loops live in /assets/, which .pubignore excludes, so they add 0 bytes to the published package while GitHub serves them raw. Before a real publish the URLs are re-pinned from `main` to an immutable commit SHA so the frozen, published README never breaks. -->

---

## Contents

- ✨ [Highlights](#highlights)
- 📦 [Install](#install)
- 🚀 [Quick start](#quick-start)
- 🧩 [The widgets](#the-widgets)
- 🟣 [The moving highlight](#the-moving-highlight)
- ⌨️ [Keyboard and input](#keyboard-and-input)
- 🌍 [Right-to-left](#right-to-left)
- ♿ [Reduced motion](#reduced-motion)
- 🎨 [Theming](#theming)
- 🎛️ [Programmatic control](#programmatic-control)
- ⚡ [Performance](#performance)
- 🗺️ [API at a glance](#api-at-a-glance)
- 🔬 [How it works](#how-it-works)
- 📌 [Status and roadmap](#status-and-roadmap)
- 🤝 [Contributing](#contributing)
- 📄 [License](#license)

---

## Highlights

- 🌊 **Motion that reads as one gesture.** Shape, glow, sheen, squash, reveal, and chevron move together off a single controller — layered, never a lone opacity fade.
- 🧩 **Three widgets, one motion language.** An expansion tile, a typed select, and a draggable picker that all feel like the same product.
- 🟣 **A highlight with real physics.** The selection box springs between options with inertia, a graded velocity squash, and a rubber band at the ends — drag it, fling it, or tap and watch it glide.
- ⌨️ **Fully keyboard and switch operable.** `SmoothSelect` follows the WCAG combobox key map, and arrow keys drive the very same spring‑glide the finger does.
- 🌍 **Right-to-left aware.** Rising text and the selection tick both honour the ambient `Directionality`.
- ♿ **Respects reduced motion.** When the OS asks for less, the widget stays fully functional and just gets fast and quiet.
- 🪶 **Render-layer only.** No `setState` and no `AnimatedBuilder` for motion; a resting widget schedules no frames.
- 🎨 **Theming to the last pixel.** Colors, durations, curves, radius, wave, and each motion channel toggle independently — per widget or shared down the tree.
- 🚫 **Zero runtime dependencies.** Pure Flutter. Nothing to audit but the framework.

---

## Install

Not on pub.dev yet. Add it by path or by git.

```yaml
dependencies:
  smooth_dropdown:
    path: packages/smooth_dropdown
```

```yaml
dependencies:
  smooth_dropdown:
    git:
      url: https://github.com/nkalahanov/smooth_dropdown
      path: packages/smooth_dropdown
```

Then import the one entry point:

```dart
import 'package:smooth_dropdown/smooth_dropdown.dart';
```

**Requires** Flutter `>=3.27.0` and Dart SDK `^3.9.0`.

---

## Quick start

### An expansion tile

```dart
SmoothExpansionTile.text(
  title: 'What is this?',
  text: 'A dropdown where the open and close move is the product.',
  icon: Icons.water_drop_rounded,
);
```

### A select field

```dart
String? fruit;

SmoothSelect<String>(
  value: fruit,
  hint: const Text('Pick a fruit'),
  onChanged: (value) => setState(() => fruit = value),
  items: const [
    SmoothSelectItem(value: 'apple', child: Text('Apple')),
    SmoothSelectItem(value: 'lime', child: Text('Lime')),
    SmoothSelectItem(value: 'plum', child: Text('Plum')),
  ],
);
```

### A picker

```dart
int hour = 9;

SmoothPicker<int>(
  value: hour,
  onChanged: (value) => setState(() => hour = value!),
  items: [
    for (var h = 0; h < 24; h++)
      SmoothPickerItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')),
  ],
);
```

---

## The widgets

### SmoothExpansionTile

A card that reveals **any** widget with the full open/close move. The header can be a title, a subtitle, a leading icon, and a trailing indicator — or a completely custom `headerBuilder`.

```dart
SmoothExpansionTile(
  leading: const Icon(Icons.tune_rounded),
  title: const Text('Settings'),
  subtitle: const Text('Open to change them'),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Put anything here — buttons, chips, a form, an image.'),
      const SizedBox(height: 8),
      FilledButton(onPressed: () {}, child: const Text('A real button')),
    ],
  ),
);
```

The `.text` factory is a shorthand for the common help/FAQ card: its text **rises up** as the tile opens, masked behind a moving surface line.

While the tile is closed, its content is hidden and cannot be tapped; while open, everything inside is fully interactive. Tall content? Pass `menuMaxHeight` and it scrolls.

| Parameter | Purpose |
| :-- | :-- |
| `child` **(required)** | The content revealed on open. |
| `title`, `subtitle`, `leading`, `trailing` | The standard header pieces. |
| `headerBuilder` | Build the entire header yourself (used _instead_ of the pieces above). |
| `controller` | Drive open/close from your code. |
| `initiallyExpanded` | Start open. |
| `onExpansionChanged` | Called with `true`/`false` on every toggle. |
| `menuMaxHeight` | Cap the open height; longer content scrolls. |
| `entrance` | An outside animation that fades and slides the whole tile in. |
| `phaseSeed` | Shift the wave so stacked tiles do not ripple as one. |
| `style` | A `SmoothStyle` laid over the theme. |

### SmoothSelect

A typed field that opens a list **in place** — it pushes the widgets below it rather than floating over them, so it composes cleanly inside scroll views and forms. It is a **controlled** widget: give it a `value` and an `onChanged`, then store what comes back.

```dart
int? level;

SmoothSelect<int>(
  value: level,
  hint: const Text('Difficulty'),
  onChanged: (value) => setState(() => level = value),
  items: const [
    SmoothSelectItem(value: 1, leading: Icon(Icons.circle_outlined), child: Text('Easy')),
    SmoothSelectItem(value: 2, child: Text('Normal')),
    SmoothSelectItem(value: 3, trailing: Text('★★★'), child: Text('Hard')),
    SmoothSelectItem(value: 4, enabled: false, child: Text('Locked')),
  ],
);
```

- Each option carries an optional **`leading`** and **`trailing`** widget (any widget, not just an icon) and an `enabled` flag.
- When the list fits without scrolling, the open list also carries the **draggable highlight** — lift it, fling it, or tap another option to glide it there.
- Set `onChanged` to `null` to disable the field; it drops out of the focus order and dims.
- `closeOnSelect` (default `true`) controls whether a pick closes the list.
- `selectedItemBuilder` customises how the picked value is shown in the header.

### SmoothPicker

A draggable, spring‑inertial selection column. Drag the soft highlight, fling it, or tap a row — on release it springs to the nearest option and rests there. The look and physics come from a [`SmoothHighlight`](#the-moving-highlight).

```dart
SmoothPicker<int>(
  value: minute,
  onChanged: (value) => setState(() => minute = value!),
  highlight: const SmoothHighlight(),
  items: [
    for (var m = 0; m < 60; m += 5)
      SmoothPickerItem(value: m, child: Text(m.toString().padLeft(2, '0'))),
  ],
);
```

---

## The moving highlight

Both `SmoothSelect` and `SmoothPicker` share one selection box — a `SmoothHighlight`. There is only **ever one** on screen: at rest it marks the current value; the instant you drag, it lifts off under your finger (no trailing offset, grab from anywhere) so the old row is never marked at the same time; on release it springs home and relaxes to a clean, full‑size box. It carries its own selection tick, and the tick travels **with** the box instead of being left behind.

```dart
SmoothSelect<int>(
  value: level,
  onChanged: (v) => setState(() => level = v),
  highlight: SmoothHighlight(
    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)]),
    borderRadius: BorderRadius.circular(14),
    shadows: const [BoxShadow(color: Color(0x557C3AED), blurRadius: 18, spreadRadius: 1)],
    checkColor: Colors.white,
  ),
  items: const [/* ... */],
);
```

**Look**

| Field | Default | Meaning |
| :-- | :-- | :-- |
| `color` | `0x26FFFFFF` | Fill of the box (ignored when `gradient` is set). |
| `gradient` | `null` | Gradient fill; wins over `color`. |
| `borderRadius` | `null` | Corner radius, or follow the option's own. |
| `border` | `null` | Optional stroke around the box. |
| `shadows` | `null` | Soft shadows or a glow underneath. |
| `insets` | `EdgeInsets.all(4)` | How far the box shrinks inside a row. |
| `checkColor` | `null` (themed) | The travelling selection tick; `Colors.transparent` hides it. |

**Physics**

| Field | Default | Meaning |
| :-- | :-- | :-- |
| `spring` | `mass 1, stiffness 600, damping 32` | Carries the box between options (damping ratio ≈ 0.65 — a crisp, small overshoot). |
| `velocityStretch` | `0.00016` | Squash slope at low speed. A brisk drag and a hard fling squash by _different_ amounts. |
| `maxStretch` | `0.12` | Ceiling the squash eases toward but never snaps to. Set to `0` to turn squash off. |
| `rubberBand` | `20` | The hard limit, in pixels, on overscroll past the first or last option. |
| `draggable` | `true` | Whether the box can be dragged and flung. |
| `commitOnRelease` | `true` | Whether a settle commits the value through `onChanged`. |

Two convenience getters help you reason about a spring: `dampingRatio` (below 1 overshoots) and `springSettles` (whether it will ever come to rest — the widgets fall back to an instant move when it would not). `SmoothHighlight` is pure data, so `copyWith`, `merge`, and `lerp` all behave.

---

## Keyboard and input

`SmoothSelect` is one focusable stop that behaves like a proper combobox. Focus stays on the field the whole time and never jumps into the list, so tab order stays sane. Arrow navigation drives the **same** spring‑glide highlight a drag does, so a keyboard walk looks exactly like a drag. A focus ring appears **only** under keyboard focus, and every key path is dormant under touch.

| Key | Action |
| :-- | :-- |
| `Enter` / `Space` | Open a closed list; commit the highlighted option and close an open one. |
| `↓` / `↑` | Move the highlight to the next / previous enabled option (glides). |
| `Home` / `End` | Jump the highlight to the first / last enabled option. |
| `Esc` | Close without changing the value (bubbles to a parent when already closed). |
| `Tab` | Close and move focus on. |

---

## Right-to-left

The package honours the ambient `Directionality` end to end. The rising reveal text lays out in the reading direction, and the travelling selection tick rides the **trailing** edge of the highlight — the right of the box in left‑to‑right, the left in right‑to‑left. Rows follow the same rule, so a `leading` widget always sits at the start.

```dart
Directionality(
  textDirection: TextDirection.rtl,
  child: SmoothSelect<int>(/* ... */),
);
```

---

## Reduced motion

When the OS "reduce motion" setting is on (`MediaQuery.disableAnimationsOf`), every widget stays fully functional and simply collapses to a fast, quiet transition. The selection highlight moves instantly instead of springing, and the layered channels stand down. Nothing is disabled — it is just calmer.

---

## Theming

Everything visible is data on a `SmoothStyle`, so two equal styles are truly equal.

### Per widget or shared

```dart
// One widget:
SmoothExpansionTile.text(
  title: 'Warm card',
  text: '...',
  style: const SmoothStyle(palette: SmoothPalette.orchid),
);

// A whole subtree — a single widget can still override on top:
SmoothTheme(
  data: const SmoothStyle(palette: SmoothPalette.mint),
  child: MyPage(),
);
```

### Palettes

Built‑in sets: `SmoothPalette.smoothGlass` (default), `SmoothPalette.orchid`, `SmoothPalette.mint`. Or build your own from five colors:

```dart
const SmoothPalette(
  accent: Color(0xFF06B6D4),
  accentBright: Color(0xFF67E8F9),
  accentDeep: Color(0xFF0E7490),
  fillTop: Color(0xFF0B1220),
  fillBottom: Color(0xFF020617),
);
```

### Motion spec

`SmoothMotionSpec` holds the timing and curves. Defaults:

| Field | Default |
| :-- | :-- |
| `expandDuration` / `collapseDuration` | `550ms` |
| `wavePeriod` | `1500ms` |
| `sheenDuration` | `800ms` |
| `reducedMotionDuration` | `120ms` |
| `hoverDuration` / `pressDuration` | `140ms` / `90ms` |
| `expandCurve` / `collapseCurve` | `easeOutCubic` / `easeInCubic` |
| `contentRevealCurve` | `easeOut` |
| `chevronCurve` | `easeOutBack` |

### Shape and channel toggles

`SmoothStyle` also carries `radius`, `waveAmplitude`, `waveSegments`, the paddings (`headerPadding`, `contentPadding`, `optionPadding`, `iconTilePadding`), `titleTextStyle`, `contentTextStyle`, and `highlightColor`. Each motion channel is an independent switch:

`showSheen` · `showRipple` · `showGlow` · `showSquash` · `showCrest` · `revealContent` · `leadingGlow`

Swap just the trailing mark with `trailing` (a `SmoothIndicatorBuilder`) or replace the whole header with `headerBuilder`.

---

## Programmatic control

Drive any tile or select from your own code with a `SmoothExpansionController`.

```dart
final controller = SmoothExpansionController();

SmoothExpansionTile(
  controller: controller,
  title: const Text('Driven'),
  child: const Text('...'),
);

// Later:
controller.expand();
controller.collapse();
controller.toggle();
final open = controller.isExpanded;
```

It is a `ChangeNotifier` — make one per widget and `dispose` it when you are done.

---

## Performance

- 🧵 **Render-layer motion.** Every channel is painted from animation values inside render objects. There is no `setState` and no `AnimatedBuilder` on the motion path.
- 💤 **Idle is free.** The wave and channels run only while a widget is actually moving, so a resting widget schedules no frames.
- 🧱 **Isolated repaints.** Expensive painters sit behind `RepaintBoundary`, and `Paint`/`Path` allocations are hoisted out of hot paint paths.
- 🎯 **Budget.** Built to hold a 60fps floor and 120fps on ProMotion displays.

---

## API at a glance

| Type | What it is |
| :-- | :-- |
| `SmoothExpansionTile` | Card that reveals any child with the full move. |
| `SmoothSelect<T>` | In-place, controlled select / combobox. |
| `SmoothPicker<T>` | Draggable, spring‑inertial picker column. |
| `SmoothHighlight` | Look and physics of the moving selection box. |
| `SmoothStyle` | All look and motion data for a widget. |
| `SmoothPalette` | A color set: `accent`, `accentBright`, `accentDeep`, `fillTop`, `fillBottom`. |
| `SmoothMotionSpec` | Durations and curves. |
| `SmoothTheme` | Share one `SmoothStyle` down the tree. |
| `SmoothExpansionController` | Open / close / toggle from your code. |
| `SmoothRevealText` | The rising text used inside a tile. |
| `SmoothDefaultIndicator` | The default animated chevron. |
| `SmoothMotionState` | `collapsed` · `expanding` · `expanded` · `collapsing`. |
| `SmoothTrace` | Opt-in debug tracing (off by default). |

---

## How it works

A few principles keep the motion coherent instead of merely busy:

- **Single source of truth.** One controller feeds every channel through derived curves and tweens — no independent, uncoordinated tickers, which is what makes drifting timing read as cheap.
- **Curves are chosen, not defaulted.** Each channel runs its own curve and timing offset; the highlight is carried by a real `SpringSimulation`, not a linear tween.
- **An explicit state machine.** Open, opening, closing, closed, hover, and press are named states (`SmoothMotionState`, `SmoothPickerPhase`) that drive the motion — never booleans scattered across the widget.
- **Guarded against jank.** The velocity squash is teleport‑guarded and eased frame to frame; a mid‑flight value change re‑aims the spring instead of snapping; a non‑settling spring falls back to an instant move so the box can never stick.

---

## Status and roadmap

- 📦 Current version: **0.1.0** — see [`CHANGELOG.md`](CHANGELOG.md).
- 🎬 Demo video: **coming soon** (it will be added to the top of this file).
- 📥 Not published to pub.dev yet — install by path or git for now.

---

## Contributing

Issues and pull requests are welcome at the [repository](https://github.com/nkalahanov/smooth_dropdown). The package uses `very_good_analysis`; please keep `dart analyze` clean and the test suite green before opening a PR.

---

## License

MIT — see [`LICENSE`](LICENSE).
