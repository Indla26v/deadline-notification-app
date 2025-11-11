import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import '../models/email_model.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GmailService {
  static const List<String> _scopes = <String>[
    gmail.GmailApi.gmailModifyScope, // Changed from readonly to allow sending
    'email',
    'profile',
    'openid',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  Future<auth.AuthClient?> signInAndGetClient() async {
    // Try silent sign-in first (uses cached credentials)
    GoogleSignInAccount? account = await _googleSignIn.signInSilently();
    
    // If silent sign-in fails, prompt user to sign in
    account ??= await _googleSignIn.signIn();
    
    if (account == null) return null;
    
    final authHeaders = await account.authHeaders;
    return auth.authenticatedClient(
      GoogleAuthClient(authHeaders), 
      auth.AccessCredentials(
        auth.AccessToken(
          'Bearer', 
          authHeaders['authorization']?.split(' ').last ?? '', 
          DateTime.now().toUtc().add(const Duration(hours: 1))
        ),
        null,
        _scopes,
      )
    );
  }
  
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
  
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }

  Future<List<EmailModel>> fetchEmails(auth.AuthClient client, {String? pageToken, int maxResults = 25}) async {
    final gmailApi = gmail.GmailApi(client);
    
    // Fetch threads instead of individual messages
    // Reduced from 100 to 25 for much faster initial load
    final threadsResponse = await gmailApi.users.threads.list(
      'me', 
      maxResults: maxResults,
      q: 'in:inbox',
      pageToken: pageToken,
    );

    final List<EmailModel> emails = [];
    for (final thread in threadsResponse.threads ?? <gmail.Thread>[]) {
      // Get full thread details
      final fullThread = await gmailApi.users.threads.get('me', thread.id!, format: 'full');
      final messages = fullThread.messages ?? [];
      
      if (messages.isEmpty) continue;
      
      // Collect all attachments and thread messages first to find the actual latest message
      final allAttachments = <EmailAttachment>[];
      final threadMessagesList = <EmailModel>[];
      DateTime? latestDate;
      
      for (final msg in messages) {
        final msgAttachments = _extractAttachments(msg.payload);
        allAttachments.addAll(msgAttachments);
        
        // Create individual message models for thread expansion
        final msgHeaders = msg.payload?.headers ?? <gmail.MessagePartHeader>[];
        final msgFrom = msgHeaders.firstWhere(
          (h) => (h.name ?? '').toLowerCase() == 'from',
          orElse: () => gmail.MessagePartHeader(name: '', value: 'Unknown'),
        ).value ?? 'Unknown';
        final msgSubject = msgHeaders.firstWhere(
          (h) => (h.name ?? '').toLowerCase() == 'subject',
          orElse: () => gmail.MessagePartHeader(name: '', value: 'No Subject'),
        ).value ?? 'No Subject';
        final msgBody = _extractPlainTextBody(msg.payload);
        
        DateTime? msgDate;
        final msgDateHeader = msgHeaders.firstWhere(
          (h) => (h.name ?? '').toLowerCase() == 'date',
          orElse: () => gmail.MessagePartHeader(name: '', value: ''),
        );
        if (msgDateHeader.value != null && msgDateHeader.value!.isNotEmpty) {
          try {
            msgDate = DateTime.parse(msgDateHeader.value!);
          } catch (_) {
            if (msg.internalDate != null) {
              msgDate = DateTime.fromMillisecondsSinceEpoch(int.parse(msg.internalDate!));
            }
          }
        } else if (msg.internalDate != null) {
          msgDate = DateTime.fromMillisecondsSinceEpoch(int.parse(msg.internalDate!));
        }
        
        // Track the latest date in thread
        if (msgDate != null && (latestDate == null || msgDate.isAfter(latestDate))) {
          latestDate = msgDate;
        }
        
        threadMessagesList.add(EmailModel(
          id: msg.id!,
          sender: msgFrom,
          subject: msgSubject,
          snippet: msg.snippet ?? '',
          body: msgBody.isNotEmpty ? msgBody : (msg.snippet ?? ''),
          link: 'https://mail.google.com/mail/u/0/#inbox/${msg.id!}',
          receivedDate: msgDate,
          attachments: msgAttachments,
          threadId: thread.id,
          messageCount: 1,
          isUnread: msg.labelIds?.contains('UNREAD') ?? false,
        ));
      }
      
      // Use the latest message as the main email for display
      final latestMsg = messages.last;
      final headers = latestMsg.payload?.headers ?? <gmail.MessagePartHeader>[];
      
      // Check if thread has UNREAD label
      final isUnread = latestMsg.labelIds?.contains('UNREAD') ?? false;
      
      final fromHeader = headers.firstWhere(
        (h) => (h.name ?? '').toLowerCase() == 'from',
        orElse: () => gmail.MessagePartHeader(name: '', value: 'Unknown'),
      );
      final subjectHeader = headers.firstWhere(
        (h) => (h.name ?? '').toLowerCase() == 'subject',
        orElse: () => gmail.MessagePartHeader(name: '', value: 'No Subject'),
      );

      final from = fromHeader.value ?? 'Unknown';
      final subject = subjectHeader.value ?? 'No Subject';
      final snippet = latestMsg.snippet ?? '';
      final body = _extractPlainTextBody(latestMsg.payload);

      emails.add(EmailModel(
        id: latestMsg.id!,
        sender: from,
        subject: subject,
        snippet: snippet,
        body: body.isNotEmpty ? body : snippet,
        link: 'https://mail.google.com/mail/u/0/#inbox/${thread.id!}',
        pageToken: threadsResponse.nextPageToken,
        receivedDate: latestDate ?? DateTime.now(), // Fallback to current time if no date found
        attachments: allAttachments, // All attachments from entire thread
        threadId: thread.id,
        messageCount: messages.length,
        threadMessages: messages.length > 1 ? threadMessagesList : null, // Only include thread messages if it's actually a multi-message thread
        isUnread: isUnread,
      ));
    }
    return emails;
  }

  String _extractPlainTextBody(gmail.MessagePart? part) {
    if (part == null) return '';

    if ((part.mimeType ?? '').toLowerCase() == 'text/plain' && part.body?.data != null) {
      return _decodeBase64Url(part.body!.data!);
    }

    if (part.parts != null) {
      for (final p in part.parts!) {
        final text = _extractPlainTextBody(p);
        if (text.isNotEmpty) return text;
      }
    }

    if (part.body?.data != null) {
      // Fallback: try decoding any body data
      try {
        return _decodeBase64Url(part.body!.data!);
      } catch (_) {}
    }

    return '';
  }

  List<EmailAttachment> _extractAttachments(gmail.MessagePart? part, [List<EmailAttachment>? attachments]) {
    attachments ??= [];
    if (part == null) return attachments;

    // Check if this part is an attachment
    if (part.filename != null && part.filename!.isNotEmpty && part.body?.attachmentId != null) {
      attachments.add(EmailAttachment(
        filename: part.filename!,
        mimeType: part.mimeType ?? 'application/octet-stream',
        attachmentId: part.body!.attachmentId!,
        sizeBytes: part.body?.size,
      ));
    }

    // Recursively check sub-parts
    if (part.parts != null) {
      for (final p in part.parts!) {
        _extractAttachments(p, attachments);
      }
    }

    return attachments;
  }

  Future<List<int>> downloadAttachment(auth.AuthClient client, String messageId, String attachmentId) async {
    final gmailApi = gmail.GmailApi(client);
    final attachment = await gmailApi.users.messages.attachments.get('me', messageId, attachmentId);
    
    if (attachment.data != null) {
      return base64Url.decode(attachment.data!);
    }
    
    throw Exception('Failed to download attachment');
  }

  Future<void> sendEmail(
    auth.AuthClient client, {
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
  }) async {
    try {
      final gmailApi = gmail.GmailApi(client);
      
      // Create RFC 2822 formatted email
      String email = '';
      email += 'To: $to\r\n';
      if (cc != null && cc.isNotEmpty) {
        email += 'Cc: $cc\r\n';
      }
      if (bcc != null && bcc.isNotEmpty) {
        email += 'Bcc: $bcc\r\n';
      }
      email += 'Subject: $subject\r\n';
      email += 'Content-Type: text/plain; charset=utf-8\r\n';
      email += '\r\n';
      email += body;

      // Encode email in base64url format
      String encodedEmail = base64Url.encode(utf8.encode(email));
      
      // Send email
      await gmailApi.users.messages.send(
        gmail.Message(raw: encodedEmail),
        'me',
      );
      
      print('Email sent successfully to $to');
    } catch (e) {
      print('Error sending email: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(auth.AuthClient client, String messageId) async {
    try {
      final gmailApi = gmail.GmailApi(client);
      await gmailApi.users.messages.modify(
        gmail.ModifyMessageRequest(removeLabelIds: ['UNREAD']),
        'me',
        messageId,
      );
      print('Marked email $messageId as read in Gmail');
    } catch (e) {
      print('Error marking email as read: $e');
    }
  }

  Future<void> markAsUnread(auth.AuthClient client, String messageId) async {
    try {
      final gmailApi = gmail.GmailApi(client);
      await gmailApi.users.messages.modify(
        gmail.ModifyMessageRequest(addLabelIds: ['UNREAD']),
        'me',
        messageId,
      );
      print('Marked email $messageId as unread in Gmail');
    } catch (e) {
      print('Error marking email as unread: $e');
    }
  }

  String _decodeBase64Url(String data) {
    String normalized = data.replaceAll('-', '+').replaceAll('_', '/');
    switch (normalized.length % 4) {
      case 2:
        normalized += '==';
        break;
      case 3:
        normalized += '=';
        break;
    }
    return utf8.decode(base64.decode(normalized));
  }
}


