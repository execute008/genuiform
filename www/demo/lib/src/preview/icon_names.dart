import 'package:flutter/material.dart';

/// Resolves a Material icon name string to its [IconData].
///
/// Names match the Flutter `Icons` field names exactly (e.g. `'calendar_today'`,
/// `'mail_outline'`). Unknown names render as [Icons.flag_outlined], which makes
/// typos visible in the workbench UI without crashing.
///
/// Flutter ships ~2000 Material icons; this map exposes a curated subset
/// (~120 names) covering common UI actions, status, communication, navigation,
/// and content categories. Add new entries on demand.
IconData iconForName(String name) =>
    _kIconLookup[name] ?? Icons.flag_outlined;

/// All icon names supported by [iconForName]. Surfaced in the legend drawer.
List<String> get kSupportedIconNames =>
    _kIconLookup.keys.toList(growable: false)..sort();

const Map<String, IconData> _kIconLookup = {
  // ── Actions / generic ───────────────────────────────────────────────────────
  'add': Icons.add,
  'add_circle': Icons.add_circle,
  'add_circle_outline': Icons.add_circle_outline,
  'check': Icons.check,
  'check_circle': Icons.check_circle,
  'check_circle_outline': Icons.check_circle_outline,
  'close': Icons.close,
  'cancel': Icons.cancel,
  'cancel_outlined': Icons.cancel_outlined,
  'delete': Icons.delete,
  'delete_outline': Icons.delete_outline,
  'edit': Icons.edit,
  'save': Icons.save,
  'save_outlined': Icons.save_outlined,
  'send': Icons.send,
  'share': Icons.share,
  'download': Icons.download,
  'upload': Icons.upload,
  'refresh': Icons.refresh,
  'search': Icons.search,
  'settings': Icons.settings,
  'settings_outlined': Icons.settings_outlined,
  'tune': Icons.tune,
  'open_in_new': Icons.open_in_new,
  'arrow_forward': Icons.arrow_forward,
  'arrow_back': Icons.arrow_back,
  'flag': Icons.flag,
  'flag_outlined': Icons.flag_outlined,

  // ── Status / feedback ───────────────────────────────────────────────────────
  'info': Icons.info,
  'info_outline': Icons.info_outline,
  'warning': Icons.warning,
  'warning_amber': Icons.warning_amber,
  'error': Icons.error,
  'error_outline': Icons.error_outline,
  'help': Icons.help,
  'help_outline': Icons.help_outline,
  'task_alt': Icons.task_alt,
  'verified': Icons.verified,
  'pending': Icons.pending,
  'schedule': Icons.schedule,
  'hourglass_empty': Icons.hourglass_empty,

  // ── Navigation / structure ──────────────────────────────────────────────────
  'home': Icons.home,
  'home_outlined': Icons.home_outlined,
  'menu': Icons.menu,
  'dashboard': Icons.dashboard,
  'dashboard_outlined': Icons.dashboard_outlined,
  'logout': Icons.logout,
  'login': Icons.login,
  'arrow_drop_down': Icons.arrow_drop_down,
  'expand_more': Icons.expand_more,

  // ── Communication ───────────────────────────────────────────────────────────
  'mail': Icons.mail,
  'mail_outline': Icons.mail_outline,
  'forward_to_inbox': Icons.forward_to_inbox,
  'phone': Icons.phone,
  'call': Icons.call,
  'sms': Icons.sms,
  'chat': Icons.chat,
  'chat_bubble_outline': Icons.chat_bubble_outline,
  'message': Icons.message,
  'support_agent': Icons.support_agent,
  'notifications': Icons.notifications,
  'notifications_outlined': Icons.notifications_outlined,

  // ── People / accounts ───────────────────────────────────────────────────────
  'person': Icons.person,
  'person_outline': Icons.person_outline,
  'person_add': Icons.person_add,
  'group': Icons.group,
  'account_circle': Icons.account_circle,
  'badge': Icons.badge,

  // ── Calendar / time ─────────────────────────────────────────────────────────
  'calendar_today': Icons.calendar_today,
  'calendar_month': Icons.calendar_month,
  'event': Icons.event,
  'event_available': Icons.event_available,
  'access_time': Icons.access_time,
  'alarm': Icons.alarm,

  // ── Commerce / payments ─────────────────────────────────────────────────────
  'shopping_cart': Icons.shopping_cart,
  'shopping_bag': Icons.shopping_bag,
  'credit_card': Icons.credit_card,
  'payment': Icons.payment,
  'attach_money': Icons.attach_money,
  'euro': Icons.euro,
  'receipt_long': Icons.receipt_long,

  // ── Content / files ─────────────────────────────────────────────────────────
  'description': Icons.description,
  'article': Icons.article,
  'attach_file': Icons.attach_file,
  'folder': Icons.folder,
  'folder_outlined': Icons.folder_outlined,
  'image': Icons.image,
  'image_outlined': Icons.image_outlined,
  'star': Icons.star,
  'star_outline': Icons.star_outline,
  'favorite': Icons.favorite,
  'favorite_border': Icons.favorite_border,
  'bookmark': Icons.bookmark,
  'bookmark_outline': Icons.bookmark_outline,

  // ── Health / fitness / lifestyle ────────────────────────────────────────────
  'medical_services': Icons.medical_services,
  'medical_services_outlined': Icons.medical_services_outlined,
  'health_and_safety': Icons.health_and_safety,
  'medication': Icons.medication,
  'fitness_center': Icons.fitness_center,
  'directions_run': Icons.directions_run,
  'self_improvement': Icons.self_improvement,
  'restaurant': Icons.restaurant,
  'restaurant_menu': Icons.restaurant_menu,
  'local_dining': Icons.local_dining,
  'monitor_weight_outlined': Icons.monitor_weight_outlined,
  'scale': Icons.scale,
  'spa': Icons.spa,
  'bedtime': Icons.bedtime,

  // ── Misc / domain flavour ───────────────────────────────────────────────────
  'rocket_launch': Icons.rocket_launch,
  'celebration': Icons.celebration,
  'trending_up': Icons.trending_up,
  'lightbulb': Icons.lightbulb,
  'lightbulb_outline': Icons.lightbulb_outline,
  'security': Icons.security,
  'lock': Icons.lock,
  'lock_outline': Icons.lock_outline,
  'visibility': Icons.visibility,
  'visibility_off': Icons.visibility_off,
  'public': Icons.public,
  'language': Icons.language,
  'translate': Icons.translate,
};
