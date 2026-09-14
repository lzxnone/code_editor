import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// 低内存 XZ 流式解压器
///
/// 解决 package:archive 在解码大于 10MB 的 XZ 压缩包时 LZMA 字典无限增长、
/// 频繁触发全量数组复制导致内存爆炸 (OOM) 与卡死的致命缺陷。
///
/// 本解码器采用固定大小环形滑动窗口（Circular Ring Buffer），内存占用严格恒定在
/// 字典大小（如 Debian rootfs 仅需 8MB），并将解压数据分块直接流式写入输出文件 Sink，
/// 内存开销从原版的数百 GB 累计分配降至仅 ~10MB。
class LowMemoryXZDecoder {
  final LowMemoryLzmaDecoder decoder = LowMemoryLzmaDecoder();
  int streamFlags = 0;

  /// 流式解压 XZ 输入流并输出到 [outputSink]
  void decodeToSink(
    InputStreamBase input,
    IOSink outputSink, {
    void Function(int bytesDecompressed, int compressedPosition)? onProgress,
    bool Function()? isCancelled,
  }) {
    var totalDecompressed = 0;

    while (!input.isEOS) {
      if (isCancelled?.call() == true) return;

      // 跳过流间或流末尾的 4 字节对齐填充（NULL 字节）
      while (!input.isEOS && input.peekBytes(1).readByte() == 0) {
        input.skip(1);
      }
      if (input.isEOS) break;

      _readStreamHeader(input);

      while (true) {
        if (isCancelled?.call() == true) return;

        final blockHeader = input.peekBytes(1).readByte();
        if (blockHeader == 0) {
          // 流索引与流尾部
          final indexSize = _readStreamIndex(input);
          _readStreamFooter(input, indexSize);
          break; // 当前流结束
        }

        final blockLength = (blockHeader + 1) * 4;
        _readBlock(input, blockLength, outputSink, (bytes) {
          totalDecompressed += bytes;
          onProgress?.call(totalDecompressed, input.position);
        }, isCancelled);
      }
    }
  }

  void _readStreamHeader(InputStreamBase input) {
    final magic = input.readBytes(6).toUint8List();
    if (magic[0] != 253 ||
        magic[1] != 55 ||
        magic[2] != 122 ||
        magic[3] != 88 ||
        magic[4] != 90 ||
        magic[5] != 0) {
      throw ArchiveException('Invalid XZ stream header signature');
    }
    final header = input.readBytes(2);
    if (header.readByte() != 0) {
      throw ArchiveException('Invalid stream flags');
    }
    streamFlags = header.readByte();
    header.reset();
    final crc = input.readUint32();
    if (getCrc32(header.toUint8List()) != crc) {
      throw ArchiveException('Invalid stream header CRC checksum');
    }
  }

