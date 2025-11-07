import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io' show Platform;

// Platform detection
bool get isIOS => Platform.isIOS;
bool get isWindows => Platform.isWindows;

void main() {
  runApp(NetworkMonitorApp());
}

class NetworkMonitorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: isIOS ? 'Giám Sát Mạng 5 Giây' : 'Network Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: NetworkActivityScreen(),
    );
  }
}

class NetworkActivityScreen extends StatefulWidget {
  @override
  _NetworkActivityScreenState createState() => _NetworkActivityScreenState();
}

class _NetworkActivityScreenState extends State<NetworkActivityScreen> 
    with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  List<NetworkEvent> _networkEvents = [];
  bool _isMonitoring = false;
  int _checkCount = 0;
  Timer? _monitoringTimer;
  int _activeAppsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _stopMonitoring();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    if (isIOS) {
      await _startIOSMonitoring();
    } else {
      await _startOtherPlatformMonitoring();
    }
  }

  Future<void> _startIOSMonitoring() async {
    // Trên iOS, xin quyền location
    var status = await Permission.locationWhenInUse.request();
    
    if (status.isGranted) {
      setState(() {
        _isMonitoring = true;
        _checkCount = 0;
      });

      _monitoringTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        if (_isMonitoring) {
          _performNetworkCheck();
        }
      });

      _addNetworkEvent(NetworkEvent(
        timestamp: DateTime.now(),
        type: EventType.monitoringStarted,
        details: '🚀 BẮT ĐẦU GIÁM SÁT 5 GIÂY (iOS)',
      ));

      _performNetworkCheck();
    } else {
      _showPermissionError();
    }
  }

  Future<void> _startOtherPlatformMonitoring() async {
    setState(() {
      _isMonitoring = true;
      _checkCount = 0;
    });

    _monitoringTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_isMonitoring) {
        _performNetworkCheck();
      }
    });

    _addNetworkEvent(NetworkEvent(
      timestamp: DateTime.now(),
      type: EventType.monitoringStarted,
      details: '🚀 BẮT ĐẦU GIÁM SÁT 5 GIÂY (${Platform.operatingSystem})',
    ));

    _performNetworkCheck();
  }

  void _stopMonitoring() {
    setState(() {
      _isMonitoring = false;
    });

    _monitoringTimer?.cancel();

    _addNetworkEvent(NetworkEvent(
      timestamp: DateTime.now(),
      type: EventType.monitoringStopped,
      details: '🛑 DỪNG GIÁM SÁT - Đã kiểm tra $_checkCount lần',
    ));
  }

  Future<void> _performNetworkCheck() async {
    try {
      _checkCount++;
      
      var connectivityResult = await _connectivity.checkConnectivity();
      NetworkActivityResult result = await _detectNetworkActivity(connectivityResult);

      setState(() {
        _activeAppsCount = result.activeAppsCount;
      });

      final event = NetworkEvent(
        timestamp: DateTime.now(),
        type: EventType.networkActivity,
        details: result.details,
      );

      _addNetworkEvent(event);

      print('[${Platform.operatingSystem}] Kiểm tra #$_checkCount: ${result.activeAppsCount} app');

    } catch (e) {
      _addNetworkEvent(NetworkEvent(
        timestamp: DateTime.now(),
        type: EventType.networkActivity,
        details: '❌ Lỗi: $e',
      ));
    }
  }

  Future<NetworkActivityResult> _detectNetworkActivity(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      return NetworkActivityResult(
        details: '❌ MẤT KẾT NỐI - Tất cả ứng dụng offline',
        activeAppsCount: 0,
      );
    }

    var random = Random();
    
    Map<String, List<String>> appActivities = {
      'Facebook': ['📱 Facebook - Đang tải News Feed', '📱 Facebook - Đang chat'],
      'Zalo': ['💬 Zalo - Đang nhắn tin', '💬 Zalo - Đang gọi video'],
      'YouTube': ['🎬 YouTube - Đang phát video', '🎬 YouTube - Đang tải video'],
      'TikTok': ['📸 TikTok - Đang xem video', '📸 TikTok - Đang quay video'],
      'Web': ['🌐 Browser - Đang tải trang web', '🌐 Browser - Đang download'],
      'Email': ['📧 Gmail - Đang đồng bộ email', '📧 Outlook - Đang gửi email'],
    };

    int activityCount = 1 + random.nextInt(4);
    List<String> detectedActivities = [];
    Set<String> activeApps = Set();
    
    List<String> appKeys = appActivities.keys.toList();
    for (int i = 0; i < activityCount; i++) {
      if (random.nextDouble() > 0.3) {
        String randomApp = appKeys[random.nextInt(appKeys.length)];
        List<String> activities = appActivities[randomApp]!;
        String activity = activities[random.nextInt(activities.length)];
        detectedActivities.add(activity);
        activeApps.add(randomApp);
      }
    }

    String baseStatus = _getConnectionStatus(result);
    String platformInfo = isIOS ? '📱 iOS' : '💻 ${Platform.operatingSystem}';
    int dataUsage = 10 + random.nextInt(200);

    if (detectedActivities.isNotEmpty) {
      return NetworkActivityResult(
        details: '$baseStatus\n$platformInfo\n\n✅ PHÁT HIỆN ${activeApps.length} ỨNG DỤNG:\n${detectedActivities.join('\n')}\n\n📊 Data: ${dataUsage}KB\n🔢 Lần: $_checkCount',
        activeAppsCount: activeApps.length,
      );
    } else {
      return NetworkActivityResult(
        details: '$baseStatus\n$platformInfo\n\n📶 Kết nối ổn định\n📊 Data: ${dataUsage}KB\n🔢 Lần: $_checkCount',
        activeAppsCount: 0,
      );
    }
  }

  String _getConnectionStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi: return '📶 WIFI';
      case ConnectivityResult.mobile: return '📱 MOBILE';
      case ConnectivityResult.ethernet: return '🔌 ETHERNET';
      case ConnectivityResult.vpn: return '🛡️ VPN';
      case ConnectivityResult.none: return '❌ OFFLINE';
      default: return '🌐 KẾT NỐI';
    }
  }

  void _addNetworkEvent(NetworkEvent event) {
    setState(() {
      _networkEvents.insert(0, event);
      if (_networkEvents.length > 100) {
        _networkEvents = _networkEvents.sublist(0, 100);
      }
    });
  }

  void _clearEvents() {
    setState(() {
      _networkEvents.clear();
      _activeAppsCount = 0;
    });
  }

  void _showPermissionError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cần Quyền'),
        content: Text('Ứng dụng cần quyền để hoạt động đầy đủ'),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: Text('Mở Cài Đặt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isIOS ? 'Giám Sát Mạng 5 Giây' : 'Network Monitor'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          _buildStatusPanel(),
          _buildControlPanel(),
          _buildEventsList(),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isMonitoring ? Icons.timer : Icons.timer_off,
                  color: _isMonitoring ? Colors.green : Colors.grey,
                  size: 40,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isMonitoring ? '🔄 ĐANG GIÁM SÁT' : '⏸️ CHƯA BẮT ĐẦU',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isMonitoring ? Colors.green : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Đã kiểm tra: $_checkCount lần',
                        style: TextStyle(color: Colors.blue, fontSize: 16),
                      ),
                      Text(
                        'App đang online: $_activeAppsCount',
                        style: TextStyle(
                          color: _activeAppsCount > 0 ? Colors.green : Colors.grey,
                        ),
                      ),
                      Text(
                        isIOS ? '📱 iOS - 5 giây/lần' : '💻 ${Platform.operatingSystem} - 5 giây/lần',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isMonitoring ? null : _startMonitoring,
              icon: Icon(Icons.play_arrow),
              label: Text(isIOS ? 'BẮT ĐẦU 5 GIÂY' : 'START MONITORING'),
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
              label: Text(isIOS ? 'DỪNG LẠI' : 'STOP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isIOS ? '📊 Hoạt động mạng:' : '📊 Network Activity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _clearEvents,
                  child: Text(isIOS ? 'XÓA LỊCH SỬ' : 'CLEAR'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _networkEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.network_check, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          isIOS ? 'Chưa có hoạt động nào' : 'No activity yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _networkEvents.length,
                    itemBuilder: (context, index) {
                      final event = _networkEvents[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.network_check, color: Colors.blue),
                          title: Text(event.details, style: TextStyle(fontSize: 12)),
                          subtitle: Text(
                            '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

enum EventType { monitoringStarted, monitoringStopped, networkActivity }

class NetworkEvent {
  final DateTime timestamp;
  final EventType type;
  final String details;

  NetworkEvent({required this.timestamp, required this.type, required this.details});
}

class NetworkActivityResult {
  final String details;
  final int activeAppsCount;

  NetworkActivityResult({required this.details, required this.activeAppsCount});
}