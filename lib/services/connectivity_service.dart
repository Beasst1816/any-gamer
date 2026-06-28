// lib/services/connectivity_service.dart
//
// Tri-mode ConnectivityService — routes virtual gamepad commands to Wi-Fi TCP,
// Bluetooth Classic SPP, or USB (ADB tunnel), and exposes a ChangeNotifier
// surface for the UI.
//
// ── pubspec.yaml dependencies ─────────────────────────────────────────────────
//   flutter_bluetooth_serial: ^0.4.0   # Classic BT SPP
//   usb_serial: ^0.5.1                 # USB hot-plug events (Android)
//   # dart:io — SDK-bundled
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import 'gamepad_command.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public enumerations
// ─────────────────────────────────────────────────────────────────────────────

/// The three transport channels the virtual gamepad can use.
enum ActiveMode { wifi, bluetooth, usb }

/// Fine-grained FSM state exposed to the UI for badge / icon rendering.
enum ServiceConnectionState {
  disconnected,
  scanning,
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
class ConnectivityService extends ChangeNotifier {
  bool _isInputPaused = false;
  bool _userRequestedDisconnect = false;
  Timer? _heartbeatTimer;

  ConnectivityService({String wifiHost = '192.168.1.100', int wifiPort = 5000})
    : _wifiHost = wifiHost,
      _wifiPort = wifiPort {
    _initUsbEventListener();
  }

  /// Start listening for USB hot-plug events at construction time so attach
  /// events are received before connect() is called.
  void _initUsbEventListener() {
    _usbEventSub = UsbSerial.usbEventStream?.listen(_onUsbEvent);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Public state
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
  Future<void> setMode(ActiveMode mode) async {
    if (mode == _activeMode) return;
    _record('Mode change: ${_activeMode.name} → ${mode.name}');
    await disconnect();
    _activeMode = mode;
    notifyListeners();
  }

  void updateWifiTarget(String host, int port) {
    if (_wifiHost == host && _wifiPort == port) return;
    _wifiHost = host;
    _wifiPort = port;
    if (_activeMode == ActiveMode.wifi && isConnected) {
      disconnect().then((_) => connect());
    }
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
    _userRequestedDisconnect = false;
    _setState(
      ServiceConnectionState.connecting,
      'Connecting via ${_activeMode.name}…',
    );

    try {
      switch (_activeMode) {
        case ActiveMode.wifi:
          await _wifiConnect();
        case ActiveMode.bluetooth:
          await _bleConnect();
        case ActiveMode.usb:
          await _usbConnect();
      }
      _setState(
        ServiceConnectionState.connected,
        'Connected · ${_activeMode.name.toUpperCase()}',
      );
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
    _userRequestedDisconnect = true;
    _heartbeatTimer?.cancel();
    _isInputPaused = false;
    _wifiCancelReconnect();
    switch (_activeMode) {
      case ActiveMode.wifi:
        await _wifiDisconnect();
      case ActiveMode.bluetooth:
        await _bleDisconnect();
      case ActiveMode.usb:
        // USB (ADB) tunnels over TCP — tear down the socket, then re-arm
        // the hot-plug listener for the next attach event.
        await _wifiDisconnect();
        _initUsbEventListener();
    }
    _setState(ServiceConnectionState.disconnected, 'Disconnected');
  }

  /// Route [command] to the correct channel send method.
  Future<void> sendCommand(GamepadCommand command) async {
    if (_isInputPaused) return;
    if (!isConnected) {
      _record(
        'sendCommand called while not connected — dropped: $command',
        level: LogLevel.warning,
      );
      return;
    }
    try {
      switch (_activeMode) {
        case ActiveMode.wifi:
        case ActiveMode.usb:
          // USB (ADB) mode shares the same TCP stack as Wi-Fi.
          _wifiSend(command);
        case ActiveMode.bluetooth:
          _bleSend(command);
      }
    } catch (e) {
      _record('Send error: $e', level: LogLevel.error);
      await _onTransportError(e);
    }
  }

  // C6: pauseInput() sends PING heartbeat only for TCP-based modes (wifi/usb).
  // BT SPP maintains its own link-layer keep-alive; a TCP PING would be
  // meaningless on a BluetoothConnection output sink.
  void pauseInput() {
    if (connectionState != ServiceConnectionState.connected) return;
    _isInputPaused = true;
    _heartbeatTimer?.cancel();
    if (_activeMode == ActiveMode.wifi || _activeMode == ActiveMode.usb) {
      // Keep-alive packet every 5 s to prevent TCP idle timeouts.
      // Use socket.add(utf8.encode()) — NOT socket.write() — to avoid latin-1 encoding.
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _tcpSocket?.add(
          utf8.encode('{"type":"system","id":"PING","value":0}\n'),
        );
      });
    }
    // BT mode: no heartbeat needed — RFCOMM keep-alive is handled at the
    // Bluetooth stack level. Skipping avoids spurious allSent futures.
  }

