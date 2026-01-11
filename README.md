👟 ShoeView
ShoeView is am inventory management system built for footwear retailers. It is designed with an offline-first architecture to ensure business continuity regardless of network stability, while maintaining real-time consistency across multiple devices.

Core Capabilities
Offline-First Synchronization: The app intelligently persists user configurations, application state, and smart suggestions locally using SharedPreferences. This allows for near-instant app launches and full functionality in low-connectivity environments.

Cross-Device Consistency: Local states are automatically synchronized with Cloud Firestore. This dual-layer approach ensures that settings and inventory data remain consistent and up-to-date across all authorized devices.

Serverless API Integration: All CRUD (Create, Read, Update, Delete) operations are handled through a secure Firebase Functions API. This centralizes business logic and ensures data integrity through server-side validation.

Secure Multi-Stage Auth: Integration with Google Sign-In and Firebase Auth provides a seamless login experience, utilizing specialized loading states to manage identity verification and permission checks.

Dynamic UI Management: Powered by a centralized AppStatusNotifier, the interface adapts instantly to changes in currency, repair status, and specialized pricing modes.
