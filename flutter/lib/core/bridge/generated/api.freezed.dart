// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Change {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Change()';
}


}

/// @nodoc
class $ChangeCopyWith<$Res>  {
$ChangeCopyWith(Change _, $Res Function(Change) __);
}


/// Adds pattern-matching-related methods to [Change].
extension ChangePatterns on Change {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Change_Playback value)?  playback,TResult Function( Change_Queue value)?  queue,TResult Function( Change_Job value)?  job,TResult Function( Change_Runtime value)?  runtime,TResult Function( Change_AuthChanged value)?  authChanged,TResult Function( Change_Sync value)?  sync_,TResult Function( Change_Library value)?  library_,TResult Function( Change_Playlist value)?  playlist,TResult Function( Change_Command value)?  command,TResult Function( Change_Warning value)?  warning,TResult Function( Change_Refresh value)?  refresh,TResult Function( Change_Resync value)?  resync,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Change_Playback() when playback != null:
return playback(_that);case Change_Queue() when queue != null:
return queue(_that);case Change_Job() when job != null:
return job(_that);case Change_Runtime() when runtime != null:
return runtime(_that);case Change_AuthChanged() when authChanged != null:
return authChanged(_that);case Change_Sync() when sync_ != null:
return sync_(_that);case Change_Library() when library_ != null:
return library_(_that);case Change_Playlist() when playlist != null:
return playlist(_that);case Change_Command() when command != null:
return command(_that);case Change_Warning() when warning != null:
return warning(_that);case Change_Refresh() when refresh != null:
return refresh(_that);case Change_Resync() when resync != null:
return resync(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Change_Playback value)  playback,required TResult Function( Change_Queue value)  queue,required TResult Function( Change_Job value)  job,required TResult Function( Change_Runtime value)  runtime,required TResult Function( Change_AuthChanged value)  authChanged,required TResult Function( Change_Sync value)  sync_,required TResult Function( Change_Library value)  library_,required TResult Function( Change_Playlist value)  playlist,required TResult Function( Change_Command value)  command,required TResult Function( Change_Warning value)  warning,required TResult Function( Change_Refresh value)  refresh,required TResult Function( Change_Resync value)  resync,}){
final _that = this;
switch (_that) {
case Change_Playback():
return playback(_that);case Change_Queue():
return queue(_that);case Change_Job():
return job(_that);case Change_Runtime():
return runtime(_that);case Change_AuthChanged():
return authChanged(_that);case Change_Sync():
return sync_(_that);case Change_Library():
return library_(_that);case Change_Playlist():
return playlist(_that);case Change_Command():
return command(_that);case Change_Warning():
return warning(_that);case Change_Refresh():
return refresh(_that);case Change_Resync():
return resync(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Change_Playback value)?  playback,TResult? Function( Change_Queue value)?  queue,TResult? Function( Change_Job value)?  job,TResult? Function( Change_Runtime value)?  runtime,TResult? Function( Change_AuthChanged value)?  authChanged,TResult? Function( Change_Sync value)?  sync_,TResult? Function( Change_Library value)?  library_,TResult? Function( Change_Playlist value)?  playlist,TResult? Function( Change_Command value)?  command,TResult? Function( Change_Warning value)?  warning,TResult? Function( Change_Refresh value)?  refresh,TResult? Function( Change_Resync value)?  resync,}){
final _that = this;
switch (_that) {
case Change_Playback() when playback != null:
return playback(_that);case Change_Queue() when queue != null:
return queue(_that);case Change_Job() when job != null:
return job(_that);case Change_Runtime() when runtime != null:
return runtime(_that);case Change_AuthChanged() when authChanged != null:
return authChanged(_that);case Change_Sync() when sync_ != null:
return sync_(_that);case Change_Library() when library_ != null:
return library_(_that);case Change_Playlist() when playlist != null:
return playlist(_that);case Change_Command() when command != null:
return command(_that);case Change_Warning() when warning != null:
return warning(_that);case Change_Refresh() when refresh != null:
return refresh(_that);case Change_Resync() when resync != null:
return resync(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Playback state)?  playback,TResult Function( Queue state)?  queue,TResult Function( Job state)?  job,TResult Function( Status state)?  runtime,TResult Function()?  authChanged,TResult Function( bool running)?  sync_,TResult Function( String cursor)?  library_,TResult Function( String playlistId)?  playlist,TResult Function( Command result)?  command,TResult Function( BridgeError error)?  warning,TResult Function()?  refresh,TResult Function( String missedEvents)?  resync,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Change_Playback() when playback != null:
return playback(_that.state);case Change_Queue() when queue != null:
return queue(_that.state);case Change_Job() when job != null:
return job(_that.state);case Change_Runtime() when runtime != null:
return runtime(_that.state);case Change_AuthChanged() when authChanged != null:
return authChanged();case Change_Sync() when sync_ != null:
return sync_(_that.running);case Change_Library() when library_ != null:
return library_(_that.cursor);case Change_Playlist() when playlist != null:
return playlist(_that.playlistId);case Change_Command() when command != null:
return command(_that.result);case Change_Warning() when warning != null:
return warning(_that.error);case Change_Refresh() when refresh != null:
return refresh();case Change_Resync() when resync != null:
return resync(_that.missedEvents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Playback state)  playback,required TResult Function( Queue state)  queue,required TResult Function( Job state)  job,required TResult Function( Status state)  runtime,required TResult Function()  authChanged,required TResult Function( bool running)  sync_,required TResult Function( String cursor)  library_,required TResult Function( String playlistId)  playlist,required TResult Function( Command result)  command,required TResult Function( BridgeError error)  warning,required TResult Function()  refresh,required TResult Function( String missedEvents)  resync,}) {final _that = this;
switch (_that) {
case Change_Playback():
return playback(_that.state);case Change_Queue():
return queue(_that.state);case Change_Job():
return job(_that.state);case Change_Runtime():
return runtime(_that.state);case Change_AuthChanged():
return authChanged();case Change_Sync():
return sync_(_that.running);case Change_Library():
return library_(_that.cursor);case Change_Playlist():
return playlist(_that.playlistId);case Change_Command():
return command(_that.result);case Change_Warning():
return warning(_that.error);case Change_Refresh():
return refresh();case Change_Resync():
return resync(_that.missedEvents);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Playback state)?  playback,TResult? Function( Queue state)?  queue,TResult? Function( Job state)?  job,TResult? Function( Status state)?  runtime,TResult? Function()?  authChanged,TResult? Function( bool running)?  sync_,TResult? Function( String cursor)?  library_,TResult? Function( String playlistId)?  playlist,TResult? Function( Command result)?  command,TResult? Function( BridgeError error)?  warning,TResult? Function()?  refresh,TResult? Function( String missedEvents)?  resync,}) {final _that = this;
switch (_that) {
case Change_Playback() when playback != null:
return playback(_that.state);case Change_Queue() when queue != null:
return queue(_that.state);case Change_Job() when job != null:
return job(_that.state);case Change_Runtime() when runtime != null:
return runtime(_that.state);case Change_AuthChanged() when authChanged != null:
return authChanged();case Change_Sync() when sync_ != null:
return sync_(_that.running);case Change_Library() when library_ != null:
return library_(_that.cursor);case Change_Playlist() when playlist != null:
return playlist(_that.playlistId);case Change_Command() when command != null:
return command(_that.result);case Change_Warning() when warning != null:
return warning(_that.error);case Change_Refresh() when refresh != null:
return refresh();case Change_Resync() when resync != null:
return resync(_that.missedEvents);case _:
  return null;

}
}

}

