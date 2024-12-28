class Summary {
  final double totalPnl;
  final double todayPnl;
  final int activeTrades;

  Summary({
    required this.totalPnl,
    required this.todayPnl,
    required this.activeTrades,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      totalPnl: json['total_pnl'] is String 
          ? double.parse(json['total_pnl']) 
          : json['total_pnl'].toDouble(),
      todayPnl: json['today_pnl'] is String 
          ? double.parse(json['today_pnl']) 
          : json['today_pnl'].toDouble(),
      activeTrades: json['active_trades'],
    );
  }
}

class Trade {
  final int id;
  final String symbol;
  final String type;
  final double entryPrice;
  final double currentPrice;
  final double pnl;
  final bool canCancel;

  Trade({
    required this.id,
    required this.symbol,
    required this.type,
    required this.entryPrice,
    required this.currentPrice,
    required this.pnl,
    required this.canCancel,
  });

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      id: json['id'],
      symbol: json['symbol'],
      type: json['type'],
      entryPrice: json['entry_price'] is String 
          ? double.parse(json['entry_price']) 
          : json['entry_price'].toDouble(),
      currentPrice: json['current_price'] is String 
          ? double.parse(json['current_price']) 
          : json['current_price'].toDouble(),
      pnl: json['pnl'] is String 
          ? double.parse(json['pnl']) 
          : json['pnl'].toDouble(),
      canCancel: json['can_cancel'],
    );
  }
} 