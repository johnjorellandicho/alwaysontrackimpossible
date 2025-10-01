import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_page.dart';
import 'alert_feed_page.dart';
import 'track_ai_page.dart';
import 'dashboard_screen.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData; // Add this parameter
  
  const SettingsPage({Key? key, required this.userData}) : super(key: key);
  
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isDarkMode = false;
  int _selectedIndex = 4; // Index for Settings tab
  
  // Alert Preferences State
  Map<String, dynamic> alertPreferences = {
    'channels': {
      'push_notifications': true,
      'sms': true,
      'email': true,
      'phone_call': false,
    },
    'quiet_hours': {
      'enabled': false,
      'start_time': '22:00',
      'end_time': '07:00',
      'emergency_override': true,
    },
    'alert_types': {
      'critical_vitals': true,
      'fall_detection': true,
      'device_disconnection': true,
      'low_battery': true,
      'medication_reminder': false,
    },
    'emergency_contacts': [],
    'escalation': {
      'enabled': true,
      'delay_minutes': 5,
    }
  };

  @override
  void initState() {
    super.initState();
    _loadAlertPreferences();
  }

  // Navigation handler for bottom navigation bar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/trackai');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/alert');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
      case 4:
        // Already on Settings
        break;
    }
  }

  // Navigation methods for different settings sections
  void _navigateToDataExport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DataExportPage(),
      ),
    );
  }

  void _navigateToDeviceSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceSettingsPage(),
      ),
    );
  }

  void _navigateToFontSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FontSettingsPage(),
      ),
    );
  }

  void _navigateToLanguageSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LanguageSettingsPage(),
      ),
    );
  }

  // Appearance toggle function
  void _toggleDarkMode(bool value) {
    setState(() {
      isDarkMode = value;
    });

    // Optional: implement global theme logic here
    if (isDarkMode) {
      print("Dark Mode Enabled");
    } else {
      print("Light Mode Enabled");
    }
  }

  // Load alert preferences from backend
  Future<void> _loadAlertPreferences() async {
    try {
      // Replace with actual user ID
      String userId = "user123"; // Get from authentication
      
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/alert-preferences/$userId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          alertPreferences = json.decode(response.body);
        });
      }
    } catch (e) {
      print('Error loading alert preferences: $e');
    }
  }

  // Save alert preferences to backend
  Future<void> _saveAlertPreferences() async {
    try {
      String userId = "user123"; // Get from authentication
      
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/alert-preferences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'preferences': alertPreferences,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alert preferences saved successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving preferences: $e')),
      );
    }
  }

  // Show Alert Channels Dialog
  void _showAlertChannelsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Preferred Alert Channels'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text('Push Notifications'),
                      subtitle: Text('Instant alerts on your device'),
                      value: alertPreferences['channels']['push_notifications'],
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setDialogState(() {
                          alertPreferences['channels']['push_notifications'] = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('SMS Messages'),
                      subtitle: Text('Text messages to your phone'),
                      value: alertPreferences['channels']['sms'],
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setDialogState(() {
                          alertPreferences['channels']['sms'] = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('Email Alerts'),
                      subtitle: Text('Email notifications'),
                      value: alertPreferences['channels']['email'],
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setDialogState(() {
                          alertPreferences['channels']['email'] = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('Phone Call'),
                      subtitle: Text('Automated voice calls for critical alerts'),
                      value: alertPreferences['channels']['phone_call'],
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setDialogState(() {
                          alertPreferences['channels']['phone_call'] = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Update main state
                    _saveAlertPreferences();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show Quiet Hours Dialog
  void _showQuietHoursDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Quiet Hours Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text('Enable Quiet Hours'),
                      subtitle: Text('Reduce non-critical alerts during specified hours'),
                      value: alertPreferences['quiet_hours']['enabled'],
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setDialogState(() {
                          alertPreferences['quiet_hours']['enabled'] = value;
                        });
                      },
                    ),
                    if (alertPreferences['quiet_hours']['enabled']) ...[
                      ListTile(
                        leading: Icon(Icons.bedtime, color: Colors.redAccent),
                        title: Text('Start Time'),
                        subtitle: Text(alertPreferences['quiet_hours']['start_time']),
                        onTap: () async {
                          TimeOfDay? time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: int.parse(alertPreferences['quiet_hours']['start_time'].split(':')[0]),
                              minute: int.parse(alertPreferences['quiet_hours']['start_time'].split(':')[1]),
                            ),
                          );
                          if (time != null) {
                            setDialogState(() {
                              alertPreferences['quiet_hours']['start_time'] = 
                                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.wb_sunny, color: Colors.redAccent),
                        title: Text('End Time'),
                        subtitle: Text(alertPreferences['quiet_hours']['end_time']),
                        onTap: () async {
                          TimeOfDay? time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: int.parse(alertPreferences['quiet_hours']['end_time'].split(':')[0]),
                              minute: int.parse(alertPreferences['quiet_hours']['end_time'].split(':')[1]),
                            ),
                          );
                          if (time != null) {
                            setDialogState(() {
                              alertPreferences['quiet_hours']['end_time'] = 
                                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                      SwitchListTile(
                        title: Text('Emergency Override'),
                        subtitle: Text('Allow critical alerts during quiet hours'),
                        value: alertPreferences['quiet_hours']['emergency_override'],
                        activeColor: Colors.redAccent,
                        onChanged: (value) {
                          setDialogState(() {
                            alertPreferences['quiet_hours']['emergency_override'] = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Update main state
                    _saveAlertPreferences();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show Emergency Contacts Dialog
  void _showEmergencyContactsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Emergency Contact List'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: alertPreferences['emergency_contacts'].length,
                        itemBuilder: (context, index) {
                          final contact = alertPreferences['emergency_contacts'][index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                child: Text(contact['name'][0].toUpperCase()),
                              ),
                              title: Text(contact['name']),
                              subtitle: Text('${contact['phone']} - ${contact['relationship']}'),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    alertPreferences['emergency_contacts'].removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddContactDialog(setDialogState),
                      icon: Icon(Icons.add),
                      label: Text('Add Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Update main state
                    _saveAlertPreferences();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show Add Contact Dialog
  void _showAddContactDialog(Function setParentState) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Emergency Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: relationshipController,
                decoration: InputDecoration(
                  labelText: 'Relationship (e.g., Spouse, Doctor)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                  setParentState(() {
                    alertPreferences['emergency_contacts'].add({
                      'name': nameController.text,
                      'phone': phoneController.text,
                      'relationship': relationshipController.text.isNotEmpty 
                          ? relationshipController.text 
                          : 'Contact',
                      'priority': alertPreferences['emergency_contacts'].length + 1,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header with gradient background
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
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.asset(
                        "assets/alwaysontracklogowhite.png",
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      "Settings",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Settings content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Permissions"),
                  _buildListTile("Data Export & Download", Icons.download, _navigateToDataExport),

                  _buildSectionTitle("Device Settings"),
                  _buildListTile("Pair/Remove Device", Icons.devices, _navigateToDeviceSettings),

                  _buildSectionTitle("Alert Preferences"),
                  _buildAlertPreferenceTile(
                    "Preferred Alert Channels", 
                    Icons.notifications, 
                    _getChannelSummary(),
                    _showAlertChannelsDialog
                  ),
                  _buildAlertPreferenceTile(
                    "Quiet Hours Settings", 
                    Icons.access_time, 
                    alertPreferences['quiet_hours']['enabled'] 
                        ? "${alertPreferences['quiet_hours']['start_time']} - ${alertPreferences['quiet_hours']['end_time']}"
                        : "Disabled",
                    _showQuietHoursDialog
                  ),
                  _buildAlertPreferenceTile(
                    "Emergency Contact List", 
                    Icons.contacts, 
                    "${alertPreferences['emergency_contacts'].length} contacts",
                    _showEmergencyContactsDialog
                  ),

                  _buildSectionTitle("Appearance"),
                  SwitchListTile(
                    value: isDarkMode,
                    onChanged: _toggleDarkMode,
                    title: const Text("Light/Dark Mode Toggle"),
                    activeColor: Colors.redAccent,
                  ),
                  _buildListTile("Font size adjustment (Small / Medium / Large)", Icons.format_size, _navigateToFontSettings),
                  _buildListTile("Language selection", Icons.language, _navigateToLanguageSettings),
                ],
              ),
            ),
          ),
        ],
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

  // Get summary of enabled channels
  String _getChannelSummary() {
    List<String> enabled = [];
    if (alertPreferences['channels']['push_notifications']) enabled.add('Push');
    if (alertPreferences['channels']['sms']) enabled.add('SMS');
    if (alertPreferences['channels']['email']) enabled.add('Email');
    if (alertPreferences['channels']['phone_call']) enabled.add('Call');
    
    return enabled.isNotEmpty ? enabled.join(', ') : 'None selected';
  }

  // Section Title Widget
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 0, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Settings List Item Widget with Navigation
  Widget _buildListTile(String title, IconData icon, [VoidCallback? onTap]) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: Colors.redAccent),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap ?? () {
          // Default fallback - show work in progress
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$title - Coming Soon"),
              backgroundColor: Colors.orange,
            ),
          );
        },
      ),
    );
  }

  // Alert Preference Tile with subtitle
  Widget _buildAlertPreferenceTile(String title, IconData icon, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: Colors.redAccent),
        title: Text(title),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// Placeholder pages for different settings sections
class DataExportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Export & Download'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Your Health Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(Icons.file_download, color: Colors.green),
                title: Text('Export as CSV'),
                subtitle: Text('Download your vital signs data as CSV file'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('CSV export started...')),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('Export as PDF Report'),
                subtitle: Text('Generate comprehensive health report'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF report generation started...')),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.cloud_download, color: Colors.blue),
                title: Text('Download Raw Data'),
                subtitle: Text('Download all sensor readings in JSON format'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Raw data download started...')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceSettingsPage extends StatefulWidget {
  @override
  _DeviceSettingsPageState createState() => _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends State<DeviceSettingsPage> {
  bool isDevicePaired = true;
  String deviceName = "Arduino R4 WiFi";
  String deviceIP = "192.168.68.118";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device Settings'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connected Devices',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.devices,
                  color: isDevicePaired ? Colors.green : Colors.grey,
                ),
                title: Text(deviceName),
                subtitle: Text('IP: $deviceIP'),
                trailing: isDevicePaired 
                    ? Icon(Icons.check_circle, color: Colors.green)
                    : Icon(Icons.error, color: Colors.red),
              ),
            ),
            SizedBox(height: 16),
            if (isDevicePaired) ...[
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isDevicePaired = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Device unpaired successfully')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Unpair Device', style: TextStyle(color: Colors.white)),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isDevicePaired = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Device paired successfully')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('Pair Device', style: TextStyle(color: Colors.white)),
              ),
            ],
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Scanning for devices...')),
                );
              },
              child: Text('Scan for New Devices'),
            ),
          ],
        ),
      ),
    );
  }
}

