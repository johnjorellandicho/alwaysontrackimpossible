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

  // OpenRouter API Configuration (Has FREE models!)
  // Sign up at: https://openrouter.ai/keys
  // You get FREE credits on signup!
  static const String openRouterApiKey = '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';
  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  
  // FREE MODELS YOU CAN USE:
  // 'meta-llama/llama-3.2-3b-instruct:free'
  // 'google/gemini-flash-1.5:free' 
  // 'mistralai/mistral-7b-instruct:free'
  // 'nousresearch/hermes-3-llama-3.1-405b:free'
  static const String modelName = 'meta-llama/llama-3.2-3b-instruct:free';

  late AnimationController _typingAnimationController;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
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
      text: "Hello $firstName! 👋\n\nI'm TrackAI, your personal health assistant. "
          "I can help you understand your health data, answer questions about your vital signs, "
          "and even chat about general topics!\n\n"
          "📊 Your current vitals:\n"
          "🌡️ Temperature: ${widget.currentVitals?['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C "
          "(${widget.currentVitals?['temperatureStatus'] ?? 'Unknown'})\n"
          "❤️ Heart Rate: ${widget.currentVitals?['heartRate']?.toString() ?? 'N/A'} BPM\n"
          "🫁 SpO2: ${widget.currentVitals?['spO2']?.toString() ?? 'N/A'}%\n"
          "💧 Humidity: ${widget.currentVitals?['humidity']?.toStringAsFixed(1) ?? 'N/A'}%\n\n"
          "What would you like to know?",
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
      final aiResponse = await _getAIResponse(userMessage);
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
      print('API Error: $e');
      setState(() {
        _isLoading = false;
      });
      _typingAnimationController.stop();
      
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

  Future<String> _getAIResponse(String userMessage) async {
    // If API key is not set, use intelligent fallback
    if (openRouterApiKey == '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') {
      return _getEnhancedFallbackResponse(userMessage);
    }

    try {
      final systemPrompt = _buildSystemPrompt();
      
      final requestBody = {
        "model": modelName,
        "messages": [
          {
            "role": "system",
            "content": systemPrompt
          },
          {
            "role": "user",
            "content": userMessage
          }
        ],
        "temperature": 0.7,
        "max_tokens": 300,
      };

      print('🚀 Sending request to OpenRouter...');
      print('📍 Model: $modelName');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $openRouterApiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://trackai.health',
          'X-Title': 'TrackAI Health Monitor',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📊 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final message = data['choices'][0]['message'];
          String aiResponse = message['content']?.toString().trim() ?? '';
          
          print('✅ AI Response received');
          
          if (aiResponse.isNotEmpty) {
            return _cleanupResponse(aiResponse);
          }
        }
        
        return _getEnhancedFallbackResponse(userMessage);
        
      } else if (response.statusCode == 401) {
        return "🔑 API key invalid. Please check your OpenRouter API key at https://openrouter.ai/keys\n\nUsing offline mode:\n\n${_getEnhancedFallbackResponse(userMessage)}";
        
      } else if (response.statusCode == 402) {
        return "💳 Out of credits. OpenRouter requires credits for this model. Try a different free model or using offline mode:\n\n${_getEnhancedFallbackResponse(userMessage)}";
        
      } else if (response.statusCode == 429) {
        return "⏳ Rate limited. Please wait a moment before sending another message.\n\nMeanwhile:\n\n${_getEnhancedFallbackResponse(userMessage)}";
        
      } else {
        final errorData = json.decode(response.body);
        print('💥 Error: ${errorData}');
        throw Exception('HTTP ${response.statusCode}: ${errorData}');
      }
    } catch (e) {
      print('💥 AI API error: $e');
      return _getEnhancedFallbackResponse(userMessage);
    }
  }

  String _buildSystemPrompt() {
    final firstName = widget.userData['firstName'] ?? 'User';
    final vitals = widget.currentVitals ?? {};
    
    return """You are TrackAI, a friendly AI health assistant for ${firstName}.

CURRENT VITALS:
- Temperature: ${vitals['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C (${vitals['temperatureStatus'] ?? 'Unknown'})
- Heart Rate: ${vitals['heartRate']?.toString() ?? 'N/A'} BPM
- SpO2: ${vitals['spO2']?.toString() ?? 'N/A'}%
- Humidity: ${vitals['humidity']?.toStringAsFixed(1) ?? 'N/A'}%

REFERENCE RANGES:
- Normal temperature: 36.1-37.2°C
- Normal resting heart rate: 60-100 BPM
- Normal SpO2: 95-100%

INSTRUCTIONS:
1. You can answer BOTH health questions and general questions
2. For health questions, reference their specific vital readings when relevant
3. Keep responses under 200 words
4. Be conversational and friendly
5. For medical concerns, always recommend consulting healthcare professionals
6. You can discuss any topic, not just health

Respond naturally and helpfully to their question.""";
  }

  String _cleanupResponse(String response) {
    response = response.trim();
    
    if (response.length > 800) {
      response = response.substring(0, 800) + '...';
    }
    
    return response;
  }

  String _getVitalsAnalysis() {
    final vitals = widget.currentVitals ?? {};
    final firstName = widget.userData['firstName'] ?? 'User';
    
    String analysis = "📊 Here's your current health status, $firstName:\n\n";
    
    final temp = vitals['temperature'];
    if (temp != null) {
      if (temp >= 38.0) {
        analysis += "🌡️ Temperature: ${temp.toStringAsFixed(1)}°C - This suggests a fever. Stay hydrated and consider contacting a healthcare provider.\n\n";
      } else if (temp >= 37.3) {
        analysis += "🌡️ Temperature: ${temp.toStringAsFixed(1)}°C - Slightly elevated. Monitor how you're feeling.\n\n";
      } else if (temp >= 36.1) {
        analysis += "🌡️ Temperature: ${temp.toStringAsFixed(1)}°C - Normal range. ✓\n\n";
      }
    }
    
    final hr = vitals['heartRate'];
    if (hr != null) {
      if (hr < 60) {
        analysis += "❤️ Heart Rate: $hr BPM - Below typical range. Normal if you're athletic.\n\n";
      } else if (hr > 100) {
        analysis += "❤️ Heart Rate: $hr BPM - Elevated. Could be from activity, stress, or caffeine.\n\n";
      } else {
        analysis += "❤️ Heart Rate: $hr BPM - Healthy range. ✓\n\n";
      }
    }
    
    final spo2 = vitals['spO2'];
    if (spo2 != null) {
      if (spo2 >= 95) {
        analysis += "🫁 Oxygen: $spo2% - Excellent levels. ✓\n\n";
      } else {
        analysis += "🫁 Oxygen: $spo2% - Below optimal. Ensure good ventilation.\n\n";
      }
    }
    
    return analysis + "💡 I'm here to help interpret your readings and answer any questions!";
  }

  String _getEnhancedFallbackResponse(String userMessage) {
    final userMessageLower = userMessage.toLowerCase();
    final vitals = widget.currentVitals ?? {};
    final firstName = widget.userData['firstName'] ?? 'there';

    // Emergency
    if (userMessageLower.contains('emergency') || userMessageLower.contains('chest pain') || 
        userMessageLower.contains('can\'t breathe')) {
      return "🚨 $firstName, if you're experiencing a medical emergency, call emergency services immediately (911)!\n\nYour vitals: Temp ${vitals['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C, HR ${vitals['heartRate'] ?? 'N/A'} BPM, SpO2 ${vitals['spO2'] ?? 'N/A'}%.";
    }

    // Temperature
    if (userMessageLower.contains('temperature') || userMessageLower.contains('fever')) {
      final temp = vitals['temperature']?.toStringAsFixed(1) ?? 'N/A';
      final status = vitals['temperatureStatus'] ?? 'Unknown';
      
      String advice = "";
      if (temp != 'N/A') {
        final tempValue = double.tryParse(temp) ?? 0;
        if (tempValue >= 38.0) {
          advice = "This suggests a fever, $firstName. Stay hydrated, rest, and contact a healthcare provider if it persists.";
        } else if (tempValue >= 37.3) {
          advice = "Slightly elevated, $firstName. Monitor and stay hydrated.";
        } else if (tempValue >= 36.1) {
          advice = "Perfect! This is in the normal range.";
        }
      }
      
      return "🌡️ Your temperature is $temp°C ($status).\n\n$advice\n\nNormal range: 36.1-37.2°C";
    }

    // Heart rate
    if (userMessageLower.contains('heart') || userMessageLower.contains('pulse')) {
      final hr = vitals['heartRate']?.toString() ?? 'N/A';
      
      String advice = "";
      if (hr != 'N/A') {
        final heartRate = int.tryParse(hr) ?? 0;
        if (heartRate < 60) {
          advice = "Below typical range. Normal if you're athletic, but monitor how you feel.";
        } else if (heartRate > 100) {
          advice = "Elevated. Could be from activity, stress, or caffeine. Try to relax.";
        } else {
          advice = "Excellent! Within healthy resting range.";
        }
      }
      
      return "❤️ Your heart rate is $hr BPM.\n\n$advice\n\nNormal resting: 60-100 BPM";
    }

    // Oxygen
    if (userMessageLower.contains('oxygen') || userMessageLower.contains('spo2')) {
      final spo2 = vitals['spO2']?.toString() ?? 'N/A';
      
      String advice = "";
      if (spo2 != 'N/A') {
        final oxygenLevel = int.tryParse(spo2) ?? 0;
        if (oxygenLevel >= 95) {
          advice = "Excellent! Your blood is carrying oxygen efficiently.";
        } else if (oxygenLevel >= 90) {
          advice = "Slightly lower than ideal. Ensure good ventilation and take deep breaths.";
        } else {
          advice = "⚠️ Low reading. If accurate, consider seeking medical attention.";
        }
      }
      
      return "🫁 Your SpO2 is $spo2%.\n\n$advice\n\nNormal range: 95-100%";
    }

    // General health
    if (userMessageLower.contains('how am i') || userMessageLower.contains('my health')) {
      return _getVitalsAnalysis();
    }

    // Greetings
    if (userMessageLower.contains('hello') || userMessageLower.contains('hi')) {
      return "Hello $firstName! 👋\n\nI'm TrackAI, monitoring your health in real-time. Your vitals look good!\n\nAsk me:\n• About your temperature, heart rate, or oxygen\n• Health tips\n• General questions\n\nWhat can I help with?";
    }

    // Jokes
    if (userMessageLower.contains('joke')) {
      return "😄 Here's one for you, $firstName:\n\nWhy did the doctor carry a red pen? In case they needed to draw blood!\n\n😂 Your vitals are looking good today, by the way!";
    }

    // Time
    if (userMessageLower.contains('time') || userMessageLower.contains('date')) {
      final now = DateTime.now();
      return "⏰ It's ${DateFormat('EEEE, MMMM d, y - h:mm a').format(now)}\n\n${_getVitalsAnalysis()}";
    }

    // Weather
    if (userMessageLower.contains('weather')) {
      return "🌤️ I don't have weather data, but your environmental humidity is ${vitals['humidity']?.toStringAsFixed(1) ?? 'N/A'}%!\n\nFor weather, check a weather app. Need anything else?";
    }

    // Default
    return "Hi $firstName! I'm TrackAI, your health assistant. 🩺\n\n${_getVitalsAnalysis()}\n\nI can also answer general questions! What would you like to know?";
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
        title: Row(
          children: [
            const Icon(Icons.smart_toy, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'TrackAI ${openRouterApiKey != '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' ? '(AI)' : '(Offline)'}',
              style: const TextStyle(
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
                      hintText: 'Ask me anything...',
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
                      prefixIcon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
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