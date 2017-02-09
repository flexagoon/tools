// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'common.dart';
import 'events.dart';
import 'recording_directory.dart';
import 'recording_file.dart';
import 'recording_file_system_entity.dart';
import 'recording_io_sink.dart';
import 'recording_link.dart';
import 'recording_random_access_file.dart';
import 'replay_proxy_mixin.dart';
import 'result_reference.dart';

/// Encodes an object into a JSON-ready representation.
///
/// Must return one of {number, boolean, string, null, list, or map}.
typedef dynamic _Encoder(dynamic object);

/// Known encoders. Types not covered here will be encoded using
/// [_encodeDefault].
///
/// When encoding an object, we will walk this map in iteration order looking
/// for a matching encoder. Thus, when there are two encoders that match an
//  object, the first one will win.
const Map<TypeMatcher<dynamic>, _Encoder> _kEncoders =
    const <TypeMatcher<dynamic>, _Encoder>{
  const TypeMatcher<num>(): _encodeRaw,
  const TypeMatcher<bool>(): _encodeRaw,
  const TypeMatcher<String>(): _encodeRaw,
  const TypeMatcher<Null>(): _encodeRaw,
  const TypeMatcher<Iterable<dynamic>>(): _encodeIterable,
  const TypeMatcher<Map<dynamic, dynamic>>(): _encodeMap,
  const TypeMatcher<Symbol>(): getSymbolName,
  const TypeMatcher<DateTime>(): _encodeDateTime,
  const TypeMatcher<Uri>(): _encodeUri,
  const TypeMatcher<p.Context>(): _encodePathContext,
  const TypeMatcher<ResultReference<dynamic>>(): _encodeResultReference,
  const TypeMatcher<LiveInvocationEvent<dynamic>>(): _encodeEvent,
  const TypeMatcher<FileSystem>(): _encodeFileSystem,
  const TypeMatcher<RecordingDirectory>(): _encodeFileSystemEntity,
  const TypeMatcher<RecordingFile>(): _encodeFileSystemEntity,
  const TypeMatcher<RecordingLink>(): _encodeFileSystemEntity,
  const TypeMatcher<RecordingIOSink>(): _encodeIOSink,
  const TypeMatcher<RecordingRandomAccessFile>(): _encodeRandomAccessFile,
  const TypeMatcher<ReplayProxyMixin>(): _encodeReplayEntity,
  const TypeMatcher<Encoding>(): _encodeEncoding,
  const TypeMatcher<FileMode>(): _encodeFileMode,
  const TypeMatcher<FileStat>(): _encodeFileStat,
  const TypeMatcher<FileSystemEntityType>(): _encodeFileSystemEntityType,
  const TypeMatcher<FileSystemEvent>(): _encodeFileSystemEvent,
};

/// Encodes an arbitrary [object] into a JSON-ready representation (a number,
/// boolean, string, null, list, or map).
///
/// Returns a value suitable for conversion into JSON using [JsonEncoder]
/// without the need for a `toEncodable` argument.
dynamic encode(dynamic object) {
  _Encoder encoder = _encodeDefault;
  for (TypeMatcher<dynamic> matcher in _kEncoders.keys) {
    if (matcher.matches(object)) {
      encoder = _kEncoders[matcher];
      break;
    }
  }
  return encoder(object);
}

/// Default encoder (used for types not covered in [_kEncoders]).
String _encodeDefault(dynamic object) => object.runtimeType.toString();

/// Pass-through encoder (used on `num`, `bool`, `String`, and `Null`).
dynamic _encodeRaw(dynamic object) => object;

/// Encodes the specified [iterable] into a JSON-ready list of encoded items.
List<dynamic> _encodeIterable(Iterable<dynamic> iterable) {
  List<dynamic> encoded = <dynamic>[];
  for (dynamic element in iterable) {
    encoded.add(encode(element));
  }
  return encoded;
}

/// Encodes the specified [map] into a JSON-ready map of encoded key/value
/// pairs.
Map<String, dynamic> _encodeMap(Map<dynamic, dynamic> map) {
  Map<String, dynamic> encoded = <String, dynamic>{};
  for (dynamic key in map.keys) {
    String encodedKey = encode(key);
    encoded[encodedKey] = encode(map[key]);
  }
  return encoded;
}

int _encodeDateTime(DateTime dateTime) => dateTime.millisecondsSinceEpoch;

String _encodeUri(Uri uri) => uri.toString();

Map<String, String> _encodePathContext(p.Context context) {
  return <String, String>{
    'style': context.style.name,
    'cwd': context.current,
  };
}

dynamic _encodeResultReference(ResultReference<dynamic> reference) =>
    reference.serializedValue;

Map<String, dynamic> _encodeEvent(LiveInvocationEvent<dynamic> event) =>
    event.serialize();

String _encodeFileSystem(FileSystem fs) => kFileSystemEncodedValue;

/// Encodes a file system entity by using its `uid` as a reference identifier.
/// During replay, this allows us to tie the return value of of one event to
/// the object of another.
String _encodeFileSystemEntity(
    RecordingFileSystemEntity<FileSystemEntity> entity) {
  return '${entity.runtimeType}@${entity.uid}';
}

String _encodeIOSink(RecordingIOSink sink) {
  return '${sink.runtimeType}@${sink.uid}';
}

String _encodeRandomAccessFile(RecordingRandomAccessFile raf) {
  return '${raf.runtimeType}@${raf.uid}';
}

String _encodeReplayEntity(ReplayProxyMixin entity) => entity.identifier;

String _encodeEncoding(Encoding encoding) => encoding.name;

String _encodeFileMode(FileMode fileMode) {
  switch (fileMode) {
    case FileMode.READ:
      return 'READ';
    case FileMode.WRITE:
      return 'WRITE';
    case FileMode.APPEND:
      return 'APPEND';
    case FileMode.WRITE_ONLY:
      return 'WRITE_ONLY';
    case FileMode.WRITE_ONLY_APPEND:
      return 'WRITE_ONLY_APPEND';
  }
  throw new ArgumentError('Invalid value: $fileMode');
}

Map<String, dynamic> _encodeFileStat(FileStat stat) => <String, dynamic>{
      'changed': _encodeDateTime(stat.changed),
      'modified': _encodeDateTime(stat.modified),
      'accessed': _encodeDateTime(stat.accessed),
      'type': _encodeFileSystemEntityType(stat.type),
      'mode': stat.mode,
      'size': stat.size,
      'modeString': stat.modeString(),
    };

String _encodeFileSystemEntityType(FileSystemEntityType type) =>
    type.toString();

Map<String, dynamic> _encodeFileSystemEvent(FileSystemEvent event) =>
    <String, dynamic>{
      'type': event.type,
      'path': event.path,
    };
