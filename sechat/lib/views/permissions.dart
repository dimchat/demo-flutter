import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

const List<Permission> allPermissions = [
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

class PermissionHandler {

  static List<Permission> get minimumPermissions {
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

  static List<Permission> get primaryPermissions {
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
      return allPermissions;
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

  static void openAppSettings() async {
    permission_handler.openAppSettings();
  }
}
















// class PermissionPage extends StatelessWidget {
//   const PermissionPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return const CupertinoApp(
//       home: Scaffold(
//         body: PermissionHandlerWidget(),
//       ),
//     );
//   }
// }
//
// /// A Flutter application demonstrating the functionality of this plugin
// class PermissionHandlerWidget extends StatefulWidget {
//   const PermissionHandlerWidget({super.key});
//
//   @override
//   State<PermissionHandlerWidget> createState() =>
//       _PermissionHandlerWidgetState();
// }
//
// class _PermissionHandlerWidgetState extends State<PermissionHandlerWidget> {
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: ListView(
//           children: Permission.values
//               .where((permission) {
//             if (Platform.isIOS) {
//               return permission != Permission.unknown &&
//                   permission != Permission.sms &&
//                   permission != Permission.storage &&
//                   permission != Permission.ignoreBatteryOptimizations &&
//                   permission != Permission.accessMediaLocation &&
//                   permission != Permission.activityRecognition &&
//                   permission != Permission.manageExternalStorage &&
//                   permission != Permission.systemAlertWindow &&
//                   permission != Permission.requestInstallPackages &&
//                   permission != Permission.accessNotificationPolicy &&
//                   permission != Permission.bluetoothScan &&
//                   permission != Permission.bluetoothAdvertise &&
//                   permission != Permission.bluetoothConnect;
//             } else {
//               return permission != Permission.unknown &&
//                   permission != Permission.mediaLibrary &&
//                   permission != Permission.photos &&
//                   permission != Permission.photosAddOnly &&
//                   permission != Permission.reminders &&
//                   permission != Permission.appTrackingTransparency &&
//                   permission != Permission.criticalAlerts;
//             }
//           })
//               .map((permission) => PermissionWidget(permission))
//               .toList()),
//     );
//   }
// }
//
// /// Permission widget containing information about the passed [Permission]
// class PermissionWidget extends StatefulWidget {
//   /// Constructs a [PermissionWidget] for the supplied [Permission]
//   const PermissionWidget(this._permission, {super.key});
//
//   final Permission _permission;
//
//   @override
//   State<PermissionWidget> createState() => _PermissionState(_permission);
// }
//
// class _PermissionState extends State<PermissionWidget> {
//   // _PermissionState() {
//   //   _permission = widget._permission;
//   // }
//   _PermissionState(this._permission);
//
//   final Permission _permission;
//   PermissionStatus _permissionStatus = PermissionStatus.denied;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _listenForPermissionStatus();
//   }
//
//   void _listenForPermissionStatus() async {
//     final status = await _permission.status;
//     setState(() => _permissionStatus = status);
//   }
//
//   Color getPermissionColor() {
//     switch (_permissionStatus) {
//       case PermissionStatus.denied:
//         return Colors.red;
//       case PermissionStatus.granted:
//         return Colors.green;
//       case PermissionStatus.limited:
//         return Colors.orange;
//       default:
//         return Colors.grey;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       title: Text(
//         _permission.toString(),
//         style: Theme.of(context).textTheme.bodyText1,
//       ),
//       subtitle: Text(
//         _permissionStatus.toString(),
//         style: TextStyle(color: getPermissionColor()),
//       ),
//       trailing: (_permission is PermissionWithService)
//           ? IconButton(
//           icon: const Icon(
//             Icons.info,
//             color: Colors.green,
//           ),
//           onPressed: () {
//             checkServiceStatus(
//                 context, _permission as PermissionWithService);
//           })
//           : null,
//       onTap: () {
//         requestPermission(_permission);
//       },
//     );
//   }
//
//   void checkServiceStatus(
//       BuildContext context, PermissionWithService permission) async {
//     // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//     //   content: Text((await permission.serviceStatus).toString()),
//     // ));
//     Alert.show(context, 'Snack Bar', (await permission.serviceStatus).toString());
//   }
//
//   Future<void> requestPermission(Permission permission) async {
//     final status = await permission.request();
//
//     setState(() {
//       print(status);
//       _permissionStatus = status;
//       print(_permissionStatus);
//     });
//   }
// }
