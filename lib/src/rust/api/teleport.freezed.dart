// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'teleport.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InboundPairingEvent {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InboundPairingEvent&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'InboundPairingEvent(field0: $field0)';
}


}

/// @nodoc
class $InboundPairingEventCopyWith<$Res>  {
$InboundPairingEventCopyWith(InboundPairingEvent _, $Res Function(InboundPairingEvent) __);
}


/// Adds pattern-matching-related methods to [InboundPairingEvent].
extension InboundPairingEventPatterns on InboundPairingEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( InboundPairingEvent_InboundPair value)?  inboundPair,TResult Function( InboundPairingEvent_CompletedPair value)?  completedPair,TResult Function( InboundPairingEvent_FailedPair value)?  failedPair,required TResult orElse(),}){
final _that = this;
switch (_that) {
case InboundPairingEvent_InboundPair() when inboundPair != null:
return inboundPair(_that);case InboundPairingEvent_CompletedPair() when completedPair != null:
return completedPair(_that);case InboundPairingEvent_FailedPair() when failedPair != null:
return failedPair(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( InboundPairingEvent_InboundPair value)  inboundPair,required TResult Function( InboundPairingEvent_CompletedPair value)  completedPair,required TResult Function( InboundPairingEvent_FailedPair value)  failedPair,}){
final _that = this;
switch (_that) {
case InboundPairingEvent_InboundPair():
return inboundPair(_that);case InboundPairingEvent_CompletedPair():
return completedPair(_that);case InboundPairingEvent_FailedPair():
return failedPair(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( InboundPairingEvent_InboundPair value)?  inboundPair,TResult? Function( InboundPairingEvent_CompletedPair value)?  completedPair,TResult? Function( InboundPairingEvent_FailedPair value)?  failedPair,}){
final _that = this;
switch (_that) {
case InboundPairingEvent_InboundPair() when inboundPair != null:
return inboundPair(_that);case InboundPairingEvent_CompletedPair() when completedPair != null:
return completedPair(_that);case InboundPairingEvent_FailedPair() when failedPair != null:
return failedPair(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( InboundPair field0)?  inboundPair,TResult Function( CompletedPair field0)?  completedPair,TResult Function( FailedPair field0)?  failedPair,required TResult orElse(),}) {final _that = this;
switch (_that) {
case InboundPairingEvent_InboundPair() when inboundPair != null:
return inboundPair(_that.field0);case InboundPairingEvent_CompletedPair() when completedPair != null:
return completedPair(_that.field0);case InboundPairingEvent_FailedPair() when failedPair != null:
return failedPair(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( InboundPair field0)  inboundPair,required TResult Function( CompletedPair field0)  completedPair,required TResult Function( FailedPair field0)  failedPair,}) {final _that = this;
switch (_that) {
case InboundPairingEvent_InboundPair():
return inboundPair(_that.field0);case InboundPairingEvent_CompletedPair():
return completedPair(_that.field0);case InboundPairingEvent_FailedPair():
return failedPair(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( InboundPair field0)?  inboundPair,TResult? Function( CompletedPair field0)?  completedPair,TResult? Function( FailedPair field0)?  failedPair,}) {final _that = this;
switch (_that) {
case InboundPairingEvent_InboundPair() when inboundPair != null:
return inboundPair(_that.field0);case InboundPairingEvent_CompletedPair() when completedPair != null:
return completedPair(_that.field0);case InboundPairingEvent_FailedPair() when failedPair != null:
return failedPair(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class InboundPairingEvent_InboundPair extends InboundPairingEvent {
  const InboundPairingEvent_InboundPair(this.field0): super._();
  

@override final  InboundPair field0;

/// Create a copy of InboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InboundPairingEvent_InboundPairCopyWith<InboundPairingEvent_InboundPair> get copyWith => _$InboundPairingEvent_InboundPairCopyWithImpl<InboundPairingEvent_InboundPair>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InboundPairingEvent_InboundPair&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'InboundPairingEvent.inboundPair(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $InboundPairingEvent_InboundPairCopyWith<$Res> implements $InboundPairingEventCopyWith<$Res> {
  factory $InboundPairingEvent_InboundPairCopyWith(InboundPairingEvent_InboundPair value, $Res Function(InboundPairingEvent_InboundPair) _then) = _$InboundPairingEvent_InboundPairCopyWithImpl;
@useResult
$Res call({
 InboundPair field0
});




}
/// @nodoc
class _$InboundPairingEvent_InboundPairCopyWithImpl<$Res>
    implements $InboundPairingEvent_InboundPairCopyWith<$Res> {
  _$InboundPairingEvent_InboundPairCopyWithImpl(this._self, this._then);

  final InboundPairingEvent_InboundPair _self;
  final $Res Function(InboundPairingEvent_InboundPair) _then;

/// Create a copy of InboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(InboundPairingEvent_InboundPair(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as InboundPair,
  ));
}


}

/// @nodoc


class InboundPairingEvent_CompletedPair extends InboundPairingEvent {
  const InboundPairingEvent_CompletedPair(this.field0): super._();
  

@override final  CompletedPair field0;

/// Create a copy of InboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InboundPairingEvent_CompletedPairCopyWith<InboundPairingEvent_CompletedPair> get copyWith => _$InboundPairingEvent_CompletedPairCopyWithImpl<InboundPairingEvent_CompletedPair>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InboundPairingEvent_CompletedPair&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'InboundPairingEvent.completedPair(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $InboundPairingEvent_CompletedPairCopyWith<$Res> implements $InboundPairingEventCopyWith<$Res> {
  factory $InboundPairingEvent_CompletedPairCopyWith(InboundPairingEvent_CompletedPair value, $Res Function(InboundPairingEvent_CompletedPair) _then) = _$InboundPairingEvent_CompletedPairCopyWithImpl;
@useResult
$Res call({
 CompletedPair field0
});




}
/// @nodoc
class _$InboundPairingEvent_CompletedPairCopyWithImpl<$Res>
    implements $InboundPairingEvent_CompletedPairCopyWith<$Res> {
  _$InboundPairingEvent_CompletedPairCopyWithImpl(this._self, this._then);

  final InboundPairingEvent_CompletedPair _self;
  final $Res Function(InboundPairingEvent_CompletedPair) _then;

/// Create a copy of InboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(InboundPairingEvent_CompletedPair(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as CompletedPair,
  ));
}


}

/// @nodoc


class InboundPairingEvent_FailedPair extends InboundPairingEvent {
  const InboundPairingEvent_FailedPair(this.field0): super._();
  

@override final  FailedPair field0;

/// Create a copy of InboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InboundPairingEvent_FailedPairCopyWith<InboundPairingEvent_FailedPair> get copyWith => _$InboundPairingEvent_FailedPairCopyWithImpl<InboundPairingEvent_FailedPair>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InboundPairingEvent_FailedPair&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'InboundPairingEvent.failedPair(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $InboundPairingEvent_FailedPairCopyWith<$Res> implements $InboundPairingEventCopyWith<$Res> {
  factory $InboundPairingEvent_FailedPairCopyWith(InboundPairingEvent_FailedPair value, $Res Function(InboundPairingEvent_FailedPair) _then) = _$InboundPairingEvent_FailedPairCopyWithImpl;
@useResult
$Res call({
 FailedPair field0
});




}
/// @nodoc
class _$InboundPairingEvent_FailedPairCopyWithImpl<$Res>
    implements $InboundPairingEvent_FailedPairCopyWith<$Res> {
  _$InboundPairingEvent_FailedPairCopyWithImpl(this._self, this._then);

  final InboundPairingEvent_FailedPair _self;
  final $Res Function(InboundPairingEvent_FailedPair) _then;

/// Create a copy of InboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(InboundPairingEvent_FailedPair(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as FailedPair,
  ));
}


}

