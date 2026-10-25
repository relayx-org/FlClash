// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../tracker.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Metadata {

 int get uid; String get network; String get sourceIP; String get sourcePort; String get destinationIP; String get destinationPort; String get host; DnsMode? get dnsMode; String get process; String get processPath; String get remoteDestination; List<String> get sourceGeoIP; List<String> get destinationGeoIP; String get destinationIPASN; String get sourceIPASN; String get specialRules; String get specialProxy;
/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetadataCopyWith<Metadata> get copyWith => _$MetadataCopyWithImpl<Metadata>(this as Metadata, _$identity);

  /// Serializes this Metadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Metadata;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Metadata&&(identical(other.uid, _this.uid) || other.uid == _this.uid)&&(identical(other.network, _this.network) || other.network == _this.network)&&(identical(other.sourceIP, _this.sourceIP) || other.sourceIP == _this.sourceIP)&&(identical(other.sourcePort, _this.sourcePort) || other.sourcePort == _this.sourcePort)&&(identical(other.destinationIP, _this.destinationIP) || other.destinationIP == _this.destinationIP)&&(identical(other.destinationPort, _this.destinationPort) || other.destinationPort == _this.destinationPort)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.dnsMode, _this.dnsMode) || other.dnsMode == _this.dnsMode)&&(identical(other.process, _this.process) || other.process == _this.process)&&(identical(other.processPath, _this.processPath) || other.processPath == _this.processPath)&&(identical(other.remoteDestination, _this.remoteDestination) || other.remoteDestination == _this.remoteDestination)&&const DeepCollectionEquality().equals(other.sourceGeoIP, _this.sourceGeoIP)&&const DeepCollectionEquality().equals(other.destinationGeoIP, _this.destinationGeoIP)&&(identical(other.destinationIPASN, _this.destinationIPASN) || other.destinationIPASN == _this.destinationIPASN)&&(identical(other.sourceIPASN, _this.sourceIPASN) || other.sourceIPASN == _this.sourceIPASN)&&(identical(other.specialRules, _this.specialRules) || other.specialRules == _this.specialRules)&&(identical(other.specialProxy, _this.specialProxy) || other.specialProxy == _this.specialProxy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Metadata;
  return Object.hash(runtimeType,_this.uid,_this.network,_this.sourceIP,_this.sourcePort,_this.destinationIP,_this.destinationPort,_this.host,_this.dnsMode,_this.process,_this.processPath,_this.remoteDestination,const DeepCollectionEquality().hash(_this.sourceGeoIP),const DeepCollectionEquality().hash(_this.destinationGeoIP),_this.destinationIPASN,_this.sourceIPASN,_this.specialRules,_this.specialProxy);
}

@override
String toString() {
  final _this = this as Metadata;
  return 'Metadata(uid: ${_this.uid}, network: ${_this.network}, sourceIP: ${_this.sourceIP}, sourcePort: ${_this.sourcePort}, destinationIP: ${_this.destinationIP}, destinationPort: ${_this.destinationPort}, host: ${_this.host}, dnsMode: ${_this.dnsMode}, process: ${_this.process}, processPath: ${_this.processPath}, remoteDestination: ${_this.remoteDestination}, sourceGeoIP: ${_this.sourceGeoIP}, destinationGeoIP: ${_this.destinationGeoIP}, destinationIPASN: ${_this.destinationIPASN}, sourceIPASN: ${_this.sourceIPASN}, specialRules: ${_this.specialRules}, specialProxy: ${_this.specialProxy})';
}


}

