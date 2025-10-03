// server.js - Complete Node.js Backend for Vital Signs Monitoring with Fall Detection and Alert Preferences
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const moment = require('moment-timezone');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
});
app.use(limiter);

// MongoDB Connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/vitalsigns';

mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('✅ Connected to MongoDB'))
.catch(err => console.error('❌ MongoDB connection error:', err));

// Sensor Data Schema
const sensorDataSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  userEmail: { type: String, required: true },
  deviceType: { type: String, default: 'Arduino_R4_WiFi_ESP32S3' },
  monitoringRole: { type: String, enum: ['patient', 'family'], default: 'patient' },
  patientInfo: {
    fullName: String,
    relationship: String,
    medicalConditions: String
  },
  sensorData: {
    timestamp: { type: Date, required: true },
    temperature: { type: Number, required: true },
    humidity: { type: Number, required: true },
    heartRate: { type: Number, required: true },
    spO2: { type: Number, required: true }
  },
  createdAt: { type: Date, default: Date.now }
});

// Emergency Alert Schema
const emergencyAlertSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  userEmail: { type: String, required: true },
  alertType: { type: String, required: true },
  timestamp: { type: Date, required: true },
  patientInfo: {
    fullName: String,
    relationship: String,
    medicalConditions: String
  },
  currentVitals: {
    temperature: Number,
    humidity: Number,
    heartRate: Number,
    spO2: Number
  },
  location: String,
  resolved: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

// Fall Detection Alert Schema
const fallDetectionSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  userEmail: { type: String, required: true },
  alertType: { type: String, default: 'fall_detection' },
  timestamp: { type: Date, required: true },
  location: {
    latitude: Number,
    longitude: Number,
    address: String
  },
  severity: { type: String, enum: ['Critical', 'Caution'], default: 'Critical' },
  sensorData: {
    accelerometer: {
      x: Number,
      y: Number,
      z: Number
    },
    gyroscope: {
      x: Number,
      y: Number,
      z: Number
    },
    impact_force: Number
  },
  currentVitals: {
    temperature: Number,
    humidity: Number,
    heartRate: Number,
    spO2: Number
  },
  resolved: { type: Boolean, default: false },
  response_time: Date, // When help arrived
  false_alarm: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

// Alert Preferences Schema
const alertPreferencesSchema = new mongoose.Schema({
  userId: { type: String, required: true, unique: true, index: true },
  userEmail: { type: String, required: true },
  preferences: {
    channels: {
      push_notifications: { type: Boolean, default: true },
      sms: { type: Boolean, default: true },
      email: { type: Boolean, default: true },
      phone_call: { type: Boolean, default: false }
    },
    quiet_hours: {
      enabled: { type: Boolean, default: false },
      start_time: { type: String, default: '22:00' },
      end_time: { type: String, default: '07:00' },
      emergency_override: { type: Boolean, default: true }
    },
    alert_types: {
      critical_vitals: { type: Boolean, default: true },
      fall_detection: { type: Boolean, default: true },
      device_disconnection: { type: Boolean, default: true },
      low_battery: { type: Boolean, default: true },
      medication_reminder: { type: Boolean, default: false }
    },
    emergency_contacts: [{
      name: String,
      phone: String,
      email: String,
      relationship: String,
      priority: { type: Number, default: 1 },
      enabled: { type: Boolean, default: true }
    }],
    escalation: {
      enabled: { type: Boolean, default: true },
      delay_minutes: { type: Number, default: 5 },
      max_attempts: { type: Number, default: 3 }
    },
    notification_sound: {
      enabled: { type: Boolean, default: true },
      volume: { type: Number, default: 80, min: 0, max: 100 }
    }
  },
  updatedAt: { type: Date, default: Date.now },
  createdAt: { type: Date, default: Date.now }
});

// Create Models
const SensorData = mongoose.model('SensorData', sensorDataSchema);
const EmergencyAlert = mongoose.model('EmergencyAlert', emergencyAlertSchema);
const FallDetectionAlert = mongoose.model('FallDetectionAlert', fallDetectionSchema);
const AlertPreferences = mongoose.model('AlertPreferences', alertPreferencesSchema);

