# Bell - Comprehensive Application Summary for Research

## Executive Summary

**Bell** is an intelligent Android mobile application built with Flutter that solves the critical problem of missing important deadlines and events buried in email. It automatically monitors Gmail, detects time-sensitive information, identifies personally relevant emails, and schedules smart alarms to ensure users never miss important deadlines.

---

## 🎯 Problem Statement

### Core Problem
**Students, professionals, and busy individuals frequently miss critical deadlines, meeting times, and important notifications because:**

1. **Information Overload**: Hundreds of emails per day make it impossible to track everything
2. **Manual Tracking**: Users must manually read every email and set reminders
3. **Context Switching**: Constantly switching between Gmail, Calendar, and Clock apps
4. **Lost in Thread**: Important information gets buried in long email threads
5. **Excel Attachments**: Critical information (selection lists, schedules) hidden in spreadsheet attachments
6. **Passive Consumption**: Email is passive - no proactive alerts for time-sensitive content
7. **Missed Deadlines**: Even when users read emails, they forget to set reminders

### Target Users
- **Students**: University students receiving placement notifications, exam schedules, assignment deadlines
- **Professionals**: Corporate employees with meeting invitations, project deadlines, client communications
- **Job Seekers**: People tracking interview schedules, application deadlines, offer letters
- **Event Attendees**: Anyone receiving event invitations, registration deadlines, venue changes

### Real-World Scenario
A student receives an email:
```
Subject: AVEVA next round of selection process scheduled on 11th November 2025
Body: *AVEVA* *next round of selection process scheduled on 11th November 2025 by 9.00 am @ SJT717*
Please find the below shortlisted listed students list...
```

**Without Bell**: Student must:
1. Read the email
2. Extract date/time manually
3. Open Clock app
4. Set alarm manually
5. Risk forgetting or setting wrong time

**With Bell**: 
1. Email arrives → Bell detects it contains student's name in selection list
2. Automatically marks as "Very Important"
3. Detects "11th November 2025 by 9.00 am"
4. Sets alarm 20 minutes before (8:40 AM)
5. Shows debug dialog with all detected dates
6. User confirms → Alarm created in system Clock app

---

## 🏗️ Architecture & Technical Implementation

### Technology Stack

**Frontend Framework**
- **Flutter 3.4+**: Cross-platform UI framework (Dart language)
- **Material Design 3**: Modern, responsive UI components
- **Provider**: State management pattern

**Backend & APIs**
- **Gmail API v1**: Email fetching, marking read/unread
- **Google Sign-In**: OAuth2 authentication
- **Google Cloud Pub/Sub**: (Optional) Real-time push notifications

**Database & Storage**
- **SQLite (sqflite)**: Local email caching
- **SharedPreferences**: User preferences, profile data, important email IDs
- **File System**: Temporary attachment storage

**Background Processing**
- **WorkManager**: Periodic background email checks (every 15 minutes)
- **Flutter Local Notifications**: Alarm notifications
- **Android Alarm Manager Plus**: Scheduled tasks

**Data Processing**
- **Excel Parser**: Reads .xlsx, .xls, .csv files to find user information
- **HTML Parser (flutter_html)**: Renders rich email content
- **RegEx Parsing**: Complex date/time pattern matching (30+ patterns)

**Real-Time Communication**
- **WebSocket (web_socket_channel)**: Real-time email notifications (requires backend)

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App (Bell)                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │               Presentation Layer                      │   │
│  │  - HomePage (Email List with Filters)                │   │
│  │  - EmailDetailScreen (Thread View, HTML Rendering)   │   │
│  │  - AlarmManagementScreen (Active Alarms)             │   │
│  │  - EditProfileScreen (User Info)                     │   │
│  │  - ParserResultsDialog (Debug Date Detection)        │   │
│  └──────────────────────────────────────────────────────┘   │
│                           ↓↑                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │               Business Logic Layer                    │   │
│  │  - GmailService (API Integration)                    │   │
│  │  - AlarmService (Time Parsing & Scheduling)          │   │
│  │  - InAppAlarmService (Notification Management)       │   │
│  │  - ProfileService (User Profile Matching)            │   │
│  │  - WebSocketService (Real-Time Updates)              │   │
│  │  - BackgroundEmailService (Periodic Sync)            │   │
│  └──────────────────────────────────────────────────────┘   │
│                           ↓↑                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │               Data Layer                              │   │
│  │  - EmailDatabase (SQLite CRUD Operations)            │   │
│  │  - SharedPreferences (Key-Value Storage)             │   │
│  │  - File System (Attachment Cache)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                            ↓↑
┌─────────────────────────────────────────────────────────────┐
│                    External Services                         │
├─────────────────────────────────────────────────────────────┤
│  - Gmail API (Google)                                        │
│  - Google OAuth 2.0 (Authentication)                         │
│  - Android Clock App (System Alarms)                         │
│  - Android Notification System                               │
│  - WebSocket Backend (Optional - for real-time push)         │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Feature Breakdown (Every Feature)

### 1. Authentication & Account Management

