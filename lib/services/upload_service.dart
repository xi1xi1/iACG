import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 上传头像
  Future<String?> uploadAvatar({
    required String userId,
    File? imageFile,
    Uint8List? imageBytes,
  }) async {
    try {
      // 生成唯一的文件名
      final String fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'avatars/$userId/$fileName';

      // 根据平台选择上传方式
      if (kIsWeb) {
        // Web 平台:使用字节数据上传
        if (imageBytes == null) {
          throw Exception('Web 平台需要提供 imageBytes');
        }
        await _client.storage
            .from('avatars')
            .uploadBinary(filePath, imageBytes);
      } else {
        // 移动/桌面平台:使用 File 上传
        if (imageFile == null) {
          throw Exception('移动平台需要提供 imageFile');
        }
        await _client.storage
            .from('avatars')
            .upload(filePath, imageFile);
      }

      // 获取公开URL
      final String publicUrl = _client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      print('头像上传错误: $e');
      rethrow;
    }
  }

  /// 上传帖子图片
  Future<List<String>> uploadPostImages({
    required int postId,
    List<File>? imageFiles,
    List<Uint8List>? imageBytesArray,
  }) async {
    try {
      final List<String> imageUrls = [];

      if (kIsWeb) {
        // Web 平台:使用字节数组上传
        if (imageBytesArray == null || imageBytesArray.isEmpty) {
          throw Exception('Web 平台需要提供 imageBytesArray');
        }

        for (int i = 0; i < imageBytesArray.length; i++) {
          final String fileName = 'post_${postId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final String filePath = 'post-images/$postId/$fileName';

          // 上传文件
          await _client.storage
              .from('post-images')
              .uploadBinary(filePath, imageBytesArray[i]);

          // 获取公开URL
          final String publicUrl = _client.storage
              .from('post-images')
              .getPublicUrl(filePath);

          imageUrls.add(publicUrl);
        }
      } else {
        // 移动/桌面平台:使用 File 上传
        if (imageFiles == null || imageFiles.isEmpty) {
          throw Exception('移动平台需要提供 imageFiles');
        }

        for (int i = 0; i < imageFiles.length; i++) {
          final String fileName = 'post_${postId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final String filePath = 'post-images/$postId/$fileName';

          // 上传文件
          await _client.storage
              .from('post-images')
              .upload(filePath, imageFiles[i]);

          // 获取公开URL
          final String publicUrl = _client.storage
              .from('post-images')
              .getPublicUrl(filePath);

          imageUrls.add(publicUrl);
        }
      }

      return imageUrls;
    } catch (e) {
      print('帖子图片上传错误: $e');
      rethrow;
    }
  }

  /// 删除头像
  Future<void> deleteAvatar({
    required String userId,
    required String fileName,
  }) async {
    try {
      final String filePath = 'avatars/$userId/$fileName';
      await _client.storage
          .from('avatars')
          .remove([filePath]);
    } catch (e) {
      print('头像删除错误: $e');
      rethrow;
    }
  }

  /// 删除帖子图片
  Future<void> deletePostImages({
    required int postId,
    required List<String> fileNames,
  }) async {
    try {
      final List<String> filePaths = fileNames
          .map((fileName) => 'post-images/$postId/$fileName')
          .toList();
      
      await _client.storage
          .from('post-images')
          .remove(filePaths);
    } catch (e) {
      print('帖子图片删除错误: $e');
      rethrow;
    }
  }
}