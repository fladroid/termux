// lib/models/entry_model.dart

class EntryModel {
  final int? id;
  final String buttonId;
  final DateTime timestamp;
  final bool deleted;

  EntryModel({
    this.id,
    required this.buttonId,
    required this.timestamp,
    this.deleted = false,
  });

  factory EntryModel.fromMap(Map<String, dynamic> map) {
    return EntryModel(
      id: map['id'] as int?,
      buttonId: map['button_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      deleted: (map['deleted'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'button_id': buttonId,
      'timestamp': timestamp.toIso8601String(),
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson({bool includeDeleted = false}) {
    return {
      'id': id,
      'button_id': buttonId,
      'timestamp': timestamp.toIso8601String(),
      if (includeDeleted) 'deleted': deleted ? 1 : 0,
    };
  }

  EntryModel copyWith({
    int? id,
    String? buttonId,
    DateTime? timestamp,
    bool? deleted,
  }) {
    return EntryModel(
      id: id ?? this.id,
      buttonId: buttonId ?? this.buttonId,
      timestamp: timestamp ?? this.timestamp,
      deleted: deleted ?? this.deleted,
    );
  }
}
