import 'package:dio/dio.dart';

import 'http_client_stub.dart'
    if (dart.library.io) 'http_client_io.dart'
    if (dart.library.js_interop) 'http_client_web.dart'
    as platform;

void configureIpingHttpClient(Dio dio) =>
    platform.configureIpingHttpClient(dio);
