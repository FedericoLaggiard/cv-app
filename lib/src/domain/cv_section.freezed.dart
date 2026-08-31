// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cv_section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AnagraficaData {

 String get nome; String get cognome; CalendarDate? get dataNascita; String? get luogoNascita; String? get nazionalita; Genere? get genere; StatoCivile? get statoCivile; String? get codiceFiscale; AssetRef? get foto; String? get headline;
/// Create a copy of AnagraficaData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnagraficaDataCopyWith<AnagraficaData> get copyWith => _$AnagraficaDataCopyWithImpl<AnagraficaData>(this as AnagraficaData, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AnagraficaData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnagraficaData&&(identical(other.nome, _this.nome) || other.nome == _this.nome)&&(identical(other.cognome, _this.cognome) || other.cognome == _this.cognome)&&(identical(other.dataNascita, _this.dataNascita) || other.dataNascita == _this.dataNascita)&&(identical(other.luogoNascita, _this.luogoNascita) || other.luogoNascita == _this.luogoNascita)&&(identical(other.nazionalita, _this.nazionalita) || other.nazionalita == _this.nazionalita)&&(identical(other.genere, _this.genere) || other.genere == _this.genere)&&(identical(other.statoCivile, _this.statoCivile) || other.statoCivile == _this.statoCivile)&&(identical(other.codiceFiscale, _this.codiceFiscale) || other.codiceFiscale == _this.codiceFiscale)&&(identical(other.foto, _this.foto) || other.foto == _this.foto)&&(identical(other.headline, _this.headline) || other.headline == _this.headline));
}


@override
int get hashCode {
  final _this = this as AnagraficaData;
  return Object.hash(runtimeType,_this.nome,_this.cognome,_this.dataNascita,_this.luogoNascita,_this.nazionalita,_this.genere,_this.statoCivile,_this.codiceFiscale,_this.foto,_this.headline);
}

@override
String toString() {
  final _this = this as AnagraficaData;
  return 'AnagraficaData(nome: ${_this.nome}, cognome: ${_this.cognome}, dataNascita: ${_this.dataNascita}, luogoNascita: ${_this.luogoNascita}, nazionalita: ${_this.nazionalita}, genere: ${_this.genere}, statoCivile: ${_this.statoCivile}, codiceFiscale: ${_this.codiceFiscale}, foto: ${_this.foto}, headline: ${_this.headline})';
}


}

