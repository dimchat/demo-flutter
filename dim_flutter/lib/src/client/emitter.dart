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
    nc.addObserver(this, NotificationNames.kPortableNetworkUploadSuccess);
    nc.addObserver(this, NotificationNames.kPortableNetworkError);
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
    if (name == NotificationNames.kPortableNetworkUploadSuccess) {
      var pnf = info['PNF'];
      String filename = info['filename'] ?? pnf?['filename'] ?? '';
      Uri url = info['url'] ?? info['URL'];
      await _onUploadSuccess(filename, url);
    } else if (name == NotificationNames.kPortableNetworkError) {
      var pnf = info['PNF'];
      String filename = info['filename'] ?? pnf?['filename'] ?? '';
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
    assert(!content.containsKey('data'), 'file content error: $content');
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
  Future<bool> handleFileContent(FileContent content, InstantMessage iMsg, {
    int priority = 0
  }) async {
    Uri? url = content.url;
    Uint8List? data = content.data;
    String? filename = content.filename;
    //
    //  1. check URL
    //
    if (url != null) {
      // download URL exists,
      // means the file data has already been uploaded
      if (data != null) {
        // file data should not exist here
        assert(!content.containsKey('data'), 'file content error: $filename, $url');
        content.data = null;
      }
      logInfo('file data uploaded: $filename -> $url');
      // no need to handle again,
      // return false to send the message immediately
      return false;
    }
    //
    //  2. check filename
    //
    if (filename == null) {
      // if download URL not exists, means file data has not been uploaded yet,
      // there must be a filename here
      logError('failed to create upload task: $content');
      assert(false, 'file content error: $content');
      // file content error,
      // return true to drop this message
      return true;
    } else if (URLHelper.isFilenameEncoded(filename)) {
      // filename encoded: "md5(data).ext"
    } else if (data != null) {
      filename = URLHelper.filenameFromData(data, filename);
      Log.info('rebuild filename: ${content.filename} -> $filename');
      content.filename = filename;
    } else {
      // filename error
      assert(false, 'filename error: $content');
      return true;
    }
    _addTask(filename, iMsg);
    //
    //  3. upload encrypted data
    //
    var ftp = SharedFileUploader();
    bool waiting = await ftp.uploadEncryptData(content, iMsg.sender);
    if (waiting) {
      logInfo('cache instant message for waiting file data uploaded: $filename');
      await _saveInstantMessage(iMsg);
    }
    return waiting;
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
