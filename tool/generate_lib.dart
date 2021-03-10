import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

const licence = '''
// Copyright (c) 2015, Alexandre Ardhuin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
''';

final customClassName = <String, String>{
  'Map': 'GMap',
  'Symbol': 'GSymbol',
  'Duration': 'GDuration',
  'DataStylingFunction': 'function(Data.Feature): Data.StyleOptions',
  'LocationBias':
      'LatLng|LatLngLiteral|LatLngBounds|LatLngBoundsLiteral|Circle|CircleLiteral|string',
  'MapMouseEvent|IconMouseEvent': 'IconMouseEvent',
  'LocationRestriction': 'LatLngBounds|LatLngBoundsLiteral',
  'Error': 'Object',
};

final customLibraryNames = <String, String>{
  'localContext': 'local_context',
};

final ignoredClasses = <String>[
  'CircleLiteral',
  'LatLngLiteral',
  'LatLngBoundsLiteral',
  'undefined',
];

void patchEntities(List<DocEntity> entities) {
  for (final entity in entities) {
    if (entity.library == null && entity.name == 'LatLng') {
      entity.constructor!
        ..parameters = [
          DocMethodParameter()
            ..name = 'lat'
            ..type = convertType('number'),
          DocMethodParameter()
            ..name = 'lng'
            ..type = convertType('number'),
        ]
        ..optionalParameters = [
          DocMethodParameter()
            ..name = 'noWrap'
            ..type = convertType('boolean'),
        ];
    } else if (entity.library == 'localContext' &&
        entity.name == 'PlaceTypePreference') {
      entity
        ..kind = Kind.interface
        ..properties = [
          DocProperty()
            ..name = 'type'
            ..type = convertType('string'),
          DocProperty()
            ..name = 'weight'
            ..type = convertType('number')
            ..optional = true,
        ];
    } else if (entity.name == 'event') {
      for (var method in entity.staticMethods) {
        if (method.returnType == 'MapsEventListener?') {
          method.returnType = 'MapsEventListener';
        }
      }
    }
    for (var method in entity.methods) {
      if (method.returnType!.startsWith('Promise<')) {
        method.returnType =
            'Future${method.returnType!.substring('Promise'.length)}';
      }
      if (method.name == 'toString') {
        method.returnType = 'String';
      }
    }
  }
}

