// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'edits.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LibraryEdit {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryEdit);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'LibraryEdit()';
}


}

/// @nodoc
class $LibraryEditCopyWith<$Res>  {
$LibraryEditCopyWith(LibraryEdit _, $Res Function(LibraryEdit) __);
}


/// Adds pattern-matching-related methods to [LibraryEdit].
extension LibraryEditPatterns on LibraryEdit {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LibraryEdit_CreatePlaylist value)?  createPlaylist,TResult Function( LibraryEdit_RenamePlaylist value)?  renamePlaylist,TResult Function( LibraryEdit_DeletePlaylist value)?  deletePlaylist,TResult Function( LibraryEdit_AddTrack value)?  addTrack,TResult Function( LibraryEdit_RemoveTrack value)?  removeTrack,TResult Function( LibraryEdit_MoveTrack value)?  moveTrack,TResult Function( LibraryEdit_Favorite value)?  favorite,TResult Function( LibraryEdit_DeleteTrack value)?  deleteTrack,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LibraryEdit_CreatePlaylist() when createPlaylist != null:
return createPlaylist(_that);case LibraryEdit_RenamePlaylist() when renamePlaylist != null:
return renamePlaylist(_that);case LibraryEdit_DeletePlaylist() when deletePlaylist != null:
return deletePlaylist(_that);case LibraryEdit_AddTrack() when addTrack != null:
return addTrack(_that);case LibraryEdit_RemoveTrack() when removeTrack != null:
return removeTrack(_that);case LibraryEdit_MoveTrack() when moveTrack != null:
return moveTrack(_that);case LibraryEdit_Favorite() when favorite != null:
return favorite(_that);case LibraryEdit_DeleteTrack() when deleteTrack != null:
return deleteTrack(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LibraryEdit_CreatePlaylist value)  createPlaylist,required TResult Function( LibraryEdit_RenamePlaylist value)  renamePlaylist,required TResult Function( LibraryEdit_DeletePlaylist value)  deletePlaylist,required TResult Function( LibraryEdit_AddTrack value)  addTrack,required TResult Function( LibraryEdit_RemoveTrack value)  removeTrack,required TResult Function( LibraryEdit_MoveTrack value)  moveTrack,required TResult Function( LibraryEdit_Favorite value)  favorite,required TResult Function( LibraryEdit_DeleteTrack value)  deleteTrack,}){
final _that = this;
switch (_that) {
case LibraryEdit_CreatePlaylist():
return createPlaylist(_that);case LibraryEdit_RenamePlaylist():
return renamePlaylist(_that);case LibraryEdit_DeletePlaylist():
return deletePlaylist(_that);case LibraryEdit_AddTrack():
return addTrack(_that);case LibraryEdit_RemoveTrack():
return removeTrack(_that);case LibraryEdit_MoveTrack():
return moveTrack(_that);case LibraryEdit_Favorite():
return favorite(_that);case LibraryEdit_DeleteTrack():
return deleteTrack(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LibraryEdit_CreatePlaylist value)?  createPlaylist,TResult? Function( LibraryEdit_RenamePlaylist value)?  renamePlaylist,TResult? Function( LibraryEdit_DeletePlaylist value)?  deletePlaylist,TResult? Function( LibraryEdit_AddTrack value)?  addTrack,TResult? Function( LibraryEdit_RemoveTrack value)?  removeTrack,TResult? Function( LibraryEdit_MoveTrack value)?  moveTrack,TResult? Function( LibraryEdit_Favorite value)?  favorite,TResult? Function( LibraryEdit_DeleteTrack value)?  deleteTrack,}){
final _that = this;
switch (_that) {
case LibraryEdit_CreatePlaylist() when createPlaylist != null:
return createPlaylist(_that);case LibraryEdit_RenamePlaylist() when renamePlaylist != null:
return renamePlaylist(_that);case LibraryEdit_DeletePlaylist() when deletePlaylist != null:
return deletePlaylist(_that);case LibraryEdit_AddTrack() when addTrack != null:
return addTrack(_that);case LibraryEdit_RemoveTrack() when removeTrack != null:
return removeTrack(_that);case LibraryEdit_MoveTrack() when moveTrack != null:
return moveTrack(_that);case LibraryEdit_Favorite() when favorite != null:
return favorite(_that);case LibraryEdit_DeleteTrack() when deleteTrack != null:
return deleteTrack(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String title)?  createPlaylist,TResult Function( String title)?  renamePlaylist,TResult Function()?  deletePlaylist,TResult Function( String trackId,  String entryId,  String? afterEntryId)?  addTrack,TResult Function( String entryId)?  removeTrack,TResult Function( String entryId,  String? afterEntryId)?  moveTrack,TResult Function( String setName,  bool value)?  favorite,TResult Function()?  deleteTrack,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LibraryEdit_CreatePlaylist() when createPlaylist != null:
return createPlaylist(_that.title);case LibraryEdit_RenamePlaylist() when renamePlaylist != null:
return renamePlaylist(_that.title);case LibraryEdit_DeletePlaylist() when deletePlaylist != null:
return deletePlaylist();case LibraryEdit_AddTrack() when addTrack != null:
return addTrack(_that.trackId,_that.entryId,_that.afterEntryId);case LibraryEdit_RemoveTrack() when removeTrack != null:
return removeTrack(_that.entryId);case LibraryEdit_MoveTrack() when moveTrack != null:
return moveTrack(_that.entryId,_that.afterEntryId);case LibraryEdit_Favorite() when favorite != null:
return favorite(_that.setName,_that.value);case LibraryEdit_DeleteTrack() when deleteTrack != null:
return deleteTrack();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String title)  createPlaylist,required TResult Function( String title)  renamePlaylist,required TResult Function()  deletePlaylist,required TResult Function( String trackId,  String entryId,  String? afterEntryId)  addTrack,required TResult Function( String entryId)  removeTrack,required TResult Function( String entryId,  String? afterEntryId)  moveTrack,required TResult Function( String setName,  bool value)  favorite,required TResult Function()  deleteTrack,}) {final _that = this;
switch (_that) {
case LibraryEdit_CreatePlaylist():
return createPlaylist(_that.title);case LibraryEdit_RenamePlaylist():
return renamePlaylist(_that.title);case LibraryEdit_DeletePlaylist():
return deletePlaylist();case LibraryEdit_AddTrack():
return addTrack(_that.trackId,_that.entryId,_that.afterEntryId);case LibraryEdit_RemoveTrack():
return removeTrack(_that.entryId);case LibraryEdit_MoveTrack():
return moveTrack(_that.entryId,_that.afterEntryId);case LibraryEdit_Favorite():
return favorite(_that.setName,_that.value);case LibraryEdit_DeleteTrack():
return deleteTrack();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String title)?  createPlaylist,TResult? Function( String title)?  renamePlaylist,TResult? Function()?  deletePlaylist,TResult? Function( String trackId,  String entryId,  String? afterEntryId)?  addTrack,TResult? Function( String entryId)?  removeTrack,TResult? Function( String entryId,  String? afterEntryId)?  moveTrack,TResult? Function( String setName,  bool value)?  favorite,TResult? Function()?  deleteTrack,}) {final _that = this;
switch (_that) {
case LibraryEdit_CreatePlaylist() when createPlaylist != null:
return createPlaylist(_that.title);case LibraryEdit_RenamePlaylist() when renamePlaylist != null:
return renamePlaylist(_that.title);case LibraryEdit_DeletePlaylist() when deletePlaylist != null:
return deletePlaylist();case LibraryEdit_AddTrack() when addTrack != null:
return addTrack(_that.trackId,_that.entryId,_that.afterEntryId);case LibraryEdit_RemoveTrack() when removeTrack != null:
return removeTrack(_that.entryId);case LibraryEdit_MoveTrack() when moveTrack != null:
return moveTrack(_that.entryId,_that.afterEntryId);case LibraryEdit_Favorite() when favorite != null:
return favorite(_that.setName,_that.value);case LibraryEdit_DeleteTrack() when deleteTrack != null:
return deleteTrack();case _:
  return null;

}
}

}

