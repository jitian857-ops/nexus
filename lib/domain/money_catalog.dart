import 'package:flutter/material.dart';

import '../data/nexus_icons.dart';

class BoxTemplate {
  const BoxTemplate({
    required this.name,
    required this.icon,
    required this.color,
    required this.tags,
  });

  final String name;
  final IconData icon;
  final Color color;
  final List<String> tags;
}

const budgetBoxTemplates = <BoxTemplate>[
  BoxTemplate(
    name: '食費',
    icon: Icons.restaurant_rounded,
    color: Color(0xFF3DA9FC),
    tags: ['外食', 'コンビニ', 'カフェ', 'スーパー', '昼食', '夕食', '飲み物', 'お菓子', 'その他'],
  ),
  BoxTemplate(
    name: '友達',
    icon: Icons.people_alt_rounded,
    color: Color(0xFFFF8AD2),
    tags: ['ご飯', 'プレゼント', 'イベント', 'その他'],
  ),
  BoxTemplate(
    name: '趣味',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF9B6BFF),
    tags: ['本', 'ゲーム', '映画', 'その他'],
  ),
  BoxTemplate(
    name: '美容',
    icon: Icons.spa_rounded,
    color: Color(0xFFFFC857),
    tags: ['化粧品', 'サロン', 'その他'],
  ),
  BoxTemplate(
    name: '交通費',
    icon: Icons.train_rounded,
    color: Color(0xFF9B6BFF),
    tags: ['電車', 'バス', 'タクシー', 'その他'],
  ),
  BoxTemplate(
    name: '日用品',
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFF65EDFF),
    tags: ['ドラッグストア', 'スーパー', 'その他'],
  ),
  BoxTemplate(
    name: 'サブスク',
    icon: Icons.subscriptions_rounded,
    color: Color(0xFF2EE6C7),
    tags: ['動画', '音楽', 'ツール', 'その他'],
  ),
  BoxTemplate(
    name: '服',
    icon: Icons.checkroom_rounded,
    color: Color(0xFF9B6BFF),
    tags: ['服', '靴', 'その他'],
  ),
  BoxTemplate(
    name: '娯楽',
    icon: Icons.celebration_rounded,
    color: Color(0xFFFF5B7A),
    tags: ['外出', 'イベント', 'その他'],
  ),
  BoxTemplate(
    name: '学費',
    icon: Icons.school_rounded,
    color: Color(0xFF00D4FF),
    tags: ['授業料', '教材', 'その他'],
  ),
  BoxTemplate(
    name: 'その他',
    icon: Icons.category_rounded,
    color: Color(0xFF8B9BB4),
    tags: ['その他'],
  ),
];

const savingsBoxTemplates = <BoxTemplate>[
  BoxTemplate(name: '車の免許', icon: Icons.directions_car_rounded, color: Color(0xFF00D4FF), tags: ['教習', '検定', 'その他']),
  BoxTemplate(name: '韓国旅行', icon: Icons.flight_rounded, color: Color(0xFFFF8AD2), tags: ['ホテル', '飛行機', '食事', 'お土産', '現地交通']),
  BoxTemplate(name: '投資', icon: Icons.trending_up_rounded, color: Color(0xFF3DFF8A), tags: ['入金', '出金']),
  BoxTemplate(name: '学費', icon: Icons.school_rounded, color: Color(0xFF9B6BFF), tags: ['積立', 'その他']),
  BoxTemplate(name: 'PC', icon: Icons.laptop_rounded, color: Color(0xFF65EDFF), tags: ['本体', '周辺機器']),
  BoxTemplate(name: '将来資金', icon: Icons.savings_rounded, color: Color(0xFFFFC857), tags: ['積立', 'その他']),
];

const boxIconChoices = kNexusIcons;

const boxColorChoices = <Color>[
  Color(0xFF3DA9FC),
  Color(0xFF9B6BFF),
  Color(0xFF2EE6C7),
  Color(0xFF3DFF8A),
  Color(0xFFFF5B7A),
  Color(0xFFFFC857),
  Color(0xFFFF8AD2),
  Color(0xFF65EDFF),
];

List<String> suggestedTagsFor(String name) {
  for (final t in [...budgetBoxTemplates, ...savingsBoxTemplates]) {
    if (name.contains(t.name) || t.name.contains(name)) return List<String>.from(t.tags);
  }
  return ['その他'];
}