// Helper Functions

// Check if current time is within quiet hours
function isQuietHours(preferences) {
  if (!preferences.quiet_hours?.enabled) return false;
  
  const now = moment().tz("Asia/Manila");
  const startTime = moment(preferences.quiet_hours.start_time, 'HH:mm').tz("Asia/Manila");
  const endTime = moment(preferences.quiet_hours.end_time, 'HH:mm').tz("Asia/Manila");
  
  // Handle overnight quiet hours (e.g., 22:00 to 07:00)
  if (startTime.isAfter(endTime)) {
    return now.isAfter(startTime) || now.isBefore(endTime);
  } else {
    return now.isBetween(startTime, endTime);
  }
}

// Check if alert should be sent based on preferences
async function shouldSendAlert(userId, alertType, severity = 'normal') {
  try {
    const preferences = await AlertPreferences.findOne({ userId });
    if (!preferences) return true; // Default to sending if no preferences
    
    const prefs = preferences.preferences;
    
    // Check if alert type is enabled
    if (!prefs.alert_types[alertType]) return false;
    
    // Check quiet hours
    if (isQuietHours(prefs)) {
      // Only allow critical/emergency alerts during quiet hours if override is enabled
      if (severity !== 'critical' && severity !== 'emergency') {
        return prefs.quiet_hours.emergency_override;
      }
    }
    
    return true;
  } catch (error) {
    console.error('Error checking alert preferences:', error);
    return true; // Default to sending on error
  }
}

// Get enabled notification channels for a user
async function getEnabledChannels(userId) {
  try {
    const preferences = await AlertPreferences.findOne({ userId });
    if (!preferences) return ['push_notifications']; // Default
    
    const channels = [];
    const channelPrefs = preferences.preferences.channels;
    
    if (channelPrefs.push_notifications) channels.push('push_notifications');
    if (channelPrefs.sms) channels.push('sms');
    if (channelPrefs.email) channels.push('email');
    if (channelPrefs.phone_call) channels.push('phone_call');
    
    return channels;
  } catch (error) {
    console.error('Error getting enabled channels:', error);
    return ['push_notifications']; // Default fallback
  }
}

// Send notification through preferred channels
async function sendNotification(userId, alertData) {
  try {
    const channels = await getEnabledChannels(userId);
    const preferences = await AlertPreferences.findOne({ userId });
    
    console.log(`📢 Sending notification to user ${userId} via channels: ${channels.join(', ')}`);
    
    for (const channel of channels) {
      switch (channel) {
        case 'push_notifications':
          console.log(`📱 Push notification sent: ${alertData.message}`);
          break;
          
        case 'sms':
          console.log(`📱 SMS sent to emergency contacts: ${alertData.message}`);
          break;
          
        case 'email':
          console.log(`📧 Email sent: ${alertData.message}`);
          break;
          
        case 'phone_call':
          console.log(`📞 Phone call initiated: ${alertData.message}`);
          break;
      }
    }
    
    // If escalation is enabled and this is a critical alert
    if (preferences?.preferences.escalation?.enabled && 
        (alertData.severity === 'critical' || alertData.severity === 'emergency')) {
      
      setTimeout(() => {
        console.log(`⏰ Escalation triggered after ${preferences.preferences.escalation.delay_minutes} minutes for user ${userId}`);
        escalateAlert(userId, alertData);
      }, preferences.preferences.escalation.delay_minutes * 60 * 1000);
    }
    
  } catch (error) {
    console.error('❌ Error sending notification:', error);
  }
}

// Escalate alert to emergency contacts
async function escalateAlert(userId, alertData) {
  try {
    const preferences = await AlertPreferences.findOne({ userId });
    if (!preferences || !preferences.preferences.emergency_contacts.length) {
      console.log(`⚠️ No emergency contacts found for escalation - user ${userId}`);
      return;
    }
    
    const contacts = preferences.preferences.emergency_contacts
      .filter(contact => contact.enabled)
      .sort((a, b) => a.priority - b.priority);
    
    console.log(`🚨 ESCALATING ALERT to ${contacts.length} emergency contacts for user ${userId}`);
    
    for (const contact of contacts) {
      console.log(`📞 Escalated alert sent to ${contact.name} (${contact.relationship}): ${contact.phone}`);
    }
    
  } catch (error) {
    console.error('❌ Error escalating alert:', error);
  }
}

