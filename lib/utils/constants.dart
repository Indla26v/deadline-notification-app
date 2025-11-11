/// Application-wide constants for Bell Mail Alarm App
library;

/// Database Configuration
class DatabaseConstants {
  static const int emailRetentionDays = 60; // Days to keep emails in cache
  static const int batchInsertSize = 100; // Number of records per batch insert
  static const int defaultEmailLimit = 100; // Default number of emails to fetch
  static const int searchResultsLimit = 500; // Maximum search results
}

/// Background Service Configuration
class BackgroundServiceConstants {
  static const Duration emailCheckInterval = Duration(minutes: 15); // Minimum is 15 on Android
  static const Duration initialDelay = Duration(seconds: 10); // Delay before first check
  static const Duration immediateCheckDelay = Duration(seconds: 5); // Delay for immediate check
}

/// Alarm Configuration
class AlarmConstants {
  static const Duration testAlarmDelay = Duration(seconds: 30); // Test alarm delay
  static const Duration autoAlarmAdvanceTime = Duration(minutes: 20); // How early to set auto-alarms
}

/// Search Configuration
class SearchConstants {
  static const Duration searchDebounceDelay = Duration(milliseconds: 300); // Delay before search executes
}

/// UI Configuration
class UIConstants {
  static const int emailSnippetMaxLength = 500; // Max characters to show in snippets
  static const int listCacheExtent = 1000; // ListView cache extent for smoother scrolling
  static const Duration alertDuration = Duration(seconds: 3); // Default alert duration
  static const Duration successAlertDuration = Duration(seconds: 2); // Success alert duration
}

/// Network Configuration
class NetworkConstants {
  static const int maxEmailsPerFetch = 100; // Max emails to fetch per API call
  static const Duration connectionTimeout = Duration(seconds: 30); // API timeout
}

/// Cache Configuration
class CacheConstants {
  static const Duration permissionCheckDelay = Duration(milliseconds: 500); // Delay between permission checks
  static const Duration signInDelay = Duration(milliseconds: 500); // Delay before auto sign-in
  static const Duration webSocketInitDelay = Duration(seconds: 2); // Delay before WebSocket init
}

/// File Configuration
class FileConstants {
  static const List<String> excelFileExtensions = ['.xlsx', '.xls', '.xlsm', '.csv'];
  static const String tempFilePrefix = 'temp_excel_';
}
