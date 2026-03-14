// lib/models/button_model.dart

class ButtonType {
  static const String counter = 'counter';
  static const String text    = 'text';
}

class ButtonModel {
  final String id;
  final String type; // counter | text
  final String symbol;
  final Map<String, String> labels;

  ButtonModel({
    required this.id,
    required this.symbol,
    required this.labels,
    this.type = ButtonType.counter,
  });

  factory ButtonModel.fromJson(Map<String, dynamic> json) {
    return ButtonModel(
      id:     json['id']     as String,
      symbol: json['symbol'] as String,
      type:   json['type']   as String? ?? ButtonType.counter,
      labels: Map<String, String>.from(json['label'] as Map),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':     id,
    'type':   type,
    'symbol': symbol,
    'label':  labels,
  };

  String getLabel(String language) =>
      labels[language] ?? labels['en'] ?? symbol;

  bool get isCounter => type == ButtonType.counter;
  bool get isText    => type == ButtonType.text;
}
