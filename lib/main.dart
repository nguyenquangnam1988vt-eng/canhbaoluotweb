import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:async';
import 'dart:io' show Platform;

void main() {
  runApp(RealNetworkMonitorApp());
}

class RealNetworkMonitorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real Network Monitor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: RealNetworkScreen(),
    );
  }
}

class RealNetworkScreen extends StatefulWidget {
  @override
  _RealNetworkScreenState createState() => _RealNetworkScreenState();
}

class _RealNetworkScreenState extends State<RealNetworkScreen> {
  final Connectivity _connectivity = Connectivity();
  List<AppUsage> _activeApps = [];
  bool _isMonitoring = false;
  Timer? _monitorTimer;
  String _networkStatus = 'Đang kiểm tra...';

  @override
  void initState() {
    super.initState();
    _checkNetwork();
  }

  Future<void> _checkNetwork() async {
    var result = await _connectivity.checkConnectivity();
    setState(() {
      _networkStatus = _getNetworkStatusText(result);
    });
  }

  String _getNetworkStatusText(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi: return '📶 Đang dùng WiFi';
      case ConnectivityResult.mobile: return '📱 Đang dùng Mobile Data';
      case ConnectivityResult.none: return '❌ Mất kết nối mạng';
      default: return '🌐 Đang kết nối...';
    }
  }

  Future<void> _startRealMonitoring() async {
    setState(() {
      _isMonitoring = true;
      _activeApps.clear();
    });

    _monitorTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (_isMonitoring) {
        await _performRealCheck();
      }
    });

    await _performRealCheck();
  }

  Future<void> _performRealCheck() async {
    try {
      // 1. Kiểm tra kết nối mạng
      var connectivityResult = await _connectivity.checkConnectivity();
      await _checkNetwork();
      
      if (connectivityResult != ConnectivityResult.none) {
        // 2. Lấy danh sách app đã cài đặt
        List<Application> apps = await DeviceApps.getInstalledApplications(
          includeSystemApps: true,
          includeAppIcons: false,
        );

        // 3. Lọc app có khả năng dùng mạng
        List<AppUsage> networkApps = [];
        
        for (var app in apps) {
          if (_isLikelyNetworkApp(app.packageName!)) {
            networkApps.add(AppUsage(
              appName: app.appName,
              packageName: app.packageName!,
              isActive: true,
            ));
          }
        }

        setState(() {
          _activeApps = networkApps;
        });

        print('📱 Phát hiện ${_activeApps.length} app có thể dùng mạng');

      } else {
        setState(() {
          _activeApps.clear();
        });
      }

    } catch (e) {
      print('❌ Lỗi kiểm tra: $e');
    }
  }

  bool _isLikelyNetworkApp(String packageName) {
    // Danh sách package name của app hay dùng mạng
    final networkAppPatterns = [
      'facebook', 'messenger', 'instagram', 'whatsapp',
      'twitter', 'youtube', 'tiktok', 'zalo', 'chrome',
      'safari', 'gmail', 'outlook', 'spotify', 'netflix',
      'shoppe', 'lazada', 'viber', 'telegram', 'skype',
      'browser', 'mail', 'music', 'video', 'chat'
    ];

    String lowerPackage = packageName.toLowerCase();
    return networkAppPatterns.any((pattern) => lowerPackage.contains(pattern));
  }

  void _stopMonitoring() {
    setState(() {
      _isMonitoring = false;
      _activeApps.clear();
    });
    _monitorTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Real Network Monitor'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Status Panel
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isMonitoring ? Icons.security : Icons.lock_open,
                        color: _isMonitoring ? Colors.green : Colors.grey,
                        size: 40,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isMonitoring ? '🔄 ĐANG GIÁM SÁT' : '⏸️ CHƯA GIÁM SÁT',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _isMonitoring ? Colors.green : Colors.grey,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _networkStatus,
                              style: TextStyle(fontSize: 14, color: Colors.blue),
                            ),
                            Text(
                              'App có thể dùng mạng: ${_activeApps.length}',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  if (_isMonitoring) ...[
                    LinearProgressIndicator(
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '⏰ Đang giám sát 5 giây/lần',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Control Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isMonitoring ? null : _startRealMonitoring,
                    icon: Icon(Icons.play_arrow),
                    label: Text('BẮT ĐẦU GIÁM SÁT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isMonitoring ? _stopMonitoring : null,
                    icon: Icon(Icons.stop),
                    label: Text('DỪNG LẠI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Active Apps List
          Expanded(
            child: _activeApps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phonelink_erase, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Chưa phát hiện app nào',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'App mạng sẽ hiển thị khi bắt đầu giám sát',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _activeApps.length,
                    itemBuilder: (context, index) {
                      final app = _activeApps[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.apps, color: Colors.blue),
                          title: Text(
                            app.appName,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            _getAppCategory(app.packageName),
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Icon(Icons.wifi, color: Colors.green),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getAppCategory(String packageName) {
    if (packageName.contains('facebook') || packageName.contains('instagram')) {
      return 'Mạng xã hội';
    } else if (packageName.contains('messenger') || packageName.contains('zalo')) {
      return 'Nhắn tin';
    } else if (packageName.contains('youtube') || packageName.contains('tiktok')) {
      return 'Video';
    } else if (packageName.contains('chrome') || packageName.contains('safari')) {
      return 'Trình duyệt';
    } else if (packageName.contains('gmail') || packageName.contains('mail')) {
      return 'Email';
    } else if (packageName.contains('spotify') || packageName.contains('music')) {
      return 'Nhạc';
    } else if (packageName.contains('shoppe') || packageName.contains('lazada')) {
      return 'Mua sắm';
    } else {
      return 'Ứng dụng mạng';
    }
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }
}

class AppUsage {
  final String appName;
  final String packageName;
  final bool isActive;

  AppUsage({
    required this.appName,
    required this.packageName,
    required this.isActive,
  });
}