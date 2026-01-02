import 'home_screen.dart';
import 'map_screen.dart';
import 'reports_screen.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize connection to database
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      // API keys and identifiers
      apiKey: "API_KEY_IS_HIDDED",
  authDomain: "civiclens-hackathon-bdc5b.firebaseapp.com",
  projectId: "civiclens-hackathon-bdc5b",
  storageBucket: "civiclens-hackathon-bdc5b.firebasestorage.app",
  messagingSenderId: "137913571986",
  appId: "1:137913571986:web:7a1d059ce8ef302041644b"
    ),
  );
  
  runApp(const CivicLensApp());
}

class CivicLensApp extends StatelessWidget {
  const CivicLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CivicLens',
      theme: ThemeData(
        useMaterial3: true,
        // 👇 1. The Color Palette
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), // Deep Navy (Professional)
          secondary: const Color(0xFFFF6D00), // Vibrant Orange (Action)
          surface: const Color(0xFFF5F7FA),   // Light Gray-Blue (Background)
        ),
        
        // 👇 2. The Typography (Modern & Clean)
        textTheme: GoogleFonts.poppinsTextTheme(), // Uses 'Poppins' font
        
        // 👇 3. Component Styling
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Modern "See-through" look
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF1A237E), 
            fontSize: 22, 
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins', // Ensure title uses font too
          ),
          iconTheme: IconThemeData(color: Color(0xFF1A237E)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            elevation: 5,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentAddress = "📍 Getting GPS Location...";
  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Start the GPS engine immediately!
  }
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String _aiResult = ""; 
  double _simulatedLux = 300.0; // Lighting sensor variable

  // --- 🔑 CONFIGURATION ---
  //  generic Gemini Key
  static const apiKey = "API_KEY_IS_HIDDED"; 

  final ImagePicker _picker = ImagePicker();

  Future<void > _analyzeImage() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    
    if (photo != null) {
      final Uint8List bytes = await photo.readAsBytes();
      
      setState(() {
        _imageBytes = bytes;
        _isLoading = true;
        _aiResult = ""; 
      });

      try {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash', 
          apiKey: apiKey,
        );

        // PROMPT for Campus Safety Officer(Gemini-2.5-flash)
      final content = TextPart("""
      Act as a Campus Safety Officer. Analyze this image for infrastructure hazards (cracks, potholes, broken glass, dangerous wiring, lighting).
      
     RULES:
      1. If the image is Safe/Cartoon/Irrelevant:
         ISSUE: No Safety Hazards Detected
         SEVERITY: Low
         DEPT: N/A
         ACTION: No action required.
      
      2. If you see a REAL hazard:
         ISSUE: [Short description of hazard]
         SEVERITY: [High/Medium/Low]
         DEPT: Campus Maintenance  <-- 👈 FORCE THIS SINGLE DEPARTMENT
         ACTION: [Specific fix recommendation]
      """);

        final imagePart = DataPart('image/jpeg', bytes);

        final response = await model.generateContent([
          Content.multi([content, imagePart])
        ]);

        setState(() {
          _aiResult = response.text ?? "Error: No response from AI";
          _isLoading = false;
        });

      } catch (e) {
        setState(() {
          _aiResult = "Error: $e";
          _isLoading = false;
        });
      }
    }
  }

  // --- 🔥 FIREBASE SUBMIT FUNCTION ---
  Future<void> _submitTicket() async {
    if (_aiResult.isEmpty) return; // Don't submit empty tickets

    try {
      // 1. Send REAL Data to Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'title': "Infrastructure Hazard",
        'description': _aiResult, 
        'location': _currentAddress, // 👈 Uses the live GPS address
        'severity': _simulatedLux < 50 ? "High (Poor Lighting)" : "Medium",
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(), // 👈 Real server time
      });

      print("✅ Ticket Submitted to Database!");

    } catch (e) {
      print("❌ Error submitting ticket: $e");
    }
  }

  void _showSuccessDialog() {
    _submitTicket();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("Report Submitted!", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Your audit has been successfully sent to the City Council. Thank you for making the campus safer!",
          textAlign: TextAlign.center,
        ),
        actions: [
        ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close popup
              setState(() {
                _imageBytes = null; // Clear photo
                _aiResult = "";     // Clear text
                _isLoading = false; 
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E), // Navy Blue
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_a_photo, size: 20),
            label: const Text("START NEW AUDIT"), 
          ),
        ],
      ),
    );
  }
  // 👇 function to get real GPS
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        // We will store coordinates for now (e.g., "Lat: 28.6, Long: 77.2")
        _currentAddress = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
      });
    } catch (e) {
      print("Could not get location: $e");
      setState(() {
        _currentAddress = "📍 Location Unknown (GPS Error)";
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. APP BAR
      appBar: AppBar(
        // The Title on the left
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.white),
            SizedBox(width: 10),
            Text("CIVIC LENS", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E), // Navy Blue
        elevation: 0,
        
        // 👇 The History Button
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: "View My Reports",
            onPressed: () {
              // Navigate to the new Reports Screen
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) =>
                 const ReportsScreen())
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // 2. HEADER SECTION (Navy Blue Background)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20, top: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A237E),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Campus Safety Auditor", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  SizedBox(height: 5),
                  Text("Report an Issue", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // 3. MAIN CONTENT (Overlapping the Header)
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    
                    // 📸 IMAGE CARD (The "Eye" of the App)
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _imageBytes == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 60, color: Colors.grey[300]),
                                  const SizedBox(height: 10),
                                  Text("Tap 'Snap & Analyze' below", style: TextStyle(color: Colors.grey[400])),
                                ],
                              )
                            : Image.memory(_imageBytes!, fit: BoxFit.cover),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ⚡ SENSOR DASHBOARD
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          // 1. Scalable Row using FittedBox + SizedBox
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox( 
                             width: MediaQuery.of(context).size.width,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(children: [
                                    Icon(Icons.wb_sunny_outlined, color: Colors.orange[700]),
                                    const SizedBox(width: 8),
                                    const Text("Lighting Sensor", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ]),
                                  
                                  // The Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _simulatedLux < 50 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _simulatedLux < 50 ? "⚠️ POOR VISIBILITY" : "✅ GOOD VISIBILITY",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _simulatedLux < 50 ? Colors.red : Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // 2. The Slider
                          Slider(
                            value: _simulatedLux,
                            min: 0, max: 500,
                            activeColor: _simulatedLux < 50 ? Colors.red : Colors.green,
                            onChanged: (value) => setState(() => _simulatedLux = value),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 🕹️ CONTROL CENTER
                    _isLoading 
                        ? const CircularProgressIndicator()
                        : Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _analyzeImage,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text("SNAP & ANALYZE"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6D00), // Safety Orange
                                    elevation: 5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.map_outlined, color: Color(0xFF1A237E)),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen())),
                                ),
                              )
                            ],
                          ),

                    const SizedBox(height: 30),

                    // 📋 OFFICIAL TICKET CARD
                    if (_aiResult.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border(left: BorderSide(width: 6, color: _aiResult.contains("Error") ? Colors.red : const Color(0xFF1A237E))),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("OFFICIAL AUDIT REPORT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
                            const Divider(height: 30),
                            Text(_aiResult, style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87)),
                            const SizedBox(height: 20),
                           // 👇 1. If Safe: Show Green Box
              if (_aiResult.contains("No Safety Hazards"))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 10),
                      Text("VERIFIED SAFE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              // 👇 2. If Hazard: Show Submit Button
              if (!_aiResult.contains("No Safety Hazards") && _aiResult.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showSuccessDialog,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const FittedBox(child: Text("SUBMIT REPORT")),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                          ],
                        ),
                      ),
                      
                    const SizedBox(height: 50), // Bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}