// Routes

// Health Check
app.get('/', (req, res) => {
  res.json({
    message: 'Vital Signs Monitoring API with Fall Detection and Alert Preferences',
    status: 'Online',
    timestamp: moment().tz("Asia/Manila").format(),
    endpoints: [
      'GET /api/sensor-data/:userId',
      'POST /api/sensor-data',
      'POST /api/emergency-alerts',
      'GET /api/emergency-alerts/:userId',
      'POST /api/fall-detection',
      'GET /api/fall-detection/:userId',
      'PATCH /api/fall-detection/:alertId/false-alarm',
      'PATCH /api/fall-detection/:alertId/resolve',
      'GET /api/stats/:userId',
      'GET /api/alert-preferences/:userId',
      'POST /api/alert-preferences',
      'GET /api/emergency-contacts/:userId',
      'POST /api/emergency-contacts/:userId',
      'DELETE /api/emergency-contacts/:userId/:contactIndex',
      'POST /api/test-notification/:userId'
    ]
  });
});

// GET sensor data for a user
app.get('/api/sensor-data/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 20, days } = req.query;

    let query = { userId };
    
    if (days) {
      const daysAgo = new Date(Date.now() - parseInt(days) * 24 * 60 * 60 * 1000);
      query['sensorData.timestamp'] = { $gte: daysAgo };
    }

    const data = await SensorData
      .find(query)
      .sort({ 'sensorData.timestamp': -1 })
      .limit(parseInt(limit));

    const transformedData = data.map(item => ({
      timestamp: moment(item.sensorData.timestamp).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss"),
      temperature: item.sensorData.temperature,
      humidity: item.sensorData.humidity,
      heartRate: item.sensorData.heartRate,
      spO2: item.sensorData.spO2
    }));

    res.json(transformedData);
    console.log(`📊 Sent ${transformedData.length} data points for user ${userId}`);
  } catch (error) {
    console.error('❌ Error fetching sensor data:', error);
    res.status(500).json({ error: 'Failed to fetch sensor data' });
  }
});

// POST new sensor data (with alert preferences integration)
app.post('/api/sensor-data', async (req, res) => {
  try {
    const sensorData = new SensorData(req.body);
    await sensorData.save();
    
    // Check for critical conditions and auto-generate alerts
    const vitals = req.body.sensorData;
    const userId = req.body.userId;
    const userEmail = req.body.userEmail;
    
    if (vitals) {
      const temp = vitals.temperature;
      const heartRate = vitals.heartRate;
      const spO2 = vitals.spO2;
      
      // Determine alert severity and type
      let alertType = '';
      let severity = 'normal';
      let shouldAlert = false;
      
      if (temp > 39.0 || temp < 35.0) {
        alertType = 'critical_vitals';
        severity = 'critical';
        shouldAlert = true;
      } else if (temp > 38.5 || temp < 35.5) {
        alertType = 'critical_vitals';
        severity = 'warning';
        shouldAlert = true;
      }
      
      if (heartRate > 130 || heartRate < 50) {
        alertType = 'critical_vitals';
        severity = 'critical';
        shouldAlert = true;
      } else if (heartRate > 120 || heartRate < 60) {
        alertType = 'critical_vitals';
        severity = 'warning';
        shouldAlert = true;
      }
      
      if (spO2 < 88) {
        alertType = 'critical_vitals';
        severity = 'critical';
        shouldAlert = true;
      } else if (spO2 < 92) {
        alertType = 'critical_vitals';
        severity = 'warning';
        shouldAlert = true;
      }
      
      // Check preferences before sending alert
      if (shouldAlert && await shouldSendAlert(userId, alertType, severity)) {
        const criticalAlert = new EmergencyAlert({
          userId,
          userEmail,
          alertType: `auto_${alertType}`,
          timestamp: vitals.timestamp,
          currentVitals: {
            temperature: temp,
            humidity: vitals.humidity,
            heartRate,
            spO2
          },
          location: 'Auto-generated from sensor data',
          resolved: false
        });
        await criticalAlert.save();
        
        // Send notification through preferred channels
        await sendNotification(userId, {
          message: `Critical vital signs detected: Temp: ${temp}°C, HR: ${heartRate} BPM, SpO2: ${spO2}%`,
          severity,
          type: alertType,
          vitals: { temp, heartRate, spO2 }
        });
        
        console.log(`🚨 AUTO-GENERATED ${severity.toUpperCase()} ALERT for user ${userId}`);
      }
    }
    
    res.status(201).json({ 
      message: 'Sensor data saved successfully',
      id: sensorData._id 
    });
    
    console.log(`💾 Saved sensor data for user ${req.body.userId}`);
    console.log(`   Time (PH): ${moment(req.body.sensorData.timestamp).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss")}`);
    console.log(`   Temperature: ${req.body.sensorData.temperature}°C`);
    console.log(`   Humidity: ${req.body.sensorData.humidity}%`);
    console.log(`   Heart Rate: ${req.body.sensorData.heartRate} BPM`);
    console.log(`   SpO2: ${req.body.sensorData.spO2}%`);
  } catch (error) {
    console.error('❌ Error saving sensor data:', error);
    res.status(500).json({ error: 'Failed to save sensor data' });
  }
});

