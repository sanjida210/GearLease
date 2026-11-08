import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/machine_telemetry_model.dart';

abstract class TelemetryWsDataSource {
  Stream<MachineTelemetryModel> streamMachineTelemetry(String assetId);
  Stream<List<MachineTelemetryModel>> streamFleetTelemetry();
  void dispose();
}

typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

class TelemetryWsDataSourceImpl implements TelemetryWsDataSource {
  final String wsBaseUrl;
  final WebSocketChannelFactory? channelFactory;
  final bool enableHeartbeat;
  final bool enableReconnect;
  Timer? _heartbeatTimer;
  final Map<String, WebSocketChannel> _activeChannels = {};
  final Map<String, StreamController<MachineTelemetryModel>> _machineControllers = {};
  final Map<String, Timer> _reconnectTimers = {};
  StreamController<List<MachineTelemetryModel>>? _fleetController;
  Timer? _fleetReconnectTimer;

  TelemetryWsDataSourceImpl({
    this.wsBaseUrl = 'wss://api.gearlease.com/ws/telemetry',
    this.channelFactory,
    this.enableHeartbeat = true,
    bool? enableReconnect,
  }) : enableReconnect = enableReconnect ?? enableHeartbeat;

  void _startHeartbeatIfNeeded() {
    if (!enableHeartbeat) return;
    if (_heartbeatTimer == null || !_heartbeatTimer!.isActive) {
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_activeChannels.isEmpty) {
          _heartbeatTimer?.cancel();
          _heartbeatTimer = null;
          return;
        }
        final pingPayload = jsonEncode({
          'type': 'PING',
          'timestamp': DateTime.now().toIso8601String(),
        });
        for (final channel in _activeChannels.values) {
          try {
            channel.sink.add(pingPayload);
          } catch (_) {}
        }
      });
    }
  }

  @override
  Stream<MachineTelemetryModel> streamMachineTelemetry(String assetId) {
    if (_machineControllers.containsKey(assetId) && !_machineControllers[assetId]!.isClosed) {
      return _machineControllers[assetId]!.stream;
    }

    late final StreamController<MachineTelemetryModel> controller;
    controller = StreamController<MachineTelemetryModel>.broadcast(
      onListen: () => _connectMachine(assetId, controller),
      onCancel: () => _disconnectMachine(assetId),
    );
    _machineControllers[assetId] = controller;
    return controller.stream;
  }

  void _connectMachine(
    String assetId,
    StreamController<MachineTelemetryModel> controller, {
    int retryCount = 0,
  }) {
    if (controller.isClosed) return;

    final baseUri = Uri.parse(wsBaseUrl);
    final uri = baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        'assetId': assetId,
      },
    );

    try {
      final channel = channelFactory != null
          ? channelFactory!(uri)
          : WebSocketChannel.connect(uri);

      _activeChannels[assetId] = channel;
      _startHeartbeatIfNeeded();

      channel.ready.then((_) {
        // Successful connection
      }).catchError((err) {
        _handleMachineDisconnect(assetId, channel, controller, retryCount);
      });

      channel.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            final type = (decoded['type'] as String?)?.toUpperCase();
            if (type == 'PONG') return;
            if (type == 'PING') {
              try {
                channel.sink.add(jsonEncode({
                  'type': 'PONG',
                  'timestamp': DateTime.now().toIso8601String(),
                }));
              } catch (_) {}
              return;
            }

            final model = MachineTelemetryModel.fromJson(decoded);
            if (!controller.isClosed) {
              controller.add(model);
            }
          } catch (_) {}
        },
        onError: (err) {
          _handleMachineDisconnect(assetId, channel, controller, retryCount);
        },
        onDone: () {
          _handleMachineDisconnect(assetId, channel, controller, retryCount);
        },
        cancelOnError: true,
      );
    } catch (_) {
      _handleMachineDisconnect(assetId, null, controller, retryCount);
    }
  }

  void _handleMachineDisconnect(
    String assetId,
    WebSocketChannel? channel,
    StreamController<MachineTelemetryModel> controller,
    int retryCount,
  ) {
    if (controller.isClosed) return;
    if (channel != null && _activeChannels[assetId] != channel && _activeChannels.containsKey(assetId)) {
      return;
    }
    _activeChannels.remove(assetId);
    _emitFallbackMachine(assetId, controller);

    if (!enableReconnect) return;

    if (controller.hasListener) {
      final delaySeconds = math.min(1 * math.pow(2, retryCount).toInt(), 30);
      _reconnectTimers[assetId]?.cancel();
      _reconnectTimers[assetId] = Timer(Duration(seconds: delaySeconds), () {
        if (!controller.isClosed && controller.hasListener) {
          _connectMachine(assetId, controller, retryCount: retryCount + 1);
        }
      });
    }
  }

  void _disconnectMachine(String assetId) {
    _reconnectTimers[assetId]?.cancel();
    _reconnectTimers.remove(assetId);
    final channel = _activeChannels.remove(assetId);
    try {
      channel?.sink.close();
    } catch (_) {}
  }

  @override
  Stream<List<MachineTelemetryModel>> streamFleetTelemetry() {
    if (_fleetController != null && !_fleetController!.isClosed) {
      return _fleetController!.stream;
    }

    late final StreamController<List<MachineTelemetryModel>> controller;
    controller = StreamController<List<MachineTelemetryModel>>.broadcast(
      onListen: () => _connectFleet(controller),
      onCancel: _disconnectFleet,
    );
    _fleetController = controller;
    return controller.stream;
  }

  void _connectFleet(StreamController<List<MachineTelemetryModel>> controller, {int retryCount = 0}) {
    if (controller.isClosed) return;

    final baseUri = Uri.parse(wsBaseUrl);
    final uri = wsBaseUrl.contains('?')
        ? Uri.parse('$wsBaseUrl&type=fleet')
        : (baseUri.path.isEmpty || baseUri.path == '/'
            ? Uri.parse('$wsBaseUrl/fleet')
            : Uri.parse('$wsBaseUrl/fleet'));

    try {
      final channel = channelFactory != null
          ? channelFactory!(uri)
          : WebSocketChannel.connect(uri);

      _activeChannels['fleet'] = channel;
      _startHeartbeatIfNeeded();

      channel.ready.then((_) {
        // Connected
      }).catchError((err) {
        _handleFleetDisconnect(channel, controller, retryCount);
      });

      channel.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String);
            if (decoded is Map<String, dynamic>) {
              final type = (decoded['type'] as String?)?.toUpperCase();
              if (type == 'PONG') return;
              if (type == 'PING') {
                try {
                  channel.sink.add(jsonEncode({
                    'type': 'PONG',
                    'timestamp': DateTime.now().toIso8601String(),
                  }));
                } catch (_) {}
                return;
              }
            } else if (decoded is List) {
              final list = decoded
                  .map((e) => MachineTelemetryModel.fromJson(e as Map<String, dynamic>))
                  .toList();
              if (!controller.isClosed) controller.add(list);
            }
          } catch (_) {}
        },
        onError: (err) {
          _handleFleetDisconnect(channel, controller, retryCount);
        },
        onDone: () {
          _handleFleetDisconnect(channel, controller, retryCount);
        },
        cancelOnError: true,
      );
    } catch (_) {
      _handleFleetDisconnect(null, controller, retryCount);
    }
  }

  void _handleFleetDisconnect(
    WebSocketChannel? channel,
    StreamController<List<MachineTelemetryModel>> controller,
    int retryCount,
  ) {
    if (controller.isClosed) return;
    if (channel != null && _activeChannels['fleet'] != channel && _activeChannels.containsKey('fleet')) {
      return;
    }
    _activeChannels.remove('fleet');
    _emitFallbackFleet(controller);

    if (!enableReconnect) return;

    if (controller.hasListener) {
      final delaySeconds = math.min(1 * math.pow(2, retryCount).toInt(), 30);
      _fleetReconnectTimer?.cancel();
      _fleetReconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        if (!controller.isClosed && controller.hasListener) {
          _connectFleet(controller, retryCount: retryCount + 1);
        }
      });
    }
  }

  void _disconnectFleet() {
    _fleetReconnectTimer?.cancel();
    _fleetReconnectTimer = null;
    final channel = _activeChannels.remove('fleet');
    try {
      channel?.sink.close();
    } catch (_) {}
  }

  void _emitFallbackMachine(String assetId, StreamController<MachineTelemetryModel> controller) {
    if (controller.isClosed) return;
    controller.add(
      MachineTelemetryModel(
        assetId: assetId,
        machineName: 'Probat P12 Roaster',
        category: 'Commercial Kitchen',
        runningHours: 1248.5,
        temperatureCelsius: 78.0,
        motorRpm: 1420.0,
        status: MachineTelemetryModel.fromJson(const {'status': 'warning'}).status,
        currentBillingCents: 112000,
        billingType: 'Revenue-Indexed',
        timestamp: DateTime.now(),
      ),
    );
  }

  void _emitFallbackFleet(StreamController<List<MachineTelemetryModel>> controller) {
    if (controller.isClosed) return;
    controller.add([
      MachineTelemetryModel(
        assetId: 'ast_probat12',
        machineName: 'Probat P12 Roaster',
        category: 'Commercial Kitchen',
        runningHours: 1248.5,
        temperatureCelsius: 78.0,
        motorRpm: 1420.0,
        status: MachineTelemetryModel.fromJson(const {'status': 'warning'}).status,
        currentBillingCents: 112000,
        billingType: 'Revenue-Indexed',
        timestamp: DateTime.now(),
      ),
      MachineTelemetryModel(
        assetId: 'ast_brewpro500',
        machineName: 'BrewPro 500 Keg Line',
        category: 'Beverage Packaging',
        runningHours: 412.0,
        temperatureCelsius: 64.0,
        motorRpm: 1800.0,
        status: MachineTelemetryModel.fromJson(const {'status': 'optimal'}).status,
        currentBillingCents: 48000,
        billingType: 'Fixed Lease',
        timestamp: DateTime.now(),
      ),
    ]);
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();

    _fleetReconnectTimer?.cancel();
    _fleetReconnectTimer = null;

    for (final channel in _activeChannels.values) {
      try {
        channel.sink.close();
      } catch (_) {}
    }
    _activeChannels.clear();

    for (final controller in _machineControllers.values) {
      controller.close();
    }
    _machineControllers.clear();

    _fleetController?.close();
    _fleetController = null;
  }
}
