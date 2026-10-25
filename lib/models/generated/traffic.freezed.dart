// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../traffic.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Traffic {

 num get up; num get down;
/// Create a copy of Traffic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrafficCopyWith<Traffic> get copyWith => _$TrafficCopyWithImpl<Traffic>(this as Traffic, _$identity);

  /// Serializes this Traffic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Traffic;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Traffic&&(identical(other.up, _this.up) || other.up == _this.up)&&(identical(other.down, _this.down) || other.down == _this.down));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Traffic;
  return Object.hash(runtimeType,_this.up,_this.down);
}

@override
String toString() {
  final _this = this as Traffic;
  return 'Traffic(up: ${_this.up}, down: ${_this.down})';
}


}

/// @nodoc
abstract mixin class $TrafficCopyWith<$Res>  {
  factory $TrafficCopyWith(Traffic value, $Res Function(Traffic) _then) = _$TrafficCopyWithImpl;
@useResult
$Res call({
 num up, num down
});




}
/// @nodoc
class _$TrafficCopyWithImpl<$Res>
    implements $TrafficCopyWith<$Res> {
  _$TrafficCopyWithImpl(this._self, this._then);

  final Traffic _self;
  final $Res Function(Traffic) _then;

/// Create a copy of Traffic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? up = null,Object? down = null,}) {
  return _then(Traffic(
up: null == up ? _self.up : up // ignore: cast_nullable_to_non_nullable
as num,down: null == down ? _self.down : down // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [Traffic].
extension TrafficPatterns on Traffic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Traffic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Traffic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Traffic value)  $default,){
final _that = this;
switch (_that) {
case _Traffic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Traffic value)?  $default,){
final _that = this;
switch (_that) {
case _Traffic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( num up,  num down)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Traffic() when $default != null:
return $default(_that.up,_that.down);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( num up,  num down)  $default,) {final _that = this;
switch (_that) {
case _Traffic():
return $default(_that.up,_that.down);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( num up,  num down)?  $default,) {final _that = this;
switch (_that) {
case _Traffic() when $default != null:
return $default(_that.up,_that.down);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Traffic implements Traffic {
  const _Traffic({this.up = 0, this.down = 0});
  factory _Traffic.fromJson(Map<String, dynamic> json) => _$TrafficFromJson(json);

@override@JsonKey() final  num up;
@override@JsonKey() final  num down;

/// Create a copy of Traffic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrafficCopyWith<_Traffic> get copyWith => __$TrafficCopyWithImpl<_Traffic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrafficToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Traffic&&(identical(other.up, up) || other.up == up)&&(identical(other.down, down) || other.down == down));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,up,down);
}

@override
String toString() {
    return 'Traffic(up: $up, down: $down)';
}


}

/// @nodoc
abstract mixin class _$TrafficCopyWith<$Res> implements $TrafficCopyWith<$Res> {
  factory _$TrafficCopyWith(_Traffic value, $Res Function(_Traffic) _then) = __$TrafficCopyWithImpl;
@override @useResult
$Res call({
 num up, num down
});




}
/// @nodoc
class __$TrafficCopyWithImpl<$Res>
    implements _$TrafficCopyWith<$Res> {
  __$TrafficCopyWithImpl(this._self, this._then);

  final _Traffic _self;
  final $Res Function(_Traffic) _then;

/// Create a copy of Traffic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? up = null,Object? down = null,}) {
  return _then(_Traffic(
up: null == up ? _self.up : up // ignore: cast_nullable_to_non_nullable
as num,down: null == down ? _self.down : down // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}

// dart format on
