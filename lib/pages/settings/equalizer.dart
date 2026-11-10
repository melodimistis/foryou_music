import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../models/equalizer.dart';
import '../../providers/equalizer_controller.dart';
import '../../providers/notice_controller.dart';
import '../../services/audio/autoeq_parser.dart';
import '../../services/audio/eq_curve.dart';
import '../../widgets/info_blocks.dart';
import '../../widgets/settings_scaffold.dart';
import 'storage.dart' show confirmAction;
import '../../widgets/rounded_ink.dart';

typedef EqFile = ({String name, List<int> bytes});
typedef EqFilePicker = Future<EqFile?> Function();

class EqFormat {
  static String _trim(String text) => text.contains('.')
      ? text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : text;

  static String hz(double f) {
    if (f >= 1000) {
      final k = f / 1000;
      return '${_trim(k.toStringAsFixed(k >= 10 ? 1 : 2))} kHz';
    }
    return '${_trim(f.toStringAsFixed(f < 100 ? 1 : 0))} Hz';
  }

  static String db(double gain) {
    if (gain.abs() < 0.05) return '0.0 dB';
    return '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)} dB';
  }

  static String q(double q) => q.toStringAsFixed(2);

  static double significant(double value, int digits) {
    if (value <= 0 || !value.isFinite) return value;
    final unit = pow(10, (log(value) / ln10).floor() - digits + 1).toDouble();
    return (value / unit).roundToDouble() * unit;
  }

  static double? parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));
}

class EqGraphScale {
  const EqGraphScale(this.size);

  static const height = 220.0;
  static const _octaves = EqFilter.maxFrequency / EqFilter.minFrequency;

  final Size size;

  Rect get plot => Rect.fromLTRB(14, 14, size.width - 14, size.height - 24);

  double x(double hz) =>
      plot.left +
      plot.width *
          (log(
                hz.clamp(EqFilter.minFrequency, EqFilter.maxFrequency) /
                    EqFilter.minFrequency,
              ) /
              log(_octaves));

  double y(double gain) =>
      plot.center.dy - plot.height / 2 * (gain / EqFilter.maxGain);

