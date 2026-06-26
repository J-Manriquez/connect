# Guía: Auto-actualización vía GitHub Releases en cualquier app Flutter

Esta guía explica cómo replicar el sistema de actualización automática que usa
**FollowProjects** (`proyecto_3`) en cualquier otra app Flutter. El mecanismo
funciona para **Windows (instalador Inno Setup), Windows (portable) y Android
(APK)** descargando los binarios publicados como *assets* de un **GitHub
Release** y aplicándolos en caliente.

---

## 1. Cómo funciona (visión general)

```
Al arrancar la app (main.dart)
        │
        ▼
UpdateService.checkForUpdate()
        │  Lista TODOS los releases del repo (API GitHub, autenticada con un PAT)
        │  Elige el de mayor versión (no draft / no prerelease)
        │  Compara su versión con la versión local (package_info_plus)
        ▼
¿Hay versión más nueva?  ──No──►  La app continúa normal
        │ Sí
        ▼
Detecta el "target" de instalación (instalador / portable / APK)
y busca el asset adecuado (.exe / .zip / .apk)
        │
        ▼
Muestra UpdateRequiredScreen (pantalla bloqueante, sin salida)
        │  El usuario pulsa "Actualizar ahora"
        ▼
downloadAsset()  → descarga autenticada con barra de progreso
        │
        ▼
Aplica la actualización según el target:
  • Instalador Win → lanza el .exe y cierra la app
  • Portable Win   → script PowerShell que espera el cierre, descomprime
                     el .zip sobre la carpeta, y relanza la app
  • Android        → abre el .apk con el instalador del sistema
```

Puntos clave del diseño:

- **Se listan todos los releases** (`/releases?per_page=100`) en vez de usar
  `/releases/latest`, porque el badge "Latest" de GitHub es un flag manual fácil
  de dejar mal puesto. Se elige el de mayor versión semántica real.
- **Repo privado soportado**: la API y la descarga de assets van autenticadas
  con un *fine-grained PAT* de solo lectura, guardado en `.env` (no en el código).
- **Detección automática de instalación** en Windows: si junto al `.exe` existe
  un `unins000.exe` (que deja Inno Setup), es instalador; si no, es portable.
- **Actualización bloqueante**: la app no deja continuar sin actualizar. Si
  prefieres que sea opcional, basta con no bloquear (ver §7).

---

## 2. Requisitos previos

### 2.1 Dependencias (`pubspec.yaml`)

```yaml
dependencies:
  http: ^1.2.0              # llamadas a la API de GitHub y descarga
  flutter_dotenv: ^5.2.1    # leer el token desde .env
  package_info_plus: ^8.1.2 # versión instalada de la app
  path_provider: ^2.1.5     # carpeta temporal para descargar
  open_filex: ^4.5.0        # abrir el APK en Android
```

> `open_filex` solo es necesario si vas a soportar Android. Si solo necesitas
> Windows, puedes omitirlo.

Declara el `.env` como asset:

```yaml
flutter:
  assets:
    - .env
```

### 2.2 Token de GitHub

Crea un **fine-grained Personal Access Token**:

1. GitHub → *Settings* → *Developer settings* → *Fine-grained tokens* → *Generate new token*.
2. *Repository access*: solo el repo de tu app.
3. *Permissions* → *Repository permissions* → **Contents: Read-only**.
4. Copia el token (empieza por `github_pat_...`).

> ⚠️ Este token va embebido en el `.env` distribuido con la app, por lo que
> queda accesible para quien tenga el binario. Usa **siempre** un token de
> **solo lectura** y limitado a ese único repo. Para apps públicas, considera
> un repo de releases público (sin token) o un proxy server.

### 2.3 `.env` y `.env.example`

`.env.example` (se versiona, sin valores):

```env
SHEETS_API_KEY=
# Fine-grained PAT de GitHub con scope "Contents: read-only" sobre el repo.
# Se usa solo para leer/descargar GitHub Releases (auto-actualización).
GITHUB_UPDATE_TOKEN=
```

`.env` (NO se versiona — añádelo a `.gitignore` — con el token real):

```env
GITHUB_UPDATE_TOKEN=github_pat_xxxxxxxxxxxxxxxxxxxx
```

---

## 3. El servicio de actualización (`lib/services/update_service.dart`)

Copia este archivo y cambia solo `_owner` y `_repo`. El resto es reutilizable
tal cual.

```dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

enum InstallTarget { windowsInstaller, windowsPortable, android }

class UpdateInfo {
  final String version;
  final String assetApiUrl;
  final String assetName;
  final InstallTarget target;
  UpdateInfo({
    required this.version,
    required this.assetApiUrl,
    required this.assetName,
    required this.target,
  });
}

class UpdateService {
  // ── CAMBIA ESTOS DOS VALORES POR LOS DE TU REPO ──
  static const String _owner = 'tu-usuario-github';
  static const String _repo = 'tu-repo';
  static const Duration _timeout = Duration(seconds: 10);

  static String get _token => dotenv.env['GITHUB_UPDATE_TOKEN'] ?? '';

  /// En Windows, Inno Setup deja un `unins000.exe`; el portable no lo tiene.
  static InstallTarget _detectarTarget() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return InstallTarget.android;
    }
    final String dir = File(Platform.resolvedExecutable).parent.path;
    final bool tieneUninstaller = File('$dir/unins000.exe').existsSync();
    return tieneUninstaller
        ? InstallTarget.windowsInstaller
        : InstallTarget.windowsPortable;
  }

  static Future<UpdateInfo?> checkForUpdate() async {
    if (_token.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases?per_page=100'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final List<dynamic> releases = jsonDecode(response.body) as List<dynamic>;
      Map<String, dynamic>? mejor;
      String mejorVersion = '';
      for (final r in releases.cast<Map<String, dynamic>>()) {
        if (r['draft'] == true || r['prerelease'] == true) continue;
        final String tag = (r['tag_name'] as String?) ?? '';
        final String version = tag.startsWith('v') ? tag.substring(1) : tag;
        if (mejor == null || _esVersionMasNueva(version, mejorVersion)) {
          mejor = r;
          mejorVersion = version;
        }
      }
      if (mejor == null) return null;

      final info = await PackageInfo.fromPlatform();
      if (!_esVersionMasNueva(mejorVersion, info.version)) return null;

      final InstallTarget target = _detectarTarget();
      final String ext = switch (target) {
        InstallTarget.windowsInstaller => '.exe',
        InstallTarget.windowsPortable => '.zip',
        InstallTarget.android => '.apk',
      };
      final List<dynamic> assets = (mejor['assets'] as List?) ?? [];
      final asset = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] as String? ?? '').toLowerCase().endsWith(ext),
            orElse: () => {},
          );
      if (asset.isEmpty) return null;

      return UpdateInfo(
        version: mejorVersion,
        assetApiUrl: asset['url'] as String,
        assetName: asset['name'] as String,
        target: target,
      );
    } catch (_) {
      return null;
    }
  }

  /// Compara "X.Y.Z". true si [remota] > [actual].
  static bool _esVersionMasNueva(String remota, String actual) {
    List<int> parse(String v) =>
        v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final r = parse(remota), a = parse(actual);
    final n = r.length > a.length ? r.length : a.length;
    for (var i = 0; i < n; i++) {
      final rv = i < r.length ? r[i] : 0;
      final av = i < a.length ? a[i] : 0;
      if (rv != av) return rv > av;
    }
    return false;
  }

  static Future<File> downloadAsset(
      UpdateInfo info, void Function(double) onProgress) async {
    final request = http.Request('GET', Uri.parse(info.assetApiUrl));
    request.headers['Authorization'] = 'Bearer $_token';
    request.headers['Accept'] = 'application/octet-stream'; // descarga binaria
    final resp = await http.Client().send(request);
    if (resp.statusCode != 200) {
      throw Exception('Descarga falló: ${resp.statusCode}');
    }
    final int total = resp.contentLength ?? 0;
    int recibido = 0;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${info.assetName}');
    final sink = file.openWrite();
    await resp.stream.listen((chunk) {
      recibido += chunk.length;
      sink.add(chunk);
      if (total > 0) onProgress(recibido / total);
    }).asFuture<void>();
    await sink.close();
    return file;
  }

  static Future<void> installWindowsInstaller(File exe) async {
    await Process.start(exe.path, [], mode: ProcessStartMode.detached);
    await Future.delayed(const Duration(milliseconds: 500));
    exit(0);
  }

  /// Windows no deja sobrescribir el .exe en ejecución: se usa un script
  /// PowerShell que espera el cierre, descomprime el .zip sobre la carpeta y
  /// relanza la app. Los parámetros se incrustan en el script para evitar
  /// problemas de comillas con rutas que contienen espacios.
  static Future<void> installWindowsPortable(File zip) async {
    final String exePath = Platform.resolvedExecutable;
    final String targetDir = File(exePath).parent.path;
    final tempDir = await getTemporaryDirectory();
    final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final scriptFile = File('${tempDir.path}/update_$stamp.ps1');
    final String logPath = '${tempDir.path}/update_log.txt';
    String esc(String v) => v.replaceAll("'", "''");

    final String script = '''
\$ProcessId = $pid
\$ZipPath = '${esc(zip.path)}'
\$TargetDir = '${esc(targetDir)}'
\$ExePath = '${esc(exePath)}'
\$LogPath = '${esc(logPath)}'
function Log(\$m) { "\$(Get-Date -Format 'HH:mm:ss') \$m" | Out-File -FilePath \$LogPath -Append -Encoding utf8 }
Log "=== inicio update portable ==="
try { Wait-Process -Id \$ProcessId -Timeout 30 -ErrorAction Stop } catch { Log "Wait: \$_" }
Start-Sleep -Seconds 1
\$extract = Join-Path \$env:TEMP ("update_extract_" + [guid]::NewGuid().ToString())
try {
  Expand-Archive -LiteralPath \$ZipPath -DestinationPath \$extract -Force
  Copy-Item -Path (Join-Path \$extract '*') -Destination \$TargetDir -Recurse -Force
  Log "copia OK"
} catch { Log "ERROR: \$_" }
Remove-Item -LiteralPath \$ZipPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath \$extract -Recurse -Force -ErrorAction SilentlyContinue
try { Start-Process -FilePath \$ExePath -WorkingDirectory \$TargetDir } catch { Log "ERROR relanzar: \$_" }
Remove-Item -LiteralPath \$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
''';

    await scriptFile.writeAsString(script);
    // `cmd /c start` garantiza que PowerShell sobreviva al cierre de la app.
    await Process.start(
      'cmd',
      ['/c', 'start', '', 'powershell', '-NoProfile', '-ExecutionPolicy',
       'Bypass', '-WindowStyle', 'Hidden', '-File', scriptFile.path],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );
    await Future.delayed(const Duration(milliseconds: 800));
    exit(0);
  }

  static Future<void> installAndroid(File apk) async {
    await OpenFilex.open(apk.path);
  }
}
```

