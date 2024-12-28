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
  Timer? _timer;
  Summary? _lastSummary;

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

        setState(() {
          summary = newSummary;
          _lastSummary = newSummary;
          trades = (data['trades'] as List)
              .map((trade) => Trade.fromJson(trade))
              .toList();
          debugText = 'Data loaded successfully';
        });
      }
    } catch (e) {
      setState(() {
        debugText = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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

              ...trades.map((trade) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        trade.symbol,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        '${trade.pnl.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: trade.pnl >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),

              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _fetchData,
                  child: const Text('Обновить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
