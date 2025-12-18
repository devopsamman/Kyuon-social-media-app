# Kyuon - Social Media App 📱

A modern, feature-rich social media application built with Flutter and Supabase. Kyuon allows users to share posts, stories, and reels while connecting with friends and followers.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)

## ✨ Features

### Authentication
- **Email OTP Verification** - Secure sign-up and login using email-based OTP
- **Profile Setup** - Complete profile creation with photo, username, bio, and gender

### Content Sharing
- **Posts** - Share images with captions
- **Stories** - Share temporary 24-hour stories (Instagram-like)
- **Reels** - Short-form video content with vertical swiping

### Social Features
- **Like & Comment** - Engage with posts
- **Follow System** - Follow other users
- **User Profiles** - View and edit profiles

### User Experience
- **Dark/Light Theme** - Toggle between themes
- **Real-time Updates** - Live content refresh
- **Responsive Design** - Works on all screen sizes

## 🛠️ Tech Stack

### Frontend
| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform mobile framework |
| **Dart** | Programming language |
| **Provider** | State management |

### Backend & Database
| Technology | Purpose |
|------------|---------|
| **Supabase** | Backend-as-a-Service (BaaS) |
| **PostgreSQL** | Database (via Supabase) |
| **Row Level Security (RLS)** | Data protection |

### Media & Storage
| Technology | Purpose |
|------------|---------|
| **Cloudinary** | Image & video hosting |
| **Image Picker** | Camera & gallery access |
| **Video Player** | Reel playback |

### Other Dependencies
| Package | Purpose |
|---------|---------|
| `supabase_flutter` | Supabase SDK for Flutter |
| `cloudinary_public` | Cloudinary uploads |
| `video_player` | Video playback |
| `shared_preferences` | Local storage |
| `cupertino_icons` | iOS-style icons |

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── post_data.dart        # Post data model
│   ├── story_data.dart       # Story data model
│   └── reel_data.dart        # Reel data model
├── screens/
│   ├── login_screen.dart     # Login UI
│   ├── signup_screen.dart    # Sign up UI
│   ├── otp_verification_screen.dart  # OTP verification
│   ├── profile_setup_screen.dart     # New user profile setup
│   ├── home_screen.dart      # Main feed
│   ├── profile_screen.dart   # User profile
│   ├── edit_profile_screen.dart      # Edit profile
│   ├── create_post_screen.dart       # Create new post
│   ├── comments_screen.dart  # Post comments
│   └── ...
├── services/
│   ├── supabase_service.dart # Supabase API calls
│   ├── cloudinary_service.dart       # Media uploads
│   ├── otp_service.dart      # OTP handling
│   └── content_provider.dart # Content state management
└── providers/
    └── theme_provider.dart   # Theme management
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK
- Supabase account
- Cloudinary account

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/devopsamman/Kyuon-social-media-app.git
   cd Kyuon-social-media-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a Supabase project
   - Update Supabase URL and anon key in `lib/main.dart`
   - Set up the required tables (profiles, posts, stories, videos, follows, comments)
   - Configure Row Level Security policies

4. **Configure Cloudinary**
   - Create a Cloudinary account
   - Update cloud name and upload preset in `lib/services/cloudinary_service.dart`

5. **Run the app**
   ```bash
   flutter run
   ```

## 📊 Database Schema

### Tables
- **profiles** - User profile information
- **posts** - User posts with images
- **stories** - Temporary story content
- **videos** - Reel videos
- **follows** - Follow relationships
- **comments** - Post comments
- **story_views** - Story view tracking

## 🔐 Security

- **Row Level Security (RLS)** - All tables are protected with RLS policies
- **OTP Verification** - Email-based authentication
- **Secure Media Upload** - Cloudinary signed uploads

## 📱 Screenshots

*Coming soon*

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

## 👨‍💻 Author

**Amman** - [GitHub](https://github.com/devopsamman)

---

Made with ❤️ using Flutter
