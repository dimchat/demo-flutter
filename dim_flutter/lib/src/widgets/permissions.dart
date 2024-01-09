import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lnc/lnc.dart';

import 'alert.dart';


Future<bool> checkDatabasePermissions() async =>
    _PermissionHandler.check(_PermissionHandler.databasePermissions);

void requestDatabasePermissions(BuildContext context,
    {required void Function(BuildContext context) onGranted}) =>
    _PermissionHandler.request(
      _PermissionHandler.databasePermissions,
      onDenied: (permission) => Alert.show(context, 'Permission Denied',
        'Grant to access external storage'.tr,
        callback: () => openAppSettings(),
      ),
    ).then((granted) {
      if (granted) {
        onGranted(context);
      }
    });

void requestPhotoReadingPermissions(BuildContext context,
    {required void Function(BuildContext context) onGranted}) =>
    _PermissionHandler.request(
      _PermissionHandler.photoReadingPermissions,
      onDenied: (permission) => Alert.show(context, 'Permission Denied',
        'Grant to access photo album'.tr,
        callback: () => openAppSettings(),
      ),
    ).then((granted) {
      if (granted) {
        onGranted(context);
      }
    });

void requestPhotoAccessingPermissions(BuildContext context,
    {required void Function(BuildContext context) onGranted}) =>
    _PermissionHandler.request(
      _PermissionHandler.photoAccessingPermissions,
      onDenied: (permission) => Alert.show(context, 'Permission Denied',
        'Grant to access photo album'.tr,
        callback: () => openAppSettings(),
      ),
    ).then((granted) {
      if (granted) {
        onGranted(context);
      }
    });

void requestCameraPermissions(BuildContext context,
    {required void Function(BuildContext context) onGranted}) =>
    _PermissionHandler.request(
      _PermissionHandler.cameraPermissions,
      onDenied: (permission) => Alert.show(context, 'Permission Denied',
        'Grant to access camera'.tr,
        callback: () => openAppSettings(),
      ),
    ).then((granted) {
      if (granted) {
        onGranted(context);
      }
    });

void requestMicrophonePermissions(BuildContext context,
    {required void Function(BuildContext context) onGranted}) =>
    _PermissionHandler.request(
      _PermissionHandler.microphonePermissions,
      onDenied: (permission) => Alert.show(context, 'Permission Denied',
        'Grant to access microphone'.tr,
        callback: () => openAppSettings(),
      ),
    ).then((granted) {
      if (granted) {
        onGranted(context);
      }
    });


class _PermissionHandler {

  static Future<bool> check(List<Permission> permissions) async {
    PermissionStatus status;
    for (Permission item in permissions) {
      status = await item.status;
      if (status.isGranted) {
        // OK
        continue;
      }
      Log.warning('permission status: $status, $item');
      // status != PermissionStatus.granted
      return false;
    }
    return true;
  }

  static Future<bool> request(List<Permission> permissions,
      {required void Function(Permission permission) onDenied}) async {
    PermissionStatus status;
    Log.info('request permissions: $permissions');
    for (Permission item in permissions) {
      try {
        status = await item.request();
      } catch (e, st) {
        Log.error('request permission error: $e, $st');
        assert(false, 'failed to request permission: $item');
        continue;
      }
      if (status.isGranted) {
        // OK
        Log.info('permission granted: $item');
        continue;
      }
      Log.warning('permission status: $status, $item');
      // status != PermissionStatus.granted
      onDenied(item);
      return false;
    }
    return true;
  }

  static List<Permission> get databasePermissions => [
    /// Android: External Storage
    /// iOS: Access to folders like `Documents` or `Downloads`. Implicitly
    /// granted.
    // Permission.storage,
  ];

  static List<Permission> get photoReadingPermissions => _photoReadingPermissions;
  static final List<Permission> _photoReadingPermissions = [
    /// When running on Android T and above: Read image files from external storage
    /// When running on Android < T: Nothing
    /// iOS: Photos
    /// iOS 14+ read & write access level
    if (Platform.isIOS)
    Permission.photos,
  ];

  static List<Permission> get photoAccessingPermissions => _photoAccessingPermissions;
  static final List<Permission> _photoAccessingPermissions = [
    /// When running on Android T and above: Read image files from external storage
    /// When running on Android < T: Nothing
    /// iOS: Photos
    /// iOS 14+ read & write access level
    if (Platform.isIOS)
    Permission.photos,

    /// Android: Nothing
    /// iOS: Photos
    /// iOS 14+ read & write access level
    if (Platform.isIOS)
    Permission.photosAddOnly,

    /// Android: External Storage
    /// iOS: Access to folders like `Documents` or `Downloads`. Implicitly
    /// granted.
    if (Platform.isAndroid)
    Permission.storage,
  ];

  static List<Permission> get cameraPermissions => [
    /// Android: Camera
    /// iOS: Photos (Camera Roll and Camera)
    Permission.camera,

    // Permission.storage,
  ];

  static List<Permission> get microphonePermissions => [
    /// Android: Microphone
    /// iOS: Microphone
    Permission.microphone,
  ];

}

bool _fixedForAndroid = false;

Future<void> fixPhotoPermissions() async {
  if (_fixedForAndroid) {
    return;
  }
  if (Platform.isAndroid) {
    AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
    int sdkInt = info.version.sdkInt;
    Log.warning('fixing photo permissions: $sdkInt');
    if (sdkInt > 32) {
      _PermissionHandler._photoAccessingPermissions.add(Permission.photos);
      _PermissionHandler._photoReadingPermissions.add(Permission.photos);
    } else {
      _PermissionHandler._photoReadingPermissions.add(Permission.storage);
    }
  }
  _fixedForAndroid = true;
}


/* iOS Podfile:

    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',

        ## dart: PermissionGroup.calendar
        # 'PERMISSION_EVENTS=1',

        ## dart: PermissionGroup.reminders
        # 'PERMISSION_REMINDERS=1',

        ## dart: PermissionGroup.contacts
        # 'PERMISSION_CONTACTS=1',

        ## dart: PermissionGroup.camera
        'PERMISSION_CAMERA=1',

        ## dart: PermissionGroup.microphone
        'PERMISSION_MICROPHONE=1',

        ## dart: PermissionGroup.speech
        # 'PERMISSION_SPEECH_RECOGNIZER=1',

        ## dart: PermissionGroup.photos
        'PERMISSION_PHOTOS=1',
        'PERMISSION_PHOTOS_ADD_ONLY=1',

        ## dart: [PermissionGroup.location, PermissionGroup.locationAlways, PermissionGroup.locationWhenInUse]
        # 'PERMISSION_LOCATION=1',

        ## dart: PermissionGroup.notification
        # 'PERMISSION_NOTIFICATIONS=1',

        ## dart: PermissionGroup.mediaLibrary
        # 'PERMISSION_MEDIA_LIBRARY=1',

        ## dart: PermissionGroup.sensors
        # 'PERMISSION_SENSORS=1',

        ## dart: PermissionGroup.bluetooth
        # 'PERMISSION_BLUETOOTH=1',

        ## dart: PermissionGroup.appTrackingTransparency
        # 'PERMISSION_APP_TRACKING_TRANSPARENCY=1',

        ## dart: PermissionGroup.criticalAlerts
        # 'PERMISSION_CRITICAL_ALERTS=1'
      ]
    end

*/