// POST emergency alert
app.post('/api/emergency-alerts', async (req, res) => {
  try {
    const emergencyAlert = new EmergencyAlert(req.body);
    await emergencyAlert.save();
    
    res.status(201).json({ 
      message: 'Emergency alert saved successfully',
      id: emergencyAlert._id 
    });
    
    console.log(`🚨 EMERGENCY ALERT for user ${req.body.userId}`);
    console.log(`   Type: ${req.body.alertType}`);
    console.log(`   Time (PH): ${moment(req.body.timestamp).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss")}`);
    console.log(`   Location: ${req.body.location}`);
    
  } catch (error) {
    console.error('❌ Error saving emergency alert:', error);
    res.status(500).json({ error: 'Failed to save emergency alert' });
  }
});

// GET emergency alerts for a user
app.get('/api/emergency-alerts/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 10 } = req.query;

    const alerts = await EmergencyAlert
      .find({ userId })
      .sort({ createdAt: -1 })
      .limit(parseInt(limit));

    const transformedAlerts = alerts.map(alert => ({
      ...alert._doc,
      createdAt: moment(alert.createdAt).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss"),
      timestamp: moment(alert.timestamp).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss")
    }));

    res.json(transformedAlerts);
    console.log(`🚨 Sent ${alerts.length} emergency alerts for user ${userId}`);
  } catch (error) {
    console.error('❌ Error fetching emergency alerts:', error);
    res.status(500).json({ error: 'Failed to fetch emergency alerts' });
  }
});

// POST fall detection alert (with alert preferences integration)
app.post('/api/fall-detection', async (req, res) => {
  try {
    const fallAlert = new FallDetectionAlert(req.body);
    await fallAlert.save();
    
    const userId = req.body.userId;
    
    // Check if fall detection alerts are enabled
    if (await shouldSendAlert(userId, 'fall_detection', 'critical')) {
      const emergencyAlert = new EmergencyAlert({
        userId: req.body.userId,
        userEmail: req.body.userEmail,
        alertType: 'fall_detection_emergency',
        timestamp: req.body.timestamp,
        currentVitals: req.body.currentVitals,
        location: req.body.location?.address || 'Fall detected - location unknown',
        resolved: false
      });
      await emergencyAlert.save();
      
      // Send notification through preferred channels
      await sendNotification(userId, {
        message: `FALL DETECTED! Location: ${req.body.location?.address || 'Unknown'}. Immediate assistance may be required.`,
        severity: 'emergency',
        type: 'fall_detection',
        location: req.body.location
      });
    }
    
    res.status(201).json({ 
      message: 'Fall detection alert saved successfully',
      fallId: fallAlert._id,
      notificationSent: await shouldSendAlert(userId, 'fall_detection', 'critical')
    });
    
    console.log(`🚨 FALL DETECTION ALERT for user ${userId}`);
    console.log(`   Time (PH): ${moment(req.body.timestamp).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss")}`);
    console.log(`   Location: ${req.body.location?.address || 'Unknown'}`);
    console.log(`   Impact Force: ${req.body.sensorData?.impact_force || 'N/A'}`);
    
  } catch (error) {
    console.error('❌ Error saving fall detection alert:', error);
    res.status(500).json({ error: 'Failed to save fall detection alert' });
  }
});

