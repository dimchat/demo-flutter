import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../channels/manager.dart';
import '../channels/transfer.dart';
import '../models/conversation.dart';
import 'constants.dart';
import 'http/ftp.dart';
import 'shared.dart';

class Emitter implements Observer {
  Emitter() {
    var nc = NotificationCenter();
    nc.addObserver(this, NotificationNames.kFileUploadSuccess);
    nc.addObserver(this, NotificationNames.kFileUploadFailure);
  }
  
  /// filename => task
  final Map<String, InstantMessage> _outgoing = {};

  void _addTask(String filename, InstantMessage item) {
    _outgoing[filename] = item;
  }

  InstantMessage? _popTask(String filename) {
    InstantMessage? item = _outgoing[filename];
    if (item != null) {
      _outgoing.remove(filename);
    }
    return item;
  }

  void purge() {
    // TODO: remove expired messages in the map
  }

  @override
  Future<void> onReceiveNotification(Notification notification) async {
    String name = notification.name;
    Map info = notification.userInfo!;
    if (name == NotificationNames.kFileUploadSuccess) {
      String filename = info['filename'];
      Uri url = info['url'];
      await _onUploadSuccess(filename, url);
    } else if (name == NotificationNames.kFileUploadFailure) {
      String filename = info['filename'];
      _onUploadFailed(filename);
    }
  }

  Future<void> _onUploadSuccess(String filename, Uri url) async {
    InstantMessage? iMsg = _popTask(filename);
    if (iMsg == null) {
      Log.error('failed to get task: $filename, url: $url');
      return;
    }
    Log.info('get task for file: $filename, url: $url');
    // file data uploaded to FTP server, replace it with download URL
    // and send the content to station
    FileContent content = iMsg.content as FileContent;
    // content.data = null;
    content.url = url.toString();
    return await _sendInstantMessage(iMsg).onError((error, stackTrace) {
      Log.error('failed to send message: $error');
    });
  }

  Future<void> _onUploadFailed(String filename) async {
    InstantMessage? iMsg = _popTask(filename);
    if (iMsg == null) {
      Log.error('failed to get task: $filename');
      return;
    }
    Log.info('get task for file: $filename');
    // file data failed to upload, mark it error
    iMsg['error'] = {
      'message': 'failed to upload file',
    };
    return await _saveInstantMessage(iMsg);
  }

  static Future<void> _sendInstantMessage(InstantMessage iMsg) async {
    Log.info('send instant message (type=${iMsg.content.type}): ${iMsg.sender} -> ${iMsg.receiver}');
    // send by shared messenger
    GlobalVariable shared = GlobalVariable();
    await shared.messenger!.sendInstantMessage(iMsg);
    // save instant message
    await _saveInstantMessage(iMsg);
  }

  static Future<void> _saveInstantMessage(InstantMessage iMsg) async {
    Amanuensis clerk = Amanuensis();
    await clerk.saveInstantMessage(iMsg).onError((error, stackTrace) {
      Log.error('failed to save message: $error');
      return false;
    });
  }

  ///  Send file content message with password
  ///
  /// @param iMsg     - outgoing message
  /// @param password - key for encrypt/decrypt file data
  /// @throws IOException on failed to save message
  Future<void> sendFileContentMessage(InstantMessage iMsg, SymmetricKey password) async {
    FileContent content = iMsg.content as FileContent;
    // 1. save origin file data
    Uint8List? data = content.data;
    String? filename = content.filename;
    int len = await FileTransfer.cacheFileData(data!, filename!);
    if (len != data.length) {
      Log.error('failed to save file data (len=${data.length}): $filename');
      return;
    }
    // 2. save instant message without file data
    content.data = null;
    await _saveInstantMessage(iMsg);
    // 3. add upload task with encrypted data
    Uint8List encrypted = password.encrypt(data);
    filename = FileTransfer.filenameFromData(encrypted, filename);
    ID sender = iMsg.sender;
    ChannelManager man = ChannelManager();
    FileTransferChannel ftp = man.ftpChannel;
    Uri? url = await ftp.uploadEncryptData(encrypted, filename, sender);
    if (url == null) {
      Log.error('failed to upload: ${content.filename} -> $filename');
      // TODO: mark message failed
    } else {
      // upload success
      Log.info('uploaded filename: ${content.filename} -> $filename => $url');
      content.url = url.toString();
      await _sendInstantMessage(iMsg);
    }
  }

  ///  Send text message to receiver
  ///
  /// @param text     - text message
  /// @param receiver - receiver ID
  /// @throws IOException on failed to save message
  Future<void> sendText(String text, ID receiver) async {
    TextContent content = TextContent.create(text);
    await _sendContent(content, receiver);
  }

  ///  Send image message to receiver
  ///
  /// @param jpeg      - image data
  /// @param thumbnail - image thumbnail
  /// @param receiver  - receiver ID
  /// @throws IOException on failed to save message
  Future<void> sendImage(Uint8List jpeg, Uint8List thumbnail, ID receiver) async {
    assert(jpeg.isNotEmpty, 'image data should not empty');
    String filename = Hex.encode(MD5.digest(jpeg));
    filename += ".jpeg";
    ImageContent content = FileContent.image(filename, binary: jpeg);
    // add image data length & thumbnail into message content
    content['length'] = jpeg.length;
    content.thumbnail = thumbnail;
    await _sendContent(content, receiver);
  }

  ///  Send voice message to receiver
  ///
  /// @param mp4      - voice file
  /// @param duration - length
  /// @param receiver - receiver ID
  /// @throws IOException on failed to save message
  Future<void> sendVoice(Uint8List mp4, double duration, ID receiver) async {
    assert(mp4.isNotEmpty, 'voice data should not empty');
    String filename = Hex.encode(MD5.digest(mp4));
    filename += ".mp4";
    AudioContent content = FileContent.audio(filename, binary: mp4);
    // add voice data length & duration into message content
    content['length'] = mp4.length;
    content['duration'] = duration;
    await _sendContent(content, receiver);
  }

  Future<void> _sendContent(Content content, ID receiver) async {
    GlobalVariable shared = GlobalVariable();
    Pair<InstantMessage, ReliableMessage?> result;
    result = await shared.messenger!.sendContent(content, sender: null, receiver: receiver);
    if (result.second == null) {
      Log.warning('not send yet (type=${content.type}): $receiver');
      return;
    }
    // save instant message
    await _saveInstantMessage(result.first);
  }

}
