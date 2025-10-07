import 'dart:async';
import 'facebook_service.dart';

class SimpleLiveNotificationService {
  final FacebookService _facebookService = FacebookService();
  Timer? _monitoringTimer;
  bool _wasLive = false;

  // Callback for when live status changes
  Function(bool)? onLiveStatusChanged;

  void startMonitoring() {
    // Check every 2 minutes for live broadcasts
    _monitoringTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      await _checkLiveStatus();
    });
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
  }

  Future<void> _checkLiveStatus() async {
    try {
      final isLive = await _facebookService.isLiveNow();
      
      // If status changed, notify listeners
      if (isLive != _wasLive) {
        _wasLive = isLive;
        onLiveStatusChanged?.call(isLive);
      }
    } catch (e) {
      print('Error monitoring live status: $e');
    }
  }

  void dispose() {
    stopMonitoring();
  }
}