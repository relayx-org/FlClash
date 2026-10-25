// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../traffic_show.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrafficShow {

 String get value; String get unit;
/// Create a copy of TrafficShow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrafficShowCopyWith<TrafficShow> get copyWith => _$TrafficShowCopyWithImpl<TrafficShow>(this as TrafficShow, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TrafficShow;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrafficShow&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.unit, _this.unit) || other.unit == _this.unit));
}


@override
int get hashCode {
  final _this = this as TrafficShow;
  return Object.hash(runtimeType,_this.value,_this.unit);
}

@override
String toString() {
  final _this = this as TrafficShow;
  return 'TrafficShow(value: ${_this.value}, unit: ${_this.unit})';
}


}

/// @nodoc
abstract mixin class $TrafficShowCopyWith<$Res>  {
  factory $TrafficShowCopyWith(TrafficShow value, $Res Function(TrafficShow) _then) = _$TrafficShowCopyWithImpl;
@useResult
$Res call({
 String value, String unit
});




}
/// @nodoc
class _$TrafficShowCopyWithImpl<$Res>
    implements $TrafficShowCopyWith<$Res> {
  _$TrafficShowCopyWithImpl(this._self, this._then);

  final TrafficShow _self;
  final $Res Function(TrafficShow) _then;

/// Create a copy of TrafficShow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? unit = null,}) {
  return _then(TrafficShow(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TrafficShow].
extension TrafficShowPatterns on TrafficShow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrafficShow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrafficShow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrafficShow value)  $default,){
final _that = this;
switch (_that) {
case _TrafficShow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrafficShow value)?  $default,){
final _that = this;
switch (_that) {
case _TrafficShow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value,  String unit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrafficShow() when $default != null:
return $default(_that.value,_that.unit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value,  String unit)  $default,) {final _that = this;
switch (_that) {
case _TrafficShow():
return $default(_that.value,_that.unit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value,  String unit)?  $default,) {final _that = this;
switch (_that) {
case _TrafficShow() when $default != null:
return $default(_that.value,_that.unit);case _:
  return null;

}
}

}

/// @nodoc


class _TrafficShow implements TrafficShow {
  const _TrafficShow({required this.value, required this.unit});
  

@override final  String value;
@override final  String unit;

/// Create a copy of TrafficShow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrafficShowCopyWith<_TrafficShow> get copyWith => __$TrafficShowCopyWithImpl<_TrafficShow>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrafficShow&&(identical(other.value, value) || other.value == value)&&(identical(other.unit, unit) || other.unit == unit));
}


@override
int get hashCode {
    return Object.hash(runtimeType,value,unit);
}

@override
String toString() {
    return 'TrafficShow(value: $value, unit: $unit)';
}


}

/// @nodoc
abstract mixin class _$TrafficShowCopyWith<$Res> implements $TrafficShowCopyWith<$Res> {
  factory _$TrafficShowCopyWith(_TrafficShow value, $Res Function(_TrafficShow) _then) = __$TrafficShowCopyWithImpl;
@override @useResult
$Res call({
 String value, String unit
});




}
/// @nodoc
class __$TrafficShowCopyWithImpl<$Res>
    implements _$TrafficShowCopyWith<$Res> {
  __$TrafficShowCopyWithImpl(this._self, this._then);

  final _TrafficShow _self;
  final $Res Function(_TrafficShow) _then;

/// Create a copy of TrafficShow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? unit = null,}) {
  return _then(_TrafficShow(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
