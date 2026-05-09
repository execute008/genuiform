import 'package:flutter/material.dart';

import '../models/field_spec.dart';
import '../models/persona.dart';
import '../models/scenario.dart';
import '../state/workbench_controller.dart';
import '../theme/app_spacing.dart';

class FormPreviewPanel extends StatefulWidget {
  final WorkbenchController controller;
  const FormPreviewPanel({super.key, required this.controller});

  @override
  State<FormPreviewPanel> createState() => _FormPreviewPanelState();
}

class _FormPreviewPanelState extends State<FormPreviewPanel> {
  int _step = 0;
  bool _complete = false;
  final Map<String, dynamic> _values = {};

  String? _lastScenario;
  String? _lastPersona;

  List<FieldSpec> _adaptedFields(Scenario s, Persona? p) {
    if (p == null) return s.fields;
    if (p.engagement == Engagement.weak) {
      return s.fields.where((f) => f.required).take(3).toList();
    }
    if (p.engagement == Engagement.medium) {
      return s.fields.take(s.fields.length.clamp(0, 4)).toList();
    }
    return s.fields;
  }

  void _resetIfChanged(String scenarioKey, String? personaId) {
    if (_lastScenario != scenarioKey || _lastPersona != personaId) {
      _lastScenario = scenarioKey;
      _lastPersona = personaId;
      _step = 0;
      _complete = false;
      _values.clear();
    }
  }

