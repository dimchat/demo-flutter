import 'package:flutter/cupertino.dart';
import 'package:lnc/lnc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'alert.dart';


Future<bool> checkStoragePermissions() async =>
    _PermissionHandler.check(_PermissionHandler.storagePermissions);

void requestStoragePermissions(BuildContext context,
    {required void Function(BuildContext context) onGranted}) =>
    _PermissionHandler.request(
      _PermissionHandler.storagePermissions,
      onDenied: (permission) => Alert.show(context, 'Permission denied',
        'You should grant the permission to access external storage.',
        callback: () => openAppSettings(),
      ),
    ).then((granted) {
      if (granted) {
        onGranted(context);
      }
    });

void requestPhotosPermissions(BuildContext context,
    {required void Function(BuildContext context) onGranted}) =>
    _PermissionHandler.request(
      _PermissionHandler.photosPermissions,
      onDenied: (permission) => Alert.show(context, 'Permission denied',
        'You should grant the permission to access photo album.',
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
      onDenied: (permission) => Alert.show(context, 'Permission denied',
        'You should grant the permission to access camera.',
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
      onDenied: (permission) => Alert.show(context, 'Permission denied',
        'You should grant the permission to access microphone.',
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
      if (status == PermissionStatus.granted) {
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
    for (Permission item in permissions) {
      status = await item.request();
      if (status == PermissionStatus.granted) {
        // OK
        continue;
      }
      Log.warning('permission status: $status, $item');
      // status != PermissionStatus.granted
      onDenied(item);
      return false;
    }
    return true;
  }

  static List<Permission> get storagePermissions => [
    /// Android: External Storage
    /// iOS: Access to folders like `Documents` or `Downloads`. Implicitly
    /// granted.
    // Permission.storage,
  ];

  static List<Permission> get photosPermissions => [
    /// When running on Android T and above: Read image files from external storage
    /// When running on Android < T: Nothing
    /// iOS: Photos
    /// iOS 14+ read & write access level
    Permission.photos,

    /// Android: Nothing
    /// iOS: Photos
    /// iOS 14+ read & write access level
    // Permission.photosAddOnly,

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
