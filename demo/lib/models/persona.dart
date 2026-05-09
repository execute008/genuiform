enum Engagement { strong, medium, weak }

class Persona {
  final String id;
  final String name;
  final String? tag;
  final String description;
  final Engagement engagement;
  final int seed;
  final double hue;

  const Persona({
    required this.id,
    required this.name,
    required this.description,
    required this.engagement,
    required this.seed,
    required this.hue,
    this.tag,
  });
}

class PersonaLibrary {
  static const Map<String, List<Persona>> byScenario = {
    'medical': [
      Persona(
        id: 'p1',
        name: 'Dr. Mira Chen',
        tag: 'Engaged',
        description: 'Primary care physician, fills forms with full context',
        engagement: Engagement.strong,
        seed: 1,
        hue: 270,
      ),
      Persona(
        id: 'p2',
        name: 'Sam, Tired Founder',
        tag: 'Skim',
        description: 'Late-night intake, wants minimum viable answers',
        engagement: Engagement.weak,
        seed: 2,
        hue: 20,
      ),
      Persona(
        id: 'p3',
        name: 'Robin, Anxious Patient',
        tag: 'Cautious',
        description: 'First-time visitor, hesitates on consent',
        engagement: Engagement.medium,
        seed: 3,
        hue: 140,
      ),
      Persona(
        id: 'p4',
        name: 'Jamie, Returning',
        tag: 'Power',
        description: 'Has filled this form before, breezes through',
        engagement: Engagement.strong,
        seed: 4,
        hue: 200,
      ),
    ],
    'signup': [
      Persona(
        id: 's1',
        name: 'Engaged CTO',
        tag: 'Detailed',
        description: 'Wants every field, reads every word',
        engagement: Engagement.strong,
        seed: 5,
        hue: 240,
      ),
      Persona(
        id: 's2',
        name: 'Casual Browser',
        tag: 'Skim',
        description: 'Curious but uncommitted, will bounce on friction',
        engagement: Engagement.weak,
        seed: 6,
        hue: 30,
      ),
      Persona(
        id: 's3',
        name: 'PM in a hurry',
        tag: 'Mid',
        description: 'Knows what they want, wants to ship by EOD',
        engagement: Engagement.medium,
        seed: 7,
        hue: 320,
      ),
    ],
    'feedback': [
      Persona(
        id: 'f1',
        name: 'Power User',
        tag: 'Loud',
        description: 'Has 5 paragraphs of opinions ready to type',
        engagement: Engagement.strong,
        seed: 8,
        hue: 100,
      ),
      Persona(
        id: 'f2',
        name: 'Quiet Lurker',
        tag: 'Skim',
        description: 'Will only answer multiple choice, never free text',
        engagement: Engagement.weak,
        seed: 9,
        hue: 50,
      ),
      Persona(
        id: 'f3',
        name: 'New User',
        tag: 'Curious',
        description: 'Tried the product yesterday, has gentle confusion',
        engagement: Engagement.medium,
        seed: 10,
        hue: 180,
      ),
    ],
  };
}
