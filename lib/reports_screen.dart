import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  // 👇 API KEY 
  static const apiKey = "API_KEY_IS_HIDDED"; 

  // ---------------------------------------------------
  // 🧠 AI LOGIC (Standard)
  // ---------------------------------------------------
  Future<void> _verifyAndFix(BuildContext context, String docId, String description) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return; 

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF1A237E)),
                  const SizedBox(width: 20),
                  Expanded(child: Text("Gemini AI Analyzing...", style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ),
        );
      }

      final Uint8List imageBytes = await photo.readAsBytes();
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

     // 👇 INTELLIGENT PROMPT
      final content = Content.multi([
        TextPart("You are a strict Maintenance Inspector. The original complaint was: '$description'. Look at this new photo. Does it show that SPECIFIC issue being fixed? 1. If the photo is unrelated (e.g., a wall when the issue was a road), reply 'REJECTED'. 2. If it shows the repair is done and safe, reply 'VERIFIED'. 3. If unclear, reply 'REJECTED'."),
        DataPart('image/jpeg', imageBytes),
      ]);

      final response = await model.generateContent([content]);
      final String result = response.text?.toUpperCase() ?? "";

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close Loading

        if (result.contains("VERIFIED")) {
          await FirebaseFirestore.instance.collection('reports').doc(docId).update({'status': 'Fixed'});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Verified! Campus Safety Score Increased.", style: GoogleFonts.poppins()), 
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Verification Failed. Repair incomplete.", style: GoogleFonts.poppins()), 
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
      }
    }
  }

  // 🕒 Helper for Dates
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    DateTime date = timestamp.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    return "${date.day}/${date.month}";
  }

  // ---------------------------------------------------
  // 🎨 THE EXECUTIVE UI
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // High-end Grey
      appBar: AppBar(
        title: Text("Safety Command Center", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF1A237E))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1A237E)),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          
          // 📊 CALCULATE LIVE STATS 
          int total = docs.length;
          
          int fixed = docs.where((doc) {
            final data = doc.data(); // Get the map
            return data['status'] == 'Fixed';
          }).length;
          
          double safetyScore = total == 0 ? 100 : (fixed / total) * 100;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. 🏆 THE DASHBOARD CARD
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Text("Campus Safety Score", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text("${safetyScore.toInt()}%", style: GoogleFonts.poppins(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: safetyScore / 100,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)), // Bright Green
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statBadge(Icons.check_circle, "$fixed Fixed"),
                          Container(height: 20, width: 1, color: Colors.white24),
                          _statBadge(Icons.warning_amber_rounded, "${total - fixed} Pending"),
                        ],
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),
              Text("Recent Reports", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
              const SizedBox(height: 15),

              // 2. 📝 THE LIST
              if (docs.isEmpty) 
                 Center(child: Padding(padding: const EdgeInsets.all(40), child: Text("No reports yet", style: GoogleFonts.poppins(color: Colors.grey)))),

              ...docs.map((doc) {
                var data = doc.data();
                bool isFixed = data['status'] == 'Fixed';
                Color statusColor = isFixed ? Colors.green : const Color(0xFFFF6D00);

                return FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(isFixed ? "RESOLVED" : "ACTION REQUIRED", style: GoogleFonts.poppins(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                              Text(_formatDate(data['timestamp']), style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(data['description'] ?? "Issue", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 5),
                          Row(children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[400]), 
                            const SizedBox(width: 5),
                            Expanded(child: Text(data['location'] ?? "Unknown", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13), maxLines: 1))
                          ]),
                          if (!isFixed) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _verifyAndFix(context, doc.id, data['description'] ?? "Issue"),
                                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                label: const Text("VERIFY FIX"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1A237E),
                                  side: BorderSide(color: const Color(0xFF1A237E).withOpacity(0.2)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _statBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
      ],
    );
  }
}