  // C4: resumeInput() re-connects for BOTH wifi AND usb modes (both use TCP).
  void resumeInput() {
    _isInputPaused = false;
    _heartbeatTimer?.cancel();
    if (!isConnected &&
        (_activeMode == ActiveMode.wifi || _activeMode == ActiveMode.usb)) {
      _wifiRetryCount = 0;
      connect();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Wi-Fi / TCP
  //
  //  Happy path: UDP broadcast discovers server → TCP connect → 60Hz commands.
  //  Main failure: server unreachable → exponential back-off reconnect (max 5).
  // ══════════════════════════════════════════════════════════════════════════

  String _wifiHost;
  int _wifiPort;

  static const Duration _wifiConnectTimeout = Duration(seconds: 5);
  static const Duration _wifiReconnectDelay = Duration(seconds: 3);
  static const int _wifiMaxRetries = 5;

  static const int _udpDiscoveryPort = 5354;
  static const Duration _udpDiscoveryTimeout = Duration(seconds: 5);

  Socket? _tcpSocket;
  StreamSubscription<Uint8List>? _tcpRxSub;
  Timer? _wifiReconnectTimer;
  int _wifiRetryCount = 0;
  bool _wifiReconnectPending = false;

  Future<void> _tryUdpDiscovery() async {
    _record('UDP: listening for BeastReceiver on port $_udpDiscoveryPort…');
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _udpDiscoveryPort,
      );

      final datagram = await socket
          .where((event) => event == RawSocketEvent.read)
          .map((_) => socket!.receive())
          .where((dg) => dg != null)
          .first
          .timeout(_udpDiscoveryTimeout);

      // Server IP comes directly from the UDP source address — no parsing required.
      final serverIp = datagram!.address.address;

      int? serverPort;
      try {
        final json =
            jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        if (json['service'] == 'ctrlforge') serverPort = json['port'] as int?;
      } catch (_) {
        // Malformed payload — IP from source address is still valid.
      }

      _wifiHost = serverIp;
      if (serverPort != null) _wifiPort = serverPort;
      _record('UDP: found server → $_wifiHost:$_wifiPort');
    } on TimeoutException {
      _record(
        'UDP: no broadcast in ${_udpDiscoveryTimeout.inSeconds}s — using saved host',
        level: LogLevel.warning,
      );
    } catch (e) {
      _record(
        'UDP: discovery error ($e) — using saved host',
        level: LogLevel.warning,
      );
    } finally {
      socket?.close();
    }
  }

  Future<void> _wifiConnect() async {
    // Tear down any stale socket from a previous failed attempt.
    if (_tcpSocket != null) {
      await _tcpRxSub?.cancel();
      _tcpRxSub = null;
      try {
        await _tcpSocket?.close();
      } catch (_) {}
      _tcpSocket = null;
    }

    await _tryUdpDiscovery();

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
      onDone: _onWifiDone,
      cancelOnError: false,
    );
    _wifiRetryCount = 0;
    _record('TCP socket established ($_wifiHost:$_wifiPort)');
  }

