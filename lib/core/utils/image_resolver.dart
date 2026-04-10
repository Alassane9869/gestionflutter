import 'dart:io';
import 'package:flutter/material.dart';
import 'package:danaya_plus/features/settings/domain/models/shop_settings_models.dart';

class ImageResolver {
  static ImageProvider getProductImage(String? imagePath, ShopSettings? settings, {int? cacheWidth = 300}) {
    if (imagePath == null || imagePath.isEmpty) {
      final fallback = const AssetImage('assets/icons/app_icon.png');
      return cacheWidth != null ? ResizeImage(fallback, width: cacheWidth) : fallback;
    }

    ImageProvider provider;

    // 1. Check if it's a full local path
    if (imagePath.contains(Platform.pathSeparator) || 
        imagePath.contains('/') || 
        (Platform.isWindows && imagePath.contains('\\'))) {
      final file = File(imagePath);
      if (file.existsSync()) {
        provider = FileImage(file);
        return cacheWidth != null ? ResizeImage(provider, width: cacheWidth) : provider;
      }
    }

    // 2. Check if it's a remote image (Client Mode)
    if (settings != null && settings.networkMode == NetworkMode.client) {
      final baseUrl = 'http://${settings.serverIp}:${settings.serverPort}';
      provider = NetworkImage('$baseUrl/images/$imagePath');
      return cacheWidth != null ? ResizeImage(provider, width: cacheWidth) : provider;
    }

    // 3. Mode Serveur/Solo - Localhost
    if (settings != null && settings.networkMode == NetworkMode.server) {
      provider = NetworkImage('http://localhost:${settings.serverPort}/images/$imagePath');
      return cacheWidth != null ? ResizeImage(provider, width: cacheWidth) : provider;
    }

    // Fallback
    provider = FileImage(File(imagePath));
    return cacheWidth != null ? ResizeImage(provider, width: cacheWidth) : provider;
  }
}
