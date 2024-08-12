import 'package:collection/collection.dart';
import 'package:macro_util/macro_util.dart';
import 'package:macros/macros.dart';

/// Generates a constructor for a class.
macro class Constructor implements ClassDeclarationsMacro {
  /// Code parts for extra parameters that can't be found by introspection.
  ///
  /// Use this if you generate fields in the same phase when this macro
  /// is applied.
  final List<List<Object>> extraNamedParameters;

  /// Whether to add 'const' keyword.
  final bool isConst;

  /// The name of the constructor.
  final String name;

  /// Whether to skip the fields that have initializers on them.
  final bool skipInitialized;

  const Constructor({
    this.extraNamedParameters = const [],
    this.isConst = false,
    this.name = '',
    this.skipInitialized = false,
  });

  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    final parts = await getParts(clazz, builder);
    builder.declareInType(DeclarationCode.fromParts(parts.indent()));
  }

  Future<List<Object>> getParts(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    await _assertNoDuplicate(clazz, builder);

    final superCtor = await _requireUnnamedSuperConstructor(clazz, builder);
    final thisParams = await _getThisParams(
      clazz,
      builder,
      skipInitialized: skipInitialized,
    );

    final superPositionalParams = await _getSuperPositionalParams(superCtor);
    final superNamedParams = await _getSuperNamedParams(superCtor);

    final namedParams = [
      ...thisParams.named,
      ...superPositionalParams,
      ...superNamedParams,
      ...extraNamedParameters,
    ];

    final hasParams = namedParams.isNotEmpty;
    final parts = <Object>[
      //
      if (isConst) 'const ',
      clazz.identifier.name,
      if (name != '') '.$name',
      '(',
      if (thisParams.positional.isNotEmpty)
        ...thisParams.positional.expand((e) => ['\n', ...e, ',']).indent(),
      if (hasParams) '{\n',
      ...namedParams.expand((e) => [...e, ',\n']).indent(),
      if (hasParams) '}',
      ')',
    ];

    if (superCtor != null) {
      parts.add(' : super(');

      if (superCtor.positionalParameters.isNotEmpty) {
        parts.add('\n');
        for (final param in superCtor.positionalParameters) {
          parts.addAll(['  ', param.identifier.name, ',\n']);
        }
      }

      parts.add(')');
    }

    parts.add(';');

    return parts;
  }

  Future<void> _assertNoDuplicate(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    final constructors = await builder.constructorsOf(clazz);
    final unnamedConstructor =
        constructors.firstWhereOrNull((c) => c.identifier.name == name);

    if (unnamedConstructor == null) {
      return;
    }

    throw ArgumentError(
      name == ''
          ? 'Cannot generate an unnamed constructor because one already exists.'
          : 'Cannot generate "$name" constructor because one already exists.',
    );
  }
}

Future<({List<List<Object>> named, List<List<Object>> positional})>
    _getThisParams(
  ClassDeclaration clazz,
  MemberDeclarationBuilder builder, {
  required bool skipInitialized,
}) async {
  final named = <List<Object>>[];
  final positional = <List<Object>>[];
  final fields = await builder.fieldsOf(clazz);

  for (final field in fields) {
    if (field.hasStatic) {
      continue;
    }

    if (field.hasInitializer && field.hasFinal) {
      continue;
    }

    if (skipInitialized && field.hasInitializer) {
      continue;
    }

    if (field.identifier.name.startsWith('_')) {
      positional.add(['this.', field.identifier]);
    } else {
      final requiredKeyword = field.type.isNullable ? '' : 'required ';
      named.add([requiredKeyword, 'this.', field.identifier]);
    }
  }

  return (named: named, positional: positional);
}

Future<List<List<Object>>> _getSuperPositionalParams(
  ConstructorDeclaration? superconstructor,
) async {
  if (superconstructor == null) {
    return [];
  }

  final result = <List<Object>>[];

  // Convert the positional parameters in the super constructor
  // to named parameters in this constructor.
  for (final param in superconstructor.positionalParameters) {
    final requiredKeyword = param.isRequired ? 'required ' : '';
    result.add([
      requiredKeyword,
      param.type.code,
      ' ',
      param.identifier.name,
    ]);
  }

  return result;
}

Future<List<List<Object>>> _getSuperNamedParams(
  ConstructorDeclaration? superconstructor,
) async {
  if (superconstructor == null) {
    return [];
  }

  final result = <List<Object>>[];

  for (final param in superconstructor.namedParameters) {
    final requiredKeyword = param.isRequired ? 'required ' : '';
    result.add([
      requiredKeyword,
      'super.',
      param.identifier.name,
    ]);
  }

  return result;
}

Future<ConstructorDeclaration?> _requireUnnamedSuperConstructor(
  ClassDeclaration clazz,
  MemberDeclarationBuilder builder,
) async {
  final superDecl = await builder.nonObjectSuperclassDeclarationOf(clazz);

  if (superDecl == null) {
    return null;
  }

  final superconstructor = (await builder.constructorsOf(superDecl))
      .firstWhereOrNull((c) => c.identifier.name == '');

  if (superconstructor == null) {
    throw ArgumentError(
      'Super class $superDecl of $clazz does not have an unnamed constructor.',
    );
  }

  return superconstructor;
}