  void _wifiSend(GamepadCommand command) {
    final socket = _tcpSocket;
    if (socket == null) {
      _record('Wi-Fi send: socket null — dropped', level: LogLevel.warning);
      return;
    }
    socket.add(utf8.encode(command.toJsonFrame()));
  }

  Future<void> _wifiDisconnect() async {
    _wifiCancelReconnect();
    await _tcpRxSub?.cancel();
    _tcpRxSub = null;
    try {
      await _tcpSocket?.close();
    } catch (_) {}
    _tcpSocket = null;
    _record('TCP socket closed');
  }

  void _onWifiData(Uint8List data) {
    _record('WiFi RX: ${utf8.decode(data, allowMalformed: true).trim()}');
  }

  void _onWifiError(Object error) {
    _record('TCP error: $error', level: LogLevel.error);
    _scheduleWifiReconnect();
  }

  void _onWifiDone() {
    _record('TCP remote closed connection', level: LogLevel.warning);
    _setState(
      ServiceConnectionState.reconnecting,
      'Wi-Fi link lost — retrying…',
    );
    _scheduleWifiReconnect();
  }

  void _scheduleWifiReconnect() {
    // Guard against duplicate timers when both onError and onDone fire for the
    // same RST.
    if (_wifiReconnectPending) return;
    if (_wifiRetryCount >= _wifiMaxRetries) {
      _setState(
        ServiceConnectionState.error,
        'Wi-Fi: max retries ($_wifiMaxRetries) reached',
      );
      return;
    }
    _wifiReconnectPending = true;
    _wifiRetryCount++;
    final delay = _wifiReconnectDelay * _wifiRetryCount;
    _record(
      'Wi-Fi reconnect in ${delay.inSeconds}s '
      '(attempt $_wifiRetryCount/$_wifiMaxRetries)',
    );
    _wifiReconnectTimer = Timer(delay, () {
      _wifiReconnectPending = false;
      connect();
    });
  }

