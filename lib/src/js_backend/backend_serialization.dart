// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js_backend.serialization;

import '../common/backend_api.dart' show BackendSerialization;
import '../dart_types.dart';
import '../elements/elements.dart';
import '../js/js.dart' as js;
import '../native/native.dart';
import '../serialization/serialization.dart'
    show DeserializerPlugin, ObjectDecoder, ObjectEncoder, SerializerPlugin;
import '../serialization/keys.dart';
import '../universe/side_effects.dart';
import 'js_backend.dart';

const String _BACKEND_DATA_TAG = 'jsBackendData';
const Key DART_TYPES_RETURNED = const Key('dartTypesReturned');
const Key SPECIAL_TYPES_RETURNED = const Key('specialTypesReturned');
const Key DART_TYPES_INSTANTIATED = const Key('dartTypesInstantiated');
const Key SPECIAL_TYPES_INSTANTIATED = const Key('specialTypesInstantiated');
const Key CODE_TEMPLATE = const Key('codeTemplate');
const Key SIDE_EFFECTS = const Key('sideEffects');
const Key THROW_BEHAVIOR = const Key('throwBehavior');
const Key IS_ALLOCATION = const Key('isAllocation');
const Key USE_GVN = const Key('useGvn');

class JavaScriptBackendSerialization implements BackendSerialization {
  final JavaScriptBackendSerializer serializer;
  final JavaScriptBackendDeserializer deserializer;

  JavaScriptBackendSerialization(JavaScriptBackend backend)
      : serializer = new JavaScriptBackendSerializer(backend),
        deserializer = new JavaScriptBackendDeserializer(backend);
}

const Key JS_INTEROP_NAME = const Key('jsInteropName');
const Key NATIVE_MEMBER_NAME = const Key('nativeMemberName');
const Key NATIVE_CLASS_TAG_INFO = const Key('nativeClassTagInfo');

class JavaScriptBackendSerializer implements SerializerPlugin {
  final JavaScriptBackend backend;

  JavaScriptBackendSerializer(this.backend);

  @override
  void onElement(Element element, ObjectEncoder createEncoder(String tag)) {
    ObjectEncoder encoder;
    ObjectEncoder getEncoder() {
      return encoder ??= createEncoder(_BACKEND_DATA_TAG);
    }

    String jsInteropName = backend.nativeData.jsInteropNames[element];
    if (jsInteropName != null) {
      getEncoder().setString(JS_INTEROP_NAME, jsInteropName);
    }
    String nativeMemberName = backend.nativeData.nativeMemberName[element];
    if (nativeMemberName != null) {
      getEncoder().setString(NATIVE_MEMBER_NAME, nativeMemberName);
    }
    String nativeClassTagInfo = backend.nativeData.nativeClassTagInfo[element];
    if (nativeClassTagInfo != null) {
      getEncoder().setString(NATIVE_CLASS_TAG_INFO, nativeClassTagInfo);
    }
  }

  /// Returns a list of the [DartType]s in [types].
  static List<DartType> filterDartTypes(List types) {
    return types.where((type) => type is DartType).toList();
  }

  /// Returns a list of the names of the [SpecialType]s in [types].
  static List<String> filterSpecialTypes(List types) {
    return types
        .where((type) => type is SpecialType)
        .map((SpecialType type) => type.name)
        .toList();
  }

  @override
  void onData(NativeBehavior behavior, ObjectEncoder encoder) {
    encoder.setTypes(
        DART_TYPES_RETURNED, filterDartTypes(behavior.typesReturned));
    encoder.setStrings(
        SPECIAL_TYPES_RETURNED, filterSpecialTypes(behavior.typesReturned));

    encoder.setTypes(
        DART_TYPES_INSTANTIATED, filterDartTypes(behavior.typesInstantiated));
    encoder.setStrings(SPECIAL_TYPES_INSTANTIATED,
        filterSpecialTypes(behavior.typesInstantiated));

    if (behavior.codeTemplateText != null) {
      encoder.setString(CODE_TEMPLATE, behavior.codeTemplateText);
    }

    encoder.setInt(SIDE_EFFECTS, behavior.sideEffects.flags);
    encoder.setEnum(THROW_BEHAVIOR, behavior.throwBehavior);
    encoder.setBool(IS_ALLOCATION, behavior.isAllocation);
    encoder.setBool(USE_GVN, behavior.useGvn);
  }
}

class JavaScriptBackendDeserializer implements DeserializerPlugin {
  final JavaScriptBackend backend;

  JavaScriptBackendDeserializer(this.backend);

  @override
  void onElement(Element element, ObjectDecoder getDecoder(String tag)) {
    ObjectDecoder decoder = getDecoder(_BACKEND_DATA_TAG);
    if (decoder != null) {
      String jsInteropName =
          decoder.getString(JS_INTEROP_NAME, isOptional: true);
      if (jsInteropName != null) {
        backend.nativeData.jsInteropNames[element] = jsInteropName;
      }
      String nativeMemberName =
          decoder.getString(NATIVE_MEMBER_NAME, isOptional: true);
      if (nativeMemberName != null) {
        backend.nativeData.nativeMemberName[element] = nativeMemberName;
      }
      String nativeClassTagInfo =
          decoder.getString(NATIVE_CLASS_TAG_INFO, isOptional: true);
      if (nativeClassTagInfo != null) {
        backend.nativeData.nativeClassTagInfo[element] = nativeClassTagInfo;
      }
    }
  }

  @override
  NativeBehavior onData(ObjectDecoder decoder) {
    SideEffects sideEffects =
        new SideEffects.fromFlags(decoder.getInt(SIDE_EFFECTS));
    NativeBehavior behavior = new NativeBehavior.internal(sideEffects);

    behavior.typesReturned
        .addAll(decoder.getTypes(DART_TYPES_RETURNED, isOptional: true));
    behavior.typesReturned.addAll(decoder
        .getStrings(SPECIAL_TYPES_RETURNED, isOptional: true)
        .map(SpecialType.fromName));

    behavior.typesReturned
        .addAll(decoder.getTypes(DART_TYPES_INSTANTIATED, isOptional: true));
    behavior.typesReturned.addAll(decoder
        .getStrings(SPECIAL_TYPES_INSTANTIATED, isOptional: true)
        .map(SpecialType.fromName));

    behavior.codeTemplateText =
        decoder.getString(CODE_TEMPLATE, isOptional: true);
    if (behavior.codeTemplateText != null) {
      behavior.codeTemplate = js.js.parseForeignJS(behavior.codeTemplateText);
    }

    behavior.throwBehavior =
        decoder.getEnum(THROW_BEHAVIOR, NativeThrowBehavior.values);
    behavior.isAllocation = decoder.getBool(IS_ALLOCATION);
    behavior.useGvn = decoder.getBool(USE_GVN);
    return behavior;
  }
}
