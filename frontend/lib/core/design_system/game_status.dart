import 'package:material_ui/material_ui.dart';

/// Valores idênticos aos da API; só os rótulos mudam com a interface.
enum GameStatus {
  backlog('backlog', 'Na fila', Icons.bookmark_border),
  playing('playing', 'Jogando', Icons.play_circle_outline),
  completed('completed', 'Concluído', Icons.check_circle_outline),
  dropped('dropped', 'Abandonado', Icons.cancel_outlined);

  const GameStatus(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;

  static GameStatus fromApi(String value) => GameStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => GameStatus.backlog,
  );
}

/// Cores de domínio como extensão do tema; o texto/ícone sempre acompanha a cor.
@immutable
class DomainColors extends ThemeExtension<DomainColors> {
  const DomainColors({
    required this.backlog,
    required this.playing,
    required this.completed,
    required this.dropped,
    required this.rating,
    required this.like,
  });

  final Color backlog;
  final Color playing;
  final Color completed;
  final Color dropped;
  final Color rating;
  final Color like;

  static const light = DomainColors(
    backlog: Color(0xFF5F6475),
    playing: Color(0xFF0B6BA8),
    completed: Color(0xFF1B7F4F),
    dropped: Color(0xFFB3412F),
    rating: Color(0xFF9A6200),
    like: Color(0xFFC2264A),
  );

  static const dark = DomainColors(
    backlog: Color(0xFFA6ABBB),
    playing: Color(0xFF63C7FF),
    completed: Color(0xFF58DDA0),
    dropped: Color(0xFFFF8E80),
    rating: Color(0xFFF5B544),
    like: Color(0xFFFF7A93),
  );

  Color forStatus(GameStatus status) => switch (status) {
    GameStatus.backlog => backlog,
    GameStatus.playing => playing,
    GameStatus.completed => completed,
    GameStatus.dropped => dropped,
  };

  @override
  DomainColors copyWith({
    Color? backlog,
    Color? playing,
    Color? completed,
    Color? dropped,
    Color? rating,
    Color? like,
  }) => DomainColors(
    backlog: backlog ?? this.backlog,
    playing: playing ?? this.playing,
    completed: completed ?? this.completed,
    dropped: dropped ?? this.dropped,
    rating: rating ?? this.rating,
    like: like ?? this.like,
  );

  @override
  DomainColors lerp(DomainColors? other, double t) {
    if (other == null) return this;
    return DomainColors(
      backlog: Color.lerp(backlog, other.backlog, t)!,
      playing: Color.lerp(playing, other.playing, t)!,
      completed: Color.lerp(completed, other.completed, t)!,
      dropped: Color.lerp(dropped, other.dropped, t)!,
      rating: Color.lerp(rating, other.rating, t)!,
      like: Color.lerp(like, other.like, t)!,
    );
  }
}

extension DomainColorsContext on BuildContext {
  DomainColors get domainColors => Theme.of(this).extension<DomainColors>()!;
}
