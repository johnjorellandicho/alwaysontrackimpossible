import 'package:alwaysontrackimpossible/screens/alert_feed_page.dart';
import 'package:alwaysontrackimpossible/screens/setting_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'profile_page.dart'; 
import 'track_ai_page.dart';
import 'setting_page.dart';

// Data point class for charts
class SensorDataPoint {
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final int heartRate;
  final int spO2;

  SensorDataPoint({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.heartRate,
    required this.spO2,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'humidity': humidity,
      'heartRate': heartRate,
      'spO2': spO2,
    };
  }

  factory SensorDataPoint.fromJson(Map<String, dynamic> json) {
    return SensorDataPoint(
      timestamp: DateTime.parse(json['timestamp']),
      temperature: json['temperature'].toDouble(),
      humidity: json['humidity'].toDouble(),
      heartRate: json['heartRate'],
      spO2: json['spO2'],
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          setState(() {
            userData = doc.data() as Map<String, dynamic>;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Unable to load user data'),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Route to appropriate dashboard based on role
    final String role = userData!['role'] ?? '';
    
    if (role == 'patient') {
      return PatientDashboard(userData: userData!);
    } else if (role == 'family') {
      return FamilyDashboard(userData: userData!);
    } else {
      return const Scaffold(
        body: Center(child: Text('Invalid user role')),
      );
    }
  }
}

// Analytics Time Range Enum
enum AnalyticsTimeRange { today, weekly, monthly, last6Months, last12Months }

// Patient Dashboard with Arduino R4 WiFi Integration + MongoDB + Enhanced Analytics
class PatientDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const PatientDashboard({super.key, required this.userData});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _selectedIndex = 2;
  
  // Arduino R4 WiFi sensor data
  double temperature = 0.0;
  double humidity = 0.0;
  int heartRate = 0;
  int spO2 = 0;
  String arduinoStatus = "Connecting...";
  String lastUpdate = "Never";
  Timer? _dataTimer;
  
  // Chart data storage (keep last 20 readings locally, full history in MongoDB)
  List<SensorDataPoint> chartData = [];
  String selectedChart = "Temperature";

  // Arduino R4 WiFi with ESP32-S3 IP - UPDATE THIS!
  String arduinoIP = "192.168.68.118";
  
  // MongoDB API endpoint - UPDATE THIS WITH YOUR BACKEND URL
  String mongodbAPI = "http://localhost:3000"; // Your Node.js/Express API

  // Enhanced Analytics Variables
  AnalyticsTimeRange selectedTimeRange = AnalyticsTimeRange.today;
  List<SensorDataPoint> filteredAnalyticsData = [];
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    
    // Load historical data from MongoDB first
    _loadHistoricalData();
    
    // Start fetching Arduino data immediately
    _fetchArduinoData();
    
    // Setup periodic data fetching every 5 seconds
    _dataTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchArduinoData();
    });

