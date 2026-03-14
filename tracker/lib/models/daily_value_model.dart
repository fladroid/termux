// lib/models/daily_value_model.dart

class DailyValueModel {
  final int?   id;
  final String buttonId;
  final String date;   // format: 2026-03-14
  final int    value;

  DailyValueModel({
    this.id,
    required this.buttonId,
    required this.date,
    required this.value,
  });

  factory DailyValueModel.fromMap(Map<String, dynamic> map) {
    return DailyValueModel(
      id:       map['id']        as int?,
      buttonId: map['button_id'] as String,
      date:     map['date']      as String,
      value:    map['value']     as int,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'button_id': buttonId,
    'date':      date,
    'value':     value,
  };

  DailyValueModel copyWith({int? id, int? value}) => DailyValueModel(
    id:       id       ?? this.id,
    buttonId: buttonId,
    date:     date,
    value:    value    ?? this.value,
  );

  static String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
}