/// @nodoc


class Change_Playback extends Change {
  const Change_Playback({required this.state}): super._();
  

 final  Playback state;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_PlaybackCopyWith<Change_Playback> get copyWith => _$Change_PlaybackCopyWithImpl<Change_Playback>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Playback&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode {
    return Object.hash(runtimeType,state);
}

@override
String toString() {
    return 'Change.playback(state: $state)';
}


}

/// @nodoc
abstract mixin class $Change_PlaybackCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_PlaybackCopyWith(Change_Playback value, $Res Function(Change_Playback) _then) = _$Change_PlaybackCopyWithImpl;
@useResult
$Res call({
 Playback state
});


$PlaybackCopyWith<$Res> get state;

}
/// @nodoc
class _$Change_PlaybackCopyWithImpl<$Res>
    implements $Change_PlaybackCopyWith<$Res> {
  _$Change_PlaybackCopyWithImpl(this._self, this._then);

  final Change_Playback _self;
  final $Res Function(Change_Playback) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? state = null,}) {
  return _then(Change_Playback(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as Playback,
  ));
}

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaybackCopyWith<$Res> get state {
  
  return $PlaybackCopyWith<$Res>(_self.state, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}

/// @nodoc


class Change_Queue extends Change {
  const Change_Queue({required this.state}): super._();
  

 final  Queue state;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_QueueCopyWith<Change_Queue> get copyWith => _$Change_QueueCopyWithImpl<Change_Queue>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Queue&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode {
    return Object.hash(runtimeType,state);
}

@override
String toString() {
    return 'Change.queue(state: $state)';
}


}

/// @nodoc
abstract mixin class $Change_QueueCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_QueueCopyWith(Change_Queue value, $Res Function(Change_Queue) _then) = _$Change_QueueCopyWithImpl;
@useResult
$Res call({
 Queue state
});




}
/// @nodoc
class _$Change_QueueCopyWithImpl<$Res>
    implements $Change_QueueCopyWith<$Res> {
  _$Change_QueueCopyWithImpl(this._self, this._then);

  final Change_Queue _self;
  final $Res Function(Change_Queue) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? state = null,}) {
  return _then(Change_Queue(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as Queue,
  ));
}


}

/// @nodoc


class Change_Job extends Change {
  const Change_Job({required this.state}): super._();
  

 final  Job state;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_JobCopyWith<Change_Job> get copyWith => _$Change_JobCopyWithImpl<Change_Job>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Job&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode {
    return Object.hash(runtimeType,state);
}

@override
String toString() {
    return 'Change.job(state: $state)';
}


}

/// @nodoc
abstract mixin class $Change_JobCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_JobCopyWith(Change_Job value, $Res Function(Change_Job) _then) = _$Change_JobCopyWithImpl;
@useResult
$Res call({
 Job state
});




}
/// @nodoc
class _$Change_JobCopyWithImpl<$Res>
    implements $Change_JobCopyWith<$Res> {
  _$Change_JobCopyWithImpl(this._self, this._then);

  final Change_Job _self;
  final $Res Function(Change_Job) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? state = null,}) {
  return _then(Change_Job(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as Job,
  ));
}


}

/// @nodoc


class Change_Runtime extends Change {
  const Change_Runtime({required this.state}): super._();
  

 final  Status state;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_RuntimeCopyWith<Change_Runtime> get copyWith => _$Change_RuntimeCopyWithImpl<Change_Runtime>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Runtime&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode {
    return Object.hash(runtimeType,state);
}

@override
String toString() {
    return 'Change.runtime(state: $state)';
}


}

/// @nodoc
abstract mixin class $Change_RuntimeCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_RuntimeCopyWith(Change_Runtime value, $Res Function(Change_Runtime) _then) = _$Change_RuntimeCopyWithImpl;
@useResult
$Res call({
 Status state
});




}
/// @nodoc
class _$Change_RuntimeCopyWithImpl<$Res>
    implements $Change_RuntimeCopyWith<$Res> {
  _$Change_RuntimeCopyWithImpl(this._self, this._then);

  final Change_Runtime _self;
  final $Res Function(Change_Runtime) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? state = null,}) {
  return _then(Change_Runtime(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as Status,
  ));
}


}

/// @nodoc


class Change_AuthChanged extends Change {
  const Change_AuthChanged(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_AuthChanged);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Change.authChanged()';
}


}




/// @nodoc


class Change_Sync extends Change {
  const Change_Sync({required this.running}): super._();
  

 final  bool running;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_SyncCopyWith<Change_Sync> get copyWith => _$Change_SyncCopyWithImpl<Change_Sync>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Sync&&(identical(other.running, running) || other.running == running));
}