Future main() async {
  final genFolder =
      '${path.dirname(Platform.script.path)}/../lib/src/generated';
  final content = (await http.get(Uri.parse(
          'https://developers.google.com/maps/documentation/javascript/reference')))
      .body;
  final document = parse(content);
  final urls = document
      .querySelectorAll('devsite-expandable-nav')
      .first
      .querySelectorAll('a.devsite-nav-title')
      .skip(1)
      .map((Element e) => e.attributes['href'])
      .map((e) => 'https://developers.google.com$e');
  final entities = (await Future.wait(urls.map(Uri.parse).map(http.get)))
      .map((response) => response.body)
      .map(parse)
      .expand((html) => html.querySelectorAll(
          'div[itemtype="http://developers.google.com/ReferenceObject"]'))
      .map(parseDocEntity)
      .where((e) => !ignoredClasses.contains(e.name))
      .map((e) => e..convertTypes())
      .toList();
  patchEntities(entities);

  final parts = <String, List<String>>{};
  for (var entity in entities) {
    final code = generateCodeForEntity(entity, entities);
    if (code.trim().isEmpty) {
      continue;
    }
    var library = entity.library ?? 'core';
    library = customLibraryNames[library] ?? library;
    final fileName = '$library/${entity.fileName}.dart';
    final bundleFile = 'google_maps_$library.dart';
    File('$genFolder/$fileName')
      ..createSync(recursive: true)
      ..writeAsStringSync(DartFormatter().format('''
$licence
part of '../$bundleFile';
$code
'''));
    parts.putIfAbsent(library, () => <String>[]).add(fileName);
  }

  for (var entry in parts.entries) {
    final library = entry.key;
    final partList = [
      for (final fileName in entry.value) "part '$fileName';",
    ].join('\n');
    final imports = <String, List<String>>{
      'core': [
        "import 'dart:async' show StreamController;",
        "import 'dart:html' show Document, Element, Node;",
        "import 'package:js_wrapping/js_wrapping.dart';",
      ],
      'drawing': [
        "import 'dart:async' show StreamController;",
        "import 'package:js_wrapping/js_wrapping.dart';",
        "import 'package:google_maps/google_maps.dart';",
      ],
      'geometry': [
        "import 'package:js_wrapping/js_wrapping.dart';",
        "import 'package:google_maps/google_maps.dart';",
      ],
      'local_context': [
        "import 'dart:async' show StreamController;",
        "import 'dart:html' show Element;",
        "import 'package:js_wrapping/js_wrapping.dart';",
        "import 'package:google_maps/google_maps.dart';",
      ],
      'places': [
        "import 'dart:async' show StreamController;",
        "import 'dart:html' show InputElement;",
        "import 'package:js_wrapping/js_wrapping.dart';",
        "import 'package:google_maps/google_maps.dart';",
      ],
      'visualization': [
        "import 'package:js_wrapping/js_wrapping.dart';",
        "import 'package:google_maps/google_maps.dart';",
      ],
    };
    File('$genFolder/google_maps_$library.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(DartFormatter().format('''
$licence

@JS()
library google_maps.$library;

${imports[library]?.join()}

$partList
'''));
  }
}

String generateCodeForEntity(DocEntity entity, List<DocEntity> entities) {
  switch (entity.kind) {
    case Kind.clazz:
      return generateCodeForClass(entity, entities);
    case Kind.interface:
      return generateCodeForInterface(entity);
    case Kind.namespace:
      return generateCodeForNamespace(entity);
    case Kind.constants:
      return generateCodeForConstants(entity);
    case Kind.typedef:
      return generateCodeForTypedef(entity);
  }
}

String generateCodeForClass(DocEntity entity, List<DocEntity> entities) {
  final additionalProperties = [];
  final additionalMethods = [];
  if (entity.kind == Kind.clazz && entity.implementsName != null) {
    final impl = entities.firstWhere(
        (e) => e.library == entity.library && e.name == entity.implementsName);
    for (final p in impl.properties) {
      if (!entity.properties.any((e) => e.name == p.name)) {
        additionalProperties.add(p);
      }
    }
    for (final m in impl.methods) {
      if (!entity.methods.any((e) => e.name == m.name)) {
        additionalMethods.add(m);
      }
    }
  }

  final name = entity.name;
  final lines = <String>[
    // constructor
    if (entity.constructor != null) ...<String>[
      'factory ${name.replaceAll(RegExp(r'<.*'), '')}${buildSignature(entity.constructor!, addIgnoreUnusedElement: true)} => \$js();',
    ],
    // properties
    for (var property in [...entity.properties, ...additionalProperties])
      ...generateCodeForProperty(entity, property),
    // methods
    for (var method in [...entity.methods, ...additionalMethods])
      ...generateCodeForMethod(entity, method),
    // events
    for (var method in entity.events) ...generateCodeForEvent(entity, method),
  ];

  return '''
@JsName('${entity.fullJsName}')
abstract class $name
${entity.extendsName != null ? 'extends ${entity.extendsName}' : ''}
${entity.implementsName != null ? 'implements ${entity.implementsName}' : ''}
{
${lines.join('\n')}
}
''';
}

String generateCodeForInterface(DocEntity entity) {
  final name = entity.name;
  final lines = <String>[
    // constructor
    'factory ${name.replaceAll(RegExp(r'<.*'), '')}() => \$js();',
    // properties
    for (var property in entity.properties)
      ...generateCodeForProperty(entity, property),
    // methods
    for (var method in entity.methods) ...generateCodeForMethod(entity, method),
  ];
  return '''
@JsName()
${entity.extendsName != null ? '@JS()' : ''}
@anonymous
abstract class $name
${entity.extendsName != null ? 'extends ${entity.extendsName}' : ''}
${entity.implementsName != null ? 'implements ${entity.implementsName}' : ''}
{
${lines.join('\n')}
}
''';
}

String generateCodeForNamespace(DocEntity entity) {
  final name = entity.name.capitalize();
  final namespace = '_$name\$namespace';
  final lines = <String>[
    // static methods
    for (var method in entity.staticMethods)
      ...generateCodeForStaticMethod(entity, method, namespace),
  ];
  return '''
@JS('${entity.fullJsName}')
external Object get $namespace;
class $name {
${lines.join('\n')}
}
''';
}

String generateCodeForConstants(DocEntity entity) {
  final name = entity.name;
  return '''
// ignore_for_file: unused_element, unused_field
@JsName('${entity.fullJsName}')
enum $name {
${entity.constants.map((e) => e.name).join(',')},
}
''';
}

// handled directly by alias in convertType
String generateCodeForTypedef(DocEntity entity) => '';

List<String> generateCodeForProperty(DocEntity entity, DocProperty property) {
  if (property.name.contains('_')) {
    final parts = property.name.split('_');
    final rename = [
      parts.first.unCapitalize(),
      ...parts.skip(1).map((e) => e.capitalize()),
    ].join();
    return [
      ' // custom name for ${property.name}',
      "@JsName('${property.name}')",
      '${property.type} $rename;',
    ];
  }
  return [
    '${property.type} ${property.name};',
  ];
}

List<String> generateCodeForMethod(DocEntity entity, DocMethod method) {
  // custom
  if (const [
    Member('LatLng', 'lat'),
    Member('LatLng', 'lng'),
  ].contains(Member(entity.name, method.name))) {
    return [
      '',
      ' // custom getter for ${method.name}',
      '${method.returnType} get ${method.name} => _${method.name}();',
      "@JsName('${method.name}')",
      '${method.returnType} _${method.name}();',
      '',
    ];
  }

  // method to implement
  if (const [
    Member('MapType', 'getTile'),
    Member('MapType', 'releaseTile'),
    Member('OverlayView', 'draw'),
    Member('OverlayView', 'onAdd'),
    Member('OverlayView', 'onRemove'),
    Member('Projection', 'fromLatLngToPoint'),
    Member('Projection', 'fromPointToLatLng'),
    Member('StreetViewTileData', 'getTileUrl'),
    Member('StyledMapType', 'getTile'),
    Member('StyledMapType', 'releaseTile'),
    Member('ImageMapType', 'getTile'),
    Member('ImageMapType', 'releaseTile'),
  ].contains(Member(entity.name, method.name))) {
    return [
      '${method.returnType} Function${buildSignature(method)}? ${method.name};',
    ];
  }

  // replace with getter
  if (method.name.startsWith('get') &&
      method.name.length > 3 &&
      method.parameters.isEmpty) {
    final name = '${method.name[3].toLowerCase()}${method.name.substring(4)}';
    return [
      '',
      ' // synthetic getter for ${method.name}',
      '${method.returnType} get $name => _${method.name}();',
      "@JsName('${method.name}')",
      '${method.returnType} _${method.name}();',
      '',
    ];
  }

  // replace with setter
  if (method.name.startsWith('set') &&
      method.name.length > 3 &&
      method.returnType == 'void' &&
      [...method.parameters, ...method.optionalParameters].length == 1) {
    if (method.optionalParameters.isNotEmpty) {
      method
        ..parameters = method.optionalParameters
        ..optionalParameters = [];
    }
    final type = method.parameters.first.type;
    final name = '${method.name[3].toLowerCase()}${method.name.substring(4)}';
    return [
      '',
      ' // synthetic setter for ${method.name}',
      'set $name($type $name) => _${method.name}($name);',
      "@JsName('${method.name}')",
      'void _${method.name}${buildSignature(method)};',
      '',
    ];
  }

  if (ignoredClasses.expand((e) => [e, '$e?']).contains(method.returnType)) {
    return [];
  }

  return [
    '${method.returnType} ${method.name}${buildSignature(method)};',
  ];
}

List<String> generateCodeForStaticMethod(
    DocEntity entity, DocMethod method, String namespace) {
  if (const [Member('event', 'trigger')]
      .contains(Member(entity.name, method.name))) {
    return [
      '',
      'static void trigger(Object instance, String eventName, List<Object?>? eventArgs)',
      "=> callMethod($namespace, 'trigger', [instance, eventName, ...?eventArgs]);",
      '',
    ];
  }
  final params = [...method.parameters, ...method.optionalParameters]
      .map((e) => e.type == 'Function?'
          ? '${e.name} == null ? null : allowInterop(${e.name})'
          : e.name)
      .join(',');
  return [
    'static ${method.returnType} ${method.name}${buildSignature(method)}',
    "  => callMethod($namespace, '${method.name}', [$params]);",
  ];
}

List<String> generateCodeForEvent(DocEntity entity, DocMethod method) {
  final eventName = method.name;
  final streamName = [
    'on',
    ...eventName.split('_').map((e) => e.capitalize()),
  ].join();
  String params;
  String type;
  if (method.parameters.isEmpty && method.optionalParameters.isEmpty) {
    type = 'void';
    params = 'null';
  } else if (method.parameters.length == 1 &&
      method.optionalParameters.isEmpty) {
    type = method.parameters.first.type!.nonNullable();
    params = method.parameters.first.name;
  } else {
    type = 'List';
    final names = [...method.parameters, ...method.optionalParameters]
        .map((e) => e.name)
        .join(',');
    params = '[$names]';
  }

  return [
    '''
    Stream<$type> get $streamName {
      late StreamController<$type> sc; // ignore: close_sinks
      late MapsEventListener mapsEventListener;
      void start() => mapsEventListener = Event.addListener(
        this,
        '$eventName',
        ${buildSignature(method, nonNullable: true)} => sc.add($params),
      );
      void stop() => mapsEventListener.remove();
      sc = StreamController<$type>(
        onListen: start,
        onCancel: stop,
        onResume: start,
        onPause: stop,
      );
      return sc.stream;
    }''',
  ];
}

String buildSignature(
  DocMethod method, {
  bool addIgnoreUnusedElement = false,
  bool nonNullable = false,
}) {
  final params = method.parameters;
  final optionalParams = method.optionalParameters;
  final result = StringBuffer('(')
    ..write(params
        .map((param) =>
            '${nonNullable ? param.type?.nonNullable() : param.type} ${param.name}')
        .join(','));
  if (optionalParams.isNotEmpty) {
    if (params.isNotEmpty) {
      result.write(',');
    }
    result
      ..write('[')
      ..write(optionalParams
          .map((param) => '${param.type} ${param.name},')
          .map((e) =>
              addIgnoreUnusedElement ? '$e // ignore: unused_element\n' : e)
          .join())
      ..write(']');
  }
  result.write(')');
  return result.toString();
}

String? convertType(String? type) {
  if (type == null) return null;
  final myType = type.trim();
  if (myType == 'boolean')
    return 'bool?';
  else if (myType == 'number')
    return 'num?';
  else if (myType == 'string')
    return 'String?';
  else if (myType == 'Date')
    return 'DateTime?';
  else if (myType == 'HTMLInputElement')
    return 'InputElement?';
  else if (myType == 'HTMLDivElement')
    return 'DivElement?';
  else if (myType == 'Event')
    return 'Object?';
  else if (myType == 'Array')
    return 'List?';
  else if (myType == 'None')
    return 'void';
  else if (myType == '*')
    return 'Object?';
  else if (myType == '?')
    return 'Object?';
  else if (customClassName.containsKey(myType))
    return convertType(customClassName[myType]);
  else if (myType.startsWith('(') && myType.endsWith(')'))
    return convertType(myType.substring(1, myType.length - 1));
  else if (splitComplexTypeBy(myType, '|').length > 1) {
    for (final ignoredClass in ignoredClasses) {
      if (myType.startsWith('$ignoredClass|')) {
        return convertType(myType.substring('$ignoredClass|'.length));
      }
      if (myType.endsWith('|$ignoredClass')) {
        return convertType(
            myType.substring(0, myType.lastIndexOf('|$ignoredClass')));
      }
      if (myType.contains('|$ignoredClass|')) {
        return convertType(myType.replaceAll('|$ignoredClass|', '|'));
      }
    }
    final typeUnion = splitComplexTypeBy(myType, '|');
    final dartUnion = typeUnion.map(convertType).join('|');
    return 'Object?/*$dartUnion*/';
  } else if (myType.startsWith('{') && myType.endsWith('}')) {
    final tupleContent =
        splitComplexTypeBy(myType.substring(1, myType.length - 1), ',')
            .map((p) => splitComplexTypeBy(p.trim(), ':'))
            .map((e) => [convertType(e[1].trim()), e[0].trim()].join(' '))
            .join(', ');
    return '($tupleContent)';
  } else if (myType.startsWith('Object<') && myType.endsWith('>')) {
    final innerType =
        convertType(myType.substring('Object<'.length, myType.length - 1));
    return 'Map<String, $innerType>?';
  } else if (myType.startsWith('Array<') && myType.endsWith('>')) {
    final innerType =
        convertType(myType.substring('Array<'.length, myType.length - 1));
    return 'List<$innerType>?';
  } else if (myType.startsWith('function(')) {
    final parts = splitComplexTypeBy(myType, ':');
    final returnType =
        parts.length > 1 ? convertType(parts.skip(1).join(':')) : 'void';
    var i = 1;
    final params = splitComplexTypeBy(
            parts[0].substring('function('.length, parts[0].lastIndexOf(')')),
            ',')
        .map(convertType)
        .map((p) => '$p p${i++}')
        .join(',');
    return '$returnType Function($params)?';
  } else if (myType.startsWith('MVCArray<') && myType.endsWith('>')) {
    final innerType =
        convertType(myType.substring('MVCArray<'.length, myType.length - 1));
    return 'MVCArray<$innerType>?';
  } else if (myType == 'void') {
    return 'void';
  } else if (myType == 'dynamic') {
    return 'dynamic';
  } else {
    return '${myType.replaceAll('.', '')}?';
  }
}

List<String> splitComplexTypeBy(String type, String char) {
  final typeParts = <String>[];
  var bracketDeepth = 0;
  var parenthesisDeepth = 0;
  var genericDeepth = 0;
  final buffer = StringBuffer();
  for (var i = 0; i < type.length; i++) {
    final c = type[i];
    if (c == char &&
        bracketDeepth == 0 &&
        parenthesisDeepth == 0 &&
        genericDeepth == 0) {
      typeParts.add(buffer.toString());
      buffer.clear();
      continue;
    }
    if (c == '{') bracketDeepth++;
    if (c == '}') bracketDeepth--;
    if (c == '(') parenthesisDeepth++;
    if (c == ')') parenthesisDeepth--;
    if (c == '<') genericDeepth++;
    if (c == '>') genericDeepth--;
    buffer.write(c);
  }
  if (buffer.isNotEmpty) typeParts.add(buffer.toString());
  return typeParts;
}

enum Kind { clazz, interface, namespace, constants, typedef }

class DocEntity {
  late Kind kind;
  String? library;
  String? path;
  late String name;
  String? fullJsName;
  String? extendsName;
  String? implementsName;
  String? comment;
  DocMethod? constructor;
  List<DocMethod> staticMethods = [];
  List<DocMethod> methods = [];
  List<DocProperty> properties = [];
  List<DocMethod> events = [];
  List<DocConstant> constants = [];

  String get fileName {
    final value = name
        .capitalize()
        .replaceAll('.', '_')
        .replaceAll(RegExp(r'<[A-Z]>'), '')
        .replaceAllMapped(RegExp(r'([A-Z]+)([A-Z][a-z]+)'),
            (m) => '${m.group(1)!.toLowerCase()}_${m.group(2)!.toLowerCase()}_')
        .replaceAllMapped(
            RegExp(r'[A-Z][a-z]+'), (m) => '${m.group(0)!.toLowerCase()}_');
    return value.substring(0, value.length - 1);
  }

  @override
  String toString() => 'DocEntity($library ,$kind, $path, $name, $extendsName)';

  void convertTypes() {
    extendsName = convertType(extendsName)?.nonNullable();
    implementsName = convertType(implementsName)?.nonNullable();
    name = convertType(name)!.replaceAll('?', '');
    constructor?.convertTypes();
    for (var e in staticMethods) {
      e.convertTypes();
    }
    for (var e in methods) {
      e.convertTypes();
    }
    for (var e in properties) {
      e.convertTypes();
    }
    for (var e in events) {
      e.convertTypes();
    }
  }
}

DocEntity parseDocEntity(Element element) {
  final entity = DocEntity()
    ..kind = toKind(element
        .querySelector('h2')!
        .attributes['data-text']!
        .trim()
        .split(RegExp(r'[ \n]+'))[1])
    ..path = element.querySelector('span[itemprop="path"]')!.text
    ..name = element.querySelector('span[itemprop="name"]')!.text
    ..library = element
        .querySelectorAll('>p')
        .firstWhereOrNull((e) => e.text.startsWith('Requires the &libraries='))
        ?.querySelector('code')
        ?.text
        .substring('&libraries='.length);

  entity
    // full js name
    ..fullJsName =
        [entity.path, entity.name].join('.').replaceFirst(RegExp(r'<.*'), '')
    // extendsName
    ..extendsName = element
        .querySelectorAll('>p')
        .firstWhereOrNull((e) =>
            e.text.startsWith(RegExp(r'This (class|interface) extends')) &&
            e.querySelector('a') != null)
        ?.querySelector('a')
        ?.text
    // implementsName
    ..implementsName = element
        .querySelectorAll('>p')
        .firstWhereOrNull((e) =>
            e.text.startsWith(RegExp(r'This (class|interface) implements')) &&
            e.querySelector('a') != null)
        ?.querySelector('a')
        ?.text;

  // constructor
  if (element.querySelector('table.constructors') != null) {
    entity.constructor = parseTrForDocMethod(element
        .querySelector('table.constructors')!
        .children[1]
        .children
        .first);
  }
  // properties
  if (element.querySelector('table.properties') != null) {
    entity.properties = element
        .querySelector('table.properties')!
        .children[1]
        .children
        .map(parseTrForDocProperty)
        .toList();
  }
  // methods
  if (element.querySelector(r'table.methods[summary$=" - Methods"]') != null) {
    entity.methods = element
        .querySelector(r'table.methods[summary$=" - Methods"]')!
        .children[1]
        .children
        .map(parseTrForDocMethod)
        .toList();
  }
  // static methods
  if (element.querySelector(r'table.methods[summary$=" - Static Methods"]') !=
      null) {
    entity.staticMethods = element
        .querySelector(r'table.methods[summary$=" - Static Methods"]')!
        .children[1]
        .children
        .map(parseTrForDocMethod)
        .toList();
  }
  // constants
  if (element.querySelector('table.constants') != null) {
    entity.constants = element
        .querySelector('table.constants')!
        .children[1]
        .children
        .map(parseTrForDocConstant)
        .toList();
  }
  // constants
  if (element.querySelector('table.details') != null) {
    entity.events = element
        .querySelector('table.details')!
        .children[1]
        .children
        .map(parseTrForDocMethod)
        .toList();
  }
  return entity;
}

DocMethod parseTrForDocMethod(Element trElement) {
  final result = DocMethod();

  final tdList = trElement.children;
  result.name = tdList[0].text;

  final descriptions = tdList[1]
      .children
      .where((e) => e.localName == 'div' && e.classes.contains('desc'));

  final parameters = descriptions.singleWhereOrNull((e) =>
      e.children.isNotEmpty &&
      (e.children.first.text == 'Parameters:' ||
          e.children.first.text == 'Arguments:'));
  if (parameters != null) {
    final paramLis = parameters.querySelectorAll('li');
    result
      ..parameters = paramLis
          .where((e) => e.querySelector('.optional-type-annotation') == null)
          .map((e) => DocMethodParameter()
            ..name = e.querySelectorAll('code')[0].text
            ..type = e.querySelectorAll('code')[1].text)
          .toList()
      ..optionalParameters = paramLis
          .where((e) => e.querySelector('.optional-type-annotation') != null)
          .map((e) => DocMethodParameter()
            ..name = e.querySelectorAll('code')[0].text
            ..type =
                e.querySelectorAll('code')[1].text.replaceAll(' optional', ''))
          .toList();
  }

  final returnType = descriptions.singleWhereOrNull(
      (e) => e.children.isNotEmpty && e.children.first.text == 'Return Value:');
  if (returnType != null) {
    result.returnType = returnType.text
        .replaceFirst('Return Value:', '')
        .replaceAll(' optional', '')
        .trim();
  }

  return result;
}

DocProperty parseTrForDocProperty(Element trElement) {
  final tdList = trElement.children;
  return DocProperty()
    ..name = tdList[0].querySelector('a.secret-link')!.text
    ..type = tdList[1]
        .children
        .firstWhere((e) => e.localName == 'div')
        .text
        .replaceFirst('Type:', '')
        .replaceAll(' optional', '')
        .trim();
}

DocConstant parseTrForDocConstant(Element trElement) {
  final tdList = trElement.children;
  return DocConstant()..name = tdList[0].text;
}

class DocProperty {
  late String name;
  String? type;
  bool? optional;
  String? comment;

  void convertTypes() {
    type = convertType(type);
  }
}

class DocMethod {
  late String name;
  List<DocMethodParameter> parameters = [];
  List<DocMethodParameter> optionalParameters = [];
  String? returnType;
  String? comment;

  void convertTypes() {
    returnType = convertType(returnType);
    for (var e in parameters) {
      e.convertTypes();
    }
    for (var e in optionalParameters) {
      e.convertTypes();
    }
  }
}

class DocMethodParameter {
  late String name;
  String? type;

  void convertTypes() {
    type = convertType(type);
  }
}

class DocConstant {
  late String name;
  String? comment;
}

Kind toKind(String value) {
  switch (value) {
    case 'class':
      return Kind.clazz;
    case 'constants':
      return Kind.constants;
    case 'interface':
      return Kind.interface;
    case 'namespace':
      return Kind.namespace;
    case 'typedef':
      return Kind.typedef;
  }
  throw StateError('Unknown kind: $value');
}

class Member {
  const Member(this.className, this.name);

  final String className;
  final String name;

  @override
  int get hashCode => 0;
  @override
  bool operator ==(other) =>
      other is Member && other.className == className && other.name == name;
}

extension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
  String unCapitalize() => this[0].toLowerCase() + substring(1);
  String nonNullable() => endsWith('?') ? substring(0, length - 1) : this;
}
