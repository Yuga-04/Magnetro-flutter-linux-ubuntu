import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:get/get.dart';
import '../api/seedr_api.dart';
import '../controllers/home_controller.dart';
import '../widgets/storage_bar.dart';
import '../widgets/file_tile.dart';
import '../utils/snack.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatelessWidget {
  final SeedrApi api;
  const HomeScreen({super.key, required this.api});

  // ─── Palette ───────────────────────────────────────────────────────────────
  static const _bgTop = Color.fromARGB(255, 26, 26, 26);
  static const _bgMid = Color.fromARGB(255, 21, 21, 21);
  static const _bgBottom = Color.fromARGB(255, 0, 0, 0);
  static const _accent = Color.fromARGB(255, 169, 23, 67);
  static const _textColor = Color(0xFFE0E0E0);

  static const _btnStyle = NeumorphicStyle(
    depth: 4,
    shape: NeumorphicShape.convex,
    intensity: 0.9,
    surfaceIntensity: 0.2,
    color: Color(0xFF121212),
    lightSource: LightSource.topLeft,
    shadowLightColor: Colors.white10,
    shadowDarkColor: Colors.black87,
  );

  static const _bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_bgTop, _bgMid, _bgBottom],
    stops: [0.0, 0.45, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(HomeController(api));

    return NeumorphicTheme(
      themeMode: ThemeMode.dark,
      darkTheme: const NeumorphicThemeData(
        baseColor: Color(0xFF222222),
        lightSource: LightSource.topLeft,
        depth: 4,
        intensity: 0.6,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ── Layer 1 : gradient background ─────────────────────────────
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(gradient: _bgGradient),
            ),

            // ── Layer 2 : neumorphic concave surface ───────────────────────
            Neumorphic(
              style: const NeumorphicStyle(
                shape: NeumorphicShape.concave,
                depth: 0,
                color: Colors.transparent,
                surfaceIntensity: 0.15,
                lightSource: LightSource.topLeft,
                shadowDarkColor: Colors.transparent,
                shadowLightColor: Colors.transparent,
              ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),

            // ── Layer 3 : main UI ──────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, ctrl),
                  _buildTabRow(context, ctrl), // ← NEW row
                  const SizedBox(height: 4),
                  Expanded(child: _buildFilesList(context, ctrl)),
                ],
              ),
            ),
          ],
        ),
        // ── FAB removed ────────────────────────────────────────────────────
      ),
    );
  }

  // ─── Tab Row ───────────────────────────────────────────────────────────────
  Widget _buildTabRow(BuildContext context, HomeController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // ── Left: "Torrents" with half-underline in accent red ────────────
          _TorrentsTab(accent: _accent),

          const Spacer(),

          // ── Right: "+ Add Magnet" rounded pill button ─────────────────────
          GestureDetector(
            onTap: () => _showAddMagnetDialog(context, ctrl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: _accent, size: 36),
                  SizedBox(width: 2),
                  Text(
                    'Add Magnet',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'UberMove',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, HomeController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _LogoButton(
            onTap: () => ctrl.loadFiles(force: true),
            onLongPress: () => _logout(context, ctrl),
            accent: _accent,
            bg: Colors.transparent,
            btnStyle: _btnStyle,
          ),
          const SizedBox(width: 12),
          const Text(
            'MAGNETRO',
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w700,
              fontSize: 25,
              fontFamily: 'UberMove',
            ),
          ),
          const SizedBox(width: 18),

          ValueListenableBuilder<Map<String, double>>(
            valueListenable: api.storageNotifier,
            builder: (_, storage, __) => StorageBar(
              used: storage['used'] ?? 0,
              max: storage['max'] ?? 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Files List ────────────────────────────────────────────────────────────
  Widget _buildFilesList(BuildContext context, HomeController ctrl) {
    return Obx(() {
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: _accent));
      }

      if (ctrl.files.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Neumorphic(
                style: _btnStyle.copyWith(
                  boxShape: const NeumorphicBoxShape.circle(),
                ),
                child: const SizedBox(
                  width: 100,
                  height: 100,
                  child: Center(
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.grey,
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No files yet',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                  fontFamily: 'UberMove',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap + to add a magnet link',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                  fontFamily: 'UberMove',
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 4, 10, 10),
        itemCount: ctrl.files.length,
        itemBuilder: (_, i) {
          final f = ctrl.files[i];
          final id = (f['id'] ?? '').toString();
          final name = (f['name'] ?? 'File').toString();
          final size = (f['size'] as num? ?? 0).toDouble();
          final parent = f['parent_name'] as String?;

          return FileTile(
            index: i,
            name: name,
            size: size,
            parentName: parent,
            fileId: id, // ← ADD THIS
            api: api, // ← ADD THIS
            onDownload: () => _getDownloadLink(context, id),
            onDelete: () => _confirmDelete(context, ctrl, id, name),
          );
        },
      );
    });
  }

  // ─── Magnet Dialog ─────────────────────────────────────────────────────────
  void _showAddMagnetDialog(BuildContext context, HomeController ctrl) {
    final magnetCtrl = TextEditingController();

    void submitMagnet() {
      if (ctrl.isAddingMagnet.value) return;

      final magnet = magnetCtrl.text.trim();

      if (magnet.isEmpty || !magnet.startsWith('magnet:')) {
        AppSnack.error('Please enter a valid magnet link');
        return;
      }

      Get.back();
      ctrl.addMagnet(magnet);
    }

    void cancelDialog() {
      if (!ctrl.isAddingMagnet.value) {
        Get.back();
      }
    }

    Get.dialog(
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  submitMagnet();
                  return null;
                },
              ),
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  cancelDialog();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: false,
              child: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;

                  final dialogWidth = screenWidth > 1400
                      ? 900.0
                      : screenWidth > 1000
                          ? 750.0
                          : screenWidth * 0.92;

                  return Container(
                    width: dialogWidth,
                    height: 400,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_bgTop, _bgMid, _bgBottom],
                        stops: [0.0, 0.45, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.add_link_rounded,
                              color: _accent,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Add Magnet',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                fontFamily: 'UberMove',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Obx(
                          () => Neumorphic(
                            style: NeumorphicStyle(
                              depth: 4,
                              intensity: 0.9,
                              color: const Color(0xFF0E0E0E),
                              lightSource: LightSource.topLeft,
                              shadowLightColor: Colors.white12,
                              shadowDarkColor: Colors.black87,
                              boxShape: NeumorphicBoxShape.roundRect(
                                BorderRadius.circular(12),
                              ),
                            ),
                            child: TextField(
                              controller: magnetCtrl,
                              autofocus: true,
                              enabled: !ctrl.isAddingMagnet.value,

                              minLines: 6,
                              maxLines: 6,

                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => submitMagnet(),

                              style: const TextStyle(
                                color: _textColor,
                                fontSize: 16,
                                fontFamily: 'UberMove',
                              ),
                              decoration: const InputDecoration(
                                hintText: 'magnet:?xt=urn:btih:...',
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontFamily: 'UberMove',
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        const Divider(color: Color(0x22FFFFFF), height: 1),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            const Text(
                              'Enter → Add    Esc → Cancel',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontFamily: 'UberMove',
                              ),
                            ),
                            const Spacer(),

                            Obx(
                              () => NeumorphicButton(
                                onPressed: ctrl.isAddingMagnet.value
                                    ? null
                                    : cancelDialog,
                                minDistance: 5,
                                style: _btnStyle.copyWith(
                                  color: const Color(0xFFD53B30),
                                  boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(8),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 12,
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontFamily: 'UberMove',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Obx(
                              () => NeumorphicButton(
                                onPressed: ctrl.isAddingMagnet.value
                                    ? null
                                    : submitMagnet,
                                style: _btnStyle.copyWith(
                                  boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(8),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 36,
                                  vertical: 12,
                                ),
                                child: Text(
                                  ctrl.isAddingMagnet.value
                                      ? 'Adding...'
                                      : 'Add',
                                  style: TextStyle(
                                    color: ctrl.isAddingMagnet.value
                                        ? Colors.grey
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    fontFamily: 'UberMove',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Delete Confirm ────────────────────────────────────────────────────────
  void _confirmDelete(
    BuildContext context,
    HomeController ctrl,
    String id,
    String name,
  ) {
    // ✅ FIX: ensure dialog receives keyboard focus so Shortcuts can trigger.
    final focusNode = FocusNode(debugLabel: 'delete_dialog_focus');

    void deleteFile() {
      Get.back();
      ctrl.deleteFile(id, name);
    }

    void cancelDelete() {
      Get.back();
    }

    Get.dialog(
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  deleteFile();
                  return null;
                },
              ),
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  cancelDelete();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true, // ✅ FIX
              focusNode: focusNode, // ✅ FIX
              child: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;

                  final dialogWidth = screenWidth > 1400
                      ? 900.0
                      : screenWidth > 1000
                          ? 750.0
                          : screenWidth * 0.92;

                  return Container(
                    width: dialogWidth,
                    height: 320,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_bgTop, _bgMid, _bgBottom],
                        stops: [0.0, 0.45, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFFF6B6B),
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Delete File',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                fontFamily: 'UberMove',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Are you sure you want to permanently delete:',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontFamily: 'UberMove',
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ),

                        const Spacer(),

                        const Divider(color: Color(0x22FFFFFF), height: 1),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            const Text(
                              'Enter → Delete    Esc → Cancel',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontFamily: 'UberMove',
                              ),
                            ),

                            const Spacer(),

                            NeumorphicButton(
                              onPressed: cancelDelete,
                              minDistance: 5,
                              style: _btnStyle.copyWith(
                                boxShape: NeumorphicBoxShape.roundRect(
                                  BorderRadius.circular(8),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontFamily: 'UberMove',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            NeumorphicButton(
                              onPressed: deleteFile,
                              minDistance: 5,
                              style: _btnStyle.copyWith(
                                color: const Color(0xFFD53B30),
                                boxShape: NeumorphicBoxShape.roundRect(
                                  BorderRadius.circular(8),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 36,
                                vertical: 12,
                              ),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'UberMove',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // ✅ FIX: prevent FocusNode leak
      focusNode.dispose();
    });
  }

  // ─── Download Link ─────────────────────────────────────────────────────────
  Future<void> _getDownloadLink(BuildContext context, String fileId) async {
    try {
      final url = await api.getFileDownload(fileId);
      Get.bottomSheet(
        FractionallySizedBox(
          widthFactor: 1.0, // full width
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgTop, _bgMid, _bgBottom],
                stops: [0.0, 0.45, 1.0],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    32,
                  ), // increased horizontal padding
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      const Row(
                        children: [
                          Icon(Icons.link_rounded, color: _accent, size: 32),
                          SizedBox(width: 10),
                          Text(
                            'Download Link',
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              fontFamily: 'UberMove',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: Neumorphic(
                          style: NeumorphicStyle(
                            depth: 4,
                            intensity: 0.9,
                            color: const Color(0xFF0E0E0E),
                            lightSource: LightSource.topLeft,
                            shadowLightColor: Colors.white10,
                            shadowDarkColor: Colors.black87,
                            boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: SelectableText(
                              url,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                                fontFamily: 'UberMove',
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: NeumorphicButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: url));
                                Get.back();
                                AppSnack.success('Link copied to clipboard');
                              },
                              minDistance: 3,
                              style: _btnStyle.copyWith(
                                boxShape: NeumorphicBoxShape.roundRect(
                                  BorderRadius.circular(6),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Center(
                                child: Text(
                                  'Copy Link',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'UberMove',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: NeumorphicButton(
                              onPressed: () async {
                                Get.back();

                                try {
                                  final short = await api.shortUrl(url);
                                  Clipboard.setData(ClipboardData(text: short));
                                  AppSnack.success('Short URL copied');
                                } catch (_) {
                                  AppSnack.error('URL shortening failed');
                                }
                              },
                              minDistance: 3,
                              style: _btnStyle.copyWith(
                                boxShape: NeumorphicBoxShape.roundRect(
                                  BorderRadius.circular(6),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Center(
                                child: Text(
                                  'Short & Copy',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'UberMove',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: NeumorphicButton(
                          onPressed: () async {
                            Get.back();

                            final uri = Uri.parse(url);

                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              AppSnack.error('Could not open link');
                            }
                          },
                          minDistance: 3,
                          style: _btnStyle.copyWith(
                            color: _accent,
                            boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(6),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_browser_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Download',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'UberMove',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        ignoreSafeArea: false, // lets the sheet respect safe area properly
      );
    } catch (e) {
      AppSnack.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ─── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout(BuildContext context, HomeController ctrl) async {
    await api.logout();
    Get.off(() => LoginScreen(api: api));
  }
}

// ─── Torrents Tab with half-underline ─────────────────────────────────────────
class _TorrentsTab extends StatelessWidget {
  final Color accent;
  const _TorrentsTab({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Torrents',
          style: TextStyle(
            color: Color(0xFFE0E0E0),
            fontSize: 26,
            fontWeight: FontWeight.w700,
            fontFamily: 'UberMove',
          ),
        ),
        const SizedBox(height: 1),
        // Half-width underline in accent red
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              // roughly half the text width — tweak the fraction as needed
              width: 85,
              height: 3.5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Logo Button (StatefulWidget — needs local timer state) ────────────────
class _LogoButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Color accent;
  final Color bg;
  final NeumorphicStyle btnStyle;

  const _LogoButton({
    required this.onTap,
    required this.onLongPress,
    required this.accent,
    required this.bg,
    required this.btnStyle,
  });

  @override
  State<_LogoButton> createState() => _LogoButtonState();
}

class _LogoButtonState extends State<_LogoButton> {
  Timer? _holdTimer;
  bool _holding = false;

  void _onLongPressStart(LongPressStartDetails _) {
    setState(() => _holding = true);
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (_holding) widget.onLongPress();
    });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _holdTimer?.cancel();
    setState(() => _holding = false);
  }

  void _onLongPressCancel() {
    _holdTimer?.cancel();
    setState(() => _holding = false);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: AnimatedScale(
        scale: _holding ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: SizedBox(
          width: 60,
          height: 60,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _holding
                  ? const Icon(
                      Icons.logout_rounded,
                      key: ValueKey('logout'),
                      color: Colors.redAccent,
                      size: 50,
                    )
                  : Image.asset(
                      key: const ValueKey('logo'),
                      'assets/images/logo.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}