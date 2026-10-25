// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../custom_proxy.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CustomProxy {

@JsonKey(fromJson: Snowflake.buildId) int get id; Map<String, dynamic> get definition; String? get order;/// Options the form lists with no value yet, which [definition] cannot
/// hold since the core reads every key in it.
 Set<ProxyField> get emptyOptions;
/// Create a copy of CustomProxy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomProxyCopyWith<CustomProxy> get copyWith => _$CustomProxyCopyWithImpl<CustomProxy>(this as CustomProxy, _$identity);

  /// Serializes this CustomProxy to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CustomProxy;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomProxy&&(identical(other.id, _this.id) || other.id == _this.id)&&const DeepCollectionEquality().equals(other.definition, _this.definition)&&(identical(other.order, _this.order) || other.order == _this.order)&&const DeepCollectionEquality().equals(other.emptyOptions, _this.emptyOptions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CustomProxy;
  return Object.hash(runtimeType,_this.id,const DeepCollectionEquality().hash(_this.definition),_this.order,const DeepCollectionEquality().hash(_this.emptyOptions));
}

@override
String toString() {
  final _this = this as CustomProxy;
  return 'CustomProxy(id: ${_this.id}, definition: ${_this.definition}, order: ${_this.order}, emptyOptions: ${_this.emptyOptions})';
}


}

/// @nodoc
abstract mixin class $CustomProxyCopyWith<$Res>  {
  factory $CustomProxyCopyWith(CustomProxy value, $Res Function(CustomProxy) _then) = _$CustomProxyCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: Snowflake.buildId) int id, Map<String, dynamic> definition, String? order, Set<ProxyField> emptyOptions
});




}
/// @nodoc
class _$CustomProxyCopyWithImpl<$Res>
    implements $CustomProxyCopyWith<$Res> {
  _$CustomProxyCopyWithImpl(this._self, this._then);

  final CustomProxy _self;
  final $Res Function(CustomProxy) _then;

/// Create a copy of CustomProxy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? definition = null,Object? order = freezed,Object? emptyOptions = null,}) {
  return _then(CustomProxy(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,definition: null == definition ? _self.definition : definition // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,order: freezed == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as String?,emptyOptions: null == emptyOptions ? _self.emptyOptions : emptyOptions // ignore: cast_nullable_to_non_nullable
as Set<ProxyField>,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomProxy].
extension CustomProxyPatterns on CustomProxy {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomProxy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomProxy() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomProxy value)  $default,){
final _that = this;
switch (_that) {
case _CustomProxy():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomProxy value)?  $default,){
final _that = this;
switch (_that) {
case _CustomProxy() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: Snowflake.buildId)  int id,  Map<String, dynamic> definition,  String? order,  Set<ProxyField> emptyOptions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomProxy() when $default != null:
return $default(_that.id,_that.definition,_that.order,_that.emptyOptions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: Snowflake.buildId)  int id,  Map<String, dynamic> definition,  String? order,  Set<ProxyField> emptyOptions)  $default,) {final _that = this;
switch (_that) {
case _CustomProxy():
return $default(_that.id,_that.definition,_that.order,_that.emptyOptions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: Snowflake.buildId)  int id,  Map<String, dynamic> definition,  String? order,  Set<ProxyField> emptyOptions)?  $default,) {final _that = this;
switch (_that) {
case _CustomProxy() when $default != null:
return $default(_that.id,_that.definition,_that.order,_that.emptyOptions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomProxy implements CustomProxy {
  const _CustomProxy({@JsonKey(fromJson: Snowflake.buildId) required this.id,  Map<String, dynamic> definition = const {}, this.order,  Set<ProxyField> emptyOptions = const {}}): _definition = definition,_emptyOptions = emptyOptions;
  factory _CustomProxy.fromJson(Map<String, dynamic> json) => _$CustomProxyFromJson(json);

@override@JsonKey(fromJson: Snowflake.buildId) final  int id;
 final  Map<String, dynamic> _definition;
@override@JsonKey() Map<String, dynamic> get definition {
  if (_definition is EqualUnmodifiableMapView) return _definition;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_definition);
}

@override final  String? order;
/// Options the form lists with no value yet, which [definition] cannot
/// hold since the core reads every key in it.
 final  Set<ProxyField> _emptyOptions;
/// Options the form lists with no value yet, which [definition] cannot
/// hold since the core reads every key in it.
@override@JsonKey() Set<ProxyField> get emptyOptions {
  if (_emptyOptions is EqualUnmodifiableSetView) return _emptyOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_emptyOptions);
}


/// Create a copy of CustomProxy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomProxyCopyWith<_CustomProxy> get copyWith => __$CustomProxyCopyWithImpl<_CustomProxy>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomProxyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomProxy&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.definition, _definition)&&(identical(other.order, order) || other.order == order)&&const DeepCollectionEquality().equals(other.emptyOptions, _emptyOptions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_definition),order,const DeepCollectionEquality().hash(_emptyOptions));
}

@override
String toString() {
    return 'CustomProxy(id: $id, definition: $definition, order: $order, emptyOptions: $emptyOptions)';
}


}

/// @nodoc
abstract mixin class _$CustomProxyCopyWith<$Res> implements $CustomProxyCopyWith<$Res> {
  factory _$CustomProxyCopyWith(_CustomProxy value, $Res Function(_CustomProxy) _then) = __$CustomProxyCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: Snowflake.buildId) int id, Map<String, dynamic> definition, String? order, Set<ProxyField> emptyOptions
});




}
/// @nodoc
class __$CustomProxyCopyWithImpl<$Res>
    implements _$CustomProxyCopyWith<$Res> {
  __$CustomProxyCopyWithImpl(this._self, this._then);

  final _CustomProxy _self;
  final $Res Function(_CustomProxy) _then;

/// Create a copy of CustomProxy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? definition = null,Object? order = freezed,Object? emptyOptions = null,}) {
  return _then(_CustomProxy(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,definition: null == definition ? _self._definition : definition // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,order: freezed == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as String?,emptyOptions: null == emptyOptions ? _self._emptyOptions : emptyOptions // ignore: cast_nullable_to_non_nullable
as Set<ProxyField>,
  ));
}


}

// dart format on
