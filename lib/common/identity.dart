import 'package:flutter_riverpod/flutter_riverpod.dart';

final identityProvider = Provider<String Function()>((ref) {
  var sequence = 0;
  return () => '${DateTime.now().microsecondsSinceEpoch}-${sequence++}';
});
