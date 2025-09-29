import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'alert_feed_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfilePage({super.key, required this.userData});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 3; // Profile tab as default

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigation logic
    switch (index) {
      case 0:
        // TrackAI - Add navigation when ready
        break;
      case 1:
        // Alert - Navigate to AlertFeedPage with userData
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlertFeedPage(userData: widget.userData),
          ),
        );
        break;
      case 2:
        // Dashboard - Navigate back to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
        break;
      case 3:
        // Profile - Already here, do nothing
        break;
      case 4:
        // Settings - Add navigation when ready
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract user data
    final String firstName = widget.userData['firstName'] ?? 'User';
    final String lastName = widget.userData['lastName'] ?? '';
    final String email = widget.userData['email'] ?? 'No email';
    final String role = widget.userData['role'] ?? 'unknown';
    final String fullName = '$firstName $lastName'.trim();
    
    // Get patient info for family members
    final Map<String, dynamic>? patientInfo = widget.userData['patientInfo'];
    final String patientName = patientInfo != null 
        ? patientInfo['fullName'] ?? 'Patient' 
        : 'No patient assigned';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Gradient Header
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

            const SizedBox(height: 12),

            // User Info
            Text(
              fullName.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            if (role == 'family' && patientName != 'No patient assigned')
              Text(
                "Monitoring: $patientName",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black,
                ),
              )
            else if (role == 'patient')
              const Text(
                "Patient Account",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green,
                ),
              ),

            const SizedBox(height: 20),

            // Profile Options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildProfileTile(
                    title: "Edit Profile Information",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfilePage(userData: widget.userData),
                        ),
                      );
                    },
                  ),
                  _buildProfileTile(
                    title: "Enable/Disable Two-Factor Authentication (2FA)",
                    trailing: Switch(
                      value: widget.userData['twoFactorEnabled'] ?? false, 
                      onChanged: (value) {
                        // Handle 2FA toggle
                        setState(() {
                          // Update local state - in real app, update Firebase
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value ? '2FA Enabled' : '2FA Disabled',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildProfileTile(
                    title: "Manage login sessions (log out of other devices)",
                    onTap: () {
                      _showLogoutSessionsDialog();
                    },
                  ),
                  _buildProfileTile(
                    title: "View Account Information",
                    onTap: () {
                      _showAccountInfoDialog();
                    },
                  ),
                  if (role == 'family')
                    _buildProfileTile(
                      title: "Patient Information",
                      onTap: () {
                        _showPatientInfoDialog();
                      },
                    ),
                  _buildProfileTile(
                    title: "Delete Account & ALL Data",
                    onTap: () {
                      _showDeleteAccountDialog();
                    },
                  ),
                  const SizedBox(height: 20),

                  // Logout Button
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        _showLogoutDialog();
                      },
                      child: const Text("Logout"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  // Reusable Tile Builder with Red Bar + Background Color
  Widget _buildProfileTile({
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFFFBEFEF),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Container(
          width: 6,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAccountInfoDialog() {
    final String role = widget.userData['role'] ?? 'unknown';
    final String createdAt = widget.userData['createdAt'] ?? 'Unknown';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Account Type:', role.toUpperCase()),
            const SizedBox(height: 8),
            _buildInfoRow('Email:', widget.userData['email'] ?? 'No email'),
            const SizedBox(height: 8),
            _buildInfoRow('Phone:', widget.userData['phone'] ?? 'Not provided'),
            const SizedBox(height: 8),
            _buildInfoRow('Created:', createdAt),
            const SizedBox(height: 8),
            _buildInfoRow('User ID:', FirebaseAuth.instance.currentUser?.uid ?? 'Unknown'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPatientInfoDialog() {
    final Map<String, dynamic>? patientInfo = widget.userData['patientInfo'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Patient Information'),
        content: patientInfo != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name:', patientInfo['fullName'] ?? 'Unknown'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Relationship:', patientInfo['relationship'] ?? 'Not specified'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Medical Conditions:', patientInfo['medicalConditions'] ?? 'None specified'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Emergency Contact:', patientInfo['emergencyContact'] ?? 'Not provided'),
                ],
              )
            : const Text('No patient information available'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutSessionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Sessions'),
        content: const Text('This will log you out of all other devices. You will need to login again on those devices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out of all other sessions'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Logout Other Sessions'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'WARNING: This will permanently delete your account and ALL data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteAccount();
            },
            child: const Text('Delete Account', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    final TextEditingController deleteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type "DELETE" to confirm account deletion:'),
            const SizedBox(height: 16),
            TextField(
              controller: deleteController,
              decoration: const InputDecoration(
                hintText: 'Type DELETE here',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (deleteController.text == 'DELETE') {
                Navigator.pop(context);
                // Handle account deletion
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deletion initiated'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE exactly to confirm'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Delete Account', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}