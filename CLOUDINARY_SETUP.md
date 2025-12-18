# Cloudinary Setup Instructions

## Step 1: Create Cloudinary Account
1. Go to https://cloudinary.com/
2. Sign up for a free account
3. Verify your email

## Step 2: Get Your Credentials
1. Login to Cloudinary Dashboard
2. Copy your **Cloud Name** from the dashboard
3. Go to Settings → Upload → Upload presets
4. Create a new unsigned upload preset or use "ml_default"
5. Copy the preset name

## Step 3: Update the App
Open `lib/services/cloudinary_service.dart` and replace:

```dart
static const String cloudName = 'YOUR_CLOUD_NAME';
static const String uploadPreset = 'YOUR_UPLOAD_PRESET';
```

With your actual credentials:

```dart
static const String cloudName = 'your-actual-cloud-name';
static const String uploadPreset = 'your-actual-preset-name';
```

## Step 4: Test Upload
1. Run the app
2. Go to Compose tab
3. Try creating a post, story, or reel
4. Check your Cloudinary Media Library to see uploaded files

## Folder Structure in Cloudinary
- Posts: `kyuon/posts/`
- Stories: `kyuon/stories/`
- Reels: `kyuon/reels/`

## Features Implemented
✅ Upload images for posts (with caption)
✅ Upload images for stories
✅ Upload videos for reels (with caption)
✅ Real-time feed updates
✅ Content stored in Cloudinary CDN
✅ Provider state management for all content

## How to Use
1. **Create Post**: Compose → Create Post → Add caption + image
2. **Create Story**: Compose → Create Story → Select image
3. **Create Reel**: Compose → Create Reel → Select video + caption

All uploaded content will appear in the feed/stories/reels for all users!