/// @nodoc
abstract mixin class $AnagraficaDataCopyWith<$Res>  {
  factory $AnagraficaDataCopyWith(AnagraficaData value, $Res Function(AnagraficaData) _then) = _$AnagraficaDataCopyWithImpl;
@useResult
$Res call({
 String nome, String cognome, CalendarDate? dataNascita, String? luogoNascita, String? nazionalita, Genere? genere, StatoCivile? statoCivile, String? codiceFiscale, AssetRef? foto, String? headline
});




}
/// @nodoc
class _$AnagraficaDataCopyWithImpl<$Res>
    implements $AnagraficaDataCopyWith<$Res> {
  _$AnagraficaDataCopyWithImpl(this._self, this._then);

  final AnagraficaData _self;
  final $Res Function(AnagraficaData) _then;

/// Create a copy of AnagraficaData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nome = null,Object? cognome = null,Object? dataNascita = freezed,Object? luogoNascita = freezed,Object? nazionalita = freezed,Object? genere = freezed,Object? statoCivile = freezed,Object? codiceFiscale = freezed,Object? foto = freezed,Object? headline = freezed,}) {
  return _then(AnagraficaData(
nome: null == nome ? _self.nome : nome // ignore: cast_nullable_to_non_nullable
as String,cognome: null == cognome ? _self.cognome : cognome // ignore: cast_nullable_to_non_nullable
as String,dataNascita: freezed == dataNascita ? _self.dataNascita : dataNascita // ignore: cast_nullable_to_non_nullable
as CalendarDate?,luogoNascita: freezed == luogoNascita ? _self.luogoNascita : luogoNascita // ignore: cast_nullable_to_non_nullable
as String?,nazionalita: freezed == nazionalita ? _self.nazionalita : nazionalita // ignore: cast_nullable_to_non_nullable
as String?,genere: freezed == genere ? _self.genere : genere // ignore: cast_nullable_to_non_nullable
as Genere?,statoCivile: freezed == statoCivile ? _self.statoCivile : statoCivile // ignore: cast_nullable_to_non_nullable
as StatoCivile?,codiceFiscale: freezed == codiceFiscale ? _self.codiceFiscale : codiceFiscale // ignore: cast_nullable_to_non_nullable
as String?,foto: freezed == foto ? _self.foto : foto // ignore: cast_nullable_to_non_nullable
as AssetRef?,headline: freezed == headline ? _self.headline : headline // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AnagraficaData].
extension AnagraficaDataPatterns on AnagraficaData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AnagraficaData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AnagraficaData() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AnagraficaData value)  $default,){
final _that = this;
switch (_that) {
case _AnagraficaData():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AnagraficaData value)?  $default,){
final _that = this;
switch (_that) {
case _AnagraficaData() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String nome,  String cognome,  CalendarDate? dataNascita,  String? luogoNascita,  String? nazionalita,  Genere? genere,  StatoCivile? statoCivile,  String? codiceFiscale,  AssetRef? foto,  String? headline)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnagraficaData() when $default != null:
return $default(_that.nome,_that.cognome,_that.dataNascita,_that.luogoNascita,_that.nazionalita,_that.genere,_that.statoCivile,_that.codiceFiscale,_that.foto,_that.headline);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String nome,  String cognome,  CalendarDate? dataNascita,  String? luogoNascita,  String? nazionalita,  Genere? genere,  StatoCivile? statoCivile,  String? codiceFiscale,  AssetRef? foto,  String? headline)  $default,) {final _that = this;
switch (_that) {
case _AnagraficaData():
return $default(_that.nome,_that.cognome,_that.dataNascita,_that.luogoNascita,_that.nazionalita,_that.genere,_that.statoCivile,_that.codiceFiscale,_that.foto,_that.headline);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String nome,  String cognome,  CalendarDate? dataNascita,  String? luogoNascita,  String? nazionalita,  Genere? genere,  StatoCivile? statoCivile,  String? codiceFiscale,  AssetRef? foto,  String? headline)?  $default,) {final _that = this;
switch (_that) {
case _AnagraficaData() when $default != null:
return $default(_that.nome,_that.cognome,_that.dataNascita,_that.luogoNascita,_that.nazionalita,_that.genere,_that.statoCivile,_that.codiceFiscale,_that.foto,_that.headline);case _:
  return null;

}
}

}

/// @nodoc


class _AnagraficaData implements AnagraficaData {
  const _AnagraficaData({required this.nome, required this.cognome, this.dataNascita, this.luogoNascita, this.nazionalita, this.genere, this.statoCivile, this.codiceFiscale, this.foto, this.headline});
  

@override final  String nome;
@override final  String cognome;
@override final  CalendarDate? dataNascita;
@override final  String? luogoNascita;
@override final  String? nazionalita;
@override final  Genere? genere;
@override final  StatoCivile? statoCivile;
@override final  String? codiceFiscale;
@override final  AssetRef? foto;
@override final  String? headline;

/// Create a copy of AnagraficaData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnagraficaDataCopyWith<_AnagraficaData> get copyWith => __$AnagraficaDataCopyWithImpl<_AnagraficaData>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnagraficaData&&(identical(other.nome, nome) || other.nome == nome)&&(identical(other.cognome, cognome) || other.cognome == cognome)&&(identical(other.dataNascita, dataNascita) || other.dataNascita == dataNascita)&&(identical(other.luogoNascita, luogoNascita) || other.luogoNascita == luogoNascita)&&(identical(other.nazionalita, nazionalita) || other.nazionalita == nazionalita)&&(identical(other.genere, genere) || other.genere == genere)&&(identical(other.statoCivile, statoCivile) || other.statoCivile == statoCivile)&&(identical(other.codiceFiscale, codiceFiscale) || other.codiceFiscale == codiceFiscale)&&(identical(other.foto, foto) || other.foto == foto)&&(identical(other.headline, headline) || other.headline == headline));
}