  int _readMultibyteInteger(InputStreamBase input) {
    var val = 0;
    var shift = 0;
    while (true) {
      final b = input.readByte();
      val |= (b & 0x7f) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    return val;
  }

  int _readPadding(InputStreamBase input) {
    var count = 0;
    while (!input.isEOS && (input.position % 4 != 0)) {
      if (input.readByte() != 0) {
        throw ArchiveException('Invalid padding byte');
      }
      count++;
    }
    return count;
  }

  void _readBlock(
    InputStreamBase input,
    int headerLength,
    IOSink sink,
    void Function(int bytes) onChunk,
    bool Function()? isCancelled,
  ) {
    final header = input.readBytes(headerLength - 4);
    header.skip(1); // 跳过 Header Length 字段
    final blockFlags = header.readByte();
    final nFilters = (blockFlags & 0x3) + 1;
    final hasCompressedLength = (blockFlags & 0x40) != 0;
    final hasUncompressedLength = (blockFlags & 0x80) != 0;

    if (hasCompressedLength) _readMultibyteInteger(header);
    if (hasUncompressedLength) _readMultibyteInteger(header);

    final filters = <int>[];
    var dictionarySize = 0;
    for (var i = 0; i < nFilters; i++) {
      final id = _readMultibyteInteger(header);
      final propLen = _readMultibyteInteger(header);
      final props = header.readBytes(propLen).toUint8List();
      if (id == 0x21) {
        final v = props[0];
        if (v > 40) throw ArchiveException('Invalid LZMA dictionary size');
        final mantissa = 2 | (v & 0x1);
        final exponent = (v >> 1) + 11;
        dictionarySize = mantissa << exponent;
        filters.add(id);
        filters.add(dictionarySize);
      } else {
        filters.add(id);
        filters.add(0);
      }
    }
    _readPadding(header);
    header.reset();
    final crc = input.readUint32();
    if (getCrc32(header.toUint8List()) != crc) {
      throw ArchiveException('Invalid block CRC checksum');
    }

    if (filters.length != 2 && filters.first != 0x21) {
      throw ArchiveException('Unsupported filters: $filters');
    }

    decoder.ensureDictionarySize(dictionarySize);
    _readLZMA2(input, sink, onChunk, isCancelled);

    _readPadding(input);

    // 根据 streamFlags 跳过 Check 校验码
    const checkSizes = [0, 4, 4, 4, 8, 8, 8, 16, 16, 16, 32, 32, 32, 64, 64, 64];
    final checkType = streamFlags & 0xf;
    if (checkType < checkSizes.length) {
      final skipBytes = checkSizes[checkType];
      if (skipBytes > 0) input.skip(skipBytes);
    }
  }

  void _readLZMA2(
    InputStreamBase input,
    IOSink sink,
    void Function(int bytes) onChunk,
    bool Function()? isCancelled,
  ) {
    while (true) {
      if (isCancelled?.call() == true) return;

      final control = input.readByte();
      if (control & 0x80 == 0) {
        if (control == 0) {
          // 结束标记
          decoder.reset(resetDictionary: true);
          return;
        } else if (control == 1) {
          // 非压缩数据（重置字典）
          decoder.reset(resetDictionary: true);
          final length = (input.readByte() << 8 | input.readByte()) + 1;
          final bytes = decoder.decodeUncompressed(input.readBytes(length), length);
          sink.add(bytes);
          onChunk(length);
        } else if (control == 2) {
          // 非压缩数据（不重置字典）
          final length = (input.readByte() << 8 | input.readByte()) + 1;
          final bytes = decoder.decodeUncompressed(input.readBytes(length), length);
          sink.add(bytes);
          onChunk(length);
        } else {
          throw ArchiveException('Unknown LZMA2 control code $control');
        }
      } else {
        final reset = (control >> 5) & 0x3;
        final uncompressedLength = ((control & 0x1f) << 16 |
                input.readByte() << 8 |
                input.readByte()) +
            1;
        final compressedLength = (input.readByte() << 8 | input.readByte()) + 1;
        int? literalContextBits;
        int? literalPositionBits;
        int? positionBits;
        if (reset >= 2) {
          var properties = input.readByte();
          positionBits = properties ~/ 45;
          properties -= positionBits * 45;
          literalPositionBits = properties ~/ 9;
          literalContextBits = properties - literalPositionBits * 9;
        }
        if (reset > 0) {
          decoder.reset(
            literalContextBits: literalContextBits,
            literalPositionBits: literalPositionBits,
            positionBits: positionBits,
            resetDictionary: reset == 3,
          );
        }

        final chunk = decoder.decode(input.readBytes(compressedLength), uncompressedLength);
        sink.add(chunk);
        onChunk(uncompressedLength);
      }
    }
  }

  int _readStreamIndex(InputStreamBase input) {
    final startPosition = input.position;
    input.skip(1); // 跳过 index indicator (0x00)
    final nRecords = _readMultibyteInteger(input);
    for (var i = 0; i < nRecords; i++) {
      _readMultibyteInteger(input); // unpaddedLength
      _readMultibyteInteger(input); // uncompressedLength
    }
    _readPadding(input);

    final indexLength = input.position - startPosition;
    input.rewind(indexLength);
    final indexData = input.readBytes(indexLength);

    final crc = input.readUint32();
    if (getCrc32(indexData.toUint8List()) != crc) {
      throw ArchiveException('Invalid stream index CRC checksum');
    }

    return indexLength + 4;
  }

  void _readStreamFooter(InputStreamBase input, int indexSize) {
    final crc = input.readUint32();
    final footer = input.readBytes(6);
    final backwardSize = (footer.readUint32() + 1) * 4;
    if (backwardSize != indexSize) {
      throw ArchiveException('Stream footer has invalid index size');
    }
    if (footer.readByte() != 0) {
      throw ArchiveException('Invalid stream flags');
    }
    final footerFlags = footer.readByte();
    if (footerFlags != streamFlags) {
      throw ArchiveException("Stream footer flags don't match header flags");
    }
    footer.reset();

    if (getCrc32(footer.toUint8List()) != crc) {
      throw ArchiveException('Invalid stream footer CRC checksum');
    }

    final magic = input.readBytes(2).toUint8List();
    if (magic[0] != 89 || magic[1] != 90) { // 'YZ'
      throw ArchiveException('Invalid XZ stream footer signature');
    }
  }
}

/// 采用固定大小环形缓冲区的高性能低内存 LZMA 解码器
class LowMemoryLzmaDecoder {
  final _rc = _LzmaRangeDecoder();

