class Summary {
  final double totalPnl;
  final double todayPnl;
  final double periodPnl;
  final int activeTrades;

  Summary({
    required this.totalPnl,
    required this.todayPnl,
    required this.periodPnl,
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
      periodPnl: json['period_pnl'] is String
          ? double.parse(json['period_pnl'])
          : json['period_pnl'].toDouble(),
      activeTrades: json['active_trades'],
    );
  }
}

class Order {
  final int id;
  final double price;
  final double size;

  Order({
    required this.id,
    required this.price,
    required this.size,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      price: json['price'] is String
          ? double.parse(json['price'])
          : json['price'].toDouble(),
      size: json['size'] is String
          ? double.parse(json['size'])
          : json['size'].toDouble(),
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
  final double averagePrice;
  final double liquidationPrice;
  final double targetProfitPrice;
  final double targetProfitPercent;
  final double targetProfitAmount;
  final List<Order> orders;

  Trade({
    required this.id,
    required this.symbol,
    required this.type,
    required this.entryPrice,
    required this.currentPrice,
    required this.pnl,
    required this.canCancel,
    required this.averagePrice,
    required this.liquidationPrice,
    required this.targetProfitPrice,
    required this.targetProfitPercent,
    required this.targetProfitAmount,
    required this.orders,
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
      averagePrice: json['average_price'] is String
          ? double.parse(json['average_price'])
          : json['average_price'].toDouble(),
      liquidationPrice: json['liquidation_price'] is String
          ? double.parse(json['liquidation_price'])
          : json['liquidation_price'].toDouble(),
      targetProfitPrice: json['target_profit_price'] is String
          ? double.parse(json['target_profit_price'])
          : json['target_profit_price'].toDouble(),
      targetProfitPercent: json['target_profit_percent'] is String
          ? double.parse(json['target_profit_percent'])
          : json['target_profit_percent'].toDouble(),
      targetProfitAmount: json['target_profit_amount'] is String
          ? double.parse(json['target_profit_amount'])
          : json['target_profit_amount'].toDouble(),
      orders: (json['orders'] as List)
          .map((order) => Order.fromJson(order))
          .toList(),
    );
  }
}

class Favorite {
  final int id;
  final String code;
  final double price;
  final double price24h;
  final double price4h;
  final double price1h;
  final double price24hPercent;
  final double price4hPercent;
  final double price1hPercent;

  Favorite({
    required this.id,
    required this.code,
    required this.price,
    required this.price24h,
    required this.price4h,
    required this.price1h,
    required this.price24hPercent,
    required this.price4hPercent,
    required this.price1hPercent,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'],
      code: json['code'],
      price: json['price'] is String
          ? double.parse(json['price'])
          : json['price'].toDouble(),
      price24h: json['price_24h'] is String
          ? double.parse(json['price_24h'])
          : json['price_24h'].toDouble(),
      price4h: json['price_4h'] is String
          ? double.parse(json['price_4h'])
          : json['price_4h'].toDouble(),
      price1h: json['price_1h'] is String
          ? double.parse(json['price_1h'])
          : json['price_1h'].toDouble(),
      price24hPercent: json['price_24h_percent'] is String
          ? double.parse(json['price_24h_percent'])
          : json['price_24h_percent'].toDouble(),
      price4hPercent: json['price_4h_percent'] is String
          ? double.parse(json['price_4h_percent'])
          : json['price_4h_percent'].toDouble(),
      price1hPercent: json['price_1h_percent'] is String
          ? double.parse(json['price_1h_percent'])
          : json['price_1h_percent'].toDouble(),
    );
  }
}
