import 'package:flutter/cupertino.dart';

class Alert {

  static void show(BuildContext context, String title, String message,
      {VoidCallback? callback}) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              if (callback != null) {
                callback();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void confirm(BuildContext context, String title, String message,
      {String? okTitle, VoidCallback? okAction,
        String? cancelTitle, VoidCallback? cancelAction}) {
    okTitle ??= 'OK';
    cancelTitle ??= 'Cancel';
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              if (okAction != null) {
                okAction();
              }
            },
            child: Text(okTitle!),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              if (cancelAction != null) {
                cancelAction();
              }
            },
            isDestructiveAction: true,
            child: Text(cancelTitle!),
          ),
        ],
      ),
    );
  }
}

class Config {
  static Config? _instance;
  Config._internal() {
    _instance = this;
    // TODO: start a background thread to query 'https://dim.chat/sechat/gsp.js'
    //       for updating configurations
  }
  factory Config() => _instance ?? Config._internal();

  get aboutURL {
    return 'https://dim.chat/';
  }

  get termsURL {
    return 'https://wallet.dim.chat/dimchat/sechat/privacy.html';
  }

  get uploadAPI {
    return 'http://106.52.25.169:8081/{ID}/upload?md5={MD5}&salt={SALT}';
  }
}
