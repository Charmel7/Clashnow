class Player {
  final String id;
  final String name;
  final int teamId;
  final String teamName;
  int score;
  int penalties;
  int teamScore;
  int attempts;
  int success;
  bool isConnected;
  bool isCaptain;

  Player({
    required this.id,
    required this.name,
    required this.teamId,
    required this.teamName,
    this.score = 0,
    this.penalties = 0,
    this.teamScore = 0,
    this.attempts = 0,
    this.success = 0,
    this.isConnected = true,
    this.isCaptain = false,
  });

  double get efficiency => attempts > 0 ? (success / attempts) * 100 : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'teamId': teamId,
      'teamName': teamName,
      'score': score,
      'penalties': penalties,
      'teamScore': teamScore,
      'attempts': attempts,
      'success': success,
      'isConnected': isConnected,
      'isCaptain': isCaptain,
      'efficiency': efficiency,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] as String,
      name: map['name'] as String,
      teamId: map['teamId'] as int,
      teamName: map['teamName'] as String,
      score: map['score'] as int? ?? 0,
      penalties: map['penalties'] as int? ?? 0,
      teamScore: map['teamScore'] as int? ?? 0,
      attempts: map['attempts'] as int? ?? 0,
      success: map['success'] as int? ?? 0,
      isConnected: map['isConnected'] as bool? ?? true,
      isCaptain: map['isCaptain'] as bool? ?? false,
    );
  }
}
