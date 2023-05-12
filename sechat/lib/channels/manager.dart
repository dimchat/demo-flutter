import 'audio.dart';
import 'session.dart';
import 'transfer.dart';

class ChannelNames {

  static const String audio = "chat.dim/audio";

  static const String session = "chat.dim/session";

  static const String fileTransfer = "chat.dim/ftp";
}

class ChannelMethods {

  //
  //  Audio Channel
  //
  static const String startRecord        = "startRecord";
  static const String stopRecord         = "stopRecord";
  static const String startPlay          = "startPlay";
  static const String stopPlay           = "stopPlay";

  static const String onRecordFinished   = "onRecordFinished";
  static const String onPlayFinished     = "onPlayFinished";

  //
  //  Session channel
  //
  static const String connect            = "connect";
  static const String login              = "login";
  static const String setSessionKey      = "setSessionKey";
  static const String getState           = "getState";
  static const String sendMessagePackage = "queueMessagePackage";

  static const String onStateChanged     = "onStateChanged";
  static const String onReceived         = "onReceived";

  static const String packData           = "packData";
  static const String unpackData         = "unpackData";

  //
  //  FTP Channel
  //
  static const String setUploadAPI       = "setUploadAPI";

  static const String uploadAvatar       = "uploadAvatar";
  static const String uploadFile         = "uploadEncryptFile";
  static const String downloadAvatar     = "downloadAvatar";
  static const String downloadFile       = "downloadEncryptedFile";

  static const String onUploadSuccess    = "onUploadSuccess";
  static const String onUploadFailure    = "onUploadFailed";
  static const String onDownloadSuccess  = "onDownloadSuccess";
  static const String onDownloadFailure  = "onDownloadFailed";

}

class ChannelManager {
  factory ChannelManager() => _instance;
  static final ChannelManager _instance = ChannelManager._internal();
  ChannelManager._internal();

  //
  //  Channels
  //
  final AudioChannel audioChannel = AudioChannel(ChannelNames.audio);
  final SessionChannel sessionChannel = SessionChannel(ChannelNames.session);
  final FileTransferChannel ftpChannel = FileTransferChannel(ChannelNames.fileTransfer);

}