class FontSettingsPage extends StatefulWidget {
  @override
  _FontSettingsPageState createState() => _FontSettingsPageState();
}

class _FontSettingsPageState extends State<FontSettingsPage> {
  double fontSize = 16.0;
  String selectedFontSize = 'Medium';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Font Settings'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Font Size Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Preview text with current font size',
              style: TextStyle(fontSize: fontSize),
            ),
            SizedBox(height: 24),
            Text('Select Font Size:', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              title: Text('Small', style: TextStyle(fontSize: 14)),
              value: 'Small',
              groupValue: selectedFontSize,
              onChanged: (value) {
                setState(() {
                  selectedFontSize = value!;
                  fontSize = 14.0;
                });
              },
            ),
            RadioListTile<String>(
              title: Text('Medium', style: TextStyle(fontSize: 16)),
              value: 'Medium',
              groupValue: selectedFontSize,
              onChanged: (value) {
                setState(() {
                  selectedFontSize = value!;
                  fontSize = 16.0;
                });
              },
            ),
            RadioListTile<String>(
              title: Text('Large', style: TextStyle(fontSize: 18)),
              value: 'Large',
              groupValue: selectedFontSize,
              onChanged: (value) {
                setState(() {
                  selectedFontSize = value!;
                  fontSize = 18.0;
                });
              },
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Font size saved: $selectedFontSize')),
                );
                Navigator.pop(context);
              },
              child: Text('Save Font Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageSettingsPage extends StatefulWidget {
  @override
  _LanguageSettingsPageState createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String selectedLanguage = 'English';
  
  final List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'it', 'name': 'Italian'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'zh', 'name': 'Chinese'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'ko', 'name': 'Korean'},
    {'code': 'ar', 'name': 'Arabic'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Language Settings'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Language',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  return RadioListTile<String>(
                    title: Text(language['name']!),
                    value: language['name']!,
                    groupValue: selectedLanguage,
                    onChanged: (value) {
                      setState(() {
                        selectedLanguage = value!;
                      });
                    },
                    activeColor: Colors.redAccent,
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Language changes will take effect after restarting the app.',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Language changed to $selectedLanguage'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Save Language Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
