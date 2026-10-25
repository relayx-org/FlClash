// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../resource_bindings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IpingResourceBindings {

 Set<String> get proxies; Set<String> get providers; Set<String> get filters; Set<String> get rules; String? get script;
/// Create a copy of IpingResourceBindings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IpingResourceBindingsCopyWith<IpingResourceBindings> get copyWith => _$IpingResourceBindingsCopyWithImpl<IpingResourceBindings>(this as IpingResourceBindings, _$identity);

  /// Serializes this IpingResourceBindings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as IpingResourceBindings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IpingResourceBindings&&const DeepCollectionEquality().equals(other.proxies, _this.proxies)&&const DeepCollectionEquality().equals(other.providers, _this.providers)&&const DeepCollectionEquality().equals(other.filters, _this.filters)&&const DeepCollectionEquality().equals(other.rules, _this.rules)&&(identical(other.script, _this.script) || other.script == _this.script));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as IpingResourceBindings;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.proxies),const DeepCollectionEquality().hash(_this.providers),const DeepCollectionEquality().hash(_this.filters),const DeepCollectionEquality().hash(_this.rules),_this.script);
}

@override
String toString() {
  final _this = this as IpingResourceBindings;
  return 'IpingResourceBindings(proxies: ${_this.proxies}, providers: ${_this.providers}, filters: ${_this.filters}, rules: ${_this.rules}, script: ${_this.script})';
}


}

/// @nodoc
abstract mixin class $IpingResourceBindingsCopyWith<$Res>  {
  factory $IpingResourceBindingsCopyWith(IpingResourceBindings value, $Res Function(IpingResourceBindings) _then) = _$IpingResourceBindingsCopyWithImpl;
@useResult
$Res call({
 Set<String> proxies, Set<String> providers, Set<String> filters, Set<String> rules, String? script
});




}
/// @nodoc
class _$IpingResourceBindingsCopyWithImpl<$Res>
    implements $IpingResourceBindingsCopyWith<$Res> {
  _$IpingResourceBindingsCopyWithImpl(this._self, this._then);

  final IpingResourceBindings _self;
  final $Res Function(IpingResourceBindings) _then;

/// Create a copy of IpingResourceBindings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? proxies = null,Object? providers = null,Object? filters = null,Object? rules = null,Object? script = freezed,}) {
  return _then(IpingResourceBindings(
proxies: null == proxies ? _self.proxies : proxies // ignore: cast_nullable_to_non_nullable
as Set<String>,providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as Set<String>,filters: null == filters ? _self.filters : filters // ignore: cast_nullable_to_non_nullable
as Set<String>,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as Set<String>,script: freezed == script ? _self.script : script // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [IpingResourceBindings].
extension IpingResourceBindingsPatterns on IpingResourceBindings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IpingResourceBindings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IpingResourceBindings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IpingResourceBindings value)  $default,){
final _that = this;
switch (_that) {
case _IpingResourceBindings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IpingResourceBindings value)?  $default,){
final _that = this;
switch (_that) {
case _IpingResourceBindings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<String> proxies,  Set<String> providers,  Set<String> filters,  Set<String> rules,  String? script)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IpingResourceBindings() when $default != null:
return $default(_that.proxies,_that.providers,_that.filters,_that.rules,_that.script);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<String> proxies,  Set<String> providers,  Set<String> filters,  Set<String> rules,  String? script)  $default,) {final _that = this;
switch (_that) {
case _IpingResourceBindings():
return $default(_that.proxies,_that.providers,_that.filters,_that.rules,_that.script);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<String> proxies,  Set<String> providers,  Set<String> filters,  Set<String> rules,  String? script)?  $default,) {final _that = this;
switch (_that) {
case _IpingResourceBindings() when $default != null:
return $default(_that.proxies,_that.providers,_that.filters,_that.rules,_that.script);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IpingResourceBindings extends IpingResourceBindings {
  const _IpingResourceBindings({ Set<String> proxies = const {},  Set<String> providers = const {},  Set<String> filters = const {},  Set<String> rules = const {}, this.script}): _proxies = proxies,_providers = providers,_filters = filters,_rules = rules,super._();
  factory _IpingResourceBindings.fromJson(Map<String, dynamic> json) => _$IpingResourceBindingsFromJson(json);

 final  Set<String> _proxies;
@override@JsonKey() Set<String> get proxies {
  if (_proxies is EqualUnmodifiableSetView) return _proxies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_proxies);
}

 final  Set<String> _providers;
@override@JsonKey() Set<String> get providers {
  if (_providers is EqualUnmodifiableSetView) return _providers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_providers);
}

 final  Set<String> _filters;
@override@JsonKey() Set<String> get filters {
  if (_filters is EqualUnmodifiableSetView) return _filters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_filters);
}

 final  Set<String> _rules;
@override@JsonKey() Set<String> get rules {
  if (_rules is EqualUnmodifiableSetView) return _rules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_rules);
}

@override final  String? script;

/// Create a copy of IpingResourceBindings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IpingResourceBindingsCopyWith<_IpingResourceBindings> get copyWith => __$IpingResourceBindingsCopyWithImpl<_IpingResourceBindings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IpingResourceBindingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IpingResourceBindings&&const DeepCollectionEquality().equals(other.proxies, _proxies)&&const DeepCollectionEquality().equals(other.providers, _providers)&&const DeepCollectionEquality().equals(other.filters, _filters)&&const DeepCollectionEquality().equals(other.rules, _rules)&&(identical(other.script, script) || other.script == script));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_proxies),const DeepCollectionEquality().hash(_providers),const DeepCollectionEquality().hash(_filters),const DeepCollectionEquality().hash(_rules),script);
}

@override
String toString() {
    return 'IpingResourceBindings(proxies: $proxies, providers: $providers, filters: $filters, rules: $rules, script: $script)';
}


}

/// @nodoc
abstract mixin class _$IpingResourceBindingsCopyWith<$Res> implements $IpingResourceBindingsCopyWith<$Res> {
  factory _$IpingResourceBindingsCopyWith(_IpingResourceBindings value, $Res Function(_IpingResourceBindings) _then) = __$IpingResourceBindingsCopyWithImpl;
@override @useResult
$Res call({
 Set<String> proxies, Set<String> providers, Set<String> filters, Set<String> rules, String? script
});




}
/// @nodoc
class __$IpingResourceBindingsCopyWithImpl<$Res>
    implements _$IpingResourceBindingsCopyWith<$Res> {
  __$IpingResourceBindingsCopyWithImpl(this._self, this._then);

  final _IpingResourceBindings _self;
  final $Res Function(_IpingResourceBindings) _then;

/// Create a copy of IpingResourceBindings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? proxies = null,Object? providers = null,Object? filters = null,Object? rules = null,Object? script = freezed,}) {
  return _then(_IpingResourceBindings(
proxies: null == proxies ? _self._proxies : proxies // ignore: cast_nullable_to_non_nullable
as Set<String>,providers: null == providers ? _self._providers : providers // ignore: cast_nullable_to_non_nullable
as Set<String>,filters: null == filters ? _self._filters : filters // ignore: cast_nullable_to_non_nullable
as Set<String>,rules: null == rules ? _self._rules : rules // ignore: cast_nullable_to_non_nullable
as Set<String>,script: freezed == script ? _self.script : script // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