    // Initialize analytics with today's data
    _filterDataByTimeRange(AnalyticsTimeRange.today);
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    super.dispose();
  }

  // Load historical sensor data from MongoDB
  Future<void> _loadHistoricalData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('$mongodbAPI/api/sensor-data/${user.uid}?limit=20'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            chartData = data.map((item) => SensorDataPoint.fromJson(item)).toList();
          });
        }
        
        print("📊 Loaded ${chartData.length} historical data points from MongoDB");
      }
    } catch (e) {
      print("❌ Error loading historical data: $e");
    }
  }

  // Fetch real-time data from Arduino R4 WiFi
  Future<void> _fetchArduinoData() async {
    try {
      final response = await http.get(
        Uri.parse('http://$arduinoIP/data'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            temperature = data['temperature']?.toDouble() ?? 0.0;
            humidity = data['humidity']?.toDouble() ?? 0.0;
            arduinoStatus = data['status'] ?? "Unknown";
            lastUpdate = DateFormat('HH:mm:ss').format(DateTime.now());
            
            // Calculate heart rate and SpO2 based on sensor data
            heartRate = _calculateHeartRate(temperature);
            spO2 = _calculateSpO2(temperature, humidity);
          });

          // Create new data point
          final newDataPoint = SensorDataPoint(
            timestamp: DateTime.now(),
            temperature: temperature,
            humidity: humidity,
            heartRate: heartRate,
            spO2: spO2,
          );
          
          // Add to local chart data
          chartData.add(newDataPoint);
          if (chartData.length > 20) {
            chartData.removeAt(0);
          }
          
          // Save to MongoDB
          _saveToMongoDB(newDataPoint);
        }
        
        print("📡 Arduino R4 WiFi data updated: ${temperature}°C, ${humidity}%");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          arduinoStatus = "Connection Error";
          lastUpdate = "Connection Failed";
        });
      }
      print("❌ Arduino R4 WiFi connection error: $e");
    }
  }

  // Save sensor data to MongoDB
  Future<void> _saveToMongoDB(SensorDataPoint dataPoint) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final payload = {
        'userId': user.uid,
        'userEmail': user.email,
        'deviceType': 'Arduino_R4_WiFi_ESP32S3',
        'sensorData': dataPoint.toJson(),
      };

      final response = await http.post(
        Uri.parse('$mongodbAPI/api/sensor-data'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        print("💾 Data saved to MongoDB successfully");
      } else {
        print("⚠️ MongoDB save failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ MongoDB save error: $e");
    }
  }

  // Heart rate calculation based on temperature (for demo purposes)
  int _calculateHeartRate(double temp) {
    if (temp < 18) return 65; // Cold
    if (temp < 25) return 72; // Normal
    if (temp < 30) return 85; // Warm
    return 95; // Hot
  }

  // SpO2 calculation based on environmental conditions
  int _calculateSpO2(double temp, double hum) {
    int base = 98;
    if (temp > 30) base -= 2; // Hot conditions
    if (hum < 30) base -= 1;  // Dry conditions
    if (hum > 80) base -= 1;  // Very humid
    return base.clamp(88, 100);
  }

  String getTemperatureStatus() {
    if (temperature < 18) return "Cold";
    if (temperature < 25) return "Normal";
    if (temperature < 30) return "Warm";
    return "Hot";
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal': return Colors.green;
      case 'warm': return Colors.orange;
      case 'hot': return Colors.red;
      case 'cold': return Colors.blue;
      default: return Colors.grey;
    }
  }

  // Enhanced Analytics Methods
  void _filterDataByTimeRange(AnalyticsTimeRange range) {
    final now = DateTime.now();
    DateTime startDate;
    
    switch (range) {
      case AnalyticsTimeRange.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case AnalyticsTimeRange.weekly:
        startDate = now.subtract(Duration(days: 7));
        break;
      case AnalyticsTimeRange.monthly:
        startDate = now.subtract(Duration(days: 30));
        break;
      case AnalyticsTimeRange.last6Months:
        startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case AnalyticsTimeRange.last12Months:
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
    }

    setState(() {
      selectedTimeRange = range;
      filteredAnalyticsData = chartData.where((point) => 
          point.timestamp.isAfter(startDate) || 
          point.timestamp.isAtSameMomentAs(startDate)
      ).toList();
    });
    
    // Load more data from MongoDB if needed
    _loadFilteredDataFromMongoDB(range);
  }

  Future<void> _loadFilteredDataFromMongoDB(AnalyticsTimeRange range) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      int daysBack;
      switch (range) {
        case AnalyticsTimeRange.today:
          daysBack = 1;
          break;
        case AnalyticsTimeRange.weekly:
          daysBack = 7;
          break;
        case AnalyticsTimeRange.monthly:
          daysBack = 30;
          break;
        case AnalyticsTimeRange.last6Months:
          daysBack = 180;
          break;
        case AnalyticsTimeRange.last12Months:
          daysBack = 365;
          break;
      }

      final response = await http.get(
        Uri.parse('$mongodbAPI/api/sensor-data/${user.uid}?days=$daysBack'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            filteredAnalyticsData = data.map((item) => SensorDataPoint.fromJson(item)).toList();
          });
        }
        
        print("📊 Loaded ${filteredAnalyticsData.length} data points for ${range.toString().split('.').last}");
      }
    } catch (e) {
      print("❌ Error loading filtered data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading historical data: $e')),
        );
      }
    }
  }

  // Replace the _exportToExcel method with this direct download version
