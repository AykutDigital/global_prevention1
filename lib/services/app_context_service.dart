import 'package:flutter/foundation.dart';

class AppContextService {
  static final AppContextService instance = AppContextService._();
  AppContextService._();

  final ValueNotifier<bool> isVeriflammeActive = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isSauvdefibActive = ValueNotifier<bool>(true);

  void setBranches({required bool veriflamme, required bool sauvdefib}) {
    isVeriflammeActive.value = veriflamme;
    isSauvdefibActive.value = sauvdefib;
  }

  void toggleVeriflamme() {
    isVeriflammeActive.value = !isVeriflammeActive.value;
  }

  void toggleSauvdefib() {
    isSauvdefibActive.value = !isSauvdefibActive.value;
  }

  bool get isGlobalMode => isVeriflammeActive.value && isSauvdefibActive.value;
  bool get isVeriflammeOnly => isVeriflammeActive.value && !isSauvdefibActive.value;
  bool get isSauvdefibOnly => !isVeriflammeActive.value && isSauvdefibActive.value;
}
