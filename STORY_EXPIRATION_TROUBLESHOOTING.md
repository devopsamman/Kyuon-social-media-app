# Story 24-Hour Expiration - Troubleshooting Guide

## Issue
Stories from 4+ days ago are still showing in the app after implementing the 24-hour filter.

## Root Cause
The filter was correctly implemented in `supabase_service.dart`, but the app needs to be restarted or data refreshed to apply the new filter.

## Solution Steps

### 1. **Stop and Restart the App** (REQUIRED)
The app must be completely restarted (not just hot reload) because:
- The `ContentProvider` caches data on app start
- Hot reload doesn't re-initialize providers
- The old stories are still in memory

**How to restart:**
```bash
# Stop the app completely
# Then run:
flutter run
```

### 2. **Pull to Refresh** (Alternative)
If you don't want to restart, pull down on the home feed to refresh the data.

### 3. **Verify the Filter is Working**
After restart, check the console logs. You should see:
```
Fetched X stories (last 24 hours)
```

If you still see old stories, it means the database has stories with incorrect `created_at` timestamps.

## Testing the Filter

### Check Current Time vs Story Time
The filter logic:
```dart
final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
// Only fetches stories where created_at >= twentyFourHoursAgo
```

### Example
```
Current Time: 2025-12-21 23:28:00
24 Hours Ago: 2025-12-20 23:28:00

Stories created AFTER  2025-12-20 23:28:00 ✅ VISIBLE
Stories created BEFORE 2025-12-20 23:28:00 ❌ HIDDEN
```

## If Stories Still Show After Restart

### Option 1: Manual Database Check
Query your database directly to see story timestamps:
```sql
SELECT id, user_name, created_at, 
       (NOW() - created_at) as age
FROM stories
ORDER BY created_at DESC;
```

### Option 2: Verify Filter in Code
Double-check the filter in `lib/services/supabase_service.dart` line 149-158:
```dart
Future<List<StoryData>> getStories() async {
  try {
    // Calculate the timestamp for 24 hours ago
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    
    final response = await _client
        .from('stories')
        .select('*')
        .gte('created_at', twentyFourHoursAgo.toIso8601String()) // THIS LINE
        .order('created_at', ascending: false);
```

### Option 3: Add Debug Logging
Temporarily add this to see what's happening:
```dart
final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
print('Current time: ${DateTime.now()}');
print('24 hours ago: $twentyFourHoursAgo');
print('Filter timestamp: ${twentyFourHoursAgo.toIso8601String()}');
```

## Clean Slate Approach

If nothing works, do a complete clean build:
```bash
flutter clean
flutter pub get
flutter run
```

## Database Timezone Issues

If your database is in a different timezone, stories might not filter correctly.

**Solution:** Ensure your Supabase database uses UTC timestamps (it should by default).

## Expected Behavior After Fix

✅ Only stories from the last 24 hours appear
✅ Stories older than 24 hours are hidden (but remain in database)
✅ Expiration happens automatically
✅ No manual cleanup needed
✅ Works for all users

## Still Not Working?

The most common reasons:
1. **App not restarted** - Hot reload won't work
2. **Old data in memory** - Pull to refresh
3. **Database timestamps wrong** - Check created_at column
4. **Timezone mismatch** - Verify database uses UTC

Remember: The filter works at the **query level**, so old stories are never even fetched from the database.