Future<void> _exportToExcel() async {
  if (filteredAnalyticsData.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No data available to export')),
    );
    return;
  }

  setState(() {
    isExporting = true;
  });

  try {
    // Get analytics summary
    final summary = _getAnalyticsSummary();
    
    // Create comprehensive CSV content
    String csvContent = '';
    
    // Add header information
    csvContent += 'Health Data Export\n';
    csvContent += 'Export Date,${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}\n';
    csvContent += 'Time Range,${_getTimeRangeDisplayName(selectedTimeRange)}\n';
    csvContent += 'Total Records,${filteredAnalyticsData.length}\n';
    csvContent += '\n';
    
    // Add summary statistics
    csvContent += 'SUMMARY STATISTICS\n';
    csvContent += 'Average Temperature,${summary['avgTemp'].toStringAsFixed(2)}°C\n';
    csvContent += 'Average Heart Rate,${summary['avgHeartRate']} BPM\n';
    csvContent += 'Average SpO2,${summary['avgSpO2']}%\n';
    csvContent += 'Average Humidity,${summary['avgHumidity'].toStringAsFixed(2)}%\n';
    csvContent += 'Min Temperature,${summary['minTemp'].toStringAsFixed(2)}°C\n';
    csvContent += 'Max Temperature,${summary['maxTemp'].toStringAsFixed(2)}°C\n';
    csvContent += '\n';
    
    // Add detailed data header
    csvContent += 'DETAILED SENSOR DATA\n';
    csvContent += 'Timestamp,Temperature(°C),Humidity(%),Heart Rate(BPM),SpO2(%),Temperature Status,Heart Rate Status,SpO2 Status\n';
    
    // Add detailed data
    for (final dataPoint in filteredAnalyticsData) {
      final tempStatus = _getTemperatureStatusForExport(dataPoint.temperature);
      final hrStatus = _getHeartRateStatusForExport(dataPoint.heartRate);
      final spo2Status = _getSpO2StatusForExport(dataPoint.spO2);
      
      csvContent += '${DateFormat('yyyy-MM-dd HH:mm:ss').format(dataPoint.timestamp)},';
      csvContent += '${dataPoint.temperature},';
      csvContent += '${dataPoint.humidity},';
      csvContent += '${dataPoint.heartRate},';
      csvContent += '${dataPoint.spO2},';
      csvContent += '$tempStatus,';
      csvContent += '$hrStatus,';
      csvContent += '$spo2Status\n';
    }

    // Generate filename with timestamp
    final fileName = 'health_data_${selectedTimeRange.toString().split('.').last}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    
    // For web: Use HTML download approach
    if (kIsWeb) {
      // Create blob and download for web
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = fileName;
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      // For mobile: Try Downloads directory first, then fallback
      try {
        Directory? directory;
        
        // Try to get Downloads directory (Android)
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }
        
        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(csvContent);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File saved to: ${file.path}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open Folder',
                onPressed: () {
                  // You can add code here to open file manager
                },
              ),
            ),
          );
        } else {
          throw Exception('Cannot access storage directory');
        }
      } catch (e) {
        // Fallback: Save to app documents directory and share
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csvContent);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Health Data Export - Save this file to your preferred location',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File created and shared: $fileName'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully exported ${filteredAnalyticsData.length} data points to $fileName'),
        backgroundColor: Colors.green,
      ),
    );
    
  } catch (e) {
    print('Export error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      isExporting = false;
    });
  }
}


  String _getTemperatureStatusForExport(double temp) {
    if (temp < 18) return "Cold";
    if (temp < 25) return "Normal";
    if (temp < 30) return "Warm";
    return "Hot";
  }

  String _getHeartRateStatusForExport(int hr) {
    if (hr < 60) return "Low";
    if (hr <= 100) return "Normal";
    return "High";
  }

  String _getSpO2StatusForExport(int spo2) {
    if (spo2 >= 95) return "Normal";
    if (spo2 >= 90) return "Low";
    return "Critical";
  }

  Map<String, dynamic> _getAnalyticsSummary() {
    if (filteredAnalyticsData.isEmpty) {
      return {
        'avgTemp': 0.0,
        'avgHumidity': 0.0,
        'avgHeartRate': 0,
        'avgSpO2': 0,
        'maxTemp': 0.0,
        'minTemp': 0.0,
        'totalReadings': 0,
        'timeRange': selectedTimeRange.toString().split('.').last,
      };
    }

    final temps = filteredAnalyticsData.map((e) => e.temperature).toList();
    final humidity = filteredAnalyticsData.map((e) => e.humidity).toList();
    final heartRates = filteredAnalyticsData.map((e) => e.heartRate).toList();
    final spO2Values = filteredAnalyticsData.map((e) => e.spO2).toList();

    return {
      'avgTemp': temps.reduce((a, b) => a + b) / temps.length,
      'avgHumidity': humidity.reduce((a, b) => a + b) / humidity.length,
      'avgHeartRate': (heartRates.reduce((a, b) => a + b) / heartRates.length).round(),
      'avgSpO2': (spO2Values.reduce((a, b) => a + b) / spO2Values.length).round(),
      'maxTemp': temps.reduce((a, b) => a > b ? a : b),
      'minTemp': temps.reduce((a, b) => a < b ? a : b),
      'totalReadings': filteredAnalyticsData.length,
      'timeRange': selectedTimeRange.toString().split('.').last,
    };
  }

  String _getTimeRangeDisplayName(AnalyticsTimeRange range) {
    switch (range) {
      case AnalyticsTimeRange.today:
        return 'Today';
      case AnalyticsTimeRange.weekly:
        return 'Week';
      case AnalyticsTimeRange.monthly:
        return 'Month';
      case AnalyticsTimeRange.last6Months:
        return '6 Months';
      case AnalyticsTimeRange.last12Months:
        return '12 Months';
    }
  }

  // Build Enhanced Analytics Section
  Widget _buildEnhancedAnalyticsSection() {
    final summary = _getAnalyticsSummary();
    
    return Column(
      children: [
        // Analytics Header with Time Range Selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Health Analytics",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  // Export Button
                  IconButton(
                    onPressed: isExporting ? null : _exportToExcel,
                    icon: isExporting 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, size: 20),
                    tooltip: "Export to Excel",
                  ),
                  // Time Range Dropdown
                  DropdownButton<AnalyticsTimeRange>(
                    value: selectedTimeRange,
                    items: AnalyticsTimeRange.values.map((range) {
                      return DropdownMenuItem(
                        value: range,
                        child: Text(_getTimeRangeDisplayName(range)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _filterDataByTimeRange(value);
                      }
                    },
                    underline: Container(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        
        // Analytics Summary Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "${_getTimeRangeDisplayName(selectedTimeRange)} Summary",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Summary Statistics
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsStatCard(
                        "Avg Temp",
                        "${summary['avgTemp'].toStringAsFixed(1)}°C",
                        Icons.thermostat,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnalyticsStatCard(
                        "Avg HR",
                        "${summary['avgHeartRate']} BPM",
                        Icons.favorite,
                        Colors.pink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsStatCard(
                        "Avg SpO2",
                        "${summary['avgSpO2']}%",
                        Icons.air,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnalyticsStatCard(
                        "Readings",
                        "${summary['totalReadings']}",
                        Icons.data_usage,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Temperature Range
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text("Min Temp", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            "${summary['minTemp'].toStringAsFixed(1)}°C",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text("Max Temp", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            "${summary['maxTemp'].toStringAsFixed(1)}°C",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text("Avg Humidity", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            "${summary['avgHumidity'].toStringAsFixed(1)}%",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Health Status Indicators
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.health_and_safety, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Current Health Status",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildHealthStatusIndicator(
                        "Temperature",
                        getTemperatureStatus(),
                        getStatusColor(getTemperatureStatus()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHealthStatusIndicator(
                        "Heart Rate",
                        (heartRate >= 60 && heartRate <= 100) ? "Normal" : "Check",
                        (heartRate >= 60 && heartRate <= 100) ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHealthStatusIndicator(
                        "SpO2",
                        spO2 >= 95 ? "Normal" : "Low",
                        spO2 >= 95 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatusIndicator(String label, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTrackAI() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackAIPage(
          userData: widget.userData,
          currentVitals: {
            'temperature': temperature,
            'humidity': humidity,
            'heartRate': heartRate,
            'spO2': spO2,
            'lastUpdate': lastUpdate,
            'temperatureStatus': getTemperatureStatus(),
          },
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Handle navigation
    switch (index) {
      case 0:
        _navigateToTrackAI();
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlertFeedPage(userData: widget.userData),
          ),
        );
        break;
      case 2:
        // Dashboard - Already here, do nothing
        break;
      case 3:
        // Profile - Navigate to ProfilePage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(userData: widget.userData),
          ),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsPage(userData: widget.userData,),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = widget.userData['firstName'] ?? 'Patient';
    String currentDate = DateFormat('MMMM d, y').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            // Header Section with Arduino R4 WiFi Status
            Container(
              width: double.infinity,
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFD0004),
                    Color(0xFFF83E41),
                    Color(0xFFFF5053),
                  ],
                  stops: [0.15, 0.95, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Logo
                  Align(
                    alignment: Alignment.topLeft,
                    child: Image.asset(
                      "assets/alwaysontracklogowhite.png",
                      width: 80,
                      height: 80,
                    ),
                  ),

                  // Profile Avatar
                  Positioned(
                    right: 0,
                    top: 40,
                    child: GestureDetector(
                      onTap: () => _showPatientProfileMenu(context),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        child: Text(
                          firstName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Welcome Message
                  Positioned(
                    right: 90,
                    top: 35,
                    child: Text(
                      "Hello, $firstName!",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Current Date
                  Positioned(
                    right: 90,
                    top: 60,
                    child: Text(
                      currentDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),

                  // Arduino R4 WiFi Connection Status
                  Positioned(
                    right: 90,
                    top: 85,
                    child: Row(
                      children: [
                        const Text(
                          "Arduino R4: ",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                        Icon(
                          Icons.circle,
                          color: arduinoStatus.toLowerCase().contains("online") || 
                                 arduinoStatus.toLowerCase().contains("connected")
                              ? Colors.green
                              : Colors.red,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          arduinoStatus.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Last Update Time
                  Positioned(
                    right: 10,
                    top: 110,
                    child: Text(
                      "Last Update: $lastUpdate",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ),

                  // Device Info
                  Positioned(
                    right: 10,
                    top: 125,
                    child: Text(
                      "ESP32-S3 Mini @ $arduinoIP",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Health Data Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Live Health Data",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            // Sensor Data Row (Temperature & SpO2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildVitalCard(
                      "Temperature", 
                      temperature.toStringAsFixed(1), 
                      "°C", 
                      Icons.thermostat, 
                      Colors.red,
                      subtitle: getTemperatureStatus(),
                      statusColor: getStatusColor(getTemperatureStatus()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalCard(
                      "SpO2", 
                      spO2.toString(), 
                      "%", 
                      Icons.air, 
                      Colors.blue,
                      subtitle: spO2 >= 95 ? "Normal" : "Low",
                      statusColor: spO2 >= 95 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Heart Rate & Humidity Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildVitalCard(
                      "Heart Rate", 
                      heartRate.toString(), 
                      "BPM", 
                      Icons.favorite, 
                      Colors.pink,
                      subtitle: (heartRate >= 60 && heartRate <= 100) ? "Normal" : "Check",
                      statusColor: (heartRate >= 60 && heartRate <= 100) ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalCard(
                      "Humidity", 
                      humidity.toStringAsFixed(1), 
                      "%", 
                      Icons.water_drop, 
                      Colors.cyan,
                      subtitle: "Environment",
                      statusColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Arduino R4 WiFi Status Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: arduinoStatus.toLowerCase().contains("online") || 
                         arduinoStatus.toLowerCase().contains("connected")
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: arduinoStatus.toLowerCase().contains("online") || 
                           arduinoStatus.toLowerCase().contains("connected")
                        ? Colors.green 
                        : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      arduinoStatus.toLowerCase().contains("online") || 
                      arduinoStatus.toLowerCase().contains("connected")
                          ? Icons.wifi 
                          : Icons.wifi_off,
                      color: arduinoStatus.toLowerCase().contains("online") || 
                             arduinoStatus.toLowerCase().contains("connected")
                          ? Colors.green 
                          : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Arduino R4 WiFi + ESP32-S3 Mini",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: arduinoStatus.toLowerCase().contains("online") || 
                                     arduinoStatus.toLowerCase().contains("connected")
                                  ? Colors.green[800] 
                                  : Colors.red[800],
                            ),
                          ),
                          Text(
                            "IP: $arduinoIP | Status: $arduinoStatus",
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            "Data stored in MongoDB",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchArduinoData,
                      tooltip: "Refresh Data",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Enhanced Analytics Section - THIS IS WHERE THE NEW ANALYTICS GO
            _buildEnhancedAnalyticsSection(),

            const SizedBox(height: 20),

            // Quick Actions
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Quick Actions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      "Emergency Alert",
                      Icons.emergency,
                      Colors.red,
                      () => _showEmergencyDialog(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      "View History",
                      Icons.history,
                      Colors.blue,
                      () => _showHistoryDialog(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.black,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: "TrackAI",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Alert",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard(String title, String value, String unit, IconData icon, Color color, {String? subtitle, Color? statusColor}) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor ?? color, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "$value$unit",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: statusColor ?? Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      height: 60,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPatientProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userData: widget.userData),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('MongoDB Data'),
              onTap: () {
                Navigator.pop(context);
                _loadHistoricalData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: const Text('Are you sure you want to send an emergency alert? This will notify emergency contacts and services.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _sendEmergencyAlert();
            },
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sensor Data History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total data points: ${chartData.length}'),
            const SizedBox(height: 10),
            const Text('Data is automatically stored in MongoDB for long-term analysis.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadHistoricalData();
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmergencyAlert() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Send emergency data to MongoDB
      final emergencyData = {
        'userId': user.uid,
        'userEmail': user.email,
        'alertType': 'emergency',
        'timestamp': DateTime.now().toIso8601String(),
        'currentVitals': {
          'temperature': temperature,
          'humidity': humidity,
          'heartRate': heartRate,
          'spO2': spO2,
        },
        'location': 'Patient Dashboard',
      };

      final response = await http.post(
        Uri.parse('$mongodbAPI/api/emergency-alerts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(emergencyData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency alert sent successfully!'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        throw Exception('Failed to send emergency alert');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send emergency alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Family Dashboard with Arduino Integration + MongoDB
class FamilyDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const FamilyDashboard({super.key, required this.userData});

  @override
  State<FamilyDashboard> createState() => _FamilyDashboardState();
}

class _FamilyDashboardState extends State<FamilyDashboard> {
  int _selectedIndex = 2;
  
  // Arduino sensor data (same as patient dashboard)
  double temperature = 0.0;
  double humidity = 0.0;
  int heartRate = 0;
  int spO2 = 0;
  String arduinoStatus = "Connecting...";
  String lastUpdate = "Never";
  Timer? _dataTimer;
  
  List<SensorDataPoint> chartData = [];
  String selectedChart = "Temperature";
  String arduinoIP = "192.168.68.118";
  String mongodbAPI = "http://localhost:3000";

  @override
  void initState() {
    super.initState();
    _loadHistoricalData();
    _fetchArduinoData();
    _dataTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchArduinoData();
    });
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    super.dispose();
  }

  // Same Arduino integration methods as PatientDashboard
  Future<void> _loadHistoricalData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('$mongodbAPI/api/sensor-data/${user.uid}?limit=20'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            chartData = data.map((item) => SensorDataPoint.fromJson(item)).toList();
          });
        }
      }
    } catch (e) {
      print("Error loading historical data: $e");
    }
  }

  Future<void> _fetchArduinoData() async {
    try {
      final response = await http.get(
        Uri.parse('http://$arduinoIP/data'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            temperature = data['temperature']?.toDouble() ?? 0.0;
            humidity = data['humidity']?.toDouble() ?? 0.0;
            arduinoStatus = data['status'] ?? "Unknown";
            lastUpdate = DateFormat('HH:mm:ss').format(DateTime.now());
            heartRate = _calculateHeartRate(temperature);
            spO2 = _calculateSpO2(temperature, humidity);
          });

          final newDataPoint = SensorDataPoint(
            timestamp: DateTime.now(),
            temperature: temperature,
            humidity: humidity,
            heartRate: heartRate,
            spO2: spO2,
          );
          
          chartData.add(newDataPoint);
          if (chartData.length > 20) {
            chartData.removeAt(0);
          }
          
          _saveToMongoDB(newDataPoint);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          arduinoStatus = "Connection Error";
          lastUpdate = "Connection Failed";
        });
      }
    }
  }

  Future<void> _saveToMongoDB(SensorDataPoint dataPoint) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final payload = {
        'userId': user.uid,
        'userEmail': user.email,
        'deviceType': 'Arduino_R4_WiFi_ESP32S3',
        'monitoringRole': 'family',
        'patientInfo': widget.userData['patientInfo'],
        'sensorData': dataPoint.toJson(),
      };

      await http.post(
        Uri.parse('$mongodbAPI/api/sensor-data'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print("MongoDB save error: $e");
    }
  }

  int _calculateHeartRate(double temp) {
    if (temp < 18) return 65;
    if (temp < 25) return 72;
    if (temp < 30) return 85;
    return 95;
  }

  int _calculateSpO2(double temp, double hum) {
    int base = 98;
    if (temp > 30) base -= 2;
    if (hum < 30) base -= 1;
    if (hum > 80) base -= 1;
    return base.clamp(88, 100);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Handle navigation
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrackAIPage(
              userData: widget.userData,
              currentVitals: {
                'temperature': temperature,
                'humidity': humidity,
                'heartRate': heartRate,
                'spO2': spO2,
                'lastUpdate': lastUpdate,
              },
            ),
          ),
        );
        break;
      case 1:
        // Alert - Add navigation when ready
        break;
      case 2:
        // Dashboard - Already here, do nothing
        break;
      case 3:
        // Profile - Navigate to ProfilePage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(userData: widget.userData),
          ),
        );
        break;
      case 4:
        // Settings - Add navigation when ready
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = widget.userData['firstName'] ?? 'Family Member';
    final Map<String, dynamic>? patientInfo = widget.userData['patientInfo'];
    final String patientName = patientInfo != null 
        ? patientInfo['fullName'] ?? 'Patient' 
        : 'Patient';
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFD0004),
              Color(0xFFF83E41),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: Text(
                        firstName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello, $firstName!",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Monitoring: $patientName",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "Arduino: $arduinoStatus | $lastUpdate",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showFamilyProfileMenu(context),
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // White content area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient Info Card
                        _buildPatientInfoCard(patientInfo),
                        const SizedBox(height: 20),
                        
                        // Patient's Vital Signs
                        Text(
                          "$patientName's Live Vital Signs",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Same vital signs grid as patient dashboard
                        Row(
                          children: [
                            Expanded(child: _buildVitalCard("Temperature", temperature.toStringAsFixed(1), "°C", Icons.thermostat, Colors.red)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildVitalCard("SpO2", spO2.toString(), "%", Icons.air, Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _buildVitalCard("Heart Rate", heartRate.toString(), "BPM", Icons.favorite, Colors.pink)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildVitalCard("Humidity", humidity.toStringAsFixed(1), "%", Icons.water_drop, Colors.cyan)),
                          ],
                        ),
                        const SizedBox(height: 25),
                        
                        // Family Actions
                        const Text(
                          "Family Actions",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        Row(
                          children: [
                            Expanded(child: _buildActionCard("Emergency Call", Icons.emergency, Colors.red, () => _showEmergencyDialog(context))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildActionCard("View History", Icons.history, Colors.blue, () => _showHistoryDialog(context))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _buildActionCard("Alert Settings", Icons.notifications, Colors.orange, () {})),
                            const SizedBox(width: 8),
                            Expanded(child: _buildActionCard("Patient Profile", Icons.person, Colors.green, () {})),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.black,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: "TrackAI",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Alert",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoCard(Map<String, dynamic>? patientInfo) {
    if (patientInfo == null) {
      return Card(
        elevation: 4,
        color: Colors.orange.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 30),
              SizedBox(width: 15),
              Expanded(
                child: Text(
                  "Patient information not available",
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String relationship = patientInfo['relationship'] ?? '';
    final String medicalConditions = patientInfo['medicalConditions'] ?? 'None specified';

    return Card(
      elevation: 4,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 10),
                Text(
                  "Patient Information",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow("Name", patientInfo['fullName'] ?? 'Unknown'),
            const SizedBox(height: 8),
            _buildInfoRow("Relationship", relationship),
            const SizedBox(height: 8),
            _buildInfoRow("Medical Conditions", medicalConditions),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            "$label:",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalCard(String title, String value, String unit, IconData icon, Color color) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text("$value$unit", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      height: 50,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _showFamilyProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userData: widget.userData),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Patient Info'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('MongoDB Data'),
              onTap: () {
                Navigator.pop(context);
                _loadHistoricalData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    final patientName = widget.userData['patientInfo']?['fullName'] ?? 'Patient';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: Text('Send emergency alert for $patientName? This will notify emergency contacts and services with current vital signs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _sendEmergencyAlert();
            },
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Patient Data History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total data points: ${chartData.length}'),
            const SizedBox(height: 10),
            const Text('All sensor data is stored in MongoDB for comprehensive patient monitoring.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadHistoricalData();
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmergencyAlert() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final emergencyData = {
        'userId': user.uid,
        'userEmail': user.email,
        'alertType': 'family_emergency',
        'timestamp': DateTime.now().toIso8601String(),
        'patientInfo': widget.userData['patientInfo'],
        'currentVitals': {
          'temperature': temperature,
          'humidity': humidity,
          'heartRate': heartRate,
          'spO2': spO2,
        },
        'location': 'Family Dashboard',
      };

      final response = await http.post(
        Uri.parse('$mongodbAPI/api/emergency-alerts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(emergencyData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency alert sent for patient!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send emergency alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}