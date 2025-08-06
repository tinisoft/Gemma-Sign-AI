# Gemma-Sign-AI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)

A real-time, on-device Speech-to-ASL interpreter that visualizes American Sign Language gestures using a custom animation engine, powered by Google's Gemma.

---

## 🎥 Live Demo

![App Demo GIF](https://your-link-to-the-demo-gif.com/demo.gif)
*Real-time interpretation of spoken language into an animated ASL stick avatar.*

---

## 🌟 Project Description

**Gemma-Sign-AI** is a Flutter-based mobile application designed to serve as a real-time interpreter, converting spoken language into animated American Sign Language (ASL). 


This project is built with a focus on creating a practical, high-performance, and socially beneficial application of local, on-device AI.

---

## ✨ Core Features

*   **🎙️ Real-Time Voice Activity Detection (VAD):** Intelligently captures complete sentences by detecting the natural pauses at the end of an utterance, creating a seamless user experience.
*   **🧠 On-Device AI with Gemma:** Utilizes a local Gemma model via a Python/Flask server for fast and private speech-to-text and translation into ASL gloss.
*   **🗃️ Comprehensive & Compressed Local Database:** Ships with a pre-seeded SQLite database containing animation data for **alphabets, numbers (0-30), and 2000+ words**. All landmark data is compressed with Gzip, significantly reducing storage requirements.


---

## 🛠️ Technology Stack

| Component         | Technology                                                                                                  | Purpose                                       |
| ----------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| **Mobile App**    | ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white) Dart | Cross-platform application framework          |
| **AI Model**      | ![Google](https://img.shields.io/badge/Google%20Gemma-4285F4?style=for-the-badge&logo=google&logoColor=white) | Speech-to-Text & ASL Gloss Translation        |
| **Backend**       | ![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white) / Flask | Local server to host the Gemma model endpoint |
| **Voice Capture** | `vad` Flutter Package                                                                                       | Voice Activity Detection                      |
| **Database**      | ![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)         | On-device storage for all sign data           |
| **Compression**   | `Gzip`                                                                                                      | Reducing database size                        |
| **Animation**     | `CustomPainter` API                                                                                         | High-performance, frame-by-frame rendering    |

---

## 🏗️ Architecture & Data Flow

**User Speaks** ➡️ **1. VAD Captures Audio** ➡️ **2. WAV Encoding** ➡️ **3. HTTP Request to Local Server** ➡️ **4. Gemma Processes Audio** ➡️ **5. JSON Response (Sentence + Gloss)** ➡️ **6. App Adds Job to Queue** ➡️ **7. Animation Worker Fetches from DB** ➡️ **8. `SignerPainter` Renders Animation**

---

## 🚀 Getting Started

This project requires a one-time manual setup for the sign language animation data due to its large size (~600 MB). Please follow these steps carefully.

### Step 1: Clone the Repository

```sh
git clone https://github.com/tinisoft/Gemma-Sign-AI.git
cd Gemma-Sign-AI
```

### Step 2: Asset Setup (Important!)

The animation data is not included in the repository and must be downloaded separately.

1.  **Download the Assets:**
    *   Download the `signs.zip` file from the following link:
    *   **[➡️ Click here to download the 600 MB assets from Google Drive](https://drive.google.com/file/d/1VzrE4VAOmHLH9HEDenbFaAwMHjNicBmh/view?usp=sharing)**

2.  **Place the Assets:**
    *   Unzip the downloaded file.
    *   You should now have a folder named `signs`.
    *   Place this entire `signs` folder inside the `assets` directory of the project.
    *   Your final folder structure should look like this:
    ```
    Gemma-Sign-AI/
    ├── assets/
    │   ├── signs/       <-- The folder you just moved
    │   │   ├── alphabets/
    │   │   ├── numbers/
    │   │   └── words/
    │   └── ... (other assets)
    ├── lib/
    └── pubspec.yaml
    ```

3.  **Enable Assets in `pubspec.yaml`:**
    *   Open the `pubspec.yaml` file.
    *   Find the `assets:` section and uncomment the lines for the `signs` subdirectories.

    **Before:**
    ```yaml
    assets:
      - .env
      - assets/images/dummy_image.png
      # - assets/signs/alphabets/hand/
      # - assets/signs/alphabets/pose/
      # - assets/signs/numbers/hand/
      # - assets/signs/numbers/pose/
      # - assets/signs/words/hand/
      # - assets/signs/words/pose/
    ```

    **After:**
    ```yaml
    assets:
      - .env
      - assets/images/dummy_image.png
      - assets/signs/alphabets/hand/
      - assets/signs/alphabets/pose/
      - assets/signs/numbers/hand/
      - assets/signs/numbers/pose/
      - assets/signs/words/hand/
      - assets/signs/words/pose/
    ```
    *   After saving the file, run `flutter pub get` in your terminal.
    
    
4.  **Configure the API Endpoint:**
 The application loads the AI server URL from an environment file to keep it separate from the source code.
    *   Create a .env file in the root directory of the project.
    *   Open the new .env file and set the BASE_URL variable to point to your local Gemma server.
        *   `BASE_URL="http://mlserver1:5000"`

### Step 3: Database Seeding (First-Time Run)

The app needs to load all the JSON animation data into a local SQLite database. This is an intensive, one-time process.

1.  **⚙️ Enable Seeding in Code:**
    *   Open the file `lib/main.dart`.
    *   Find the `main` function and **uncomment** the `await databaseSeeding();` line.

    **Before:**
    ```dart
    // await databaseSeeding();
    runApp(HomeView());
    ```

    **After:**
    ```dart
    await databaseSeeding();
    runApp(HomeView());
    ```

2.  **🚀 Run the Seeding Process:**
    *   Install dependencies if you haven't already: `flutter pub get`
    *   Run the application: `flutter run`
    *   **Watch the debug console.** You will see progress messages as the app seeds the alphabets, numbers, and words. This will take a few minutes to complete. Please wait until you see the final "seeding complete" message.
    *   Once seeding is complete, Press the mic to listen.


---

## 🗺️ Future Roadmap

*   [ ] **Expand Vocabulary:** Integrate and seed an even larger dataset of words and phrases.
*   [ ] **Add Facial Expressions:** Extend the data format to include facial landmarks for more expressive and nuanced signing.
*   [ ] **Playback Controls:** Allow users to slow down, pause, or loop the animation for learning purposes.
*   [ ] **Explore Rive:** Investigate migrating the `CustomPainter` engine to the high-performance [Rive](https://rive.app/) animation runtime for even smoother visuals and easier animation management.
*   [ ] **Model Optimization:** Fine-tune the local Gemma model for lower latency and improved translation accuracy.

---