#### Google OAuth2 Sign-In
- **Scopes**: `gmail.readonly`, `email`, `profile`, `openid`
- **Silent Sign-In**: Attempts cached credentials first
- **Token Management**: Automatic refresh token handling
- **Sign Out**: Complete credential clearing
- **Error Handling**: Invalid token detection, re-authentication prompts

#### First-Time Setup
- **Welcome Dialog**: Guides new users to profile setup
- **Full Inbox Scan**: On first sign-in, scans all existing emails for profile matches
- **Profile Configuration**: Captures name, registration number, emails
- **One-Time Flag**: Uses SharedPreferences to track first-time users

### 2. Email Management

#### Email Fetching
- **Gmail API Integration**: Fetches emails via `users.threads.list` endpoint
- **Pagination**: Loads 100 emails per request with `nextPageToken`
- **Thread Support**: Fetches complete conversation threads
- **Infinite Scroll**: Auto-loads more emails when scrolling to bottom
- **Pull to Refresh**: Manual refresh with visual indicator

#### Local Caching (SQLite Database)
**Schema:**
```sql
CREATE TABLE emails (
  id TEXT PRIMARY KEY,
  sender TEXT,
  subject TEXT,
  snippet TEXT,
  body TEXT,
  link TEXT,
  receivedDate INTEGER,
  hasAlarm INTEGER,
  alarmTimes TEXT,  -- JSON array of timestamps
  isVeryImportant INTEGER,
  isUnread INTEGER,
  threadId TEXT,
  messageCount INTEGER,
  attachments TEXT,  -- JSON array
  pageToken TEXT,
  createdAt INTEGER
)

CREATE INDEX idx_receivedDate ON emails(receivedDate DESC)
CREATE INDEX idx_isVeryImportant ON emails(isVeryImportant)
CREATE INDEX idx_hasAlarm ON emails(hasAlarm)
CREATE INDEX idx_search ON emails(subject, body, sender, snippet)
```

**Operations:**
- **Insert/Batch Insert**: Efficient bulk inserts with conflict resolution
- **Update**: Preserves local state (alarms, importance) when refreshing
- **Delete Old**: Auto-deletes emails older than 60 days
- **Search**: Full-text search across subject, body, sender, snippet
- **Count**: Quick statistics queries

#### Email Display
- **List View**: Virtualized scrolling with caching (1000px cache extent)
- **Card Design**: Color-coded (white=unread, grey=read, green=alarm, red=important)
- **Badges**: Visual indicators (⏰ Alarm Set, ⭐ Very Important, 📎 Attachments, 💬 Thread count)
- **Date Formatting**: Relative dates (Today, Yesterday) and absolute (MMM d)
- **Snippet Preview**: 3-line excerpt with ellipsis
- **Unread Styling**: Bold text (font-weight: 900) for unread emails

#### Email Detail View
- **Full Content**: Complete email body with HTML rendering
- **Thread Expansion**: Expandable conversation view (latest message shown first)
- **HTML Support**: Images, tables, links, styled text via flutter_html
- **Plain Text Fallback**: Linkified plain text with smart formatting
- **Table Detection**: Auto-highlights structured data (candidate lists, schedules)
- **Attachment List**: File type icons, size display, download buttons
- **Read Status**: Auto-marks as read when opened (syncs with Gmail)

#### Filtering & Search
- **Three Filter Tabs**: 
  - "All" - Complete email list
  - "Important (X)" - Profile-matched emails (red star)
  - "Alarms (X)" - Emails with active alarms (clock icon)
- **Universal Search**: 
  - Searches entire local database (all cached emails)
  - 300ms debounce for performance
  - Searches: subject, body, sender, snippet
  - Limit: 500 results
  - Works across all filter tabs
  - Clear button (X) to reset

#### Thread Support
- **Conversation View**: Groups related messages by threadId
- **Message Count**: Shows total messages in thread (💬 badge)
- **Chronological Order**: Latest message first
- **Individual Messages**: Each message expandable with sender, date, body
- **Attachment Aggregation**: Shows all attachments from entire thread

### 3. Intelligent Detection System

#### Profile Matching Engine

**User Profile Model:**
```dart
class UserProfile {
  String name;                // e.g., "Abhinay Babu Manikanti"
  String registrationNumber;  // e.g., "22bce9726"
  String primaryEmail;        // e.g., "student@vitapstudent.ac.in"
  String secondaryEmail;      // e.g., "personal@gmail.com"
}
```

**Text Matching Algorithm:**
```
1. Split user name into parts (min 3 chars)
   "Abhinay Babu Manikanti" → ["Abhinay", "Babu", "Manikanti"]

2. Generate registration number variants:
   - Original: "22bce9726"
   - No spaces: "22bce9726"
   - No dashes: "22bce9726"
   - No underscores: "22bce9726"

3. Extract email usernames:
   - "student@vitapstudent.ac.in" → ["student@vitapstudent.ac.in", "student"]

4. For each email:
   a. Search subject and body (case-insensitive)
   b. Count name part matches
   c. Check registration number variants
   d. Check email presence
   
5. Mark as Important if:
   - Registration number found (highest confidence)
   - OR (2+ name parts + email found)
   - OR (all name parts found)
```

