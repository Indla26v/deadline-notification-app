import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../services/gmail_service.dart';

class ComposeEmailScreen extends StatefulWidget {
  final auth.AuthClient? client;
  final String? replyTo;
  final String? replySubject;

  const ComposeEmailScreen({
    Key? key,
    this.client,
    this.replyTo,
    this.replySubject,
  }) : super(key: key);

  @override
  State<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _bccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final GmailService _gmailService = GmailService();
  
  bool _sending = false;
  bool _showCc = false;
  bool _showBcc = false;

  @override
  void initState() {
    super.initState();
    if (widget.replyTo != null) {
      _toController.text = widget.replyTo!;
    }
    if (widget.replySubject != null) {
      _subjectController.text = 'Re: ${widget.replySubject}';
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.client == null) {
      _showSnackBar('❌ Please sign in to send emails', isError: true);
      return;
    }

    setState(() => _sending = true);

    try {
      await _gmailService.sendEmail(
        widget.client!,
        to: _toController.text.trim(),
        subject: _subjectController.text.trim(),
        body: _bodyController.text,
        cc: _ccController.text.trim().isNotEmpty ? _ccController.text.trim() : null,
        bcc: _bccController.text.trim().isNotEmpty ? _bccController.text.trim() : null,
      );

      if (mounted) {
        _showSnackBar('✅ Email sent successfully!', isError: false);
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('❌ Failed to send email: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Compose Email'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendEmail,
              tooltip: 'Send',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // To field
              Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          'To',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _toController,
                          decoration: const InputDecoration(
                            hintText: 'Recipients',
                            border: InputBorder.none,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter recipient email';
                            }
                            return null;
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        onPressed: () {
                          setState(() {
                            _showCc = !_showCc;
                            if (!_showCc) _showBcc = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey[300]),

              // CC field (conditional)
              if (_showCc) ...[
                Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            'Cc',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _ccController,
                            decoration: const InputDecoration(
                              hintText: 'Cc recipients',
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _showBcc = !_showBcc);
                          },
                          child: Text('Bcc', style: TextStyle(color: Colors.blue.shade700)),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey[300]),
              ],

              // BCC field (conditional)
              if (_showBcc) ...[
                Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            'Bcc',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _bccController,
                            decoration: const InputDecoration(
                              hintText: 'Bcc recipients',
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey[300]),
              ],

              // Subject field
              Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          'Subject',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            hintText: 'Email subject',
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter subject';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey[300]),

              const SizedBox(height: 16),

              // Body field
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    hintText: 'Compose email...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  minLines: 15,
                  keyboardType: TextInputType.multiline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter message body';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
