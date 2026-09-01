/// Utility di test per PDF generati (ticket 24).
///
/// Non facciamo pixel-perfect rendering: solo che il PDF è un PDF (magic
/// bytes), e che contiene il testo atteso. Per la ricerca testuale i test
/// che la usano devono generare il documento con `compress: false`,
/// altrimenti il contenuto è compresso FlateDecode e non è cercabile come
/// stringa grezza.
library;

import 'dart:convert';
import 'dart:typed_data';

/// True se [bytes] inizia con i magic bytes `%PDF`.
bool hasPdfMagicBytes(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x25 && // %
    bytes[1] == 0x50 && // P
    bytes[2] == 0x44 && // D
    bytes[3] == 0x46; // F

/// Cerca [needle] nel contenuto testuale grezzo di un PDF non compresso
/// (`compress: false`). I comandi di testo PDF sono ASCII/Latin1, quindi
/// basta decodificare come Latin1 e cercare la sottostringa.
bool pdfContainsText(Uint8List bytes, String needle) =>
    latin1.decode(bytes, allowInvalid: true).contains(needle);
