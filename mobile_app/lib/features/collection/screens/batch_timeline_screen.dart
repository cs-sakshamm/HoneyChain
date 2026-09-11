import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/workflow_request.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/theme_context.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BatchTimelineScreen extends StatefulWidget {
  final String batchId;

  const BatchTimelineScreen({Key? key, required this.batchId}) : super(key: key);

  @override
  _BatchTimelineScreenState createState() => _BatchTimelineScreenState();
}

class _BatchTimelineScreenState extends State<BatchTimelineScreen> {
  List<dynamic> events = [];
  bool isLoading = true;

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
      debugPrint("Error fetching provenance: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chain of Custody'),
        backgroundColor: context.surfaceColor,
      ),
      backgroundColor: context.scaffoldBg,
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                color: context.surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            event['eventType'],
                            style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16, color: context.primaryDarkColor),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: event['status'] == 'CONFIRMED' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12)
                            ),
                            child: Text(event['status'], style: TextStyle(color: event['status'] == 'CONFIRMED' ? Colors.green : Colors.orange)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Batch ID: ${event['batchId']}", style: TextStyle(color: context.textSecondaryColor)),
                      Text("Actor ID: ${event['actorId']}", style: TextStyle(color: context.textSecondaryColor)),
                      const SizedBox(height: 8),
                      Text("Tx Hash: ${event['txHash'] ?? 'Pending...'}", style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: context.textPrimaryColor)),
                      Text("Data Hash: ${event['dataHash']}", style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: context.textPrimaryColor)),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
