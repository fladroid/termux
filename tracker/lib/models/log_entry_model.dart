// lib/models/log_entry_model.dart

class LogType {
  static const String counter  = 'counter';
  static const String text     = 'text';
  static const String settings = 'settings';
}

class LogEntryModel {
  final int?    id;
  final String  timestamp;
  final String  type;       // counter | text | settings
  final String? buttonId;
  final int?    delta;      // +1 | -1 za counter
  final String? textValue;  // za text gumb ili settings opis
  final bool    deleted;

  LogEntryModel({
    this.id,
    required this.timestamp,
    required this.type,
    this.buttonId,
    this.delta,
    this.textValue,
    this.deleted = false,
  });

  factory LogEntryModel.fromMap(Map<String, dynamic> map) {
    return LogEntryModel(
      id:         map['id']         as int?,
      timestamp:  map['timestamp']  as String,
      type:       map['type']       as String,
      buttonId:   map['button_id']  as String?,
      delta:      map['delta']      as int?,
      textValue:  map['text_value'] as String?,
      deleted:    (map['deleted']   as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'timestamp':  timestamp,
    'type':       type,
    'button_id':  buttonId,
    'delta':      delta,
    'text_value': textValue,
    'deleted':    deleted ? 1 : 0,
  };

  Map<String, dynamic> toJson({bool includeDeleted = false}) => {
    'id':         id,
    'timestamp':  timestamp,
    'type':       type,
    'button_id':  buttonId,
    'delta':      delta,
    'text_value': textValue,
    if (includeDeleted) 'deleted': deleted ? 1 : 0,
  };

  DateTime get dateTime => DateTime.parse(timestamp);
}
