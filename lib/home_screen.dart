import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:math' show cos, sqrt, asin; // 👈 Added for distance math

import 'auth_service.dart'; 
import 'map_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 🔑 USING THE KEY WE KNOW WORKS
  final String apiKey = "AIzaSyDk9rarVtm99zX6JqfcSj87qu5_C_mB8BE"; 

  bool _isAnalyzing = false;
  Position? _currentPosition; // 📍 To store exact GPS for math

  // 👇 MATH FUNCTION: Calculates distance between two points in Meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a)) * 1000; 
  }

  Future<void> _analyzeImage() async {
    final ImagePicker picker = ImagePicker();
    
    if (!kIsWeb) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    }

    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800, 
      imageQuality: 70, 
    );
    
    if (image == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // 📍 GET PRECISE LOCATION
      String displayLocation = "Unknown Location";
      try {
        _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        displayLocation = "(${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)})";
      } catch (e) {
        displayLocation = "Location Unavailable";
      }

      // 🤖 GEMINI AI SCAN
      final Uint8List imageBytes = await image.readAsBytes();
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final content = Content.multi([
        TextPart("Analyze this image for civic hazards. Format strictly: 'ISSUE: [Title] | SEVERITY: [High/Medium/Low] | DEPT: [Type]'. If safe, reply 'SAFE'."),
        DataPart('image/jpeg', imageBytes),
      ]);

      final response = await model.generateContent([content]).timeout(const Duration(seconds: 15));
      final String result = response.text ?? "SAFE";
      
      if (!result.contains("SAFE")) {
         String description = result;
         String severity = "Medium";
         String dept = "General";

         // Parse Response
         if (result.contains("ISSUE:")) {
             var parts = result.split("|");
             if (parts.isNotEmpty) description = parts[0].replaceAll("ISSUE:", "").trim();
             if (parts.length > 1) severity = parts[1].replaceAll("SEVERITY:", "").trim();
             if (parts.length > 2) dept = parts[2].replaceAll("DEPT:", "").trim();
         }

         // 🔥 SMART SUBMIT: Checks for duplicates first!
         await _smartSubmitReport(description, severity, dept, displayLocation);

      } else {
        if (mounted) _showResult("✅ Area Verified Safe", Colors.green);
      }

    } catch (e) {
      if (mounted) _showResult("Error: Check Internet", Colors.red);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // 👇 THE SMART LOGIC FUNCTION
  Future<void> _smartSubmitReport(String desc, String severity, String dept, String dispLoc) async {
    if (_currentPosition == null) {
      await _addToFirestore(desc, severity, dept, dispLoc, 1); // No GPS? Just add.
      if (mounted) _showSuccessDialog("Report Submitted", "Hazard reported successfully.", severity, dispLoc);
      return;
    }

    // 1. Get all Pending reports
    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'Pending')
        .get();

    String? existingDocId;
    int currentVotes = 0;

    // 2. Check if any report is closer than 50 METERS
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['latitude'] != null && data['longitude'] != null) {
        double dist = _calculateDistance(
          _currentPosition!.latitude, 
          _currentPosition!.longitude, 
          data['latitude'], 
          data['longitude']
        );

        if (dist < 50) { // MATCH FOUND!
          existingDocId = doc.id;
          currentVotes = data['votes'] ?? 1;
          break;
        }
      }
    }

    if (existingDocId != null) {
      // 🔄 MERGE: Update the existing report
      await FirebaseFirestore.instance.collection('reports').doc(existingDocId).update({
        'description': desc, // Overwrite with new (likely better) description
        'severity': severity, 
        'votes': currentVotes + 1, // 🚀 ESCALATE VOTE COUNT
        'last_updated': FieldValue.serverTimestamp(),
      });
      if (mounted) _showSuccessDialog("Report Merged!", "Similar report found nearby. We escalated priority (+1 Vote).", severity, dispLoc);
    } else {
      // 🆕 NEW: Create fresh report
      await _addToFirestore(desc, severity, dept, dispLoc, 1);
      if (mounted) _showSuccessDialog("Hazard Reported", "New hazard reported successfully.", severity, dispLoc);
    }
  }

  Future<void> _addToFirestore(String desc, String sev, String dept, String loc, int votes) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'description': desc,
      'severity': sev,
      'dept': dept,
      'location': loc,
      'latitude': _currentPosition?.latitude, // Store GPS for future matching
      'longitude': _currentPosition?.longitude,
      'status': 'Pending',
      'votes': votes,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // 🎨 POPUP DESIGN (Maintained your look)
  void _showSuccessDialog(String title, String subtitle, String severity, String loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: severity.contains("High") ? Colors.red[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: severity.contains("High") ? Colors.red : Colors.orange),
              ),
              child: Text("Severity: $severity", style: TextStyle(color: severity.contains("High") ? Colors.red : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 10),
            Text("Location: $loc", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _analyzeImage(); },
            child: const Text("Scan Another"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  void _showResult(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: 250,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 30, backgroundColor: Color(0xFFF1F1F1), child: Icon(Icons.person, size: 35, color: Colors.grey)),
            const SizedBox(height: 10),
            Text("User Profile", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Student ID: 102203"),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(ctx); AuthService().signOut(); },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                icon: const Icon(Icons.logout), 
                label: const Text("Sign Out"),
              ),
            ),
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("CivicLens", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1A237E))),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text("Campus Monitor Active", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showProfile,
                    child: const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFF5F5F5),
                      child: Icon(Icons.person, color: Colors.grey),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 40),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny_outlined, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text("LIGHT SENSOR", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(value: 0.85, minHeight: 6, color: Colors.orange, backgroundColor: Color(0xFFFFF3E0)),
                    ),
                    const SizedBox(height: 10),
                    Text("Visibility: Optimal (850 Lux)", style: GoogleFonts.poppins(fontSize: 14)),
                  ],
                ),
              ),

              const Spacer(),

              Center(
                child: GestureDetector(
                  onTap: _isAnalyzing ? null : _analyzeImage,
                  child: Container(
                    width: 260, height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.08), blurRadius: 40, spreadRadius: 10),
                        BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
                      ],
                    ),
                    child: Center(
                      child: _isAnalyzing 
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(Icons.camera_alt_rounded, size: 32, color: Colors.white),
                              ),
                              const SizedBox(height: 15),
                              Text("TAP TO SCAN", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF1A237E), fontSize: 16)),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              Center(child: Text("AI analyzing hazardous conditions...", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12))),
              const Spacer(),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF1A237E),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          currentIndex: 1, 
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            if (index == 0) Navigator.push(context, MaterialPageRoute(builder: (c) => const MapScreen()));
            if (index == 1) _analyzeImage();
            if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (c) => const ReportsScreen()));
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: "Map"),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner, size: 32), label: "Scan Hazard"),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: "Reports"),
          ],
        ),
      ),
    );
  }
}