// GET fall detection alerts for a user
app.get('/api/fall-detection/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 10 } = req.query;

    const alerts = await FallDetectionAlert
      .find({ userId })
      .sort({ createdAt: -1 })
      .limit(parseInt(limit));

    const transformedAlerts = alerts.map(alert => ({
      ...alert._doc,
      createdAt: moment(alert.createdAt).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss"),
      timestamp: moment(alert.timestamp).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss")
    }));

    res.json(transformedAlerts);
    console.log(`🚨 Sent ${alerts.length} fall detection alerts for user ${userId}`);
  } catch (error) {
    console.error('❌ Error fetching fall detection alerts:', error);
    res.status(500).json({ error: 'Failed to fetch fall detection alerts' });
  }
});

// Mark fall alert as false alarm
app.patch('/api/fall-detection/:alertId/false-alarm', async (req, res) => {
  try {
    const { alertId } = req.params;
    
    await FallDetectionAlert.findByIdAndUpdate(alertId, {
      false_alarm: true,
      resolved: true,
      response_time: new Date()
    });
    
    res.json({ message: 'Fall alert marked as false alarm' });
    console.log(`✅ Fall alert ${alertId} marked as false alarm`);
  } catch (error) {
    console.error('❌ Error updating fall alert:', error);
    res.status(500).json({ error: 'Failed to update fall alert' });
  }
});

// Resolve fall alert (help has arrived)
app.patch('/api/fall-detection/:alertId/resolve', async (req, res) => {
  try {
    const { alertId } = req.params;
    
    await FallDetectionAlert.findByIdAndUpdate(alertId, {
      resolved: true,
      response_time: new Date()
    });
    
    res.json({ message: 'Fall alert resolved' });
    console.log(`✅ Fall alert ${alertId} resolved - help has arrived`);
  } catch (error) {
    console.error('❌ Error resolving fall alert:', error);
    res.status(500).json({ error: 'Failed to resolve fall alert' });
  }
});

// GET all alerts (emergency + fall detection) for alert feed
app.get('/api/all-alerts/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 20 } = req.query;

    const emergencyAlerts = await EmergencyAlert
      .find({ userId })
      .sort({ createdAt: -1 })
      .limit(parseInt(limit));

    const fallAlerts = await FallDetectionAlert
      .find({ userId })
      .sort({ createdAt: -1 })
      .limit(parseInt(limit));

    const allAlerts = [
      ...emergencyAlerts.map(alert => ({
        ...alert._doc,
        alertSource: 'emergency',
        createdAt: moment(alert.createdAt).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss"),
        timestamp: moment(alert.timestamp).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss")
      })),
      ...fallAlerts.map(alert => ({
        ...alert._doc,
        alertSource: 'fall_detection',
        createdAt: moment(alert.createdAt).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss"),
        timestamp: moment(alert.timestamp).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss")
      }))
    ];

    allAlerts.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    const limitedAlerts = allAlerts.slice(0, parseInt(limit));

    res.json(limitedAlerts);
    console.log(`🚨 Sent ${limitedAlerts.length} combined alerts for user ${userId}`);
  } catch (error) {
    console.error('❌ Error fetching combined alerts:', error);
    res.status(500).json({ error: 'Failed to fetch combined alerts' });
  }
});

