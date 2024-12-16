import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';
import 'package:pnf/dos.dart';
import 'package:pnf/pnf.dart' show URLHelper;
import 'package:stargate/startrek.dart';

import '../common/constants.dart';
import '../models/amanuensis.dart';
import '../filesys/upload.dart';

import 'shared.dart';


class Emitter with Logging implements Observer {
  Emitter() {
    var nc = NotificationCenter();
    nc.addObserver(this, NotificationNames.kFileUploadSuccess);
    nc.addObserver(this, NotificationNames.kFileUploadFailure);
  }
  
  /// filename => task
  final Map<String, InstantMessage> _outgoing = {};

  // void _addTask(String filename, InstantMessage item) {
  //   _outgoing[filename] = item;
  // }

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
      await _onUploadFailed(filename);
    }
  }

  Future<void> _onUploadSuccess(String filename, Uri url) async {
    InstantMessage? iMsg = _popTask(filename);
    if (iMsg == null) {
      logWarning('failed to get task: $filename, url: $url');
      return;
    }
    logInfo('get task for file: $filename, url: $url');
    // file data uploaded to FTP server, replace it with download URL
    // and send the content to station
    FileContent content = iMsg.content as FileContent;
    assert(content.data == null, 'file content error: $content');
    // content.data = null;
    content.url = url;
    await sendInstantMessage(iMsg, priority: 1).onError((error, stackTrace) {
      logError('failed to send message: $error');
      return null;
    });
  }

  Future<void> _onUploadFailed(String filename) async {
    InstantMessage? iMsg = _popTask(filename);
    if (iMsg == null) {
      logError('failed to get task: $filename');
      return;
    }
    logInfo('get task for file: $filename');
    // file data failed to upload, mark it error
    iMsg['error'] = {
      'message': 'failed to upload file',
    };
    return await _saveInstantMessage(iMsg);
  }

  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    logInfo('send instant message (type=${iMsg.content.type}): ${iMsg.sender} -> ${iMsg.receiver}');
    ReliableMessage? rMsg;
    ID receiver = iMsg.receiver;
    if (receiver.isGroup) {
      // send by group manager
      SharedGroupManager manager = SharedGroupManager();
      rMsg = await manager.sendInstantMessage(iMsg, priority: priority);
    } else {
      // send by shared messenger
      GlobalVariable shared = GlobalVariable();
      ClientMessenger? mess = shared.messenger;
      rMsg = await mess?.sendInstantMessage(iMsg, priority: priority);
    }
    // save instant message
    await _saveInstantMessage(iMsg);
    return rMsg;
  }

  static Future<void> _saveInstantMessage(InstantMessage iMsg) async {
    Amanuensis clerk = Amanuensis();
    await clerk.saveInstantMessage(iMsg).onError((error, stackTrace) {
      Log.error('failed to save message: $error');
      return false;
    });
  }

  ///  Upload file data encrypted with password
  ///
  /// @param content  - file content
  /// @param password - encrypt/decrypt key
  /// @param sender   - from where
  /// @return false on error
  Future<bool> uploadFileData(FileContent content,
      {required SymmetricKey password, required ID sender}) async {
    // 0. check file content
    Uint8List? data = content.data;
    if (data == null) {
      logWarning('already uploaded: ${content.url}');
      return false;
    }
    assert(content.password == null, 'file content error: $content');
    assert(content.url == null, 'file content error: $content');
    // 1. save origin file data
    String? filename = content.filename;
    assert(filename != null, 'content filename should not empty: $content');
    int len = await FileUploader.cacheFileData(data, filename!);
    if (len != data.length) {
      logError('failed to save file data (len=${data.length}): $filename');
      return false;
    }
    // 2. add upload task with encrypted data
    Uint8List encrypted = password.encrypt(data, content);
    /// NOTICE:
    ///     Because the filename here is a MD5 string of the plaintext,
    ///     but the encrypted data must be different every time, so
    ///     we must rebuild the filename again.
    String? ext = Paths.extension(filename);
    if (ext == null || ext.isEmpty) {
      filename = 'filename.dat';
    } else {
      filename = 'filename.$ext';
    }
    filename = URLHelper.filenameFromData(encrypted, filename);
    FileUploader ftp = FileUploader();
    Uri? url = await ftp.uploadEncryptData(encrypted, filename, sender);
    if (url == null) {
      logError('failed to upload: ${content.filename} -> $filename');
      // TODO: mark message failed
      return false;
    } else {
      // upload success
      logInfo('uploaded filename: ${content.filename} -> $filename => $url');
    }
    // 3. replace file data with URL & decrypt key
    content.url = url;
    content.password = password;
    content.data = null;
    return true;
  }

  ///  Send text message to receiver
  ///
  /// @param text     - text message
  /// @param receiver - receiver ID
  /// @throws IOException on failed to save message
  Future<void> sendText(String text, {required ID receiver}) async {
    TextContent content = TextContent.create(text);
    // check text format
    if (_checkMarkdown(text)) {
      logInfo('send text as markdown: $text => $receiver');
      content['format'] = 'markdown';
    } else {
      logInfo('send text as plain: $text -> $receiver');
    }
    await sendContent(content, receiver);
  }
  bool _checkMarkdown(String text) {
    if (text.contains('://')) {
      return true;
    } else if (text.contains('\n> ')) {
      return true;
    } else if (text.contains('\n# ')) {
      return true;
    } else if (text.contains('\n## ')) {
      return true;
    } else if (text.contains('\n### ')) {
      return true;
    }
    int pos = text.indexOf('```');
    if (pos >= 0) {
      pos += 3;
      int next = text.codeUnitAt(pos);
      if (next != '`'.codeUnitAt(0)) {
        return text.indexOf('```', pos + 1) > 0;
      }
    }
    return false;
  }

  ///  Send image message to receiver
  ///
  /// @param jpeg      - image data
  /// @param thumbnail - image thumbnail
  /// @param receiver  - receiver ID
  /// @throws IOException on failed to save message
  Future<void> sendImage(Uint8List jpeg,
      {required String filename, String? thumbnail,
        Map<String, Object>? extra, required ID receiver}) async {
    assert(jpeg.isNotEmpty, 'image data should not empty');
    // rebuild filename
    String ext = Paths.extension(filename) ?? 'jpeg';
    filename = Hex.encode(MD5.digest(jpeg));
    filename = '$filename.$ext';
    // create image content
    TransportableData ted = TransportableData.create(jpeg);
    ImageContent content = FileContent.image(filename: filename, data: ted);
    // add image data length & thumbnail into message content
    content['length'] = jpeg.length;
    if (thumbnail != null) {
      content['thumbnail'] = thumbnail;
    }
    if (extra != null) {
      content.addAll(extra);
    }
    await sendContent(content, receiver);
  }

  ///  Send voice message to receiver
  ///
  /// @param mp4      - voice file
  /// @param duration - length
  /// @param receiver - receiver ID
  /// @throws IOException on failed to save message
  Future<void> sendVoice(Uint8List mp4,
      {required String filename, required double duration,
        required ID receiver}) async {
    assert(mp4.isNotEmpty, 'voice data should not empty');
    // rebuild filename
    String ext = Paths.extension(filename) ?? 'mp4';
    filename = Hex.encode(MD5.digest(mp4));
    filename = '$filename.$ext';
    // create audio content
    TransportableData ted = TransportableData.create(mp4);
    AudioContent content = FileContent.audio(filename: filename, data: ted);
    // add voice data length & duration into message content
    content['length'] = mp4.length;
    content['duration'] = duration;
    await sendContent(content, receiver);
  }

  Future<void> sendVideo(Uri url,
      {String? filename, String? title, String? snapshot,
        Map<String, Object>? extra, required ID receiver}) async {
    VideoContent content = FileContent.video(url: url,
      filename: filename,
      password: PlainKey.getInstance(),
    );
    content['title'] = title;
    content['snapshot'] = snapshot;
    if (extra != null) {
      content.addAll(extra);
    }
    await sendContent(content, receiver);
  }

  Future<Pair<InstantMessage?, ReliableMessage?>> sendContent(Content content, ID receiver, {int priority = 0}) async {
    if (receiver.isGroup) {
      assert(!content.containsKey('group') || content.group == receiver, 'group ID error: $receiver, $content');
      content.group = receiver;
    }
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return const Pair(null, null);
    }
    ID sender = user.identifier;
    //
    //  1. pack instant message
    //
    Envelope envelope = Envelope.create(sender: sender, receiver: receiver);
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    //
    //  2. check file content
    //
    if (content is FileContent) {
      // encrypt & upload file data before send out
      if (content.data != null/* && content.url == null*/) {
        SymmetricKey? password = await shared.messenger?.getEncryptKey(iMsg);
        if (password == null) {
          assert(false, 'failed to get encrypt key: ''$sender => $receiver, ${iMsg['group']}');
          return Pair(iMsg, null);
        } else if (await uploadFileData(content, password: password, sender: sender)) {
          logInfo('uploaded file data for sender: $sender, ${content.filename}');
        } else {
          logError('failed to upload file data for sender: $sender, ${content.filename}');
          return Pair(iMsg, null);
        }
      }
    }
    //
    //  3. send
    //
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: priority);
    if (rMsg == null && !receiver.isGroup) {
      logWarning('not send yet (type=${content.type}): $receiver');
    }
    return Pair(iMsg, rMsg);
  }

  //
  //  Recall Messages
  //

  /// recall text message
  Future<Pair<InstantMessage?, ReliableMessage?>> recallTextMessage(TextContent content, Envelope envelope) async =>
      await recallMessage(content, envelope, text: '_(message recalled)_');

  /// recall image message
  Future<Pair<InstantMessage?, ReliableMessage?>> recallImageMessage(ImageContent content, Envelope envelope) async =>
      await recallFileMessage(content, envelope, text: '_(image recalled)_');

  /// recall audio message
  Future<Pair<InstantMessage?, ReliableMessage?>> recallAudioMessage(AudioContent content, Envelope envelope) async =>
      await recallFileMessage(content, envelope, text: '_(voice message recalled)_');

  /// recall video message
  Future<Pair<InstantMessage?, ReliableMessage?>> recallVideoMessage(VideoContent content, Envelope envelope) async =>
      await recallFileMessage(content, envelope, text: '_(video recalled)_');

  /// recall file message
  Future<Pair<InstantMessage?, ReliableMessage?>> recallFileMessage(FileContent content, Envelope envelope, {
    String? text,
  }) async => await recallMessage(content, envelope, text: text ?? '_(file recalled)_', origin: {
    'type': content['type'],
    'sn': content['sn'],
    'URL': content['URL'],
    'filename': content['filename'],
  });

  /// recall other message
  Future<Pair<InstantMessage?, ReliableMessage?>> recallMessage(Content content, Envelope envelope, {
    String? text, Map<String, dynamic>? origin,
  }) async {
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return const Pair(null, null);
    }
    // check sender
    ID sender = user.identifier;
    if (sender != envelope.sender) {
      assert(false, 'cannot recall this message: ${envelope.sender} -> ${envelope.receiver}, ${content.group}');
      return const Pair(null, null);
    }
    ID receiver = content.group ?? envelope.receiver;
    return await _recall(content, sender: sender, receiver: receiver,
      text: text ?? '_(message recalled)_', origin: origin ?? {
        'type': content['type'],
        'sn': content['sn'],
      },
    );
  }

  Future<Pair<InstantMessage?, ReliableMessage?>> _recall(Content content, {
    required ID sender, required ID receiver,
    required String text, required Map<String, dynamic> origin,
  }) async {
    assert(sender != receiver, 'cycled message: $sender, $text, $content');
    //
    //  1. build the recall command
    //
    Content command = TextContent.create(text);
    command['format'] = 'markdown';
    command['action'] = 'recall';
    command['origin'] = origin;
    command['time'] = content['time'];
    command['sn'] = content['sn'];
    if (receiver.isGroup) {
      command.group = receiver;
    }
    //
    //  2. pack instant message
    //
    Envelope envelope = Envelope.create(sender: sender, receiver: receiver);
    content = Content.parse(command.toMap()) ?? command;
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    iMsg['muted'] = true;
    //
    //  3. send
    //
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: DeparturePriority.kSlower);
    if (rMsg == null && !receiver.isGroup) {
      logWarning('not send yet (type=${content.type}): $receiver');
    }
    return Pair(iMsg, rMsg);
  }

}
