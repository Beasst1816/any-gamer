// lib/services/gamepad_command.dart
//
// Immutable value-object that carries one virtual gamepad event and knows
// how to serialise itself for every transport channel.

import 'dart:typed_data';

import 'package:flutter/foundation.dart'; // @immutable

// ─────────────────────────────────────────────────────────────────────────────
// Command type taxonomy
// ─────────────────────────────────────────────────────────────────────────────

/// Coarse category of a gamepad input event.
enum CommandType {
  button, // digital: A / B / X / Y / shoulder / start / select …
  axis,   // analogue stick axis: LS_X, LS_Y, RS_X, RS_Y, LT, RT
  dpad,   // 8-way hat switch: up / down / left / right / diagonals
  rumble, // force-feedback intensity command
  system,
}

// ─────────────────────────────────────────────────────────────────────────────
// Wire-format constants (keep in sync with host-side decoder)
// ─────────────────────────────────────────────────────────────────────────────

/// USB/BLE frame header byte marking the start of every packet.
const int kFrameHeader = 0xAA;

/// USB/BLE frame footer / end-of-packet sentinel.
const int kFrameFooter = 0x55;

/// Protocol version embedded in every packet.
const int kProtoVersion = 0x01;

// ─────────────────────────────────────────────────────────────────────────────
// GamepadCommand
// ─────────────────────────────────────────────────────────────────────────────

/// A single input event emitted by the virtual gamepad UI layer.
///
/// ### Value ranges
/// | [type]          | [value]                                  |
/// |-----------------|------------------------------------------|
/// | [CommandType.button] | 0 = released, 1 = pressed           |
/// | [CommandType.axis]   | −32 768 … 32 767 (signed 16-bit)    |
/// | [CommandType.dpad]   | 0–7 clockwise from North, 8 = centre |
/// | [CommandType.rumble] | 0 (off) … 255 (max)                  |
@immutable
class GamepadCommand {
  const GamepadCommand({
    required this.type,
    required this.id,
    this.value = 0,
    DateTime? timestamp,
  }) : _timestamp = timestamp;

  /// What kind of input this is.
  final CommandType type;

  /// Human-readable identifier matching the UI widget label.
  /// Examples: `'A'`, `'B'`, `'LT'`, `'LS_X'`, `'DPAD'`, `'RUMBLE_L'`.
  final String id;

  /// Payload value (range depends on [type] — see class doc).
  final int value;

  final DateTime? _timestamp;

  /// Wall-clock timestamp of this event (defaults to now on first access).
  DateTime get timestamp => _timestamp ?? DateTime.now();

  // ── Wi-Fi / TCP serialiser ──────────────────────────────────────────────────

  /// Newline-delimited JSON frame sent over the TCP socket.
  ///
  /// ```json
  /// {"v":1,"type":"button","id":"A","value":1,"ts":1718123456789}
  /// ```
  String toJsonFrame() {
    final map = <String, dynamic>{
      'v': kProtoVersion,
      'type': type.name,
      'id': id,
      'value': value,
      'ts': timestamp.millisecondsSinceEpoch,
    };
    // Manual encoding avoids a hard dependency on dart:convert at model level.
    // If you already import dart:convert elsewhere, replace with jsonEncode(map).
    final parts = map.entries
        .map((e) => '"${e.key}":${e.value is String ? '"${e.value}"' : e.value}')
        .join(',');
    return '{$parts}\n';
  }

  // ── USB / Serial serialiser ─────────────────────────────────────────────────

  /// Compact 8-byte binary frame for USB serial transport.
  ///
  /// ```
  /// Byte  0    : 0xAA  – frame header
  /// Byte  1    : 0x01  – protocol version
  /// Byte  2    : type  – CommandType ordinal (0–3)
  /// Byte  3    : id[0] – first ASCII byte of [id]
  /// Byte  4    : id[1] – second ASCII byte (or 0x00 for single-char IDs)
  /// Byte  5    : MSB   – value >> 8
  /// Byte  6    : LSB   – value & 0xFF
  /// Byte  7    : 0x55  – frame footer / end-of-packet sentinel
  /// ```
  Uint8List toUsbBytes() {
    final clamped = value.clamp(-32768, 32767);
    final msb = (clamped >> 8) & 0xFF;
    final lsb = clamped & 0xFF;

    final idB0 = id.isNotEmpty ? id.codeUnitAt(0) & 0xFF : 0x00;
    final idB1 = id.length > 1 ? id.codeUnitAt(1) & 0xFF : 0x00;

    return Uint8List.fromList([
      kFrameHeader,       // 0xAA
      kProtoVersion,      // 0x01
      type.index,         // 0-3
      idB0,               // id byte 0
      idB1,               // id byte 1
      msb,                // value MSB
      lsb,                // value LSB
      kFrameFooter,       // 0x55
    ]);
  }

  // ── Bluetooth / BLE serialiser ──────────────────────────────────────────────

  /// BLE characteristic write payload.
  ///
  /// Identical wire format to [toUsbBytes] so the host-side decoder is shared.
  /// Use `withoutResponse: true` on non-critical button events for throughput;
  /// flip to `false` for rumble / config commands that need a GATT ACK.
  Uint8List toBleBytes() => toUsbBytes();

  // ── Debug ───────────────────────────────────────────────────────────────────

  @override
  String toString() =>
      'GamepadCommand(type:${type.name}, id:$id, value:$value, '
          'ts:${timestamp.millisecondsSinceEpoch})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is GamepadCommand &&
              other.type == type &&
              other.id == id &&
              other.value == value;

  @override
  int get hashCode => Object.hash(type, id, value);
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience constructors (factory helpers used by the UI layer)
// ─────────────────────────────────────────────────────────────────────────────

extension GamepadCommandFactory on GamepadCommand {
  /// Shorthand for a digital button press (value = 1).
  static GamepadCommand buttonDown(String id) =>
      GamepadCommand(type: CommandType.button, id: id, value: 1);

  /// Shorthand for a digital button release (value = 0).
  static GamepadCommand buttonUp(String id) =>
      GamepadCommand(type: CommandType.button, id: id, value: 0);

  /// Shorthand for an analogue axis update.
  static GamepadCommand axis(String id, int value) =>
      GamepadCommand(type: CommandType.axis, id: id, value: value);

  /// Shorthand for a D-pad direction (0-7 clockwise from North, 8 = centre).
  static GamepadCommand dpad(int direction) =>
      GamepadCommand(type: CommandType.dpad, id: 'DPAD', value: direction);

  /// Shorthand for a rumble intensity command (0–255).
  static GamepadCommand rumble({required int left, required int right}) =>
      GamepadCommand(
          type: CommandType.rumble,
          id: 'RUMBLE',
          value: (left.clamp(0, 15) << 4) | right.clamp(0, 15));

  static GamepadCommand setProfile(String profileId) {
    return GamepadCommand(
      type: CommandType.system,
      id: 'SET_PROFILE',
      value: profileId == 'xbox360' ? 0 : 1,  // 0 = Xbox 360, 1 = DS4
    );
  }
}
