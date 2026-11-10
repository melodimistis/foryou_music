enum EqFilterType {
  peak('Peak'),
  lowShelf('Low shelf'),
  highShelf('High shelf');

  const EqFilterType(this.label);

  final String label;

  static EqFilterType named(String? name) => EqFilterType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => EqFilterType.peak,
  );
}

class EqFilter {
  const EqFilter({
    required this.frequency,
    this.type = EqFilterType.peak,
    this.gain = 0,
    this.q = defaultQ,
    this.enabled = true,
  });

  static const minFrequency = 20.0;
  static const maxFrequency = 20000.0;
  static const maxGain = 15.0;
  static const minQ = 0.1;
  static const maxQ = 10.0;
  static const defaultQ = 1.0;
  static const shelfQ = 0.71;

  final EqFilterType type;
  final double frequency;
  final double gain;
  final double q;
  final bool enabled;

  static double _number(Object? value, double fallback) {
    final n = value is num ? value.toDouble() : fallback;
    return n.isFinite ? n : fallback;
  }

  factory EqFilter.clamped({
    required double frequency,
    EqFilterType type = EqFilterType.peak,
    double gain = 0,
    double q = defaultQ,
    bool enabled = true,
  }) => EqFilter(
    type: type,
    frequency: _number(frequency, 1000).clamp(minFrequency, maxFrequency),
    gain: _number(gain, 0).clamp(-maxGain, maxGain),
    q: _number(q, defaultQ).clamp(minQ, maxQ),
    enabled: enabled,
  );

  EqFilter copyWith({
    EqFilterType? type,
    double? frequency,
    double? gain,
    double? q,
    bool? enabled,
  }) => EqFilter.clamped(
    type: type ?? this.type,
    frequency: frequency ?? this.frequency,
    gain: gain ?? this.gain,
    q: q ?? this.q,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'frequency': frequency,
    'gain': gain,
    'q': q,
    'enabled': enabled,
  };

  factory EqFilter.fromMap(Map<dynamic, dynamic> m) => EqFilter.clamped(
    type: EqFilterType.named(m['type'] as String?),
    frequency: _number(m['frequency'], 1000),
    gain: _number(m['gain'], 0),
    q: _number(m['q'], defaultQ),
    enabled: m['enabled'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      other is EqFilter &&
      other.type == type &&
      other.frequency == frequency &&
      other.gain == gain &&
      other.q == q &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(type, frequency, gain, q, enabled);
}

class EqProfile {
  const EqProfile({required this.name, this.filters = const []});

  static const maxFilters = 10;
  static const maxNameLength = 40;

  static const flat = EqProfile(name: 'Flat');

  static const builtIn = [
    flat,
    EqProfile(
      name: 'Bass',
      filters: [
        EqFilter(
          type: EqFilterType.lowShelf,
          frequency: 105,
          gain: 5,
          q: EqFilter.shelfQ,
        ),
      ],
    ),
    EqProfile(
      name: 'Vocal',
      filters: [
        EqFilter(
          type: EqFilterType.lowShelf,
          frequency: 120,
          gain: -2,
          q: EqFilter.shelfQ,
        ),
        EqFilter(frequency: 3000, gain: 3.5, q: 0.9),
      ],
    ),
    EqProfile(
      name: 'Treble',
      filters: [
        EqFilter(
          type: EqFilterType.highShelf,
          frequency: 8000,
          gain: 5,
          q: EqFilter.shelfQ,
        ),
      ],
    ),
    EqProfile(
      name: 'Late night',
      filters: [
        EqFilter(
          type: EqFilterType.lowShelf,
          frequency: 100,
          gain: -4,
          q: EqFilter.shelfQ,
        ),
        EqFilter(frequency: 2500, gain: 2, q: 1),
        EqFilter(
          type: EqFilterType.highShelf,
          frequency: 8000,
          gain: -3,
          q: EqFilter.shelfQ,
        ),
      ],
    ),
  ];

  final String name;
  final List<EqFilter> filters;

  bool get isFull => filters.length >= maxFilters;

  EqProfile copyWith({String? name, List<EqFilter>? filters}) => EqProfile(
    name: name ?? this.name,
    filters: List.unmodifiable(
      (filters ?? this.filters).take(maxFilters).toList(),
    ),
  );

  bool sameFilters(EqProfile other) {
    if (other.filters.length != filters.length) return false;
    for (var i = 0; i < filters.length; i++) {
      if (filters[i] != other.filters[i]) return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'filters': [for (final f in filters) f.toMap()],
  };

  factory EqProfile.fromMap(Map<dynamic, dynamic> m) {
    final raw = m['filters'];
    final name = (m['name'] as String? ?? '').trim();
    return EqProfile(
      name: name.isEmpty ? 'Custom' : name,
      filters: List.unmodifiable([
        if (raw is List)
          for (final f in raw.take(maxFilters))
            if (f is Map) EqFilter.fromMap(f),
      ]),
    );
  }
}