@override
int get hashCode {
    return Object.hash(runtimeType,running);
}

@override
String toString() {
    return 'Change.sync_(running: $running)';
}


}

/// @nodoc
abstract mixin class $Change_SyncCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_SyncCopyWith(Change_Sync value, $Res Function(Change_Sync) _then) = _$Change_SyncCopyWithImpl;
@useResult
$Res call({
 bool running
});




}
/// @nodoc
class _$Change_SyncCopyWithImpl<$Res>
    implements $Change_SyncCopyWith<$Res> {
  _$Change_SyncCopyWithImpl(this._self, this._then);

  final Change_Sync _self;
  final $Res Function(Change_Sync) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? running = null,}) {
  return _then(Change_Sync(
running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class Change_Library extends Change {
  const Change_Library({required this.cursor}): super._();
  

 final  String cursor;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_LibraryCopyWith<Change_Library> get copyWith => _$Change_LibraryCopyWithImpl<Change_Library>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Library&&(identical(other.cursor, cursor) || other.cursor == cursor));
}


@override
int get hashCode {
    return Object.hash(runtimeType,cursor);
}

@override
String toString() {
    return 'Change.library_(cursor: $cursor)';
}


}

/// @nodoc
abstract mixin class $Change_LibraryCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_LibraryCopyWith(Change_Library value, $Res Function(Change_Library) _then) = _$Change_LibraryCopyWithImpl;
@useResult
$Res call({
 String cursor
});




}
/// @nodoc
class _$Change_LibraryCopyWithImpl<$Res>
    implements $Change_LibraryCopyWith<$Res> {
  _$Change_LibraryCopyWithImpl(this._self, this._then);

  final Change_Library _self;
  final $Res Function(Change_Library) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? cursor = null,}) {
  return _then(Change_Library(
cursor: null == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Change_Playlist extends Change {
  const Change_Playlist({required this.playlistId}): super._();
  

 final  String playlistId;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_PlaylistCopyWith<Change_Playlist> get copyWith => _$Change_PlaylistCopyWithImpl<Change_Playlist>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Playlist&&(identical(other.playlistId, playlistId) || other.playlistId == playlistId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,playlistId);
}

@override
String toString() {
    return 'Change.playlist(playlistId: $playlistId)';
}


}

/// @nodoc
abstract mixin class $Change_PlaylistCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_PlaylistCopyWith(Change_Playlist value, $Res Function(Change_Playlist) _then) = _$Change_PlaylistCopyWithImpl;
@useResult
$Res call({
 String playlistId
});




}
/// @nodoc
class _$Change_PlaylistCopyWithImpl<$Res>
    implements $Change_PlaylistCopyWith<$Res> {
  _$Change_PlaylistCopyWithImpl(this._self, this._then);

  final Change_Playlist _self;
  final $Res Function(Change_Playlist) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? playlistId = null,}) {
  return _then(Change_Playlist(
playlistId: null == playlistId ? _self.playlistId : playlistId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Change_Command extends Change {
  const Change_Command({required this.result}): super._();
  

 final  Command result;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_CommandCopyWith<Change_Command> get copyWith => _$Change_CommandCopyWithImpl<Change_Command>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Command&&(identical(other.result, result) || other.result == result));
}


@override
int get hashCode {
    return Object.hash(runtimeType,result);
}

@override
String toString() {
    return 'Change.command(result: $result)';
}


}

/// @nodoc
abstract mixin class $Change_CommandCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_CommandCopyWith(Change_Command value, $Res Function(Change_Command) _then) = _$Change_CommandCopyWithImpl;
@useResult
$Res call({
 Command result
});




}
/// @nodoc
class _$Change_CommandCopyWithImpl<$Res>
    implements $Change_CommandCopyWith<$Res> {
  _$Change_CommandCopyWithImpl(this._self, this._then);

  final Change_Command _self;
  final $Res Function(Change_Command) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? result = null,}) {
  return _then(Change_Command(
result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as Command,
  ));
}


}

/// @nodoc


class Change_Warning extends Change {
  const Change_Warning({required this.error}): super._();
  

 final  BridgeError error;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_WarningCopyWith<Change_Warning> get copyWith => _$Change_WarningCopyWithImpl<Change_Warning>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Warning&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,error);
}

@override
String toString() {
    return 'Change.warning(error: $error)';
}


}

/// @nodoc
abstract mixin class $Change_WarningCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_WarningCopyWith(Change_Warning value, $Res Function(Change_Warning) _then) = _$Change_WarningCopyWithImpl;
@useResult
$Res call({
 BridgeError error
});




}
/// @nodoc
class _$Change_WarningCopyWithImpl<$Res>
    implements $Change_WarningCopyWith<$Res> {
  _$Change_WarningCopyWithImpl(this._self, this._then);

  final Change_Warning _self;
  final $Res Function(Change_Warning) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(Change_Warning(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as BridgeError,
  ));
}


}

/// @nodoc


class Change_Refresh extends Change {
  const Change_Refresh(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Refresh);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Change.refresh()';
}


}




/// @nodoc


class Change_Resync extends Change {
  const Change_Resync({required this.missedEvents}): super._();
  

 final  String missedEvents;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Change_ResyncCopyWith<Change_Resync> get copyWith => _$Change_ResyncCopyWithImpl<Change_Resync>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Change_Resync&&(identical(other.missedEvents, missedEvents) || other.missedEvents == missedEvents));
}


@override
int get hashCode {
    return Object.hash(runtimeType,missedEvents);
}

@override
String toString() {
    return 'Change.resync(missedEvents: $missedEvents)';
}


}

