import 'package:local_auth/local_auth.dart';

/// Best-effort biometric gate. If the device has no biometric or the user
/// hasn't enabled it, this never blocks. `ponytail:` ceiling — a real PIN
/// fallback + per-launch retry is v0.2.

class BiometricGate {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether the device can do biometrics at all.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Authenticate; returns true only if the user passes. Non-fatal on error.
  Future<bool> gate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock your ledger',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
