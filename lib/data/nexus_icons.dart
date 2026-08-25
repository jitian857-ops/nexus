import 'package:flutter/material.dart';

const kNexusIcons = <IconData>[
  Icons.restaurant_rounded,
  Icons.train_rounded,
  Icons.menu_book_rounded,
  Icons.people_alt_rounded,
  Icons.spa_rounded,
  Icons.shopping_bag_rounded,
  Icons.flight_rounded,
  Icons.savings_rounded,
  Icons.sports_esports_rounded,
  Icons.checkroom_rounded,
  Icons.school_rounded,
  Icons.home_rounded,
  Icons.phone_iphone_rounded,
  Icons.category_rounded,
  Icons.inbox_rounded,
  Icons.functions,
  Icons.code_rounded,
  Icons.calculate_outlined,
  Icons.science_rounded,
  Icons.history_edu_rounded,
  Icons.biotech_rounded,
  Icons.language_rounded,
  Icons.directions_car_rounded,
  Icons.trending_up_rounded,
  Icons.laptop_rounded,
  Icons.celebration_rounded,
  Icons.subscriptions_rounded,
  Icons.wb_sunny_rounded,
  Icons.directions_run_rounded,
  Icons.nightlight_round,
  Icons.bedtime_rounded,
  Icons.water_drop_rounded,
  Icons.self_improvement_rounded,
  Icons.fitness_center_rounded,
  Icons.edit_note_rounded,
];

IconData nexusIconFromCode(int codePoint) {
  for (final icon in kNexusIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.category_rounded;
}