  int _positionBits = 2;
  int _literalPositionBits = 0;
  int _literalContextBits = 3;

  final _nonLiteralTables = <_LzmaRangeDecoderTable>[];
  late final _LzmaRangeDecoderTable _repeatTable;
  late final _LzmaRangeDecoderTable _repeat0Table;
  final _longRepeat0Tables = <_LzmaRangeDecoderTable>[];
  late final _LzmaRangeDecoderTable _repeat1Table;
  late final _LzmaRangeDecoderTable _repeat2Table;

  final _literalTables = <_LzmaRangeDecoderTable>[];
  final _matchLiteralTables0 = <_LzmaRangeDecoderTable>[];
  final _matchLiteralTables1 = <_LzmaRangeDecoderTable>[];

  late final _LzmaLengthDecoder _matchLengthDecoder;
  late final _LzmaLengthDecoder _repeatLengthDecoder;
  late final _LzmaDistanceDecoder _distanceDecoder;

  var _distance0 = 0;
  var _distance1 = 0;
  var _distance2 = 0;
  var _distance3 = 0;

  var state = _LzmaState.litLit;

  Uint8List _dict = Uint8List(0);
  int _dictMask = 0;
  int _writePos = 0;

  LowMemoryLzmaDecoder() {
    for (var i = 0; i < _LzmaState.values.length; i++) {
      _nonLiteralTables.add(_LzmaRangeDecoderTable(_LzmaState.values.length));
    }
    _repeatTable = _LzmaRangeDecoderTable(_LzmaState.values.length);
    _repeat0Table = _LzmaRangeDecoderTable(_LzmaState.values.length);
    for (var i = 0; i < _LzmaState.values.length; i++) {
      _longRepeat0Tables.add(_LzmaRangeDecoderTable(_LzmaState.values.length));
    }
    _repeat1Table = _LzmaRangeDecoderTable(_LzmaState.values.length);
    _repeat2Table = _LzmaRangeDecoderTable(_LzmaState.values.length);

    var positionCount = 1 << _positionBits;
    _matchLengthDecoder = _LzmaLengthDecoder(_rc, positionCount);
    _repeatLengthDecoder = _LzmaLengthDecoder(_rc, positionCount);
    _distanceDecoder = _LzmaDistanceDecoder(_rc);

    reset();
  }

  /// 确保字典大小为大于等于 [dictSize] 的 2 的整数幂，以便通过位掩码快速寻址
  void ensureDictionarySize(int dictSize) {
    var capacity = 4096;
    while (capacity < dictSize) {
      capacity <<= 1;
    }
    if (_dict.length != capacity) {
      _dict = Uint8List(capacity);
      _dictMask = capacity - 1;
      _writePos = 0;
    }
  }

  void reset({
    int? positionBits,
    int? literalPositionBits,
    int? literalContextBits,
    bool resetDictionary = false,
  }) {
    _positionBits = positionBits ?? _positionBits;
    _literalPositionBits = literalPositionBits ?? _literalPositionBits;
    _literalContextBits = literalContextBits ?? _literalContextBits;

    state = _LzmaState.litLit;
    _distance0 = 0;
    _distance1 = 0;
    _distance2 = 0;
    _distance3 = 0;

    final maxLiteralStates = 1 << (_literalPositionBits + _literalContextBits);
    if (_literalTables.length != maxLiteralStates) {
      for (var i = _literalTables.length; i < maxLiteralStates; i++) {
        _literalTables.add(_LzmaRangeDecoderTable(256));
        _matchLiteralTables0.add(_LzmaRangeDecoderTable(256));
        _matchLiteralTables1.add(_LzmaRangeDecoderTable(256));
      }
    }

    for (final table in _nonLiteralTables) {
      table.reset();
    }
    _repeatTable.reset();
    _repeat0Table.reset();
    for (final table in _longRepeat0Tables) {
      table.reset();
    }
    _repeat1Table.reset();
    _repeat2Table.reset();
    for (final table in _literalTables) {
      table.reset();
    }
    for (final table in _matchLiteralTables0) {
      table.reset();
    }
    for (final table in _matchLiteralTables1) {
      table.reset();
    }

    final positionCount = 1 << _positionBits;
    _matchLengthDecoder.reset(positionCount);
    _repeatLengthDecoder.reset(positionCount);
    _distanceDecoder.reset();

    if (resetDictionary) {
      _writePos = 0;
    }
  }