/// @nodoc


class LibraryEdit_CreatePlaylist extends LibraryEdit {
  const LibraryEdit_CreatePlaylist({required this.title}): super._();
  

 final  String title;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryEdit_CreatePlaylistCopyWith<LibraryEdit_CreatePlaylist> get copyWith => _$LibraryEdit_CreatePlaylistCopyWithImpl<LibraryEdit_CreatePlaylist>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryEdit_CreatePlaylist&&(identical(other.title, title) || other.title == title));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title);
}

@override
String toString() {
    return 'LibraryEdit.createPlaylist(title: $title)';
}


}

/// @nodoc
abstract mixin class $LibraryEdit_CreatePlaylistCopyWith<$Res> implements $LibraryEditCopyWith<$Res> {
  factory $LibraryEdit_CreatePlaylistCopyWith(LibraryEdit_CreatePlaylist value, $Res Function(LibraryEdit_CreatePlaylist) _then) = _$LibraryEdit_CreatePlaylistCopyWithImpl;
@useResult
$Res call({
 String title
});




}
/// @nodoc
class _$LibraryEdit_CreatePlaylistCopyWithImpl<$Res>
    implements $LibraryEdit_CreatePlaylistCopyWith<$Res> {
  _$LibraryEdit_CreatePlaylistCopyWithImpl(this._self, this._then);

  final LibraryEdit_CreatePlaylist _self;
  final $Res Function(LibraryEdit_CreatePlaylist) _then;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? title = null,}) {
  return _then(LibraryEdit_CreatePlaylist(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LibraryEdit_RenamePlaylist extends LibraryEdit {
  const LibraryEdit_RenamePlaylist({required this.title}): super._();
  

 final  String title;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryEdit_RenamePlaylistCopyWith<LibraryEdit_RenamePlaylist> get copyWith => _$LibraryEdit_RenamePlaylistCopyWithImpl<LibraryEdit_RenamePlaylist>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryEdit_RenamePlaylist&&(identical(other.title, title) || other.title == title));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title);
}

@override
String toString() {
    return 'LibraryEdit.renamePlaylist(title: $title)';
}


}

