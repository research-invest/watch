import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';
import 'models.dart';

// Глобальный экземпляр для уведомлений
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация уведомлений
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const WatchScreen(),
    );
  }
}

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  String debugText = 'Waiting for data...';
  Summary? summary;
  List<Trade> trades = [];
  List<Favorite> favorites = [];
  Timer? _timer;
  Summary? _lastSummary;
  Color backgroundColor = Colors.black;

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
    _fetchData(); // Первоначальная загрузка
    // Автообновление каждые 30 секунд
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'crypto_watch_channel',
      'Crypto Watch Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
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
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newSummary = Summary.fromJson(data['summary']);

        setState(() {
          summary = newSummary;
          _lastSummary = newSummary;
          trades = (data['trades'] as List)
              .map((trade) => Trade.fromJson(trade))
              .toList();
          favorites = (data['favorites'] as List)
              .map((fav) => Favorite.fromJson(fav))
              .toList();
          debugText = 'Data loaded successfully';
          // Обновляем цвет фона
          backgroundColor = _getBackgroundColor();
        });

        // Проверяем изменения в PNL
        if (_lastSummary != null) {
          if (newSummary.todayPnl != _lastSummary!.todayPnl) {
            final difference = newSummary.todayPnl - _lastSummary!.todayPnl;
            final isPositive = difference > 0;

            // Вибрация и уведомление при изменении PNL
            Vibration.vibrate(duration: isPositive ? 100 : 300);
            await _showNotification(
              'PNL Update',
              'Today PNL changed by ${difference.toStringAsFixed(2)} (${isPositive ? '↑' : '↓'})',
            );
          }
        }
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
        Uri.parse('http://37.143.9.19/api/v1/watch/trades/{trade}/cancel'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
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

              if (summary != null) ...[
                Text(
                  'Total: ${summary!.totalPnl.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Today: ${summary!.todayPnl.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: summary!.todayPnl >= 0 ? Colors.green : Colors.red,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
              ],

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
                                'PNL: ${trade.pnl.toStringAsFixed(1)}',
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
              Center(
                child: ElevatedButton(
                  onPressed: _fetchData,
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
                ...favorites.map((fav) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
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
                              fav.code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              fav.price.toStringAsFixed(
                                fav.price < 1 ? 4 : 1
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
                                  '${fav.price1hPercent.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: fav.price1hPercent >= 0
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
                                  '${fav.price4hPercent.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: fav.price4hPercent >= 0
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
                                  '${fav.price24hPercent.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: fav.price24hPercent >= 0
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
                )).toList(),
              ],

            ],
          ),
        ),
      ),
    );
  }
}
