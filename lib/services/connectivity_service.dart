// lib/services/connectivity_service.dart
//
// Trimode ConnectivityService — routes virtual gamepad commands to the correct
// hardware channel (Wi-Fi TCP, Bluetooth BLE, or USB Serial) and exposes a
// single ChangeNotifier surface for the UI layer.
//
// ── Required pubspec.yaml dependencies ────────────────────────────────────────
//   flutter_blue_plus: ^1.32.0   # BLE
//   usb_serial: ^0.5.1           # USB serial (Android / Windows / Linux)
//   # dart:io is SDK-bundled — no additional dep for TCP
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:usb_serial/usb_serial.dart';

import 'gamepad_command.dart'; // GamepadCommand, CommandType

// ─────────────────────────────────────────────────────────────────────────────
// Public enumerations
// ─────────────────────────────────────────────────────────────────────────────

/// The three transport channels the virtual gamepad can use.
enum ActiveMode { wifi, bluetooth, usb }

/// Fine-grained FSM state exposed to the UI for badge / icon rendering.
enum ServiceConnectionState {
  disconnected,
  scanning,    // BLE scan in progress
  connecting,
  connected,
  reconnecting,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal log model
// ─────────────────────────────────────────────────────────────────────────────

enum LogLevel { info, warning, error }

@immutable
class LogEntry {
  const LogEntry(this.level, this.message, this.timestamp);

  final LogLevel level;
  final String message;
  final DateTime timestamp;

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] [${level.name.toUpperCase()}] $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// ConnectivityService
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton-friendly ChangeNotifier that manages all three transport channels.
///
/// ### Typical usage
/// ```dart
/// // 1. Register with your DI/provider setup:
/// MultiProvider(providers: [
///   ChangeNotifierProvider(create: (_) => ConnectivityService()),
/// ])
///
/// // 2. Switch mode and connect:
/// final svc = context.read<ConnectivityService>();
/// await svc.setMode(ActiveMode.bluetooth);
/// await svc.connect();
///
/// // 3. Send commands from any button widget:
/// await svc.sendCommand(GamepadCommandFactory.buttonDown('A'));
/// ```
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({
    String wifiHost = '10.42.224.212',
    int wifiPort = 5000,
    String? bleDeviceName, // null → first device advertising kBleServiceUuid
  })  : _wifiHost = wifiHost,
        _wifiPort = wifiPort,
        _bleTargetName = bleDeviceName;

  // ══════════════════════════════════════════════════════════════════════════
  //  Public state (consumed by UI via context.watch / Consumer)
  // ══════════════════════════════════════════════════════════════════════════

  ActiveMode _activeMode = ActiveMode.wifi;

  /// Currently selected transport channel.
  ActiveMode get activeMode => _activeMode;

  ServiceConnectionState _connState = ServiceConnectionState.disconnected;

  /// Fine-grained FSM state — use for icons, progress indicators, badges.
  ServiceConnectionState get connectionState => _connState;

  /// Convenience: true only when fully established and ready to send.
  bool get isConnected => _connState == ServiceConnectionState.connected;

  String _statusMessage = 'Idle';

  /// Human-readable one-liner describing the current state.
  String get statusMessage => _statusMessage;

  /// Rotating buffer of the last [_maxLogEntries] events.
  final List<LogEntry> _entries = [];
  List<LogEntry> get log => List.unmodifiable(_entries);
  static const int _maxLogEntries = 150;

  // ══════════════════════════════════════════════════════════════════════════
  //  Mode switching
  // ══════════════════════════════════════════════════════════════════════════

