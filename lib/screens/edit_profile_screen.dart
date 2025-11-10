import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../widgets/glossy_snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  
  final _nameController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _primaryEmailController = TextEditingController();
  final _secondaryEmailController = TextEditingController();
  final _whitelistEmailController = TextEditingController();
  
  UserProfile? _userProfile;
  List<String> _whitelistedEmails = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.loadProfile();
      setState(() {
        _userProfile = profile;
        _nameController.text = profile.name;
        _registrationNumberController.text = profile.registrationNumber;
        _primaryEmailController.text = profile.primaryEmail;
        _secondaryEmailController.text = profile.secondaryEmail;
        _whitelistedEmails = List.from(profile.whitelistedEmails);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedProfile = UserProfile(
        name: _nameController.text.trim(),
        registrationNumber: _registrationNumberController.text.trim(),
        primaryEmail: _primaryEmailController.text.trim(),
        secondaryEmail: _secondaryEmailController.text.trim(),
        whitelistedEmails: _whitelistedEmails,
      );

      await _profileService.saveProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile Updated Successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Wait a moment to show the snackbar
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate profile was updated
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to save: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addWhitelistEmail() {
    final email = _whitelistEmailController.text.trim();
    
    if (email.isEmpty) {
      showGlossySnackbar(
        context,
        message: 'Please enter an email address',
        color: const Color(0xFF66B2FF), // Blue
        icon: Icons.info,
      );
      return;
    }

    if (!_isValidEmail(email)) {
      showGlossySnackbar(
        context,
        message: 'Please enter a valid email address',
        color: const Color(0xFFFF6B6B), // Red
        icon: Icons.error,
      );
      return;
    }

    if (_whitelistedEmails.contains(email)) {
      showGlossySnackbar(
        context,
        message: 'Email already in whitelist',
        color: const Color(0xFF66B2FF), // Blue
        icon: Icons.info,
      );
      return;
    }

    setState(() {
      _whitelistedEmails.add(email);
      _whitelistEmailController.clear();
    });

    showGlossySnackbar(
      context,
      message: 'Email added to whitelist',
      color: const Color(0xFF7FD97F), // Green
      icon: Icons.check_circle,
    );
  }

  void _removeWhitelistEmail(String email) {
    setState(() {
      _whitelistedEmails.remove(email);
    });

    showGlossySnackbar(
      context,
      message: 'Email removed from whitelist',
      color: const Color(0xFF7FD97F), // Green
      icon: Icons.check_circle,
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default Emails?'),
        content: const Text(
          'This will reset the whitelist to default VIT-AP placement emails:\n'
          '• students.cdc.2026@vitap.ac.in\n'
          '• placement@vitap.ac.in\n\n'
          'Your custom emails will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _whitelistedEmails = [
                  'students.cdc.2026@vitap.ac.in',
                  'placement@vitap.ac.in',
                ];
              });
              Navigator.pop(context);
              showGlossySnackbar(
                context,
                message: 'Whitelist reset to defaults',
                color: const Color(0xFF7FD97F), // Green
                icon: Icons.check_circle,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationNumberController.dispose();
    _primaryEmailController.dispose();
    _secondaryEmailController.dispose();
    _whitelistEmailController.dispose();
    super.dispose();
  }

  // Get initials from name
  String _getInitials() {
    if (_nameController.text.trim().isEmpty) return 'U';
    final parts = _nameController.text.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                const Color(0xFFF9E4B7),
                Colors.white,
              ],
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // Gradient Header with Avatar
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFF9E4B7),
                        const Color(0xFFFFF8E1),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Large Avatar with Initials
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade400,
                              Colors.amber.shade600,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Profile Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Basic Information Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Basic Information', Icons.person),
                            const SizedBox(height: 20),
                            
                            // Full Name Field
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                hintText: 'Enter your full name',
                                prefixIcon: Icon(Icons.badge, color: Colors.amber.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}), // Refresh initials
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Registration Number Field
                            TextFormField(
                              controller: _registrationNumberController,
                              decoration: InputDecoration(
                                labelText: 'Registration Number',
                                hintText: 'e.g., 22BCE9726',
                                prefixIcon: Icon(Icons.numbers, color: Colors.amber.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your registration number';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Primary Email Field
                            TextFormField(
                              controller: _primaryEmailController,
                              decoration: InputDecoration(
                                labelText: 'Primary Email',
                                hintText: 'student@vitapstudent.ac.in',
                                prefixIcon: Icon(Icons.email, color: Colors.amber.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your primary email';
                                }
                                if (!_isValidEmail(value.trim())) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Secondary Email Field
                            TextFormField(
                              controller: _secondaryEmailController,
                              decoration: InputDecoration(
                                labelText: 'Secondary Email (Optional)',
                                hintText: 'personal@gmail.com',
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty && !_isValidEmail(value.trim())) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Whitelist Section Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Email Whitelist', Icons.filter_alt),
                            const SizedBox(height: 12),
                            
                            _buildInfoCard(
                              icon: Icons.info_outline,
                              title: 'What is Email Whitelist?',
                              content: 'Only emails from whitelisted addresses will be checked for profile matching. '
                                  'This helps filter placement-related emails from trusted senders like VIT-AP placement cell.',
                              color: Colors.blue.shade50,
                            ),
                            
                            const SizedBox(height: 16),

                            // Add Email Input
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _whitelistEmailController,
                                    decoration: InputDecoration(
                                      labelText: 'Add Email to Whitelist',
                                      hintText: 'example@vitap.ac.in',
                                      prefixIcon: Icon(Icons.add_circle_outline, color: Colors.green.shade700),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    onSubmitted: (_) => _addWhitelistEmail(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _addWhitelistEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Reset to Defaults Button
                            OutlinedButton.icon(
                              onPressed: _resetToDefaults,
                              icon: const Icon(Icons.restore),
                              label: const Text('Reset to Default VIT-AP Emails'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Colors.orange.shade400, width: 2),
                                foregroundColor: Colors.orange.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Whitelisted Emails List
                            if (_whitelistedEmails.isEmpty)
                              _buildInfoCard(
                                icon: Icons.warning_amber,
                                title: 'No Emails Whitelisted',
                                content: 'Add at least one email to enable profile matching. '
                                    'We recommend using the default VIT-AP placement emails.',
                                color: Colors.orange.shade50,
                              )
                            else
                              ...[
                                Text(
                                  'Whitelisted Emails (${_whitelistedEmails.length})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._whitelistedEmails.map((email) => _buildEmailChip(email)),
                              ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save and Cancel Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel', style: TextStyle(fontSize: 16)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Profile',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber.shade700, size: 24),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailChip(String email) {
    final isDefault = email == 'students.cdc.2026@vitap.ac.in' || 
                      email == 'placement@vitap.ac.in';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDefault 
              ? [Colors.blue.shade50, Colors.blue.shade100]
              : [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? Colors.blue.shade300 : Colors.green.shade300,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDefault ? Colors.blue.shade200 : Colors.green.shade200,
          child: Icon(
            isDefault ? Icons.verified : Icons.email,
            color: isDefault ? Colors.blue.shade700 : Colors.green.shade700,
            size: 20,
          ),
        ),
        title: Text(
          email,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDefault ? Colors.blue.shade900 : Colors.green.shade900,
          ),
        ),
        subtitle: isDefault 
            ? Text(
                'Default VIT-AP Email',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontStyle: FontStyle.italic,
                ),
              )
            : null,
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: Colors.red.shade400,
          ),
          onPressed: () => _removeWhitelistEmail(email),
          tooltip: 'Remove from whitelist',
        ),
      ),
    );
  }
}
