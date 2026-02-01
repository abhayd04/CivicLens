# CivicLens - Smart City Maintenance 🚧
**Team Hackaholics**

## 🎥 Project Demo
[Watch the Video Demo Here](https://drive.google.com/file/d/17LVPqpVVIcO0optGW4Bt9zEQFSz4Fjrq/view?usp=drivesdk)

## 📱 How to Test (Important!)
Since this app relies on the Camera and GPS, the Web version has limitations.
- **For the best experience:** Download the **Android APK** here: [Link to Drive APK](https://drive.google.com/file/d/1_rmew6wqCC4xLtoR3Ixtj_e9EVfpa7wb/view?usp=sharing)
- **Web Demo:** [Link to Netlify Web App](https://civiclens-web.netlify.app/) *(Note: Web version uses static images for testing)*

## 💡 Project Description

**CivicLens** is an AI-powered civic maintenance platform designed to bridge the gap between student reporting and administrative action.

### 🔴 The Problem: "The Black Hole" of Maintenance
On university campuses and in smart cities, critical hazards like potholes, broken lights, and exposed wires often go unfixed for weeks. Why?
* **High Friction:** Reporting requires finding the right authority, filling long forms, and waiting in queues.
* **No Transparency:** Students never receive feedback, leading to a "Trust Deficit."
* **Lack of Verification:** Administrators struggle to verify if a contractor actually fixed the issue or just marked it "Done."

### 🟢 The Solution: CivicLens
We built **CivicLens** to turn a 3-day reporting process into a **10-second action**. By leveraging **Google Gemini 2.5 Flash**, the app automatically detects hazards from a photo, grades their severity, and pins their exact location.

### ✨ Key Features
* **📸 Instant AI Scanning:** Users simply point their camera at a hazard. The app uses **Gemini 2.5 Flash** to identify the issue (e.g., "Pothole") and assess Severity (High/Medium/Low) in real-time.
* **📍 Precision Geotagging:** Integrates Android Location Services with **OpenStreetMap** to pinpoint the exact latitude and longitude of the hazard for maintenance teams.
* **🔄 The "Verify Fix" Loop (Killer Feature):** To solve the trust deficit, CivicLens introduces an AI verification step. When a repair is claimed, users can re-scan the spot. The AI compares "Before" vs. "After" images to scientifically prove the repair was done before closing the ticket.
* **🚀 Real-Time Feedback:** Users receive instant updates on their ticket status, closing the feedback loop and encouraging civic participation.

  ## ⚙️ How it Works (User Workflow)

**Step 1: Open & Scan** 📸
- Open the app and tap the big **"Tap to Scan"** button on the home screen.
- Point your camera at a civic hazard (e.g., a pothole, broken street light, or garbage pile).

**Step 2: AI Analysis** 🧠
- **Google Gemini 2.5 Flash** instantly analyzes the image.
- It automatically detects the **Issue Type** (e.g., "Pothole") and assigns a **Severity Score** (High/Medium/Low).
- The app captures your exact **GPS Location** using Android Location Services.

**Step 3: Submit Report** 🚀
- Review the AI-generated details.
- Tap **"Submit Ticket"** to send the report to the Admin Dashboard (stored in Firebase).

**Step 4: Verify the Fix (The "Trust Loop")** ✅
- Once a repair is claimed, any user can go back to the location.
- Tap the **"Verify Fix"** button on the ticket.
- Re-scan the same spot. The AI compares the "Before" vs. "After" images to confirm the hazard is gone before closing the ticket.
  
## 🚀 Tech Stack
- **Frontend:** Flutter (Dart)
- **AI:** Google Gemini 2.5 Flash
- **Backend:** Firebase
- **Maps:** OpenStreetMap
