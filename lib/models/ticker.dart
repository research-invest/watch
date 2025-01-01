class Ticker {
  final String symbol;
  final double lastPrice;
  final double volume;
  final DateTime timestamp;

  Ticker({
    required this.symbol,
    required this.lastPrice,
    required this.volume,
    required this.timestamp,
  });

  factory Ticker.fromJson(Map<String, dynamic> json) {
    return Ticker(
      symbol: json['symbol'],
      lastPrice: json['last_price'].toDouble(),
      volume: json['volume'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
} 