  Uint8List decodeUncompressed(InputStreamBase input, int uncompressedLength) {
    final inputBytes = input.readBytes(uncompressedLength).toUint8List();
    for (var i = 0; i < uncompressedLength; i++) {
      _dict[_writePos & _dictMask] = inputBytes[i];
      _writePos++;
    }
    return inputBytes;
  }

  Uint8List decode(InputStreamBase input, int uncompressedLength) {
    _rc.input = input;
    _rc.initialize();

    final chunkOut = Uint8List(uncompressedLength);
    var chunkOffset = 0;

    while (chunkOffset < uncompressedLength) {
      final positionMask = (1 << _positionBits) - 1;
      final posState = _writePos & positionMask;
      if (_rc.readBit(_nonLiteralTables[state.index], posState) == 0) {
        _decodeLiteral(chunkOut, chunkOffset);
        chunkOffset += 1;
      } else if (_rc.readBit(_repeatTable, state.index) == 0) {
        final len = _decodeMatch(posState, chunkOut, chunkOffset);
        chunkOffset += len;
      } else {
        final len = _decodeRepeat(posState, chunkOut, chunkOffset);
        chunkOffset += len;
      }
    }

    return chunkOut;
  }

  bool _prevPacketIsLiteral() {
    switch (state) {
      case _LzmaState.litLit:
      case _LzmaState.matchLitLit:
      case _LzmaState.repLitLit:
      case _LzmaState.shortRepLitLit:
      case _LzmaState.matchLit:
      case _LzmaState.repLit:
      case _LzmaState.shortRepLit:
        return true;
      case _LzmaState.litMatch:
      case _LzmaState.litLongRep:
      case _LzmaState.litShortRep:
      case _LzmaState.nonLitMatch:
      case _LzmaState.nonLitRep:
        return false;
    }
  }

  void _decodeLiteral(Uint8List chunkOut, int chunkOffset) {
    var prevByte = _writePos > 0 ? _dict[(_writePos - 1) & _dictMask] : 0;
    final low = prevByte >> (8 - _literalContextBits);
    final positionMask = (1 << _literalPositionBits) - 1;
    final high = (_writePos & positionMask) << _literalContextBits;
    final hash = low + high;
    final table = _literalTables[hash];

    int value;
    if (_prevPacketIsLiteral()) {
      value = _rc.readBittree(table, 8);
    } else {
      prevByte = _dict[(_writePos - _distance0 - 1) & _dictMask];

      value = 0;
      var symbolPrefix = 1;
      var matched = true;
      final matchTable0 = _matchLiteralTables0[hash];
      final matchTable1 = _matchLiteralTables1[hash];
      for (var i = 0; i < 8; i++) {
        int b;
        if (matched) {
          final matchBit = (prevByte >> 7) & 0x1;
          prevByte <<= 1;
          b = _rc.readBit(
              matchBit == 0 ? matchTable0 : matchTable1, symbolPrefix | value);
          matched = b == matchBit;
        } else {
          b = _rc.readBit(table, symbolPrefix | value);
        }
        value = (value << 1) | b;
        symbolPrefix <<= 1;
      }
    }

    _dict[_writePos & _dictMask] = value;
    chunkOut[chunkOffset] = value;
    _writePos++;

    switch (state) {
      case _LzmaState.litLit:
      case _LzmaState.matchLitLit:
      case _LzmaState.repLitLit:
      case _LzmaState.shortRepLitLit:
        state = _LzmaState.litLit;
        break;
      case _LzmaState.matchLit:
        state = _LzmaState.matchLitLit;
        break;
      case _LzmaState.repLit:
        state = _LzmaState.repLitLit;
        break;
      case _LzmaState.shortRepLit:
        state = _LzmaState.shortRepLitLit;
        break;
      case _LzmaState.litMatch:
      case _LzmaState.nonLitMatch:
        state = _LzmaState.matchLit;
        break;
      case _LzmaState.litLongRep:
      case _LzmaState.nonLitRep:
        state = _LzmaState.repLit;
        break;
      case _LzmaState.litShortRep:
        state = _LzmaState.shortRepLit;
        break;
    }
  }

