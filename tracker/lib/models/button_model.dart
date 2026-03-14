// lib/models/button_model.dart

class ButtonModel {
  final String id;
  final String symbol;
  final Map<String, String> labels;

  ButtonModel({
    required this.id,
    required this.symbol,
    required this.labels,
  });

  factory ButtonModel.fromJson(Map<String, dynamic> json) {
    return ButtonModel(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      labels: Map<String, String>.from(json['label'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'label': labels,
    };
  }

  String getLabel(String language) {
    return labels[language] ?? labels['en'] ?? symbol;
  }
}