  /// Switch the active transport channel.
  ///
  /// Tears down any live connection before switching; safe to await.
  Future<void> setMode(ActiveMode mode) async {
    if (mode == _activeMode) return;
    _record('Mode change: ${_activeMode.name} → ${mode.name}');
    await disconnect();
    _activeMode = mode;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Unified connect / disconnect / send  (public API)
  // ══════════════════════════════════════════════════════════════════════════

  /// Open a connection on the active channel.  Idempotent while [isConnected].
  Future<void> connect() async {
    if (_connState == ServiceConnectionState.connecting ||
        _connState == ServiceConnectionState.scanning) {
      return;
    }
    _setState(ServiceConnectionState.connecting,
        'Connecting via ${_activeMode.name}…');

    try {
      switch (_activeMode) {
        case ActiveMode.wifi:
          await _wifiConnect();
        case ActiveMode.bluetooth:
          await _bleConnect();
        case ActiveMode.usb:
          await _usbConnect();
      }
      _setState(ServiceConnectionState.connected,
          'Connected · ${_activeMode.name.toUpperCase()}');
    } on TimeoutException catch (e) {
      _setState(ServiceConnectionState.error, 'Timeout: $e');
      _record('Timeout during connect', level: LogLevel.error);
    } catch (e, st) {
      _setState(ServiceConnectionState.error, 'Error: $e');
      _record('Connect error: $e\n$st', level: LogLevel.error);
    }
  }

  /// Gracefully close the active channel.
  Future<void> disconnect() async {
    _wifiCancelReconnect();
    switch (_activeMode) {
      case ActiveMode.wifi:
        await _wifiDisconnect();
      case ActiveMode.bluetooth:
        await _bleDisconnect();
      case ActiveMode.usb:
        await _usbDisconnect();
    }
    _setState(ServiceConnectionState.disconnected, 'Disconnected');
  }

  /// Route [command] to the correct channel send method.
  ///
  /// Silently dropped if not [isConnected]; logs a warning in debug mode.
  Future<void> sendCommand(GamepadCommand command) async {
    if (!isConnected) {
      _record('sendCommand called while not connected — dropped: $command',
          level: LogLevel.warning);
      return;
    }
    try {
      switch (_activeMode) {
        case ActiveMode.wifi:
          await _wifiSend(command);
        case ActiveMode.bluetooth:
          await _bleSend(command);
        case ActiveMode.usb:
          await _usbSend(command);
      }
    } catch (e) {
      _record('Send error: $e', level: LogLevel.error);
      await _onTransportError(e);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ──  Wi-Fi / TCP channel  ────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  // ── Configuration ──────────────────────────────────────────────────────────

  final String _wifiHost;
  final int _wifiPort;

  static const Duration _wifiConnectTimeout  = Duration(seconds: 5);
  static const Duration _wifiReconnectDelay  = Duration(seconds: 3);
  static const int      _wifiMaxRetries      = 5;

  // ── State ──────────────────────────────────────────────────────────────────

  Socket? _tcpSocket;
  StreamSubscription<Uint8List>? _tcpRxSub;
  Timer?  _wifiReconnectTimer;
  int     _wifiRetryCount = 0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Opens a TCP socket to [_wifiHost]:[_wifiPort].
  ///
  /// Enables `TCP_NODELAY` to minimise latency for small command frames.
  Future<void> _wifiConnect() async {
    _record('TCP → $_wifiHost:$_wifiPort');
    _tcpSocket = await Socket.connect(
      _wifiHost,
      _wifiPort,
      timeout: _wifiConnectTimeout,
    );
    _tcpSocket!.setOption(SocketOption.tcpNoDelay, true);
    _tcpRxSub = _tcpSocket!.listen(
      _onWifiData,
      onError: _onWifiError,
      onDone:  _onWifiDone,
      cancelOnError: false,
    );
    _wifiRetryCount = 0;
    _record('TCP socket established ($_wifiHost:$_wifiPort)');
  }

  /// Sends [command] as newline-delimited JSON over the open TCP socket.
  ///
  /// The newline delimiter allows the host to use a simple `readline()` reader.
  Future<void> _wifiSend(GamepadCommand command) async {
    final payload = command.toJsonFrame(); // already contains trailing '\n'
    _tcpSocket!.add(utf8.encode(payload));
    await _tcpSocket!.flush();
    _record('WiFi TX: ${payload.trimRight()}');
  }

  Future<void> _wifiDisconnect() async {
    _wifiCancelReconnect();
    await _tcpRxSub?.cancel();
    _tcpRxSub = null;
    try {
      await _tcpSocket?.close();
    } catch (_) {/* already closed */}
    _tcpSocket = null;
    _record('TCP socket closed');
  }

  // ── Inbound data ───────────────────────────────────────────────────────────

  /// Handle bytes arriving from the TCP host (ACKs, haptic triggers, etc.).
  void _onWifiData(Uint8List data) {
    final text = utf8.decode(data, allowMalformed: true).trim();
    _record('WiFi RX: $text');
    // TODO: parse host → controller messages here (e.g. rumble requests).
    // Each newline-delimited JSON object can be decoded with jsonDecode(text).
  }

  // ── Error / reconnect handling ─────────────────────────────────────────────

  void _onWifiError(Object error) {
    _record('TCP error: $error', level: LogLevel.error);
    _scheduleWifiReconnect();
  }

  void _onWifiDone() {
    _record('TCP remote closed connection', level: LogLevel.warning);
    _setState(ServiceConnectionState.reconnecting, 'Wi-Fi link lost — retrying…');
    _scheduleWifiReconnect();
  }

  void _scheduleWifiReconnect() {
    if (_wifiRetryCount >= _wifiMaxRetries) {
      _setState(ServiceConnectionState.error,
          'Wi-Fi: max retries ($_wifiMaxRetries) reached');
      return;
    }
    _wifiRetryCount++;
    final delay = _wifiReconnectDelay * _wifiRetryCount; // linear back-off
    _record('Wi-Fi reconnect in ${delay.inSeconds}s '
        '(attempt $_wifiRetryCount/$_wifiMaxRetries)');
    _wifiReconnectTimer = Timer(delay, connect);
  }

  void _wifiCancelReconnect() {
    _wifiReconnectTimer?.cancel();
    _wifiReconnectTimer = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ──  Bluetooth / BLE channel  ────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  // ── GATT profile UUIDs (override to match your firmware) ──────────────────

  /// Primary GATT service that hosts the gamepad characteristic.
  static const String kBleServiceUuid =
      '12345678-1234-1234-1234-1234567890ab';

  /// Writable characteristic that accepts [GamepadCommand.toBleBytes()] frames.
  static const String kBleCommandCharUuid =
      'abcdef01-1234-1234-1234-abcdefabcdef';

  /// Optional: subscribe to this notify characteristic for ACKs / rumble events.
  static const String kBleNotifyCharUuid =
      'abcdef02-1234-1234-1234-abcdefabcdef';

  // ── Configuration ──────────────────────────────────────────────────────────

  final String? _bleTargetName;

  static const Duration _bleScanTimeout    = Duration(seconds: 10);
  static const Duration _bleConnectTimeout = Duration(seconds: 15);

  // ── State ──────────────────────────────────────────────────────────────────

  BluetoothDevice?         _bleDevice;
  BluetoothCharacteristic? _bleCmdChar;
  BluetoothCharacteristic? _bleNotifyChar;

  StreamSubscription<BluetoothConnectionState>? _bleConnStateSub;
  StreamSubscription<List<ScanResult>>?         _bleScanSub;
  StreamSubscription<List<int>>?                _bleNotifySub;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> _bleConnect() async {
    _setState(ServiceConnectionState.scanning, 'BLE: scanning…');

    // ── 1. Scan for the peripheral ──────────────────────────────────────────
    final completer = Completer<BluetoothDevice>();

    await FlutterBluePlus.startScan(
      withServices: [Guid(kBleServiceUuid)],
      timeout: _bleScanTimeout,
    );

    _bleScanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final nameMatch = _bleTargetName == null ||
            r.device.platformName == _bleTargetName;
        if (nameMatch && !completer.isCompleted) {
          FlutterBluePlus.stopScan();
          completer.complete(r.device);
          return;
        }
      }
    });

    _bleDevice = await completer.future.timeout(
      _bleScanTimeout,
      onTimeout: () => throw TimeoutException('BLE: no device found in scan window'),
    );

    // ── 2. Connect to the peripheral ────────────────────────────────────────
    _record('BLE: connecting to ${_bleDevice!.platformName}…');
    await _bleDevice!.connect(
      timeout: _bleConnectTimeout,
      autoConnect: false,
    );
    _record('BLE: connected to ${_bleDevice!.platformName}');

    // ── 3. Monitor connection state ─────────────────────────────────────────
    _bleConnStateSub = _bleDevice!.connectionState.listen(_onBleConnectionState);

    // ── 4. Discover characteristics ─────────────────────────────────────────
    await _discoverBleCharacteristics();
  }

  /// Walk the GATT table and cache the command + notify characteristics.
  Future<void> _discoverBleCharacteristics() async {
    final services = await _bleDevice!.discoverServices();
    for (final svc in services) {
      if (svc.uuid.str.toLowerCase() == kBleServiceUuid.toLowerCase()) {
        for (final char in svc.characteristics) {
          final uuid = char.uuid.str.toLowerCase();
          if (uuid == kBleCommandCharUuid.toLowerCase()) {
            _bleCmdChar = char;
            _record('BLE: command characteristic found');
          } else if (uuid == kBleNotifyCharUuid.toLowerCase()) {
            _bleNotifyChar = char;
            // Subscribe to host→controller notifications.
            await char.setNotifyValue(true);
            _bleNotifySub = char.lastValueStream.listen(_onBleNotification);
            _record('BLE: notify characteristic subscribed');
          }
        }
      }
    }
    if (_bleCmdChar == null) {
      throw StateError('BLE: command characteristic not found in GATT table');
    }
  }

  Future<void> _bleSend(GamepadCommand command) async {
    if (_bleCmdChar == null) throw StateError('BLE: characteristic not ready');

    final bytes = command.toBleBytes();

    // Use withoutResponse for high-frequency axis / button events (latency ↓).
    // Flip to withoutResponse:false for config / rumble (reliability ↑).
    final withoutResponse = command.type != CommandType.rumble;

    await _bleCmdChar!.write(bytes, withoutResponse: withoutResponse);
    _record('BLE TX [${withoutResponse ? "NoAck" : "Ack"}]: '
        '${_hexDump(bytes)}');
  }

  Future<void> _bleDisconnect() async {
    await _bleScanSub?.cancel();
    await _bleNotifySub?.cancel();
    await _bleConnStateSub?.cancel();
    try {
      await _bleDevice?.disconnect();
    } catch (_) {/* ignore */}
    _bleDevice       = null;
    _bleCmdChar      = null;
    _bleNotifyChar   = null;
    _bleScanSub      = null;
    _bleNotifySub    = null;
    _bleConnStateSub = null;
    _record('BLE disconnected');
  }

  // ── Inbound / event handlers ───────────────────────────────────────────────

  void _onBleConnectionState(BluetoothConnectionState state) {
    _record('BLE state → ${state.name}');
    if (state == BluetoothConnectionState.disconnected) {
      _bleCmdChar = null;
      _setState(ServiceConnectionState.disconnected, 'BLE link dropped');
    }
  }

  /// Handle incoming notifications from the host peripheral
  /// (ACKs, battery level, haptic triggers, mode confirmations…).
  void _onBleNotification(List<int> data) {
    _record('BLE NOTIFY: ${_hexDump(Uint8List.fromList(data))}');
    // TODO: frame parse — check header byte, dispatch on type nibble.
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ──  USB / Serial channel  ───────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  // ── Configuration ──────────────────────────────────────────────────────────

  static const int _usbBaudRate = 115200;
  static const int _usbDataBits = UsbPort.DATABITS_8;
  static const int _usbStopBits = UsbPort.STOPBITS_1;
  static const int _usbParity   = UsbPort.PARITY_NONE;
  static const int _usbFlowCtrl = UsbPort.FLOW_CONTROL_OFF;

  // Filter for a specific device when multiple are attached.
  // Set to null to pick the first available port.
  static const int? kTargetVendorId  = null; // e.g. 0x1234
  static const int? kTargetProductId = null; // e.g. 0x5678

  // ── State ──────────────────────────────────────────────────────────────────

  UsbPort?                        _usbPort;
  StreamSubscription<Uint8List>?  _usbRxSub;
  StreamSubscription<UsbEvent>? _usbEventSub;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> _usbConnect() async {
    // ── 1. Enumerate attached devices ───────────────────────────────────────
    final devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      throw StateError('USB: no serial devices attached');
    }

    final device = kTargetVendorId != null
        ? devices.firstWhere(
          (d) => d.vid == kTargetVendorId && d.pid == kTargetProductId,
      orElse: () =>
      throw StateError('USB: target VID/PID device not found'),
    )
        : devices.first;

    _record('USB: device "${device.productName}" '
        '[VID:0x${device.vid?.toRadixString(16)} '
        'PID:0x${device.pid?.toRadixString(16)}]');

    // ── 2. Open the port ────────────────────────────────────────────────────
    _usbPort = await device.create();
    if (_usbPort == null) throw StateError('USB: failed to create UsbPort');

    final opened = await _usbPort!.open();
    if (!opened) throw StateError('USB: failed to open port');

    // ── 3. Configure UART parameters ────────────────────────────────────────
    await _usbPort!.setPortParameters(
      _usbBaudRate,
      _usbDataBits,
      _usbStopBits,
      _usbParity,
    );
    await _usbPort!.setFlowControl(_usbFlowCtrl);
    _record('USB: port open @ $_usbBaudRate baud 8-N-1');

    // ── 4. Subscribe to RX stream ───────────────────────────────────────────
    _usbRxSub = _usbPort!.inputStream?.listen(
      _onUsbData,
      onError: _onUsbError,
      cancelOnError: false,
    );

    // ── 5. Watch for hot-unplug events ──────────────────────────────────────
    _usbEventSub = UsbSerial.usbEventStream?.listen(_onUsbEvent);
  }

  /// Send [command] as a compact 8-byte binary frame over USB serial.
  Future<void> _usbSend(GamepadCommand command) async {
    if (_usbPort == null) throw StateError('USB: port not open');
    final bytes = command.toUsbBytes();
    await _usbPort!.write(bytes);
    _record('USB TX: ${_hexDump(bytes)}');
  }

  Future<void> _usbDisconnect() async {
    await _usbRxSub?.cancel();
    await _usbEventSub?.cancel();
    _usbRxSub    = null;
    _usbEventSub = null;
    try {
      await _usbPort?.close();
    } catch (_) {/* ignore */}
    _usbPort = null;
    _record('USB port closed');
  }

  // ── Inbound / event handlers ───────────────────────────────────────────────

  /// Handle inbound bytes from the USB host
  /// (ACK frames, rumble commands, firmware version responses…).
  void _onUsbData(Uint8List data) {
    _record('USB RX [${data.length}B]: ${_hexDump(data)}');

    // TODO: stateful frame reassembler goes here.
    // Pattern: buffer bytes until 0xAA header + 0x55 footer are both seen,
    // then dispatch the complete frame to your command handler.
  }

  void _onUsbError(Object error) {
    _record('USB error: $error', level: LogLevel.error);
    _setState(ServiceConnectionState.error, 'USB error: $error');
  }

  /// Typed adapter: receives the structured [UsbEvent] from
  /// [UsbSerial.usbEventStream] and delegates to [_onUsbDeviceEvent]
  /// with the normalised device list.
  ///
  /// [UsbEvent] carries:
  ///   - [UsbEvent.event]  - "ACTION_USB_ATTACHED" or "ACTION_USB_DETACHED"
  ///   - [UsbEvent.device] - the single [UsbDevice] that changed (may be null)
  void _onUsbEvent(UsbEvent event) {
    _record('USB event: ${event.event} '
        '- ${event.device?.productName ?? "unknown device"}');
    // Build a list compatible with _onUsbDeviceEvent:
    // empty list on detach signals removal; device wrapped in list on attach.
    final isDetach = event.event == UsbEvent.ACTION_USB_DETACHED;
    final devices  = isDetach || event.device == null
        ? <UsbDevice>[]
        : [event.device!];
    _onUsbDeviceEvent(devices);
  }

  /// React to USB attach / detach events fired by the OS.
  void _onUsbDeviceEvent(List<UsbDevice> devices) {
    if (_usbPort != null && devices.isEmpty) {
      _record('USB device removed', level: LogLevel.warning);
      _setState(ServiceConnectionState.disconnected, 'USB device unplugged');
    } else if (devices.isNotEmpty) {
      _record('USB device list updated (${devices.length} device(s))');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Shared helpers
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _onTransportError(Object error) async {
    _setState(ServiceConnectionState.error, 'Transport error: $error');
    // Auto-reconnect only for Wi-Fi; BLE and USB require user action.
    if (_activeMode == ActiveMode.wifi) _scheduleWifiReconnect();
  }

  void _setState(ServiceConnectionState state, String message) {
    _connState = state;
    _statusMessage = message;
    _record(message);
    notifyListeners();
  }

  void _record(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(level, message, DateTime.now());
    debugPrint(entry.toString());
    _entries.add(entry);
    if (_entries.length > _maxLogEntries) _entries.removeAt(0);
    // Callers that change _connState call _setState which calls notifyListeners;
    // plain log entries don't trigger a rebuild to avoid excessive repaints.
  }

  /// Format a byte array as `AA BB CC …` hex string (truncated at 24 bytes).
  static String _hexDump(Uint8List bytes, {int maxBytes = 24}) {
    final slice = bytes.length > maxBytes ? bytes.sublist(0, maxBytes) : bytes;
    final hex = slice.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    return bytes.length > maxBytes ? '$hex …(${bytes.length}B)' : hex;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Disposal
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> dispose() async {
    // Cancel all timers and subscriptions before calling super.
    _wifiCancelReconnect();
    await _tcpRxSub?.cancel();
    await _tcpSocket?.close();

    await _bleScanSub?.cancel();
    await _bleNotifySub?.cancel();
    await _bleConnStateSub?.cancel();
    await _bleDevice?.disconnect();

    await _usbRxSub?.cancel();
    await _usbEventSub?.cancel();
    await _usbPort?.close();

    super.dispose();
  }
}