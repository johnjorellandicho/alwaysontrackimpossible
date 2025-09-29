import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfilePage({super.key, required this.userData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController patientController;
  late TextEditingController passwordController;
  late TextEditingController phoneController;
  late TextEditingController emergencyContactController;
  late TextEditingController medicalConditionsController;
  late TextEditingController relationshipController;

  bool isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with user data
    firstNameController = TextEditingController(
      text: widget.userData['firstName'] ?? '',
    );
    lastNameController = TextEditingController(
      text: widget.userData['lastName'] ?? '',
    );
    passwordController = TextEditingController(); // Empty for security
    phoneController = TextEditingController(
      text: widget.userData['phone'] ?? '',
    );

    // Initialize patient info controllers for family members
    final Map<String, dynamic>? patientInfo = widget.userData['patientInfo'];
    patientController = TextEditingController(
      text: patientInfo?['fullName'] ?? '',
    );
    emergencyContactController = TextEditingController(
      text: patientInfo?['emergencyContact'] ?? '',
    );
    medicalConditionsController = TextEditingController(
      text: patientInfo?['medicalConditions'] ?? '',
    );
    relationshipController = TextEditingController(
      text: patientInfo?['relationship'] ?? '',
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    patientController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    emergencyContactController.dispose();
    medicalConditionsController.dispose();
    relationshipController.dispose();
    super.dispose();
  }

  Future<void> _updateFirestoreData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Prepare updated data
    Map<String, dynamic> updatedData = {
      'firstName': firstNameController.text.trim(),
      'lastName': lastNameController.text.trim(),
      'fullName': '${firstNameController.text.trim()} ${lastNameController.text.trim()}',
      'phone': phoneController.text.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // Add patient info for family members
    if (widget.userData['role'] == 'family') {
      updatedData['patientInfo'] = {
        'fullName': patientController.text.trim(),
        'relationship': relationshipController.text.trim(),
        'medicalConditions': medicalConditionsController.text.trim(),
        'emergencyContact': emergencyContactController.text.trim(),
      };
    }

    // Update password if provided
    if (passwordController.text.isNotEmpty && passwordController.text != '••••••••') {
      await user.updatePassword(passwordController.text);
      updatedData['passwordUpdated'] = DateTime.now().toIso8601String();
    }

    // Update Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update(updatedData);
  }

  Future<void> _saveProfile() async {
    if (firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await _updateFirestoreData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.userData['role'] ?? 'unknown';
    final String firstName = widget.userData['firstName'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top red gradient header
            Container(
              width: double.infinity,
              height: 180,
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
              child: Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Text(
                    firstName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 60,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    _buildSectionHeader("Personal Information"),
                    
                    _buildLabel("First Name: *"),
                    _buildTextField(firstNameController),
                    
                    _buildLabel("Last Name:"),
                    _buildTextField(lastNameController),
                    
                    _buildLabel("Phone Number:"),
                    _buildTextField(phoneController, keyboardType: TextInputType.phone),

                    // Password Section
                    _buildSectionHeader("Security"),
                    _buildLabel("New Password: (leave blank to keep current)"),
                    _buildPasswordField(),

                    // Patient Information Section (only for family members)
                    if (role == 'family') ...[
                      _buildSectionHeader("Patient Information"),
                      
                      _buildLabel("Patient Name:"),
                      _buildTextField(patientController),
                      
                      _buildLabel("Relationship:"),
                      _buildTextField(relationshipController),
                      
                      _buildLabel("Medical Conditions:"),
                      _buildTextField(medicalConditionsController, maxLines: 3),
                      
                      _buildLabel("Emergency Contact:"),
                      _buildTextField(emergencyContactController, keyboardType: TextInputType.phone),
                    ],

                    const SizedBox(height: 30),

                    // Save button
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                        ),
                        onPressed: isLoading ? null : _saveProfile,
                        child: isLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Save Changes"),
                      ),
                    ),

                    // Cancel button
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      ),
    );
  }

  // Label
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          suffixIcon: Icon(Icons.edit, color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.red,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              const Icon(Icons.edit, color: Colors.red),
            ],
          ),
          hintText: "Enter new password (optional)",
          hintStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}