/// @nodoc
abstract mixin class $MetadataCopyWith<$Res>  {
  factory $MetadataCopyWith(Metadata value, $Res Function(Metadata) _then) = _$MetadataCopyWithImpl;
@useResult
$Res call({
 int uid, String network, String sourceIP, String sourcePort, String destinationIP, String destinationPort, String host, DnsMode? dnsMode, String process, String processPath, String remoteDestination, List<String> sourceGeoIP, List<String> destinationGeoIP, String destinationIPASN, String sourceIPASN, String specialRules, String specialProxy
});




}
/// @nodoc
class _$MetadataCopyWithImpl<$Res>
    implements $MetadataCopyWith<$Res> {
  _$MetadataCopyWithImpl(this._self, this._then);

  final Metadata _self;
  final $Res Function(Metadata) _then;

/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? network = null,Object? sourceIP = null,Object? sourcePort = null,Object? destinationIP = null,Object? destinationPort = null,Object? host = null,Object? dnsMode = freezed,Object? process = null,Object? processPath = null,Object? remoteDestination = null,Object? sourceGeoIP = null,Object? destinationGeoIP = null,Object? destinationIPASN = null,Object? sourceIPASN = null,Object? specialRules = null,Object? specialProxy = null,}) {
  return _then(Metadata(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as int,network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as String,sourceIP: null == sourceIP ? _self.sourceIP : sourceIP // ignore: cast_nullable_to_non_nullable
as String,sourcePort: null == sourcePort ? _self.sourcePort : sourcePort // ignore: cast_nullable_to_non_nullable
as String,destinationIP: null == destinationIP ? _self.destinationIP : destinationIP // ignore: cast_nullable_to_non_nullable
as String,destinationPort: null == destinationPort ? _self.destinationPort : destinationPort // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,dnsMode: freezed == dnsMode ? _self.dnsMode : dnsMode // ignore: cast_nullable_to_non_nullable
as DnsMode?,process: null == process ? _self.process : process // ignore: cast_nullable_to_non_nullable
as String,processPath: null == processPath ? _self.processPath : processPath // ignore: cast_nullable_to_non_nullable
as String,remoteDestination: null == remoteDestination ? _self.remoteDestination : remoteDestination // ignore: cast_nullable_to_non_nullable
as String,sourceGeoIP: null == sourceGeoIP ? _self.sourceGeoIP : sourceGeoIP // ignore: cast_nullable_to_non_nullable
as List<String>,destinationGeoIP: null == destinationGeoIP ? _self.destinationGeoIP : destinationGeoIP // ignore: cast_nullable_to_non_nullable
as List<String>,destinationIPASN: null == destinationIPASN ? _self.destinationIPASN : destinationIPASN // ignore: cast_nullable_to_non_nullable
as String,sourceIPASN: null == sourceIPASN ? _self.sourceIPASN : sourceIPASN // ignore: cast_nullable_to_non_nullable
as String,specialRules: null == specialRules ? _self.specialRules : specialRules // ignore: cast_nullable_to_non_nullable
as String,specialProxy: null == specialProxy ? _self.specialProxy : specialProxy // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Metadata].
extension MetadataPatterns on Metadata {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Metadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Metadata() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Metadata value)  $default,){
final _that = this;
switch (_that) {
case _Metadata():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Metadata value)?  $default,){
final _that = this;
switch (_that) {
case _Metadata() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int uid,  String network,  String sourceIP,  String sourcePort,  String destinationIP,  String destinationPort,  String host,  DnsMode? dnsMode,  String process,  String processPath,  String remoteDestination,  List<String> sourceGeoIP,  List<String> destinationGeoIP,  String destinationIPASN,  String sourceIPASN,  String specialRules,  String specialProxy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Metadata() when $default != null:
return $default(_that.uid,_that.network,_that.sourceIP,_that.sourcePort,_that.destinationIP,_that.destinationPort,_that.host,_that.dnsMode,_that.process,_that.processPath,_that.remoteDestination,_that.sourceGeoIP,_that.destinationGeoIP,_that.destinationIPASN,_that.sourceIPASN,_that.specialRules,_that.specialProxy);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int uid,  String network,  String sourceIP,  String sourcePort,  String destinationIP,  String destinationPort,  String host,  DnsMode? dnsMode,  String process,  String processPath,  String remoteDestination,  List<String> sourceGeoIP,  List<String> destinationGeoIP,  String destinationIPASN,  String sourceIPASN,  String specialRules,  String specialProxy)  $default,) {final _that = this;
switch (_that) {
case _Metadata():
return $default(_that.uid,_that.network,_that.sourceIP,_that.sourcePort,_that.destinationIP,_that.destinationPort,_that.host,_that.dnsMode,_that.process,_that.processPath,_that.remoteDestination,_that.sourceGeoIP,_that.destinationGeoIP,_that.destinationIPASN,_that.sourceIPASN,_that.specialRules,_that.specialProxy);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int uid,  String network,  String sourceIP,  String sourcePort,  String destinationIP,  String destinationPort,  String host,  DnsMode? dnsMode,  String process,  String processPath,  String remoteDestination,  List<String> sourceGeoIP,  List<String> destinationGeoIP,  String destinationIPASN,  String sourceIPASN,  String specialRules,  String specialProxy)?  $default,) {final _that = this;
switch (_that) {
case _Metadata() when $default != null:
return $default(_that.uid,_that.network,_that.sourceIP,_that.sourcePort,_that.destinationIP,_that.destinationPort,_that.host,_that.dnsMode,_that.process,_that.processPath,_that.remoteDestination,_that.sourceGeoIP,_that.destinationGeoIP,_that.destinationIPASN,_that.sourceIPASN,_that.specialRules,_that.specialProxy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Metadata implements Metadata {
  const _Metadata({this.uid = 0, this.network = '', this.sourceIP = '', this.sourcePort = '', this.destinationIP = '', this.destinationPort = '', this.host = '', this.dnsMode, this.process = '', this.processPath = '', this.remoteDestination = '',  List<String> sourceGeoIP = const [],  List<String> destinationGeoIP = const [], this.destinationIPASN = '', this.sourceIPASN = '', this.specialRules = '', this.specialProxy = ''}): _sourceGeoIP = sourceGeoIP,_destinationGeoIP = destinationGeoIP;
  factory _Metadata.fromJson(Map<String, dynamic> json) => _$MetadataFromJson(json);

@override@JsonKey() final  int uid;
@override@JsonKey() final  String network;
@override@JsonKey() final  String sourceIP;
@override@JsonKey() final  String sourcePort;
@override@JsonKey() final  String destinationIP;
@override@JsonKey() final  String destinationPort;
@override@JsonKey() final  String host;
@override final  DnsMode? dnsMode;
@override@JsonKey() final  String process;
@override@JsonKey() final  String processPath;
@override@JsonKey() final  String remoteDestination;
 final  List<String> _sourceGeoIP;
@override@JsonKey() List<String> get sourceGeoIP {
  if (_sourceGeoIP is EqualUnmodifiableListView) return _sourceGeoIP;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sourceGeoIP);
}

 final  List<String> _destinationGeoIP;
@override@JsonKey() List<String> get destinationGeoIP {
  if (_destinationGeoIP is EqualUnmodifiableListView) return _destinationGeoIP;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_destinationGeoIP);
}

@override@JsonKey() final  String destinationIPASN;
@override@JsonKey() final  String sourceIPASN;
@override@JsonKey() final  String specialRules;
@override@JsonKey() final  String specialProxy;

/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MetadataCopyWith<_Metadata> get copyWith => __$MetadataCopyWithImpl<_Metadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetadataToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Metadata&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.network, network) || other.network == network)&&(identical(other.sourceIP, sourceIP) || other.sourceIP == sourceIP)&&(identical(other.sourcePort, sourcePort) || other.sourcePort == sourcePort)&&(identical(other.destinationIP, destinationIP) || other.destinationIP == destinationIP)&&(identical(other.destinationPort, destinationPort) || other.destinationPort == destinationPort)&&(identical(other.host, host) || other.host == host)&&(identical(other.dnsMode, dnsMode) || other.dnsMode == dnsMode)&&(identical(other.process, process) || other.process == process)&&(identical(other.processPath, processPath) || other.processPath == processPath)&&(identical(other.remoteDestination, remoteDestination) || other.remoteDestination == remoteDestination)&&const DeepCollectionEquality().equals(other.sourceGeoIP, _sourceGeoIP)&&const DeepCollectionEquality().equals(other.destinationGeoIP, _destinationGeoIP)&&(identical(other.destinationIPASN, destinationIPASN) || other.destinationIPASN == destinationIPASN)&&(identical(other.sourceIPASN, sourceIPASN) || other.sourceIPASN == sourceIPASN)&&(identical(other.specialRules, specialRules) || other.specialRules == specialRules)&&(identical(other.specialProxy, specialProxy) || other.specialProxy == specialProxy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,uid,network,sourceIP,sourcePort,destinationIP,destinationPort,host,dnsMode,process,processPath,remoteDestination,const DeepCollectionEquality().hash(_sourceGeoIP),const DeepCollectionEquality().hash(_destinationGeoIP),destinationIPASN,sourceIPASN,specialRules,specialProxy);
}

@override
String toString() {
    return 'Metadata(uid: $uid, network: $network, sourceIP: $sourceIP, sourcePort: $sourcePort, destinationIP: $destinationIP, destinationPort: $destinationPort, host: $host, dnsMode: $dnsMode, process: $process, processPath: $processPath, remoteDestination: $remoteDestination, sourceGeoIP: $sourceGeoIP, destinationGeoIP: $destinationGeoIP, destinationIPASN: $destinationIPASN, sourceIPASN: $sourceIPASN, specialRules: $specialRules, specialProxy: $specialProxy)';
}


}