@override
int get hashCode {
    return Object.hash(runtimeType,nome,cognome,dataNascita,luogoNascita,nazionalita,genere,statoCivile,codiceFiscale,foto,headline);
}

@override
String toString() {
    return 'AnagraficaData(nome: $nome, cognome: $cognome, dataNascita: $dataNascita, luogoNascita: $luogoNascita, nazionalita: $nazionalita, genere: $genere, statoCivile: $statoCivile, codiceFiscale: $codiceFiscale, foto: $foto, headline: $headline)';
}


}

/// @nodoc
abstract mixin class _$AnagraficaDataCopyWith<$Res> implements $AnagraficaDataCopyWith<$Res> {
  factory _$AnagraficaDataCopyWith(_AnagraficaData value, $Res Function(_AnagraficaData) _then) = __$AnagraficaDataCopyWithImpl;
@override @useResult
$Res call({
 String nome, String cognome, CalendarDate? dataNascita, String? luogoNascita, String? nazionalita, Genere? genere, StatoCivile? statoCivile, String? codiceFiscale, AssetRef? foto, String? headline
});




}
/// @nodoc
class __$AnagraficaDataCopyWithImpl<$Res>
    implements _$AnagraficaDataCopyWith<$Res> {
  __$AnagraficaDataCopyWithImpl(this._self, this._then);

  final _AnagraficaData _self;
  final $Res Function(_AnagraficaData) _then;

/// Create a copy of AnagraficaData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nome = null,Object? cognome = null,Object? dataNascita = freezed,Object? luogoNascita = freezed,Object? nazionalita = freezed,Object? genere = freezed,Object? statoCivile = freezed,Object? codiceFiscale = freezed,Object? foto = freezed,Object? headline = freezed,}) {
  return _then(_AnagraficaData(
nome: null == nome ? _self.nome : nome // ignore: cast_nullable_to_non_nullable
as String,cognome: null == cognome ? _self.cognome : cognome // ignore: cast_nullable_to_non_nullable
as String,dataNascita: freezed == dataNascita ? _self.dataNascita : dataNascita // ignore: cast_nullable_to_non_nullable
as CalendarDate?,luogoNascita: freezed == luogoNascita ? _self.luogoNascita : luogoNascita // ignore: cast_nullable_to_non_nullable
as String?,nazionalita: freezed == nazionalita ? _self.nazionalita : nazionalita // ignore: cast_nullable_to_non_nullable
as String?,genere: freezed == genere ? _self.genere : genere // ignore: cast_nullable_to_non_nullable
as Genere?,statoCivile: freezed == statoCivile ? _self.statoCivile : statoCivile // ignore: cast_nullable_to_non_nullable
as StatoCivile?,codiceFiscale: freezed == codiceFiscale ? _self.codiceFiscale : codiceFiscale // ignore: cast_nullable_to_non_nullable
as String?,foto: freezed == foto ? _self.foto : foto // ignore: cast_nullable_to_non_nullable
as AssetRef?,headline: freezed == headline ? _self.headline : headline // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$EsperienzaItem {

 String get id; String get ruolo; String get azienda; String? get luogo; ModalitaLavoro? get modalita; TipoContratto? get tipoContratto; YearMonth get startDate; YearMonth? get endDate; bool get current; String? get descrizione;
/// Create a copy of EsperienzaItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EsperienzaItemCopyWith<EsperienzaItem> get copyWith => _$EsperienzaItemCopyWithImpl<EsperienzaItem>(this as EsperienzaItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EsperienzaItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EsperienzaItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.ruolo, _this.ruolo) || other.ruolo == _this.ruolo)&&(identical(other.azienda, _this.azienda) || other.azienda == _this.azienda)&&(identical(other.luogo, _this.luogo) || other.luogo == _this.luogo)&&(identical(other.modalita, _this.modalita) || other.modalita == _this.modalita)&&(identical(other.tipoContratto, _this.tipoContratto) || other.tipoContratto == _this.tipoContratto)&&(identical(other.startDate, _this.startDate) || other.startDate == _this.startDate)&&(identical(other.endDate, _this.endDate) || other.endDate == _this.endDate)&&(identical(other.current, _this.current) || other.current == _this.current)&&(identical(other.descrizione, _this.descrizione) || other.descrizione == _this.descrizione));
}


@override
int get hashCode {
  final _this = this as EsperienzaItem;
  return Object.hash(runtimeType,_this.id,_this.ruolo,_this.azienda,_this.luogo,_this.modalita,_this.tipoContratto,_this.startDate,_this.endDate,_this.current,_this.descrizione);
}

@override
String toString() {
  final _this = this as EsperienzaItem;
  return 'EsperienzaItem(id: ${_this.id}, ruolo: ${_this.ruolo}, azienda: ${_this.azienda}, luogo: ${_this.luogo}, modalita: ${_this.modalita}, tipoContratto: ${_this.tipoContratto}, startDate: ${_this.startDate}, endDate: ${_this.endDate}, current: ${_this.current}, descrizione: ${_this.descrizione})';
}


}

/// @nodoc
abstract mixin class $EsperienzaItemCopyWith<$Res>  {
  factory $EsperienzaItemCopyWith(EsperienzaItem value, $Res Function(EsperienzaItem) _then) = _$EsperienzaItemCopyWithImpl;
@useResult
$Res call({
 String id, String ruolo, String azienda, String? luogo, ModalitaLavoro? modalita, TipoContratto? tipoContratto, YearMonth startDate, YearMonth? endDate, bool current, String? descrizione
});




}
/// @nodoc
class _$EsperienzaItemCopyWithImpl<$Res>
    implements $EsperienzaItemCopyWith<$Res> {
  _$EsperienzaItemCopyWithImpl(this._self, this._then);

  final EsperienzaItem _self;
  final $Res Function(EsperienzaItem) _then;

/// Create a copy of EsperienzaItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ruolo = null,Object? azienda = null,Object? luogo = freezed,Object? modalita = freezed,Object? tipoContratto = freezed,Object? startDate = null,Object? endDate = freezed,Object? current = null,Object? descrizione = freezed,}) {
  return _then(EsperienzaItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ruolo: null == ruolo ? _self.ruolo : ruolo // ignore: cast_nullable_to_non_nullable
as String,azienda: null == azienda ? _self.azienda : azienda // ignore: cast_nullable_to_non_nullable
as String,luogo: freezed == luogo ? _self.luogo : luogo // ignore: cast_nullable_to_non_nullable
as String?,modalita: freezed == modalita ? _self.modalita : modalita // ignore: cast_nullable_to_non_nullable
as ModalitaLavoro?,tipoContratto: freezed == tipoContratto ? _self.tipoContratto : tipoContratto // ignore: cast_nullable_to_non_nullable
as TipoContratto?,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as YearMonth,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as YearMonth?,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,descrizione: freezed == descrizione ? _self.descrizione : descrizione // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EsperienzaItem].
extension EsperienzaItemPatterns on EsperienzaItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EsperienzaItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EsperienzaItem() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EsperienzaItem value)  $default,){
final _that = this;
switch (_that) {
case _EsperienzaItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EsperienzaItem value)?  $default,){
final _that = this;
switch (_that) {
case _EsperienzaItem() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ruolo,  String azienda,  String? luogo,  ModalitaLavoro? modalita,  TipoContratto? tipoContratto,  YearMonth startDate,  YearMonth? endDate,  bool current,  String? descrizione)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EsperienzaItem() when $default != null:
return $default(_that.id,_that.ruolo,_that.azienda,_that.luogo,_that.modalita,_that.tipoContratto,_that.startDate,_that.endDate,_that.current,_that.descrizione);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ruolo,  String azienda,  String? luogo,  ModalitaLavoro? modalita,  TipoContratto? tipoContratto,  YearMonth startDate,  YearMonth? endDate,  bool current,  String? descrizione)  $default,) {final _that = this;
switch (_that) {
case _EsperienzaItem():
return $default(_that.id,_that.ruolo,_that.azienda,_that.luogo,_that.modalita,_that.tipoContratto,_that.startDate,_that.endDate,_that.current,_that.descrizione);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ruolo,  String azienda,  String? luogo,  ModalitaLavoro? modalita,  TipoContratto? tipoContratto,  YearMonth startDate,  YearMonth? endDate,  bool current,  String? descrizione)?  $default,) {final _that = this;
switch (_that) {
case _EsperienzaItem() when $default != null:
return $default(_that.id,_that.ruolo,_that.azienda,_that.luogo,_that.modalita,_that.tipoContratto,_that.startDate,_that.endDate,_that.current,_that.descrizione);case _:
  return null;

}
}

}