/// @nodoc
mixin _$OutboundPairingEvent {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutboundPairingEvent&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'OutboundPairingEvent(field0: $field0)';
}


}

/// @nodoc
class $OutboundPairingEventCopyWith<$Res>  {
$OutboundPairingEventCopyWith(OutboundPairingEvent _, $Res Function(OutboundPairingEvent) __);
}


/// Adds pattern-matching-related methods to [OutboundPairingEvent].
extension OutboundPairingEventPatterns on OutboundPairingEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( OutboundPairingEvent_Created value)?  created,TResult Function( OutboundPairingEvent_CompletedPair value)?  completedPair,TResult Function( OutboundPairingEvent_FailedPair value)?  failedPair,required TResult orElse(),}){
final _that = this;
switch (_that) {
case OutboundPairingEvent_Created() when created != null:
return created(_that);case OutboundPairingEvent_CompletedPair() when completedPair != null:
return completedPair(_that);case OutboundPairingEvent_FailedPair() when failedPair != null:
return failedPair(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( OutboundPairingEvent_Created value)  created,required TResult Function( OutboundPairingEvent_CompletedPair value)  completedPair,required TResult Function( OutboundPairingEvent_FailedPair value)  failedPair,}){
final _that = this;
switch (_that) {
case OutboundPairingEvent_Created():
return created(_that);case OutboundPairingEvent_CompletedPair():
return completedPair(_that);case OutboundPairingEvent_FailedPair():
return failedPair(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( OutboundPairingEvent_Created value)?  created,TResult? Function( OutboundPairingEvent_CompletedPair value)?  completedPair,TResult? Function( OutboundPairingEvent_FailedPair value)?  failedPair,}){
final _that = this;
switch (_that) {
case OutboundPairingEvent_Created() when created != null:
return created(_that);case OutboundPairingEvent_CompletedPair() when completedPair != null:
return completedPair(_that);case OutboundPairingEvent_FailedPair() when failedPair != null:
return failedPair(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( U8Array6 field0)?  created,TResult Function( CompletedPair field0)?  completedPair,TResult Function( FailedPair field0)?  failedPair,required TResult orElse(),}) {final _that = this;
switch (_that) {
case OutboundPairingEvent_Created() when created != null:
return created(_that.field0);case OutboundPairingEvent_CompletedPair() when completedPair != null:
return completedPair(_that.field0);case OutboundPairingEvent_FailedPair() when failedPair != null:
return failedPair(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( U8Array6 field0)  created,required TResult Function( CompletedPair field0)  completedPair,required TResult Function( FailedPair field0)  failedPair,}) {final _that = this;
switch (_that) {
case OutboundPairingEvent_Created():
return created(_that.field0);case OutboundPairingEvent_CompletedPair():
return completedPair(_that.field0);case OutboundPairingEvent_FailedPair():
return failedPair(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( U8Array6 field0)?  created,TResult? Function( CompletedPair field0)?  completedPair,TResult? Function( FailedPair field0)?  failedPair,}) {final _that = this;
switch (_that) {
case OutboundPairingEvent_Created() when created != null:
return created(_that.field0);case OutboundPairingEvent_CompletedPair() when completedPair != null:
return completedPair(_that.field0);case OutboundPairingEvent_FailedPair() when failedPair != null:
return failedPair(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class OutboundPairingEvent_Created extends OutboundPairingEvent {
  const OutboundPairingEvent_Created(this.field0): super._();
  

@override final  U8Array6 field0;

/// Create a copy of OutboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OutboundPairingEvent_CreatedCopyWith<OutboundPairingEvent_Created> get copyWith => _$OutboundPairingEvent_CreatedCopyWithImpl<OutboundPairingEvent_Created>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutboundPairingEvent_Created&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'OutboundPairingEvent.created(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $OutboundPairingEvent_CreatedCopyWith<$Res> implements $OutboundPairingEventCopyWith<$Res> {
  factory $OutboundPairingEvent_CreatedCopyWith(OutboundPairingEvent_Created value, $Res Function(OutboundPairingEvent_Created) _then) = _$OutboundPairingEvent_CreatedCopyWithImpl;
@useResult
$Res call({
 U8Array6 field0
});




}
/// @nodoc
class _$OutboundPairingEvent_CreatedCopyWithImpl<$Res>
    implements $OutboundPairingEvent_CreatedCopyWith<$Res> {
  _$OutboundPairingEvent_CreatedCopyWithImpl(this._self, this._then);

  final OutboundPairingEvent_Created _self;
  final $Res Function(OutboundPairingEvent_Created) _then;

/// Create a copy of OutboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(OutboundPairingEvent_Created(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as U8Array6,
  ));
}


}

/// @nodoc


class OutboundPairingEvent_CompletedPair extends OutboundPairingEvent {
  const OutboundPairingEvent_CompletedPair(this.field0): super._();
  

@override final  CompletedPair field0;

/// Create a copy of OutboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OutboundPairingEvent_CompletedPairCopyWith<OutboundPairingEvent_CompletedPair> get copyWith => _$OutboundPairingEvent_CompletedPairCopyWithImpl<OutboundPairingEvent_CompletedPair>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutboundPairingEvent_CompletedPair&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'OutboundPairingEvent.completedPair(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $OutboundPairingEvent_CompletedPairCopyWith<$Res> implements $OutboundPairingEventCopyWith<$Res> {
  factory $OutboundPairingEvent_CompletedPairCopyWith(OutboundPairingEvent_CompletedPair value, $Res Function(OutboundPairingEvent_CompletedPair) _then) = _$OutboundPairingEvent_CompletedPairCopyWithImpl;
@useResult
$Res call({
 CompletedPair field0
});




}
/// @nodoc
class _$OutboundPairingEvent_CompletedPairCopyWithImpl<$Res>
    implements $OutboundPairingEvent_CompletedPairCopyWith<$Res> {
  _$OutboundPairingEvent_CompletedPairCopyWithImpl(this._self, this._then);

  final OutboundPairingEvent_CompletedPair _self;
  final $Res Function(OutboundPairingEvent_CompletedPair) _then;

/// Create a copy of OutboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(OutboundPairingEvent_CompletedPair(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as CompletedPair,
  ));
}


}

/// @nodoc


class OutboundPairingEvent_FailedPair extends OutboundPairingEvent {
  const OutboundPairingEvent_FailedPair(this.field0): super._();
  

@override final  FailedPair field0;

/// Create a copy of OutboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OutboundPairingEvent_FailedPairCopyWith<OutboundPairingEvent_FailedPair> get copyWith => _$OutboundPairingEvent_FailedPairCopyWithImpl<OutboundPairingEvent_FailedPair>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutboundPairingEvent_FailedPair&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'OutboundPairingEvent.failedPair(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $OutboundPairingEvent_FailedPairCopyWith<$Res> implements $OutboundPairingEventCopyWith<$Res> {
  factory $OutboundPairingEvent_FailedPairCopyWith(OutboundPairingEvent_FailedPair value, $Res Function(OutboundPairingEvent_FailedPair) _then) = _$OutboundPairingEvent_FailedPairCopyWithImpl;
@useResult
$Res call({
 FailedPair field0
});




}
/// @nodoc
class _$OutboundPairingEvent_FailedPairCopyWithImpl<$Res>
    implements $OutboundPairingEvent_FailedPairCopyWith<$Res> {
  _$OutboundPairingEvent_FailedPairCopyWithImpl(this._self, this._then);

  final OutboundPairingEvent_FailedPair _self;
  final $Res Function(OutboundPairingEvent_FailedPair) _then;

/// Create a copy of OutboundPairingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(OutboundPairingEvent_FailedPair(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as FailedPair,
  ));
}


}

// dart format on
