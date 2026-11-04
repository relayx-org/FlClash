import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

void configureIpingHttpClient(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => _SecureHttpOverrides().createClient(),
  );
}

class _SecureHttpOverrides extends HttpOverrides {
  HttpClient createClient() =>
      super.createHttpClient(SecurityContext.defaultContext);
}
