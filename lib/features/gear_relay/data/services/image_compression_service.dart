import 'package:flutter_image_compress/flutter_image_compress.dart';

abstract class ImageCompressionService {
  Future<String> compressImage(String sourcePath);
}

class ImageCompressionServiceImpl implements ImageCompressionService {
  @override
  Future<String> compressImage(String sourcePath) async {
    try {
      final targetPath = '${sourcePath}_compressed.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: 80,
        minWidth: 1920,
        minHeight: 1080,
      );
      return result?.path ?? sourcePath;
    } catch (_) {
      return sourcePath;
    }
  }
}
