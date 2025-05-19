import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Clase inmutable para el estado de conectividad
@immutable
class ConnectivityState {
  final bool isConnected; // Indica si hay acceso real a Internet
  final ConnectivityResult connectionType; // Tipo de conexión de red (wifi, mobile, none, etc.)
  final bool isChecking; // Indica si se está realizando una verificación activa
  final String? error; // Mensaje de error si lo hay

  const ConnectivityState({
    this.isConnected = false,
    this.connectionType = ConnectivityResult.none,
    this.isChecking = false,
    this.error,
  });

  ConnectivityState copyWith({
    bool? isConnected,
    ConnectivityResult? connectionType,
    bool? isChecking,
    String? error,
  }) {
    return ConnectivityState(
      isConnected: isConnected ?? this.isConnected,
      connectionType: connectionType ?? this.connectionType,
      isChecking: isChecking ?? this.isChecking,
      error: error ?? this.error,
    );
  }
}

// StateNotifier para manejar la conectividad
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  ConnectivityNotifier() : super(const ConnectivityState()) {
    _init(); // Inicia la verificación y escucha al crearse
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _retryTimer; // Temporizador para reintentar la verificación de internet

  // Inicializa el notifier: verifica el estado inicial y empieza a escuchar cambios
  void _init() async {
    await _checkConnectivityAndReport(); // Realiza la verificación inicial
    _listenToConnectivityChanges(); // Empieza a escuchar cambios de tipo de conexión
  }

  // Configura la escucha de cambios en el tipo de conectividad
  void _listenToConnectivityChanges() {
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) async {
        final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
        // Maneja el cambio de tipo de conexión reportado por el plugin
        await _handleConnectivityChange(result);
      },
      onError: (error) {
        // Maneja errores en el stream de conectividad
        state = state.copyWith(
          error: 'Error monitoreando conectividad: $error',
          isChecking: false,
        );
        _cancelRetry(); // Cancela cualquier reintento si hay un error en el stream
      },
    );
  }

  // Maneja un cambio en el tipo de conexión de red
  Future<void> _handleConnectivityChange(ConnectivityResult newConnectionType) async {
     // Actualiza el tipo de conexión y marca como verificando
     state = state.copyWith(
       connectionType: newConnectionType,
       isChecking: true,
       error: null, // Limpia errores previos en un nuevo chequeo
     );

     if (newConnectionType == ConnectivityResult.none) {
        // Si no hay red, cancela reintentos y actualiza el estado
        _cancelRetry();
        state = state.copyWith(
          isConnected: false,
          isChecking: false,
        );
     } else {
       // Si hay red (wifi, mobile, ethernet, etc.), verifica el acceso a internet real
       await _checkInternetAccessAndReport();
     }
  }

  // Verifica el acceso a internet real (haciendo pings) y actualiza el estado
  Future<void> _checkInternetAccessAndReport() async {
    // Evita verificar si ya se está verificando o si no hay ningún tipo de red
    if (state.isChecking || state.connectionType == ConnectivityResult.none) {
       if (state.connectionType == ConnectivityResult.none) {
          state = state.copyWith(isConnected: false, isChecking: false);
       }
       _cancelRetry(); // Asegura que no haya reintentos programados si no hay red o ya se está verificando
       return;
    }

    // Marca como verificando antes de realizar la comprobación
    state = state.copyWith(isChecking: true, error: null);

    // Realiza la comprobación de acceso a internet
    final hasInternet = await _pingHosts();

    // Actualiza el estado con el resultado de la verificación
    state = state.copyWith(
      isConnected: hasInternet,
      isChecking: false,
    );

    // Programa un reintento solo si hay una conexión de red pero no internet
    if (!hasInternet && state.connectionType != ConnectivityResult.none) {
        _scheduleRetry();
    } else {
        // Si se detectó internet o no hay red, cancela cualquier reintento pendiente
        _cancelRetry();
    }
  }

  // Intenta hacer ping a múltiples hosts para verificar el acceso a internet
  Future<bool> _pingHosts() async {
     try {
       // Realiza los pings en paralelo y espera los resultados
       final results = await Future.wait([
         _pingHost('8.8.8.8', 53), // Google DNS
         _pingHost('1.1.1.1', 53), // Cloudflare DNS
         _pingHost('https://www.google.com/url?sa=E&source=gmail&q=google.com', 80), // Un sitio web conocido
       ].map((future) => future.catchError((e) {
           // Maneja errores individuales de ping, no detiene Future.wait
           print('Error haciendo ping: $e'); // Opcional para depuración
           return false;
       })).toList());

       // Considera que hay internet si al menos uno de los pings fue exitoso
       return results.any((result) => result == true);
     } catch (error) {
       // Maneja errores en el Future.wait mismo (menos probable)
       print('Error general durante pingHosts: $error');
       return false;
     }
  }

  // Intenta conectar a un host y puerto específico para verificar la accesibilidad
  Future<bool> _pingHost(String host, int port) async {
    try {
      // Intenta resolver la dirección IP primero (útil si hay problemas de DNS)
      final InternetAddress address = (await InternetAddress.lookup(host)).first;
      final socket = await Socket.connect(
        address, // Usa la dirección IP resuelta
        port,
        timeout: const Duration(seconds: 5), // Aumenta el tiempo de espera
      );
      socket.destroy(); // Cierra la conexión inmediatamente
      return true; // Conexión exitosa
    } catch (error) {
      // Si hay un error al conectar, significa que el host no es accesible
      return false; // Conexión fallida
    }
  }

  // Programa un reintento para verificar el acceso a internet después de un tiempo
  void _scheduleRetry() {
    _cancelRetry(); // Cancela cualquier temporizador de reintento existente
    _retryTimer = Timer(const Duration(seconds: 5), () async {
      // Solo reintenta si el estado actual indica que hay red pero no internet y no se está verificando ya
      if (!state.isConnected && state.connectionType != ConnectivityResult.none && !state.isChecking) {
        print('Reintentando verificar acceso a internet...'); // Opcional para depuración
        await _checkInternetAccessAndReport(); // Realiza la verificación y actualiza el estado
      }
    });
  }

  // Cancela el temporizador de reintento si está activo
  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  // Método público para forzar una verificación manual de conectividad
  Future<void> checkConnectivity() async {
    // Fuerza un chequeo completo, pero evita iniciar múltiples verificaciones a la vez
    if (!state.isChecking) {
      await _checkConnectivityAndReport();
    }
  }

  // Método para realizar una verificación completa (tipo de red y acceso a internet)
  Future<void> _checkConnectivityAndReport() async {
      // Marca como verificando al inicio
      state = state.copyWith(isChecking: true, error: null);
      try {
          // Obtiene el tipo de conexión actual
          final results = await _connectivity.checkConnectivity();
          final currentConnectionType = results.isNotEmpty ? results.first : ConnectivityResult.none;

          // Actualiza el tipo de conexión en el estado
          state = state.copyWith(connectionType: currentConnectionType);

          if (currentConnectionType == ConnectivityResult.none) {
             // Si no hay red, actualiza el estado y cancela reintentos
             state = state.copyWith(isConnected: false, isChecking: false);
             _cancelRetry();
          } else {
             // Si hay red, verifica el acceso a internet
             await _checkInternetAccessAndReport(); // Esta función se encarga de actualizar isConnected y programar reintentos
          }
      } catch(e) {
          // Maneja errores durante la verificación inicial
          state = state.copyWith(
            error: 'La verificación inicial falló: $e',
            isChecking: false,
            isConnected: false, // Asume sin internet si el chequeo falla
            connectionType: ConnectivityResult.none, // Asume sin conexión si el chequeo falla
          );
          _cancelRetry();
      }
  }

  // Se llama al hacer dispose del notifier (cuando deja de ser necesario)
  @override
  void dispose() {
    _subscription?.cancel(); // Cancela la escucha de cambios
    _cancelRetry(); // Cancela cualquier reintento pendiente
    super.dispose();
  }
}

