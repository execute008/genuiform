import 'package:flutter/material.dart';

/// A static registry that maps string icon names to Flutter [IconData].
///
/// The registry is populated with every Material icon found in the gymgeist
/// codebase (160 names, extracted via grep). Consumers can extend the registry
/// at runtime using [register].
///
/// **Case-sensitivity**: The registry is case-sensitive. The key `'add'` and
/// the key `'Add'` are distinct entries. All built-in keys follow the
/// `snake_case` convention that matches `Icons.<name>` in Flutter.
abstract class IconRegistry {
  // ---------------------------------------------------------------------------
  // Default icon set (gymgeist Material icons, 160 entries)
  // ---------------------------------------------------------------------------

  static const Map<String, IconData> _kDefaults = {
    'access_time': Icons.access_time,
    'accessibility_new': Icons.accessibility_new,
    'add': Icons.add,
    'add_circle_outline': Icons.add_circle_outline,
    'add_comment_outlined': Icons.add_comment_outlined,
    'add_rounded': Icons.add_rounded,
    'air': Icons.air,
    'alarm': Icons.alarm,
    'all_inclusive': Icons.all_inclusive,
    'analytics': Icons.analytics,
    'apple': Icons.apple,
    'arrow_back': Icons.arrow_back,
    'arrow_forward_ios': Icons.arrow_forward_ios,
    'auto_awesome': Icons.auto_awesome,
    'bar_chart': Icons.bar_chart,
    'bedtime_outlined': Icons.bedtime_outlined,
    'bolt': Icons.bolt,
    'bolt_outlined': Icons.bolt_outlined,
    'bug_report': Icons.bug_report,
    'calendar_today': Icons.calendar_today,
    'camera_alt': Icons.camera_alt,
    'camera_alt_outlined': Icons.camera_alt_outlined,
    'chat': Icons.chat,
    'chat_bubble_outline': Icons.chat_bubble_outline,
    'chat_bubble_outline_rounded': Icons.chat_bubble_outline_rounded,
    'chat_bubble_rounded': Icons.chat_bubble_rounded,
    'check': Icons.check,
    'check_circle': Icons.check_circle,
    'check_circle_outline': Icons.check_circle_outline,
    'check_circle_rounded': Icons.check_circle_rounded,
    'chevron_left_rounded': Icons.chevron_left_rounded,
    'chevron_right': Icons.chevron_right,
    'chevron_right_rounded': Icons.chevron_right_rounded,
    'circle': Icons.circle,
    'clear': Icons.clear,
    'close': Icons.close,
    'close_rounded': Icons.close_rounded,
    'cloud_done': Icons.cloud_done,
    'construction': Icons.construction,
    'copy_outlined': Icons.copy_outlined,
    'delete': Icons.delete,
    'delete_outline': Icons.delete_outline,
    'delete_outline_rounded': Icons.delete_outline_rounded,
    'description': Icons.description,
    'directions_run': Icons.directions_run,
    'directions_walk': Icons.directions_walk,
    'diversity_1': Icons.diversity_1,
    'done': Icons.done,
    'eco': Icons.eco,
    'edit': Icons.edit,
    'edit_outlined': Icons.edit_outlined,
    'egg': Icons.egg,
    'emoji_events': Icons.emoji_events,
    'emoji_events_outlined': Icons.emoji_events_outlined,
    'error': Icons.error,
    'error_outline': Icons.error_outline,
    'favorite': Icons.favorite,
    'favorite_border': Icons.favorite_border,
    'feed_outlined': Icons.feed_outlined,
    'female': Icons.female,
    'fitness_center': Icons.fitness_center,
    'fitness_center_rounded': Icons.fitness_center_rounded,
    'flag': Icons.flag,
    'g_mobiledata': Icons.g_mobiledata,
    'grass': Icons.grass,
    'height': Icons.height,
    'help_outline': Icons.help_outline,
    'history_rounded': Icons.history_rounded,
    'image_outlined': Icons.image_outlined,
    'info': Icons.info,
    'line_weight': Icons.line_weight,
    'link': Icons.link,
    'list': Icons.list,
    'local_cafe': Icons.local_cafe,
    'local_dining': Icons.local_dining,
    'local_drink': Icons.local_drink,
    'local_fire_department': Icons.local_fire_department,
    'local_fire_department_outlined': Icons.local_fire_department_outlined,
    'local_fire_department_rounded': Icons.local_fire_department_rounded,
    'local_florist': Icons.local_florist,
    'local_pizza': Icons.local_pizza,
    'lock_open_rounded': Icons.lock_open_rounded,
    'lock_outline': Icons.lock_outline,
    'logout': Icons.logout,
    'male': Icons.male,
    'manage_accounts': Icons.manage_accounts,
    'mic_outlined': Icons.mic_outlined,
    'monitor_heart_outlined': Icons.monitor_heart_outlined,
    'more_vert': Icons.more_vert,
    'music_note': Icons.music_note,
    'nights_stay': Icons.nights_stay,
    'no_meals': Icons.no_meals,
    'notes': Icons.notes,
    'notifications': Icons.notifications,
    'notifications_active': Icons.notifications_active,
    'notifications_none': Icons.notifications_none,
    'open_in_new': Icons.open_in_new,
    'paste': Icons.paste,
    'people': Icons.people,
    'people_outline': Icons.people_outline,
    'person': Icons.person,
    'person_add': Icons.person_add,
    'play_arrow': Icons.play_arrow,
    'play_arrow_rounded': Icons.play_arrow_rounded,
    'play_circle_filled': Icons.play_circle_filled,
    'play_circle_outline': Icons.play_circle_outline,
    'psychology': Icons.psychology,
    'question_mark': Icons.question_mark,
    'radio_button_checked': Icons.radio_button_checked,
    'radio_button_unchecked': Icons.radio_button_unchecked,
    'refresh': Icons.refresh,
    'refresh_rounded': Icons.refresh_rounded,
    'remove': Icons.remove,
    'restaurant': Icons.restaurant,
    'restaurant_menu': Icons.restaurant_menu,
    'restaurant_outlined': Icons.restaurant_outlined,
    'restore': Icons.restore,
    'save': Icons.save,
    'schedule': Icons.schedule,
    'search': Icons.search,
    'self_improvement_sharp': Icons.self_improvement_sharp,
    'send': Icons.send,
    'send_rounded': Icons.send_rounded,
    'sentiment_dissatisfied': Icons.sentiment_dissatisfied,
    'set_meal': Icons.set_meal,
    'settings': Icons.settings,
    'share': Icons.share,
    'shopping_cart': Icons.shopping_cart,
    'skip_next': Icons.skip_next,
    'skip_next_rounded': Icons.skip_next_rounded,
    'sports': Icons.sports,
    'sports_kabaddi': Icons.sports_kabaddi,
    'sports_martial_arts': Icons.sports_martial_arts,
    'stairs': Icons.stairs,
    'star': Icons.star,
    'star_border': Icons.star_border,
    'star_half': Icons.star_half,
    'star_rounded': Icons.star_rounded,
    'stop_circle': Icons.stop_circle,
    'straighten': Icons.straighten,
    'summarize_outlined': Icons.summarize_outlined,
    'swap_horiz_rounded': Icons.swap_horiz_rounded,
    'timer': Icons.timer,
    'timer_outlined': Icons.timer_outlined,
    'trending_down': Icons.trending_down,
    'trending_up': Icons.trending_up,
    'trending_up_rounded': Icons.trending_up_rounded,
    'tune_rounded': Icons.tune_rounded,
    'verified': Icons.verified,
    'video_library': Icons.video_library,
    'videocam': Icons.videocam,
    'visibility_outlined': Icons.visibility_outlined,
    'volume_off_rounded': Icons.volume_off_rounded,
    'volume_up_rounded': Icons.volume_up_rounded,
    'volunteer_activism': Icons.volunteer_activism,
    'warning_amber_rounded': Icons.warning_amber_rounded,
    'water_drop': Icons.water_drop,
    'water_drop_outlined': Icons.water_drop_outlined,
    'waves': Icons.waves,
    'web': Icons.web,
  };

