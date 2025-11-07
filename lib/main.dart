import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NetworkMonitorApp());
}

class NetworkMonitorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: NetworkMonitorScreen(),
    );
  }
}

class NetworkMonitorScreen extends StatefulWidget {
  @override
  _NetworkMonitorScreenState createState() => _NetworkMonitorScreenState();
}

class _NetworkMonitorScreenState extends State<NetworkMonitorScreen> {
  final Connectivity _connectivity = Connectivity();
  String _networkStatus = 'Đang kiểm tra...';
  bool _isMonitoring = false;
  Timer? _monitorTimer;
  List<String> _networkEvents = [];

  @override
  void initState() {
    super.initState();
    _checkNetwork();
  }

  @override
  void dispose() {
    _stopMonitoring();
    super.dispose();
  }

  Future<void> _checkNetwork() async {
    try {
      var result = await _connectivity.checkConnectivity();
      setState(() {
        _networkStatus = _getNetworkStatus(result);
      });
      _addEvent('Kiểm tra: $_networkStatus');
    } catch (e) {
      setState(() {
        _networkStatus = 'Lỗi kiểm tra';
      });
    }
  }

  String _getNetworkStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return '📶 Đang dùng WiFi';
      case ConnectivityResult.mobile:
        return '📱 Đang dùng Mobile Data';
      case ConnectivityResult.none:
        return '❌ Mất kết nối mạng';
      default:
        return '🌐 Đang kết nối...';
    }
  }

  void _startMonitoring() {
    setState(() {
      _isMonitoring = true;
      _networkEvents.clear();
    });

    _monitorTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (_isMonitoring) {
        await _checkNetwork();
        _addEvent('Giám sát - ${DateTime.now().toString()}');
      }
    });

    _addEvent('Bắt đầu giám sát mạng');
  }

  void _stopMonitoring() {
    setState(() {
      _isMonitoring = false;
    });
    _monitorTimer?.cancel();
    _addEvent('Dừng giám sát');
  }

  void _addEvent(String event) {
    setState(() {
      _networkEvents.insert(0, '${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} - $event');
      if (_networkEvents.length > 20) {
        _networkEvents = _networkEvents.sublist(0, 20);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Network Monitor'),
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
                        _isMonitoring ? Icons.network_check : Icons.network_wifi,
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
                            SizedBox(height: 8),
                            Text(
                              _networkStatus,
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              'Giám sát 5 giây/lần',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isMonitoring) ...[
                    SizedBox(height: 10),
                    LinearProgressIndicator(
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
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
                    onPressed: _isMonitoring ? null : _startMonitoring,
                    icon: Icon(Icons.play_arrow),
                    label: Text('BẮT ĐẦU'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isMonitoring ? _stopMonitoring : null,
                    icon: Icon(Icons.stop),
                    label: Text('DỪNG'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Events List
          Expanded(
            child: _networkEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Chưa có sự kiện nào'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _networkEvents.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: Icon(Icons.circle, size: 8, color: Colors.blue),
                        title: Text(_networkEvents[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}