// GET statistics for dashboard
app.get('/api/stats/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const totalRecords = await SensorData.countDocuments({ userId });
    const emergencyAlerts = await EmergencyAlert.countDocuments({ userId });
    const fallAlerts = await FallDetectionAlert.countDocuments({ userId });
    
    const latestReading = await SensorData
      .findOne({ userId })
      .sort({ 'sensorData.timestamp': -1 });
    
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recentData = await SensorData.find({
      userId,
      'sensorData.timestamp': { $gte: yesterday }
    });

    let avgTemp = 0, avgHumidity = 0, avgHeartRate = 0, avgSpO2 = 0;
    if (recentData.length > 0) {
      avgTemp = recentData.reduce((sum, item) => sum + item.sensorData.temperature, 0) / recentData.length;
      avgHumidity = recentData.reduce((sum, item) => sum + item.sensorData.humidity, 0) / recentData.length;
      avgHeartRate = recentData.reduce((sum, item) => sum + item.sensorData.heartRate, 0) / recentData.length;
      avgSpO2 = recentData.reduce((sum, item) => sum + item.sensorData.spO2, 0) / recentData.length;
    }

    res.json({
      totalRecords,
      emergencyAlerts,
      fallAlerts,
      totalAlerts: emergencyAlerts + fallAlerts,
      recentReadings: recentData.length,
      latestReading: latestReading ? {
        ...latestReading.sensorData._doc,
        timestamp: moment(latestReading.sensorData.timestamp).tz("Asia/Manila").format("YYYY-MM-DD HH:mm:ss")
      } : null,
      averages24h: {
        temperature: Math.round(avgTemp * 10) / 10,
        humidity: Math.round(avgHumidity * 10) / 10,
        heartRate: Math.round(avgHeartRate),
        spO2: Math.round(avgSpO2)
      }
    });
    
  } catch (error) {
    console.error('❌ Error fetching statistics:', error);
    res.status(500).json({ error: 'Failed to fetch statistics' });
  }
});

// Resolve emergency alert
app.patch('/api/emergency-alerts/:alertId/resolve', async (req, res) => {
  try {
    const { alertId } = req.params;
    
    await EmergencyAlert.findByIdAndUpdate(alertId, {
      resolved: true
    });
    
    res.json({ message: 'Emergency alert resolved' });
    console.log(`✅ Emergency alert ${alertId} resolved`);
  } catch (error) {
    console.error('❌ Error resolving emergency alert:', error);
    res.status(500).json({ error: 'Failed to resolve emergency alert' });
  }
});

// Get unresolved alerts count
app.get('/api/unresolved-alerts/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const unresolvedEmergency = await EmergencyAlert.countDocuments({ 
      userId, 
      resolved: false 
    });
    
    const unresolvedFalls = await FallDetectionAlert.countDocuments({ 
      userId, 
      resolved: false,
      false_alarm: false
    });
    
    res.json({
      emergency: unresolvedEmergency,
      falls: unresolvedFalls,
      total: unresolvedEmergency + unresolvedFalls
    });
    
  } catch (error) {
    console.error('❌ Error fetching unresolved alerts:', error);
    res.status(500).json({ error: 'Failed to fetch unresolved alerts' });
  }
});

// Delete old resolved alerts (cleanup endpoint)
app.delete('/api/cleanup-alerts/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { days = 30 } = req.query;
    
    const cutoffDate = new Date(Date.now() - parseInt(days) * 24 * 60 * 60 * 1000);
    
    const deletedEmergency = await EmergencyAlert.deleteMany({
      userId,
      resolved: true,
      createdAt: { $lt: cutoffDate }
    });
    
    const deletedFalls = await FallDetectionAlert.deleteMany({
      userId,
      resolved: true,
      createdAt: { $lt: cutoffDate }
    });
    
    res.json({
      message: 'Cleanup completed',
      deletedEmergencyAlerts: deletedEmergency.deletedCount,
      deletedFallAlerts: deletedFalls.deletedCount,
      totalDeleted: deletedEmergency.deletedCount + deletedFalls.deletedCount
    });
    
    console.log(`🧹 Cleanup completed for user ${userId}: ${deletedEmergency.deletedCount + deletedFalls.deletedCount} old alerts deleted`);
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    res.status(500).json({ error: 'Failed to cleanup old alerts' });
  }
});

// ===============================
// ALERT PREFERENCES ROUTES
// ===============================

