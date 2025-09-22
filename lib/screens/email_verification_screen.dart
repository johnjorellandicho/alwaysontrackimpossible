import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/user_role.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final UserRole userRole;
  final String firstName;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.userRole,
    required this.firstName,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isEmailVerified = false;
  Timer? _timer;
  bool _canResendEmail = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    
    if (!_isEmailVerified) {
      // Don't automatically send email - let user request it
      setState(() => _canResendEmail = true);
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    setState(() {
      _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    if (_isEmailVerified) {
      _timer?.cancel();
      // Navigate to dashboard
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  Future<void> _sendEmailVerification() async {
    try {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception('No user found. Please log in again.');
      }
      
      if (user.emailVerified) {
        setState(() => _isEmailVerified = true);
        _timer?.cancel();
        Navigator.of(context).pushReplacementNamed('/dashboard');
        return;
      }
      
      await user.sendEmailVerification();
      
      setState(() {
        _canResendEmail = false;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Allow resend after 2 minutes to avoid rate limits
      Timer(const Duration(minutes: 2), () {
        if (mounted) {
          setState(() => _canResendEmail = true);
        }
      });
      
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message = 'Error sending verification email';
      
      switch (e.code) {
        case 'too-many-requests':
          message = 'Too many email requests. Please wait 5-10 minutes before trying again.';
          // Wait longer before allowing retry
          Timer(const Duration(minutes: 5), () {
            if (mounted) {
              setState(() => _canResendEmail = true);
            }
          });
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          setState(() => _canResendEmail = true);
          break;
        case 'user-not-found':
          message = 'No user found. Please register again.';
          setState(() => _canResendEmail = true);
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          setState(() => _canResendEmail = true);
          break;
        default:
          message = 'Error: ${e.message ?? "Unknown error"}';
          Timer(const Duration(minutes: 1), () {
            if (mounted) {
              setState(() => _canResendEmail = true);
            }
          });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _canResendEmail = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
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
        child: Column(
          children: [
            const SizedBox(height: 80),
            Image.asset(
              "assets/alwaysontracklogowhite.png",
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),

            // White card container
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Email icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFD0004).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.email_outlined,
                          size: 50,
                          color: Color(0xFFFD0004),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      Text(
                        "Verify Your Email",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 15),
                      
                      Text(
                        "Hi ${widget.firstName}!",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      Text(
                        "We'll send a verification email to:",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        widget.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFD0004),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Text(
                        "Click the button below to send a verification email, then check your email and click the verification link.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Loading indicator while checking
                      if (!_isEmailVerified) ...[
                        const CircularProgressIndicator(
                          color: Color(0xFFFD0004),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Checking verification status...",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 30),
                      
                      // Resend email button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_canResendEmail && !_isLoading) ? _sendEmailVerification : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_canResendEmail && !_isLoading)
                                ? const Color(0xFFFD0004) 
                                : Colors.grey.shade300,
                            foregroundColor: (_canResendEmail && !_isLoading)
                                ? Colors.white 
                                : Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _canResendEmail 
                                      ? "Resend Verification Email" 
                                      : "Resend Available in 60s",
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Manual check button
                      TextButton(
                        onPressed: _checkEmailVerified,
                        child: const Text(
                          "I've verified my email",
                          style: TextStyle(
                            color: Color(0xFFFD0004),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Back to login
                      TextButton(
                        onPressed: () {
                          FirebaseAuth.instance.signOut();
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                        child: const Text(
                          "Back to Login",
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Help text
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Didn't receive the email?",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Check your spam folder or try resending the verification email.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}