import 'package:collection/collection.dart';
import 'package:macro_util/macro_util.dart';
import 'package:macros/macros.dart';

macro class Constructor implements ClassDeclarationsMacro {
  const Constructor({
    this.name = '',
    this.skipInitialized = false,
  });

  final String name;
  final bool skipInitialized;

  @override
  Future<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    await _assertNoDuplicate(clazz, builder);

    final superCtor = await _requireUnnamedSuperConstructor(clazz, builder);
    final thisParams =
        await _getThisParams(clazz, builder, skipInitialized: skipInitialized);
    final superPositionalParams = await _getSuperPositionalParams(superCtor);
    final superNamedParams = await _getSuperNamedParams(superCtor);

    final params = [
      ...thisParams,
      ...superPositionalParams,
      ...superNamedParams,
    ];

    final hasParams = params.isNotEmpty;
    final parts = <Object>[
      //
      clazz.identifier.name,
      if (name != '') '.$name',
      '(',
      if (hasParams) '{\n',
      ...params.expand((e) => [...e, ',\n']).indent(),
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
    builder.declareInType(DeclarationCode.fromParts(parts.indent()));
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

Future<List<List<Object>>> _getThisParams(
  ClassDeclaration clazz,
  MemberDeclarationBuilder builder, {
  required bool skipInitialized,
}) async {
  final result = <List<Object>>[];
  final fields = await builder.fieldsOf(clazz);

  for (final field in fields) {
    if (skipInitialized && field.hasInitializer) {
      continue;
    }

    final requiredKeyword = field.type.isNullable ? '' : 'required ';
    result.add([requiredKeyword, field.identifier]);
  }

  return result;
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
