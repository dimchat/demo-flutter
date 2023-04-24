import 'dart:io';

import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as lib;

import 'alert.dart';

const List<Permission> _allPermissions = [
  /// Android: Camera
  /// iOS: Photos (Camera Roll and Camera)
  Permission.camera,

  /// Android: Microphone
  /// iOS: Microphone
  Permission.microphone,

  /// When running on Android T and above: Read image files from external storage
  /// When running on Android < T: Nothing
  /// iOS: Photos
  /// iOS 14+ read & write access level
  Permission.photos,

  /// Android: Nothing
  /// iOS: Photos
  /// iOS 14+ read & write access level
  Permission.photosAddOnly,

  /// Android: Microphone
  /// iOS: Speech
  Permission.speech,

  /// Android: External Storage
  /// iOS: Access to folders like `Documents` or `Downloads`. Implicitly
  /// granted.
  Permission.storage,

  /// Android: Notification
  /// iOS: Notification
  Permission.notification,

  // /// Android: Allows an app to request installing packages.
  // /// iOS: Nothing
  // Permission.requestInstallPackages,
  //
  // /// When running on Android T and above: Read video files from external storage
  // /// When running on Android < T: Nothing
  // /// iOS: Nothing
  // Permission.videos,
  //
  // /// When running on Android T and above: Read audio files from external storage
  // /// When running on Android < T: Nothing
  // /// iOS: Nothing
  // Permission.audio,
];

class _PermissionHandler {

  static List<Permission> get primaryPermissions {
    if (Platform.isIOS) {
      // iOS
      return [
        Permission.photos,
        Permission.photosAddOnly,
        // Permission.storage,
      ];
    } else if (Platform.isAndroid) {
      // Android
      return [
        // Permission.photos,
        // Permission.photosAddOnly,
        Permission.storage,
      ];
    } else {
      return [
        Permission.photos,
        Permission.photosAddOnly,
        Permission.storage,
      ];
    }
  }

  static List<Permission> get secondaryPermissions {
    if (Platform.isIOS) {
      // iOS
      return [
        Permission.camera,
        Permission.microphone,
        Permission.photos,
        Permission.photosAddOnly,
        Permission.speech,
        // Permission.storage,
        Permission.notification,
      ];
    } else if (Platform.isAndroid) {
      // Android
      return [
        Permission.camera,
        Permission.microphone,
        // Permission.photos,
        // Permission.photosAddOnly,
        Permission.speech,
        Permission.storage,
        Permission.notification,
      ];
    } else {
      return _allPermissions;
    }
  }

  static Future<bool> check(List<Permission> permissions) async {
    PermissionStatus status;
    for (Permission item in permissions) {
      status = await item.status;
      if (status != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  static Future<bool> request(List<Permission> permissions) async {
    PermissionStatus status;
    for (Permission item in permissions) {
      status = await item.request();
      if (status != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  static void openAppSettings() async => lib.openAppSettings();
}

Future<bool> checkPrimaryPermissions() async {
  return await _PermissionHandler.check(_PermissionHandler.primaryPermissions);
}

void requestPrimaryPermissions(BuildContext context,
    {required void Function(BuildContext context) onGranted}) {
  _PermissionHandler.request(_PermissionHandler.primaryPermissions).then((value) {
    if (!value) {
      // base permissions not granted
      Alert.show(context, 'Permission denied',
        'You should grant the permission to continue using this app.',
        callback: () => _PermissionHandler.openAppSettings(),
      );
    } else {
      Log.info('permission granted');
      onGranted(context);
    }
  }).onError((error, stackTrace) {
    Log.error('request permission error: $error');
  });
}

void requestSecondaryPermissions(BuildContext context,
    {required void Function(BuildContext context) onGranted}) {
  _PermissionHandler.request(_PermissionHandler.secondaryPermissions).then((value) {
    if (!value) {
      // advanced permissions not granted
      Alert.show(context, 'Permission denied',
        'You should grant the permission to continue using this function.',
        callback: () => _PermissionHandler.openAppSettings(),
      );
    } else {
      Log.info('permission granted');
      onGranted(context);
    }
  }).onError((error, stackTrace) {
    Log.error('request permission error: $error');
  });
}
