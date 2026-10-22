import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Typed, instance-owned interaction state. Keep the provider identity in the
/// owning ConsumerState; autoDispose releases it after the widget stops watching.
NotifierProvider<LocalValue<T>, T> localValueProvider<T>(T initial) =>
    NotifierProvider.autoDispose<LocalValue<T>, T>(() => LocalValue(initial));

class LocalValue<T> extends Notifier<T> {
  LocalValue(this.initial);
  final T initial;
  @override
  T build() => initial;
  void set(T value) => state = value;
  void update(T Function(T) change) => state = change(state);
}

/// Bridges a Flutter controller into Riverpod without a second mutable value in
/// the widget. The widget owns the controller; the provider owns its listener.
class ControllerText extends Notifier<String> {
  ControllerText(this.controller);
  final TextEditingController controller;
  @override
  String build() {
    void changed() => state = controller.text;
    controller.addListener(changed);
    ref.onDispose(() => controller.removeListener(changed));
    return controller.text;
  }
}
