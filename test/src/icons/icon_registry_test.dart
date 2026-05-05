import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

/// All icon names extracted from gymgeist/lib/ via:
///   grep -rh "Icons\." /Users/exe008/gymgeist/lib/ --include="*.dart" \
///     | grep -oE "Icons\.[a-zA-Z_0-9]+" | sed 's/Icons\.//' | sort -u
///
/// Count: 160 unique names (all confirmed present in Flutter stable 3.41.8).
const List<String> _gymgeistIconNames = [
  'access_time',
  'accessibility_new',
  'add',
  'add_circle_outline',
  'add_comment_outlined',
  'add_rounded',
  'air',
  'alarm',
  'all_inclusive',
  'analytics',
  'apple',
  'arrow_back',
  'arrow_forward_ios',
  'auto_awesome',
  'bar_chart',
  'bedtime_outlined',
  'bolt',
  'bolt_outlined',
  'bug_report',
  'calendar_today',
  'camera_alt',
  'camera_alt_outlined',
  'chat',
  'chat_bubble_outline',
  'chat_bubble_outline_rounded',
  'chat_bubble_rounded',
  'check',
  'check_circle',
  'check_circle_outline',
  'check_circle_rounded',
  'chevron_left_rounded',
  'chevron_right',
  'chevron_right_rounded',
  'circle',
  'clear',
  'close',
  'close_rounded',
  'cloud_done',
  'construction',
  'copy_outlined',
  'delete',
  'delete_outline',
  'delete_outline_rounded',
  'description',
  'directions_run',
  'directions_walk',
  'diversity_1',
  'done',
  'eco',
  'edit',
  'edit_outlined',
  'egg',
  'emoji_events',
  'emoji_events_outlined',
  'error',
  'error_outline',
  'favorite',
  'favorite_border',
  'feed_outlined',
  'female',
  'fitness_center',
  'fitness_center_rounded',
  'flag',
  'g_mobiledata',
  'grass',
  'height',
  'help_outline',
  'history_rounded',
  'image_outlined',
  'info',
  'line_weight',
  'link',
  'list',
  'local_cafe',
  'local_dining',
  'local_drink',
  'local_fire_department',
  'local_fire_department_outlined',
  'local_fire_department_rounded',
  'local_florist',
  'local_pizza',
  'lock_open_rounded',
  'lock_outline',
  'logout',
  'male',
  'manage_accounts',
  'mic_outlined',
  'monitor_heart_outlined',
  'more_vert',
  'music_note',
  'nights_stay',
  'no_meals',
  'notes',
  'notifications',
  'notifications_active',
  'notifications_none',
  'open_in_new',
  'paste',
  'people',
  'people_outline',
  'person',
  'person_add',
  'play_arrow',
  'play_arrow_rounded',
  'play_circle_filled',
  'play_circle_outline',
  'psychology',
  'question_mark',
  'radio_button_checked',
  'radio_button_unchecked',
  'refresh',
  'refresh_rounded',
  'remove',
  'restaurant',
  'restaurant_menu',
  'restaurant_outlined',
  'restore',
  'save',
  'schedule',
  'search',
  'self_improvement_sharp',
  'send',
  'send_rounded',
  'sentiment_dissatisfied',
  'set_meal',
  'settings',
  'share',
  'shopping_cart',
  'skip_next',
  'skip_next_rounded',
  'sports',
  'sports_kabaddi',
  'sports_martial_arts',
  'stairs',
  'star',
  'star_border',
  'star_half',
  'star_rounded',
  'stop_circle',
  'straighten',
  'summarize_outlined',
  'swap_horiz_rounded',
  'timer',
  'timer_outlined',
  'trending_down',
  'trending_up',
  'trending_up_rounded',
  'tune_rounded',
  'verified',
  'video_library',
  'videocam',
  'visibility_outlined',
  'volume_off_rounded',
  'volume_up_rounded',
  'volunteer_activism',
  'warning_amber_rounded',
  'water_drop',
  'water_drop_outlined',
  'waves',
  'web',
];

void main() {
  group('IconRegistry — resolve', () {
    test('returns null for null input', () {
      expect(IconRegistry.resolve(null), isNull);
    });

    test('returns null for unknown name', () {
      expect(
        IconRegistry.resolve('this_does_not_exist_anywhere_42'),
        isNull,
      );
    });

    test('resolves every gymgeist icon name to a non-null IconData', () {
      for (final name in _gymgeistIconNames) {
        final icon = IconRegistry.resolve(name);
        expect(
          icon,
          isNotNull,
          reason: 'IconRegistry.resolve("$name") returned null',
        );
      }
    });

    test('is case-sensitive — uppercase variant returns null', () {
      // Registry is explicitly case-sensitive; 'Add' != 'add'
      expect(IconRegistry.resolve('Add'), isNull);
      expect(IconRegistry.resolve('FITNESS_CENTER'), isNull);
    });
  });

  group('IconRegistry — resolveOrFallback', () {
    test('returns the icon when name is known', () {
      expect(IconRegistry.resolveOrFallback('add'), equals(Icons.add));
    });

    test('returns custom fallback for unknown name', () {
      const customFallback = Icons.error;
      expect(
        IconRegistry.resolveOrFallback(
          'totally_unknown_icon',
          fallback: customFallback,
        ),
        equals(customFallback),
      );
    });

    test('returns default fallback (Icons.help_outline) for unknown name', () {
      expect(
        IconRegistry.resolveOrFallback('unknown_icon'),
        equals(Icons.help_outline),
      );
    });

    test('returns default fallback for null name', () {
      expect(
        IconRegistry.resolveOrFallback(null),
        equals(Icons.help_outline),
      );
    });
  });

  group('IconRegistry — registeredIconNames', () {
    test('contains all gymgeist icon names', () {
      final registered = IconRegistry.registeredIconNames;
      for (final name in _gymgeistIconNames) {
        expect(
          registered,
          contains(name),
          reason: '"$name" is missing from registeredIconNames',
        );
      }
    });

    test('returns a non-empty list', () {
      expect(IconRegistry.registeredIconNames, isNotEmpty);
    });
  });

  group('IconRegistry — register', () {
    const testIconName = 'test_custom_icon_unique_xyz';
    const testIconName2 = 'test_custom_icon_unique_xyz_2';

    tearDown(() {
      // Re-register with replacement to clean up between tests if needed.
      // The registry is global state, so names added here persist for the
      // duration of the test run. We use unique names to avoid cross-test
      // pollution.
    });

    test('successfully registers a new icon', () {
      IconRegistry.register(testIconName, Icons.star);
      expect(IconRegistry.resolve(testIconName), equals(Icons.star));
    });

    test('throws StateError on duplicate registration without replaceExisting',
        () {
      IconRegistry.register(testIconName2, Icons.star);
      expect(
        () => IconRegistry.register(testIconName2, Icons.circle),
        throwsA(isA<StateError>()),
      );
    });

    test('succeeds on duplicate registration with replaceExisting: true', () {
      IconRegistry.register(
        testIconName2,
        Icons.circle,
        replaceExisting: true,
      );
      expect(IconRegistry.resolve(testIconName2), equals(Icons.circle));
    });

    test('registered name appears in registeredIconNames', () {
      const newName = 'test_custom_icon_unique_xyz_3';
      IconRegistry.register(newName, Icons.ac_unit);
      expect(IconRegistry.registeredIconNames, contains(newName));
    });
  });
}
