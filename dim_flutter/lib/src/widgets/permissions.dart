import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:dim_client/ok.dart';

import '../common/platform.dart';
import 'alert.dart';


class PermissionChecker {
  factory PermissionChecker() => _instance;
  static final PermissionChecker _instance = PermissionChecker._internal();
  PermissionChecker._internal();

  bool? _isNotificationAllowed;

  bool _needsNotification = false;
  bool _checkingForNotification = false;

  bool? get isNotificationPermissionGranted => _isNotificationAllowed;
  // bool get needsNotificationPermissions => _needsNotification;

  void setNeedsNotificationPermissions() {
    _needsNotification = true;
    _checkingForNotification = true;
  }
  void checkAgain() {
    if (_needsNotification) {
      // _isNotificationAllowed = null;
      _checkingForNotification = true;
    }
  }

  Future<bool> checkNotificationPermissions(BuildContext context) async {
    if (_checkingForNotification) {
      // needs checking now
      _checkingForNotification = false;
    } else {
      Log.info('no need to check notification permissions now');
      return _isNotificationAllowed == true;
    }
    Log.info('checking notification permissions');
    var center = PermissionCenter();
    bool granted = await center.requestNotificationPermissions(context,
      onGranted: (context) => Log.info('notification permissions granted.'),
    );
    _isNotificationAllowed = granted;
    return granted;
  }

  Future<bool> checkDatabasePermissions() async => _PermissionHandler.check(
    _PermissionHandler.databasePermissions,
    onDenied: (permission) => Log.error('database permissions denied: $permission'),
  );

}


class PermissionCenter {
  factory PermissionCenter() => _instance;
  static final PermissionCenter _instance = PermissionCenter._internal();
  PermissionCenter._internal();

  Future<bool> openSettings() async {
    PermissionChecker().checkAgain();
    return await openAppSettings();
  }

  Future<bool> requestDatabasePermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.databasePermissions,
    'Grant to access external storage'.tr,
    context: context,
    onGranted: onGranted,
  );

  Future<bool> requestPhotoReadingPermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.photoReadingPermissions,
    'Grant to access photo album'.tr,
    context: context,
    onGranted: onGranted,
  );

  Future<bool> requestPhotoAccessingPermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.photoAccessingPermissions,
    'Grant to access photo album'.tr,
    context: context,
    onGranted: onGranted,
  );

  Future<bool> requestCameraPermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.cameraPermissions,
    'Grant to access camera'.tr,
    context: context,
    onGranted: onGranted,
  );

  Future<bool> requestMicrophonePermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.microphonePermissions,
    'Grant to access microphone'.tr,
    context: context,
    onGranted: onGranted,
  );

  Future<bool> requestNotificationPermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.notificationPermissions,
    'Grant to allow notifications'.tr,
    context: context,
    onGranted: onGranted,
  );

}


Future<bool> _requestPermissions(List<Permission> permissions, String message, {
  required BuildContext context,
  required void Function(BuildContext context) onGranted
}) async {
  bool granted = await _PermissionHandler.request(
    permissions,
    onDenied: (permission) => Alert.confirm(context,
      'Permission Denied',
      message,
      okTitle: 'Settings',
      okAction: () => PermissionCenter().openSettings(),
    ),
  );
  if (granted && context.mounted) {
    onGranted(context);
  }
  return granted;
}


class _PermissionHandler {

  static Future<bool> check(List<Permission> permissions, {
    required void Function(Permission permission) onDenied
  }) async {
    PermissionStatus status;
    bool isGranted;
    Log.info('check permissions: $permissions');
    for (Permission item in permissions) {
      try {
        status = await item.status;
        isGranted = status.isGranted;
      } catch (e, st) {
        Log.error('check permission error: $e, $st');
        assert(false, 'failed to check permission: $item');
        isGranted = false;
      }
      if (isGranted) {
        // OK
        Log.info('permission granted: $item');
        continue;
      }
      Log.warning('permission status: $isGranted, $item');
      // status != PermissionStatus.granted
      onDenied(item);
      return false;
    }
    return true;
  }

  static Future<bool> request(List<Permission> permissions, {
    required void Function(Permission permission) onDenied
  }) async {
    PermissionStatus status;
    bool isGranted;
    Log.info('request permissions: $permissions');
    for (Permission item in permissions) {
      try {
        status = await item.request();
        isGranted = status.isGranted;
      } catch (e, st) {
        Log.error('request permission error: $e, $st');
        assert(false, 'failed to request permission: $item');
        isGranted = false;
      }
      if (isGranted) {
        // OK
        Log.info('permission granted: $item');
        continue;
      }
      Log.warning('permission status: $isGranted, $item');
      // status != PermissionStatus.granted
      onDenied(item);
      return false;
    }
    return true;
  }

  //
  //  All Permissions
  //

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
    if (DevicePlatform.isIOS)
    Permission.photos,
  ];

  static List<Permission> get photoAccessingPermissions => _photoAccessingPermissions;
  static final List<Permission> _photoAccessingPermissions = [
    /// When running on Android T and above: Read image files from external storage
    /// When running on Android < T: Nothing
    /// iOS: Photos
    /// iOS 14+ read & write access level
    if (DevicePlatform.isIOS)
    Permission.photos,

    /// Android: Nothing
    /// iOS: Photos
    /// iOS 14+ read & write access level
    if (DevicePlatform.isIOS)
    Permission.photosAddOnly,

    /// Android: External Storage
    /// iOS: Access to folders like `Documents` or `Downloads`. Implicitly
    /// granted.
    // if (DevicePlatform.isAndroid)
    // Permission.storage,
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

  static List<Permission> get notificationPermissions => [
    /// Android: Firebase Cloud Messaging
    Permission.notification,
  ];

}

bool _isPhotoPermissionsFixed = false;

Future<bool> fixPhotoPermissions() async {
  if (_isPhotoPermissionsFixed) {
    return false;
  } else {
    _isPhotoPermissionsFixed = true;
  }
  if (DevicePlatform.isAndroid) {
    AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
    int sdkInt = info.version.sdkInt;
    Log.warning('fixing photo permissions: $sdkInt');
    if (sdkInt > 32) {
      _PermissionHandler._photoAccessingPermissions.add(Permission.photos);
      _PermissionHandler._photoReadingPermissions.add(Permission.photos);
    } else {
      _PermissionHandler._photoAccessingPermissions.add(Permission.storage);
      _PermissionHandler._photoReadingPermissions.add(Permission.storage);
    }
    return true;
  }
  return false;
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