// Provider principal que expone el estado de conectividad
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>(
  (ref) => ConnectivityNotifier(),
);

// Providers adicionales para acceder a propiedades específicas del estado (útiles para optimizar reconstrucciones)
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider.select((state) => state.isConnected));
});

final connectionTypeProvider = Provider<ConnectivityResult>((ref) {
  return ref.watch(connectivityProvider.select((state) => state.connectionType));
});

final isCheckingConnectivityProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider.select((state) => state.isChecking));
});

// /*
// Puedes descomentar y usar los siguientes Widgets de ejemplo en tu aplicación:

// Widget para mostrar el estado detallado de conectividad
// class ConnectivityStatusWidget extends ConsumerWidget {
//   const ConnectivityStatusWidget({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final connectivityState = ref.watch(connectivityProvider);
//     final connectivityNotifier = ref.watch(connectivityProvider.notifier);

//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               children: [
//                 _buildConnectionIcon(connectivityState),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         _getConnectionStatusText(connectivityState),
//                         style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                           color: _getStatusColor(connectivityState),
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         _getConnectionTypeText(connectivityState.connectionType),
//                         style: Theme.of(context).textTheme.bodySmall,
//                       ),
//                     ],
//                   ),
//                 ),
//                 if (connectivityState.isChecking)
//                   const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(strokeWidth: 2),
//                   )
//                 else
//                   IconButton(
//                     icon: const Icon(Icons.refresh),
//                     onPressed: () => connectivityNotifier.checkConnectivity(),
//                     tooltip: 'Verificar conectividad',
//                   ),
//               ],
//             ),
//             if (connectivityState.error != null) ...[
//               const SizedBox(height: 12),
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.red.shade50,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.error, color: Colors.red.shade700, size: 16),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         connectivityState.error!,
//                         style: TextStyle(
//                           color: Colors.red.shade700,
//                           fontSize: 12,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildConnectionIcon(ConnectivityState state) {
//     if (state.isChecking) {
//       return const Icon(
//         Icons.signal_wifi_statusbar_null,
//         color: Colors.orange,
//         size: 32,
//       );
//     }