/// @nodoc


class _EsperienzaItem implements EsperienzaItem {
  const _EsperienzaItem({required this.id, required this.ruolo, required this.azienda, this.luogo, this.modalita, this.tipoContratto, required this.startDate, this.endDate, this.current = false, this.descrizione});
  

@override final  String id;
@override final  String ruolo;
@override final  String azienda;
@override final  String? luogo;
@override final  ModalitaLavoro? modalita;
@override final  TipoContratto? tipoContratto;
@override final  YearMonth startDate;
@override final  YearMonth? endDate;
@override@JsonKey() final  bool current;
@override final  String? descrizione;

/// Create a copy of EsperienzaItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EsperienzaItemCopyWith<_EsperienzaItem> get copyWith => __$EsperienzaItemCopyWithImpl<_EsperienzaItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EsperienzaItem&&(identical(other.id, id) || other.id == id)&&(identical(other.ruolo, ruolo) || other.ruolo == ruolo)&&(identical(other.azienda, azienda) || other.azienda == azienda)&&(identical(other.luogo, luogo) || other.luogo == luogo)&&(identical(other.modalita, modalita) || other.modalita == modalita)&&(identical(other.tipoContratto, tipoContratto) || other.tipoContratto == tipoContratto)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.current, current) || other.current == current)&&(identical(other.descrizione, descrizione) || other.descrizione == descrizione));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,ruolo,azienda,luogo,modalita,tipoContratto,startDate,endDate,current,descrizione);
}