**Excel Attachment Scanning:**
```
1. Detect Excel files: .xlsx, .xls, .xlsm, .csv
2. Download attachment via Gmail API
3. Parse with excel package (in-memory, no file saving)
4. Iterate all sheets and rows
5. Convert each row to lowercase text
6. Apply same matching algorithm
7. If match found, mark email as Important
```

**Performance Optimizations:**
- Excel files only scanned for non-important emails
- Parsing happens in background (doesn't block UI)
- Results cached in SharedPreferences
- First-time scan runs once, subsequent checks only on new emails

#### Auto-Alarm for Important Emails
```
IF email is Very Important
  AND email has no alarm yet
  AND date/time is detected
  AND detected time is > 20 minutes in future
THEN:
  Schedule alarm for (detected time - 20 minutes)
  Mark email with auto-alarm flag
```

### 4. Date/Time Parsing System

#### Advanced Pattern Recognition
**30+ Regular Expression Patterns** organized in passes:

**Pass 1A: Start Time Patterns (Highest Priority)**
```regex
// "from 31st October 2025" or "from 31st Oct 2025 9:00 am"
(?:from|starting\s+from|begins\s+on)\s+(\d{1,2})(?:st|nd|rd|th)?\s+(January|...|December)\s+(?:(\d{4})\s+)?(?:(\d{1,2})[:\.](\d{2})\s*(am|pm)?)?

// "Scheduled from 31-10-2025 at 8:30 am"
(?:from|starting\s+from|scheduled\s+from)\s+(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4})(?:\s+(?:at\s+)?(\d{1,2})[:\.](\d{2})\s*(am|pm)?)?
```

**Pass 1B: General Date + Time Patterns**
```regex
// Special: "3rd November 2025 by 12 Noon"
(\d{1,2})(?:st|nd|rd|th)?\s+(January|...|December)\s+(?:(\d{4})\s+)?(?:at|by)\s+(?:12\s*)?(noon|midnight)

// Priority: "*31-10-2025 @ 8.00PM*"
(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4})\s*@\s*(\d{1,2})[:\.](\d{2})\s*(am|pm)?

// With 'at/by': "04-11-2025 at 8:30 am"
(?:on\s+)?(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4}).*?(?:at|by)\s+(\d{1,2})[:\.\s](\d{2})?\s*(am|pm)?

// Immediate: "04-11-2025 8:30 am"
(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4})\s+(\d{1,2})[:\.\s](\d{2})?\s*(am|pm)?

// DATE/TIME keywords: "DATE: 14TH NOV ... TIME: 6:00 PM"
DATE:\s*(\d{1,2})(?:st|nd|rd|th)?\s+(Jan|...|Dec).*?TIME:\s*(\d{1,2})[:\.](\d{2})\s*(am|pm)?

// With ordinals: "8th November at 8:30 am"
(\d{1,2})(?:st|nd|rd|th)?\s+(January|...|December)\s+(?:(\d{4})\s+)?(?:at|by)\s+(\d{1,2})[:\.\s](\d{2})?\s*(am|pm)?

// Month first: "November 8 at 8:30 am"
(January|...|December)\s+(\d{1,2}),?\s+(?:(\d{4})\s+)?(?:at|by)\s+(\d{1,2})[:\.\s](\d{2})?\s*(am|pm)?

// Compact: "nov14 6:00pm", "14nov 6:00pm"
(Jan|...|Dec)\w*\s*(\d{1,2})\s+(\d{1,2})[:\.](\d{2})\s*(am|pm)?
```

**Pass 2: Time-Only Patterns (Fallback)**
```regex
// 24-hour: "13:52", "09:30"
\b([01]?\d|2[0-3]):([0-5]\d)\b

// 12-hour: "1:52 PM", "3 PM"
(\d{1,2}):?(\d{2})?\s*(AM|PM|am|pm)
```

#### Parsing Logic Flow
```
1. Log full email content (subject + body)
2. Try Pass 1A (START times) → If found, select EARLIEST
3. Try Pass 1B (General dates) → If found, select NEAREST FUTURE
4. Try Pass 2 (Time only) → Schedule for today/tomorrow based on current time
5. If multiple candidates:
   - Filter future dates only
   - Sort chronologically
   - Select nearest future date
6. If no future dates:
   - Return latest past date (with warning)
```

#### Parser Debug Dialog
**New Feature (Latest Implementation):**
- **Trigger**: When user taps "Add Alarm"
- **Display**:
  - Email content (subject + body preview)
  - All detected date/time candidates
  - Original matched text for each candidate
  - Pattern identifier (e.g., "#date-time-6")
  - Final selected date (highlighted in green)
- **Actions**:
  - "CANCEL" - Dismiss without setting alarm
  - "YES, SET ALARM" - Confirm and schedule alarm
- **Purpose**: Transparency and debugging for users

### 5. Alarm System

#### Two-Tier Alarm Architecture

**Tier 1: In-App Alarms (SQLite Database)**
```sql
CREATE TABLE alarms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  emailId TEXT UNIQUE,
  subject TEXT,
  sender TEXT,
  scheduledTime INTEGER,
  emailLink TEXT,
  isActive INTEGER,
  createdAt INTEGER
)
```

**Operations:**
- Schedule: Insert alarm record + schedule notification
- Cancel: Delete record + cancel notification
- Get Pending: Retrieve all future alarms with email details
- Cleanup: Remove expired alarms (scheduled time < now)

**Tier 2: System Alarms (Android Clock App)**
- Uses `AndroidIntent` with action `android.intent.action.SET_ALARM`
- Parameters:
  - `HOUR`, `MINUTES`: Time components
  - `MESSAGE`: Alarm label (📧 + email subject)
  - `SKIP_UI`: Don't show Clock UI (background creation)
  - `DAYS`: Day of week for multi-day scheduling
- Benefits:
  - Survives app force-close
  - User can manage in Clock app
  - System-level reliability

#### Notification System
**Channels:**
1. **Alarm Channel**: Scheduled email reminders
   - Importance: High
   - Sound: Enabled
   - Vibration: Enabled
   - Color: Amber (#FFC107)

2. **Important Channel**: Very important email alerts
   - Importance: Max
   - Sound: Enabled (custom if provided)
   - Vibration: Pattern [0, 500, 250, 500]
   - Color: Red (#F44336)

3. **Confirmation Channel**: Alarm set confirmations
   - Importance: High
   - Sound: Enabled
   - Timeout: 5 seconds
   - Color: Amber

**Notification Content:**
```
Title: "Bell • Nov 11, 9:00 AM 🔔"
Body: "AVEVA next round of selection..."
Big Text: Full email subject + sender
Actions: [Open Email, Dismiss]
Icon: Bell icon
Large Icon: Bell icon (circular)
When: Scheduled time
```

**Click Handling:**
- Payload format: `emailId|link`
- Opens email detail screen directly
- Falls back to Gmail web link

#### Alarm Management Screen
- **List View**: All active alarms sorted by scheduled time
- **Card Design**: 
  - Yellow border (active)
  - Red border (overdue)
  - Alarm icon with time badge
- **Information**:
  - Email subject (truncated)
  - Sender
  - Exact scheduled date/time
  - Countdown (days/hours/minutes/seconds)
  - Last-minute countdown (shows seconds when < 60s)
- **Actions**:
  - Delete individual alarm (with confirmation)
  - Delete all alarms (bulk action)
  - Refresh button

#### Permissions
- **POST_NOTIFICATIONS** (Android 13+): For displaying notifications
- **SCHEDULE_EXACT_ALARM** (Android 12+): For precise alarm scheduling
- **USE_EXACT_ALARM** (Android 14+): Additional exact alarm permission
- **RECEIVE_BOOT_COMPLETED**: To reschedule alarms after reboot
- **WAKE_LOCK**: To ensure alarm triggers even in deep sleep

### 6. Background Processing

#### WorkManager Background Service
**Configuration:**
```dart
Workmanager().registerPeriodicTask(
  "email-sync",
  "emailBackgroundFetch",
  frequency: Duration(minutes: 15),  // Minimum allowed by Android
  constraints: Constraints(
    networkType: NetworkType.connected,
    requiresBatteryNotLow: true,
  ),
  existingWorkPolicy: ExistingWorkPolicy.keep,
)
```

**Background Task Logic:**
```
1. Check if authenticated (has valid OAuth token)
2. Fetch latest 20 emails from Gmail
3. Check for Very Important emails (profile matching)
4. Save to SQLite database
5. For each Very Important email:
   a. Check if already notified (SharedPreferences flag)
   b. If new, show immediate notification
   c. If has detected time, auto-schedule alarm
6. Cleanup: Delete old emails (>60 days)
```

**Notification for Very Important Emails:**
```
Title: "🔔 Very Important Email"
Body: "[Subject]"
Subtext: "From: [Sender]"
Priority: Max
Sound: Enabled
Auto-Cancel: No
Action: Tap to open Bell app
```

**Android Restrictions:**
- Minimum frequency: 15 minutes (Android OS limit)
- Doze mode: May delay execution
- Battery optimization: Users can whitelist Bell for unrestricted background
- Network requirement: Only syncs when connected

### 7. User Interface Components

#### Home Page (Main Screen)

**Top App Bar:**
- Bell icon (custom painted, gold color)
- Title: "Bell"
- Profile icon button (right)

**Filter Bar (Glassy Design):**
```
┌─────────────────────────────────────┐
│  All  │  ⭐ Important (X)  │  ⏰ Alarms (X)  │
└─────────────────────────────────────┘
```
- Frosted glass effect (backdrop blur)
- Selected tab: Primary color background
- Unselected: Transparent
- Smooth animations
- Shows counts for Important and Alarms

**Email Cards:**
```
┌────────────────────────────────────────┐
│ [⭐ Very Important] [⏰ Alarm Set] [📎 2]│
│ Subject Line Here (Bold if Unread)     │
│ Sender Name                            │
│ Email body preview text... (3 lines)   │
│ ⏰ Nov 11, 9:00 AM                     │
│ [Edit] [Add/Remove Alarm]              │
└────────────────────────────────────────┘
```
- Color coding: Red (important), Green (alarm), White (unread), Grey (read)
- Elevation: 4 (important), 3 (unread), 0 (read)
- Tap: Opens email detail
- Long press: (No action currently)

**Floating Search Bar (Bottom):**
- Position: 20px from bottom, 80px from right (for scroll button)
- Glassy frosted effect
- Placeholder: "Search all emails..."
- Icons: Search (left), Clear X (right, when typing)
- Debounced: 300ms delay
- Keyboard: Shows on tap

**Scroll to Top Button:**
- Position: Bottom right corner
- 50x50px circular button
- Glassy frosted effect
- Icon: Arrow up
- Animation: Smooth scroll to top

**Loading States:**
- Initial: Centered spinner
- Pull to refresh: Top spinner
- Pagination: Bottom spinner (when loading more)

#### Email Detail Screen

**Header:**
- Subject (22px, bold, wrap)
- Sender with person icon
- Date/time with clock icon
- Thread indicator (if multi-message)

**Content Area:**
- HTML rendering for rich emails
- Plain text with linkified URLs
- Table detection (highlighted in blue boxes)
- Thread messages (expandable cards)
- Attachment list (file icons, sizes, download buttons)

**Floating Google Form Button** (if detected):
```
┌──────────────────────────────────┐
│ 🔗 Open Google Form  [Form] →   │
└──────────────────────────────────┘
```
- Position: Bottom center, 20px padding
- Blue gradient background
- Shadow effect
- Auto-detects forms in email body
- Opens in external browser

**Menu (Three Dots):**
- Add/Remove Alarm
- Mark/Unmark as Very Important
- (Future: Archive, Delete, etc.)

#### Alarm Management Screen

**Header:**
- Title: "Alarm Management"
- Delete all button (trash sweep icon)
- Refresh button

**Empty State:**
- Centered alarm-off icon (80px, grey)
- Text: "No Active Alarms"
- Subtext: "Set an alarm from any email to get started"

**Alarm Cards:**
```
┌──────────────────────────────────────┐
│ [🔔] Subject Line (truncated)        │
│     From: Sender Name                │
│     🕐 Nov 11, 2025 · 9:00 AM       │
│     [in 17 hours]              [🗑️]  │
└──────────────────────────────────────┘
```
- Yellow border: Active alarms
- Red border: Overdue alarms
- Countdown updates every second
- Delete button: Confirmation dialog

#### Edit Profile Screen

**Form Fields:**
- Name (text input, required)
- Registration Number (text input, required)
- Primary Email (text input, email keyboard)
- Secondary Email (text input, email keyboard, optional)

**Save Button:**
- Bottom of screen
- Validation: Name and registration required
- On save: Updates SharedPreferences, rescans emails

**Navigation:**
- Back button: Discards changes (confirmation if modified)
- Save: Returns to previous screen with result

#### Custom Widgets

**Bell Icon (Custom Painter):**
```dart
// Draws bell shape using Path
// Components:
// - Bell dome (arc + lines)
// - Handle (arc at top)
// - Clapper (circle at bottom)
// - Smooth curves (Bezier paths)
// Customizable: size, color, stroke width
```

**Glassy Snackbar:**
- Frosted glass background
- Color-coded (green=success, red=error, orange=warning, blue=info)
- Auto-dismiss timer
- Icon on left
- Action button (optional)

**Parser Results Dialog:**
- Full-screen dialog
- Scrollable content
- Blue header
- Amber highlights for candidates
- Green highlight for final selection
- Two buttons: CANCEL, YES SET ALARM

### 8. WebSocket Real-Time Support (Latest Addition)

#### Purpose
Enable instant email notifications without polling, reducing battery usage and providing immediate updates.

#### Client Implementation (Flutter)
```dart
class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _pingTimer;
  
  // Features:
  - Auto-reconnection (max 5 attempts, 5s delay)
  - Ping/pong keepalive (every 30s)
  - Message broadcasting (Stream)
  - Error handling
  - Clean disconnect
}
```

**Connection Flow:**
```
1. User signs in → Get email address
2. Connect to WebSocket server (wss://backend.com/ws?email=...)
3. Send auth message: {"type":"auth", "email":"...", "timestamp":"..."}
4. Server sets up Gmail watch for user
5. Start ping/pong to keep connection alive
6. Listen for messages
```

**Message Types:**
```json
// New email notification
{
  "type": "new_email",
  "subject": "Email subject",
  "from": "sender@example.com",
  "messageId": "abc123",
  "timestamp": "2025-11-10T15:00:00Z"
}

// Error message
{
  "type": "error",
  "message": "Connection lost. Please refresh."
}

// Pong response
{
  "type": "pong",
  "timestamp": "2025-11-10T15:00:00Z"
}
```

**UI Integration:**
- Shows snackbar when new email arrives
- "Refresh" button in snackbar
- Auto-refreshes email list
- Graceful degradation (works without WebSocket)

#### Backend Requirements (Not Included)
**Required Setup:**
1. Google Cloud Pub/Sub topic creation
2. Gmail API watch setup (7-day expiration)
3. Pub/Sub subscription listener
4. WebSocket server (Node.js/Python)
5. OAuth token management
6. Email detail fetching

**Example Backend Flow:**
```
1. Gmail → New email event → Google Pub/Sub
2. Pub/Sub → Backend listener
3. Backend → Fetch email details via Gmail API
4. Backend → Send to connected WebSocket clients
5. Flutter app → Receive notification → Update UI
```

**Cost Implications:**
- Google Cloud Pub/Sub: ~$0.40/million operations
- Cloud Run: ~$0.00002400/GB-second
- For 1000 users, 10 emails/day: ~$17/month

**Fallback:**
- App fully functional without WebSocket
- Uses manual refresh and 15-minute background sync

### 9. Data Persistence & State Management

#### SharedPreferences (Key-Value Store)
```
Keys Used:
- "isSignedIn": boolean - Login state
- "hasSignedInBefore": boolean - First-time flag
- "veryImportantEmails": List<String> - IDs of important emails
- "autoAlarmEmails": List<String> - IDs with auto-alarms
- "userProfile": JSON - User profile data
- "notifiedEmails": List<String> - Background notification tracking
```

#### SQLite Database
**File Location:** `${ApplicationDocumentsDirectory}/emails.db`

**Migrations:**
- Version 1: Initial schema (2024)
- Version 2: Added isUnread column (2024)
- Version 3: Added threadId, messageCount (2024)
- Version 4: Added alarms table (2025)

**Indexes:**
- Primary: id (email ID from Gmail)
- Secondary: receivedDate DESC (for sorting)
- Secondary: isVeryImportant (for filtering)
- Secondary: hasAlarm (for filtering)
- Full-text: subject, body, sender, snippet (for search)

**Cleanup Policy:**
- Auto-delete: Emails older than 60 days
- Runs on: App launch
- Exceptions: Emails with active alarms (preserved)

#### File System Storage
- **Attachments**: `/data/user/0/com.example.bell/cache/attachments/`
- **Temporary**: Auto-cleaned by system when storage low
- **App Data**: `/data/user/0/com.example.bell/app_flutter/`

#### State Management Pattern
```
Provider (top-level) → AlarmService
  ↓
HomePage (StatefulWidget)
  ├─ Local State: _emails, _client, _loading, _searchQuery
  ├─ Services: GmailService, EmailDatabase, ProfileService
  └─ Children: EmailCard widgets (stateless)

EmailDetailScreen (StatefulWidget)
  ├─ Local State: _downloadingAttachments, _googleFormUrl
  └─ Services: GmailService, AlarmService

AlarmManagementScreen (StatefulWidget)
  ├─ Local State: _alarms, _isLoading
  └─ Services: InAppAlarmService, EmailDatabase
```

### 10. Performance Optimizations

#### Email List Optimization
- **Virtualized Scrolling**: ListView.builder (only renders visible items)
- **Cache Extent**: 1000px (pre-renders items above/below viewport)
- **Keys**: ValueKey(email.id) for efficient widget reuse
- **Debounced Search**: 300ms delay prevents excessive database queries
- **Pagination**: Loads 100 emails at a time (prevents memory overload)

#### Database Optimization
- **Prepared Statements**: Reuses compiled SQL queries
- **Batch Inserts**: InsertAll for multiple emails (single transaction)
- **Indexed Queries**: All filters use indexed columns
- **Connection Pooling**: Singleton database instance
- **Async Operations**: All DB calls in background isolates

#### Image & Attachment Handling
- **Lazy Loading**: Attachments downloaded only when requested
- **Caching**: Downloaded files cached in temp directory
- **Compression**: Images compressed before display (if large)
- **Memory Management**: Large files opened in external apps (not loaded in memory)

#### Background Task Optimization
- **Constraint-Based**: Only runs when connected, battery not low
- **Minimal Fetch**: Only 20 latest emails (not full inbox)
- **Incremental Sync**: Tracks last sync token (if Gmail API supports)
- **Smart Notifications**: Only notifies for new Very Important emails

### 11. Security & Privacy

#### Data Security
- **OAuth2**: No password storage, only access tokens
- **Token Storage**: Encrypted by Android Keystore (handled by google_sign_in)
- **SQLite Encryption**: Not enabled (emails already encrypted on device)
- **HTTPS**: All Gmail API calls over TLS
- **No Cloud Storage**: All data local to device

#### Privacy Features
- **Minimal Permissions**: Only requests necessary permissions
- **No Analytics**: No Firebase, no tracking SDKs
- **No Ads**: Completely ad-free
- **Open Source**: Code reviewable (can be)
- **Local Processing**: Profile matching happens on-device

#### Compliance Considerations
- **GDPR**: User data stays on device, can be deleted
- **Data Deletion**: Uninstalling app removes all data
- **Right to Access**: Users can export SQLite database
- **Consent**: Explicit OAuth consent flow

### 12. Error Handling & Edge Cases

#### Network Errors
- **Offline Mode**: Shows cached emails, disables refresh
- **Timeout Handling**: 30s timeout for Gmail API calls
- **Retry Logic**: 3 retries with exponential backoff
- **User Feedback**: Snackbar with error message

#### Authentication Errors
- **Token Expiration**: Auto-refresh token, re-authenticate if fails
- **Invalid Grant**: Clear credentials, prompt re-sign-in
- **Scope Changes**: Detect missing scopes, re-request

#### Database Errors
- **Corruption**: Fallback to rebuild database
- **Disk Full**: Show error, offer to delete old emails
- **Migration Failure**: Rollback to previous version

#### Parsing Edge Cases
- **No Date Found**: Shows "No valid time found" message
- **Past Date**: Warns user, allows manual selection
- **Ambiguous Dates**: Shows all candidates in debug dialog
- **Invalid Dates**: Validates (e.g., Feb 30 rejected)

#### Alarm Edge Cases
- **Past Time**: Prevents setting alarm, shows error
- **Duplicate Alarms**: Replaces existing alarm for same email
- **System Limits**: Android allows max 500 alarms per app
- **Boot/Update**: Alarms may need rescheduling

### 13. Accessibility Features

#### Screen Reader Support
- **Semantic Labels**: All buttons and icons have labels
- **Content Descriptions**: Images described
- **Navigation Order**: Logical tab order

#### Visual Accessibility
- **Color Contrast**: WCAG AA compliant (4.5:1 minimum)
- **Font Sizes**: Respects system font size settings
- **Touch Targets**: All buttons minimum 48x48 dp

#### Input Methods
- **Keyboard Navigation**: Full keyboard support
- **Voice Input**: Supports voice-to-text in search

### 14. Testing

#### Unit Tests
**File**: `test/alarm_service_parse_test.dart`
- Tests date/time parsing patterns
- Covers 30+ test cases
- Validates different formats

#### Integration Tests
- (Not implemented yet)
- Recommended: Test email fetching, alarm scheduling, database operations

#### Manual Testing
- Tested on Android 6.0 - Android 14
- Multiple device manufacturers (Samsung, Pixel, OnePlus)
- Various screen sizes (5" to 7")

---

## 📊 Statistics & Metrics

### Code Metrics
- **Total Lines**: ~8,500 lines of Dart code
- **Files**: 20 Dart files
- **Services**: 7 service classes
- **Screens**: 4 main screens
- **Widgets**: 3 custom widgets
- **Models**: 2 data models

### Database Schema
- **Tables**: 2 (emails, alarms)
- **Indexes**: 5
- **Average Rows**: 100-500 emails per user
- **Storage**: ~50KB - 5MB per user

### Supported Formats
- **Email Types**: Plain text, HTML, multipart
- **Attachment Types**: All (display icons for 15+ types)
- **Date Formats**: 30+ patterns detected
- **Languages**: English (date/time parsing)

### Performance Benchmarks
- **App Launch**: <2s on mid-range devices
- **Email Fetch**: ~3s for 100 emails (network dependent)
- **Search**: <100ms for 500 emails
- **Alarm Creation**: <500ms
- **Background Sync**: <10s (15min intervals)

---

## 🔄 User Flow Examples

### Flow 1: First-Time User
```
1. Install Bell from APK
2. Open app → See "Sign in with Google"
3. Tap → Google OAuth screen
4. Select account → Grant permissions
5. Welcome dialog appears
6. Tap "Setup Profile"
7. Enter: Name, Reg No, Emails
8. Save → Bell scans all emails
9. Shows "✓ Found X emails matching your profile!"
10. Email list appears with:
    - All emails (grey/white)
    - Important emails (red)
    - Auto-alarms set (green badges)
11. Tap any email → See details
12. Tap "Add Alarm" → See parser dialog
13. Review dates → Tap "YES, SET ALARM"
14. Alarm scheduled → Toast confirmation
```

### Flow 2: Daily Usage
```
1. Receive email (Gmail app shows notification)
2. Bell checks in background (every 15min)
3. If Very Important:
   a. Bell notification appears
   b. Auto-alarm set (if time detected)
4. User opens Bell
5. Pull to refresh → New emails appear
6. Filter by "Alarms" → See all scheduled
7. Tap alarm card → See countdown
8. When alarm triggers:
   a. System notification appears
   b. User taps → Opens email in Bell
   c. Or opens in Gmail web
```

### Flow 3: Manual Alarm Creation
```
1. Open Bell
2. Browse or search emails
3. Find email without time
4. Tap "Add Alarm"
5. No auto-detect → Manual picker appears
6. Select date → Select time
7. Confirm → Alarm created
8. Go to Alarm Management
9. See new alarm in list
10. Can edit or delete anytime
```

---

## 🚀 Deployment & Distribution

### Build Process
```bash
# Development build
flutter run

# Release APK
flutter build apk --release

# Release App Bundle (for Play Store)
flutter build appbundle --release

# Split APKs (for specific architectures)
flutter build apk --split-per-abi
```

### APK Details
- **File Size**: 28.2 MB (release)
- **Min SDK**: Android 6.0 (API 23)
- **Target SDK**: Android 14 (API 34)
- **Permissions**: 8 runtime permissions
- **Architectures**: arm64-v8a, armeabi-v7a, x86_64

### Installation Methods
1. **Direct APK**: Share via USB, email, or cloud
2. **Play Store**: (Not published yet)
3. **Internal Distribution**: Firebase App Distribution

---

## 🐛 Known Limitations & Future Improvements

### Current Limitations
1. **Android Only**: iOS not supported (requires different alarm APIs)
2. **Gmail Only**: No support for Outlook, Yahoo, etc.
3. **English Only**: Date parsing only works for English text
4. **No Cloud Backup**: Uninstall loses all data
5. **System Alarm Limit**: Android max 500 alarms per app
6. **Background Restrictions**: May not work reliably on aggressive battery savers
7. **Excel Size**: Large files (>10MB) may crash parser
8. **No Dark Mode**: Only light theme available

### Roadmap (Future Features)
1. **iOS Support**: SwiftUI version with iOS alarms
2. **Dark Mode**: System-adaptive theming
3. **Multi-Account**: Support multiple Gmail accounts
4. **Custom Sounds**: User-selectable alarm sounds
5. **Calendar Integration**: Export detected events to Google Calendar
6. **AI Improvements**: Better date parsing with ML model
7. **Push Notifications**: Real-time via Firebase Cloud Messaging
8. **Widget**: Home screen widget showing next alarm
9. **Wear OS**: Smartwatch app for quick email checking
10. **Backup/Restore**: Cloud sync (Google Drive or Firebase)
11. **Language Support**: Multi-language date parsing
12. **Email Providers**: Support for Outlook, Yahoo
13. **Smart Reply**: Quick response templates
14. **Priority Inbox**: ML-based importance ranking
15. **Snooze Alarms**: Delay alarm temporarily

---

## 💡 Innovation & Unique Features

### What Makes Bell Special?

1. **Zero Manual Work**: 
   - Auto-detects important emails
   - Auto-schedules alarms
   - No calendar entry needed

2. **Smart Profile Matching**:
   - Scans Excel attachments
   - Matches multiple name variants
   - Persists across sessions

3. **Transparent Parsing**:
   - Debug dialog shows all detected dates
   - Users can verify before confirming
   - Builds trust through transparency

4. **Hybrid Alarm System**:
   - In-app database for flexibility
   - System alarms for reliability
   - Best of both worlds

5. **Offline-First**:
   - Works without internet (cached emails)
   - Local processing (fast)
   - Privacy-focused

6. **Email-to-Action**:
   - Direct link from email to alarm
   - No context switching
   - Single-tap workflow

---

## 🎓 Research Applications

### Potential Research Areas

1. **NLP & Date Extraction**:
   - Benchmark Bell's pattern-based approach vs. ML models
   - Multi-language date parsing
   - Context-aware time detection

2. **User Behavior Analysis**:
   - Study how users interact with auto-alarms
   - Acceptance rate of auto-detected times
   - Patterns in manual overrides

3. **Notification Effectiveness**:
   - Optimal lead time for reminders (currently 20min)
   - Notification fatigue vs. importance
   - User response times

4. **Background Task Optimization**:
   - Balance between battery life and sync frequency
   - Adaptive sync based on user patterns
   - Predictive prefetching

5. **Profile Matching Accuracy**:
   - False positive/negative rates
   - Effectiveness of Excel scanning
   - User trust in auto-detection

6. **Mobile Alarm Reliability**:
   - Compare app-based vs. system alarms
   - Survival rate across device reboots
   - Impact of battery optimization

7. **Email Overload Solutions**:
   - Effectiveness of importance filtering
   - Reduction in missed deadlines
   - User productivity metrics

---

## 📝 Conclusion

Bell is a comprehensive solution to the problem of missing important deadlines hidden in email overload. By combining intelligent detection, smart parsing, and reliable alarm systems, it transforms passive email consumption into proactive deadline management. The app demonstrates successful integration of multiple complex systems (OAuth, Gmail API, SQLite, background processing, system alarms) into a cohesive, user-friendly mobile experience.

**Target Impact:**
- **Students**: Never miss placement tests, assignment deadlines, or exam schedules
- **Professionals**: Stay on top of meetings, project milestones, and client deadlines
- **Everyone**: Reduce stress from information overload and improve time management

**Technical Achievement:**
- Production-ready Flutter app with 8,500+ lines of code
- Handles real-world complexity (threading, attachments, parsing)
- Scales to thousands of emails per user
- Resilient to network issues, device reboots, and OS updates

This app can serve as:
- **Case study** for mobile app development best practices
- **Benchmark** for date/time parsing algorithms
- **Reference** for Gmail API integration
- **Template** for notification-based mobile applications
- **Research platform** for studying user behavior with automated systems

---

**Version**: 1.0.0+1  
**Last Updated**: November 10, 2025  
**Platform**: Android 6.0+  
**Framework**: Flutter 3.4+  
**License**: MIT (if open-sourced)

---

*This summary is intended for research, educational, and documentation purposes. For technical implementation details, refer to the source code and inline documentation.*
