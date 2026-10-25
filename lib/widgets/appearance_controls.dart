import 'confirmation.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import '../l10n/l10n.dart';
import '../ui/ui.dart';
import '../ui/icons/icons.dart';
import '../ui/appearance.dart';
import '../ui/appearance_defaults.dart';
import '../ui/appearance_preview.dart';
import 'palette.dart';

const _unchangedColor = Object();

class AppearancePalette {
  const AppearancePalette({
    this.primaryColor = defaultPrimaryColor,
    this.primaryColors = defaultPrimaryColors,
    this.colorStyle = ColorStyle.vivid,
  });
  final int? primaryColor;
  final List<int> primaryColors;
  final ColorStyle colorStyle;
  bool get isDefault =>
      primaryColor == defaultPrimaryColor &&
      listEquals(primaryColors, defaultPrimaryColors) &&
      colorStyle == ColorStyle.vivid;
  AppearancePalette copyWith({
    Object? primaryColor = _unchangedColor,
    List<int>? primaryColors,
    ColorStyle? colorStyle,
  }) => AppearancePalette(
    primaryColor: identical(primaryColor, _unchangedColor)
        ? this.primaryColor
        : primaryColor as int?,
    primaryColors: primaryColors ?? this.primaryColors,
    colorStyle: colorStyle ?? this.colorStyle,
  );
}

String colorStyleLabel(ColorStyle style, AppLocalizations l) => switch (style) {
  ColorStyle.vivid => l.vividStyle,
  ColorStyle.tinted => l.tintedStyle,
  ColorStyle.soft => l.softStyle,
  ColorStyle.monochrome => l.monochromeScheme,
};

class AppearancePaletteControl extends StatelessWidget {
  const AppearancePaletteControl({
    super.key,
    required this.value,
    required this.systemColor,
    required this.floatingBar,
    required this.liquidGlass,
    required this.pureBlack,
    required this.onChanged,
  });
  final AppearancePalette value;
  final Color systemColor;
  final bool floatingBar;
  final bool liquidGlass;
  final bool pureBlack;
  final ValueChanged<AppearancePalette> onChanged;

  Future<void> _handleReset(BuildContext context) async {
    final res = await confirmChange(
      context,
      message: AppLocalizations.of(context).resetTip,
      destructive: true,
      confirmText: AppLocalizations.of(context).reset,
    );
    if (res != true || !context.mounted) {
      return;
    }
    onChanged(const AppearancePalette());
  }

  Future<void> _handleDelete(BuildContext context, int color) async {
    final appLocalizations = AppLocalizations.of(context);
    final res = await confirmChange(
      context,
      message: appLocalizations.deleteTip(appLocalizations.color),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res != true || !context.mounted) {
      return;
    }
    _update((state) {
      final primaryColors = List<int>.from(state.primaryColors)..remove(color);
      var primaryColor = state.primaryColor;
      if (primaryColor == color) {
        primaryColor = primaryColors.contains(defaultPrimaryColor)
            ? defaultPrimaryColor
            : null;
      }
      return state.copyWith(
        primaryColors: primaryColors,
        primaryColor: primaryColor,
      );
    });
  }

  void _showColorSheet(
    BuildContext context,
    Color initialColor,
    ValueChanged<int> onConfirmed,
  ) {
    showSheet<void>(
      context: context,
      props: const SheetProps(detents: [0.9]),
      builder: (_) => _CustomColorSheet(
        initialColor: initialColor,
        floatingBar: floatingBar,
        liquidGlass: liquidGlass,
        colorStyle: value.colorStyle,
        pureBlack: pureBlack,
        onConfirmed: (color) {
          if (context.mounted) {
            onConfirmed(color);
          }
        },
      ),
    );
  }

  void _handleAdd(BuildContext context) {
    final primaryColor = value.primaryColor;
    _showColorSheet(
      context,
      primaryColor != null ? Color(primaryColor) : systemColor,
      (color) => _update(
        (state) => state.copyWith(
          primaryColors: state.primaryColors.contains(color)
              ? state.primaryColors
              : [...state.primaryColors, color],
          primaryColor: color,
        ),
      ),
    );
  }