  // ---------------------------------------------------------------------------
  // Mutable registry (initialised from defaults; extended by [register])
  // ---------------------------------------------------------------------------

  static final Map<String, IconData> _registry = {..._kDefaults};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the [IconData] for [name], or `null` if the name is not
  /// registered or [name] is `null`.
  ///
  /// Never throws. The registry is case-sensitive: `'add'` and `'Add'` are
  /// distinct keys.
  static IconData? resolve(String? name) {
    if (name == null) return null;
    return _registry[name];
  }

  /// Returns the [IconData] for [name], or [fallback] if the name is not
  /// registered or [name] is `null`.
  ///
  /// The default [fallback] is [Icons.help_outline], which renders as a
  /// placeholder question-mark circle that is visually neutral to end users.
  static IconData resolveOrFallback(
    String? name, {
    IconData fallback = Icons.help_outline,
  }) {
    return resolve(name) ?? fallback;
  }

  /// Returns an unordered list of all currently registered icon names.
  ///
  /// The list can be injected into LLM prompts so the model knows which names
  /// are available.
  static List<String> get registeredIconNames => _registry.keys.toList();

  /// Registers a custom [icon] under [name].
  ///
  /// Throws [StateError] if [name] is already registered and
  /// [replaceExisting] is `false` (the default).
  ///
  /// Use [replaceExisting]: `true` to overwrite an existing entry.
  ///
  /// The registry is case-sensitive; registering `'MyIcon'` and `'myicon'`
  /// creates two separate entries.
  static void register(
    String name,
    IconData icon, {
    bool replaceExisting = false,
  }) {
    if (_registry.containsKey(name) && !replaceExisting) {
      throw StateError(
        'IconRegistry already contains an entry for "$name". '
        'Use replaceExisting: true to overwrite it.',
      );
    }
    _registry[name] = icon;
  }
}
