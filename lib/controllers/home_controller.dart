import 'package:get/get.dart';
import '../api/seedr_api.dart';
import '../utils/snack.dart';

class HomeController extends GetxController {
  final SeedrApi api;
  HomeController(this.api);

  final files = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final isAddingMagnet = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadFiles();
  }

  Future<void> loadFiles({bool force = false}) async {
    isLoading.value = true;
    try {
      final result = await api.listAllFilesFlat(forceRefresh: force);
      files.assignAll(result);
      await api.refreshStorageUsage(forceRefresh: force); // ← moved inside try
    } catch (e) {
      AppSnack.error(e.toString().replaceAll('Exception: ', ''));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addMagnet(String magnet) async {
    isAddingMagnet.value = true;
    try {
      final result = await api.addMagnet(magnet);

      if (result is Map &&
          result['reason_phrase'] == 'not_enough_space_added_to_wishlist') {
        AppSnack.info('Not enough space — added to wishlist');
        isAddingMagnet.value = false;
        return;
      }

      AppSnack.info('Magnet added! Waiting for Seedr...');

      // Poll every 4s up to 5 times until files appear
      final prevCount = files.length;
      for (var attempt = 1; attempt <= 5; attempt++) {
        await Future.delayed(const Duration(seconds: 4));
        try {
          final fresh = await api.listAllFilesFlat(forceRefresh: true);
          files.assignAll(fresh);
          await api.refreshStorageUsage(forceRefresh: true);
          if (files.length > prevCount) {
            AppSnack.success('Files are ready!');
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      AppSnack.error(e.toString().replaceAll('Exception: ', ''));
    } finally {
      isAddingMagnet.value = false;
    }
  }

  Future<void> deleteFile(String fileId, String name) async {
    files.removeWhere((f) => (f['id'] ?? '').toString() == fileId);
    try {
      await api.deleteFile(fileId);
      AppSnack.success('"$name" deleted');
      await api.refreshStorageUsage(forceRefresh: true);
    } catch (e) {
      AppSnack.error(e.toString().replaceAll('Exception: ', ''));
      await loadFiles(force: true);
    }
  }
}