// GET user's alert preferences
app.get('/api/alert-preferences/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    let preferences = await AlertPreferences.findOne({ userId });
    
    // If no preferences exist, create default ones
    if (!preferences) {
      preferences = new AlertPreferences({
        userId,
        userEmail: req.query.email || `${userId}@example.com`,
        preferences: {
          channels: {
            push_notifications: true,
            sms: true,
            email: true,
            phone_call: false
          },
          quiet_hours: {
            enabled: false,
            start_time: '22:00',
            end_time: '07:00',
            emergency_override: true
          },
          alert_types: {
            critical_vitals: true,
            fall_detection: true,
            device_disconnection: true,
            low_battery: true,
            medication_reminder: false
          },
          emergency_contacts: [],
          escalation: {
            enabled: true,
            delay_minutes: 5,
            max_attempts: 3
          }
        }
      });
      await preferences.save();
    }
    
    res.json(preferences.preferences);
    console.log(`📱 Sent alert preferences for user ${userId}`);
    
  } catch (error) {
    console.error('❌ Error fetching alert preferences:', error);
    res.status(500).json({ error: 'Failed to fetch alert preferences' });
  }
});

// POST/UPDATE user's alert preferences
app.post('/api/alert-preferences', async (req, res) => {
  try {
    const { userId, userEmail, preferences } = req.body;
    
    const alertPrefs = await AlertPreferences.findOneAndUpdate(
      { userId },
      { 
        userEmail: userEmail || `${userId}@example.com`,
        preferences,
        updatedAt: new Date()
      },
      { 
        upsert: true, 
        new: true,
        runValidators: true
      }
    );
    
    res.json({ 
      message: 'Alert preferences saved successfully',
      preferences: alertPrefs.preferences
    });
    
    console.log(`✅ Updated alert preferences for user ${userId}`);
    console.log(`   Channels: Push:${preferences.channels?.push_notifications}, SMS:${preferences.channels?.sms}, Email:${preferences.channels?.email}`);
    console.log(`   Quiet Hours: ${preferences.quiet_hours?.enabled ? 'Enabled' : 'Disabled'}`);
    console.log(`   Emergency Contacts: ${preferences.emergency_contacts?.length || 0}`);
    
  } catch (error) {
    console.error('❌ Error saving alert preferences:', error);
    res.status(500).json({ error: 'Failed to save alert preferences' });
  }
});

// GET emergency contacts for a user
app.get('/api/emergency-contacts/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const preferences = await AlertPreferences.findOne({ userId });
    
    if (!preferences) {
      return res.json([]);
    }
    
    res.json(preferences.preferences.emergency_contacts || []);
    console.log(`👥 Sent ${preferences.preferences.emergency_contacts?.length || 0} emergency contacts for user ${userId}`);
    
  } catch (error) {
    console.error('❌ Error fetching emergency contacts:', error);
    res.status(500).json({ error: 'Failed to fetch emergency contacts' });
  }
});

// POST/UPDATE emergency contact
app.post('/api/emergency-contacts/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { name, phone, email, relationship, priority } = req.body;
    
    const preferences = await AlertPreferences.findOne({ userId });
    if (!preferences) {
      return res.status(404).json({ error: 'User preferences not found' });
    }
    
    const newContact = {
      name,
      phone,
      email: email || '',
      relationship: relationship || 'Contact',
      priority: priority || (preferences.preferences.emergency_contacts.length + 1),
      enabled: true
    };
    
    preferences.preferences.emergency_contacts.push(newContact);
    preferences.updatedAt = new Date();
    await preferences.save();
    
    res.json({ 
      message: 'Emergency contact added successfully',
      contact: newContact
    });
    
    console.log(`👤 Added emergency contact for user ${userId}: ${name} (${phone})`);
    
  } catch (error) {
    console.error('❌ Error adding emergency contact:', error);
    res.status(500).json({ error: 'Failed to add emergency contact' });
  }
});

