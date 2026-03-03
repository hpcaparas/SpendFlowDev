import '../features/auth/token_store.dart';
import '../services/push_notification_service.dart';
import '../core/config/app_config.dart'; // wherever your apiBaseUrl is

class PushBootstrap {
  static Future<void> registerAfterLogin() async {
    // You already store tokens in TokenStore
    final jwt = await TokenStore.getAccessToken();
    final userId = await TokenStore.getUserId();
    final companyId = await TokenStore.getCompanyId();

    if (jwt == null || userId == null || companyId == null) return;

    // Don't crash login if push fails
    try {
      await PushNotificationService().initAndRegister(
        baseUrl: AppConfig.baseUrl,
        jwt: jwt,
        userId: userId,
        companyId: companyId,
      );
    } catch (_) {
      // log if you want; ignore for UX
    }
  }
}