/// @nodoc
abstract mixin class $Change_ResyncCopyWith<$Res> implements $ChangeCopyWith<$Res> {
  factory $Change_ResyncCopyWith(Change_Resync value, $Res Function(Change_Resync) _then) = _$Change_ResyncCopyWithImpl;
@useResult
$Res call({
 String missedEvents
});




}
/// @nodoc
class _$Change_ResyncCopyWithImpl<$Res>
    implements $Change_ResyncCopyWith<$Res> {
  _$Change_ResyncCopyWithImpl(this._self, this._then);

  final Change_Resync _self;
  final $Res Function(Change_Resync) _then;

/// Create a copy of Change
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? missedEvents = null,}) {
  return _then(Change_Resync(
missedEvents: null == missedEvents ? _self.missedEvents : missedEvents // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$Playback {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Playback);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Playback()';
}


}

/// @nodoc
class $PlaybackCopyWith<$Res>  {
$PlaybackCopyWith(Playback _, $Res Function(Playback) __);
}


/// Adds pattern-matching-related methods to [Playback].
extension PlaybackPatterns on Playback {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Playback_Idle value)?  idle,TResult Function( Playback_Ended value)?  ended,TResult Function( Playback_Buffering value)?  buffering,TResult Function( Playback_Playing value)?  playing,TResult Function( Playback_Paused value)?  paused,TResult Function( Playback_Failed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Playback_Idle() when idle != null:
return idle(_that);case Playback_Ended() when ended != null:
return ended(_that);case Playback_Buffering() when buffering != null:
return buffering(_that);case Playback_Playing() when playing != null:
return playing(_that);case Playback_Paused() when paused != null:
return paused(_that);case Playback_Failed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Playback_Idle value)  idle,required TResult Function( Playback_Ended value)  ended,required TResult Function( Playback_Buffering value)  buffering,required TResult Function( Playback_Playing value)  playing,required TResult Function( Playback_Paused value)  paused,required TResult Function( Playback_Failed value)  failed,}){
final _that = this;
switch (_that) {
case Playback_Idle():
return idle(_that);case Playback_Ended():
return ended(_that);case Playback_Buffering():
return buffering(_that);case Playback_Playing():
return playing(_that);case Playback_Paused():
return paused(_that);case Playback_Failed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Playback_Idle value)?  idle,TResult? Function( Playback_Ended value)?  ended,TResult? Function( Playback_Buffering value)?  buffering,TResult? Function( Playback_Playing value)?  playing,TResult? Function( Playback_Paused value)?  paused,TResult? Function( Playback_Failed value)?  failed,}){
final _that = this;
switch (_that) {
case Playback_Idle() when idle != null:
return idle(_that);case Playback_Ended() when ended != null:
return ended(_that);case Playback_Buffering() when buffering != null:
return buffering(_that);case Playback_Playing() when playing != null:
return playing(_that);case Playback_Paused() when paused != null:
return paused(_that);case Playback_Failed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( String trackId)?  ended,TResult Function( String trackId,  BigInt positionMs,  BigInt durationMs)?  buffering,TResult Function( String trackId,  BigInt positionMs,  BigInt durationMs)?  playing,TResult Function( String trackId,  BigInt positionMs,  BigInt durationMs)?  paused,TResult Function( String? trackId,  String code)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Playback_Idle() when idle != null:
return idle();case Playback_Ended() when ended != null:
return ended(_that.trackId);case Playback_Buffering() when buffering != null:
return buffering(_that.trackId,_that.positionMs,_that.durationMs);case Playback_Playing() when playing != null:
return playing(_that.trackId,_that.positionMs,_that.durationMs);case Playback_Paused() when paused != null:
return paused(_that.trackId,_that.positionMs,_that.durationMs);case Playback_Failed() when failed != null:
return failed(_that.trackId,_that.code);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( String trackId)  ended,required TResult Function( String trackId,  BigInt positionMs,  BigInt durationMs)  buffering,required TResult Function( String trackId,  BigInt positionMs,  BigInt durationMs)  playing,required TResult Function( String trackId,  BigInt positionMs,  BigInt durationMs)  paused,required TResult Function( String? trackId,  String code)  failed,}) {final _that = this;
switch (_that) {
case Playback_Idle():
return idle();case Playback_Ended():
return ended(_that.trackId);case Playback_Buffering():
return buffering(_that.trackId,_that.positionMs,_that.durationMs);case Playback_Playing():
return playing(_that.trackId,_that.positionMs,_that.durationMs);case Playback_Paused():
return paused(_that.trackId,_that.positionMs,_that.durationMs);case Playback_Failed():
return failed(_that.trackId,_that.code);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( String trackId)?  ended,TResult? Function( String trackId,  BigInt positionMs,  BigInt durationMs)?  buffering,TResult? Function( String trackId,  BigInt positionMs,  BigInt durationMs)?  playing,TResult? Function( String trackId,  BigInt positionMs,  BigInt durationMs)?  paused,TResult? Function( String? trackId,  String code)?  failed,}) {final _that = this;
switch (_that) {
case Playback_Idle() when idle != null:
return idle();case Playback_Ended() when ended != null:
return ended(_that.trackId);case Playback_Buffering() when buffering != null:
return buffering(_that.trackId,_that.positionMs,_that.durationMs);case Playback_Playing() when playing != null:
return playing(_that.trackId,_that.positionMs,_that.durationMs);case Playback_Paused() when paused != null:
return paused(_that.trackId,_that.positionMs,_that.durationMs);case Playback_Failed() when failed != null:
return failed(_that.trackId,_that.code);case _:
  return null;

}
}

}

/// @nodoc


class Playback_Idle extends Playback {
  const Playback_Idle(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Playback_Idle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Playback.idle()';
}


}




/// @nodoc


class Playback_Ended extends Playback {
  const Playback_Ended({required this.trackId}): super._();
  

 final  String trackId;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Playback_EndedCopyWith<Playback_Ended> get copyWith => _$Playback_EndedCopyWithImpl<Playback_Ended>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Playback_Ended&&(identical(other.trackId, trackId) || other.trackId == trackId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,trackId);
}

@override
String toString() {
    return 'Playback.ended(trackId: $trackId)';
}


}

