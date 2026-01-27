# Quick Fixes - Code Examples

## 🔧 Critical Fixes You Can Implement Now

### 1. Add Debouncing to Search

**File**: `lib/shoe_list_view.dart`

```dart
import 'dart:async';

class _ShoeListViewState extends State<ShoeListView> {
  Timer? _debounceTimer;
  
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase().trim();
        });
      }
    });
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

### 2. Improve Error Handling in Firebase Service

**File**: `lib/Services/firebase_service.dart`

```dart
Future<List<Shoe>> fetchData() async {
  final url = Uri.parse(dotenv.env['TEST_URI_DATA'] ?? '');
  
  if (url.toString().isEmpty) {
    throw Exception('Data URL not configured');
  }

  List<Shoe> shoes = [];
  try {
    final response = await http.get(url).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Request timed out');
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      for (var item in data) {
        try {
          final shoe = Shoe.fromJson(item as Map<String, dynamic>);
          if (shoe.itemId > 0) shoes.add(shoe);
        } catch (e) {
          AppLogger.log('Error mapping shoe: $e');
          // Continue processing other items
        }
      }
    } else {
      throw HttpException('Failed to fetch data: ${response.statusCode}');
    }
  } on TimeoutException {
    rethrow;
  } on HttpException {
    rethrow;
  } catch (e) {
    AppLogger.log('Unexpected error fetching data: $e');
    throw Exception('Failed to fetch shoe data: ${e.toString()}');
  }
  
  return shoes;
}
```

### 3. Add Loading States

**File**: `lib/shoe_list_view.dart`

```dart
// Add to state
bool _isInitialLoading = true;

// In StreamBuilder
StreamBuilder<List<Shoe>>(
  stream: _shoeStream,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting && 
        _isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading shoes...'),
          ],
        ),
      );
    }
    
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading shoes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              snapshot.error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _isInitialLoading = true);
                // Retry logic
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    _isInitialLoading = false;
    // ... rest of your code
  },
)
```

### 4. Improve Empty State

**File**: `lib/shoe_list_view.dart`

```dart
if (_displayedShoes.isEmpty) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty 
              ? Icons.search_off 
              : Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
              ? 'No shoes found'
              : 'No shoes yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
              ? 'Try adjusting your search terms'
              : 'Tap the + button to add your first shoe!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _searchController.clear(),
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    ),
  );
}
```

### 5. Add Retry Mechanism

**File**: `lib/shoe_list_view.dart`

```dart
Future<void> _onRefreshData() async {
  setState(() => _isLoadingExternalData = true);
  final firebaseService = context.read<FirebaseService>();

  int retryCount = 0;
  const maxRetries = 3;
  
  while (retryCount < maxRetries) {
    try {
      final fetchedShoes = await firebaseService.fetchData();
      // ... existing success logic
      
      if (mounted) {
        setState(() => _isLoadingExternalData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fetched ${fetchedShoes.length} item(s). Added ${newAvailableShoes.length} new.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      return; // Success, exit retry loop
      
    } catch (error) {
      retryCount++;
      if (retryCount >= maxRetries) {
        // Final failure
        if (mounted) {
          setState(() => _isLoadingExternalData = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed after $maxRetries attempts: $error'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _onRefreshData,
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      // Wait before retry (exponential backoff)
      await Future.delayed(Duration(seconds: retryCount));
    }
  }
}
```

### 6. Optimize Image Loading

**File**: `lib/shoe_list_view.dart`

```dart
void _warmUpImages(List<Shoe> shoes) {
  final cache = ShoeViewCacheManager();
  
  // Only warm up first 20 items (visible + buffer)
  final itemsToWarm = shoes.take(20).toList();
  
  // Load in batches to avoid overwhelming the system
  const batchSize = 5;
  for (int i = 0; i < itemsToWarm.length; i += batchSize) {
    final batch = itemsToWarm.skip(i).take(batchSize);
    
    // Small delay between batches
    Future.delayed(Duration(milliseconds: 100 * (i ~/ batchSize)), () {
      for (var shoe in batch) {
        if (shoe.remoteImageUrl.isNotEmpty) {
          cache.getCachedOrDownloadFile(shoe.remoteImageUrl);
        }
      }
    });
  }
}
```

### 7. Add Constants File

**File**: `lib/shared/constants/app_constants.dart`

```dart
class AppConstants {
  // Cache
  static const int maxCacheSize = 500;
  static const Duration cacheStalePeriod = Duration(days: 60);
  
  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Search
  static const Duration searchDebounceDelay = Duration(milliseconds: 500);
  
  // Network
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  
  // Pagination
  static const int itemsPerPage = 20;
  static const int imageWarmupCount = 20;
  static const int imageBatchSize = 5;
  
  // Image
  static const double defaultImageSize = 100.0;
  static const double listItemImageSize = 60.0;
}
```

### 8. Improve Delete Confirmation

**File**: `lib/shoe_list_view.dart`

```dart
void _deleteShoe(Shoe shoe) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      title: const Text('Delete Shoe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to delete this shoe?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shoe.shoeDetail,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('ID: ${shoe.itemId} | Shipment: ${shoe.shipmentId}'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This action cannot be undone.',
            style: TextStyle(
              color: Colors.red[700],
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  ) ?? false;

  if (confirmed && mounted) {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final firebaseService = context.read<FirebaseService>();
      final response = await firebaseService.deleteShoe(shoe);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
      }
      
      if (response['success'] == false && mounted) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Error',
            message: response['message'] ?? 'Failed to delete shoe',
            onDismissed: () {},
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shoe deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Error',
            message: 'Failed to delete shoe: ${e.toString()}',
            onDismissed: () {},
          ),
        );
      }
    }
  }
}
```

### 9. Add Skeleton Loader

**File**: `lib/shared/widgets/skeleton_loader.dart`

```dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShoeListItemSkeleton extends StatelessWidget {
  const ShoeListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 16.0,
        ),
        leading: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        title: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 16,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 12,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Add to pubspec.yaml:**
```yaml
dependencies:
  shimmer: ^3.0.0
```

### 10. Improve Theme Configuration

**File**: `lib/main.dart`

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppStatusNotifier>().themeMode;

    return MaterialApp(
      title: 'Shoe View',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        // Add consistent text styles
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 12),
        ),
        // Add consistent spacing
        cardTheme: CardTheme(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        // Same text theme for dark mode
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          // ... same as light theme
        ),
      ),
      themeMode: themeMode,
      home: const AuthScreen(),
    );
  }
}
```

---

## 📦 Required Dependencies

Add these to `pubspec.yaml`:

```yaml
dependencies:
  shimmer: ^3.0.0  # For skeleton loaders
  # Add other dependencies as needed
```

---

## ✅ Testing Checklist

After implementing fixes:

- [ ] Test search debouncing (type quickly, verify delay)
- [ ] Test error handling (simulate network failure)
- [ ] Test loading states (verify skeletons appear)
- [ ] Test empty states (verify helpful messages)
- [ ] Test retry mechanism (verify retries work)
- [ ] Test image loading (verify optimization works)
- [ ] Test delete confirmation (verify improved UX)
- [ ] Test theme changes (verify consistency)

---

*These fixes address the most critical issues identified in the code review.*
