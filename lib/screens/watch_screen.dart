import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'dart:convert';
import 'dart:async';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import '../widgets/price_history_dialog.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with SingleTickerProviderStateMixin {
  String debugText = 'Waiting for data...';
  Summary? summary;
  List<Trade> trades = [];
  List<Favorite> favorites = [];
  Timer? _timer;
  Summary? _lastSummary;
  Color backgroundColor = Colors.black;
  double? _lastBtcPrice;
  final double _priceChangeThreshold = 1.0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Функция для определения цвета фона
  Color _getBackgroundColor() {
    // Находим BTC в избранном
    final btc = favorites.firstWhere(
          (f) => f.code == 'BTCUSDT',
      orElse: () => Favorite(
        id: 0,
        code: 'BTCUSDT',
        price: 0,
        price24h: 0,
        price4h: 0,
        price1h: 0,
        price24hPercent: 0,
        price4hPercent: 0,
        price1hPercent: 0,
      ),
    );

    if (btc.id == 0) {
      // Если BTC не найден, возвращаем случайный цвет
      return Color((DateTime.now().millisecondsSinceEpoch % 0xFFFFFF).toInt())
          .withOpacity(0.3);
    }

    if (btc.price > btc.price1h) {
      // Цена выросла - зеленоватый фон
      return Colors.green.withOpacity(0.5);
    } else if (btc.price < btc.price1h) {
      // Цена упала - красноватый фон
      return Colors.red.withOpacity(0.3);
    } else {
      // Цена не изменилась - случайный цвет
      return Color((DateTime.now().millisecondsSinceEpoch % 0xFFFFFF).toInt())
          .withOpacity(0.3);
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fetchData();

    // Автообновление каждые 30 секунд
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _checkBtcPriceChange(List<Favorite> favorites) {
    final btc = favorites.firstWhere(
      (f) => f.code == 'BTCUSDT',
      orElse: () => Favorite(
        id: 0,
        code: 'BTCUSDT',
        price: 0,
        price24h: 0,
        price4h: 0,
        price1h: 0,
        price24hPercent: 0,
        price4hPercent: 0,
        price1hPercent: 0,
      ),
    );

    if (btc.id != 0 && _lastBtcPrice != null) {
      final priceChange = ((btc.price - _lastBtcPrice!) / _lastBtcPrice! * 100).abs();

      if (priceChange >= _priceChangeThreshold) {
        final isUp = btc.price > _lastBtcPrice!;
        final direction = isUp ? '↑' : '↓';

        NotificationService.instance.showNotification(
          title: 'BTC Price Alert',
          body: 'BTC price ${direction} ${priceChange.toStringAsFixed(1)}% \n'
               'From: ${_lastBtcPrice!.toStringAsFixed(1)} \n'
               'To: ${btc.price.toStringAsFixed(1)}',
        );

        // Вибрация в зависимости от направления движения
        Vibration.vibrate(duration: isUp ? 600 : 2000);
      }
    }

    // Обновляем последнюю цену
    _lastBtcPrice = btc.price;
  }

  Future<void> _fetchData() async {
    setState(() {
      debugText = 'Fetching data...';
    });

    try {
      final response = await http.get(
        Uri.parse('http://37.143.9.19/api/v1/watch'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${await AuthService().getToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newSummary = Summary.fromJson(data['summary']);
        final newFavorites = (data['favorites'] as List)
            .map((fav) => Favorite.fromJson(fav))
            .toList();

        // Проверяем изменение цены BTC
        _checkBtcPriceChange(newFavorites);

        // Запускаем анимацию если PNL изменился
        if (summary != null && summary!.totalPnl != newSummary.totalPnl) {
          _animationController.forward().then((_) {
            _animationController.reverse();
          });
        }

        setState(() {
          summary = newSummary;
          _lastSummary = newSummary;
          trades = (data['trades'] as List)
              .map((trade) => Trade.fromJson(trade))
              .toList();
          favorites = newFavorites;
          debugText = 'Data loaded successfully';
          backgroundColor = _getBackgroundColor();
        });
      }
    } catch (e) {
      setState(() {
        debugText = 'Error: $e';
      });
    }
  }

  Future<bool> _closeTrade(int tradeId) async {
    try {
      final response = await http.post(
        Uri.parse('http://37.143.9.19/api/v1/watch/trades/{trade}/cancel'), // selll.ru
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({'trade_id': tradeId}),
      );

      if (response.statusCode == 200) {
        // Обновляем данные после успешного закрытия
        await _fetchData();
        return true;
      }
      return false;
    } catch (e) {
      print('Error closing trade: $e');
      return false;
    }
  }

  Future<void> _showConfirmationDialog(BuildContext context, Trade trade) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтверждение'),
          content: Text('Вы уверены, что хотите закрыть сделку ${trade.symbol}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                final success = await _closeTrade(trade.id);
                if (success) {
                  // Показываем уведомление об успехе
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Сделка успешно закрыта'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  // Показываем уведомление об ошибке
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ошибка при закрытии сделки'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Закрыть сделку',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showOrdersDialog(BuildContext context, Trade trade) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '${trade.symbol} Orders',
            style: const TextStyle(fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...trade.orders.map((order) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Price: ${order.price.toStringAsFixed(2)}\n'
                        'Size: ${order.size.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                )).toList(),
                const Divider(),
                Text(
                  'Average: ${trade.averagePrice.toStringAsFixed(2)}\n'
                      'Current: ${trade.currentPrice.toStringAsFixed(2)}\n'
                      'Liq price: ${trade.liquidationPrice.toStringAsFixed(2)}\n'
                      'PNL: ${trade.pnl.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showConfirmationDialog(context, trade);
              },
              child: const Text(
                'Закрыть сделку',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  String formatPnl(double pnl) {
    return pnl.toStringAsFixed(2);
  }

  // Обновляем метод отображения PNL
  Widget _buildPnlText(double pnl) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Text(
            formatPnl(pnl),
            style: TextStyle(
              color: pnl >= 0 ? Colors.green : Colors.red,
              fontSize: 20 * _scaleAnimation.value,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLogoutConfirmDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Подтверждение',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Вы действительно хотите выйти?',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Отмена',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Сначала закрываем диалог
                Navigator.of(context).pop();
                // Очищаем токен
                await AuthService().logout();
                // Переходим на экран логина
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                }
              },
              child: const Text(
                'Выйти',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Debug: $debugText',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),

                if (trades.isNotEmpty) ...[
                  const Text(
                    'Active Trades:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...trades.map((trade) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: InkWell(
                      onTap: () => _showOrdersDialog(context, trade),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${trade.symbol} (${trade.type})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'PNL: ${formatPnl(trade.pnl)}',
                                  style: TextStyle(
                                    color: trade.pnl >= 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Avg: ${trade.averagePrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Liq price: ${trade.liquidationPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Current: ${trade.currentPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                ],

                const SizedBox(height: 16),

                if (summary != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Total: ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildPnlText(summary!.totalPnl),
                        ],
                      ),
                      // Today и Period PNL
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Today: ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                formatPnl(summary!.todayPnl),
                                style: TextStyle(
                                  color: summary!.todayPnl >= 0 ? Colors.green : Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                'Period: ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                formatPnl(summary!.periodPnl ?? 0.0),
                                style: TextStyle(
                                  color: (summary!.periodPnl ?? 0.0) >= 0 ? Colors.green : Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      _fetchData();
                      await Vibration.vibrate(duration: 100);
                    },
                    child: const Text('Обновить'),
                  ),
                ),
                if (favorites.isNotEmpty) ...[
                  const Text(
                    'Favorites:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...favorites.map((favorite) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => PriceHistoryDialog(symbol: favorite.code),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  favorite.code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  favorite.price.toStringAsFixed(
                                      favorite.price < 1 ? 6 : 1
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '1h: ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${favorite.price1hPercent.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        color: favorite.price1hPercent >= 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text(
                                      '4h: ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${favorite.price4hPercent.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        color: favorite.price4hPercent >= 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text(
                                      '24h: ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${favorite.price24hPercent.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        color: favorite.price24hPercent >= 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                ],

                const SizedBox(height: 24),
                const Divider(color: Colors.grey),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () => _showLogoutConfirmDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Выйти',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