//     if (!state.isConnected) {
//       return const Icon(
//         Icons.wifi_off,
//         color: Colors.red,
//         size: 32,
//       );
//     }

//     switch (state.connectionType) {
//       case ConnectivityResult.wifi:
//         return const Icon(
//           Icons.wifi,
//           color: Colors.green,
//           size: 32,
//         );
//       case ConnectivityResult.mobile:
//         return const Icon(
//           Icons.signal_cellular_alt,
//           color: Colors.green,
//           size: 32,
//         );
//       case ConnectivityResult.ethernet:
//         return const Icon(
//           Icons.settings_ethernet,
//           color: Colors.green,
//           size: 32,
//         );
//       default: // handles VPN, other
//         return const Icon(
//           Icons.vpn_lock, // Or another suitable icon
//           color: Colors.green,
//           size: 32,
//         );
//     }
//   }

//   String _getConnectionStatusText(ConnectivityState state) {
//     if (state.isChecking) {
//       return 'Verificando conexión...';
//     }

//     if (state.isConnected) {
//       return 'Conectado a Internet';
//     }

//     if (state.connectionType != ConnectivityResult.none) {
//       return 'Red disponible, sin acceso a Internet';
//     }

//     return 'Sin conexión de red';
//   }

//   String _getConnectionTypeText(ConnectivityResult type) {
//     switch (type) {
//       case ConnectivityResult.wifi:
//         return 'WiFi';
//       case ConnectivityResult.mobile:
//         return 'Datos móviles';
//       case ConnectivityResult.ethernet:
//         return 'Ethernet';
//       case ConnectivityResult.none:
//         return 'Sin conexión';
//       case ConnectivityResult.vpn:
//         return 'VPN';
//       case ConnectivityResult.bluetooth:
//         return 'Bluetooth';
//       case ConnectivityResult.other:
//         return 'Otro';
//       default:
//         return 'Desconocido';
//     }
//   }

//   Color _getStatusColor(ConnectivityState state) {
//     if (state.isChecking) {
//       return Colors.orange;
//     }

//     if (state.isConnected) {
//       return Colors.green;
//     }

//     return Colors.red;
//   }
// }

// // Widget de indicador simple para la AppBar o similar
// class ConnectivityIndicator extends ConsumerWidget {
//   const ConnectivityIndicator({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final isConnected = ref.watch(isConnectedProvider);
//     final isChecking = ref.watch(isCheckingConnectivityProvider);

//     if (isChecking) {
//       return const Icon(
//         Icons.signal_wifi_statusbar_null,
//         color: Colors.orange,
//       );
//     }

//     return Icon(
//       isConnected ? Icons.wifi : Icons.wifi_off,
//       color: isConnected ? Colors.green : Colors.red,
//     );
//   }
// }

// // Ejemplo de uso en la app principal
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ProviderScope(
//       child: MaterialApp(
//         title: 'Connectivity Monitor',
//         theme: ThemeData(
//           primarySwatch: Colors.blue,
//           useMaterial3: true,
//         ),
//         home: const ConnectivityScreen(),
//       ),
//     );
//   }
// }

// class ConnectivityScreen extends ConsumerWidget {
//   const ConnectivityScreen({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Monitor de Conectividad'),
//         actions: const [
//           ConnectivityIndicator(),
//           SizedBox(width: 16),
//         ],
//       ),
//       body: const Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             ConnectivityStatusWidget(),
//             SizedBox(height: 24),
//             Text(
//               'Este ejemplo usa StateNotifier para monitorear la conectividad de forma reactiva, incluyendo la verificación de acceso a Internet real.',
//               textAlign: TextAlign.center,
//               style: TextStyle(fontSize: 16),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// */