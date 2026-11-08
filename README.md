# Ilocano Teatro Master

**An Educational Platform for Ilocano Literature, Theater, and Playwriting**

Developed by **MR Bisac Studios**

Ilocano Teatro Master is a cross-platform educational application designed to support the learning, appreciation, and preservation of Ilocano literature and theatrical traditions.

The platform provides an interactive learning environment where students can explore cultural stories, complete educational activities, develop playwriting skills, and receive guidance from teachers.

The application supports **Android and Web**.

---

## Features

### Student Features
- **Story Vault** — Explore published Ilocano cultural stories and chapters.
- **Learning Modules** — Access educational lessons and learning materials.
- **Quizzes and Assessments** — Complete quizzes and review results.
- **Playwriting Theme Builder** — Create, save, edit, and submit playwriting ideas.
- **Teacher Feedback** — Receive reviews, comments, and revision requests.
- **Progress Tracking** — Monitor learning activities and accomplishments.
- **Notifications** — Receive updates about submissions and reviews.

### Teacher Features
- **Teacher Dashboard** — View assigned students and learning activity.
- **Student Management** — Manage student connections through class codes.
- **Review Queue** — Evaluate student submissions and provide feedback.
- **Student Progress** — Monitor student learning and assessment results.
- **Story Vault** — Access published cultural learning content.

### Curriculum Management
Authorized curriculum editors can manage educational content, including:
- Learning modules and lessons
- Quizzes and assessment materials
- Cultural stories and chapters
- Supported educational media

Curriculum management features are restricted to authorized accounts.

---

## Technology Stack

| Component | Technology |
|---|---|
| Application Framework | Flutter |
| Programming Language | Dart |
| Database | PostgreSQL |
| Backend Services | Supabase |
| Authentication | Supabase Auth |
| File Storage | Supabase Storage |
| Server-side Functions | Supabase Edge Functions |
| Web Hosting | Firebase Hosting |
| Version Control | Git and GitHub |
| Supported Platforms | Android and Web |

---

## Application Roles

**Student** — Accesses learning materials, completes quizzes, creates playwriting drafts, submits work, and receives feedback.

**Teacher** — Manages assigned students, monitors learning activity, and reviews submitted work.

**Curriculum Editor** — An authorized teacher with additional permissions to manage educational content.

---

## Android Installation

The Android application is distributed through GitHub Releases during the testing period.

1. Open the repository's **Releases** section.
2. Download the latest Android APK.
3. Open the downloaded APK on an Android device.
4. Follow Android's instructions to install the application.
5. Launch Ilocano Teatro Master and sign in or create a student account.

**Note:** Android may request permission to install applications from the selected download source.

### Google Play Availability

The application is currently undergoing Google Play testing and review. Google Play availability will be announced once the relevant release is approved.

---

## Web Application

The web version is hosted using Firebase Hosting.

**Web URL:** https://ilocano-teatro-master.web.app

The web application uses the same backend services as the Android application.

---

## Development and Configuration

The project uses Flutter and requires properly configured backend services.

### Requirements
- Flutter SDK
- Dart SDK
- Android SDK for Android builds
- Supabase project configuration
- Firebase CLI for web deployment

### Install Dependencies

```bash
flutter pub get
```

### Run the Application

Use the configured local environment file:

```bash
flutter run --dart-define-from-file=supabase.local.json
```

The local configuration file must be created separately and should not contain privileged backend credentials.

### Build Android APK

```bash
flutter build apk --release --dart-define-from-file=supabase.local.json
```

### Build Web

```bash
flutter build web --release --dart-define-from-file=supabase.local.json
```

Release signing must be configured separately before distributing a production-signed Android build.

---

## Privacy and Account Deletion

The application uses authentication and access controls to help protect user information.

- **Privacy Policy:** https://ilocano-teatro-master.web.app/privacy
- **Account Deletion:** https://ilocano-teatro-master.web.app/delete-account

Users may contact the developer regarding privacy or account-deletion requests.

---

## Developer

**MR Bisac Studios**

Application Development and Software Solutions

**Contact:** marcronielbisac@gmail.com

---

## Project Status

**Android:** Testing release  
**Web:** Deployment supported  
**Google Play:** Testing and review

---

© 2026 MR Bisac Studios. All rights reserved.