/// @nodoc
abstract mixin class $LibraryEdit_RenamePlaylistCopyWith<$Res> implements $LibraryEditCopyWith<$Res> {
  factory $LibraryEdit_RenamePlaylistCopyWith(LibraryEdit_RenamePlaylist value, $Res Function(LibraryEdit_RenamePlaylist) _then) = _$LibraryEdit_RenamePlaylistCopyWithImpl;
@useResult
$Res call({
 String title
});




}
/// @nodoc
class _$LibraryEdit_RenamePlaylistCopyWithImpl<$Res>
    implements $LibraryEdit_RenamePlaylistCopyWith<$Res> {
  _$LibraryEdit_RenamePlaylistCopyWithImpl(this._self, this._then);

  final LibraryEdit_RenamePlaylist _self;
  final $Res Function(LibraryEdit_RenamePlaylist) _then;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? title = null,}) {
  return _then(LibraryEdit_RenamePlaylist(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LibraryEdit_DeletePlaylist extends LibraryEdit {
  const LibraryEdit_DeletePlaylist(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryEdit_DeletePlaylist);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'LibraryEdit.deletePlaylist()';
}


}




/// @nodoc


class LibraryEdit_AddTrack extends LibraryEdit {
  const LibraryEdit_AddTrack({required this.trackId, required this.entryId, this.afterEntryId}): super._();
  

 final  String trackId;
 final  String entryId;
 final  String? afterEntryId;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryEdit_AddTrackCopyWith<LibraryEdit_AddTrack> get copyWith => _$LibraryEdit_AddTrackCopyWithImpl<LibraryEdit_AddTrack>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryEdit_AddTrack&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.entryId, entryId) || other.entryId == entryId)&&(identical(other.afterEntryId, afterEntryId) || other.afterEntryId == afterEntryId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,trackId,entryId,afterEntryId);
}

@override
String toString() {
    return 'LibraryEdit.addTrack(trackId: $trackId, entryId: $entryId, afterEntryId: $afterEntryId)';
}


}

