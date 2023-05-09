import 'package:flutter/services.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;

import '../client/constants.dart';
import '../client/filesys/paths.dart';
import '../models/config.dart';
import 'manager.dart';

class FileTransferChannel extends MethodChannel {
  FileTransferChannel(super.name) {
    setMethodCallHandler(_handle);
  }

  final Map<String, Uri> _uploads = {};    // filename => download url
  final Map<Uri, String> _downloads = {};  // url => file path

  static final Uri _upWaiting = Uri.parse('https://chat.dim.sechat/up/waiting');
  static final Uri _upError = Uri.parse('https://chat.dim.sechat/up/error');
  static const String _downWaiting = '/tmp/down/waiting';
  static const String _downError = '/tmp/down/error';

  /// upload task will be expired after 10 minutes
  static int uploadExpires = 10 * 60 * 1000;

  /// root directory for local storage
  bool _apiUpdated = false;

  Future<void> _prepare() async {
    if (_apiUpdated) {
      return;
    }
    // config for upload
    Config config = Config();
    List api = await config.uploadAPI;
    String secret = await config.uploadKey;
    Log.warning('setUploadConfig: $secret, $api');
    assert(api.isNotEmpty, 'upload API not found');
    // TODO: pick up the fastest API for upload
    await setUploadConfig(api: api[0], secret: secret);
    _apiUpdated = true;
  }

  /// MethCallHandler
  Future<void> _handle(MethodCall call) async {
    String method = call.method;
    Map arguments = call.arguments;
    if (method == ChannelMethods.onDownloadSuccess) {
      String urlString = arguments['url'];
      Uri url = Uri.parse(urlString);
      String path = arguments['path'];
      Log.warning('download success: $url -> $path');
      _downloads[url] = path;
    } else if (method == ChannelMethods.onDownloadFailure) {
      String urlString = arguments['url'];
      Uri url = Uri.parse(urlString);
      Log.error('download $url error: ${arguments['error']}');
      _downloads[url] = _downError;
    } else if (method == ChannelMethods.onUploadSuccess) {
      String? filename = arguments['filename'];
      filename ??= Paths.filename(arguments['path']);
      Map res = arguments['response'];
      Uri url = Uri.parse(res['url']);
      Log.warning('upload success: $filename -> $url');
      _uploads[filename!] = url;
    } else if (method == ChannelMethods.onUploadFailure) {
      String? filename = arguments['filename'];
      filename ??= Paths.filename(arguments['path']);
      Log.error('upload $filename error: ${arguments['error']}');
      _uploads[filename!] = _upError;
    }
  }

  //
  //  Invoke Methods
  //
  Future<dynamic> _invoke(String method, Map? arguments) async {
    try {
      return await invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      return;
    }
  }

  /// set upload API & secret key
  Future<void> setUploadConfig({required String api, required String secret}) async {
    _invoke(ChannelMethods.setUploadAPI, {
      'api': api,
      'secret': secret,
    });
  }

  ///  Upload avatar image data for user
  ///
  /// @param data     - image data
  /// @param filename - image filename ('${hex(md5(data))}.jpg')
  /// @param sender   - user ID
  /// @return remote URL if same file uploaded before
  Future<Uri?> uploadAvatar(Uint8List data, String filename, ID sender) async {
    return await _doUpload(ChannelMethods.uploadAvatar, data, filename, sender);
  }

  ///  Upload encrypted file data for user
  ///
  /// @param data     - encrypted data
  /// @param filename - data file name ('${hex(md5(data))}.mp4')
  /// @param sender   - user ID
  /// @return remote URL if same file uploaded before
  Future<Uri?> uploadEncryptData(Uint8List data, String filename, ID sender) async {
    return await _doUpload(ChannelMethods.uploadFile, data, filename, sender);
  }

  ///  Download avatar image file
  ///
  /// @param url      - avatar URL
  /// @return local path if same file downloaded before
  Future<String?> downloadAvatar(Uri url) async {
    return await _doDownload(ChannelMethods.downloadAvatar, url);
  }

  ///  Download encrypted file data for user
  ///
  /// @param url      - relay URL
  /// @return temporary path if same file downloaded before
  Future<String?> downloadFile(Uri url) async {
    return await _doDownload(ChannelMethods.downloadFile, url);
  }

  Future<Uri?> _doUpload(String method, Uint8List data, String filename, ID sender) async {
    await _prepare();
    // 1. check old task
    Uri? url = _uploads[filename];
    if (url == null) {
      Log.warning('new task, try to upload: $filename');
      url = _upWaiting;
      _uploads[filename] = url;
    } else if (url == _upError) {
      Log.warning('error task, try to upload again: $filename');
      url = _upWaiting;
      _uploads[filename] = url;
    }
    // 2. do upload
    if (url == _upWaiting) {
      // call ftp client to upload
      url = await _invoke(method, {
        'data': data,
        'filename': filename,
        'sender': sender.toString(),
      });
      if (url != null) {
        Log.error('same file uploaded: $filename -> $url');
      }
      int now = Time.currentTimeMillis;
      int expired = now + uploadExpires;
      while (url == null || url == _upWaiting) {
        // wait a while to check the result
        await Future.delayed(const Duration(milliseconds: 512));
        url = _uploads[filename];
        now = Time.currentTimeMillis;
        if (now > expired) {
          Log.error('upload expired: $filename');
          break;
        }
      }
      // check result
      if (url == null || url == _upWaiting) {
        url = _upError;
        _uploads[filename] = url;
      }
    }
    Log.info('upload result: $filename -> $url');
    // 3. return url when not error
    String notification;
    if (url == _upError) {
      url = null;
      notification = NotificationNames.kFileUploadFailure;
    } else {
      assert(url != _upWaiting, 'upload result error: $filename -> $url');
      notification = NotificationNames.kFileUploadSuccess;
    }
    // post notification async
    var nc = lnc.NotificationCenter();
    nc.postNotification(notification, this, {
      'filename': filename,
      'url': url,
    });
    return url;
  }

  Future<String?> _doDownload(String method, Uri url) async {
    await _prepare();
    // 1. check old task
    String? path = _downloads[url];
    if (path == null) {
      Log.info('new task, try to download: $url');
      path = _downWaiting;
      _downloads[url] = path;
    } else if (path == _downError) {
      Log.warning('error task, try to download again: $url');
      path = _downWaiting;
      _downloads[url] = path;
    }
    // 2. do download
    if (path == _downWaiting) {
      // call ftp client to download
      path = await _invoke(method, {
        'url': url.toString(),
      });
      if (path != null) {
        Log.debug('found cached file: $path -> $url');
      }
      int now = Time.currentTimeMillis;
      int expired = now + uploadExpires;
      while (path == null || path == _downWaiting) {
        // wait a while to check the result
        await Future.delayed(const Duration(milliseconds: 512));
        path = _downloads[url];
        now = Time.currentTimeMillis;
        if (now > expired) {
          Log.error('download expired: $url');
          break;
        }
      }
      // check result
      if (path == null || path == _downWaiting) {
        path = _downError;
        _downloads[url] = path;
      }
    } else {
      Log.debug('memory cached file: $path -> $url');
    }
    // 3. return url when not error
    if (path == _downError) {
      path = null;
    } else {
      assert(path != _downWaiting, 'download task error: $url -> $path');
    }
    return path;
  }

}
