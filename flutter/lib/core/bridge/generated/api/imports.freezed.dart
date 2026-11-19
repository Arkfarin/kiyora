// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'imports.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ImportResult {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ImportResult()';
}


}

/// @nodoc
class $ImportResultCopyWith<$Res>  {
$ImportResultCopyWith(ImportResult _, $Res Function(ImportResult) __);
}


/// Adds pattern-matching-related methods to [ImportResult].
extension ImportResultPatterns on ImportResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ImportResult_Command value)?  command,TResult Function( ImportResult_Review value)?  review,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ImportResult_Command() when command != null:
return command(_that);case ImportResult_Review() when review != null:
return review(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ImportResult_Command value)  command,required TResult Function( ImportResult_Review value)  review,}){
final _that = this;
switch (_that) {
case ImportResult_Command():
return command(_that);case ImportResult_Review():
return review(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ImportResult_Command value)?  command,TResult? Function( ImportResult_Review value)?  review,}){
final _that = this;
switch (_that) {
case ImportResult_Command() when command != null:
return command(_that);case ImportResult_Review() when review != null:
return review(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Command command)?  command,TResult Function( ImportReview review)?  review,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ImportResult_Command() when command != null:
return command(_that.command);case ImportResult_Review() when review != null:
return review(_that.review);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Command command)  command,required TResult Function( ImportReview review)  review,}) {final _that = this;
switch (_that) {
case ImportResult_Command():
return command(_that.command);case ImportResult_Review():
return review(_that.review);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Command command)?  command,TResult? Function( ImportReview review)?  review,}) {final _that = this;
switch (_that) {
case ImportResult_Command() when command != null:
return command(_that.command);case ImportResult_Review() when review != null:
return review(_that.review);case _:
  return null;

}
}

}

/// @nodoc


class ImportResult_Command extends ImportResult {
  const ImportResult_Command({required this.command}): super._();
  

 final  Command command;

/// Create a copy of ImportResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImportResult_CommandCopyWith<ImportResult_Command> get copyWith => _$ImportResult_CommandCopyWithImpl<ImportResult_Command>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportResult_Command&&(identical(other.command, command) || other.command == command));
}


@override
int get hashCode {
    return Object.hash(runtimeType,command);
}

@override
String toString() {
    return 'ImportResult.command(command: $command)';
}


}

/// @nodoc
abstract mixin class $ImportResult_CommandCopyWith<$Res> implements $ImportResultCopyWith<$Res> {
  factory $ImportResult_CommandCopyWith(ImportResult_Command value, $Res Function(ImportResult_Command) _then) = _$ImportResult_CommandCopyWithImpl;
@useResult
$Res call({
 Command command
});




}
/// @nodoc
class _$ImportResult_CommandCopyWithImpl<$Res>
    implements $ImportResult_CommandCopyWith<$Res> {
  _$ImportResult_CommandCopyWithImpl(this._self, this._then);

  final ImportResult_Command _self;
  final $Res Function(ImportResult_Command) _then;

/// Create a copy of ImportResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? command = null,}) {
  return _then(ImportResult_Command(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as Command,
  ));
}


}

/// @nodoc


class ImportResult_Review extends ImportResult {
  const ImportResult_Review({required this.review}): super._();
  

 final  ImportReview review;

/// Create a copy of ImportResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImportResult_ReviewCopyWith<ImportResult_Review> get copyWith => _$ImportResult_ReviewCopyWithImpl<ImportResult_Review>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportResult_Review&&(identical(other.review, review) || other.review == review));
}


@override
int get hashCode {
    return Object.hash(runtimeType,review);
}

@override
String toString() {
    return 'ImportResult.review(review: $review)';
}


}

/// @nodoc
abstract mixin class $ImportResult_ReviewCopyWith<$Res> implements $ImportResultCopyWith<$Res> {
  factory $ImportResult_ReviewCopyWith(ImportResult_Review value, $Res Function(ImportResult_Review) _then) = _$ImportResult_ReviewCopyWithImpl;
@useResult
$Res call({
 ImportReview review
});




}
/// @nodoc
class _$ImportResult_ReviewCopyWithImpl<$Res>
    implements $ImportResult_ReviewCopyWith<$Res> {
  _$ImportResult_ReviewCopyWithImpl(this._self, this._then);

  final ImportResult_Review _self;
  final $Res Function(ImportResult_Review) _then;

/// Create a copy of ImportResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? review = null,}) {
  return _then(ImportResult_Review(
review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as ImportReview,
  ));
}


}

// dart format on
