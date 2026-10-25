import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'client_web.dart';

void main() {
  runApp(const RouterApp(client: WebRouterClient()));
}
