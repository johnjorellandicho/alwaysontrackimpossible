import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard_screen.dart';
import 'profile_page.dart';

class Alert {
  final String id;
  final String type;
  final String severity;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? vitals;
  final bool resolved;

  Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.vitals,
    this.resolved = false,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['_id'] ?? '',
      type: json['alertType'] ?? 'System',
      severity: _getSeverityFromAlert(json),
      message: _getMessageFromAlert(json),
      timestamp: DateTime.parse(json['timestamp']),
      vitals: json['currentVitals'],
      resolved: json['resolved'] ?? false,
    );
  }

  static String _getSeverityFromAlert(Map<String, dynamic> json) {
    final alertType = json['alertType'] ?? '';
    if (alertType.contains('emergency')) return 'Critical';
    if (json['currentVitals'] != null) {
      final vitals = json['currentVitals'];
      final temp = vitals['temperature'] ?? 0.0;
      final heartRate = vitals['heartRate'] ?? 70;
      final spO2 = vitals['spO2'] ?? 98;
      
      if (temp > 38.5 || heartRate > 120 || spO2 < 90) return 'Critical';
      if (temp > 37.5 || heartRate > 100 || spO2 < 95) return 'Caution';
    }
    return 'Normal';
  }

  static String _getMessageFromAlert(Map<String, dynamic> json) {
    final alertType = json['alertType'] ?? '';
    final vitals = json['currentVitals'];
    
    if (alertType.contains('emergency')) {
      return 'Emergency alert triggered';
    }
    
    if (vitals != null) {
      final temp = vitals['temperature'] ?? 0.0;
      final heartRate = vitals['heartRate'] ?? 70;
      final spO2 = vitals['spO2'] ?? 98;
      
      if (temp > 38.5) return 'High temperature detected: ${temp.toStringAsFixed(1)}°C';
      if (temp < 35.0) return 'Low temperature detected: ${temp.toStringAsFixed(1)}°C';
      if (heartRate > 120) return 'High heart rate detected: $heartRate BPM';
      if (heartRate < 50) return 'Low heart rate detected: $heartRate BPM';
      if (spO2 < 90) return 'Critical SpO2 level: $spO2%';
      if (spO2 < 95) return 'Low SpO2 level: $spO2%';
      
      return 'Vital signs monitoring update';
    }
    
    return json['message'] ?? 'System alert';
  }
}

class AlertFeedPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AlertFeedPage({super.key, required this.userData});

  @override
  State<AlertFeedPage> createState() => _AlertFeedPageState();
}

class _AlertFeedPageState extends State<AlertFeedPage> {
  String selectedSeverity = "All";
  String selectedType = "All";
  String selectedDateFilter = "Today";
  DateTime? customDate;
  int _selectedIndex = 1;

