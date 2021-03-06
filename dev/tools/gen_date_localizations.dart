// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This program extracts localized date symbols and patterns from the intl
/// package for the subset of locales supported by the flutter_localizations
/// package.
///
/// The extracted data is written into lib/src/l10n/date_localizations.dart.
///
/// Usage:
///
/// The following outputs the generated Dart code to the console as a dry run:
///
/// ```
/// dart dev/tools/gen_date_localizations.dart
/// ```
///
/// If the data looks good, use the `-w` option to overwrite the
/// lib/src/l10n/date_localizations.dart file:
///
/// ```
/// dart dev/tools/gen_date_localizations.dart -w
/// ```

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart' as args;
import 'package:path/path.dart' as path;

const String _kCommandName = 'gen_date_localizations.dart';

Future<Null> main(List<String> rawArgs) async {
  final bool writeToFile = (new args.ArgParser()..addFlag('overwrite', abbr: 'w', defaultsTo: false)).parse(rawArgs)['overwrite'];
  final bool isRepoRoot = new Directory('.git').existsSync();

  if (!isRepoRoot) {
    _fatal(
      '$_kCommandName must be run from the root of the Flutter repository. The '
      'current working directory is: ${Directory.current.path}'
    );
  }

  final File dotPackagesFile = new File(path.join('packages', 'flutter', '.packages'));
  final bool dotPackagesExists = dotPackagesFile.existsSync();

  if (!dotPackagesExists) {
    _fatal(
      'File not found: ${dotPackagesFile.path}. $_kCommandName must be run '
      'after a successful "flutter update-packages".'
    );
  }

  final String pathToIntl = dotPackagesFile
    .readAsStringSync()
    .split('\n')
    .firstWhere(
      (String line) => line.startsWith('intl:'),
      orElse: () {
        _fatal('intl dependency not found in ${dotPackagesFile.path}');
      },
    )
    .split(':')
    .last;

  final Directory dateSymbolsDirectory = new Directory(path.join(pathToIntl, 'src', 'data', 'dates', 'symbols'));
  final Map<String, File> symbolFiles = _listIntlData(dateSymbolsDirectory);
  final Directory datePatternsDirectory = new Directory(path.join(pathToIntl, 'src', 'data', 'dates', 'patterns'));
  final Map<String, File> patternFiles = _listIntlData(datePatternsDirectory);
  final List<String> materialLocales = _materialLocales().toList();
  final StringBuffer buffer = new StringBuffer();

  buffer.writeln(
'''
// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file has been automatically generated.  Please do not edit it manually.
// To regenerate run (omit -w to print to console instead of the file):
// dart dev/tools/gen_date_localizations.dart -w

'''
);
  buffer.writeln('const Map<String, dynamic> dateSymbols = const <String, dynamic> {');
  symbolFiles.forEach((String locale, File data) {
    if (materialLocales.contains(locale))
      buffer.writeln(_jsonToMapEntry(locale, JSON.decode(data.readAsStringSync())));
  });
  buffer.writeln('};');

  buffer.writeln('const Map<String, dynamic> datePatterns = const <String, dynamic> {');
  patternFiles.forEach((String locale, File data) {
    if (materialLocales.contains(locale))
      buffer.writeln(_jsonToMapEntry(locale, JSON.decode(data.readAsStringSync())));
  });
  buffer.writeln('};');

  if (writeToFile) {
    final File dateLocalizationsFile = new File(path.join('packages', 'flutter_localizations', 'lib', 'src', 'l10n', 'date_localizations.dart'));
    dateLocalizationsFile.writeAsStringSync(buffer.toString());
    Process.runSync(path.join('bin', 'cache', 'dart-sdk', 'bin', 'dartfmt'), <String>[
      '-w',
      dateLocalizationsFile.path,
    ]);
  } else {
    print(buffer);
  }
}

String _jsonToMapEntry(String key, dynamic value) {
  return "'$key': ${_jsonToMap(value)},";
}

String _jsonToMap(dynamic json) {
  if (json == null || json is num || json is bool)
    return '$json';

  if (json is String) {
    if (json.contains("'"))
      return 'r"""$json"""';
    else
      return "r'''$json'''";
  }

  if (json is Iterable)
    return 'const <dynamic>[${json.map(_jsonToMap).join(',')}]';

  if (json is Map) {
    final StringBuffer buffer = new StringBuffer('const <String, dynamic>{');
    json.forEach((String key, dynamic value) {
      buffer.writeln(_jsonToMapEntry(key, value));
    });
    buffer.write('}');
    return buffer.toString();
  }

  throw 'Unsupported JSON type ${json.runtimeType} of value $json.';
}

void _fatal(String message) {
  stderr.writeln(message);
  exit(1);
}

Iterable<String> _materialLocales() sync* {
  final RegExp filenameRE = new RegExp(r'.*_(\w+)\.arb$');
  final Directory materialLocalizationsDirectory = new Directory(path.join('packages', 'flutter_localizations', 'lib', 'src', 'l10n'));
  for (FileSystemEntity entity in materialLocalizationsDirectory.listSync()) {
    final String filePath = entity.path;
    if (FileSystemEntity.isFileSync(filePath) && filenameRE.hasMatch(filePath))
      yield filenameRE.firstMatch(filePath)[1];
  }
}

Map<String, File> _listIntlData(Directory directory) {
  final Map<String, File> result = <String, File>{};
  for (FileSystemEntity entity in directory.listSync()) {
    final String filePath = entity.path;
    if (FileSystemEntity.isFileSync(filePath) && filePath.endsWith('.json')) {
      final String locale = path.basenameWithoutExtension(filePath);
      result[locale] = entity;
    }
  }
  return result;
}