// DELETE emergency contact
app.delete('/api/emergency-contacts/:userId/:contactIndex', async (req, res) => {
  try {
    const { userId, contactIndex } = req.params;
    const index = parseInt(contactIndex);
    
    const preferences = await AlertPreferences.findOne({ userId });
    if (!preferences) {
      return res.status(404).json({ error: 'User preferences not found' });
    }
    
    if (index < 0 || index >= preferences.preferences.emergency_contacts.length) {
      return res.status(400).json({ error: 'Invalid contact index' });
    }
    
    const removedContact = preferences.preferences.emergency_contacts.splice(index, 1)[0];
    preferences.updatedAt = new Date();
    await preferences.save();
    
    res.json({ 
      message: 'Emergency contact removed successfully',
      removedContact
    });
    
    console.log(`🗑️ Removed emergency contact for user ${userId}: ${removedContact.name}`);
    
  } catch (error) {
    console.error('❌ Error removing emergency contact:', error);
    res.status(500).json({ error: 'Failed to remove emergency contact' });
  }
});

// Test notification endpoint
app.post('/api/test-notification/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { message, severity } = req.body;
    
    const testAlert = {
      message: message || 'Test notification from Always On Track',
      severity: severity || 'normal',
      timestamp: new Date(),
      type: 'test'
    };
    
    await sendNotification(userId, testAlert);
    
    res.json({ 
      message: 'Test notification sent successfully',
      channels: await getEnabledChannels(userId)
    });
    
    console.log(`🧪 Test notification sent for user ${userId}`);
    
  } catch (error) {
    console.error('❌ Error sending test notification:', error);
    res.status(500).json({ error: 'Failed to send test notification' });
  }
});

// Get notification settings summary
app.get('/api/notification-summary/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const preferences = await AlertPreferences.findOne({ userId });
    
    if (!preferences) {
      return res.json({
        channelsEnabled: 0,
        quietHours: false,
        emergencyContacts: 0,
        escalationEnabled: false
      });
    }
    
    const prefs = preferences.preferences;
    const channelsEnabled = Object.values(prefs.channels).filter(Boolean).length;
    
    res.json({
      channelsEnabled,
      quietHours: prefs.quiet_hours?.enabled || false,
      quietHoursTime: prefs.quiet_hours?.enabled ? 
        `${prefs.quiet_hours.start_time} - ${prefs.quiet_hours.end_time}` : null,
      emergencyContacts: prefs.emergency_contacts?.length || 0,
      escalationEnabled: prefs.escalation?.enabled || false,
      escalationDelay: prefs.escalation?.delay_minutes || 5
    });
    
  } catch (error) {
    console.error('❌ Error fetching notification summary:', error);
    res.status(500).json({ error: 'Failed to fetch notification summary' });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📊 API endpoints:`);
  console.log(`   GET  /api/sensor-data/:userId`);
  console.log(`   POST /api/sensor-data`);
  console.log(`   POST /api/emergency-alerts`);
  console.log(`   GET  /api/emergency-alerts/:userId`);
  console.log(`   POST /api/fall-detection`);
  console.log(`   GET  /api/fall-detection/:userId`);
  console.log(`   PATCH /api/fall-detection/:alertId/false-alarm`);
  console.log(`   PATCH /api/fall-detection/:alertId/resolve`);
  console.log(`   PATCH /api/emergency-alerts/:alertId/resolve`);
  console.log(`   GET  /api/all-alerts/:userId`);
  console.log(`   GET  /api/stats/:userId`);
  console.log(`   GET  /api/unresolved-alerts/:userId`);
  console.log(`   DELETE /api/cleanup-alerts/:userId`);
  console.log(`📢 Alert Preferences endpoints:`);
  console.log(`   GET  /api/alert-preferences/:userId`);
  console.log(`   POST /api/alert-preferences`);
  console.log(`   GET  /api/emergency-contacts/:userId`);
  console.log(`   POST /api/emergency-contacts/:userId`);
  console.log(`   DELETE /api/emergency-contacts/:userId/:contactIndex`);
  console.log(`   POST /api/test-notification/:userId`);
  console.log(`   GET  /api/notification-summary/:userId`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  mongoose.connection.close(() => {
    console.log('MongoDB connection closed.');
    process.exit(0);
  });
});