  // MongoDB connection
  String mongodbAPI = "http://localhost:3000"; // Update with your backend URL
  List<Alert> alerts = [];
  List<Alert> emergencyAlerts = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAlertsFromMongoDB();
    _generateVitalSignAlerts();
  }

  Future<void> _loadAlertsFromMongoDB() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = "User not authenticated";
          isLoading = false;
        });
        return;
      }

      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Load emergency alerts
      final emergencyResponse = await http.get(
        Uri.parse('$mongodbAPI/api/emergency-alerts/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (emergencyResponse.statusCode == 200) {
        final List<dynamic> emergencyData = json.decode(emergencyResponse.body);
        emergencyAlerts = emergencyData.map((item) => Alert.fromJson(item)).toList();
      }

      // Load sensor data for vital sign alerts
      final sensorResponse = await http.get(
        Uri.parse('$mongodbAPI/api/sensor-data/${user.uid}?limit=50'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (sensorResponse.statusCode == 200) {
        final List<dynamic> sensorData = json.decode(sensorResponse.body);
        _processSensorDataForAlerts(sensorData);
      }

      // Combine all alerts
      alerts = [...emergencyAlerts, ...alerts];
      alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        isLoading = false;
      });

      print("📱 Loaded ${alerts.length} alerts from MongoDB");

    } catch (e) {
      setState(() {
        errorMessage = "Failed to load alerts: ${e.toString()}";
        isLoading = false;
      });
      print("❌ Error loading alerts: $e");
    }
  }

  void _processSensorDataForAlerts(List<dynamic> sensorData) {
    List<Alert> vitalAlerts = [];
    
    for (var data in sensorData) {
      final temp = data['temperature'] ?? 0.0;
      final heartRate = data['heartRate'] ?? 70;
      final spO2 = data['spO2'] ?? 98;
      final timestamp = DateTime.parse(data['timestamp']);
      
      // Generate alerts for abnormal readings
      if (temp > 38.5) {
        vitalAlerts.add(Alert(
          id: 'temp_high_${timestamp.millisecondsSinceEpoch}',
          type: 'Temperature',
          severity: 'Critical',
          message: 'High temperature detected: ${temp.toStringAsFixed(1)}°C',
          timestamp: timestamp,
          vitals: data,
        ));
      } else if (temp > 37.5) {
        vitalAlerts.add(Alert(
          id: 'temp_caution_${timestamp.millisecondsSinceEpoch}',
          type: 'Temperature',
          severity: 'Caution',
          message: 'Elevated temperature: ${temp.toStringAsFixed(1)}°C',
          timestamp: timestamp,
          vitals: data,
        ));
      }
      
      if (heartRate > 120) {
        vitalAlerts.add(Alert(
          id: 'hr_high_${timestamp.millisecondsSinceEpoch}',
          type: 'Heart Rate',
          severity: 'Critical',
          message: 'High heart rate detected: $heartRate BPM',
          timestamp: timestamp,
          vitals: data,
        ));
      } else if (heartRate < 50) {
        vitalAlerts.add(Alert(
          id: 'hr_low_${timestamp.millisecondsSinceEpoch}',
          type: 'Heart Rate',
          severity: 'Caution',
          message: 'Low heart rate detected: $heartRate BPM',
          timestamp: timestamp,
          vitals: data,
        ));
      }
      
      if (spO2 < 90) {
        vitalAlerts.add(Alert(
          id: 'spo2_critical_${timestamp.millisecondsSinceEpoch}',
          type: 'SPO2',
          severity: 'Critical',
          message: 'Critical SpO2 level: $spO2%',
          timestamp: timestamp,
          vitals: data,
        ));
      } else if (spO2 < 95) {
        vitalAlerts.add(Alert(
          id: 'spo2_low_${timestamp.millisecondsSinceEpoch}',
          type: 'SPO2',
          severity: 'Caution',
          message: 'Low SpO2 level: $spO2%',
          timestamp: timestamp,
          vitals: data,
        ));
      }
    }
    
    // Limit to recent vital alerts to avoid overwhelming
    vitalAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    alerts.addAll(vitalAlerts.take(20));
  }

  void _generateVitalSignAlerts() {
    // Add some normal readings as well
    final now = DateTime.now();
    alerts.add(Alert(
      id: 'normal_${now.millisecondsSinceEpoch}',
      type: 'System',
      severity: 'Normal',
      message: 'All vital signs within normal range',
      timestamp: now.subtract(const Duration(minutes: 30)),
    ));
  }

  Future<void> _refreshAlerts() async {
    await _loadAlertsFromMongoDB();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(userData: widget.userData),
        ),
      );
    }
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Alert> filteredAlerts = alerts.where((alert) {
      bool severityMatch =
          selectedSeverity == "All" || alert.severity == selectedSeverity;
      bool typeMatch = selectedType == "All" || alert.type == selectedType;
      bool dateMatch = _filterByDate(alert.timestamp);
      return severityMatch && typeMatch && dateMatch;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // Gradient Header with Logo + Filters
          Container(
            width: double.infinity,
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
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        "assets/alwaysontracklogowhite.png",
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _refreshAlerts,
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            tooltip: "Refresh Alerts",
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${filteredAlerts.length} alerts",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Alert Feed",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Dropdowns
                  Row(
                    children: [
                      _buildDropdown(
                        value: selectedSeverity,
                        items: ["All", "Normal", "Caution", "Critical"],
                        onChanged: (value) {
                          setState(() => selectedSeverity = value!);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildDropdown(
                        value: selectedType,
                        items: [
                          "All",
                          "SPO2",
                          "Temperature",
                          "Heart Rate",
                          "System"
                        ],
                        onChanged: (value) {
                          setState(() => selectedType = value!);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildDropdown(
                        value: selectedDateFilter,
                        items: ["Today", "Yesterday", "This Week", "Choose Date"],
                        onChanged: (value) async {
                          if (value == "Choose Date") {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                selectedDateFilter = value!;
                                customDate = pickedDate;
                              });
                            }
                          } else {
                            setState(() {
                              selectedDateFilter = value!;
                              customDate = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  if (selectedDateFilter == "Choose Date" && customDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat("MMM dd, yyyy").format(customDate!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Loading/Error/Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage!,
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshAlerts,
                              child: const Text("Retry"),
                            ),
                          ],
                        ),
                      )
                    : filteredAlerts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off, 
                                     size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                const Text(
                                  "No alerts match your filters",
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedSeverity = "All";
                                      selectedType = "All";
                                      selectedDateFilter = "Today";
                                    });
                                  },
                                  child: const Text("Clear Filters"),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshAlerts,
                            child: ListView.builder(
                              itemCount: filteredAlerts.length,
                              itemBuilder: (context, index) {
                                Alert alert = filteredAlerts[index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getSeverityColor(alert.severity)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getSeverityColor(alert.severity)
                                          .withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: _getSeverityIcon(alert.severity, type: alert.type),
                                    title: Text(
                                      "${alert.severity}: ${alert.type}",
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(alert.message),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat("MMM dd, yyyy • hh:mm a").format(alert.timestamp),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (alert.vitals != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            "T: ${alert.vitals!['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C | "
                                            "HR: ${alert.vitals!['heartRate'] ?? 'N/A'} | "
                                            "SpO2: ${alert.vitals!['spO2'] ?? 'N/A'}%",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[700],
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: alert.resolved
                                        ? Icon(Icons.check_circle, color: Colors.green[600], size: 20)
                                        : null,
                                    onTap: () => _showAlertDetails(alert),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),

      // Bottom Navigation
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

  void _showAlertDetails(Alert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${alert.type} Alert"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("Severity", alert.severity),
              _buildDetailRow("Time", DateFormat("MMM dd, yyyy • hh:mm:ss a").format(alert.timestamp)),
              _buildDetailRow("Message", alert.message),
              if (alert.vitals != null) ...[
                const SizedBox(height: 12),
                const Text(
                  "Vital Signs:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDetailRow("Temperature", "${alert.vitals!['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C"),
                _buildDetailRow("Heart Rate", "${alert.vitals!['heartRate'] ?? 'N/A'} BPM"),
                _buildDetailRow("SpO2", "${alert.vitals!['spO2'] ?? 'N/A'}%"),
                _buildDetailRow("Humidity", "${alert.vitals!['humidity']?.toStringAsFixed(1) ?? 'N/A'}%"),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _getSeverityIcon(String severity, {String? type}) {
    Color iconColor = _getSeverityColor(severity);
    
    if (type == "Fall Detect") {
      return Icon(Icons.person_off, color: iconColor, size: 30);
    }
    
    switch (type) {
      case "Temperature":
        return Icon(Icons.thermostat, color: iconColor, size: 30);
      case "Heart Rate":
        return Icon(Icons.favorite, color: iconColor, size: 30);
      case "SPO2":
        return Icon(Icons.air, color: iconColor, size: 30);
      case "System":
        return Icon(Icons.info, color: iconColor, size: 30);
      default:
        switch (severity) {
          case "Critical":
            return const Icon(Icons.error, color: Colors.red, size: 30);
          case "Caution":
            return const Icon(Icons.warning, color: Colors.orange, size: 30);
          case "Normal":
            return const Icon(Icons.check_circle, color: Colors.green, size: 30);
          default:
            return const Icon(Icons.info, color: Colors.grey, size: 30);
        }
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case "Critical":
        return Colors.red;
      case "Caution":
        return Colors.orange;
      case "Normal":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  bool _filterByDate(DateTime timestamp) {
    final now = DateTime.now();
    switch (selectedDateFilter) {
      case "Today":
        return timestamp.year == now.year &&
            timestamp.month == now.month &&
            timestamp.day == now.day;
      case "Yesterday":
        final yesterday = now.subtract(const Duration(days: 1));
        return timestamp.year == yesterday.year &&
            timestamp.month == yesterday.month &&
            timestamp.day == yesterday.day;
      case "This Week":
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return timestamp.isAfter(startOfWeek);
      case "Choose Date":
        if (customDate == null) return true;
        return timestamp.year == customDate!.year &&
            timestamp.month == customDate!.month &&
            timestamp.day == customDate!.day;
      default:
        return true;
    }
  }
}