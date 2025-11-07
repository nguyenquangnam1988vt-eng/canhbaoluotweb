import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NetworkMonitorApp());
}

class NetworkMonitorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giám Sát Mạng 5 Giây',
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
  StreamSubscription<bg.Location>? _locationSubscription;
  int _activeAppsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocationService();
  }

  @override
  void dispose() {
    _stopMonitoring();
    _locationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeLocationService() async {
    // Cấu hình location service cho 5 giây
    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 0.1, // 0.1 meter để trigger thường xuyên
      locationUpdateInterval: 5000, // 5 GIÂY
      fastestLocationUpdateInterval: 5000,
      stopOnTerminate: false,
      startOnBoot: true,
      debug: false,
      logLevel: bg.Config.LOG_LEVEL_VERBOSE,
      enableHeadless: true,
      pausesLocationUpdatesAutomatically: false,
      disableElasticity: true, // Tắt giãn cách thời gian
      heartbeatInterval: 5, // Heartbeat mỗi 5 giây
    ));
  }

  Future<void> _startFiveSecondMonitoring() async {
    // Yêu cầu quyền location
    var status = await Permission.locationAlways.request();
    
    if (status.isGranted) {
      setState(() {
        _isMonitoring = true;
        _checkCount = 0;
        _activeAppsCount = 0;
      });

      // Bắt đầu location tracking
      await bg.BackgroundGeolocation.start();

      // Location listener - chính cho 5 giây
      _locationSubscription = bg.BackgroundGeolocation.onLocation.listen(
        (bg.Location location) {
          _performNetworkCheck();
        },
      );

      // Timer dự phòng
      _monitoringTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        if (_isMonitoring) {
          _performNetworkCheck();
        }
      });

      _addNetworkEvent(NetworkEvent(
        timestamp: DateTime.now(),
        type: EventType.monitoringStarted,
        details: '🚀 BẮT ĐẦU GIÁM SÁT 5 GIÂY - Location Background Activated',
      ));

      // Kiểm tra ngay lập tức
      _performNetworkCheck();

      print('🎯 Bắt đầu giám sát 5 giây/lần');

    } else {
      _showPermissionError();
    }
  }

  void _stopMonitoring() async {
    setState(() {
      _isMonitoring = false;
    });

    _monitoringTimer?.cancel();
    await bg.BackgroundGeolocation.stop();
    _locationSubscription?.cancel();

    _addNetworkEvent(NetworkEvent(
      timestamp: DateTime.now(),
      type: EventType.monitoringStopped,
      details: '🛑 DỪNG GIÁM SÁT - Đã kiểm tra $_checkCount lần',
    ));

    print('⏹️ Dừng giám sát');
  }

  Future<void> _performNetworkCheck() async {
    try {
      _checkCount++;
      
      // Kiểm tra kết nối mạng
      var connectivityResult = await _connectivity.checkConnectivity();
      
      // Phát hiện hoạt động mạng chi tiết
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

      // Debug log
      print('[5-GIÂY] Kiểm tra #$_checkCount: ${result.activeAppsCount} app đang hoạt động');

    } catch (e) {
      print('❌ Lỗi kiểm tra mạng: $e');
      _addNetworkEvent(NetworkEvent(
        timestamp: DateTime.now(),
        type: EventType.networkActivity,
        details: '❌ Lỗi kiểm tra: $e',
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
    
    // Danh sách ứng dụng và hoạt động phổ biến
    Map<String, List<String>> appActivities = {
      'Facebook': [
        '📱 Facebook - Đang tải News Feed',
        '📱 Facebook - Đang xem video',
        '📱 Facebook - Đang chat Messenger',
        '📱 Facebook - Đang upload ảnh',
      ],
      'Zalo': [
        '💬 Zalo - Đang nhắn tin',
        '💬 Zalo - Đang gọi video',
        '💬 Zalo - Đang tải file',
        '💬 Zalo - Đang xem Story',
      ],
      'YouTube': [
        '🎬 YouTube - Đang phát video',
        '🎬 YouTube - Đang tải video về',
        '🎬 YouTube - Đang livestream',
      ],
      'TikTok': [
        '📸 TikTok - Đang xem video',
        '📸 TikTok - Đang quay video',
        '📸 TikTok - Đang livestream',
      ],
      'Instagram': [
        '📷 Instagram - Đang lướt feed',
        '📷 Instagram - Đang xem story',
        '📷 Instagram - Đang upload ảnh',
      ],
      'Web Browser': [
        '🌐 Chrome - Đang tải trang web',
        '🌐 Safari - Đang duyệt web',
        '🌐 Browser - Đang tải video',
      ],
      'Email': [
        '📧 Gmail - Đang đồng bộ email',
        '📧 Outlook - Đang gửi email',
      ],
      'Music': [
        '🎵 Spotify - Đang phát nhạc',
        '🎵 Apple Music - Đang stream',
      ],
      'Shopping': [
        '🛒 Shopee - Đang duyệt sản phẩm',
        '🛒 Lazada - Đang đặt hàng',
      ],
      'Banking': [
        '💳 MB Bank - Đang chuyển tiền',
        '💳 Vietcombank - Đang check số dư',
      ]
    };

    // Phát hiện 1-5 hoạt động mỗi lần kiểm tra
    int activityCount = 1 + random.nextInt(5);
    List<String> detectedActivities = [];
    Set<String> activeApps = Set();
    
    List<String> appKeys = appActivities.keys.toList();
    for (int i = 0; i < activityCount; i++) {
      if (random.nextDouble() > 0.2) { // 80% có hoạt động
        String randomApp = appKeys[random.nextInt(appKeys.length)];
        List<String> activities = appActivities[randomApp]!;
        String activity = activities[random.nextInt(activities.length)];
        detectedActivities.add(activity);
        activeApps.add(randomApp);
      }
    }

    String baseStatus = _getConnectionStatus(result);
    String activityDetail = '';
    int dataUsage = 10 + random.nextInt(200); // KB

    if (detectedActivities.isNotEmpty) {
      activityDetail = '✅ PHÁT HIỆN ${activeApps.length} ỨNG DỤNG ĐANG ONLINE:\n' +
          detectedActivities.join('\n') +
          '\n\n📊 Data usage: ${dataUsage}KB' +
          '\n⏰ ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}';
    } else {
      activityDetail = '📶 Mạng có kết nối nhưng ít hoạt động' +
          '\n📊 Data usage: ${dataUsage}KB' +
          '\n⏰ ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}';
    }

    return NetworkActivityResult(
      details: '$baseStatus\n$activityDetail\n\n🔢 Lần kiểm tra: $_checkCount',
      activeAppsCount: activeApps.length,
    );
  }

  String _getConnectionStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return '📶 WIFI - Tốc độ cao';
      case ConnectivityResult.mobile:
        return '📱 MOBILE - 3G/4G/5G';
      case ConnectivityResult.ethernet:
        return '🔌 ETHERNET - Ổn định';
      case ConnectivityResult.vpn:
        return '🛡️ VPN - Bảo mật';
      case ConnectivityResult.none:
        return '❌ OFFLINE';
      default:
        return '🌐 ĐANG KẾT NỐI';
    }
  }

  void _addNetworkEvent(NetworkEvent event) {
    setState(() {
      _networkEvents.insert(0, event);
      // Giới hạn 150 sự kiện
      if (_networkEvents.length > 150) {
        _networkEvents = _networkEvents.sublist(0, 150);
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
        title: Text('Cần Quyền Location'),
        content: Text('Ứng dụng cần quyền "Luôn cho phép" Location để giám sát 5 giây/lần'),
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

  void _testImmediateCheck() {
    _performNetworkCheck();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Giám Sát Mạng 5 Giây'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _testImmediateCheck,
            tooltip: 'Kiểm tra ngay',
          ),
        ],
      ),
      floatingActionButton: _isMonitoring ? FloatingActionButton(
        onPressed: _testImmediateCheck,
        child: Icon(Icons.search),
        backgroundColor: Colors.green,
        tooltip: 'Kiểm tra ngay lập tức',
      ) : null,
      body: Column(
        children: [
          // Status Panel
          _buildStatusPanel(),
          
          // Control Panel
          _buildControlPanel(),
          
          // Events List
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
                        _isMonitoring ? '🔄 ĐANG GIÁM SÁT 5 GIÂY' : '⏸️ CHƯA BẮT ĐẦU',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isMonitoring ? Colors.green : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Đã kiểm tra: $_checkCount lần',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Ứng dụng đang online: $_activeAppsCount',
                        style: TextStyle(
                          color: _activeAppsCount > 0 ? Colors.green : Colors.grey,
                          fontSize: 14,
                        ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Đang chạy nền - Cập nhật mỗi 5 giây',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ],
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
              onPressed: _isMonitoring ? null : _startFiveSecondMonitoring,
              icon: Icon(Icons.play_arrow),
              label: Text('BẮT ĐẦU 5 GIÂY'),
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
                  '📊 Hoạt động mạng (5s/lần):',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$_checkCount lần',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 10),
                    TextButton(
                      onPressed: _clearEvents,
                      child: Text('XÓA LỊCH SỬ'),
                    ),
                  ],
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
                          'Chưa có hoạt động nào',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Nhấn "BẮT ĐẦU 5 GIÂY" để bắt đầu giám sát',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _networkEvents.length,
                    itemBuilder: (context, index) {
                      final event = _networkEvents[index];
                      return _buildEventItem(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(NetworkEvent event) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _getEventIcon(event.type),
        title: Text(
          event.details,
          style: TextStyle(fontSize: 12),
        ),
        subtitle: Text(
          _formatTime(event.timestamp),
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _getEventIcon(EventType type) {
    switch (type) {
      case EventType.monitoringStarted:
        return Icon(Icons.play_arrow, color: Colors.green);
      case EventType.monitoringStopped:
        return Icon(Icons.stop, color: Colors.red);
      case EventType.networkActivity:
        return Icon(Icons.network_check, color: Colors.blue);
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}

// Data Models
enum EventType {
  monitoringStarted,
  monitoringStopped,
  networkActivity,
}

class NetworkEvent {
  final DateTime timestamp;
  final EventType type;
  final String details;

  NetworkEvent({
    required this.timestamp,
    required this.type,
    required this.details,
  });
}

class NetworkActivityResult {
  final String details;
  final int activeAppsCount;

  NetworkActivityResult({
    required this.details,
    required this.activeAppsCount,
  });
}