import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() => runApp(MyApp());

void _requestPermission() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BluetoothScreen(),
    );
  }
}

class BluetoothScreen extends StatefulWidget {
  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  BluetoothConnection? connection;
  List<ChartData> dataPoints = []; // Store received data points
  bool isLoading = false;
  bool hasError = false;
  bool showWarning = false;

  @override
  void initState() {
    super.initState();
    initBluetooth();
  }

  Future<void> initBluetooth() async {
    setState(() {
      isLoading = true;
    });

    // Request Bluetooth permissions
    if (!await _requestPermissions()) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
      return;
    }

    // Initialize Bluetooth
    await FlutterBluetoothSerial.instance.requestEnable();

    setState(() {
      isLoading = false;
    });
  }

  Future<bool> _requestPermissions() async {
    // Request Bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
    ].request();

    return statuses[Permission.bluetooth] == PermissionStatus.granted &&
        statuses[Permission.bluetoothConnect] == PermissionStatus.granted;
  }

  // Discover and connect to HC-05
  Future<void> _discoverDevices() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    List<BluetoothDevice> devices = [];
    try {
      devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
        hasError = true;
      });
      return;
    }

    // Choose HC-05 device or use the first device found
    BluetoothDevice hc05 = devices.firstWhere((device) => device.name == 'HC-05');

    // Connect to the chosen device
    try {
      connection = await BluetoothConnection.toAddress(hc05.address);
      print('Connected to ${hc05.name}');

      // Start reading data
      connection!.input?.listen((Uint8List data) {
        String stringData = utf8.decode(data); // Convert bytes to string
        double numericData = double.tryParse(stringData) ?? 0.0; // Parse data to double
        setState(() {
          dataPoints.add(ChartData(dataPoints.length + 1, numericData)); // Add data point to list

          // Check if received value exceeds threshold (e.g., 140)
          if (numericData > 140) {
            showWarning = true; // Display warning
          } else {
            showWarning = false; // Hide warning
          }
        });
      }).onDone(() {
        print('Disconnected');
        setState(() {
          connection = null;
        });
      });
    } catch (e) {
      print('Failed to connect: $e');
      setState(() {
        hasError = true;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Example'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Failed to initialize Bluetooth.'),
                      ElevatedButton(
                        onPressed: () {
                          initBluetooth(); // Retry initialization
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _discoverDevices(); // Start device discovery and connection
                        },
                        child: Text('Connect to HC-05'),
                      ),
                      if (connection != null)
                        ElevatedButton(
                          onPressed: () {
                            connection!.finish(); // Disconnect from the device
                          },
                          child: Text('Disconnect'),
                        ),
                      SizedBox(height: 20),
                      // Display warning message if value exceeds 140
                      if (showWarning)
                        Text(
                          'Warning: Value exceeds 140!',
                          style: TextStyle(color: Colors.red),
                        ),
                      // Display line chart
                      if (dataPoints.isNotEmpty)
                        Container(
                          height: 300,
                          padding: EdgeInsets.all(16),
                          child: SfCartesianChart(
                            primaryXAxis: NumericAxis(),
                            series: <LineSeries<ChartData, double>>[
                              LineSeries<ChartData, double>(
                                dataSource: dataPoints,
                                xValueMapper: (ChartData sales, _) => sales.x,
                                yValueMapper: (ChartData sales, _) => sales.y,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class ChartData {
  final double x;
  final double y;

  ChartData(this.x, this.y);
}
