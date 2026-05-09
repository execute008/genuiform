/// Data model for a single workbench scenario preset.
library;

/// A named scenario preset that can be loaded into the workbench editor.
class Scenario {
  final String id;
  final String name;
  final String description;
  final String dsl;

  const Scenario({
    required this.id,
    required this.name,
    required this.description,
    required this.dsl,
  });
}
