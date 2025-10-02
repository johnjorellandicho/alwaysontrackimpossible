import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  String _currentLanguage = 'English';

  String get currentLanguage => _currentLanguage;
  bool get isFilipino => _currentLanguage == 'Filipino';

  // Initialize language from storage
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? 'English';
    notifyListeners();
  }

  // Change language and persist
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    notifyListeners();
  }

  // Translation method
  String translate(String english, String filipino) {
    return _currentLanguage == 'Filipino' ? filipino : english;
  }
}

// Translations Map - Add all your app strings here
class AppTranslations {
  final LanguageService _languageService;

  AppTranslations(this._languageService);

  String get hello => _languageService.translate('Hello', 'Kumusta');
  String get dashboard => _languageService.translate('Dashboard', 'Dashboard');
  String get settings => _languageService.translate('Settings', 'Mga Setting');
  String get profile => _languageService.translate('Profile', 'Profile');
  String get trackAI => _languageService.translate('TrackAI', 'TrackAI');
  String get alert => _languageService.translate('Alert', 'Alerto');
  
  // Dashboard translations
  String get liveHealthData => _languageService.translate('Live Health Data', 'Live na Datos ng Kalusugan');
  String get temperature => _languageService.translate('Temperature', 'Temperatura');
  String get heartRate => _languageService.translate('Heart Rate', 'Tibok ng Puso');
  String get spO2 => _languageService.translate('SpO2', 'SpO2');
  String get humidity => _languageService.translate('Humidity', 'Halumigmig');
  String get normal => _languageService.translate('Normal', 'Normal');
  String get cold => _languageService.translate('Cold', 'Malamig');
  String get warm => _languageService.translate('Warm', 'Mainit');
  String get hot => _languageService.translate('Hot', 'Napakainit');
  String get low => _languageService.translate('Low', 'Mababa');
  String get high => _languageService.translate('High', 'Mataas');
  String get environment => _languageService.translate('Environment', 'Kapaligiran');
  
  // Health Analytics
  String get healthAnalytics => _languageService.translate('Health Analytics', 'Pagsusuri ng Kalusugan');
  String get today => _languageService.translate('Today', 'Ngayon');
  String get week => _languageService.translate('Week', 'Linggo');
  String get month => _languageService.translate('Month', 'Buwan');
  String get readings => _languageService.translate('Readings', 'Mga Pagbasa');
  String get average => _languageService.translate('Avg', 'Ave');
  String get min => _languageService.translate('Min', 'Min');
  String get max => _languageService.translate('Max', 'Max');
  
  // Quick Actions
  String get quickActions => _languageService.translate('Quick Actions', 'Mabilis na Aksyon');
  String get emergencyAlert => _languageService.translate('Emergency Alert', 'Emergency na Alerto');
  String get viewHistory => _languageService.translate('View History', 'Tingnan ang Kasaysayan');
  
  // Settings Page
  String get permissions => _languageService.translate('Permissions', 'Mga Pahintulot');
  String get dataExport => _languageService.translate('Data Export & Download', 'Pag-export at Pag-download ng Datos');
  String get deviceSettings => _languageService.translate('Device Settings', 'Mga Setting ng Device');
  String get pairRemoveDevice => _languageService.translate('Pair/Remove Device', 'Ipares/Alisin ang Device');
  String get alertPreferences => _languageService.translate('Alert Preferences', 'Mga Kagustuhan sa Alerto');
  String get preferredAlertChannels => _languageService.translate('Preferred Alert Channels', 'Ginustong Channel ng Alerto');
  String get quietHoursSettings => _languageService.translate('Quiet Hours Settings', 'Setting ng Quiet Hours');
  String get emergencyContactList => _languageService.translate('Emergency Contact List', 'Listahan ng Emergency Contact');
  String get appearance => _languageService.translate('Appearance', 'Hitsura');
  String get lightDarkMode => _languageService.translate('Light/Dark Mode Toggle', 'Toggle ng Light/Dark Mode');
  String get fontSizeAdjustment => _languageService.translate('Font size adjustment (Small / Medium / Large)', 'Pag-adjust ng laki ng font (Maliit / Katamtaman / Malaki)');
  String get languageSelection => _languageService.translate('Language selection', 'Pagpili ng Wika');
  
  // Language Settings Page
  String get selectLanguage => _languageService.translate('Select Language', 'Pumili ng Wika');
  String get languageChangeInfo => _languageService.translate(
    'Language changes will take effect immediately.',
    'Ang pagbabago ng wika ay magkakabisa kaagad.'
  );
  String get saveLanguageSettings => _languageService.translate('Save Language Settings', 'I-save ang Setting ng Wika');
  String get languageChangedTo => _languageService.translate('Language changed to', 'Binago ang wika sa');
  
  // Common buttons
  String get save => _languageService.translate('Save', 'I-save');
  String get cancel => _languageService.translate('Cancel', 'Kanselahin');
  String get close => _languageService.translate('Close', 'Isara');
  String get refresh => _languageService.translate('Refresh', 'I-refresh');
  String get logout => _languageService.translate('Logout', 'Mag-logout');
  
  // Status messages
  String get connecting => _languageService.translate('Connecting...', 'Kumukonekta...');
  String get connectionError => _languageService.translate('Connection Error', 'Error sa Koneksyon');
  String get lastUpdate => _languageService.translate('Last Update', 'Huling Update');
  String get never => _languageService.translate('Never', 'Hindi pa');
}