@override
String toString() {
    return 'EsperienzaItem(id: $id, ruolo: $ruolo, azienda: $azienda, luogo: $luogo, modalita: $modalita, tipoContratto: $tipoContratto, startDate: $startDate, endDate: $endDate, current: $current, descrizione: $descrizione)';
}


}

/// @nodoc
abstract mixin class _$EsperienzaItemCopyWith<$Res> implements $EsperienzaItemCopyWith<$Res> {
  factory _$EsperienzaItemCopyWith(_EsperienzaItem value, $Res Function(_EsperienzaItem) _then) = __$EsperienzaItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String ruolo, String azienda, String? luogo, ModalitaLavoro? modalita, TipoContratto? tipoContratto, YearMonth startDate, YearMonth? endDate, bool current, String? descrizione
});




}
/// @nodoc
class __$EsperienzaItemCopyWithImpl<$Res>
    implements _$EsperienzaItemCopyWith<$Res> {
  __$EsperienzaItemCopyWithImpl(this._self, this._then);

  final _EsperienzaItem _self;
  final $Res Function(_EsperienzaItem) _then;

/// Create a copy of EsperienzaItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ruolo = null,Object? azienda = null,Object? luogo = freezed,Object? modalita = freezed,Object? tipoContratto = freezed,Object? startDate = null,Object? endDate = freezed,Object? current = null,Object? descrizione = freezed,}) {
  return _then(_EsperienzaItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ruolo: null == ruolo ? _self.ruolo : ruolo // ignore: cast_nullable_to_non_nullable
as String,azienda: null == azienda ? _self.azienda : azienda // ignore: cast_nullable_to_non_nullable
as String,luogo: freezed == luogo ? _self.luogo : luogo // ignore: cast_nullable_to_non_nullable
as String?,modalita: freezed == modalita ? _self.modalita : modalita // ignore: cast_nullable_to_non_nullable
as ModalitaLavoro?,tipoContratto: freezed == tipoContratto ? _self.tipoContratto : tipoContratto // ignore: cast_nullable_to_non_nullable
as TipoContratto?,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as YearMonth,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as YearMonth?,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,descrizione: freezed == descrizione ? _self.descrizione : descrizione // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
