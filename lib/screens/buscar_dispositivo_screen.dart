import 'package:flutter/material.dart';
import 'package:connect/services/device_finder_service.dart';
import 'package:connect/services/device_search_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;

class BuscarDispositivoScreen extends StatefulWidget {
  const BuscarDispositivoScreen({Key? key}) : super(key: key);

  @override
  State<BuscarDispositivoScreen> createState() =>
      _BuscarDispositivoScreenState();
}

class _BuscarDispositivoScreenState extends State<BuscarDispositivoScreen>
    with TickerProviderStateMixin {
  // ✅ SOLUCIÓN ÓPTIMA: Separar animaciones para mejor rendimiento
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ✅ Ticker separado solo para rotación (más eficiente)
  late Ticker _rotationTicker;
  double _currentRotation = 0.0;
  static const double _rotationSpeed =
      0.5; // Velocidad en revoluciones por segundo

  @override
  void initState() {
    super.initState();

    // ✅ Configurar animación de pulso (optimizada)
    _pulseController = AnimationController(
      duration: const Duration(
        milliseconds: 1200,
      ), // Ligeramente más lento para suavidad
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ✅ Ticker optimizado para rotación suave
    _rotationTicker = createTicker(_onRotationTick);

    // Iniciar animaciones
    _pulseController.repeat(reverse: true);
    _rotationTicker.start();
  }

  // ✅ Función optimizada para rotación sin lag
  void _onRotationTick(Duration elapsed) {
    if (mounted) {
      // ✅ Calcular rotación de forma más eficiente
      final newRotation =
          (elapsed.inMilliseconds / 1000.0) * _rotationSpeed * 2 * math.pi;

      // ✅ Solo actualizar si hay cambio significativo (reduce llamadas a setState)
      if ((newRotation - _currentRotation).abs() > 0.01) {
        setState(() {
          _currentRotation = newRotation % (2 * math.pi);
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationTicker.dispose();
    super.dispose();
  }

  Future<void> _stopSearch() async {
    await DeviceFinderService.instance.stopDeviceSearch();
    
    // ✅ Resetear el campo correspondiente en Firebase
    try {
      final DeviceSearchService deviceSearchService = DeviceSearchService.instance;
      final bool disableAutoRedirect = await PreferencesService.getDisableAutoRedirect();
      
      if (disableAutoRedirect) {
        // Es receptor, resetear buscar-receptor
        await deviceSearchService.resetBuscarReceptor();
      } else {
        // Es emisor, resetear buscar-emisor
        await deviceSearchService.resetBuscarEmisor();
      }
    } catch (e) {
      // print('Error al resetear campos de búsqueda: $e');
    }
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  bool _isSmallScreenMediaQuery(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight < 450;
  }

  bool _isSmallScreenLayoutBuilder(double maxHeight) {
    return maxHeight < 450;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmallMediaQuery = _isSmallScreenMediaQuery(context);
          bool isSmallLayoutBuilder = _isSmallScreenLayoutBuilder(
            constraints.maxHeight,
          );
          bool isSmallScreen = isSmallMediaQuery || isSmallLayoutBuilder;

          return SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    SizedBox(height: isSmallScreen ? 10 : 25),

                    if (!isSmallScreen) ...[
                      Text(
                        'Buscando Dispositivo',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 24 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 20),

                      Text(
                        'Tu dispositivo está sonando y vibrando\npara ayudarte a encontrarlo',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isSmallScreen ? 30 : 60),
                    ],

                    // ✅ BOTÓN OPTIMIZADO: Separar animaciones para mejor rendimiento
                    GestureDetector(
                      onTap: () {
                        _stopSearch();
                      },
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // ✅ Contenedor rotativo optimizado
                                Transform.rotate(
                                  angle: _currentRotation,
                                  child: Container(
                                    width: isSmallScreen ? 270 : 300,
                                    height: isSmallScreen ? 270 : 300,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(
                                            0.7,
                                          ), // ✅ Corregido a 0.7
                                          Colors.red.withOpacity(0.7),
                                          // Colors.orange.withOpacity(0.7),
                                          Colors.yellow.withOpacity(0.7),
                                          Colors.green.withOpacity(0.7),
                                          Colors.blue.withOpacity(0.7),
                                          Colors.purple.withOpacity(0.7),
                                          Colors.white.withOpacity(0.7),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: isSmallScreen ? 15 : 20,
                                          spreadRadius: isSmallScreen ? 3 : 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // ✅ Ícono que NO rota
                                Icon(
                                  Icons.search,
                                  size: isSmallScreen ? 160 : 130,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 30 : 60),

                    // ✅ Indicador de ondas sonoras optimizado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.volume_up,
                          color: Colors.black,
                          size: isSmallScreen ? 34 : 30,
                        ),
                        const SizedBox(width: 10),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Row(
                              children: List.generate(3, (index) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  width: 4,
                                  height:
                                      (isSmallScreen ? 25 : 20) +
                                      ((isSmallScreen ? 18 : 10) *
                                          _pulseAnimation.value *
                                          (index + 1) /
                                          3),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.vibration,
                          color: Colors.black,
                          size: isSmallScreen ? 34 : 30,
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 40 : 80),

                    if (isSmallScreen) ...[
                      Text(
                        'Buscando Dispositivo',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 34 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 20),

                      Text(
                        'Tu dispositivo está sonando y vibrando para ayudarte a encontrarlo',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 16,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 60),
                    ],

                    // Botón para detener
                    SizedBox(
                      width: double.infinity,
                      height: isSmallScreen ? 60 : 56,
                      child: ElevatedButton(
                        onPressed: () {
                          _stopSearch();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.stop, size: isSmallScreen ? 30 : 24),
                            const SizedBox(width: 8),
                            Text(
                              'Detener Búsqueda',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 26 : 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 20),

                    Text(
                      'La búsqueda se detendrá automáticamente\nen 30 segundos',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 14,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 20),

                    // Indicador de detección para pantallas pequeñas
                    // if (isSmallScreen) ...[
                    //   Container(
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 12,
                    //       vertical: 6,
                    //     ),
                    //     decoration: BoxDecoration(
                    //       color: Colors.blue.withOpacity(0.1),
                    //       borderRadius: BorderRadius.circular(8),
                    //       border: Border.all(
                    //         color: Colors.blue.withOpacity(0.3),
                    //       ),
                    //     ),
                    //     child: Text(
                    //       'Pantalla pequeña detectada: $detectionMethod',
                    //       style: TextStyle(
                    //         fontSize: 12,
                    //         color: Colors.blue.shade700,
                    //         fontWeight: FontWeight.w500,
                    //       ),
                    //     ),
                    //   ),
                    //   SizedBox(height: 20),
                    // ],

                    // GestureDetector(
                    //   onTap: () {
                    //     _stopSearch();
                    //   },
                    //   child: AnimatedBuilder(
                    //     animation: _pulseAnimation,
                    //     builder: (context, child) {
                    //       return Transform.scale(
                    //         scale: _pulseAnimation.value,
                    //         child: AnimatedBuilder(
                    //           animation: _rotationAnimation,
                    //           builder: (context, child) {
                    //             return Transform.rotate(
                    //               angle: _rotationAnimation.value * 2 * 3.14159,
                    //               child: Container(
                    //                 width: isSmallScreen ? 280 : 260,
                    //                 height: isSmallScreen ? 280 : 260,
                    //                 decoration: BoxDecoration(
                    //                   shape: BoxShape.circle,
                    //                   gradient: LinearGradient(
                    //                     colors: [
                    //                       Colors.white.withOpacity(0.6),
                    //                       Colors.red.withOpacity(0.6),
                    //                       Colors.orange.withOpacity(0.6),
                    //                       Colors.yellow.withOpacity(0.6),
                    //                       Colors.green.withOpacity(0.6),
                    //                       Colors.blue.withOpacity(0.6),
                    //                       Colors.purple.withOpacity(0.6),
                    //                       Colors.white.withOpacity(0.6),
                    //                     ],
                    //                     begin: Alignment.topLeft,
                    //                     end: Alignment.bottomRight,
                    //                   ),
                    //                   boxShadow: [
                    //                     BoxShadow(
                    //                       color: Colors.black.withOpacity(0.3),
                    //                       blurRadius: isSmallScreen ? 15 : 20,
                    //                       spreadRadius: isSmallScreen ? 3 : 5,
                    //                     ),
                    //                   ],
                    //                 ),
                    //                 child: Icon(
                    //                   Icons.search,
                    //                   size: isSmallScreen ? 160 : 130,
                    //                   color: Colors.white,
                    //                 ),
                    //               ),
                    //             );
                    //           },
                    //         ),
                    //       );
                    //     },
                    //   ),
                    // ),

                    // Información de debug (opcional, puedes quitarla en producción)
                    // if (isSmallScreen) ...[
                    //   const SizedBox(height: 10),
                    //   Container(
                    //     padding: const EdgeInsets.all(8),
                    //     decoration: BoxDecoration(
                    //       color: Colors.grey.withOpacity(0.1),
                    //       borderRadius: BorderRadius.circular(6),
                    //     ),
                    //     child: Column(
                    //       children: [
                    //         Text(
                    //           'Info de pantalla:',
                    //           style: TextStyle(
                    //             fontSize: 10,
                    //             fontWeight: FontWeight.bold,
                    //             color: Colors.grey.shade600,
                    //           ),
                    //         ),
                    //         Text(
                    //           'MediaQuery: ${MediaQuery.of(context).size.height.toInt()}px',
                    //           style: TextStyle(
                    //             fontSize: 10,
                    //             color: Colors.grey.shade600,
                    //           ),
                    //         ),
                    //         Text(
                    //           'LayoutBuilder: ${constraints.maxHeight.toInt()}px',
                    //           style: TextStyle(
                    //             fontSize: 10,
                    //             color: Colors.grey.shade600,
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
