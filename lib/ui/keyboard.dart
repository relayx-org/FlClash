import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

SingleActivator controlSingleActivator(LogicalKeyboardKey trigger) {
  final control = !(kIsWeb
      ? defaultTargetPlatform == TargetPlatform.macOS
      : Platform.isMacOS);
  return SingleActivator(trigger, control: control, meta: !control);
}
