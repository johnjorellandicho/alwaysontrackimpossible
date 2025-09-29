import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class TrackAIPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? currentVitals;

  const TrackAIPage({
    super.key,
    required this.userData,
    this.currentVitals,
  });

  @override
  State<TrackAIPage> createState() => _TrackAIPageState();
}

class _TrackAIPageState extends State<TrackAIPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // Google Gemini API Configuration - FIXED ENDPOINT
  static const String geminiApiKey = 'AIzaSyAhuA3yucpLFGs8zzl_OsXLnNKMrbpenwc';
  static const String geminiApiUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent';

  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _typingAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    final String firstName = widget.userData['firstName'] ?? 'User';
    final welcomeMessage = ChatMessage(
      text: "Hello $firstName!\n\nI'm TrackAI, your personal health assistant powered by Google Gemini AI. "
          "I can help you understand your health data, answer questions about your vital signs, "
          "and provide health insights based on your sensor readings.\n\n"
          "Your current vitals:\n"
          "🌡️ Temperature: ${widget.currentVitals?['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C "
          "(${widget.currentVitals?['temperatureStatus'] ?? 'Unknown'})\n"
          "❤️ Heart Rate: ${widget.currentVitals?['heartRate']?.toString() ?? 'N/A'} BPM\n"
          "🫁 SpO2: ${widget.currentVitals?['spO2']?.toString() ?? 'N/A'}%\n"
          "💧 Humidity: ${widget.currentVitals?['humidity']?.toStringAsFixed(1) ?? 'N/A'}%\n\n"
          "What would you like to know about your health today?",
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(welcomeMessage);
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();
    _typingAnimationController.repeat();

    try {
      final aiResponse = await _getGeminiResponse(userMessage);
      setState(() {
        _messages.add(ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _typingAnimationController.stop();
      _scrollToBottom();
    } catch (e) {
      print('API Error Details: $e');
      setState(() {
        _messages.add(ChatMessage(
          text: "I'm having trouble connecting to my AI service right now. "
              "Error: $e\n\n"
              "Let me provide a health-focused response instead based on your vitals.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _typingAnimationController.stop();
      
      // Add a follow-up response with health insights
      await Future.delayed(const Duration(seconds: 1));
      final fallbackResponse = _getEnhancedFallbackResponse(userMessage);
      setState(() {
        _messages.add(ChatMessage(
          text: fallbackResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    }
  }

  Future<String> _getGeminiResponse(String userMessage) async {
    try {
      // Build health-focused prompt - ENHANCED VERSION
      final healthPrompt = _buildHealthPrompt(userMessage);
      
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": healthPrompt
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 512,
          "stopSequences": []
        },
        "safetySettings": [
          {
            "category": "HARM_CATEGORY_HARASSMENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_HATE_SPEECH",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          }
        ]
      };

      print('Sending request to: $geminiApiUrl?key=$geminiApiKey');
      print('Request body: ${json.encode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$geminiApiUrl?key=$geminiApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final candidate = data['candidates'][0];
          
          // Check for safety blocking
          if (candidate['finishReason'] == 'SAFETY') {
            return "I want to provide helpful health information, but I need to be extra careful with medical advice. Let me give you general guidance about your current vitals instead.\n\n${_getVitalsAnalysis()}";
          }
          
          if (candidate['content']?['parts'] != null && candidate['content']['parts'].isNotEmpty) {
            String aiResponse = candidate['content']['parts'][0]['text']?.toString().trim() ?? '';
            
            if (aiResponse.isNotEmpty) {
              return _cleanupResponse(aiResponse);
            }
          }
        }
        
        return "I received an empty response from the AI service. Let me provide you with health insights based on your current vitals instead.\n\n${_getVitalsAnalysis()}";
        
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw Exception('Bad Request: ${errorData['error']?['message'] ?? 'Invalid request format'}');
      } else if (response.statusCode == 403) {
        throw Exception('API Key Error: Please check your API key permissions and billing status');
      } else if (response.statusCode == 429) {
        return "I'm currently experiencing high demand. Please try again in a moment. Your current vitals look good while we wait!";
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Gemini API error details: $e');
      rethrow;
    }
  }

  String _buildHealthPrompt(String userMessage) {
    final firstName = widget.userData['firstName'] ?? 'User';
    final vitals = widget.currentVitals ?? {};
    
    // ENHANCED PROMPT - More specific and focused
    return """You are TrackAI, a specialized health monitoring assistant helping ${firstName} understand their vital signs and health data.

CRITICAL: You must respond as TrackAI in a conversational, personalized manner. Do NOT give generic responses.

CONTEXT & ROLE:
- You are specifically designed for health monitoring and vital sign interpretation
- You have access to ${firstName}'s real-time health data from IoT sensors
- Your responses should be specific to their current readings and question
- Always be supportive but emphasize medical professional consultation for concerns

CURRENT LIVE VITAL READINGS:
Temperature: ${vitals['temperature']?.toStringAsFixed(1) ?? 'No reading'}°C (${vitals['temperatureStatus'] ?? 'Status unknown'})
Heart Rate: ${vitals['heartRate']?.toString() ?? 'No reading'} BPM
Blood Oxygen (SpO2): ${vitals['spO2']?.toString() ?? 'No reading'}%
Environmental Humidity: ${vitals['humidity']?.toStringAsFixed(1) ?? 'No reading'}%

REFERENCE RANGES:
- Normal temperature: 36.1-37.2°C
- Normal resting heart rate: 60-100 BPM
- Normal SpO2: 95-100%
- Comfortable humidity: 30-60%

USER'S SPECIFIC QUESTION: "${userMessage}"

RESPONSE REQUIREMENTS:
1. Address ${firstName} personally
2. Reference their specific vital readings when relevant
3. Provide actionable insights about their current health status
4. Keep response under 300 words
5. Be conversational, not clinical
6. Always recommend professional medical care for serious concerns

Respond directly to their question with specific insights about their health data:""";
  }

  String _getVitalsAnalysis() {
    final vitals = widget.currentVitals ?? {};
    final firstName = widget.userData['firstName'] ?? 'User';
    
    String analysis = "Here's what your current vitals tell me, $firstName:\n\n";
    
    // Temperature analysis
    final temp = vitals['temperature'];
    if (temp != null) {
      if (temp >= 38.0) {
        analysis += "🌡️ Your temperature (${temp.toStringAsFixed(1)}°C) suggests you might have a fever. Stay hydrated and consider contacting a healthcare provider.\n\n";
      } else if (temp >= 37.3) {
        analysis += "🌡️ Your temperature (${temp.toStringAsFixed(1)}°C) is slightly elevated. Monitor how you're feeling.\n\n";
      } else if (temp >= 36.1) {
        analysis += "🌡️ Your temperature (${temp.toStringAsFixed(1)}°C) is perfectly normal.\n\n";
      }
    }
    
    // Heart rate analysis
    final hr = vitals['heartRate'];
    if (hr != null) {
      if (hr < 60) {
        analysis += "❤️ Your heart rate ($hr BPM) is below typical range. This could be normal if you're athletic, but worth monitoring.\n\n";
      } else if (hr > 100) {
        analysis += "❤️ Your heart rate ($hr BPM) is elevated. This could be from activity, stress, or caffeine.\n\n";
      } else {
        analysis += "❤️ Your heart rate ($hr BPM) is in the healthy range.\n\n";
      }
    }
    
    // SpO2 analysis
    final spo2 = vitals['spO2'];
    if (spo2 != null) {
      if (spo2 >= 95) {
        analysis += "🫁 Your oxygen levels ($spo2%) are excellent.\n\n";
      } else {
        analysis += "🫁 Your oxygen levels ($spo2%) are below optimal. Ensure good ventilation and consider consulting a healthcare provider if you feel unwell.\n\n";
      }
    }
    
    return analysis + "Remember, I'm here to help interpret your readings, but always consult healthcare professionals for medical decisions.";
  }

  String _cleanupResponse(String response) {
    // Remove common AI artifacts and clean up the response
    response = response.replaceAll(RegExp(r'^(Response:|Answer:|TrackAI:)\s*'), '');
    response = response.replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1'); // Remove bold markdown
    response = response.replaceAll(RegExp(r'\n\n+'), '\n\n');
    response = response.trim();
    
    // Ensure response isn't too long
    if (response.length > 800) {
      response = response.substring(0, 800) + '...\n\nFor more detailed information, feel free to ask specific questions!';
    }
    
    return response;
  }

  // Enhanced fallback response for when API is unavailable
  String _getEnhancedFallbackResponse(String userMessage) {
    final userMessageLower = userMessage.toLowerCase();
    final vitals = widget.currentVitals ?? {};
    final firstName = widget.userData['firstName'] ?? 'there';

    // Emergency or critical questions
    if (userMessageLower.contains('emergency') || userMessageLower.contains('critical') || 
        userMessageLower.contains('chest pain') || userMessageLower.contains('can\'t breathe')) {
      return "🚨 $firstName, if you're experiencing a medical emergency, please call emergency services immediately (911, 999, or your local emergency number).\n\nFor chest pain, difficulty breathing, or any symptoms that worry you, seek immediate medical attention. I'm a health monitoring assistant, not a replacement for emergency medical care.\n\nYour current vitals: Temperature ${vitals['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C, Heart Rate ${vitals['heartRate'] ?? 'N/A'} BPM, SpO2 ${vitals['spO2'] ?? 'N/A'}%.";
    }

    // Temperature questions
    if (userMessageLower.contains('temperature') || userMessageLower.contains('fever')) {
      final temp = vitals['temperature']?.toStringAsFixed(1) ?? 'N/A';
      final status = vitals['temperatureStatus'] ?? 'Unknown';
      
      String interpretation = "";
      if (temp != 'N/A') {
        final tempValue = double.tryParse(temp) ?? 0;
        if (tempValue >= 38.0) {
          interpretation = "$firstName, this may indicate a fever. Consider contacting a healthcare provider if you feel unwell or if it persists.";
        } else if (tempValue >= 37.3) {
          interpretation = "This is slightly elevated, $firstName. Monitor how you're feeling and stay hydrated.";
        } else if (tempValue >= 36.1) {
          interpretation = "Great news, $firstName! This is within the normal range.";
        } else if (tempValue > 0) {
          interpretation = "This seems lower than typical, $firstName. Make sure you're staying warm enough.";
        }
      }
      
      return "🌡️ $firstName, your current temperature is $temp°C, classified as $status. $interpretation\n\nNormal body temperature ranges from 36.1-37.2°C (97-99°F). If you have concerns about fever or feel unwell, it's best to consult with a healthcare provider.";
    }

    // Heart rate questions
    if (userMessageLower.contains('heart') || userMessageLower.contains('pulse') || userMessageLower.contains('bpm')) {
      final hr = vitals['heartRate']?.toString() ?? 'N/A';
      
      String interpretation = "";
      if (hr != 'N/A') {
        final heartRate = int.tryParse(hr) ?? 0;
        if (heartRate < 60) {
          interpretation = "$firstName, this is below the typical resting range (60-100 BPM). If you're an athlete, this could be normal, but consider consulting a healthcare provider if you have concerns.";
        } else if (heartRate > 100) {
          interpretation = "$firstName, this is above the typical resting range. This could be due to activity, stress, caffeine, or other factors. Try to relax and monitor it.";
        } else {
          interpretation = "Excellent, $firstName! This is within the normal resting heart rate range.";
        }
      }
      
      return "❤️ $firstName, your current heart rate is $hr BPM. $interpretation\n\nHeart rate naturally varies with activity, emotions, caffeine, and other factors. If you're concerned about unusual patterns, consider discussing with a healthcare provider.";
    }

    // Default response with actual vitals analysis
    return _getVitalsAnalysis();
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'TrackAI (Gemini)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFD0004),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              _addWelcomeMessage();
            },
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick vitals display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFD0004).withOpacity(0.8),
                  const Color(0xFFF83E41).withOpacity(0.8),
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickStat(
                    "🌡️",
                    "${widget.currentVitals?['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C",
                    widget.currentVitals?['temperatureStatus'] ?? 'Unknown',
                  ),
                ),
                Expanded(
                  child: _buildQuickStat(
                    "❤️",
                    "${widget.currentVitals?['heartRate']?.toString() ?? 'N/A'} BPM",
                    "Heart Rate",
                  ),
                ),
                Expanded(
                  child: _buildQuickStat(
                    "🫁",
                    "${widget.currentVitals?['spO2']?.toString() ?? 'N/A'}%",
                    "Oxygen",
                  ),
                ),
              ],
            ),
          ),
          // Chat messages
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildTypingIndicator();
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask me about your health...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      prefixIcon: const Icon(Icons.health_and_safety, color: Colors.grey),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFD0004),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String emoji, String value, String status) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          status,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFFD0004),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? const Color(0xFFFD0004) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: message.isUser ? Colors.white.withOpacity(0.7) : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFFD0004),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Text(
              'TrackAI is thinking...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}