  int _decodeMatch(int posState, Uint8List chunkOut, int chunkOffset) {
    final length = _matchLengthDecoder.readLength(posState);
    final distance = _distanceDecoder.readDistance(length);

    _repeatData(distance, length, chunkOut, chunkOffset);

    _distance3 = _distance2;
    _distance2 = _distance1;
    _distance1 = _distance0;
    _distance0 = distance;

    state =
        _prevPacketIsLiteral() ? _LzmaState.litMatch : _LzmaState.nonLitMatch;
    return length;
  }

  int _decodeRepeat(int posState, Uint8List chunkOut, int chunkOffset) {
    int distance;
    if (_rc.readBit(_repeat0Table, state.index) == 0) {
      if (_rc.readBit(_longRepeat0Tables[state.index], posState) == 0) {
        _repeatData(_distance0, 1, chunkOut, chunkOffset);
        state = _prevPacketIsLiteral()
            ? _LzmaState.litShortRep
            : _LzmaState.nonLitRep;
        return 1;
      } else {
        distance = _distance0;
      }
    } else if (_rc.readBit(_repeat1Table, state.index) == 0) {
      distance = _distance1;
      _distance1 = _distance0;
      _distance0 = distance;
    } else if (_rc.readBit(_repeat2Table, state.index) == 0) {
      distance = _distance2;
      _distance2 = _distance1;
      _distance1 = _distance0;
      _distance0 = distance;
    } else {
      distance = _distance3;
      _distance3 = _distance2;
      _distance2 = _distance1;
      _distance1 = _distance0;
      _distance0 = distance;
    }

    var length = _repeatLengthDecoder.readLength(posState);
    _repeatData(distance, length, chunkOut, chunkOffset);

    state =
        _prevPacketIsLiteral() ? _LzmaState.litLongRep : _LzmaState.nonLitRep;
    return length;
  }

  void _repeatData(int distance, int length, Uint8List chunkOut, int chunkOffset) {
    var src = _writePos - distance - 1;
    for (var i = 0; i < length; i++) {
      if (src < 0 || _writePos < 0) {
        break;
      }
      final b = _dict[src & _dictMask];
      _dict[_writePos & _dictMask] = b;
      chunkOut[chunkOffset + i] = b;
      src++;
      _writePos++;
    }
  }
}

enum _LzmaState {
  litLit,
  matchLitLit,
  repLitLit,
  shortRepLitLit,
  matchLit,
  repLit,
  shortRepLit,
  litMatch,
  litLongRep,
  litShortRep,
  nonLitMatch,
  nonLitRep
}

const _probabilityBitCount = 11;
const _probabilityOne = (1 << _probabilityBitCount);
const _probabilityHalf = _probabilityOne ~/ 2;

class _LzmaRangeDecoderTable {
  final Uint16List table;
  _LzmaRangeDecoderTable(int length) : table = Uint16List(length) {
    reset();
  }
  void reset() {
    table.fillRange(0, table.length, _probabilityHalf);
  }
}

class _LzmaRangeDecoder {
  late InputStreamBase _input;
  var range = 0xffffffff;
  var code = 0;

  set input(InputStreamBase value) {
    _input = value;
  }

  void reset() {
    range = 0xffffffff;
    code = 0;
  }

  void initialize() {
    code = 0;
    range = 0xffffffff;
    _input.skip(1);
    for (var i = 0; i < 4; i++) {
      code = (code << 8 | _input.readByte());
    }
  }

  int readBit(_LzmaRangeDecoderTable table, int index) {
    _load();
    final p = table.table[index];
    final bound = (range >> _probabilityBitCount) * p;
    const moveBits = 5;
    if (code < bound) {
      range = bound;
      final oneMinusP = _probabilityOne - p;
      final shifted = oneMinusP >> moveBits;
      table.table[index] += shifted;
      return 0;
    } else {
      range -= bound;
      code -= bound;
      table.table[index] -= p >> moveBits;
      return 1;
    }
  }

  int readBittree(_LzmaRangeDecoderTable table, int count) {
    var value = 0;
    var symbolPrefix = 1;
    for (var i = 0; i < count; i++) {
      final b = readBit(table, symbolPrefix | value);
      value = ((value << 1) | b) & 0xffffffff;
      symbolPrefix = (symbolPrefix << 1) & 0xffffffff;
    }
    return value;
  }