---

## 4. La pantalla bloqueante (`lib/screens/update_required_screen.dart`)

Reutilizable tal cual. Muestra la versión nueva, un botón y barra de progreso;
despacha al método de instalación según el `target`.

```dart
import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateRequiredScreen extends StatefulWidget {
  final UpdateInfo info;
  const UpdateRequiredScreen({super.key, required this.info});
  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool _descargando = false;
  double _progreso = 0.0;
  String? _error;

  Future<void> _actualizarAhora() async {
    setState(() { _descargando = true; _progreso = 0.0; _error = null; });
    try {
      final archivo = await UpdateService.downloadAsset(widget.info, (p) {
        if (mounted) setState(() => _progreso = p);
      });
      switch (widget.info.target) {
        case InstallTarget.windowsInstaller:
          await UpdateService.installWindowsInstaller(archivo);
        case InstallTarget.windowsPortable:
          await UpdateService.installWindowsPortable(archivo);
        case InstallTarget.android:
          await UpdateService.installAndroid(archivo);
      }
    } catch (e) {
      if (mounted) setState(() { _descargando = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // sin salida: hay que actualizar
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update, size: 64),
                  const SizedBox(height: 24),
                  const Text('Actualización requerida',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Hay una nueva versión (v${widget.info.version}). '
                      'Debes actualizar para continuar.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (_descargando) ...[
                    LinearProgressIndicator(value: _progreso > 0 ? _progreso : null),
                    const SizedBox(height: 8),
                    Text('${(_progreso * 100).toStringAsFixed(0)}%'),
                  ] else
                    ElevatedButton(
                      onPressed: _actualizarAhora,
                      child: const Text('Actualizar ahora'),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    TextButton(onPressed: _actualizarAhora,
                        child: const Text('Reintentar')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 5. Integración en `main.dart`

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/update_service.dart';
import 'screens/update_required_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Cargar el .env (contiene GITHUB_UPDATE_TOKEN)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('ERROR cargando .env: $e');
  }

  // ... aquí inicializas Firebase, Hive, etc. ...

  // 2) Verificar actualización antes de mostrar la UI normal
  final UpdateInfo? actualizacion = await UpdateService.checkForUpdate();
  if (actualizacion != null) {
    runApp(MainApp(pantallaInicial: UpdateRequiredScreen(info: actualizacion)));
    return; // bloquea: no se carga la app normal
  }

  runApp(const MainApp()); // sin actualización → app normal
}
```

