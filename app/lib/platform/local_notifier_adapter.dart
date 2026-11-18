import 'package:core/core.dart';
import 'package:local_notifier/local_notifier.dart';

/// [Notifier] on local_notifier. Plugin-backed: UI isolate only.
/// [onAction] receives the notification's `actionId` when the user clicks it.
class LocalNotifierAdapter implements Notifier {
  LocalNotifierAdapter({this.onAction});
  final void Function(String actionId)? onAction;

  static Future<void> setup() => localNotifier.setup(appName: 'Ant Manager');

  @override
  Future<void> show({required String title, required String body, String? actionId}) {
    final n = LocalNotification(title: title, body: body);
    if (actionId != null && onAction != null) n.onClick = () => onAction!(actionId);
    return n.show();
  }
}
