import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BatchTimelineScreen extends StatefulWidget {
  final String batchId;

  const BatchTimelineScreen({super.key, required this.batchId});

  @override
  State<BatchTimelineScreen> createState() => _BatchTimelineScreenState();
}

class _BatchTimelineScreenState extends State<BatchTimelineScreen> {
  List<dynamic> events = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProvenance();
  }

  Future<void> _fetchProvenance() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:3000/api/batches'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final batch = data.firstWhere((b) => b['id'] == widget.batchId, orElse: () => null);
        if (batch != null) {
          setState(() {
            events = batch['provenanceEvents'] ?? [];
            events.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching provenance: $e');
      setState(() => errorMessage = 'Unable to load chain of custody data.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _PillBackButton(),
                  const SizedBox(width: 14),
                  Text(
                    'Chain of Custody',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: context.errorColor),
                              const SizedBox(height: 16),
                              Text(
                                errorMessage!,
                                style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : events.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 64, color: context.textMutedColor),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No provenance events',
                                    style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Blockchain events will appear here once recorded.',
                                    style: GoogleFonts.inter(fontSize: 14, color: context.textSecondaryColor),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: events.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final event = events[index];
                                return Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: context.surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: context.borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              event['eventType'] ?? 'Unknown',
                                              style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15, color: context.primaryDarkColor),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: event['status'] == 'CONFIRMED' ? context.successBgColor : context.warningBgColor,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              event['status'] ?? 'PENDING',
                                              style: GoogleFonts.manrope(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: event['status'] == 'CONFIRMED' ? context.successColor : context.warningColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Batch ID: ${event['batchId'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor)),
                                      Text('Actor ID: ${event['actorId'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 13, color: context.textSecondaryColor)),
                                      if (event['txHash'] != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tx: ${event['txHash']}',
                                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w500, fontSize: 11, color: context.textPrimaryColor),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillBackButton extends StatelessWidget {
  const _PillBackButton();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: context.textPrimaryColor),
        ),
      ),
    );
  }
}