/// @nodoc
abstract mixin class $LibraryEdit_AddTrackCopyWith<$Res> implements $LibraryEditCopyWith<$Res> {
  factory $LibraryEdit_AddTrackCopyWith(LibraryEdit_AddTrack value, $Res Function(LibraryEdit_AddTrack) _then) = _$LibraryEdit_AddTrackCopyWithImpl;
@useResult
$Res call({
 String trackId, String entryId, String? afterEntryId
});




}
/// @nodoc
class _$LibraryEdit_AddTrackCopyWithImpl<$Res>
    implements $LibraryEdit_AddTrackCopyWith<$Res> {
  _$LibraryEdit_AddTrackCopyWithImpl(this._self, this._then);

  final LibraryEdit_AddTrack _self;
  final $Res Function(LibraryEdit_AddTrack) _then;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? entryId = null,Object? afterEntryId = freezed,}) {
  return _then(LibraryEdit_AddTrack(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,entryId: null == entryId ? _self.entryId : entryId // ignore: cast_nullable_to_non_nullable
as String,afterEntryId: freezed == afterEntryId ? _self.afterEntryId : afterEntryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class LibraryEdit_RemoveTrack extends LibraryEdit {
  const LibraryEdit_RemoveTrack({required this.entryId}): super._();
  

 final  String entryId;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryEdit_RemoveTrackCopyWith<LibraryEdit_RemoveTrack> get copyWith => _$LibraryEdit_RemoveTrackCopyWithImpl<LibraryEdit_RemoveTrack>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryEdit_RemoveTrack&&(identical(other.entryId, entryId) || other.entryId == entryId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,entryId);
}

@override
String toString() {
    return 'LibraryEdit.removeTrack(entryId: $entryId)';
}


}

/// @nodoc
abstract mixin class $LibraryEdit_RemoveTrackCopyWith<$Res> implements $LibraryEditCopyWith<$Res> {
  factory $LibraryEdit_RemoveTrackCopyWith(LibraryEdit_RemoveTrack value, $Res Function(LibraryEdit_RemoveTrack) _then) = _$LibraryEdit_RemoveTrackCopyWithImpl;
@useResult
$Res call({
 String entryId
});




}
/// @nodoc
class _$LibraryEdit_RemoveTrackCopyWithImpl<$Res>
    implements $LibraryEdit_RemoveTrackCopyWith<$Res> {
  _$LibraryEdit_RemoveTrackCopyWithImpl(this._self, this._then);

  final LibraryEdit_RemoveTrack _self;
  final $Res Function(LibraryEdit_RemoveTrack) _then;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entryId = null,}) {
  return _then(LibraryEdit_RemoveTrack(
entryId: null == entryId ? _self.entryId : entryId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LibraryEdit_MoveTrack extends LibraryEdit {
  const LibraryEdit_MoveTrack({required this.entryId, this.afterEntryId}): super._();
  

 final  String entryId;
 final  String? afterEntryId;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryEdit_MoveTrackCopyWith<LibraryEdit_MoveTrack> get copyWith => _$LibraryEdit_MoveTrackCopyWithImpl<LibraryEdit_MoveTrack>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryEdit_MoveTrack&&(identical(other.entryId, entryId) || other.entryId == entryId)&&(identical(other.afterEntryId, afterEntryId) || other.afterEntryId == afterEntryId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,entryId,afterEntryId);
}

@override
String toString() {
    return 'LibraryEdit.moveTrack(entryId: $entryId, afterEntryId: $afterEntryId)';
}


}

/// @nodoc
abstract mixin class $LibraryEdit_MoveTrackCopyWith<$Res> implements $LibraryEditCopyWith<$Res> {
  factory $LibraryEdit_MoveTrackCopyWith(LibraryEdit_MoveTrack value, $Res Function(LibraryEdit_MoveTrack) _then) = _$LibraryEdit_MoveTrackCopyWithImpl;
@useResult
$Res call({
 String entryId, String? afterEntryId
});




}
/// @nodoc
class _$LibraryEdit_MoveTrackCopyWithImpl<$Res>
    implements $LibraryEdit_MoveTrackCopyWith<$Res> {
  _$LibraryEdit_MoveTrackCopyWithImpl(this._self, this._then);

  final LibraryEdit_MoveTrack _self;
  final $Res Function(LibraryEdit_MoveTrack) _then;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entryId = null,Object? afterEntryId = freezed,}) {
  return _then(LibraryEdit_MoveTrack(
entryId: null == entryId ? _self.entryId : entryId // ignore: cast_nullable_to_non_nullable
as String,afterEntryId: freezed == afterEntryId ? _self.afterEntryId : afterEntryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class LibraryEdit_Favorite extends LibraryEdit {
  const LibraryEdit_Favorite({required this.setName, required this.value}): super._();
  

 final  String setName;
 final  bool value;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryEdit_FavoriteCopyWith<LibraryEdit_Favorite> get copyWith => _$LibraryEdit_FavoriteCopyWithImpl<LibraryEdit_Favorite>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryEdit_Favorite&&(identical(other.setName, setName) || other.setName == setName)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode {
    return Object.hash(runtimeType,setName,value);
}

@override
String toString() {
    return 'LibraryEdit.favorite(setName: $setName, value: $value)';
}


}

/// @nodoc
abstract mixin class $LibraryEdit_FavoriteCopyWith<$Res> implements $LibraryEditCopyWith<$Res> {
  factory $LibraryEdit_FavoriteCopyWith(LibraryEdit_Favorite value, $Res Function(LibraryEdit_Favorite) _then) = _$LibraryEdit_FavoriteCopyWithImpl;
@useResult
$Res call({
 String setName, bool value
});




}
/// @nodoc
class _$LibraryEdit_FavoriteCopyWithImpl<$Res>
    implements $LibraryEdit_FavoriteCopyWith<$Res> {
  _$LibraryEdit_FavoriteCopyWithImpl(this._self, this._then);

  final LibraryEdit_Favorite _self;
  final $Res Function(LibraryEdit_Favorite) _then;

/// Create a copy of LibraryEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? setName = null,Object? value = null,}) {
  return _then(LibraryEdit_Favorite(
setName: null == setName ? _self.setName : setName // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class LibraryEdit_DeleteTrack extends LibraryEdit {
  const LibraryEdit_DeleteTrack(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryEdit_DeleteTrack);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'LibraryEdit.deleteTrack()';
}


}




// dart format on
