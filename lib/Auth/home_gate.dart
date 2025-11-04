// --- HomeGate.dart ---

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/Services/firebase_service.dart';
import 'package:shoe_view/shoe_list_view.dart';
import 'package:shoe_view/Subscription/subscription_manager.dart';

class HomeGate extends StatelessWidget {
  final FirebaseService firebaseService;

  const HomeGate({super.key, required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    final appStatusNotifier = context.read<AppStatusNotifier>();
    return MultiProvider(
      providers: [
        // 1. Inject FirebaseService (Stateless/Read-only Service)
        // Use the basic Provider.value constructor since it is NOT a ChangeNotifier.
        Provider<FirebaseService>.value(
          value:
              firebaseService, // The instance created in AuthScreen is passed here.
        ),

        // 2. Inject SubscriptionManager (Stateful/ChangeNotifier Service)
        // Use ChangeNotifierProvider because it implements ChangeNotifier.
        ChangeNotifierProvider(
          // The manager is created ONCE here, using the injected firebaseService.
          create: (_) =>
              SubscriptionManager(firebaseService, appStatusNotifier),
          lazy:
              false, // Ensures IAP initialization starts immediately on entry.
        ),
      ],
      // ShoeListView and all its children can now access both services using context.read<T>() or context.watch<T>().
      child: ShoeListView(),
    );
  }
}
