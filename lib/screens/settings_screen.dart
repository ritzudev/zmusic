import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Z Music Configuración')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('General'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text('Idioma'),
                      trailing: Icon(Icons.arrow_forward_ios),
                    ),
                    ListTile(
                      title: Text('Tema'),
                      trailing: Icon(Icons.arrow_forward_ios),
                    ),
                    ListTile(
                      title: Text('Notificaciones'),
                      trailing: Icon(Icons.arrow_forward_ios),
                    ),
                  ],
                ),
              ),
              /* Text('Reproducción'),
              Divider(),
              Text('Almacenamiento'),
              Divider(),
              Text('Acerca de'),
              Divider(), */
            ],
          ),
        ),
      ),
    );
  }
}
