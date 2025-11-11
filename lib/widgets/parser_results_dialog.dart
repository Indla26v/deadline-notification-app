import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ParserResultsDialog extends StatelessWidget {
  final Map<String, dynamic> parseResult;
  final String emailSubject;
  final String emailBody;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onManualPick;

  const ParserResultsDialog({
    Key? key,
    required this.parseResult,
    required this.emailSubject,
    required this.emailBody,
    required this.onConfirm,
    required this.onCancel,
    this.onManualPick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final finalDate = parseResult['finalDate'] as DateTime?;
    final candidatesLog = (parseResult['candidatesLog'] as List<String>?) ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Debug: Parser Results',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onCancel,
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email Content Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email Content:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            emailSubject,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emailBody.length > 300 
                                ? '${emailBody.substring(0, 300)}...' 
                                : emailBody,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // All Candidates Found Section
                    if (candidatesLog.isNotEmpty) ...[
                      Row(
                        children: [
                          const Text(
                            'All Candidates Found:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${candidatesLog.length} found',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: candidatesLog.asMap().entries.map((entry) {
                            final index = entry.key;
                            final log = entry.value;
                            final isFinalSelection = index == candidatesLog.length - 1;
                            
                            // Parse the log to extract date and pattern
                            final lines = log.split('\n');
                            final foundLine = lines.firstWhere(
                              (line) => line.startsWith('Found:'),
                              orElse: () => log,
                            );
                            final fromLine = lines.firstWhere(
                              (line) => line.contains('- From:'),
                              orElse: () => '',
                            );
                            final patternLine = lines.firstWhere(
                              (line) => line.contains('- Using pattern:'),
                              orElse: () => '',
                            );
                            
                            // Extract pattern ID
                            final patternId = patternLine.contains('pattern:') 
                                ? patternLine.split('pattern:').last.trim() 
                                : 'Unknown';
                            
                            // Calculate pseudo-confidence (higher for full date, lower for time-only)
                            final confidence = patternId.contains('time-only') || patternId.contains('fallback')
                                ? '45%' 
                                : patternId.contains('relative') 
                                    ? '75%'
                                    : '95%';
                            final isLowConfidence = confidence.startsWith('4') || confidence.startsWith('5');

                            return GestureDetector(
                              onLongPress: () {
                                // Copy matched text to clipboard
                                if (fromLine.isNotEmpty) {
                                  // Could implement clipboard copy here
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isFinalSelection 
                                      ? Colors.green.shade50 
                                      : isLowConfidence 
                                          ? Colors.orange.shade50
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isFinalSelection 
                                        ? Colors.green.shade400 
                                        : isLowConfidence
                                            ? Colors.orange.shade300
                                            : Colors.grey.shade300,
                                    width: isFinalSelection ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isFinalSelection 
                                              ? Icons.check_circle 
                                              : Icons.schedule,
                                          size: 16,
                                          color: isFinalSelection 
                                              ? Colors.green.shade700 
                                              : isLowConfidence
                                                  ? Colors.orange.shade700
                                                  : Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            foundLine.replaceFirst('Found:', '').trim(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isFinalSelection 
                                                  ? FontWeight.bold 
                                                  : FontWeight.w600,
                                              color: isFinalSelection 
                                                  ? Colors.green.shade900
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isFinalSelection 
                                                ? Colors.green.shade700
                                                : isLowConfidence
                                                    ? Colors.orange.shade600
                                                    : Colors.blue.shade600,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            confidence,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (fromLine.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 24, top: 4),
                                        child: Text(
                                          '📝 ${fromLine.trim().replaceFirst('- From:', '').trim()}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (patternId != 'Unknown')
                                      Padding(
                                        padding: const EdgeInsets.only(left: 24, top: 2),
                                        child: Text(
                                          '🔍 Pattern: $patternId',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    if (isLowConfidence)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 24, top: 4),
                                        child: Text(
                                          '⚠️ Low confidence - consider manual selection',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ),
                                    if (isFinalSelection)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 24, top: 4),
                                        child: Text(
                                          '✓ SELECTED AS FINAL',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Final Selected Date Section
                    if (finalDate != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.shade400,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Final Selected Date:',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                DateFormat('EEEE, MMM d, yyyy @ h:mm a').format(finalDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Manual picker button (left side)
                  if (onManualPick != null)
                    OutlinedButton.icon(
                      onPressed: onManualPick,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text(
                        'PICK MANUALLY',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade400, width: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  
                  // Right side buttons
                  Row(
                    children: [
                      TextButton(
                        onPressed: onCancel,
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: finalDate != null ? onConfirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'YES, SET ALARM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
