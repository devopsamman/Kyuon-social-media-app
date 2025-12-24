# Story 24-Hour Expiration Implementation

## Overview
Stories now automatically expire after 24 hours. They remain in the database for record-keeping but are no longer displayed to any users.

## Implementation Details

### Query Filter
The story fetching logic in `supabase_service.dart` now includes a time-based filter:

```dart
// Calculate the timestamp for 24 hours ago
final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));

final response = await _client
    .from('stories')
    .select('*')
    .gte('created_at', twentyFourHoursAgo.toIso8601String()) // Only fetch stories from last 24 hours
    .order('created_at', ascending: false);
```

### How It Works

1. **Calculation**: Every time stories are fetched, the app calculates the timestamp for 24 hours ago
2. **Filter**: Only stories with `created_at >= 24 hours ago` are retrieved
3. **Database**: Stories older than 24 hours remain in the database but are not fetched
4. **Universal**: This applies to all users - both the story owner and viewers

## Behavior

### For Story Owners
- Stories created less than 24 hours ago: ✅ Visible
- Stories created more than 24 hours ago: ❌ Hidden (but still in database)

### For Other Users
- Stories created less than 24 hours ago: ✅ Visible
- Stories created more than 24 hours ago: ❌ Hidden (but still in database)

## Benefits

1. **Data Preservation**: Stories are never deleted from the database
2. **Automatic Cleanup**: No manual cleanup required
3. **Real-time**: Expiration happens automatically based on current time
4. **Consistent**: Same behavior for all users
5. **Analytics Ready**: Old stories remain available for analytics/reports

## Example Timeline

```
Story created: 2025-12-21 10:00:00
Current time:  2025-12-21 15:00:00 → Story VISIBLE (5 hours old)
Current time:  2025-12-22 09:00:00 → Story VISIBLE (23 hours old)
Current time:  2025-12-22 10:01:00 → Story HIDDEN (24+ hours old)
```

## Database Impact

- Stories table structure: Unchanged
- No new columns needed
- Uses existing `created_at` timestamp
- Old stories accumulate in database (can be cleaned up later if needed)

## Future Enhancements (Optional)

If you want to clean up old stories from the database:

1. **Scheduled Deletion**: Create a Supabase Edge Function to delete stories older than 30 days
2. **Archive Table**: Move old stories to an archive table
3. **Soft Delete**: Add an `is_deleted` flag instead of filtering by time

For now, the current implementation provides Instagram-like story behavior with automatic 24-hour expiration.
