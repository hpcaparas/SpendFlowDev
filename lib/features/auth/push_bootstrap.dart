import 'token_store.dart';
import '../../services/push_notification_service.dart';
import '../../core/config/app_config.dart'; // wherever your apiBaseUrl is

class PushBootstrap {
  static Future<void> registerAfterLogin() async {
    final jwt = await TokenStore.getAccessToken();
    final userId = await TokenStore.getUserId();
    final companyId = await TokenStore.getCompanyId();

    if (jwt == null || jwt.isEmpty || userId == null || companyId == null)
      return;

    try {
      await PushNotificationService().initAndRegister(
        baseUrl: AppConfig.baseUrl,
        jwt: jwt,
        userId: userId,
        companyId: companyId,
      );
    } catch (_) {
      // Don't block login UX if push fails
    }
  }
}