/// @nodoc
abstract mixin class $Playback_EndedCopyWith<$Res> implements $PlaybackCopyWith<$Res> {
  factory $Playback_EndedCopyWith(Playback_Ended value, $Res Function(Playback_Ended) _then) = _$Playback_EndedCopyWithImpl;
@useResult
$Res call({
 String trackId
});




}
/// @nodoc
class _$Playback_EndedCopyWithImpl<$Res>
    implements $Playback_EndedCopyWith<$Res> {
  _$Playback_EndedCopyWithImpl(this._self, this._then);

  final Playback_Ended _self;
  final $Res Function(Playback_Ended) _then;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,}) {
  return _then(Playback_Ended(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Playback_Buffering extends Playback {
  const Playback_Buffering({required this.trackId, required this.positionMs, required this.durationMs}): super._();
  

 final  String trackId;
 final  BigInt positionMs;
 final  BigInt durationMs;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Playback_BufferingCopyWith<Playback_Buffering> get copyWith => _$Playback_BufferingCopyWithImpl<Playback_Buffering>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Playback_Buffering&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,trackId,positionMs,durationMs);
}

@override
String toString() {
    return 'Playback.buffering(trackId: $trackId, positionMs: $positionMs, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class $Playback_BufferingCopyWith<$Res> implements $PlaybackCopyWith<$Res> {
  factory $Playback_BufferingCopyWith(Playback_Buffering value, $Res Function(Playback_Buffering) _then) = _$Playback_BufferingCopyWithImpl;
@useResult
$Res call({
 String trackId, BigInt positionMs, BigInt durationMs
});




}
/// @nodoc
class _$Playback_BufferingCopyWithImpl<$Res>
    implements $Playback_BufferingCopyWith<$Res> {
  _$Playback_BufferingCopyWithImpl(this._self, this._then);

  final Playback_Buffering _self;
  final $Res Function(Playback_Buffering) _then;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? positionMs = null,Object? durationMs = null,}) {
  return _then(Playback_Buffering(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,positionMs: null == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as BigInt,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class Playback_Playing extends Playback {
  const Playback_Playing({required this.trackId, required this.positionMs, required this.durationMs}): super._();
  

 final  String trackId;
 final  BigInt positionMs;
 final  BigInt durationMs;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Playback_PlayingCopyWith<Playback_Playing> get copyWith => _$Playback_PlayingCopyWithImpl<Playback_Playing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Playback_Playing&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,trackId,positionMs,durationMs);
}

@override
String toString() {
    return 'Playback.playing(trackId: $trackId, positionMs: $positionMs, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class $Playback_PlayingCopyWith<$Res> implements $PlaybackCopyWith<$Res> {
  factory $Playback_PlayingCopyWith(Playback_Playing value, $Res Function(Playback_Playing) _then) = _$Playback_PlayingCopyWithImpl;
@useResult
$Res call({
 String trackId, BigInt positionMs, BigInt durationMs
});




}
/// @nodoc
class _$Playback_PlayingCopyWithImpl<$Res>
    implements $Playback_PlayingCopyWith<$Res> {
  _$Playback_PlayingCopyWithImpl(this._self, this._then);

  final Playback_Playing _self;
  final $Res Function(Playback_Playing) _then;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? positionMs = null,Object? durationMs = null,}) {
  return _then(Playback_Playing(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,positionMs: null == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as BigInt,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class Playback_Paused extends Playback {
  const Playback_Paused({required this.trackId, required this.positionMs, required this.durationMs}): super._();
  

 final  String trackId;
 final  BigInt positionMs;
 final  BigInt durationMs;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Playback_PausedCopyWith<Playback_Paused> get copyWith => _$Playback_PausedCopyWithImpl<Playback_Paused>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Playback_Paused&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,trackId,positionMs,durationMs);
}

@override
String toString() {
    return 'Playback.paused(trackId: $trackId, positionMs: $positionMs, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class $Playback_PausedCopyWith<$Res> implements $PlaybackCopyWith<$Res> {
  factory $Playback_PausedCopyWith(Playback_Paused value, $Res Function(Playback_Paused) _then) = _$Playback_PausedCopyWithImpl;
@useResult
$Res call({
 String trackId, BigInt positionMs, BigInt durationMs
});




}
/// @nodoc
class _$Playback_PausedCopyWithImpl<$Res>
    implements $Playback_PausedCopyWith<$Res> {
  _$Playback_PausedCopyWithImpl(this._self, this._then);

  final Playback_Paused _self;
  final $Res Function(Playback_Paused) _then;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? positionMs = null,Object? durationMs = null,}) {
  return _then(Playback_Paused(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,positionMs: null == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as BigInt,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class Playback_Failed extends Playback {
  const Playback_Failed({this.trackId, required this.code}): super._();
  

 final  String? trackId;
 final  String code;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Playback_FailedCopyWith<Playback_Failed> get copyWith => _$Playback_FailedCopyWithImpl<Playback_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Playback_Failed&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,trackId,code);
}

@override
String toString() {
    return 'Playback.failed(trackId: $trackId, code: $code)';
}


}

/// @nodoc
abstract mixin class $Playback_FailedCopyWith<$Res> implements $PlaybackCopyWith<$Res> {
  factory $Playback_FailedCopyWith(Playback_Failed value, $Res Function(Playback_Failed) _then) = _$Playback_FailedCopyWithImpl;
@useResult
$Res call({
 String? trackId, String code
});




}
/// @nodoc
class _$Playback_FailedCopyWithImpl<$Res>
    implements $Playback_FailedCopyWith<$Res> {
  _$Playback_FailedCopyWithImpl(this._self, this._then);

  final Playback_Failed _self;
  final $Res Function(Playback_Failed) _then;

/// Create a copy of Playback
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = freezed,Object? code = null,}) {
  return _then(Playback_Failed(
trackId: freezed == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String?,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$QueueEdit {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QueueEdit);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'QueueEdit()';
}


}

/// @nodoc
class $QueueEditCopyWith<$Res>  {
$QueueEditCopyWith(QueueEdit _, $Res Function(QueueEdit) __);
}


/// Adds pattern-matching-related methods to [QueueEdit].
extension QueueEditPatterns on QueueEdit {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( QueueEdit_Append value)?  append,TResult Function( QueueEdit_Remove value)?  remove,TResult Function( QueueEdit_Move value)?  move,TResult Function( QueueEdit_Jump value)?  jump,TResult Function( QueueEdit_Shuffle value)?  shuffle,TResult Function( QueueEdit_Repeat value)?  repeat,required TResult orElse(),}){
final _that = this;
switch (_that) {
case QueueEdit_Append() when append != null:
return append(_that);case QueueEdit_Remove() when remove != null:
return remove(_that);case QueueEdit_Move() when move != null:
return move(_that);case QueueEdit_Jump() when jump != null:
return jump(_that);case QueueEdit_Shuffle() when shuffle != null:
return shuffle(_that);case QueueEdit_Repeat() when repeat != null:
return repeat(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( QueueEdit_Append value)  append,required TResult Function( QueueEdit_Remove value)  remove,required TResult Function( QueueEdit_Move value)  move,required TResult Function( QueueEdit_Jump value)  jump,required TResult Function( QueueEdit_Shuffle value)  shuffle,required TResult Function( QueueEdit_Repeat value)  repeat,}){
final _that = this;
switch (_that) {
case QueueEdit_Append():
return append(_that);case QueueEdit_Remove():
return remove(_that);case QueueEdit_Move():
return move(_that);case QueueEdit_Jump():
return jump(_that);case QueueEdit_Shuffle():
return shuffle(_that);case QueueEdit_Repeat():
return repeat(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( QueueEdit_Append value)?  append,TResult? Function( QueueEdit_Remove value)?  remove,TResult? Function( QueueEdit_Move value)?  move,TResult? Function( QueueEdit_Jump value)?  jump,TResult? Function( QueueEdit_Shuffle value)?  shuffle,TResult? Function( QueueEdit_Repeat value)?  repeat,}){
final _that = this;
switch (_that) {
case QueueEdit_Append() when append != null:
return append(_that);case QueueEdit_Remove() when remove != null:
return remove(_that);case QueueEdit_Move() when move != null:
return move(_that);case QueueEdit_Jump() when jump != null:
return jump(_that);case QueueEdit_Shuffle() when shuffle != null:
return shuffle(_that);case QueueEdit_Repeat() when repeat != null:
return repeat(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<String> trackIds,  bool next)?  append,TResult Function( int index)?  remove,TResult Function( int from,  int to)?  move,TResult Function( int index)?  jump,TResult Function( bool enabled)?  shuffle,TResult Function( Repeat mode)?  repeat,required TResult orElse(),}) {final _that = this;
switch (_that) {
case QueueEdit_Append() when append != null:
return append(_that.trackIds,_that.next);case QueueEdit_Remove() when remove != null:
return remove(_that.index);case QueueEdit_Move() when move != null:
return move(_that.from,_that.to);case QueueEdit_Jump() when jump != null:
return jump(_that.index);case QueueEdit_Shuffle() when shuffle != null:
return shuffle(_that.enabled);case QueueEdit_Repeat() when repeat != null:
return repeat(_that.mode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<String> trackIds,  bool next)  append,required TResult Function( int index)  remove,required TResult Function( int from,  int to)  move,required TResult Function( int index)  jump,required TResult Function( bool enabled)  shuffle,required TResult Function( Repeat mode)  repeat,}) {final _that = this;
switch (_that) {
case QueueEdit_Append():
return append(_that.trackIds,_that.next);case QueueEdit_Remove():
return remove(_that.index);case QueueEdit_Move():
return move(_that.from,_that.to);case QueueEdit_Jump():
return jump(_that.index);case QueueEdit_Shuffle():
return shuffle(_that.enabled);case QueueEdit_Repeat():
return repeat(_that.mode);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<String> trackIds,  bool next)?  append,TResult? Function( int index)?  remove,TResult? Function( int from,  int to)?  move,TResult? Function( int index)?  jump,TResult? Function( bool enabled)?  shuffle,TResult? Function( Repeat mode)?  repeat,}) {final _that = this;
switch (_that) {
case QueueEdit_Append() when append != null:
return append(_that.trackIds,_that.next);case QueueEdit_Remove() when remove != null:
return remove(_that.index);case QueueEdit_Move() when move != null:
return move(_that.from,_that.to);case QueueEdit_Jump() when jump != null:
return jump(_that.index);case QueueEdit_Shuffle() when shuffle != null:
return shuffle(_that.enabled);case QueueEdit_Repeat() when repeat != null:
return repeat(_that.mode);case _:
  return null;

}
}

}

/// @nodoc


class QueueEdit_Append extends QueueEdit {
  const QueueEdit_Append({required  List<String> trackIds, required this.next}): _trackIds = trackIds,super._();
  

 final  List<String> _trackIds;
 List<String> get trackIds {
  if (_trackIds is EqualUnmodifiableListView) return _trackIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trackIds);
}

 final  bool next;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueueEdit_AppendCopyWith<QueueEdit_Append> get copyWith => _$QueueEdit_AppendCopyWithImpl<QueueEdit_Append>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QueueEdit_Append&&const DeepCollectionEquality().equals(other.trackIds, _trackIds)&&(identical(other.next, next) || other.next == next));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_trackIds),next);
}

