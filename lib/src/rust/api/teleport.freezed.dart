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
mixin _$InboundFileStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InboundFileStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'InboundFileStatus()';
}


}

/// @nodoc
class $InboundFileStatusCopyWith<$Res>  {
$InboundFileStatusCopyWith(InboundFileStatus _, $Res Function(InboundFileStatus) __);
}


/// Adds pattern-matching-related methods to [InboundFileStatus].
extension InboundFileStatusPatterns on InboundFileStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( InboundFileStatus_Progress value)?  progress,TResult Function( InboundFileStatus_Done value)?  done,TResult Function( InboundFileStatus_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case InboundFileStatus_Progress() when progress != null:
return progress(_that);case InboundFileStatus_Done() when done != null:
return done(_that);case InboundFileStatus_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( InboundFileStatus_Progress value)  progress,required TResult Function( InboundFileStatus_Done value)  done,required TResult Function( InboundFileStatus_Error value)  error,}){
final _that = this;
switch (_that) {
case InboundFileStatus_Progress():
return progress(_that);case InboundFileStatus_Done():
return done(_that);case InboundFileStatus_Error():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( InboundFileStatus_Progress value)?  progress,TResult? Function( InboundFileStatus_Done value)?  done,TResult? Function( InboundFileStatus_Error value)?  error,}){
final _that = this;
switch (_that) {
case InboundFileStatus_Progress() when progress != null:
return progress(_that);case InboundFileStatus_Done() when done != null:
return done(_that);case InboundFileStatus_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( BigInt offset,  BigInt size,  double bytesPerSecond)?  progress,TResult Function( String path,  String name)?  done,TResult Function( String field0)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case InboundFileStatus_Progress() when progress != null:
return progress(_that.offset,_that.size,_that.bytesPerSecond);case InboundFileStatus_Done() when done != null:
return done(_that.path,_that.name);case InboundFileStatus_Error() when error != null:
return error(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( BigInt offset,  BigInt size,  double bytesPerSecond)  progress,required TResult Function( String path,  String name)  done,required TResult Function( String field0)  error,}) {final _that = this;
switch (_that) {
case InboundFileStatus_Progress():
return progress(_that.offset,_that.size,_that.bytesPerSecond);case InboundFileStatus_Done():
return done(_that.path,_that.name);case InboundFileStatus_Error():
return error(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( BigInt offset,  BigInt size,  double bytesPerSecond)?  progress,TResult? Function( String path,  String name)?  done,TResult? Function( String field0)?  error,}) {final _that = this;
switch (_that) {
case InboundFileStatus_Progress() when progress != null:
return progress(_that.offset,_that.size,_that.bytesPerSecond);case InboundFileStatus_Done() when done != null:
return done(_that.path,_that.name);case InboundFileStatus_Error() when error != null:
return error(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class InboundFileStatus_Progress extends InboundFileStatus {
  const InboundFileStatus_Progress({required this.offset, required this.size, required this.bytesPerSecond}): super._();
  

 final  BigInt offset;
 final  BigInt size;
 final  double bytesPerSecond;

/// Create a copy of InboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InboundFileStatus_ProgressCopyWith<InboundFileStatus_Progress> get copyWith => _$InboundFileStatus_ProgressCopyWithImpl<InboundFileStatus_Progress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InboundFileStatus_Progress&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.size, size) || other.size == size)&&(identical(other.bytesPerSecond, bytesPerSecond) || other.bytesPerSecond == bytesPerSecond));
}


@override
int get hashCode => Object.hash(runtimeType,offset,size,bytesPerSecond);

@override
String toString() {
  return 'InboundFileStatus.progress(offset: $offset, size: $size, bytesPerSecond: $bytesPerSecond)';
}


}

/// @nodoc
abstract mixin class $InboundFileStatus_ProgressCopyWith<$Res> implements $InboundFileStatusCopyWith<$Res> {
  factory $InboundFileStatus_ProgressCopyWith(InboundFileStatus_Progress value, $Res Function(InboundFileStatus_Progress) _then) = _$InboundFileStatus_ProgressCopyWithImpl;
@useResult
$Res call({
 BigInt offset, BigInt size, double bytesPerSecond
});




}
/// @nodoc
class _$InboundFileStatus_ProgressCopyWithImpl<$Res>
    implements $InboundFileStatus_ProgressCopyWith<$Res> {
  _$InboundFileStatus_ProgressCopyWithImpl(this._self, this._then);

  final InboundFileStatus_Progress _self;
  final $Res Function(InboundFileStatus_Progress) _then;

/// Create a copy of InboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? offset = null,Object? size = null,Object? bytesPerSecond = null,}) {
  return _then(InboundFileStatus_Progress(
offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as BigInt,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as BigInt,bytesPerSecond: null == bytesPerSecond ? _self.bytesPerSecond : bytesPerSecond // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class InboundFileStatus_Done extends InboundFileStatus {
  const InboundFileStatus_Done({required this.path, required this.name}): super._();
  

 final  String path;
 final  String name;

/// Create a copy of InboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InboundFileStatus_DoneCopyWith<InboundFileStatus_Done> get copyWith => _$InboundFileStatus_DoneCopyWithImpl<InboundFileStatus_Done>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InboundFileStatus_Done&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,path,name);

@override
String toString() {
  return 'InboundFileStatus.done(path: $path, name: $name)';
}


}

/// @nodoc
abstract mixin class $InboundFileStatus_DoneCopyWith<$Res> implements $InboundFileStatusCopyWith<$Res> {
  factory $InboundFileStatus_DoneCopyWith(InboundFileStatus_Done value, $Res Function(InboundFileStatus_Done) _then) = _$InboundFileStatus_DoneCopyWithImpl;
@useResult
$Res call({
 String path, String name
});




}
/// @nodoc
class _$InboundFileStatus_DoneCopyWithImpl<$Res>
    implements $InboundFileStatus_DoneCopyWith<$Res> {
  _$InboundFileStatus_DoneCopyWithImpl(this._self, this._then);

  final InboundFileStatus_Done _self;
  final $Res Function(InboundFileStatus_Done) _then;

/// Create a copy of InboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? name = null,}) {
  return _then(InboundFileStatus_Done(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class InboundFileStatus_Error extends InboundFileStatus {
  const InboundFileStatus_Error(this.field0): super._();
  

 final  String field0;

/// Create a copy of InboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InboundFileStatus_ErrorCopyWith<InboundFileStatus_Error> get copyWith => _$InboundFileStatus_ErrorCopyWithImpl<InboundFileStatus_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InboundFileStatus_Error&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'InboundFileStatus.error(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $InboundFileStatus_ErrorCopyWith<$Res> implements $InboundFileStatusCopyWith<$Res> {
  factory $InboundFileStatus_ErrorCopyWith(InboundFileStatus_Error value, $Res Function(InboundFileStatus_Error) _then) = _$InboundFileStatus_ErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$InboundFileStatus_ErrorCopyWithImpl<$Res>
    implements $InboundFileStatus_ErrorCopyWith<$Res> {
  _$InboundFileStatus_ErrorCopyWithImpl(this._self, this._then);

  final InboundFileStatus_Error _self;
  final $Res Function(InboundFileStatus_Error) _then;

/// Create a copy of InboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(InboundFileStatus_Error(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$OutboundFileStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutboundFileStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OutboundFileStatus()';
}


}

/// @nodoc
class $OutboundFileStatusCopyWith<$Res>  {
$OutboundFileStatusCopyWith(OutboundFileStatus _, $Res Function(OutboundFileStatus) __);
}


/// Adds pattern-matching-related methods to [OutboundFileStatus].
extension OutboundFileStatusPatterns on OutboundFileStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( OutboundFileStatus_Progress value)?  progress,TResult Function( OutboundFileStatus_Done value)?  done,TResult Function( OutboundFileStatus_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case OutboundFileStatus_Progress() when progress != null:
return progress(_that);case OutboundFileStatus_Done() when done != null:
return done(_that);case OutboundFileStatus_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( OutboundFileStatus_Progress value)  progress,required TResult Function( OutboundFileStatus_Done value)  done,required TResult Function( OutboundFileStatus_Error value)  error,}){
final _that = this;
switch (_that) {
case OutboundFileStatus_Progress():
return progress(_that);case OutboundFileStatus_Done():
return done(_that);case OutboundFileStatus_Error():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( OutboundFileStatus_Progress value)?  progress,TResult? Function( OutboundFileStatus_Done value)?  done,TResult? Function( OutboundFileStatus_Error value)?  error,}){
final _that = this;
switch (_that) {
case OutboundFileStatus_Progress() when progress != null:
return progress(_that);case OutboundFileStatus_Done() when done != null:
return done(_that);case OutboundFileStatus_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( BigInt offset,  BigInt size,  double bytesPerSecond)?  progress,TResult Function()?  done,TResult Function( String field0)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case OutboundFileStatus_Progress() when progress != null:
return progress(_that.offset,_that.size,_that.bytesPerSecond);case OutboundFileStatus_Done() when done != null:
return done();case OutboundFileStatus_Error() when error != null:
return error(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( BigInt offset,  BigInt size,  double bytesPerSecond)  progress,required TResult Function()  done,required TResult Function( String field0)  error,}) {final _that = this;
switch (_that) {
case OutboundFileStatus_Progress():
return progress(_that.offset,_that.size,_that.bytesPerSecond);case OutboundFileStatus_Done():
return done();case OutboundFileStatus_Error():
return error(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( BigInt offset,  BigInt size,  double bytesPerSecond)?  progress,TResult? Function()?  done,TResult? Function( String field0)?  error,}) {final _that = this;
switch (_that) {
case OutboundFileStatus_Progress() when progress != null:
return progress(_that.offset,_that.size,_that.bytesPerSecond);case OutboundFileStatus_Done() when done != null:
return done();case OutboundFileStatus_Error() when error != null:
return error(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class OutboundFileStatus_Progress extends OutboundFileStatus {
  const OutboundFileStatus_Progress({required this.offset, required this.size, required this.bytesPerSecond}): super._();
  

 final  BigInt offset;
 final  BigInt size;
 final  double bytesPerSecond;

/// Create a copy of OutboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OutboundFileStatus_ProgressCopyWith<OutboundFileStatus_Progress> get copyWith => _$OutboundFileStatus_ProgressCopyWithImpl<OutboundFileStatus_Progress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutboundFileStatus_Progress&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.size, size) || other.size == size)&&(identical(other.bytesPerSecond, bytesPerSecond) || other.bytesPerSecond == bytesPerSecond));
}


@override
int get hashCode => Object.hash(runtimeType,offset,size,bytesPerSecond);

@override
String toString() {
  return 'OutboundFileStatus.progress(offset: $offset, size: $size, bytesPerSecond: $bytesPerSecond)';
}


}

/// @nodoc
abstract mixin class $OutboundFileStatus_ProgressCopyWith<$Res> implements $OutboundFileStatusCopyWith<$Res> {
  factory $OutboundFileStatus_ProgressCopyWith(OutboundFileStatus_Progress value, $Res Function(OutboundFileStatus_Progress) _then) = _$OutboundFileStatus_ProgressCopyWithImpl;
@useResult
$Res call({
 BigInt offset, BigInt size, double bytesPerSecond
});




}
/// @nodoc
class _$OutboundFileStatus_ProgressCopyWithImpl<$Res>
    implements $OutboundFileStatus_ProgressCopyWith<$Res> {
  _$OutboundFileStatus_ProgressCopyWithImpl(this._self, this._then);

  final OutboundFileStatus_Progress _self;
  final $Res Function(OutboundFileStatus_Progress) _then;

/// Create a copy of OutboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? offset = null,Object? size = null,Object? bytesPerSecond = null,}) {
  return _then(OutboundFileStatus_Progress(
offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as BigInt,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as BigInt,bytesPerSecond: null == bytesPerSecond ? _self.bytesPerSecond : bytesPerSecond // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class OutboundFileStatus_Done extends OutboundFileStatus {
  const OutboundFileStatus_Done(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutboundFileStatus_Done);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OutboundFileStatus.done()';
}


}




/// @nodoc


class OutboundFileStatus_Error extends OutboundFileStatus {
  const OutboundFileStatus_Error(this.field0): super._();
  

 final  String field0;

/// Create a copy of OutboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OutboundFileStatus_ErrorCopyWith<OutboundFileStatus_Error> get copyWith => _$OutboundFileStatus_ErrorCopyWithImpl<OutboundFileStatus_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutboundFileStatus_Error&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'OutboundFileStatus.error(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $OutboundFileStatus_ErrorCopyWith<$Res> implements $OutboundFileStatusCopyWith<$Res> {
  factory $OutboundFileStatus_ErrorCopyWith(OutboundFileStatus_Error value, $Res Function(OutboundFileStatus_Error) _then) = _$OutboundFileStatus_ErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$OutboundFileStatus_ErrorCopyWithImpl<$Res>
    implements $OutboundFileStatus_ErrorCopyWith<$Res> {
  _$OutboundFileStatus_ErrorCopyWithImpl(this._self, this._then);

  final OutboundFileStatus_Error _self;
  final $Res Function(OutboundFileStatus_Error) _then;

/// Create a copy of OutboundFileStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(OutboundFileStatus_Error(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PairingResponse {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingResponse);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PairingResponse()';
}


}

/// @nodoc
class $PairingResponseCopyWith<$Res>  {
$PairingResponseCopyWith(PairingResponse _, $Res Function(PairingResponse) __);
}


/// Adds pattern-matching-related methods to [PairingResponse].
extension PairingResponsePatterns on PairingResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PairingResponse_Success value)?  success,TResult Function( PairingResponse_WrongCode value)?  wrongCode,TResult Function( PairingResponse_WrongSecret value)?  wrongSecret,TResult Function( PairingResponse_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PairingResponse_Success() when success != null:
return success(_that);case PairingResponse_WrongCode() when wrongCode != null:
return wrongCode(_that);case PairingResponse_WrongSecret() when wrongSecret != null:
return wrongSecret(_that);case PairingResponse_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PairingResponse_Success value)  success,required TResult Function( PairingResponse_WrongCode value)  wrongCode,required TResult Function( PairingResponse_WrongSecret value)  wrongSecret,required TResult Function( PairingResponse_Error value)  error,}){
final _that = this;
switch (_that) {
case PairingResponse_Success():
return success(_that);case PairingResponse_WrongCode():
return wrongCode(_that);case PairingResponse_WrongSecret():
return wrongSecret(_that);case PairingResponse_Error():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PairingResponse_Success value)?  success,TResult? Function( PairingResponse_WrongCode value)?  wrongCode,TResult? Function( PairingResponse_WrongSecret value)?  wrongSecret,TResult? Function( PairingResponse_Error value)?  error,}){
final _that = this;
switch (_that) {
case PairingResponse_Success() when success != null:
return success(_that);case PairingResponse_WrongCode() when wrongCode != null:
return wrongCode(_that);case PairingResponse_WrongSecret() when wrongSecret != null:
return wrongSecret(_that);case PairingResponse_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  success,TResult Function()?  wrongCode,TResult Function()?  wrongSecret,TResult Function( String field0)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PairingResponse_Success() when success != null:
return success();case PairingResponse_WrongCode() when wrongCode != null:
return wrongCode();case PairingResponse_WrongSecret() when wrongSecret != null:
return wrongSecret();case PairingResponse_Error() when error != null:
return error(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  success,required TResult Function()  wrongCode,required TResult Function()  wrongSecret,required TResult Function( String field0)  error,}) {final _that = this;
switch (_that) {
case PairingResponse_Success():
return success();case PairingResponse_WrongCode():
return wrongCode();case PairingResponse_WrongSecret():
return wrongSecret();case PairingResponse_Error():
return error(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  success,TResult? Function()?  wrongCode,TResult? Function()?  wrongSecret,TResult? Function( String field0)?  error,}) {final _that = this;
switch (_that) {
case PairingResponse_Success() when success != null:
return success();case PairingResponse_WrongCode() when wrongCode != null:
return wrongCode();case PairingResponse_WrongSecret() when wrongSecret != null:
return wrongSecret();case PairingResponse_Error() when error != null:
return error(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class PairingResponse_Success extends PairingResponse {
  const PairingResponse_Success(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingResponse_Success);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PairingResponse.success()';
}


}




/// @nodoc


class PairingResponse_WrongCode extends PairingResponse {
  const PairingResponse_WrongCode(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingResponse_WrongCode);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PairingResponse.wrongCode()';
}


}




/// @nodoc


class PairingResponse_WrongSecret extends PairingResponse {
  const PairingResponse_WrongSecret(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingResponse_WrongSecret);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PairingResponse.wrongSecret()';
}


}




/// @nodoc


class PairingResponse_Error extends PairingResponse {
  const PairingResponse_Error(this.field0): super._();
  

 final  String field0;

/// Create a copy of PairingResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairingResponse_ErrorCopyWith<PairingResponse_Error> get copyWith => _$PairingResponse_ErrorCopyWithImpl<PairingResponse_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingResponse_Error&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'PairingResponse.error(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $PairingResponse_ErrorCopyWith<$Res> implements $PairingResponseCopyWith<$Res> {
  factory $PairingResponse_ErrorCopyWith(PairingResponse_Error value, $Res Function(PairingResponse_Error) _then) = _$PairingResponse_ErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$PairingResponse_ErrorCopyWithImpl<$Res>
    implements $PairingResponse_ErrorCopyWith<$Res> {
  _$PairingResponse_ErrorCopyWithImpl(this._self, this._then);

  final PairingResponse_Error _self;
  final $Res Function(PairingResponse_Error) _then;

/// Create a copy of PairingResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(PairingResponse_Error(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$SendFileSource {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendFileSource&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'SendFileSource(field0: $field0)';
}


}

/// @nodoc
class $SendFileSourceCopyWith<$Res>  {
$SendFileSourceCopyWith(SendFileSource _, $Res Function(SendFileSource) __);
}


/// Adds pattern-matching-related methods to [SendFileSource].
extension SendFileSourcePatterns on SendFileSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SendFileSource_Path value)?  path,TResult Function( SendFileSource_Fd value)?  fd,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SendFileSource_Path() when path != null:
return path(_that);case SendFileSource_Fd() when fd != null:
return fd(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SendFileSource_Path value)  path,required TResult Function( SendFileSource_Fd value)  fd,}){
final _that = this;
switch (_that) {
case SendFileSource_Path():
return path(_that);case SendFileSource_Fd():
return fd(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SendFileSource_Path value)?  path,TResult? Function( SendFileSource_Fd value)?  fd,}){
final _that = this;
switch (_that) {
case SendFileSource_Path() when path != null:
return path(_that);case SendFileSource_Fd() when fd != null:
return fd(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String field0)?  path,TResult Function( int field0)?  fd,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SendFileSource_Path() when path != null:
return path(_that.field0);case SendFileSource_Fd() when fd != null:
return fd(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String field0)  path,required TResult Function( int field0)  fd,}) {final _that = this;
switch (_that) {
case SendFileSource_Path():
return path(_that.field0);case SendFileSource_Fd():
return fd(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String field0)?  path,TResult? Function( int field0)?  fd,}) {final _that = this;
switch (_that) {
case SendFileSource_Path() when path != null:
return path(_that.field0);case SendFileSource_Fd() when fd != null:
return fd(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class SendFileSource_Path extends SendFileSource {
  const SendFileSource_Path(this.field0): super._();
  

@override final  String field0;

/// Create a copy of SendFileSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendFileSource_PathCopyWith<SendFileSource_Path> get copyWith => _$SendFileSource_PathCopyWithImpl<SendFileSource_Path>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendFileSource_Path&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'SendFileSource.path(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $SendFileSource_PathCopyWith<$Res> implements $SendFileSourceCopyWith<$Res> {
  factory $SendFileSource_PathCopyWith(SendFileSource_Path value, $Res Function(SendFileSource_Path) _then) = _$SendFileSource_PathCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$SendFileSource_PathCopyWithImpl<$Res>
    implements $SendFileSource_PathCopyWith<$Res> {
  _$SendFileSource_PathCopyWithImpl(this._self, this._then);

  final SendFileSource_Path _self;
  final $Res Function(SendFileSource_Path) _then;

/// Create a copy of SendFileSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(SendFileSource_Path(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class SendFileSource_Fd extends SendFileSource {
  const SendFileSource_Fd(this.field0): super._();
  

@override final  int field0;

/// Create a copy of SendFileSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendFileSource_FdCopyWith<SendFileSource_Fd> get copyWith => _$SendFileSource_FdCopyWithImpl<SendFileSource_Fd>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendFileSource_Fd&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'SendFileSource.fd(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $SendFileSource_FdCopyWith<$Res> implements $SendFileSourceCopyWith<$Res> {
  factory $SendFileSource_FdCopyWith(SendFileSource_Fd value, $Res Function(SendFileSource_Fd) _then) = _$SendFileSource_FdCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$SendFileSource_FdCopyWithImpl<$Res>
    implements $SendFileSource_FdCopyWith<$Res> {
  _$SendFileSource_FdCopyWithImpl(this._self, this._then);

  final SendFileSource_Fd _self;
  final $Res Function(SendFileSource_Fd) _then;

/// Create a copy of SendFileSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(SendFileSource_Fd(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UIConnectionQuality {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UIConnectionQuality);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UIConnectionQuality()';
}


}

/// @nodoc
class $UIConnectionQualityCopyWith<$Res>  {
$UIConnectionQualityCopyWith(UIConnectionQuality _, $Res Function(UIConnectionQuality) __);
}


/// Adds pattern-matching-related methods to [UIConnectionQuality].
extension UIConnectionQualityPatterns on UIConnectionQuality {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UIConnectionQuality_Direct value)?  direct,TResult Function( UIConnectionQuality_Relay value)?  relay,TResult Function( UIConnectionQuality_None value)?  none,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UIConnectionQuality_Direct() when direct != null:
return direct(_that);case UIConnectionQuality_Relay() when relay != null:
return relay(_that);case UIConnectionQuality_None() when none != null:
return none(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UIConnectionQuality_Direct value)  direct,required TResult Function( UIConnectionQuality_Relay value)  relay,required TResult Function( UIConnectionQuality_None value)  none,}){
final _that = this;
switch (_that) {
case UIConnectionQuality_Direct():
return direct(_that);case UIConnectionQuality_Relay():
return relay(_that);case UIConnectionQuality_None():
return none(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UIConnectionQuality_Direct value)?  direct,TResult? Function( UIConnectionQuality_Relay value)?  relay,TResult? Function( UIConnectionQuality_None value)?  none,}){
final _that = this;
switch (_that) {
case UIConnectionQuality_Direct() when direct != null:
return direct(_that);case UIConnectionQuality_Relay() when relay != null:
return relay(_that);case UIConnectionQuality_None() when none != null:
return none(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( BigInt latency)?  direct,TResult Function( BigInt latency)?  relay,TResult Function()?  none,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UIConnectionQuality_Direct() when direct != null:
return direct(_that.latency);case UIConnectionQuality_Relay() when relay != null:
return relay(_that.latency);case UIConnectionQuality_None() when none != null:
return none();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( BigInt latency)  direct,required TResult Function( BigInt latency)  relay,required TResult Function()  none,}) {final _that = this;
switch (_that) {
case UIConnectionQuality_Direct():
return direct(_that.latency);case UIConnectionQuality_Relay():
return relay(_that.latency);case UIConnectionQuality_None():
return none();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( BigInt latency)?  direct,TResult? Function( BigInt latency)?  relay,TResult? Function()?  none,}) {final _that = this;
switch (_that) {
case UIConnectionQuality_Direct() when direct != null:
return direct(_that.latency);case UIConnectionQuality_Relay() when relay != null:
return relay(_that.latency);case UIConnectionQuality_None() when none != null:
return none();case _:
  return null;

}
}

}

/// @nodoc


class UIConnectionQuality_Direct extends UIConnectionQuality {
  const UIConnectionQuality_Direct({required this.latency}): super._();
  

 final  BigInt latency;

/// Create a copy of UIConnectionQuality
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UIConnectionQuality_DirectCopyWith<UIConnectionQuality_Direct> get copyWith => _$UIConnectionQuality_DirectCopyWithImpl<UIConnectionQuality_Direct>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UIConnectionQuality_Direct&&(identical(other.latency, latency) || other.latency == latency));
}


@override
int get hashCode => Object.hash(runtimeType,latency);

@override
String toString() {
  return 'UIConnectionQuality.direct(latency: $latency)';
}


}

/// @nodoc
abstract mixin class $UIConnectionQuality_DirectCopyWith<$Res> implements $UIConnectionQualityCopyWith<$Res> {
  factory $UIConnectionQuality_DirectCopyWith(UIConnectionQuality_Direct value, $Res Function(UIConnectionQuality_Direct) _then) = _$UIConnectionQuality_DirectCopyWithImpl;
@useResult
$Res call({
 BigInt latency
});




}
/// @nodoc
class _$UIConnectionQuality_DirectCopyWithImpl<$Res>
    implements $UIConnectionQuality_DirectCopyWith<$Res> {
  _$UIConnectionQuality_DirectCopyWithImpl(this._self, this._then);

  final UIConnectionQuality_Direct _self;
  final $Res Function(UIConnectionQuality_Direct) _then;

/// Create a copy of UIConnectionQuality
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? latency = null,}) {
  return _then(UIConnectionQuality_Direct(
latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class UIConnectionQuality_Relay extends UIConnectionQuality {
  const UIConnectionQuality_Relay({required this.latency}): super._();
  

 final  BigInt latency;

/// Create a copy of UIConnectionQuality
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UIConnectionQuality_RelayCopyWith<UIConnectionQuality_Relay> get copyWith => _$UIConnectionQuality_RelayCopyWithImpl<UIConnectionQuality_Relay>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UIConnectionQuality_Relay&&(identical(other.latency, latency) || other.latency == latency));
}


@override
int get hashCode => Object.hash(runtimeType,latency);

@override
String toString() {
  return 'UIConnectionQuality.relay(latency: $latency)';
}


}

/// @nodoc
abstract mixin class $UIConnectionQuality_RelayCopyWith<$Res> implements $UIConnectionQualityCopyWith<$Res> {
  factory $UIConnectionQuality_RelayCopyWith(UIConnectionQuality_Relay value, $Res Function(UIConnectionQuality_Relay) _then) = _$UIConnectionQuality_RelayCopyWithImpl;
@useResult
$Res call({
 BigInt latency
});




}
/// @nodoc
class _$UIConnectionQuality_RelayCopyWithImpl<$Res>
    implements $UIConnectionQuality_RelayCopyWith<$Res> {
  _$UIConnectionQuality_RelayCopyWithImpl(this._self, this._then);

  final UIConnectionQuality_Relay _self;
  final $Res Function(UIConnectionQuality_Relay) _then;

/// Create a copy of UIConnectionQuality
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? latency = null,}) {
  return _then(UIConnectionQuality_Relay(
latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class UIConnectionQuality_None extends UIConnectionQuality {
  const UIConnectionQuality_None(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UIConnectionQuality_None);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UIConnectionQuality.none()';
}


}




// dart format on
