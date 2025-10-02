import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import 'profile_page.dart';
import 'alert_feed_page.dart';
import 'track_ai_page.dart';
import 'dashboard_screen.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const SettingsPage({Key? key, required this.userData}) : super(key: key);
  
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isDarkMode = false;
  int _selectedIndex = 4;
  
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

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrackAIPage(userData: widget.userData),
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AlertFeedPage(userData: widget.userData),
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(userData: widget.userData),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(userData: widget.userData),
          ),
        );
        break;
      case 4:
        break;
    }
  }

  void _navigateToFontSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FontSettingsPage()),
    );
  }

  void _navigateToLanguageSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LanguageSettingsPage()),
    );
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      isDarkMode = value;
    });
  }

  Future<void> _loadAlertPreferences() async {
    try {
      String userId = "user123";
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

  Future<void> _saveAlertPreferences() async {
    try {
      String userId = "user123";
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/alert-preferences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'preferences': alertPreferences,
        }),
      );
      if (response.statusCode == 200) {
        final languageService = Provider.of<LanguageService>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageService.translate(
            'Alert preferences saved successfully',
            'Matagumpay na na-save ang mga kagustuhan sa alerto'
          ))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving preferences: $e')),
      );
    }
  }

  void _showAlertChannelsDialog() {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final translations = AppTranslations(languageService);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(translations.preferredAlertChannels),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text(languageService.translate('Push Notifications', 'Push Notifications')),
                      subtitle: Text(languageService.translate(
                        'Instant alerts on your device',
                        'Instant na alerto sa iyong device'
                      )),
                      value: alertPreferences['channels']['push_notifications'],
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setDialogState(() {
                          alertPreferences['channels']['push_notifications'] = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text(languageService.translate('SMS Messages', 'SMS Messages')),
                      subtitle: Text(languageService.translate(
                        'Text messages to your phone',
                        'Text messages sa iyong telepono'
                      )),
                      value: alertPreferences['channels']['sms'],
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setDialogState(() {
                          alertPreferences['channels']['sms'] = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text(languageService.translate('Email Alerts', 'Email Alerts')),
                      subtitle: Text(languageService.translate(
                        'Email notifications',
                        'Email notifications'
                      )),
                      value: alertPreferences['channels']['email'],
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setDialogState(() {
                          alertPreferences['channels']['email'] = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text(languageService.translate('Phone Call', 'Tawag sa Telepono')),
                      subtitle: Text(languageService.translate(
                        'Automated voice calls for critical alerts',
                        'Automated na tawag para sa kritikal na alerto'
                      )),
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
                  child: Text(translations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    _saveAlertPreferences();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(translations.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQuietHoursDialog() {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final translations = AppTranslations(languageService);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(translations.quietHoursSettings),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text(languageService.translate('Enable Quiet Hours', 'I-enable ang Quiet Hours')),
                      subtitle: Text(languageService.translate(
                        'Reduce non-critical alerts during specified hours',
                        'Bawasan ang non-critical alerts sa tinukoy na oras'
                      )),
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
                        title: Text(languageService.translate('Start Time', 'Oras ng Simula')),
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
                        title: Text(languageService.translate('End Time', 'Oras ng Pagtatapos')),
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
                        title: Text(languageService.translate('Emergency Override', 'Emergency Override')),
                        subtitle: Text(languageService.translate(
                          'Allow critical alerts during quiet hours',
                          'Pahintulutan ang kritikal na alerto sa quiet hours'
                        )),
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
                  child: Text(translations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    _saveAlertPreferences();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(translations.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEmergencyContactsDialog() {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final translations = AppTranslations(languageService);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(translations.emergencyContactList),
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
                      label: Text(languageService.translate('Add Contact', 'Magdagdag ng Contact')),
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
                  child: Text(translations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    _saveAlertPreferences();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(translations.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddContactDialog(Function setParentState) {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(languageService.translate('Add Emergency Contact', 'Magdagdag ng Emergency Contact')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: languageService.translate('Full Name', 'Buong Pangalan'),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: languageService.translate('Phone Number', 'Numero ng Telepono'),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: relationshipController,
                decoration: InputDecoration(
                  labelText: languageService.translate(
                    'Relationship (e.g., Spouse, Doctor)',
                    'Relasyon (hal., Asawa, Doktor)'
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageService.translate('Cancel', 'Kanselahin')),
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
              child: Text(languageService.translate('Add', 'Idagdag')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final translations = AppTranslations(languageService);
    
    return Scaffold(
      body: Column(
        children: [
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
                  Center(
                    child: Text(
                      translations.settings,
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

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(translations.alertPreferences),
                  _buildAlertPreferenceTile(
                    translations.preferredAlertChannels, 
                    Icons.notifications, 
                    _getChannelSummary(),
                    _showAlertChannelsDialog
                  ),
                  _buildAlertPreferenceTile(
                    translations.quietHoursSettings, 
                    Icons.access_time, 
                    alertPreferences['quiet_hours']['enabled'] 
                        ? "${alertPreferences['quiet_hours']['start_time']} - ${alertPreferences['quiet_hours']['end_time']}"
                        : languageService.translate("Disabled", "Naka-disable"),
                    _showQuietHoursDialog
                  ),
                  _buildAlertPreferenceTile(
                    translations.emergencyContactList, 
                    Icons.contacts, 
                    "${alertPreferences['emergency_contacts'].length} ${languageService.translate('contacts', 'mga contact')}",
                    _showEmergencyContactsDialog
                  ),

                  _buildSectionTitle(translations.appearance),
                  SwitchListTile(
                    value: isDarkMode,
                    onChanged: _toggleDarkMode,
                    title: Text(translations.lightDarkMode),
                    activeColor: Colors.redAccent,
                  ),
                  _buildListTile(translations.fontSizeAdjustment, Icons.format_size, _navigateToFontSettings),
                  _buildListTile(translations.languageSelection, Icons.language, _navigateToLanguageSettings),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.black,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: translations.trackAI,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: translations.alert,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: translations.dashboard,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: translations.profile,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: translations.settings,
          ),
        ],
      ),
    );
  }

  String _getChannelSummary() {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    List<String> enabled = [];
    if (alertPreferences['channels']['push_notifications']) enabled.add('Push');
    if (alertPreferences['channels']['sms']) enabled.add('SMS');
    if (alertPreferences['channels']['email']) enabled.add('Email');
    if (alertPreferences['channels']['phone_call']) enabled.add(languageService.translate('Call', 'Tawag'));
    
    return enabled.isNotEmpty ? enabled.join(', ') : languageService.translate('None selected', 'Walang napili');
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 0, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

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
          final languageService = Provider.of<LanguageService>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$title - ${languageService.translate('Coming Soon', 'Malapit Na')}"),
              backgroundColor: Colors.orange,
            ),
          );
        },
      ),
    );
  }

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

// Font Settings Page
class FontSettingsPage extends StatefulWidget {
  @override
  _FontSettingsPageState createState() => _FontSettingsPageState();
}

class _FontSettingsPageState extends State<FontSettingsPage> {
  double fontSize = 16.0;
  String selectedFontSize = 'Medium';

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(languageService.translate('Font Settings', 'Setting ng Font')),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageService.translate('Font Size Settings', 'Setting ng Laki ng Font'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              languageService.translate('Preview text with current font size', 'Preview ng text sa kasalukuyang laki ng font'),
              style: TextStyle(fontSize: fontSize),
            ),
            SizedBox(height: 24),
            Text(
              languageService.translate('Select Font Size:', 'Pumili ng Laki ng Font:'),
              style: TextStyle(fontWeight: FontWeight.bold)
            ),
            RadioListTile<String>(
              title: Text(languageService.translate('Small', 'Maliit'), style: TextStyle(fontSize: 14)),
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
              title: Text(languageService.translate('Medium', 'Katamtaman'), style: TextStyle(fontSize: 16)),
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
              title: Text(languageService.translate('Large', 'Malaki'), style: TextStyle(fontSize: 18)),
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
                  SnackBar(content: Text(languageService.translate(
                    'Font size saved: $selectedFontSize',
                    'Na-save ang laki ng font: $selectedFontSize'
                  ))),
                );
                Navigator.pop(context);
              },
              child: Text(languageService.translate('Save Font Settings', 'I-save ang Setting ng Font')),
            ),
          ],
        ),
      ),
    );
  }
}

// Language Settings Page
class LanguageSettingsPage extends StatefulWidget {
  @override
  _LanguageSettingsPageState createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String selectedLanguage = 'English';
  
  final List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'fil', 'name': 'Filipino'},
  ];

  @override
  void initState() {
    super.initState();
    final languageService = Provider.of<LanguageService>(context, listen: false);
    selectedLanguage = languageService.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final translations = AppTranslations(languageService);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(translations.languageSelection),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translations.selectLanguage,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  return Card(
                    elevation: selectedLanguage == language['name'] ? 4 : 1,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selectedLanguage == language['name'] 
                            ? Colors.redAccent 
                            : Colors.grey.shade300,
                        width: selectedLanguage == language['name'] ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      title: Row(
                        children: [
                          Text(
                            language['name']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: selectedLanguage == language['name'] 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                          SizedBox(width: 8),
                          if (language['code'] == 'en')
                            Text('🇬🇧', style: TextStyle(fontSize: 20)),
                          if (language['code'] == 'fil')
                            Text('🇵🇭', style: TextStyle(fontSize: 20)),
                        ],
                      ),
                      subtitle: Text(
                        language['code'] == 'en' 
                            ? 'English (Default)' 
                            : 'Wikang Filipino',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: language['name']!,
                      groupValue: selectedLanguage,
                      onChanged: (value) {
                        setState(() {
                          selectedLanguage = value!;
                        });
                      },
                      activeColor: Colors.redAccent,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      translations.languageChangeInfo,
                      style: TextStyle(color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await languageService.setLanguage(selectedLanguage);
                  
                  if (mounted) {
                    final trans = AppTranslations(languageService);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${trans.languageChangedTo} $selectedLanguage'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(translations.saveLanguageSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}