@override
String toString() {
    return 'QueueEdit.append(trackIds: $trackIds, next: $next)';
}


}

/// @nodoc
abstract mixin class $QueueEdit_AppendCopyWith<$Res> implements $QueueEditCopyWith<$Res> {
  factory $QueueEdit_AppendCopyWith(QueueEdit_Append value, $Res Function(QueueEdit_Append) _then) = _$QueueEdit_AppendCopyWithImpl;
@useResult
$Res call({
 List<String> trackIds, bool next
});




}
/// @nodoc
class _$QueueEdit_AppendCopyWithImpl<$Res>
    implements $QueueEdit_AppendCopyWith<$Res> {
  _$QueueEdit_AppendCopyWithImpl(this._self, this._then);

  final QueueEdit_Append _self;
  final $Res Function(QueueEdit_Append) _then;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackIds = null,Object? next = null,}) {
  return _then(QueueEdit_Append(
trackIds: null == trackIds ? _self._trackIds : trackIds // ignore: cast_nullable_to_non_nullable
as List<String>,next: null == next ? _self.next : next // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class QueueEdit_Remove extends QueueEdit {
  const QueueEdit_Remove({required this.index}): super._();
  

 final  int index;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueueEdit_RemoveCopyWith<QueueEdit_Remove> get copyWith => _$QueueEdit_RemoveCopyWithImpl<QueueEdit_Remove>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QueueEdit_Remove&&(identical(other.index, index) || other.index == index));
}


@override
int get hashCode {
    return Object.hash(runtimeType,index);
}

@override
String toString() {
    return 'QueueEdit.remove(index: $index)';
}


}