  double frequencyAt(double dx) {
    final t = ((dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return EqFilter.minFrequency * pow(_octaves, t);
  }

  double gainAt(double dy) =>
      ((plot.center.dy - dy) / (plot.height / 2) * EqFilter.maxGain).clamp(
        -EqFilter.maxGain,
        EqFilter.maxGain,
      );

  Offset point(EqFilter f) => Offset(x(f.frequency), y(f.gain));
}

class _EagerPanRecognizer extends PanGestureRecognizer {
  _EagerPanRecognizer(this.allows);

  bool Function(Offset local) allows;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      allows(event.localPosition) && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class EqGraph extends StatefulWidget {
  const EqGraph({
    super.key,
    required this.profile,
    required this.selected,
    required this.active,
    required this.onSelect,
    required this.onChanged,
    required this.onChangeEnd,
  });

  static const grabRadius = 30.0;

  final EqProfile profile;
  final int selected;
  final bool active;
  final ValueChanged<int> onSelect;
  final void Function(int index, EqFilter filter) onChanged;
  final VoidCallback onChangeEnd;

  @override
  State<EqGraph> createState() => _EqGraphState();
}

class _EqGraphState extends State<EqGraph> {
  int _dragging = -1;
  Size _size = Size.zero;

  int _hit(Offset at) {
    final scale = EqGraphScale(_size);
    var best = -1;
    var bestDistance = EqGraph.grabRadius;
    final filters = widget.profile.filters;
    for (var i = 0; i < filters.length; i++) {
      final d = (scale.point(filters[i]) - at).distance;
      final wins = i == widget.selected ? d <= bestDistance : d < bestDistance;
      if (wins) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  void _move(Offset at) {
    final i = _dragging;
    if (i < 0 || i >= widget.profile.filters.length) return;
    final scale = EqGraphScale(_size);
    widget.onChanged(
      i,
      widget.profile.filters[i].copyWith(
        frequency: EqFormat.significant(scale.frequencyAt(at.dx), 3),
        gain: (scale.gainAt(at.dy) * 10).roundToDouble() / 10,
      ),
    );
  }

  void _end() {
    if (_dragging >= 0) widget.onChangeEnd();
    _dragging = -1;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: EqGraphScale.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          return RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _EagerPanRecognizer:
                  GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
                    () => _EagerPanRecognizer((at) => _hit(at) >= 0),
                    (recognizer) => recognizer
                      ..allows = ((at) => _hit(at) >= 0)
                      ..onDown = (details) {
                        _dragging = _hit(details.localPosition);
                        if (_dragging >= 0) widget.onSelect(_dragging);
                      }
                      ..onUpdate = ((details) => _move(details.localPosition))
                      ..onEnd = ((_) => _end())
                      ..onCancel = _end,
                  ),
            },
            child: CustomPaint(
              size: _size,
              painter: _EqGraphPainter(
                profile: widget.profile,
                selected: widget.selected,
                active: widget.active,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EqGraphPainter extends CustomPainter {
  _EqGraphPainter({
    required this.profile,
    required this.selected,
    required this.active,
  });

  final EqProfile profile;
  final int selected;
  final bool active;

  static const _lines = <double>[50, 100, 200, 500, 1000, 2000, 5000, 10000];
  static const _gains = <double>[-12, -6, 0, 6, 12];

  static String? _label(double hz) => switch (hz) {
    100 => '100',
    1000 => '1k',
    10000 => '10k',
    _ => null,
  };

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    Color color = Colors.white38,
    double size = 10,
    FontWeight weight = FontWeight.w500,
    bool centered = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'Inter',
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centered
          ? at - Offset(painter.width / 2, painter.height / 2)
          : at - Offset(painter.width / 2, 0),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = EqGraphScale(size);
    final plot = scale.plot;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      Paint()..color = AppColors.surface,
    );

    final grid = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    for (final hz in _lines) {
      final x = scale.x(hz);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      final label = _label(hz);
      if (label != null) _text(canvas, label, Offset(x, plot.bottom + 6));
    }
    for (final gain in _gains) {
      final y = scale.y(gain);
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..color = gain == 0 ? Colors.white24 : Colors.white10
          ..strokeWidth = 1,
      );
    }
    _text(canvas, '+12', Offset(plot.left + 12, scale.y(12) + 3));
    _text(canvas, '-12', Offset(plot.left + 12, scale.y(-12) - 15));

    const steps = 160;
    final line = Path();
    final area = Path()..moveTo(plot.left, scale.y(0));
    for (var i = 0; i <= steps; i++) {
      final x = plot.left + plot.width * i / steps;
      final y = scale.y(EqCurve.gainAt(profile, scale.frequencyAt(x)));
      i == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
      area.lineTo(x, y);
    }
    area
      ..lineTo(plot.right, scale.y(0))
      ..close();
    canvas.save();
    canvas.clipRect(plot.inflate(1));
    canvas.drawPath(
      area,
      Paint()
        ..color = active ? const Color(0x1AFFFFFF) : const Color(0x0DFFFFFF),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = active ? Colors.white : Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    final order = [
      for (var i = 0; i < profile.filters.length; i++)
        if (i != selected) i,
      if (selected >= 0 && selected < profile.filters.length) selected,
    ];
    for (final i in order) {
      final f = profile.filters[i];
      final at = scale.point(f);
      final chosen = i == selected;
      final strong = f.enabled && active;
      canvas.drawCircle(
        at,
        chosen ? 12 : 10,
        Paint()..color = chosen ? Colors.white : AppColors.background,
      );
      if (!chosen) {
        canvas.drawCircle(
          at,
          10,
          Paint()
            ..color = strong ? Colors.white : Colors.white38
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      _text(
        canvas,
        '${i + 1}',
        at,
        color: chosen
            ? Colors.black
            : strong
            ? Colors.white
            : Colors.white38,
        size: 11,
        weight: FontWeight.w800,
        centered: true,
      );
    }
  }

  @override
  bool shouldRepaint(_EqGraphPainter old) =>
      old.profile != profile ||
      old.selected != selected ||
      old.active != active;
}

const _title = TextStyle(
  color: Colors.white,
  fontFamily: 'Inter',
  fontSize: 16,
  fontWeight: FontWeight.w600,
);
const _subtitle = TextStyle(
  color: Colors.white54,
  fontFamily: 'Inter',
  fontSize: 13,
);
const _value = TextStyle(
  color: Colors.white70,
  fontFamily: 'Inter',
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key, this.pickFile});

  static const maxFileBytes = 256 * 1024;

  final EqFilePicker? pickFile;

  static Future<EqFile?> pickFromDevice() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a ParametricEQ.txt file',
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length != null && length > maxFileBytes) {
      return (name: file.name, bytes: const <int>[]);
    }
    return (name: file.name, bytes: await file.readAsBytes());
  }

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  int _selected = -1;

  static String _status(EqStatus status) => switch (status) {
    EqStatus.unsupported => 'Not available on this device',
    EqStatus.off => 'Off. Music plays exactly as it is.',
    EqStatus.active => 'On',
    EqStatus.failed =>
      'Could not start on this device. Music keeps playing without it.',
  };

  Future<void> _add(EqualizerController eq) async {
    final index = await eq.addFilter();
    if (!mounted) return;
    if (index < 0) {
      context.read<NoticeController>().show(
        'A preset holds up to ${EqProfile.maxFilters} filters',
        icon: Icons.tune_rounded,
      );
      return;
    }
    setState(() => _selected = index);
  }

  Future<void> _remove(EqualizerController eq, int index) async {
    await eq.removeFilter(index);
    if (mounted) setState(() => _selected = -1);
  }

  Future<void> _reset(EqualizerController eq) async {
    if (eq.matchingPreset == null && eq.profile.filters.isNotEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Reset the equalizer?',
        body:
            'Your unsaved changes are removed and the sound goes back to '
            'flat. Saved presets stay.',
        action: 'Reset',
      );
      if (!ok) return;
    }
    await eq.reset();
    if (mounted) setState(() => _selected = -1);
  }

  Future<void> _saveAs(EqualizerController eq) async {
    final notices = context.read<NoticeController>();
    final known = eq.userPresets.any((p) => p.name == eq.profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: known ? eq.profile.name : ''),
    );
    if (name == null) return;
    final error = await eq.saveAs(name);
    notices.show(
      error ?? 'Saved "${name.trim()}"',
      icon: error == null ? Icons.check_rounded : Icons.error_outline_rounded,
    );
  }

  Future<void> _deletePreset(EqualizerController eq, EqProfile preset) async {
    final notices = context.read<NoticeController>();
    final ok = await confirmAction(
      context,
      title: 'Delete "${preset.name}"?',
      body: 'The preset is removed. The sound you hear now does not change.',
      action: 'Delete',
    );
    if (!ok) return;
    await eq.deletePreset(preset.name);
    notices.show(
      'Deleted "${preset.name}"',
      icon: Icons.delete_outline_rounded,
    );
  }

  Future<void> _import(EqualizerController eq) async {
    final notices = context.read<NoticeController>();
    final EqFile? file;
    try {
      file = await (widget.pickFile ?? EqualizerPage.pickFromDevice)();
    } catch (e) {
      debugPrint('Could not open the file: $e');
      notices.show(
        'Could not open that file',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    if (file == null) return;
    if (file.bytes.isEmpty || file.bytes.length > EqualizerPage.maxFileBytes) {
      notices.show(
        'That does not look like a ParametricEQ.txt file',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    final result = await eq.importAutoEq(
      AutoEqParser.decode(file.bytes),
      name: file.name,
    );
    if (!mounted) return;
    if (result.isEmpty) {
      notices.show(
        'No filters found. Choose the ParametricEQ.txt file from AutoEq.',
        icon: Icons.error_outline_rounded,
        duration: const Duration(seconds: 5),
      );
      return;
    }
    setState(() => _selected = -1);
    final count = result.filters.length;
    final skipped = result.skipped == 0 ? '' : ', ${result.skipped} left out';
    notices.show(
      'Imported $count ${count == 1 ? 'filter' : 'filters'}$skipped',
      icon: Icons.check_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.watch<EqualizerController>();
    if (!eq.supported) {
      return const SettingsScaffold(
        title: 'Equalizer',
        children: [
          InfoSection(
            'Not available on this device',
            'The equalizer needs Android 9 or newer. It is not available on '
                'Linux or Windows yet. Music plays exactly as it is.',
          ),
        ],
      );
    }

    final profile = eq.profile;
    final selected = _selected < profile.filters.length ? _selected : -1;
    final matching = eq.matchingPreset;
    final headroom = eq.headroom;

    return SettingsScaffold(
      title: 'Equalizer',
      children: [
        TileBleed(
          child: SwitchListTile(
            contentPadding: TileBleed.padding,
            title: const Text('Equalizer', style: _title),
            subtitle: Text(_status(eq.status), style: _subtitle),
            value: eq.enabled,
            onChanged: eq.setEnabled,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final preset in eq.presets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Pill(
                    label: preset.name,
                    selected: identical(preset, matching),
                    onTap: () {
                      setState(() => _selected = -1);
                      eq.select(preset);
                    },
                    onLongPress: EqualizerController.isBuiltIn(preset.name)
                        ? null
                        : () => _deletePreset(eq, preset),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EqGraph(
          profile: profile,
          selected: selected,
          active: eq.enabled,
          onSelect: (i) => setState(() => _selected = i),
          onChanged: (i, f) => eq.updateFilter(i, f, persist: false),
          onChangeEnd: eq.save,
        ),
        const SizedBox(height: 8),
        Text(
          profile.filters.isEmpty
              ? 'Flat. Add a filter or pick a preset to shape the sound.'
              : headroom > 0.05
              ? 'Volume lowered by ${headroom.toStringAsFixed(1)} dB so the '
                    'boost does not distort.'
              : 'Drag a point, or tap it to fine-tune below.',
          style: _subtitle,
        ),
        const SizedBox(height: 16),
        if (selected >= 0)
          _FilterEditor(
            index: selected,
            filter: profile.filters[selected],
            onChanged: (f, {persist = true}) =>
                eq.updateFilter(selected, f, persist: persist),
            onCommit: eq.save,
            onRemove: () => _remove(eq, selected),
          ),
        for (var i = 0; i < profile.filters.length; i++)
          _FilterRow(
            index: i,
            filter: profile.filters[i],
            selected: i == selected,
            onTap: () => setState(() => _selected = i == selected ? -1 : i),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            _Action(
              icon: Icons.add_rounded,
              label: profile.isFull
                  ? '${EqProfile.maxFilters} of ${EqProfile.maxFilters} filters'
                  : 'Add filter',
              onTap: profile.isFull ? null : () => _add(eq),
            ),
            _Action(
              icon: Icons.file_open_outlined,
              label: 'Import AutoEq',
              onTap: () => _import(eq),
            ),
            _Action(
              icon: Icons.bookmark_add_outlined,
              label: 'Save as preset',
              onTap: profile.filters.isEmpty ? null : () => _saveAs(eq),
            ),
            _Action(
              icon: Icons.restart_alt_rounded,
              label: 'Reset',
              onTap: profile.filters.isEmpty ? null : () => _reset(eq),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const InfoSection(
          'How it works',
          'Each filter raises or lowers one part of the sound. Peak shapes '
              'the area around its frequency, low shelf everything below it '
              'and high shelf everything above it. Q sets how wide a filter '
              'reaches: a lower Q is wider and gentler.',
        ),
        const InfoSection(
          'Why a boost lowers the volume',
          'When you raise part of the sound, the whole song is turned down '
              'by the same amount so loud moments do not distort. Lowering '
              'what you have too much of keeps the volume up.',
        ),
        const InfoSection(
          'Headphone profiles',
          'AutoEq publishes tuning profiles for thousands of headphones. '
              'Download the ParametricEQ.txt file for yours, tap Import '
              'AutoEq and choose it. Long press a saved preset to delete it.',
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? Colors.white : Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.index,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final EqFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !filter.enabled
        ? Colors.white38
        : selected
        ? Colors.white
        : Colors.white70;
    final style = TextStyle(
      color: color,
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 28, child: Text('${index + 1}', style: style)),
            Expanded(
              flex: 5,
              child: Text(
                filter.enabled
                    ? filter.type.label
                    : '${filter.type.label}, off',
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(EqFormat.hz(filter.frequency), style: style),
            ),
            Expanded(
              flex: 4,
              child: Text(
                EqFormat.db(filter.gain),
                style: style,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterEditor extends StatelessWidget {
  const _FilterEditor({
    required this.index,
    required this.filter,
    required this.onChanged,
    required this.onCommit,
    required this.onRemove,
  });

  final int index;
  final EqFilter filter;
  final void Function(EqFilter filter, {bool persist}) onChanged;
  final VoidCallback onCommit;
  final VoidCallback onRemove;

  static const _frequencySpan = EqFilter.maxFrequency / EqFilter.minFrequency;
  static const _qSpan = EqFilter.maxQ / EqFilter.minQ;

  Future<void> _type(
    BuildContext context,
    String title,
    String unit,
    double current,
    EqFilter Function(double value) apply,
  ) async {
    final typed = await showDialog<double>(
      context: context,
      builder: (context) =>
          _NumberDialog(title: title, unit: unit, initial: current),
    );
    if (typed != null) onChanged(apply(typed));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Filter ${index + 1}', style: _title)),
              Switch(
                value: filter.enabled,
                onChanged: (v) => onChanged(filter.copyWith(enabled: v)),
              ),
              IconButton(
                tooltip: 'Remove filter',
                color: Colors.white70,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onRemove,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4, bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in EqFilterType.values)
                  _Pill(
                    label: type.label,
                    selected: type == filter.type,
                    onTap: () => onChanged(
                      filter.copyWith(
                        type: type,
                        q: type == filter.type
                            ? filter.q
                            : type == EqFilterType.peak
                            ? EqFilter.defaultQ
                            : EqFilter.shelfQ,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _Dial(
            label: 'Frequency',
            text: EqFormat.hz(filter.frequency),
            value:
                log(filter.frequency / EqFilter.minFrequency) /
                log(_frequencySpan),
            onChanged: (t) => onChanged(
              filter.copyWith(
                frequency: EqFormat.significant(
                  EqFilter.minFrequency * pow(_frequencySpan, t),
                  3,
                ),
              ),
              persist: false,
            ),
            onCommit: onCommit,
            onType: () => _type(
              context,
              'Frequency',
              'Hz',
              filter.frequency,
              (v) => filter.copyWith(frequency: v),
            ),
          ),
          _Dial(
            label: 'Gain',
            text: EqFormat.db(filter.gain),
            value: (filter.gain + EqFilter.maxGain) / (2 * EqFilter.maxGain),
            divisions: (EqFilter.maxGain * 4).round(),
            onChanged: (t) => onChanged(
              filter.copyWith(
                gain: (t * 2 * EqFilter.maxGain - EqFilter.maxGain),
              ),
              persist: false,
            ),
            onCommit: onCommit,
            onType: () => _type(
              context,
              'Gain',
              'dB',
              filter.gain,
              (v) => filter.copyWith(gain: v),
            ),
          ),
          _Dial(
            label: 'Q',
            text: EqFormat.q(filter.q),
            value: log(filter.q / EqFilter.minQ) / log(_qSpan),
            onChanged: (t) => onChanged(
              filter.copyWith(
                q: EqFormat.significant(EqFilter.minQ * pow(_qSpan, t), 2),
              ),
              persist: false,
            ),
            onCommit: onCommit,
            onType: () =>
                _type(context, 'Q', '', filter.q, (v) => filter.copyWith(q: v)),
          ),
        ],
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({
    required this.label,
    required this.text,
    required this.value,
    required this.onChanged,
    required this.onCommit,
    required this.onType,
    this.divisions,
  });

  final String label;
  final String text;
  final double value;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final VoidCallback onCommit;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 76, child: Text(label, style: _subtitle)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white12,
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
              trackHeight: 2,
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              divisions: divisions,
              semanticFormatterCallback: (_) => '$label $text',
              onChanged: onChanged,
              onChangeEnd: (_) => onCommit(),
            ),
          ),
        ),
        InkWell(
          onTap: onType,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.centerRight,
            child: Text(text, style: _value),
          ),
        ),
      ],
    );
  }
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.unit,
    required this.initial,
  });

  final String title;
  final String unit;
  final double initial;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _text = TextEditingController(
    text: EqFormat._trim(widget.initial.toStringAsFixed(2)),
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(EqFormat.parse(_text.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(
          suffixText: widget.unit.isEmpty ? null : widget.unit,
        ),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _done, child: const Text('Set')),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_text.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Save as preset'),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: EqProfile.maxNameLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Preset name'),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _done, child: const Text('Save')),
      ],
    );
  }
}