  void _handleEdit(BuildContext context, int color) {
    _showColorSheet(
      context,
      Color(color),
      (edited) => _update((state) {
        final index = state.primaryColors.indexOf(color);
        if (edited == color || index == -1) {
          return state;
        }
        final primaryColors = List<int>.from(state.primaryColors);
        if (primaryColors.contains(edited)) {
          primaryColors.removeAt(index);
        } else {
          primaryColors[index] = edited;
        }
        return state.copyWith(
          primaryColors: primaryColors,
          primaryColor: state.primaryColor == color
              ? edited
              : state.primaryColor,
        );
      }),
    );
  }

  void _update(AppearancePalette Function(AppearancePalette state) update) =>
      onChanged(update(value));

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final themeColors = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoHeader(
          info: Info(
            label: appLocalizations.themeColor,
            glyph: AppGlyphs.palette,
          ),
          actions: [
            if (!themeColors.isDefault)
              _ResetButton(onPressed: () => _handleReset(context)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              _ColorSwatches(
                colors: [null, ...themeColors.primaryColors],
                systemColor: systemColor,
                selected: themeColors.primaryColor,
                onSelect: (color) =>
                    _update((state) => state.copyWith(primaryColor: color)),
                onEdit: (color) => _handleEdit(context, color),
                onDelete: (color) => _handleDelete(context, color),
                onAdd: () => _handleAdd(context),
              ),
              generateSection(
                items: [
                  ListItem<ColorStyle>.options(
                    title: Text(appLocalizations.colorStyle),
                    options: ColorStyle.values,
                    value: themeColors.colorStyle,
                    textBuilder: (style) =>
                        colorStyleLabel(style, appLocalizations),
                    onChanged: (style) =>
                        _update((state) => state.copyWith(colorStyle: style)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({
    required this.colors,
    required this.systemColor,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  static const double _minGap = 6;

  // Lines the dots, not their selection rings, up with the rows' text.
  static const double _inset = 16 - (_ColorSwatch.size - _ColorSwatch.dot) / 2;

  final List<int?> colors;
  final Color systemColor;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final level = context.raisedSurfaceLevel;
    return Container(
      padding: const EdgeInsets.all(_inset),
      decoration: ShapeDecoration(
        color: level.colorOf(colorScheme),
        shape: AppShape.xl,
      ),
      child: SurfaceScope(
        level: level,
        child: LayoutBuilder(
          builder: (_, constraints) {
            const cell = _ColorSwatch.size;
            final width = constraints.maxWidth;
            final columns = max(
              1,
              ((width + _minGap) / (cell + _minGap)).floor(),
            );
            final gap = columns > 1
                ? ((width - columns * cell) / (columns - 1)).floorToDouble()
                : 0.0;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final color in colors)
                  _ColorSwatch(
                    color: color == null ? null : Color(color),
                    systemColor: systemColor,
                    isSelected: color == selected,
                    label: color == null
                        ? appLocalizations.followSystem
                        : Color(color).hex,
                    onPressed: () => onSelect(color),
                    menuItems: color == null
                        ? null
                        : [
                            CommonPopupMenuItem(
                              glyph: AppGlyphs.edit,
                              label: appLocalizations.edit,
                              onPressed: () => onEdit(color),
                            ),
                            CommonPopupMenuItem(
                              danger: true,
                              glyph: AppGlyphs.delete,
                              label: appLocalizations.delete,
                              onPressed: () => onDelete(color),
                            ),
                          ],
                  ),
                _AddColorButton(onPressed: onAdd),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatefulWidget {
  const _ColorSwatch({
    required this.color,
    required this.systemColor,
    required this.isSelected,
    required this.label,
    required this.onPressed,
    this.menuItems,
  });

  static const double size = 44;
  static const double dot = 32;
  static const double _ring = 2.5;
  static const _duration = Duration(milliseconds: 200);

  static const double _badge = 20;

  /// Null follows the system's accent color, [systemColor].
  final Color? color;
  final Color systemColor;
  final bool isSelected;
  final String label;
  final VoidCallback onPressed;
  final List<CommonPopupMenuItem>? menuItems;

  @override
  State<_ColorSwatch> createState() => _ColorSwatchState();
}

class _ColorSwatchState extends State<_ColorSwatch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final fill = color ?? widget.systemColor;
    final selected = widget.isSelected;
    final check = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final swatch = Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      child: SizedBox.square(
        dimension: _ColorSwatch.size,
        child: Material(
          type: MaterialType.transparency,
          shape: AppShape.circle,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: AppShape.circle,
            onTap: widget.onPressed,
            onFocusChange: (value) => setState(() => _focused = value),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: selected || _focused ? 1 : 0,
                  duration: _ColorSwatch._duration,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: AppShape.circle.copyWith(
                        side: BorderSide(
                          color: selected ? fill : context.colorScheme.primary,
                          width: _ColorSwatch._ring,
                        ),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                SizedBox.square(
                  dimension: _ColorSwatch.dot,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill,
                      shape: AppShape.circle,
                    ),
                  ),
                ),
                if (color == null)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: _EyedropperBadge(size: _ColorSwatch._badge),
                  ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: _ColorSwatch._duration,
                  curve: Curves.easeOutBack,
                  child: GlyphIcon(
                    AppGlyphs.check,
                    size: 18,
                    fill: 1,
                    color: check,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final menuItems = widget.menuItems;
    if (menuItems == null) {
      return swatch;
    }
    return ContextMenuRegion(menuItems: menuItems, child: swatch);
  }
}

class _EyedropperBadge extends StatelessWidget {
  const _EyedropperBadge({required this.size});

  static const double _gap = 2;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(_gap),
      decoration: ShapeDecoration(
        color: context.surfaceLevel.colorOf(colorScheme),
        shape: AppShape.circle,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.raisedSurfaceLevel.colorOf(colorScheme),
          shape: AppShape.circle,
        ),
        child: Center(
          child: GlyphIcon(
            AppGlyphs.eyedropper,
            size: size - _gap * 2 - 4,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _AddColorButton extends StatelessWidget {
  const _AddColorButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Tooltip(
      message: AppLocalizations.of(context).add,
      child: Semantics(
        button: true,
        child: SizedBox.square(
          dimension: _ColorSwatch.size,
          child: Material(
            type: MaterialType.transparency,
            shape: AppShape.circle,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: AppShape.circle,
              onTap: onPressed,
              child: Center(
                child: Container(
                  width: _ColorSwatch.dot,
                  height: _ColorSwatch.dot,
                  decoration: ShapeDecoration(
                    color: context.raisedSurfaceLevel.colorOf(colorScheme),
                    shape: AppShape.circle,
                  ),
                  child: GlyphIcon(
                    AppGlyphs.add,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PureBlackChoice extends StatelessWidget {
  final bool value;
  final ColorScheme standardScheme;
  final ColorScheme blackScheme;
  final bool floatingBar;
  final bool liquidGlass;
  final ValueChanged<bool> onChanged;
  const PureBlackChoice({
    super.key,
    required this.value,
    required this.standardScheme,
    required this.blackScheme,
    required this.floatingBar,
    required this.liquidGlass,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    Widget preview(bool pureBlack) => MiniScreenThumb(
      screen: MiniScreen(
        colorScheme: pureBlack ? blackScheme : standardScheme,
        floatingBar: floatingBar,
        liquidGlass: liquidGlass,
      ),
    );
    return PreviewChoiceGroup<bool>(
      info: Info(
        label: appLocalizations.pureBlackMode,
        glyph: AppGlyphs.pureBlack,
      ),
      value: value,
      choices: [
        PreviewChoice(
          value: false,
          label: appLocalizations.standard,
          pictogram: preview(false),
        ),
        PreviewChoice(
          value: true,
          label: appLocalizations.pureBlack,
          pictogram: preview(true),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class NavigationBarChoice extends StatelessWidget {
  final bool value;
  final bool liquidGlass;
  final ValueChanged<bool> onChanged;
  const NavigationBarChoice({
    super.key,
    required this.value,
    required this.liquidGlass,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    return PreviewChoiceGroup<bool>(
      info: Info(
        label: appLocalizations.navigationBarStyle,
        glyph: AppGlyphs.layers,
      ),
      value: value,
      choices: [
        PreviewChoice(
          value: true,
          label: appLocalizations.floating,
          pictogram: MiniScreenThumb(
            screen: MiniScreen(
              colorScheme: colorScheme,
              floatingBar: true,
              liquidGlass: liquidGlass,
            ),
          ),
        ),
        PreviewChoice(
          value: false,
          label: appLocalizations.docked,
          pictogram: MiniScreenThumb(
            screen: MiniScreen(colorScheme: colorScheme, floatingBar: false),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class TabAnimationChoice extends StatelessWidget {
  final TabAnimation value;
  final bool floatingBar;
  final bool liquidGlass;
  final ValueChanged<TabAnimation> onChanged;
  const TabAnimationChoice({
    super.key,
    required this.value,
    required this.floatingBar,
    required this.liquidGlass,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    Widget switching(TabAnimation tabAnimation) => MiniScreenThumb(
      screen: MiniScreen(
        colorScheme: colorScheme,
        floatingBar: floatingBar,
        liquidGlass: liquidGlass,
        selected: 1,
        previous: 0,
        progress: 0.55,
        tabAnimation: tabAnimation,
      ),
    );
    return PreviewChoiceGroup<TabAnimation>(
      info: Info(label: appLocalizations.tabAnimation, glyph: AppGlyphs.motion),
      value: value,
      choices: [
        PreviewChoice(
          value: TabAnimation.slide,
          label: appLocalizations.slide,
          pictogram: switching(TabAnimation.slide),
        ),
        PreviewChoice(
          value: TabAnimation.fade,
          label: appLocalizations.fade,
          pictogram: switching(TabAnimation.fade),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class TextScaleControl extends StatefulWidget {
  const TextScaleControl({
    super.key,
    required this.enabled,
    required this.scale,
    required this.systemScale,
    required this.onChanged,
  });
  final bool enabled;
  final double scale;
  final double systemScale;
  final void Function(bool enabled, double scale) onChanged;

  static const _step = 0.05;

  @override
  State<TextScaleControl> createState() => TextScaleControlState();
}

class TextScaleControlState extends State<TextScaleControl> {
  double? _draft;

  void _update({bool? enabled, double? scale}) {
    setState(() => _draft = null);
    widget.onChanged(enabled ?? widget.enabled, scale ?? widget.scale);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final systemScale = widget.systemScale
        .clamp(minTextScale, maxTextScale)
        .toDouble();
    final scale = _draft ?? (widget.enabled ? widget.scale : systemScale);
    final percent = '${(scale * 100).round()}%';
    final level = context.raisedSurfaceLevel;
    final divisions = ((maxTextScale - minTextScale) / TextScaleControl._step)
        .round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoHeader(
          info: Info(
            label: appLocalizations.textScale,
            glyph: AppGlyphs.textSize,
          ),
          actions: [
            if (widget.enabled && widget.scale != 1)
              _ResetButton(onPressed: () => _update(scale: 1)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            spacing: 8,
            children: [
              SegmentedControl<bool>(
                segments: [
                  (false, appLocalizations.followSystem),
                  (true, appLocalizations.custom),
                ],
                value: widget.enabled,
                onChanged: (value) => _update(enabled: value),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: ShapeDecoration(
                  color: level.colorOf(colorScheme),
                  shape: AppShape.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Expanded(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topLeft,
                            child: MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(textScaler: TextScaler.linear(scale)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 4,
                                children: [
                                  Text(
                                    'Aa',
                                    style: AppTextStyle.title3.of(context),
                                  ),
                                  Text(
                                    appLocalizations.textScalePreview,
                                    style: AppTextStyle.subheadline
                                        .of(context)
                                        .copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: ShapeDecoration(
                            color: level.next.colorOf(colorScheme),
                            shape: AppShape.full,
                          ),
                          child: Text(
                            percent,
                            style: AppTextStyle.subheadline
                                .of(context, emphasized: true)
                                .copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MediaQuery.withNoTextScaling(
                      child: Row(
                        spacing: 12,
                        children: [
                          ExcludeSemantics(
                            child: Text(
                              'A',
                              style: AppTextStyle.footnote
                                  .of(context)
                                  .copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderDefaultsM3(context),
                              child: Slider(
                                padding: EdgeInsets.zero,
                                min: minTextScale,
                                max: maxTextScale,
                                divisions: divisions,
                                value: scale,
                                label: percent,
                                onChanged: widget.enabled
                                    ? (value) => setState(() => _draft = value)
                                    : null,
                                onChangeEnd: (value) => _update(scale: value),
                              ),
                            ),
                          ),
                          ExcludeSemantics(
                            child: Text(
                              'A',
                              style: AppTextStyle.title2
                                  .of(context)
                                  .copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TonalButtonTheme(
      size: TonalButtonSize.section,
      child: ElasticPress(
        child: IconButton(
          tooltip: AppLocalizations.of(context).reset,
          onPressed: onPressed,
          icon: const GlyphIcon(AppGlyphs.reset),
        ),
      ),
    );
  }
}

class _CustomColorSheet extends StatefulWidget {
  const _CustomColorSheet({
    required this.initialColor,
    required this.onConfirmed,
    required this.floatingBar,
    required this.liquidGlass,
    required this.colorStyle,
    required this.pureBlack,
  });

  final Color initialColor;
  final bool floatingBar;
  final bool liquidGlass;
  final ColorStyle colorStyle;
  final bool pureBlack;

  /// Runs once the sheet has closed, so retheming every page cannot stall it.
  final ValueChanged<int> onConfirmed;

  @override
  State<_CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<_CustomColorSheet> {
  late final _controller = ValueNotifier<Color>(widget.initialColor);

  void _confirm() {
    final color = _controller.value.toARGB32();
    final onConfirmed = widget.onConfirmed;
    unawaited(
      ModalRoute.of(context)!.completed.whenComplete(() => onConfirmed(color)),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    // Clears Android's edge back-swipe zone; exclusion rects stop at 200 dp.
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
    return CommonScaffold(
      title: appLocalizations.customColor,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: appLocalizations.confirm,
        onPressed: _confirm,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          max(16, gestureInsets.left),
          context.contentTopPadding,
          max(16, gestureInsets.right),
          20,
        ),
        children: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, color, _) => _CustomColorPreview(
              color: color,
              floatingBar: widget.floatingBar,
              liquidGlass: widget.liquidGlass,
              colorStyle: widget.colorStyle,
              pureBlack: widget.pureBlack,
              onChanged: (color) => _controller.value = color,
            ),
          ),
          const SizedBox(height: 16),
          Palette(controller: _controller),
        ],
      ),
    );
  }
}

class _CustomColorPreview extends StatelessWidget {
  const _CustomColorPreview({
    required this.color,
    required this.onChanged,
    required this.floatingBar,
    required this.liquidGlass,
    required this.colorStyle,
    required this.pureBlack,
  });
  final bool floatingBar;
  final bool liquidGlass;
  final ColorStyle colorStyle;
  final bool pureBlack;

  static const Size _screenSize = Size(96, 128);
  static const double _scale = 0.75;

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final level = context.raisedSurfaceLevel;
    Widget screen(Brightness brightness) => ExcludeSemantics(
      child: SizedBox.fromSize(
        size: _screenSize * _scale,
        child: ClipRSuperellipse(
          borderRadius: AppRadius.md,
          child: FittedBox(
            child: SizedBox.fromSize(
              size: _screenSize,
              child: MiniScreen(
                colorScheme: seededColorScheme(
                  seedColor: color,
                  brightness: brightness,
                  style: colorStyle,
                ).toPureBlack(pureBlack),
                floatingBar: floatingBar,
                liquidGlass: liquidGlass,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: level.colorOf(context.colorScheme),
        shape: AppShape.xl,
      ),
      child: SurfaceScope(
        level: level,
        child: Row(
          spacing: 12,
          children: [
            screen(Brightness.light),
            screen(Brightness.dark),
            Expanded(
              child: HexColorField(color: color, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class AppearanceFontControl extends StatelessWidget {
  const AppearanceFontControl({
    super.key,
    required this.fontFamily,
    required this.label,
    required this.pageBuilder,
  });
  final String? fontFamily;
  final String label;
  final WidgetBuilder pageBuilder;
  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final preview = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        spacing: 12,
        children: [
          Text(
            'Aa',
            style: AppTextStyle.headline
                .of(context)
                .copyWith(fontFamily: fontFamily),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.subheadline
                  .of(context)
                  .copyWith(
                    fontFamily: fontFamily,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          GlyphIcon(
            AppGlyphs.chevronForward,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
    final cardColor = context.raisedSurfaceLevel.colorOf(colorScheme);
    Widget card(VoidCallback onTap) => Material(
      color: cardColor,
      shape: AppShape.lg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(customBorder: AppShape.lg, onTap: onTap, child: preview),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoHeader(
          info: Info(label: appLocalizations.fontFamily, glyph: AppGlyphs.font),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: context.isMobileView
              ? OpenContainer<void>(
                  closedShape: AppShape.lg,
                  closedColor: cardColor,
                  closedBuilder: (_, open) => card(open),
                  openBuilder: (_, _) => pageBuilder(context),
                )
              : card(
                  () => showSheet<void>(
                    context: context,
                    builder: (_) => pageBuilder(context),
                  ),
                ),
        ),
      ],
    );
  }
}
