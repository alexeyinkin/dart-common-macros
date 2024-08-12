import 'dart:async';

import 'package:macros/macros.dart';

/// Generates a getter for a private field by dropping the underscore.
macro class Getter implements FieldDeclarationsMacro {
  const Getter();

  @override
  Future<void> buildDeclarationsForField(
    FieldDeclaration field,
    MemberDeclarationBuilder builder,
  ) async {
    final name = field.identifier.name;
    if (!name.startsWith('_')) {
      throw ArgumentError(
        'A getter can be generated for private fields only.',
      );
    }

    final publicName = name.substring(1);
    final getter = DeclarationCode.fromParts([
      field.type.code,
      ' get $publicName => ',
      field.identifier,
      ';',
    ]);
    builder.declareInType(getter);
  }
}
