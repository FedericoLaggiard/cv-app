/// Sentinel used by `copyWith` methods to distinguish "argument not passed"
/// from "argument explicitly set to null".
///
/// Usage:
/// ```dart
/// Foo copyWith({Object? someNullable = unset}) => Foo(
///   someNullable: identical(someNullable, unset)
///     ? this.someNullable
///     : someNullable as SomeType?,
/// );
/// ```
///
/// Without this, the classic `x ?? this.x` pattern silently ignores an
/// intentional `null` — blocking every UI flow that clears an optional
/// field (removing a photo, ending an "in corso" experience, clearing a
/// date, etc). Ticket 07 depends on this behavior.
library;

const Object unset = Object();

bool isUnset(Object? value) => identical(value, unset);
