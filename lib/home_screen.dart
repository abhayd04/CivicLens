import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'map_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 🔑 API KEY 
  final String apiKey = "AIzaSyA5tywEOFKz64cn-WAUTRDSiGVk3oUY0Pg"; 

  bool _isAnalyzing = false;

  // ⚡ SPEED OPTIMIZATION: Compresses image to make Gemini faster
  Future<void> _analyzeImage() async {
    final ImagePicker picker = ImagePicker();
    
    // 1. Permission Check (Web-Safe)
    if (!kIsWeb) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    }

    // 📸 Take Photo (Low Resolution for FAST AI Response)
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800, // Resizes large photos
      imageQuality: 70, // Compresses file size
    );
    
    if (image == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // 📍 SMART LOCATION LOGIC
      String displayLocation = "Unknown Location";
      String technicalLocation = ""; // Stores Coordinates

      // Get Position safely
      try {
        Position pos = await Geolocator.getCurrentPosition();
        technicalLocation = "(${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})";
        
        if (kIsWeb) {
          displayLocation = "Live GPS $technicalLocation";
        } else {
          // Phone: Try to get address
          try {
            List<Placemark> pm = await placemarkFromCoordinates(pos.latitude, pos.longitude);
            if (pm.isNotEmpty) {
              String area = pm[0].subLocality ?? pm[0].locality ?? "Campus";
              displayLocation = "$area $technicalLocation";
            }
          } catch (e) {
            displayLocation = "GPS $technicalLocation";
          }
        }
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

      // ⚡ TIMEOUT ADDED
      final response = await model.generateContent([content]).timeout(const Duration(seconds: 15));
      final String result = response.text ?? "SAFE";
      
      if (!result.contains("SAFE")) {
         // Parse the result
         String description = "Hazard Detected";
         String severity = "Medium";
         String dept = "General";

         if (result.contains("|")) {
           List<String> parts = result.split("|");
           for (String part in parts) {
             if (part.trim().startsWith("ISSUE:")) description = part.replaceAll("ISSUE:", "").trim();
             if (part.trim().startsWith("SEVERITY:")) severity = part.replaceAll("SEVERITY:", "").trim();
             if (part.trim().startsWith("DEPT:")) dept = part.replaceAll("DEPT:", "").trim();
           }
         }

         // 🔥 UPLOAD REPORT
         await FirebaseFirestore.instance.collection('reports').add({
          'description': description,
          'severity': severity,
          'dept': dept,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Pending',
          'location': displayLocation, 
        });

        // 🎉 SUCCESS POPUP
        _showSuccessDialog(description, severity, displayLocation);

      } else {
        _showResult("✅ Area Verified Safe", Colors.green);
      }

    } catch (e) {
      _showResult("Error: Check Internet/API Key", Colors.red);
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // 🎨 Beautiful Success Popup
  void _showSuccessDialog(String issue, String severity, String loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🚨 Hazard Reported"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Issue: $issue", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("Severity: $severity"),
            const SizedBox(height: 5),
            Text("Location: $loc", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              _analyzeImage(); // 🔄 SCAN AGAIN BUTTON
            },
            child: const Text("Scan Another"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  void _showResult(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context, 
      builder: (ctx) => Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
            const SizedBox(height: 10),
            Text("User Profile", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Student ID: 102203"),
            const Spacer(),
            const Text("CivicLens v1.0 (Hackathon Build)"),
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      
      // 1. TOP BAR
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("CivicLens", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF1A237E), fontSize: 22)),
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text("Campus Monitor Active", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            ]),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _showProfile,
            child: const Padding(
              padding: EdgeInsets.only(right: 15.0),
              child: CircleAvatar(backgroundColor: Color(0xFFF1F1F1), child: Icon(Icons.person, color: Colors.grey)),
            ),
          )
        ],
      ),

      // 2. MAIN BODY
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // 💡 LIGHT SENSOR CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wb_sunny_outlined, color: Colors.orange),
                          const SizedBox(width: 10),
                          Text("LIGHT SENSOR", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const LinearProgressIndicator(value: 0.85, color: Colors.orange, backgroundColor: Color(0xFFF5F5F5)),
                      const SizedBox(height: 10),
                      Text("Visibility: Optimal (850 Lux)", style: GoogleFonts.poppins(fontSize: 14)),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // 📸 MIDDLE: TAP TO SCAN BUTTON
                GestureDetector(
                  onTap: _isAnalyzing ? null : _analyzeImage,
                  child: Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.1), width: 15),
                      boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
                    ),
                    child: Center(
                      child: _isAnalyzing 
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.camera_alt_rounded, size: 50, color: Color(0xFF1A237E)),
                              const SizedBox(height: 10),
                              Text("TAP TO SCAN", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF1A237E))),
                            ],
                          ),
                    ),
                  ),
                ),
                
                // Hint text
                const SizedBox(height: 20),
                Text("AI analyzing hazardous conditions...", style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),

      // 3. BOTTOM NAVIGATION
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1A237E),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        currentIndex: 1, // 'Scan' is selected by default
        onTap: (index) {
          if (index == 0) Navigator.push(context, MaterialPageRoute(builder: (c) => const MapScreen()));
          if (index == 1) _analyzeImage(); // Center button also scans!
          if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (c) => const ReportsScreen()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: "Map"),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner, size: 40), label: "Scan Hazard"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Reports"),
        ],
      ),
    );
  }
}