/// @nodoc
abstract mixin class $QueueEdit_RemoveCopyWith<$Res> implements $QueueEditCopyWith<$Res> {
  factory $QueueEdit_RemoveCopyWith(QueueEdit_Remove value, $Res Function(QueueEdit_Remove) _then) = _$QueueEdit_RemoveCopyWithImpl;
@useResult
$Res call({
 int index
});




}
/// @nodoc
class _$QueueEdit_RemoveCopyWithImpl<$Res>
    implements $QueueEdit_RemoveCopyWith<$Res> {
  _$QueueEdit_RemoveCopyWithImpl(this._self, this._then);

  final QueueEdit_Remove _self;
  final $Res Function(QueueEdit_Remove) _then;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? index = null,}) {
  return _then(QueueEdit_Remove(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class QueueEdit_Move extends QueueEdit {
  const QueueEdit_Move({required this.from, required this.to}): super._();
  

 final  int from;
 final  int to;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueueEdit_MoveCopyWith<QueueEdit_Move> get copyWith => _$QueueEdit_MoveCopyWithImpl<QueueEdit_Move>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QueueEdit_Move&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to));
}


@override
int get hashCode {
    return Object.hash(runtimeType,from,to);
}

@override
String toString() {
    return 'QueueEdit.move(from: $from, to: $to)';
}


}

