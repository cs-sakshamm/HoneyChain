import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/telemetry_alert_controller.dart';
import '../../core/widgets/critical_alert_dialog.dart';
import '../profile/controllers/user_controller.dart';

/// Global persistent emergency-alert host.
///
/// Sits above the entire navigator (see app.dart) so a critical alert:
///  * stays visible until the Harvester explicitly acknowledges it,
///  * is not dismissed by navigation — there is no route to pop,
///  * is restored automatically on app restart, because the controller
///    re-fetches ACTIVE alerts from the backend on every poll.
///
/// Alerts are queued: the controller surfaces the newest unacknowledged
/// critical alert; acknowledging it reveals the next one on the following
/// poll, so multiple simultaneous alerts are never lost.
class CriticalAlertModalWrapper extends StatelessWidget {
  final Widget child;

  const CriticalAlertModalWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Consumer<TelemetryAlertController>(
          builder: (context, controller, _) {
            final alert = controller.activeUnacknowledgedAlert;
            if (controller.isAlertPopupOpen && alert != null) {
              // Full-screen scrim blocks interaction with the app beneath;
              // PopScope-free Stack placement means back-navigation cannot
              // silently dismiss the emergency.
              return Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.72),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.92, end: 1.0),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, alertWidget) {
                          return Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: scale.clamp(0.0, 1.0),
                              child: alertWidget,
                            ),
                          );
                        },
                        child: CriticalAlertDialog(
                          alert: alert,
                          onAcknowledge: () {
                            final user = context.read<UserController>().user;
                            controller.acknowledgeAlert(
                              alert.id,
                              userId: (user.id != null && user.id!.isNotEmpty) ? user.id : user.email,
                              userName: user.name,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