/// @nodoc
abstract mixin class _$MetadataCopyWith<$Res> implements $MetadataCopyWith<$Res> {
  factory _$MetadataCopyWith(_Metadata value, $Res Function(_Metadata) _then) = __$MetadataCopyWithImpl;
@override @useResult
$Res call({
 int uid, String network, String sourceIP, String sourcePort, String destinationIP, String destinationPort, String host, DnsMode? dnsMode, String process, String processPath, String remoteDestination, List<String> sourceGeoIP, List<String> destinationGeoIP, String destinationIPASN, String sourceIPASN, String specialRules, String specialProxy
});




}
/// @nodoc
class __$MetadataCopyWithImpl<$Res>
    implements _$MetadataCopyWith<$Res> {
  __$MetadataCopyWithImpl(this._self, this._then);

  final _Metadata _self;
  final $Res Function(_Metadata) _then;

/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? network = null,Object? sourceIP = null,Object? sourcePort = null,Object? destinationIP = null,Object? destinationPort = null,Object? host = null,Object? dnsMode = freezed,Object? process = null,Object? processPath = null,Object? remoteDestination = null,Object? sourceGeoIP = null,Object? destinationGeoIP = null,Object? destinationIPASN = null,Object? sourceIPASN = null,Object? specialRules = null,Object? specialProxy = null,}) {
  return _then(_Metadata(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as int,network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as String,sourceIP: null == sourceIP ? _self.sourceIP : sourceIP // ignore: cast_nullable_to_non_nullable
as String,sourcePort: null == sourcePort ? _self.sourcePort : sourcePort // ignore: cast_nullable_to_non_nullable
as String,destinationIP: null == destinationIP ? _self.destinationIP : destinationIP // ignore: cast_nullable_to_non_nullable
as String,destinationPort: null == destinationPort ? _self.destinationPort : destinationPort // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,dnsMode: freezed == dnsMode ? _self.dnsMode : dnsMode // ignore: cast_nullable_to_non_nullable
as DnsMode?,process: null == process ? _self.process : process // ignore: cast_nullable_to_non_nullable
as String,processPath: null == processPath ? _self.processPath : processPath // ignore: cast_nullable_to_non_nullable
as String,remoteDestination: null == remoteDestination ? _self.remoteDestination : remoteDestination // ignore: cast_nullable_to_non_nullable
as String,sourceGeoIP: null == sourceGeoIP ? _self._sourceGeoIP : sourceGeoIP // ignore: cast_nullable_to_non_nullable
as List<String>,destinationGeoIP: null == destinationGeoIP ? _self._destinationGeoIP : destinationGeoIP // ignore: cast_nullable_to_non_nullable
as List<String>,destinationIPASN: null == destinationIPASN ? _self.destinationIPASN : destinationIPASN // ignore: cast_nullable_to_non_nullable
as String,sourceIPASN: null == sourceIPASN ? _self.sourceIPASN : sourceIPASN // ignore: cast_nullable_to_non_nullable
as String,specialRules: null == specialRules ? _self.specialRules : specialRules // ignore: cast_nullable_to_non_nullable
as String,specialProxy: null == specialProxy ? _self.specialProxy : specialProxy // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TrackerInfo {

 String get id; int get upload; int get download; DateTime get start; Metadata get metadata; List<String> get chains; String get rule; String get rulePayload; int? get downloadSpeed; int? get uploadSpeed;
/// Create a copy of TrackerInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackerInfoCopyWith<TrackerInfo> get copyWith => _$TrackerInfoCopyWithImpl<TrackerInfo>(this as TrackerInfo, _$identity);

  /// Serializes this TrackerInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TrackerInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackerInfo&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.upload, _this.upload) || other.upload == _this.upload)&&(identical(other.download, _this.download) || other.download == _this.download)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.metadata, _this.metadata) || other.metadata == _this.metadata)&&const DeepCollectionEquality().equals(other.chains, _this.chains)&&(identical(other.rule, _this.rule) || other.rule == _this.rule)&&(identical(other.rulePayload, _this.rulePayload) || other.rulePayload == _this.rulePayload)&&(identical(other.downloadSpeed, _this.downloadSpeed) || other.downloadSpeed == _this.downloadSpeed)&&(identical(other.uploadSpeed, _this.uploadSpeed) || other.uploadSpeed == _this.uploadSpeed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TrackerInfo;
  return Object.hash(runtimeType,_this.id,_this.upload,_this.download,_this.start,_this.metadata,const DeepCollectionEquality().hash(_this.chains),_this.rule,_this.rulePayload,_this.downloadSpeed,_this.uploadSpeed);
}

@override
String toString() {
  final _this = this as TrackerInfo;
  return 'TrackerInfo(id: ${_this.id}, upload: ${_this.upload}, download: ${_this.download}, start: ${_this.start}, metadata: ${_this.metadata}, chains: ${_this.chains}, rule: ${_this.rule}, rulePayload: ${_this.rulePayload}, downloadSpeed: ${_this.downloadSpeed}, uploadSpeed: ${_this.uploadSpeed})';
}


}

/// @nodoc
abstract mixin class $TrackerInfoCopyWith<$Res>  {
  factory $TrackerInfoCopyWith(TrackerInfo value, $Res Function(TrackerInfo) _then) = _$TrackerInfoCopyWithImpl;
@useResult
$Res call({
 String id, int upload, int download, DateTime start, Metadata metadata, List<String> chains, String rule, String rulePayload, int? downloadSpeed, int? uploadSpeed
});


$MetadataCopyWith<$Res> get metadata;

}
/// @nodoc
class _$TrackerInfoCopyWithImpl<$Res>
    implements $TrackerInfoCopyWith<$Res> {
  _$TrackerInfoCopyWithImpl(this._self, this._then);

  final TrackerInfo _self;
  final $Res Function(TrackerInfo) _then;

/// Create a copy of TrackerInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? upload = null,Object? download = null,Object? start = null,Object? metadata = null,Object? chains = null,Object? rule = null,Object? rulePayload = null,Object? downloadSpeed = freezed,Object? uploadSpeed = freezed,}) {
  return _then(TrackerInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Metadata,chains: null == chains ? _self.chains : chains // ignore: cast_nullable_to_non_nullable
as List<String>,rule: null == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as String,rulePayload: null == rulePayload ? _self.rulePayload : rulePayload // ignore: cast_nullable_to_non_nullable
as String,downloadSpeed: freezed == downloadSpeed ? _self.downloadSpeed : downloadSpeed // ignore: cast_nullable_to_non_nullable
as int?,uploadSpeed: freezed == uploadSpeed ? _self.uploadSpeed : uploadSpeed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of TrackerInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetadataCopyWith<$Res> get metadata {
  
  return $MetadataCopyWith<$Res>(_self.metadata, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// Adds pattern-matching-related methods to [TrackerInfo].
extension TrackerInfoPatterns on TrackerInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackerInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackerInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackerInfo value)  $default,){
final _that = this;
switch (_that) {
case _TrackerInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackerInfo value)?  $default,){
final _that = this;
switch (_that) {
case _TrackerInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int upload,  int download,  DateTime start,  Metadata metadata,  List<String> chains,  String rule,  String rulePayload,  int? downloadSpeed,  int? uploadSpeed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackerInfo() when $default != null:
return $default(_that.id,_that.upload,_that.download,_that.start,_that.metadata,_that.chains,_that.rule,_that.rulePayload,_that.downloadSpeed,_that.uploadSpeed);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int upload,  int download,  DateTime start,  Metadata metadata,  List<String> chains,  String rule,  String rulePayload,  int? downloadSpeed,  int? uploadSpeed)  $default,) {final _that = this;
switch (_that) {
case _TrackerInfo():
return $default(_that.id,_that.upload,_that.download,_that.start,_that.metadata,_that.chains,_that.rule,_that.rulePayload,_that.downloadSpeed,_that.uploadSpeed);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int upload,  int download,  DateTime start,  Metadata metadata,  List<String> chains,  String rule,  String rulePayload,  int? downloadSpeed,  int? uploadSpeed)?  $default,) {final _that = this;
switch (_that) {
case _TrackerInfo() when $default != null:
return $default(_that.id,_that.upload,_that.download,_that.start,_that.metadata,_that.chains,_that.rule,_that.rulePayload,_that.downloadSpeed,_that.uploadSpeed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrackerInfo implements TrackerInfo {
  const _TrackerInfo({required this.id, this.upload = 0, this.download = 0, required this.start, required this.metadata, required  List<String> chains, required this.rule, required this.rulePayload, this.downloadSpeed, this.uploadSpeed}): _chains = chains;
  factory _TrackerInfo.fromJson(Map<String, dynamic> json) => _$TrackerInfoFromJson(json);

@override final  String id;
@override@JsonKey() final  int upload;
@override@JsonKey() final  int download;
@override final  DateTime start;
@override final  Metadata metadata;
 final  List<String> _chains;
@override List<String> get chains {
  if (_chains is EqualUnmodifiableListView) return _chains;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chains);
}

@override final  String rule;
@override final  String rulePayload;
@override final  int? downloadSpeed;
@override final  int? uploadSpeed;

/// Create a copy of TrackerInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackerInfoCopyWith<_TrackerInfo> get copyWith => __$TrackerInfoCopyWithImpl<_TrackerInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackerInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackerInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.download, download) || other.download == download)&&(identical(other.start, start) || other.start == start)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&const DeepCollectionEquality().equals(other.chains, _chains)&&(identical(other.rule, rule) || other.rule == rule)&&(identical(other.rulePayload, rulePayload) || other.rulePayload == rulePayload)&&(identical(other.downloadSpeed, downloadSpeed) || other.downloadSpeed == downloadSpeed)&&(identical(other.uploadSpeed, uploadSpeed) || other.uploadSpeed == uploadSpeed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,upload,download,start,metadata,const DeepCollectionEquality().hash(_chains),rule,rulePayload,downloadSpeed,uploadSpeed);
}

@override
String toString() {
    return 'TrackerInfo(id: $id, upload: $upload, download: $download, start: $start, metadata: $metadata, chains: $chains, rule: $rule, rulePayload: $rulePayload, downloadSpeed: $downloadSpeed, uploadSpeed: $uploadSpeed)';
}


}

/// @nodoc
abstract mixin class _$TrackerInfoCopyWith<$Res> implements $TrackerInfoCopyWith<$Res> {
  factory _$TrackerInfoCopyWith(_TrackerInfo value, $Res Function(_TrackerInfo) _then) = __$TrackerInfoCopyWithImpl;
@override @useResult
$Res call({
 String id, int upload, int download, DateTime start, Metadata metadata, List<String> chains, String rule, String rulePayload, int? downloadSpeed, int? uploadSpeed
});


@override $MetadataCopyWith<$Res> get metadata;

}
/// @nodoc
class __$TrackerInfoCopyWithImpl<$Res>
    implements _$TrackerInfoCopyWith<$Res> {
  __$TrackerInfoCopyWithImpl(this._self, this._then);

  final _TrackerInfo _self;
  final $Res Function(_TrackerInfo) _then;

/// Create a copy of TrackerInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? upload = null,Object? download = null,Object? start = null,Object? metadata = null,Object? chains = null,Object? rule = null,Object? rulePayload = null,Object? downloadSpeed = freezed,Object? uploadSpeed = freezed,}) {
  return _then(_TrackerInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Metadata,chains: null == chains ? _self._chains : chains // ignore: cast_nullable_to_non_nullable
as List<String>,rule: null == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as String,rulePayload: null == rulePayload ? _self.rulePayload : rulePayload // ignore: cast_nullable_to_non_nullable
as String,downloadSpeed: freezed == downloadSpeed ? _self.downloadSpeed : downloadSpeed // ignore: cast_nullable_to_non_nullable
as int?,uploadSpeed: freezed == uploadSpeed ? _self.uploadSpeed : uploadSpeed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of TrackerInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetadataCopyWith<$Res> get metadata {
  
  return $MetadataCopyWith<$Res>(_self.metadata, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}

/// @nodoc
mixin _$TrackerInfosState {

 List<TrackerInfo> get trackerInfos; List<String> get keywords; String get query; bool get autoScrollToEnd;
/// Create a copy of TrackerInfosState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackerInfosStateCopyWith<TrackerInfosState> get copyWith => _$TrackerInfosStateCopyWithImpl<TrackerInfosState>(this as TrackerInfosState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TrackerInfosState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackerInfosState&&const DeepCollectionEquality().equals(other.trackerInfos, _this.trackerInfos)&&const DeepCollectionEquality().equals(other.keywords, _this.keywords)&&(identical(other.query, _this.query) || other.query == _this.query)&&(identical(other.autoScrollToEnd, _this.autoScrollToEnd) || other.autoScrollToEnd == _this.autoScrollToEnd));
}


@override
int get hashCode {
  final _this = this as TrackerInfosState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.trackerInfos),const DeepCollectionEquality().hash(_this.keywords),_this.query,_this.autoScrollToEnd);
}

@override
String toString() {
  final _this = this as TrackerInfosState;
  return 'TrackerInfosState(trackerInfos: ${_this.trackerInfos}, keywords: ${_this.keywords}, query: ${_this.query}, autoScrollToEnd: ${_this.autoScrollToEnd})';
}


}

/// @nodoc
abstract mixin class $TrackerInfosStateCopyWith<$Res>  {
  factory $TrackerInfosStateCopyWith(TrackerInfosState value, $Res Function(TrackerInfosState) _then) = _$TrackerInfosStateCopyWithImpl;
@useResult
$Res call({
 List<TrackerInfo> trackerInfos, List<String> keywords, String query, bool autoScrollToEnd
});




}
/// @nodoc
class _$TrackerInfosStateCopyWithImpl<$Res>
    implements $TrackerInfosStateCopyWith<$Res> {
  _$TrackerInfosStateCopyWithImpl(this._self, this._then);

  final TrackerInfosState _self;
  final $Res Function(TrackerInfosState) _then;

/// Create a copy of TrackerInfosState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? trackerInfos = null,Object? keywords = null,Object? query = null,Object? autoScrollToEnd = null,}) {
  return _then(TrackerInfosState(
trackerInfos: null == trackerInfos ? _self.trackerInfos : trackerInfos // ignore: cast_nullable_to_non_nullable
as List<TrackerInfo>,keywords: null == keywords ? _self.keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,autoScrollToEnd: null == autoScrollToEnd ? _self.autoScrollToEnd : autoScrollToEnd // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackerInfosState].
extension TrackerInfosStatePatterns on TrackerInfosState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackerInfosState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackerInfosState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackerInfosState value)  $default,){
final _that = this;
switch (_that) {
case _TrackerInfosState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackerInfosState value)?  $default,){
final _that = this;
switch (_that) {
case _TrackerInfosState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TrackerInfo> trackerInfos,  List<String> keywords,  String query,  bool autoScrollToEnd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackerInfosState() when $default != null:
return $default(_that.trackerInfos,_that.keywords,_that.query,_that.autoScrollToEnd);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TrackerInfo> trackerInfos,  List<String> keywords,  String query,  bool autoScrollToEnd)  $default,) {final _that = this;
switch (_that) {
case _TrackerInfosState():
return $default(_that.trackerInfos,_that.keywords,_that.query,_that.autoScrollToEnd);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TrackerInfo> trackerInfos,  List<String> keywords,  String query,  bool autoScrollToEnd)?  $default,) {final _that = this;
switch (_that) {
case _TrackerInfosState() when $default != null:
return $default(_that.trackerInfos,_that.keywords,_that.query,_that.autoScrollToEnd);case _:
  return null;

}
}

}

/// @nodoc


class _TrackerInfosState implements TrackerInfosState {
  const _TrackerInfosState({ List<TrackerInfo> trackerInfos = const [],  List<String> keywords = const [], this.query = '', this.autoScrollToEnd = true}): _trackerInfos = trackerInfos,_keywords = keywords;
  

 final  List<TrackerInfo> _trackerInfos;
@override@JsonKey() List<TrackerInfo> get trackerInfos {
  if (_trackerInfos is EqualUnmodifiableListView) return _trackerInfos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trackerInfos);
}

 final  List<String> _keywords;
@override@JsonKey() List<String> get keywords {
  if (_keywords is EqualUnmodifiableListView) return _keywords;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_keywords);
}

@override@JsonKey() final  String query;
@override@JsonKey() final  bool autoScrollToEnd;

/// Create a copy of TrackerInfosState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackerInfosStateCopyWith<_TrackerInfosState> get copyWith => __$TrackerInfosStateCopyWithImpl<_TrackerInfosState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackerInfosState&&const DeepCollectionEquality().equals(other.trackerInfos, _trackerInfos)&&const DeepCollectionEquality().equals(other.keywords, _keywords)&&(identical(other.query, query) || other.query == query)&&(identical(other.autoScrollToEnd, autoScrollToEnd) || other.autoScrollToEnd == autoScrollToEnd));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_trackerInfos),const DeepCollectionEquality().hash(_keywords),query,autoScrollToEnd);
}

@override
String toString() {
    return 'TrackerInfosState(trackerInfos: $trackerInfos, keywords: $keywords, query: $query, autoScrollToEnd: $autoScrollToEnd)';
}


}

/// @nodoc
abstract mixin class _$TrackerInfosStateCopyWith<$Res> implements $TrackerInfosStateCopyWith<$Res> {
  factory _$TrackerInfosStateCopyWith(_TrackerInfosState value, $Res Function(_TrackerInfosState) _then) = __$TrackerInfosStateCopyWithImpl;
@override @useResult
$Res call({
 List<TrackerInfo> trackerInfos, List<String> keywords, String query, bool autoScrollToEnd
});




}
/// @nodoc
class __$TrackerInfosStateCopyWithImpl<$Res>
    implements _$TrackerInfosStateCopyWith<$Res> {
  __$TrackerInfosStateCopyWithImpl(this._self, this._then);

  final _TrackerInfosState _self;
  final $Res Function(_TrackerInfosState) _then;

/// Create a copy of TrackerInfosState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? trackerInfos = null,Object? keywords = null,Object? query = null,Object? autoScrollToEnd = null,}) {
  return _then(_TrackerInfosState(
trackerInfos: null == trackerInfos ? _self._trackerInfos : trackerInfos // ignore: cast_nullable_to_non_nullable
as List<TrackerInfo>,keywords: null == keywords ? _self._keywords : keywords // ignore: cast_nullable_to_non_nullable
as List<String>,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,autoScrollToEnd: null == autoScrollToEnd ? _self.autoScrollToEnd : autoScrollToEnd // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
