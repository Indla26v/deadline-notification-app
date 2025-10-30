# 🔔 Bell - Smart Email Alarm Manager# Mail Alarm



<p align="center">Flutter app that connects to Gmail, detects event times in emails, and lets users set one-tap alarms that open the Gmail message when they trigger.

  <img src="assets/bell_icon.png" alt="Bell App Icon" width="120"/>

</p>## Prerequisites

- Flutter (latest stable)

**Bell** is an intelligent Flutter-based mobile application that reads your Gmail, automatically detects important emails and meeting times, and helps you schedule alarms so you never miss what matters.- Android device or emulator

- VS Code recommended

## ✨ Features

## Google Cloud Setup

### 📧 Smart Email Management1. Create a Google Cloud Project.

- **Gmail Integration**: Secure OAuth2 sign-in with Google2. Enable the Gmail API.

- **Instant Loading**: Local SQLite database caches emails for 2 months3. Create OAuth 2.0 Client ID (Android or Desktop for testing).

- **Thread Support**: View email conversations with proper threading4. Download `client_secret.json` and place it at `assets/client_secret.json` (replace the placeholder).

- **HTML Rendering**: Rich email content display with images and formatting

- **Universal Search**: Fast database-backed search across all cached emails (with 300ms debounce)## Run

- **Read/Unread Sync**: Automatic synchronization with Gmail status```bash

flutter pub get

### ⭐ Intelligent Detectionflutter run

- **Profile Matching**: Automatically marks emails containing your personal information as "Very Important"```

- **Excel Scanning**: Analyzes Excel attachments to detect your name, registration number, or email

- **First-Time Setup**: On initial sign-in, scans entire inbox for profile matches## Notes

- **Smart Categorization**: Three filter tabs - All, Very Important, Alarms- On Android 13+, the app requests notification permission on first run.

- On Android 12+, the app requests exact alarm permission to schedule precise alarms.

### ⏰ Alarm Features- Sign in with Google, the app loads last 20 inbox messages, detects times, and schedules a notification that opens the Gmail web link when tapped.

- **Time Detection**: Parses email content to detect dates and times

- **Auto-Scheduling**: Automatically sets alarms 20 minutes before detected times for important emails
- **System Integration**: Creates native Android alarms in the Clock app
- **Custom Alarms**: Manual alarm creation and editing with date/time picker
- **Notification Handling**: Click notifications to open specific email details

### 🎨 Modern UI/UX
- **Glassy Design**: Beautiful frosted glass effects on search bar and buttons
- **Gmail-like Interface**: Familiar read/unread visual indicators
- **Custom Bell Icon**: Brand-consistent icon throughout the app
- **Scroll to Top**: Glassy floating button for quick navigation
- **Responsive**: Smooth animations and instant feedback

### 🔄 Background Features
- **Periodic Checks**: Background worker checks for new emails every 15 minutes
- **Instant Notifications**: Immediate alerts for very important emails
- **Smart Notifications**: Bell-branded notifications with gold/red color coding

## 🛠️ Tech Stack

- **Framework**: Flutter 3.4+
- **Language**: Dart
- **Database**: SQLite (sqflite)
- **Authentication**: Google Sign-In + OAuth2
- **APIs**: Gmail API (googleapis)
- **Background Tasks**: workmanager
- **Notifications**: flutter_local_notifications
- **HTML Rendering**: flutter_html
- **File Parsing**: excel package for .xlsx/.xls files
- **State Management**: Provider pattern

## 📱 Requirements

- Android 6.0 (API 23) or higher
- Google account with Gmail access
- Internet connection for email sync
- Storage permissions for attachment downloads

## 🚀 Installation