  void _wifiCancelReconnect() {
    _wifiReconnectPending = false;
    _wifiReconnectTimer?.cancel();
    _wifiReconnectTimer = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Bluetooth Classic SPP
  //
  //  Happy path: UI calls getBondedDevices() → picker → setBluetoothTarget()
  //              → connect() → SPP RFCOMM link → fire-and-forget 60Hz sends.
  //  Main failure: device out of range → toAddress() hangs → 10s timeout
  //                triggers StateError → exponential retry via cancellable Timer.
  //
  // FlutterBluetoothSerial does NOT have a pickDevice() method.
  // Device selection is a two-step UI flow:
  //   1. UI calls getBondedDevices() to get the paired device list.
  //   2. UI shows its own picker, then calls setBluetoothTarget(address, name).
  //   3. UI calls connect() — _bleConnect() uses the stored address.
  // ──────────────────────────────────────────────────────────────────────────

  BluetoothConnection? _btConnection;
  int _bleRetryCount = 0;
  static const int _maxBleRetries = 6; // 500 ms → 1 s → 2 s → 4 s → 8 s → 16 s
  static const Duration _bleConnectTimeout = Duration(seconds: 10);

  // C3: stored Timer so _bleDisconnect() can cancel any pending retry.
  Timer? _bleReconnectTimer;

  /// Address and display name of the device selected by the UI.
  String? _bleTargetAddress;
  String? _bleTargetName;

  // ── Public BT helpers for the UI layer ─────────────────────────────────────

  /// Returns all Classic BT devices already bonded (paired) to this phone.
  ///
  /// Usage in UI:
  /// ```dart
  /// final devices = await service.getBondedDevices();
  /// // … show picker …
  /// service.setBluetoothTarget(chosen.address, chosen.name);
  /// service.connect();
  /// ```
  Future<List<BluetoothDevice>> getBondedDevices() =>
      FlutterBluetoothSerial.instance.getBondedDevices();

  /// Pre-selects the BT device to connect to.
  ///
  /// Must be called (with a valid address) before [connect()] when
  /// [activeMode] is [ActiveMode.bluetooth].
  void setBluetoothTarget(String address, [String? name]) {
    _bleTargetAddress = address;
    _bleTargetName = name ?? address;
    _record('BT: target set → ${_bleTargetName ?? address}');
    notifyListeners();
  }

  // ── _bleConnect() ──────────────────────────────────────────────────────────

  /// Connects to [_bleTargetAddress] via Classic BT SPP (RFCOMM).
  ///
  /// Throws [StateError] if [setBluetoothTarget] has not been called first.
  /// C2: wraps toAddress() with a 10s timeout to prevent indefinite hangs on
  /// out-of-range devices.
  Future<void> _bleConnect() async {
    final address = _bleTargetAddress;
    if (address == null) {
      throw StateError(
        'BT: no target device — call setBluetoothTarget() before connect()',
      );
    }
    final displayName = _bleTargetName ?? address;

    _setState(
      ServiceConnectionState.connecting,
      'BT: connecting to $displayName…',
    );

    // C2: timeout guards against toAddress() hanging on an out-of-range device.
    _btConnection = await BluetoothConnection.toAddress(
      address,
    ).timeout(_bleConnectTimeout);

    _btConnection!.input!.listen(
      _onBleData,
      onError: _onBleError,
      onDone: _onBleDone,
      cancelOnError: false,
    );

    _bleRetryCount = 0;
    _record('BT: connected to $displayName');
    _setState(ServiceConnectionState.connected, 'BT: $displayName');
  }

  // C1: _bleSend() is fire-and-forget — does NOT await allSent per-command.
  // At 60Hz, awaiting allSent creates 120+ concurrent futures and floods the
  // RFCOMM sink, causing disconnects. Flush happens once in _bleDisconnect().
  void _bleSend(GamepadCommand command) {
    if (_btConnection == null || !_btConnection!.isConnected) {
      throw StateError('BT: not connected');
    }
    _btConnection!.output.add(utf8.encode(command.toJsonFrame()));
  }

  Future<void> _bleDisconnect() async {
    _userRequestedDisconnect = true;
    // C3: cancel any pending retry Timer before tearing down the connection.
    _bleReconnectTimer?.cancel();
    _bleReconnectTimer = null;
    // finish() flushes the output buffer before closing (vs close() which is abrupt).
    // This is the ONE point where we flush accumulated fire-and-forget sends.
    await _btConnection?.finish();
    _btConnection = null;
    _setState(ServiceConnectionState.disconnected, 'BT: disconnected');
    _record('BT: disconnected (user requested)');
  }

  void _onBleData(Uint8List data) {
    _record('BT ← ${utf8.decode(data, allowMalformed: true).trimRight()}');
  }

  void _onBleError(Object error, StackTrace stack) {
    _record('BT error: $error', level: LogLevel.error);
    _btConnection = null;
    _setState(ServiceConnectionState.error, 'BT error: $error');
    if (!_userRequestedDisconnect) _scheduleBleReconnect();
  }

  void _onBleDone() {
    _record('BT: connection closed by remote');
    _btConnection = null;
    _setState(ServiceConnectionState.disconnected, 'BT: disconnected');
    if (!_userRequestedDisconnect) _scheduleBleReconnect();
  }

  // C3: uses a stored Timer (not Future.delayed) so it can be cancelled by
  // _bleDisconnect() if the user disconnects before the retry fires.
  void _scheduleBleReconnect() {
    if (_bleRetryCount >= _maxBleRetries) {
      _record('BT: max retries ($_maxBleRetries) reached — giving up');
      _setState(ServiceConnectionState.error, 'BT: could not reconnect');
      return;
    }
    final delay = Duration(
      milliseconds: (500 * (1 << _bleRetryCount)).clamp(500, 16000),
    );
    _bleRetryCount++;
    _record(
      'BT: scheduling retry $_bleRetryCount in ${delay.inMilliseconds} ms',
    );
    _bleReconnectTimer = Timer(delay, () {
      _bleReconnectTimer = null;
      if (!_userRequestedDisconnect) connect();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  USB / ADB tunnel
  //
  //  Happy path: cable plugged → ADB forward active → auto-connect fires →
  //              TCP to 127.0.0.1:_wifiPort → 60Hz commands flow.
  //  Main failure: ADB forward not running → TCP connect fails → error state
  //                (no auto-retry; user must run `adb forward` then replug).
  //
  //  USB mode reuses the Wi-Fi TCP stack by temporarily patching _wifiHost to
  //  127.0.0.1.  ADB forwards phone-side localhost:_wifiPort to PC-side
  //  localhost:_wifiPort where BeastReceiver is listening — no C# changes needed.
  //
  //  One-time setup:
  //    1. Enable USB Debugging on the phone (Developer Options).
  //    2. Connect USB cable.
  //    3. On PC, run once:  adb forward tcp:5000 tcp:5000
  //    4. In CTRLFORGE, select "USB (ADB)" and press CONNECT.
  // ══════════════════════════════════════════════════════════════════════════

  StreamSubscription<UsbEvent>? _usbEventSub;

  Future<void> _usbConnect() async {
    _record('USB mode: ADB tunnel (tcp:$_wifiPort → tcp:$_wifiPort)');
    // Temporarily override host to loopback; restore in finally so Settings
    // are never mutated on error.
    final String savedHost = _wifiHost;
    _wifiHost = '127.0.0.1';
    try {
      await _wifiConnect();
    } finally {
      _wifiHost = savedHost;
    }
  }

  void _onUsbEvent(UsbEvent event) {
    _record(
      'USB event: ${event.event} — '
      '${event.device?.productName ?? "unknown device"}',
    );
    final isDetach = event.event == UsbEvent.ACTION_USB_DETACHED;
    _onUsbDeviceEvent(isDetach || event.device == null ? [] : [event.device!]);
  }

  // C5: auto-connect is mode-guarded AND checks that no connection is already
  // active. Checking _connState == disconnected alone is insufficient because
  // a BT connection in another mode also shows as connected, not disconnected —
  // the explicit activeMode guard prevents cross-mode double-connect.
  void _onUsbDeviceEvent(List<UsbDevice> devices) {
    if (devices.isEmpty) {
      if (_activeMode == ActiveMode.usb && isConnected) {
        _record('USB device removed', level: LogLevel.warning);
        _setState(ServiceConnectionState.disconnected, 'USB device unplugged');
      }
    } else {
      _record('USB device attached (${devices.length} device(s))');
      if (_activeMode == ActiveMode.usb &&
          !isConnected &&
          _connState != ServiceConnectionState.connecting &&
          !_userRequestedDisconnect) {
        _record('USB: auto-connecting on device attach…');
        connect();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Shared helpers
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _onTransportError(Object error) async {
    _setState(ServiceConnectionState.error, 'Transport error: $error');
    // Auto-reconnect only for Wi-Fi; BT and USB require user action.
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
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Disposal
  // ══════════════════════════════════════════════════════════════════════════

  // C7: all timers, subscriptions, sockets, and BT connections are released.
  @override
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _wifiCancelReconnect();
    _bleReconnectTimer?.cancel();
    await _tcpRxSub?.cancel();
    await _tcpSocket?.close();
    await _btConnection?.finish();
    await _usbEventSub?.cancel();
    super.dispose();
  }
}
