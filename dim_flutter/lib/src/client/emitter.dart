import 'dart:typed_data';

import 'package:dim_client/ok.dart';
import 'package:dim_client/ws.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/client.dart';
import 'package:pnf/pnf.dart' show URLHelper;

import '../common/constants.dart';
import '../models/amanuensis.dart';
import '../filesys/upload.dart';

import 'shared.dart';


class SharedEmitter extends Emitter implements Observer {
  SharedEmitter() {
    var nc = NotificationCenter();
    nc.addObserver(this, NotificationNames.kFileUploadSuccess);
    nc.addObserver(this, NotificationNames.kFileUploadFailure);
  }

  @override
  Future<User?> get currentUser async {
    GlobalVariable shared = GlobalVariable();
    return await shared.facebook.currentUser;
  }

  @override
  Transmitter? get messenger {
    GlobalVariable shared = GlobalVariable();
    return shared.messenger;
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
      Uri url = info['url'] ?? info['URL'];
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
    await _saveInstantMessage(iMsg);
  }

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    ReliableMessage? rMsg = await super.sendInstantMessage(iMsg, priority: priority);
    // save instant message after sent
    await _saveInstantMessage(iMsg);
    return rMsg;
  }

  static Future<bool> _saveInstantMessage(InstantMessage iMsg) async {
    Amanuensis clerk = Amanuensis();
    return await clerk.saveInstantMessage(iMsg).onError((error, stackTrace) {
      Log.error('failed to save message: $error');
      return false;
    });
  }

  @override
  Future<bool> cacheFileData(Uint8List data, String filename) async {
    int len = await FileUploader.cacheFileData(data, filename);
    return len == data.length;
  }

  @override
  Future<Uint8List?> getFileData(String filename) async =>
      await FileUploader.getFileData(filename);

  @override
  Future<bool> cacheInstantMessage(InstantMessage iMsg) async =>
      await _saveInstantMessage(iMsg);

  @override
  Future<Uri?> uploadFileData(Uint8List encrypted, String filename, ID sender) async {
    /// NOTICE:
    ///     Because the filename here is a MD5 string of the plaintext,
    ///     but the encrypted data must be different every time, so
    ///     we need to rebuild the filename here.
    // rebuild filename
    filename = URLHelper.filenameFromData(encrypted, filename);
    // now upload the encrypted data with new filename
    FileUploader ftp = FileUploader();
    return await ftp.uploadEncryptData(encrypted, filename, sender);
  }

  @override
  Future<bool> sendPicture(Uint8List jpeg, {
    required String filename, required PortableNetworkFile? thumbnail,
    Map<String, Object>? extra,
    required ID receiver
  }) async {
    // rebuild filename
    filename = URLHelper.filenameFromData(jpeg, filename);
    return await super.sendPicture(jpeg,
      filename: filename, thumbnail: thumbnail,
      extra: extra,
      receiver: receiver,
    );
  }

  @override
  Future<bool> sendVoice(Uint8List mp4, {
    required String filename, required double duration,
    Map<String, Object>? extra,
    required ID receiver
  }) async {
    // rebuild filename
    filename = URLHelper.filenameFromData(mp4, filename);
    return await super.sendVoice(mp4,
      filename: filename, duration: duration,
      extra: extra,
      receiver: receiver,
    );
  }

  // @override
  // Future<bool> sendMovie(Uri url, {
  //   required PortableNetworkFile? snapshot, required String? title,
  //   String? filename, Map<String, Object>? extra,
  //   required ID receiver
  // }) async {
  //   // rebuild filename
  //   filename = URLHelper.filenameFromURL(url, filename);
  //   return await super.sendMovie(url,
  //     snapshot: snapshot, title: title,
  //     extra: extra,
  //     receiver: receiver,
  //   );
  // }

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
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: DeparturePriority.SLOWER);
    if (rMsg == null && !receiver.isGroup) {
      logWarning('not send yet (type=${content.type}): $receiver');
    }
    return Pair(iMsg, rMsg);
  }

}