  void _restart() {
    setState(() {
      _step = 0;
      _complete = false;
      _values.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.controller;
    final scenario = c.scenario;
    final persona = c.activePersona;
    _resetIfChanged(scenario.key, persona?.id);
    final fields = _adaptedFields(scenario, persona);
    final total = fields.length;

    return Column(
      children: [
        _PreviewBar(
          controller: c,
          onRestart: _restart,
        ),
        Expanded(
          child: Container(
            color: cs.surface,
            child: CustomPaint(
              painter: _DotGridPainter(color: cs.onSurface.withValues(alpha: 0.04)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s7),
                child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _DeviceCard(
                    scenario: scenario,
                    persona: persona,
                    field: total > 0 && !_complete ? fields[_step] : null,
                    step: _step,
                    total: total,
                    complete: _complete,
                    values: _values,
                    onChange: (k, v) => setState(() => _values[k] = v),
                    onNext: () => setState(() {
                      if (_step + 1 >= total) {
                        _complete = true;
                      } else {
                        _step += 1;
                      }
                    }),
                    onBack: () => setState(() {
                      if (_step > 0) _step -= 1;
                    }),
                    onRestart: _restart,
                  ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _StatusBar(
          step: _complete ? total : _step + 1,
          total: total,
          engagement: persona?.engagement ?? Engagement.medium,
          path: _complete ? scenario.paths.first : 'in_progress',
          debug: c.debug,
          posture: scenario.posture.name,
        ),
      ],
    );
  }
}

/* -------------------- Preview top bar -------------------- */
class _PreviewBar extends StatelessWidget {
  final WorkbenchController controller;
  final VoidCallback onRestart;
  const _PreviewBar({required this.controller, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: controller.scenarioKey,
              dropdownColor: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.rS),
              items: [
                for (final s in ScenarioLibrary.all)
                  DropdownMenuItem(
                    value: s.key,
                    child: Text(s.label),
                  ),
              ],
              onChanged: (v) {
                if (v != null) controller.setScenarioKey(v);
              },
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                'Debug',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.s2),
              Switch(
                value: controller.debug,
                onChanged: controller.setDebug,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.s2),
          IconButton(
            tooltip: 'Reload preview',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: onRestart,
          ),
          const SizedBox(width: AppSpacing.s2),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Run'),
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }
}

/* -------------------- Device card -------------------- */
class _DeviceCard extends StatelessWidget {
  final Scenario scenario;
  final Persona? persona;
  final FieldSpec? field;
  final int step;
  final int total;
  final bool complete;
  final Map<String, dynamic> values;
  final void Function(String, dynamic) onChange;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onRestart;

  const _DeviceCard({
    required this.scenario,
    required this.persona,
    required this.field,
    required this.step,
    required this.total,
    required this.complete,
    required this.values,
    required this.onChange,
    required this.onNext,
    required this.onBack,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = complete ? 1.0 : (step / (total == 0 ? 1 : total));
    final firstName = persona?.name.split(RegExp(r'[ ,]')).first;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.rXl),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 48,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        children: [
          // Greeting header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5,
              AppSpacing.s5,
              AppSpacing.s5,
              AppSpacing.s3,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [cs.tertiary, cs.primary],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (persona?.name ?? 'GU').characters.first,
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName != null ? 'Hi, $firstName' : 'Hi there',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        scenario.formName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Progress
          ClipRRect(
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.primary,
              ),
            ),
          ),
          // Body
          if (!complete)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s5,
                AppSpacing.s6,
                AppSpacing.s5,
                AppSpacing.s5,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                child: field == null
                    ? const SizedBox(height: 200)
                    : KeyedSubtree(
                        key: ValueKey('${scenario.key}-${persona?.id}-${field!.key}'),
                        child: _FieldRender(
                          field: field!,
                          value: values[field!.key],
                          onChange: (v) => onChange(field!.key, v),
                        ),
                      ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s5,
                vertical: AppSpacing.s7,
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primaryContainer,
                    ),
                    child: Icon(Icons.check, size: 42, color: cs.primary),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    scenario.paths.first.replaceAll('_', ' '),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'Your form has been completed.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  OutlinedButton(
                    onPressed: onRestart,
                    child: const Text('Restart'),
                  ),
                ],
              ),
            ),
          // Action bar
          if (!complete)
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s5,
                AppSpacing.s3,
                AppSpacing.s5,
                AppSpacing.s5,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppSpacing.rXl),
                  bottomRight: Radius.circular(AppSpacing.rXl),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (step > 0)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                      onPressed: onBack,
                    ),
                  const SizedBox(width: AppSpacing.s2),
                  FilledButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(step + 1 >= total ? 'Submit' : 'Continue'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------- Field rendering -------------------- */
class _FieldRender extends StatelessWidget {
  final FieldSpec field;
  final dynamic value;
  final void Function(dynamic) onChange;

  const _FieldRender({
    required this.field,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget body;

    switch (field.input) {
      case FieldInputStyle.outlined:
        body = TextField(
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: onChange,
          decoration: const InputDecoration(hintText: 'Type your answer…'),
        );
        break;
      case FieldInputStyle.filled:
        body = TextField(
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: onChange,
          decoration: InputDecoration(
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            hintText: 'Type your answer…',
            border: UnderlineInputBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.rXs),
              ),
              borderSide: BorderSide(color: cs.outline),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: cs.outline),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.rXs),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: cs.primary, width: 2),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.rXs),
              ),
            ),
          ),
        );
        break;
      case FieldInputStyle.tonalCard:
        body = Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(AppSpacing.rL),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You can list multiple, separated by commas.',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSecondaryContainer.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              TextField(
                controller:
                    TextEditingController(text: value?.toString() ?? ''),
                onChanged: onChange,
                style: TextStyle(color: cs.onSecondaryContainer),
                decoration: InputDecoration(
                  hintText: 'ibuprofen, vitamin d…',
                  hintStyle: TextStyle(
                    color: cs.onSecondaryContainer.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        );
        break;
      case FieldInputStyle.slider:
        final range = field.range ?? const NumRange(0, 10);
        final v = (value as num?)?.toDouble() ??
            ((range.min + range.max) / 2).toDouble();
        return _LabeledField(
          field: field,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Slider(
                value: v.clamp(range.min.toDouble(), range.max.toDouble()),
                min: range.min.toDouble(),
                max: range.max.toDouble(),
                divisions:
                    (range.max - range.min).toInt().clamp(1, 100).toInt(),
                onChanged: (v) => onChange(v.round()),
                label: v.round().toString(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${range.min.toInt()}',
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurfaceVariant)),
                    Text('${v.round()}',
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurfaceVariant)),
                    Text('${range.max.toInt()}',
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );
      case FieldInputStyle.choiceChips:
        final opts = field.options ?? const ['Yes', 'Maybe', 'No'];
        final List<String> sel = (value as List<String>?)?.toList() ?? [];
        return _LabeledField(
          field: field,
          child: Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              for (final o in opts)
                FilterChip(
                  label: Text(o),
                  selected: sel.contains(o),
                  onSelected: (v) {
                    final next = [...sel];
                    if (v) {
                      next.add(o);
                    } else {
                      next.remove(o);
                    }
                    onChange(next);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.rS),
                    side: BorderSide(color: cs.outline),
                  ),
                  selectedColor: cs.secondaryContainer,
                  backgroundColor: Colors.transparent,
                  labelStyle: TextStyle(
                    color: sel.contains(o)
                        ? cs.onSecondaryContainer
                        : cs.onSurface,
                    fontSize: 13,
                  ),
                  showCheckmark: true,
                ),
            ],
          ),
        );
      case FieldInputStyle.switchControl:
        return Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s3,
            AppSpacing.s2,
            AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSpacing.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (field.hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        field.hint!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value == true,
                onChanged: onChange,
              ),
            ],
          ),
        );
    }

    return _LabeledField(field: field, child: body);
  }
}

class _LabeledField extends StatelessWidget {
  final FieldSpec field;
  final Widget child;
  const _LabeledField({required this.field, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        if (field.hint != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            field.hint!,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s3),
        child,
      ],
    );
  }
}

/* -------------------- Status bar -------------------- */
class _StatusBar extends StatelessWidget {
  final int step;
  final int total;
  final Engagement engagement;
  final String path;
  final bool debug;
  final String posture;

  const _StatusBar({
    required this.step,
    required this.total,
    required this.engagement,
    required this.path,
    required this.debug,
    required this.posture,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color engColor;
    switch (engagement) {
      case Engagement.strong:
        engColor = const Color(0xFF9FD4A3);
        break;
      case Engagement.medium:
        engColor = const Color(0xFFFFC77A);
        break;
      case Engagement.weak:
        engColor = const Color(0xFFFFB4AB);
        break;
    }

    Widget cell(String label, Widget value) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                value,
              ],
            ),
          ),
        );

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          cell('Step', _Token('step $step/$total')),
          cell(
            'Engagement',
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: engColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(engagement.name, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          cell('Path', _Token(path)),
          if (debug) _Token('tdl/v3 · $posture'),
        ],
      ),
    );
  }
}

class _Token extends StatelessWidget {
  final String text;
  const _Token(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.rXs),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    const spacing = 24.0;
    const radius = 1.0;
    
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