/// @nodoc
abstract mixin class $QueueEdit_MoveCopyWith<$Res> implements $QueueEditCopyWith<$Res> {
  factory $QueueEdit_MoveCopyWith(QueueEdit_Move value, $Res Function(QueueEdit_Move) _then) = _$QueueEdit_MoveCopyWithImpl;
@useResult
$Res call({
 int from, int to
});




}
/// @nodoc
class _$QueueEdit_MoveCopyWithImpl<$Res>
    implements $QueueEdit_MoveCopyWith<$Res> {
  _$QueueEdit_MoveCopyWithImpl(this._self, this._then);

  final QueueEdit_Move _self;
  final $Res Function(QueueEdit_Move) _then;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? from = null,Object? to = null,}) {
  return _then(QueueEdit_Move(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as int,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class QueueEdit_Jump extends QueueEdit {
  const QueueEdit_Jump({required this.index}): super._();
  

 final  int index;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueueEdit_JumpCopyWith<QueueEdit_Jump> get copyWith => _$QueueEdit_JumpCopyWithImpl<QueueEdit_Jump>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QueueEdit_Jump&&(identical(other.index, index) || other.index == index));
}


@override
int get hashCode {
    return Object.hash(runtimeType,index);
}

@override
String toString() {
    return 'QueueEdit.jump(index: $index)';
}


}

/// @nodoc
abstract mixin class $QueueEdit_JumpCopyWith<$Res> implements $QueueEditCopyWith<$Res> {
  factory $QueueEdit_JumpCopyWith(QueueEdit_Jump value, $Res Function(QueueEdit_Jump) _then) = _$QueueEdit_JumpCopyWithImpl;
@useResult
$Res call({
 int index
});




}
/// @nodoc
class _$QueueEdit_JumpCopyWithImpl<$Res>
    implements $QueueEdit_JumpCopyWith<$Res> {
  _$QueueEdit_JumpCopyWithImpl(this._self, this._then);

  final QueueEdit_Jump _self;
  final $Res Function(QueueEdit_Jump) _then;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? index = null,}) {
  return _then(QueueEdit_Jump(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class QueueEdit_Shuffle extends QueueEdit {
  const QueueEdit_Shuffle({required this.enabled}): super._();
  

 final  bool enabled;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueueEdit_ShuffleCopyWith<QueueEdit_Shuffle> get copyWith => _$QueueEdit_ShuffleCopyWithImpl<QueueEdit_Shuffle>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QueueEdit_Shuffle&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode {
    return Object.hash(runtimeType,enabled);
}

@override
String toString() {
    return 'QueueEdit.shuffle(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $QueueEdit_ShuffleCopyWith<$Res> implements $QueueEditCopyWith<$Res> {
  factory $QueueEdit_ShuffleCopyWith(QueueEdit_Shuffle value, $Res Function(QueueEdit_Shuffle) _then) = _$QueueEdit_ShuffleCopyWithImpl;
@useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class _$QueueEdit_ShuffleCopyWithImpl<$Res>
    implements $QueueEdit_ShuffleCopyWith<$Res> {
  _$QueueEdit_ShuffleCopyWithImpl(this._self, this._then);

  final QueueEdit_Shuffle _self;
  final $Res Function(QueueEdit_Shuffle) _then;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? enabled = null,}) {
  return _then(QueueEdit_Shuffle(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class QueueEdit_Repeat extends QueueEdit {
  const QueueEdit_Repeat({required this.mode}): super._();
  

 final  Repeat mode;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueueEdit_RepeatCopyWith<QueueEdit_Repeat> get copyWith => _$QueueEdit_RepeatCopyWithImpl<QueueEdit_Repeat>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QueueEdit_Repeat&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mode);
}

@override
String toString() {
    return 'QueueEdit.repeat(mode: $mode)';
}


}

/// @nodoc
abstract mixin class $QueueEdit_RepeatCopyWith<$Res> implements $QueueEditCopyWith<$Res> {
  factory $QueueEdit_RepeatCopyWith(QueueEdit_Repeat value, $Res Function(QueueEdit_Repeat) _then) = _$QueueEdit_RepeatCopyWithImpl;
@useResult
$Res call({
 Repeat mode
});




}
/// @nodoc
class _$QueueEdit_RepeatCopyWithImpl<$Res>
    implements $QueueEdit_RepeatCopyWith<$Res> {
  _$QueueEdit_RepeatCopyWithImpl(this._self, this._then);

  final QueueEdit_Repeat _self;
  final $Res Function(QueueEdit_Repeat) _then;

/// Create a copy of QueueEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mode = null,}) {
  return _then(QueueEdit_Repeat(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as Repeat,
  ));
}


}

/// @nodoc
mixin _$Transport {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Transport);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Transport()';
}


}

/// @nodoc
class $TransportCopyWith<$Res>  {
$TransportCopyWith(Transport _, $Res Function(Transport) __);
}


/// Adds pattern-matching-related methods to [Transport].
extension TransportPatterns on Transport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Transport_Pause value)?  pause,TResult Function( Transport_Resume value)?  resume,TResult Function( Transport_Stop value)?  stop,TResult Function( Transport_Next value)?  next,TResult Function( Transport_Previous value)?  previous,TResult Function( Transport_Seek value)?  seek,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Transport_Pause() when pause != null:
return pause(_that);case Transport_Resume() when resume != null:
return resume(_that);case Transport_Stop() when stop != null:
return stop(_that);case Transport_Next() when next != null:
return next(_that);case Transport_Previous() when previous != null:
return previous(_that);case Transport_Seek() when seek != null:
return seek(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Transport_Pause value)  pause,required TResult Function( Transport_Resume value)  resume,required TResult Function( Transport_Stop value)  stop,required TResult Function( Transport_Next value)  next,required TResult Function( Transport_Previous value)  previous,required TResult Function( Transport_Seek value)  seek,}){
final _that = this;
switch (_that) {
case Transport_Pause():
return pause(_that);case Transport_Resume():
return resume(_that);case Transport_Stop():
return stop(_that);case Transport_Next():
return next(_that);case Transport_Previous():
return previous(_that);case Transport_Seek():
return seek(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Transport_Pause value)?  pause,TResult? Function( Transport_Resume value)?  resume,TResult? Function( Transport_Stop value)?  stop,TResult? Function( Transport_Next value)?  next,TResult? Function( Transport_Previous value)?  previous,TResult? Function( Transport_Seek value)?  seek,}){
final _that = this;
switch (_that) {
case Transport_Pause() when pause != null:
return pause(_that);case Transport_Resume() when resume != null:
return resume(_that);case Transport_Stop() when stop != null:
return stop(_that);case Transport_Next() when next != null:
return next(_that);case Transport_Previous() when previous != null:
return previous(_that);case Transport_Seek() when seek != null:
return seek(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  pause,TResult Function()?  resume,TResult Function()?  stop,TResult Function()?  next,TResult Function()?  previous,TResult Function( BigInt milliseconds)?  seek,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Transport_Pause() when pause != null:
return pause();case Transport_Resume() when resume != null:
return resume();case Transport_Stop() when stop != null:
return stop();case Transport_Next() when next != null:
return next();case Transport_Previous() when previous != null:
return previous();case Transport_Seek() when seek != null:
return seek(_that.milliseconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  pause,required TResult Function()  resume,required TResult Function()  stop,required TResult Function()  next,required TResult Function()  previous,required TResult Function( BigInt milliseconds)  seek,}) {final _that = this;
switch (_that) {
case Transport_Pause():
return pause();case Transport_Resume():
return resume();case Transport_Stop():
return stop();case Transport_Next():
return next();case Transport_Previous():
return previous();case Transport_Seek():
return seek(_that.milliseconds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  pause,TResult? Function()?  resume,TResult? Function()?  stop,TResult? Function()?  next,TResult? Function()?  previous,TResult? Function( BigInt milliseconds)?  seek,}) {final _that = this;
switch (_that) {
case Transport_Pause() when pause != null:
return pause();case Transport_Resume() when resume != null:
return resume();case Transport_Stop() when stop != null:
return stop();case Transport_Next() when next != null:
return next();case Transport_Previous() when previous != null:
return previous();case Transport_Seek() when seek != null:
return seek(_that.milliseconds);case _:
  return null;

}
}

}

/// @nodoc


class Transport_Pause extends Transport {
  const Transport_Pause(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Transport_Pause);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Transport.pause()';
}


}




/// @nodoc


class Transport_Resume extends Transport {
  const Transport_Resume(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Transport_Resume);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Transport.resume()';
}


}




/// @nodoc


class Transport_Stop extends Transport {
  const Transport_Stop(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Transport_Stop);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Transport.stop()';
}


}




/// @nodoc


class Transport_Next extends Transport {
  const Transport_Next(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Transport_Next);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Transport.next()';
}


}




/// @nodoc


class Transport_Previous extends Transport {
  const Transport_Previous(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Transport_Previous);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Transport.previous()';
}


}




/// @nodoc


class Transport_Seek extends Transport {
  const Transport_Seek({required this.milliseconds}): super._();
  

 final  BigInt milliseconds;

/// Create a copy of Transport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Transport_SeekCopyWith<Transport_Seek> get copyWith => _$Transport_SeekCopyWithImpl<Transport_Seek>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Transport_Seek&&(identical(other.milliseconds, milliseconds) || other.milliseconds == milliseconds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,milliseconds);
}

@override
String toString() {
    return 'Transport.seek(milliseconds: $milliseconds)';
}


}

/// @nodoc
abstract mixin class $Transport_SeekCopyWith<$Res> implements $TransportCopyWith<$Res> {
  factory $Transport_SeekCopyWith(Transport_Seek value, $Res Function(Transport_Seek) _then) = _$Transport_SeekCopyWithImpl;
@useResult
$Res call({
 BigInt milliseconds
});




}
/// @nodoc
class _$Transport_SeekCopyWithImpl<$Res>
    implements $Transport_SeekCopyWith<$Res> {
  _$Transport_SeekCopyWithImpl(this._self, this._then);

  final Transport_Seek _self;
  final $Res Function(Transport_Seek) _then;

/// Create a copy of Transport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? milliseconds = null,}) {
  return _then(Transport_Seek(
milliseconds: null == milliseconds ? _self.milliseconds : milliseconds // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

// dart format on
