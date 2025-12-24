# 🔧 Profile Navigation - Complete Fix Guide

## ✅ **Fixed Issues:**

### **1. Bottom Nav Bar Issue** ✅
- **Problem:** Clicking current user in search opens profile WITHOUT bottom nav
- **Solution:** Use `MainNavigationScaffold(initialIndex: 4)` instead of pushing `ProfileScreen`
- **Status:** FIXED in search_screen.dart

### **2. Username Click in Posts/Reels** ⚠️
- **Problem:** Username/avatar in UserPostsView and UserReelsView doesn't open profile
- **Solution:** These screens need profile navigation added
- **Status:** NEEDS FIX

---

## 🎯 **What Works Now:**

### **From Search Results:**
```dart
Click on current user → MainNavigationScaffold (Profile tab) ✅
  - Shows bottom navigation bar
  - Opens profile screen
  - Can navigate to other tabs

Click on other user → OtherUserProfileScreen ✅
  - Full screen profile
  - No bottom nav (correct)
  - Back button works
```

---

## ⚠️ **What Still Needs Fix:**

### **UserPostsView.dart:**
The username and avatar in post headers need click handlers.

**Add this to UserPostsView:**

```dart
// In the header section where username is displayed
GestureDetector(
  onTap: () {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == post.userId) {
      // Current user's post - go to profile tab
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationScaffold(initialIndex: 4),
        ),
        (route) => false,
      );
    } else {
      // Other user's post - open their profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfileScreen(userId: post.userId),
        ),
      );
    }
  },
  child: Text(
    post.username,
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
)
```

### **UserReelsView.dart:**
Similar fix needed for reel headers.

**Add this to UserReelsView:**

```dart
// In the overlay where username is displayed
GestureDetector(
  onTap: () {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == reel.uploaderId) {
      // Current user's reel - go to profile tab
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationScaffold(initialIndex: 4),
        ),
        (route) => false,
      );
    } else {
      // Other user's reel - open their profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfileScreen(userId: reel.uploaderId),
        ),
      );
    }
  },
  child: Text(
    reel.username,
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
)
```

---

## 📋 **Implementation Steps:**

### **Step 1: Find Username Display in UserPostsView**
Look for where the username is displayed (likely in the header of each post).

### **Step 2: Wrap Username with GestureDetector**
Add the onTap handler with user check as shown above.

### **Step 3: Do Same for Avatar**
Wrap CircleAvatar or profile image with GestureDetector too.

### **Step 4: Repeat for UserReelsView**
Find username/avatar in reel overlay and add same logic.

### **Step 5: Add Imports**
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // For MainNavigationScaffold
import 'other_user_profile_screen.dart';
```

---

## 🎨 **Expected Behavior:**

### **Current User's Content:**
```
Click username/avatar
    ↓
Navigator.pushAndRemoveUntil
    ↓
MainNavigationScaffold(initialIndex: 4)
    ↓
Shows Profile tab with bottom nav ✅
```

### **Other User's Content:**
```
Click username/avatar
    ↓
Navigator.push
    ↓
OtherUserProfileScreen
    ↓
Full screen profile, back button ✅
```

---

## ⚡ **Quick Copy-Paste:**

### **For Both UserPostsView and UserReelsView:**

Add this helper method to the State class:

```dart
void _navigateToProfile(BuildContext context, String userId) {
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  
  if (currentUserId == userId) {
    // Own content - go to profile tab
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainNavigationScaffold(initialIndex: 4),
      ),
      (route) => false,
    );
  } else {
    // Other's content - open their profile
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(userId: userId),
      ),
    );
  }
}
```

Then use it:
```dart
GestureDetector(
  onTap: () => _navigateToProfile(context, post.userId),
  child: Text(post.username),
)
```

---

## 🧪 **Test Checklist:**

- [ ] Search for current user → Click → Shows profile with bottom nav
- [ ] Search for other user → Click → Shows their profile without bottom nav
- [ ] Open post from search → Click username → Opens profile
- [ ] Open reel from search → Click username → Opens profile
- [ ] Own post → Click username → Goes to profile tab
- [ ] Other's post → Click username → Opens their profile
- [ ] All back buttons work correctly

---

## 📝 **Files to Edit:**

1. ✅ **search_screen.dart** - DONE
2. ⚠️ **user_posts_view.dart** - TODO
3. ⚠️ **user_reels_view.dart** - TODO

---

**Search screen is fixed! Now need to update UserPostsView and UserReelsView!**
