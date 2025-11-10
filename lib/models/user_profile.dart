class UserProfile {
  String name;
  String registrationNumber;
  String primaryEmail;
  String secondaryEmail;
  List<String> whitelistedEmails; // Custom email whitelist

  UserProfile({
    this.name = '',
    this.registrationNumber = '',
    this.primaryEmail = '',
    this.secondaryEmail = '',
    List<String>? whitelistedEmails,
  }) : whitelistedEmails = whitelistedEmails ?? _getDefaultWhitelistedEmails();

  // Default whitelisted emails for VIT-AP
  static List<String> _getDefaultWhitelistedEmails() {
    return [
      'students.cdc.2026@vitap.ac.in',
      'placement@vitap.ac.in',
    ];
  }

  // Convert to JSON for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'registrationNumber': registrationNumber,
      'primaryEmail': primaryEmail,
      'secondaryEmail': secondaryEmail,
      'whitelistedEmails': whitelistedEmails,
    };
  }

  // Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      registrationNumber: json['registrationNumber'] ?? '',
      primaryEmail: json['primaryEmail'] ?? '',
      secondaryEmail: json['secondaryEmail'] ?? '',
      whitelistedEmails: json['whitelistedEmails'] != null 
          ? List<String>.from(json['whitelistedEmails'])
          : _getDefaultWhitelistedEmails(),
    );
  }

  // Check if profile is complete
  bool get isComplete {
    return name.isNotEmpty && 
           registrationNumber.isNotEmpty && 
           (primaryEmail.isNotEmpty || secondaryEmail.isNotEmpty);
  }

  // Check if email sender is whitelisted
  bool isSenderWhitelisted(String senderEmail) {
    if (whitelistedEmails.isEmpty) return true; // If no whitelist, allow all
    
    final senderLower = senderEmail.toLowerCase();
    return whitelistedEmails.any((whitelisted) {
      final whitelistedLower = whitelisted.toLowerCase();
      // Check exact match or if sender contains whitelisted email
      return senderLower.contains(whitelistedLower) || 
             whitelistedLower.contains(senderLower);
    });
  }

  // Check if email body or subject contains profile information
  // Now also checks if sender is whitelisted
  bool matchesEmail(String subject, String body, String senderEmail) {
    // First check if sender is whitelisted
    if (!isSenderWhitelisted(senderEmail)) {
      return false; // Not from whitelisted sender, skip profile matching
    }

    if (!isComplete) return false;

    final searchText = '$subject $body'.toLowerCase();
    
    // More flexible name matching - check each part independently
    final nameParts = name.trim().split(RegExp(r'\s+'))
        .where((p) => p.length > 2) // Skip initials and short words
        .map((p) => p.toLowerCase())
        .toList();
    
    int nameMatchCount = 0;
    for (final part in nameParts) {
      if (searchText.contains(part)) {
        nameMatchCount++;
      }
    }
    
    // Consider it a name match if at least 2 parts match (e.g., first + last name)
    final nameMatches = nameMatchCount >= 2 || 
                       (nameParts.length == 1 && nameMatchCount == 1); // Single name case
    
    // Check for registration number (handle different formats)
    final regNoMatch = registrationNumber.isNotEmpty && (
        searchText.contains(registrationNumber.toLowerCase()) ||
        searchText.contains(registrationNumber.toLowerCase().replaceAll(' ', '')) ||
        searchText.contains(registrationNumber.toLowerCase().replaceAll('-', ''))
    );
    
    // Check for emails (handle different formats)
    final primaryEmailMatch = primaryEmail.isNotEmpty && (
        searchText.contains(primaryEmail.toLowerCase()) ||
        searchText.contains(primaryEmail.toLowerCase().split('@')[0]) // Username part
    );
    
    final secondaryEmailMatch = secondaryEmail.isNotEmpty && (
        searchText.contains(secondaryEmail.toLowerCase()) ||
        searchText.contains(secondaryEmail.toLowerCase().split('@')[0]) // Username part
    );
    
    // More lenient matching:
    // 1. Registration number alone is enough (most reliable)
    // 2. Name match + any email match
    // 3. Both emails match
    // 4. Registration number partial + name match
    return regNoMatch || 
           (nameMatches && (primaryEmailMatch || secondaryEmailMatch)) ||
           (primaryEmailMatch && secondaryEmailMatch) ||
           (nameMatchCount >= 1 && regNoMatch);
  }
}
