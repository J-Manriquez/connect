import 'package:flutter/material.dart';
import 'package:connect/services/device_finder_service.dart';
import 'package:connect/theme_colors.dart';

class BuscarDispositivoScreen extends StatefulWidget {
  const BuscarDispositivoScreen({Key? key}) : super(key: key);

  @override
  State<BuscarDispositivoScreen> createState() =>
      _BuscarDispositivoScreenState();
}

class _BuscarDispositivoScreenState extends State<BuscarDispositivoScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Configurar animaciones
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    // Iniciar animaciones
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _stopSearch() async {
    await DeviceFinderService.instance.stopDeviceSearch();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 1. Envuelve el body con SingleChildScrollView
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              // 2. Se elimina `mainAxisAlignment` porque ya no tiene efecto dentro de un scroll.
              //    El contenido ahora se alinea al inicio por defecto.
              children: [
                // Es bueno agregar un espacio al inicio para que no se vea tan pegado arriba.
                const SizedBox(height: 40),

                // Título
                Text(
                  '🔍 Buscando Dispositivo',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Subtítulo
                Text(
                  'Tu dispositivo está sonando y vibrando\npara ayudarte a encontrarlo',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),

                GestureDetector(
                  onTap: () {
                    _stopSearch(); // Asegúrate de tener esta función definida
                  },
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value * 2 * 3.14159,
                              child: Container(
                                width: 260,
                                height: 260,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.6),
                                      Colors.red.withOpacity(0.6),
                                      Colors.orange.withOpacity(0.6),
                                      Colors.yellow.withOpacity(0.6),
                                      Colors.green.withOpacity(0.6),
                                      Colors.blue.withOpacity(0.6),
                                      Colors.purple.withOpacity(0.6),
                                      Colors.white.withOpacity(0.6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.search,
                                  size: 130,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 60),

                // Indicador de ondas sonoras
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_up, color: Colors.black, size: 30),
                    const SizedBox(width: 10),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Row(
                          children: List.generate(3, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 4,
                              height:
                                  20 +
                                  (10 *
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
                    Icon(Icons.vibration, color: Colors.black, size: 30),
                  ],
                ),
                const SizedBox(height: 80),

                // Botón para detener
                SizedBox(
                  width: double.infinity,
                  height: 56,
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stop, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Detener Búsqueda',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Texto informativo
                Text(
                  'La búsqueda se detendrá automáticamente\nen 30 segundos',
                  style: TextStyle(fontSize: 14, color: Colors.black),
                  textAlign: TextAlign.center,
                ),

                // Espacio al final para que el scroll se sienta más cómodo
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
