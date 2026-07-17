class ReadingState {
  final List<int> order;
  final int pos;

  const ReadingState({
    required this.order,
    required this.pos,
  });

  int get cycleLength => order.length;

  bool get isEmpty => order.isEmpty;

  int? get currentIndex {
    if (isEmpty || pos < 0 || pos >= order.length) return null;
    return order[pos];
  }

  Map<String, dynamic> toJson() => {
        'order': order,
        'pos': pos,
      };

  factory ReadingState.fromJson(Map<String, dynamic> json) {
    return ReadingState(
      order: List<int>.from(json['order'] as List),
      pos: json['pos'] as int,
    );
  }

  ReadingState copyWith({
    List<int>? order,
    int? pos,
  }) {
    return ReadingState(
      order: order ?? this.order,
      pos: pos ?? this.pos,
    );
  }
}