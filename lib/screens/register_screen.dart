import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_verification_screen.dart';
import '../models/user_role.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Patient information controllers (for family members)
  final _patientFirstNameController = TextEditingController();
  final _patientLastNameController = TextEditingController();
  final _illnessesController = TextEditingController();

  UserRole? _selectedRole;
  String? _selectedRelationship;
  bool _isLoading = false;
  
  final List<String> _relationships = [
    'Parent',
    'Child', 
    'Spouse',
    'Sibling',
    'Grandparent',
    'Grandchild',
    'Other Family Member',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _patientFirstNameController.dispose();
    _patientLastNameController.dispose();
    _illnessesController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _selectedRole == null) {
      if (_selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select your role")),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      Map<String, dynamic> userData = {
        'uid': userCred.user!.uid,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'fullName': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'email': _emailController.text.trim(),
        'role': _selectedRole.toString().split('.').last,
        'emailVerified': false,
        'biometricsEnabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedRole == UserRole.family) {
        userData.addAll({
          'patientInfo': {
            'firstName': _patientFirstNameController.text.trim(),
            'lastName': _patientLastNameController.text.trim(),
            'fullName': '${_patientFirstNameController.text.trim()} ${_patientLastNameController.text.trim()}',
            'relationship': _selectedRelationship,
            'medicalConditions': _illnessesController.text.trim(),
            'setupDate': FieldValue.serverTimestamp(),
          }
        });
      }

      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set(userData);
      await userCred.user?.sendEmailVerification();

      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(
            email: _emailController.text.trim(),
            userRole: _selectedRole!,
            firstName: _firstNameController.text.trim(),
          ),
        ),
      );

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message = "Registration failed";
      
      if (e.code == 'email-already-in-use') {
        message = "Email is already registered";
      } else if (e.code == 'weak-password') {
        message = "Password is too weak";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.15, 0.9, 1.0],
            colors: [
              Color(0xFFFD0004),
              Color(0xFFF83E41),
              Color(0xFFFF5053),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Image.asset(
                "assets/alwaysontracklogowhite.png",
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 30),

            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Register with your personal information",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 25),

                        // First Name and Last Name Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                decoration: const InputDecoration(
                                  labelText: "First Name",
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                  ),
                                ),
                                validator: (value) =>
                                    value!.isEmpty ? "Enter your first name" : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: "Last Name",
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                  ),
                                ),
                                validator: (value) =>
                                    value!.isEmpty ? "Enter your last name" : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Enter your email";
                            }
                            if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$")
                                .hasMatch(value)) {
                              return "Enter a valid email";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Role Selection
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  "I am registering as:",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              RadioListTile<UserRole>(
                                title: const Text('Patient'),
                                subtitle: const Text('Monitor my own health vitals'),
                                value: UserRole.patient,
                                groupValue: _selectedRole,
                                onChanged: (UserRole? value) {
                                  setState(() {
                                    _selectedRole = value;
                                  });
                                },
                              ),
                              const Divider(height: 1),
                              RadioListTile<UserRole>(
                                title: const Text('Family Member'),
                                subtitle: const Text('Monitor a family member\'s health'),
                                value: UserRole.family,
                                groupValue: _selectedRole,
                                onChanged: (UserRole? value) {
                                  setState(() {
                                    _selectedRole = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Patient Information Fields (shown only when Family Member is selected)
                        if (_selectedRole == UserRole.family) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person_add, color: Colors.blue.shade600, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Patient Information",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Enter details of the patient you'll be monitoring",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Patient First and Last Name
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _patientFirstNameController,
                                        decoration: const InputDecoration(
                                          labelText: "Patient First Name",
                                          prefixIcon: Icon(Icons.person),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(8)),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        validator: (value) {
                                          if (_selectedRole == UserRole.family) {
                                            if (value == null || value.isEmpty) {
                                              return "Required";
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _patientLastNameController,
                                        decoration: const InputDecoration(
                                          labelText: "Patient Last Name",
                                          prefixIcon: Icon(Icons.person_outline),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(8)),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        validator: (value) {
                                          if (_selectedRole == UserRole.family) {
                                            if (value == null || value.isEmpty) {
                                              return "Required";
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Relationship
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: "Your relationship to patient",
                                    prefixIcon: Icon(Icons.family_restroom),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  value: _selectedRelationship,
                                  items: _relationships.map((String relationship) {
                                    return DropdownMenuItem<String>(
                                      value: relationship,
                                      child: Text(relationship),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() => _selectedRelationship = newValue);
                                  },
                                  validator: (value) {
                                    if (_selectedRole == UserRole.family) {
                                      if (value == null) {
                                        return "Please select relationship";
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                
                                // Illnesses
                                TextFormField(
                                  controller: _illnessesController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: "Known medical conditions",
                                    hintText: "e.g., High BP, Diabetes, Heart condition, etc.",
                                    prefixIcon: Icon(Icons.medical_information),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (value) {
                                    if (_selectedRole == UserRole.family) {
                                      if (value == null || value.trim().isEmpty) {
                                        return "Enter conditions or 'None'";
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Password",
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (value) =>
                              value!.length < 6 ? "Min 6 characters" : null,
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Confirm Password",
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (value) =>
                              value != _passwordController.text
                                  ? "Passwords don't match"
                                  : null,
                        ),
                        const SizedBox(height: 24),

                        // Register button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFD0004),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading ? null : _register,
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "Register",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Already have account? Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? "),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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