### Prerequisites
1. Install [Flutter](https://flutter.dev/docs/get-started/install) (3.4.0 or higher)
2. Set up Android Studio or VS Code with Flutter extensions
3. Connect an Android device or emulator

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/bell.git
   cd bell
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Google OAuth**
   - Create a project in [Google Cloud Console](https://console.cloud.google.com)
   - Enable Gmail API
   - Create OAuth 2.0 credentials (Android)
   - Download `client_secret.json` and place it in `assets/` folder
   - Update `android/app/src/main/AndroidManifest.xml` with your OAuth client ID

4. **Generate launcher icons**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

5. **Build and run**
   ```bash
   flutter run
   # or for release build
   flutter build apk --release
   ```

## 📖 Usage

### First Time Setup
1. **Sign In**: Tap "Sign in with Google" and authorize Gmail access
2. **Welcome Dialog**: You'll see a welcome prompt to set up your profile
3. **Profile Configuration**: Enter your name, registration number, and email addresses
4. **Auto-Scan**: Bell scans all emails and marks matches as "Very Important"

### Managing Emails
- **Browse**: Swipe through the email list with smooth scrolling
- **Search**: Use the floating search bar to find emails across your entire cache
- **Filter**: Switch between All, Very Important (⭐), and Alarms (⏰) tabs
- **Read Email**: Tap any email to view full content with threading support

### Setting Alarms
- **Auto-Alarms**: Bell automatically sets alarms for important emails with detected times
- **Manual Creation**: 
  - Tap "Add Alarm" on any email card
  - Or use the menu (⋮) in email detail view
  - Bell parses dates like "8th November at 8:30 am"
- **Edit/Remove**: Use card buttons or detail screen menu

### Profile Matching
- **What It Detects**: Name, registration number, primary/secondary emails
- **Where It Looks**: Email subject, body, and Excel attachments (.xlsx, .xls, .csv)
- **Marking Important**: Use the menu in detail view to manually add/remove

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry point, global navigation
├── models/
│   ├── email_model.dart              # Email data model with threading
│   └── user_profile.dart             # User profile for matching
├── screens/
│   ├── home_page.dart                # Main email list with filters & search
│   ├── email_detail_screen.dart      # Email detail with HTML & menu
│   └── edit_profile_screen.dart      # Profile editing form
├── services/
│   ├── gmail_service.dart            # Gmail API integration
│   ├── email_database.dart           # SQLite operations
│   ├── alarm_service.dart            # Alarm scheduling & notifications
│   ├── background_email_service.dart # Background worker
│   └── profile_service.dart          # Profile storage
└── widgets/
    └── bell_icon.dart                # Custom painted bell icon

assets/
├── bell_icon.png                     # App launcher icon
└── client_secret.json                # Google OAuth credentials (not in repo)

android/                               # Android-specific configuration
```

## 🔐 Privacy & Security

- **Local First**: Emails are cached locally in encrypted SQLite database
- **OAuth2**: Secure Google authentication (no password storage)
- **Permissions**: Only requests necessary permissions (Internet, Notifications, Alarms)
- **Data Retention**: Auto-deletes emails older than 60 days
- **No Tracking**: No analytics or third-party data sharing

## 🎨 Customization

### Change Bell Color
Edit `lib/screens/home_page.dart` and `lib/widgets/bell_icon.dart`:
```dart
color: Color(0xFFFFC107), // Current amber/gold
```

### Adjust Cache Duration
In `lib/screens/home_page.dart`:
```dart
await _emailDatabase.deleteOldEmails(60); // Days to keep
```

### Background Check Frequency
In `lib/services/background_email_service.dart`:
```dart
frequency: const Duration(minutes: 15), // Minimum is 15 minutes on Android
```

## 🐛 Known Limitations

- **Android Only**: iOS not currently supported (requires different alarm APIs)
- **Background Limits**: Android 12+ restricts background tasks to save battery
- **Excel Parsing**: Large Excel files (>5MB) may take time to scan
- **Alarm Management**: Alarms are created in system Clock app (cannot be canceled from Bell)

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Dart style guidelines
- Add comments for complex logic
- Test on multiple Android versions
- Update README for new features

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Google for Gmail API and OAuth2 services
- Contributors to packages: sqflite, workmanager, flutter_html, excel, and more

## 📧 Contact

For questions, suggestions, or issues:
- Open an issue on GitHub
- Email: your.email@example.com

## 🗺️ Roadmap

- [ ] iOS support
- [ ] Push notifications via Gmail Pub/Sub
- [ ] Calendar integration
- [ ] Dark mode
- [ ] Multiple account support
- [ ] Custom notification sounds
- [ ] Backup/Restore functionality
- [ ] Widget support

---

**Made with ❤️ using Flutter**

*Never miss an important email again with Bell! 🔔*
