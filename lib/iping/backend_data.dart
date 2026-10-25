import '../ui/proxy_style.dart';
import '../models/log.dart';
import '../models/tracker.dart';

export '../ui/proxy_style.dart' show ProxiesSortType;
export '../models/delay.dart';
export '../models/log.dart';
export '../models/tracker.dart';

const ipingBackendPageSize = 60;
const _computedProxyTypes = {'URLTest', 'Fallback'};

String? ipingProxySelection({
  required String type,
  required String name,
  required String pinned,
}) {
  final computed = _computedProxyTypes.contains(type);
  if (type != 'Selector' && !computed) return null;
  return computed && pinned == name ? '' : name;
}

class IpingProxyQuery {
  const IpingProxyQuery({
    this.group = '',
    this.offset = 0,
    this.query = '',
    this.sort = ProxiesSortType.none,
    this.hideTimeout = false,
  });

  final String group;
  final int offset;
  final String query;
  final ProxiesSortType sort;
  final bool hideTimeout;
}

class IpingProxyNode {
  const IpingProxyNode({
    required this.name,
    required this.type,
    this.selected = '',
    this.delay,
  });

  final String name;
  final String type;
  final String selected;
  final int? delay;
}

class IpingProxyGroup {
  const IpingProxyGroup({
    required this.name,
    required this.type,
    required this.count,
    this.selected = '',
    this.pinned = '',
    this.icon = '',
    this.selectedIndex = -1,
  });

  final String name;
  final String type;
  final int count;
  final String selected;
  final String pinned;
  final String icon;
  final int selectedIndex;

  bool get computed => _computedProxyTypes.contains(type);
  bool get selectable => type == 'Selector' || computed;

  String? selectionFor(String name) =>
      ipingProxySelection(type: type, name: name, pinned: pinned);
}

class IpingProxyPage {
  const IpingProxyPage({
    this.groups = const [],
    this.group = '',
    this.items = const [],
    this.total = 0,
    this.offset = 0,
    this.selectedIndex = -1,
  });

  final List<IpingProxyGroup> groups;
  final String group;
  final List<IpingProxyNode> items;
  final int total;
  final int offset;
  final int selectedIndex;
}

class IpingConnectionQuery {
  const IpingConnectionQuery({
    this.query = '',
    this.offset = 0,
    this.limit = ipingBackendPageSize,
  }) : assert(limit == null || limit > 0);

  final String query;
  final int offset;
  final int? limit;
}

class IpingConnectionPage {
  const IpingConnectionPage({
    this.items = const [],
    this.total = 0,
    this.offset = 0,
  });

  final List<TrackerInfo> items;
  final int total;
  final int offset;
}

class IpingLogSnapshot {
  const IpingLogSnapshot({required this.logs, this.source});

  final List<Log> logs;
  final String? source;
}
