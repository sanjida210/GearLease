import 'dart:async';
import 'dart:convert';
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
  Timer? _heartbeatTimer;
  final Map<String, WebSocketChannel> _activeChannels = {};
  final Map<String, StreamController<MachineTelemetryModel>> _machineControllers = {};
  StreamController<List<MachineTelemetryModel>>? _fleetController;

  TelemetryWsDataSourceImpl({
    this.wsBaseUrl = 'wss://api.gearlease.io/ws/telemetry',
    this.channelFactory,
  }) {
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      for (final channel in _activeChannels.values) {
        try {
          channel.sink.add(jsonEncode({'type': 'PING', 'timestamp': DateTime.now().toIso8601String()}));
        } catch (_) {}
      }
    });
  }

  @override
  Stream<MachineTelemetryModel> streamMachineTelemetry(String assetId) {
    if (_machineControllers.containsKey(assetId) && !_machineControllers[assetId]!.isClosed) {
      return _machineControllers[assetId]!.stream;
    }

    late final StreamController<MachineTelemetryModel> controller;
    controller = StreamController<MachineTelemetryModel>.broadcast(
      onListen: () => _connectMachine(assetId, controller),
    );
    _machineControllers[assetId] = controller;
    return controller.stream;
  }

  void _connectMachine(String assetId, StreamController<MachineTelemetryModel> controller) {
    final uri = Uri.parse('$wsBaseUrl/assets/$assetId');
    try {
      final channel = channelFactory != null
          ? channelFactory!(uri)
          : WebSocketChannel.connect(uri);

      _activeChannels[assetId] = channel;

      channel.ready.catchError((err) {
        _emitFallbackMachine(assetId, controller);
      });

      channel.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            if (decoded['type'] == 'PONG') return;
            final model = MachineTelemetryModel.fromJson(decoded);
            if (!controller.isClosed) controller.add(model);
          } catch (_) {}
        },
        onError: (err) {
          _emitFallbackMachine(assetId, controller);
        },
        onDone: () {},
      );
    } catch (_) {
      _emitFallbackMachine(assetId, controller);
    }
  }

  @override
  Stream<List<MachineTelemetryModel>> streamFleetTelemetry() {
    if (_fleetController != null && !_fleetController!.isClosed) {
      return _fleetController!.stream;
    }

    late final StreamController<List<MachineTelemetryModel>> controller;
    controller = StreamController<List<MachineTelemetryModel>>.broadcast(
      onListen: () => _connectFleet(controller),
    );
    _fleetController = controller;
    return controller.stream;
  }

  void _connectFleet(StreamController<List<MachineTelemetryModel>> controller) {
    final uri = Uri.parse('$wsBaseUrl/fleet');
    try {
      final channel = channelFactory != null
          ? channelFactory!(uri)
          : WebSocketChannel.connect(uri);

      _activeChannels['fleet'] = channel;

      channel.ready.catchError((err) {
        _emitFallbackFleet(controller);
      });

      channel.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String);
            if (decoded is List) {
              final list = decoded
                  .map((e) => MachineTelemetryModel.fromJson(e as Map<String, dynamic>))
                  .toList();
              if (!controller.isClosed) controller.add(list);
            }
          } catch (_) {}
        },
        onError: (err) {
          _emitFallbackFleet(controller);
        },
        onDone: () {},
      );
    } catch (_) {
      _emitFallbackFleet(controller);
    }
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
  }
}
