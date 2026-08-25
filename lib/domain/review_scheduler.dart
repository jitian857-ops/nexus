import '../data/models.dart';

class ReviewScheduler {
  ReviewScheduler._();

  static const intervals = [1, 5];

  static List<ReviewCard> cardsFor({
    required String problemId,
    required DateTime learnedAt,
    required String Function() nextId,
  }) {
    return [
      for (final day in intervals)
        ReviewCard(
          id: nextId(),
          problemId: problemId,
          dueAt: DateTime(learnedAt.year, learnedAt.month, learnedAt.day + day),
          intervalStep: day,
        ),
    ];
  }
}