> `checkForUpdate()` nunca lanza: ante cualquier fallo (sin red, token vacío,
> API caída) devuelve `null` y la app arranca con normalidad. La verificación
> tiene un timeout de 10 s para no colgar el arranque.

---

## 6. Publicar un release (lado emisor)

Para que una nueva versión sea detectada:

1. **Sube la versión** en `pubspec.yaml` (ej. `version: 0.4.0`). Esta es la
   versión que `package_info_plus` lee como "versión instalada".
2. Compila los binarios:
   - Windows instalador → `flutter build windows` + Inno Setup → `MiApp-Setup.exe`
   - Windows portable → comprime `build/windows/x64/runner/Release/` → `MiApp-portable.zip`
   - Android → `flutter build apk` → `app-release.apk`
3. En GitHub, crea un **Release** con:
   - **Tag** `vX.Y.Z` (ej. `v0.4.0`) — debe coincidir con `pubspec.yaml`.
   - **No marcar** como *draft* ni *prerelease*.
   - Adjunta los assets. El servicio busca por extensión:
     - `.exe` para instalador Windows
     - `.zip` para portable Windows
     - `.apk` para Android

   > El nombre del asset da igual; solo importa que termine en la extensión
   > correcta. Adjunta los tres si distribuyes en las tres modalidades.

Al siguiente arranque, las apps con versión menor verán la pantalla de
actualización.

---

## 7. Variantes y ajustes

- **Actualización opcional (no bloqueante)**: en vez de reemplazar la pantalla
  inicial, muestra un diálogo/banner con `UpdateInfo` y deja que el usuario
  elija. La lógica de `downloadAsset` + `install*` es la misma.
- **Verificación periódica**: llama a `checkForUpdate()` también con un `Timer`
  mientras la app corre, no solo al arranque.
- **Solo Windows o solo Android**: elimina las ramas del `enum`/`switch` que no
  uses y la dependencia `open_filex` si no soportas Android.
- **macOS / Linux**: añade nuevos valores a `InstallTarget` con su lógica de
  instalación (`.dmg`, `.AppImage`, `.deb`, etc.).
- **Repo público sin token**: si el repo de releases es público, puedes quitar
  el header `Authorization`. Para descargar assets públicos por la API igual
  necesitas `Accept: application/octet-stream`, o usa directamente la
  `browser_download_url` del asset.

---

## 8. Checklist de adopción

- [ ] Añadir dependencias a `pubspec.yaml` y declarar `.env` como asset.
- [ ] Crear el fine-grained PAT (Contents: Read-only) del repo.
- [ ] Crear `.env` (con token, en `.gitignore`) y `.env.example` (sin token).
- [ ] Copiar `update_service.dart` y cambiar `_owner` / `_repo`.
- [ ] Copiar `update_required_screen.dart`.
- [ ] Cargar `dotenv` y llamar `checkForUpdate()` en `main.dart`.
- [ ] Subir versión en `pubspec.yaml` y publicar un Release `vX.Y.Z` con assets.
- [ ] Probar con una versión local menor que la del release.

---

## 9. Resolución de problemas

| Síntoma | Causa probable |
|---|---|
| No detecta la actualización | Token vacío/ inválido, release marcado *draft/prerelease*, o tag sin formato `vX.Y.Z`. |
| Detecta pero "no tiene asset" | El asset no termina en `.exe`/`.zip`/`.apk` según el target. |
| Portable no se actualiza | Revisa el log en `%TEMP%\update_log.txt`; suele ser permisos de escritura en la carpeta de instalación (instálalo fuera de `Program Files`). |
| Descarga 404 / 401 | El PAT no tiene acceso al repo o le falta `Contents: Read-only`. |
| APK no instala | Falta permiso "Instalar apps desconocidas" para tu app en Android. |
