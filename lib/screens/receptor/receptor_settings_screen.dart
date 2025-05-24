import 'package:flutter/material.dart';

class ReceptorSettingsScreen extends StatelessWidget {
  const ReceptorSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Receptor'),
      ),
      body: const Center(
        child: Text('Pantalla de configuración del receptor (vacía)'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Configuración
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/notificaciones');
              break;
            case 1:
              // Ya estamos en configuración
              break;
          }
        },
        selectedFontSize: 14.0,
        unselectedFontSize: 12.0,
        selectedIconTheme: const IconThemeData(size: 37.5),
        unselectedIconTheme: const IconThemeData(size: 22.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notificaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }
}