  int readBittreeReverse(_LzmaRangeDecoderTable table, int count) {
    var value = 0;
    var symbolPrefix = 1;
    for (var i = 0; i < count; i++) {
      final b = readBit(table, symbolPrefix | value);
      value = (value | b << i) & 0xffffffff;
      symbolPrefix = (symbolPrefix << 1) & 0xffffffff;
    }
    return value;
  }

  int readDirect(int count) {
    var value = 0;
    for (var i = 0; i < count; i++) {
      _load();
      range >>= 1;
      code -= range;
      value <<= 1;
      if (code & 0x80000000 != 0) {
        code += range;
      } else {
        value++;
      }
    }
    return value;
  }

  void _load() {
    const topValue = 1 << 24;
    if (range < topValue) {
      range <<= 8;
      code = (code << 8) | _input.readByte();
    }
  }
}

class _LzmaLengthDecoder {
  final _LzmaRangeDecoder _input;
  late final _LzmaRangeDecoderTable formTable;
  late final List<_LzmaRangeDecoderTable> shortTables;
  late final List<_LzmaRangeDecoderTable> mediumTables;
  late final _LzmaRangeDecoderTable longTable;

  _LzmaLengthDecoder(this._input, int positionCount) {
    formTable = _LzmaRangeDecoderTable(2);
    shortTables = <_LzmaRangeDecoderTable>[];
    mediumTables = <_LzmaRangeDecoderTable>[];
    longTable = _LzmaRangeDecoderTable(256);
    reset(positionCount);
  }

  void reset(int positionCount) {
    formTable.reset();
    if (positionCount != shortTables.length) {
      shortTables.clear();
      mediumTables.clear();
      for (var i = 0; i < positionCount; i++) {
        shortTables.add(_LzmaRangeDecoderTable(8));
        mediumTables.add(_LzmaRangeDecoderTable(8));
      }
    } else {
      for (var table in shortTables) {
        table.reset();
      }
      for (var table in mediumTables) {
        table.reset();
      }
    }
    longTable.reset();
  }

  int readLength(int posState) {
    if (_input.readBit(formTable, 0) == 0) {
      return 2 + _input.readBittree(shortTables[posState], 3);
    } else if (_input.readBit(formTable, 1) == 0) {
      return 10 + _input.readBittree(mediumTables[posState], 3);
    } else {
      return 18 + _input.readBittree(longTable, 8);
    }
  }
}

class _LzmaDistanceDecoder {
  final int _slotBitCount = 6;
  final int _alignBitCount = 4;
  final _LzmaRangeDecoder _input;
  late final List<_LzmaRangeDecoderTable> _slotTables;
  late final List<_LzmaRangeDecoderTable> _shortTables;
  late final _LzmaRangeDecoderTable _longTable;

  _LzmaDistanceDecoder(this._input) {
    _slotTables = <_LzmaRangeDecoderTable>[];
    var slotSize = 1 << _slotBitCount;
    for (var i = 0; i < 4; i++) {
      _slotTables.add(_LzmaRangeDecoderTable(slotSize));
    }
    _shortTables = <_LzmaRangeDecoderTable>[];
    for (var slot = 4; slot < 14; slot++) {
      var bitCount = (slot ~/ 2) - 1;
      _shortTables.add(_LzmaRangeDecoderTable(1 << bitCount));
    }
    var alignSize = 1 << _alignBitCount;
    _longTable = _LzmaRangeDecoderTable(alignSize);
  }

  void reset() {
    for (var table in _slotTables) {
      table.reset();
    }
    for (var table in _shortTables) {
      table.reset();
    }
    _longTable.reset();
  }

  int readDistance(int length) {
    var distState = length - 2;
    if (distState >= _slotTables.length) {
      distState = _slotTables.length - 1;
    }
    final table = _slotTables[distState];
    final slot = _input.readBittree(table, _slotBitCount);
    if (slot < 4) return slot;

    final prefix = 0x2 | (slot & 0x1);
    final bitCount = (slot ~/ 2) - 1;
    if (slot < 14) {
      final result = (prefix << bitCount) |
          _input.readBittreeReverse(_shortTables[slot - 4], bitCount);
      return result;
    }

    final directCount = bitCount - _alignBitCount;
    final directBits = _input.readDirect(directCount);
    final alignBits = _input.readBittreeReverse(_longTable, _alignBitCount);
    final r1 = (prefix << bitCount) & 0xffffffff;
    final r2 = (directBits << _alignBitCount) & 0xffffffff;
    return r1 | r2 | alignBits;
  }
}
