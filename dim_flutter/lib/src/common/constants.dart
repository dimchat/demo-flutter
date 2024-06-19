
import 'package:pnf/pnf.dart' as pnf show NotificationNames;

abstract class NotificationNames {

  static const String kServiceProviderUpdated = 'ServiceProviderUpdated';
  static const String kStationsUpdated = 'StationsUpdated';
  static const String kStationSpeedUpdated = 'StationSpeedUpdated';

  static const String kServerStateChanged = 'ServerStateChanged';

  static const String kStartChat = 'StartChat';

  static const String kAccountDeleted = 'AccountDeleted';

  static const String kPrivateKeySaved = 'PrivateKeySaved';
  static const String kMetaSaved = 'MetaSaved';
  static const String kDocumentUpdated = 'DocumentUpdated';

  static const String kLocalUsersUpdated = 'LocalUsersUpdated';
  static const String kContactsUpdated = 'ContactsUpdated';
  static const String kRemarkUpdated = 'RemarkUpdated';
  static const String kBlockListUpdated = 'BlockListUpdated';
  static const String kMuteListUpdated = 'MuteListUpdated';

  static const String kLoginCommandUpdated = 'LoginCommandUpdated';
  static const String kGroupHistoryUpdated = 'GroupHistoryUpdated';

  static const String kGroupCreated = 'GroupCreated';
  static const String kGroupRemoved = 'GroupRemoved';
  static const String kMembersUpdated = 'MembersUpdated';
  static const String kAdministratorsUpdated = 'AdministratorsUpdated';
  static const String kParticipantsUpdated = 'ParticipantsUpdated';

  static const String kHistoryUpdated = 'HistoryUpdated';
  static const String kMessageUpdated = 'MessageUpdated';
  static const String kMessageCleaned = 'MessageCleaned';
  static const String kMessageTraced = 'MessageTraced';

  static const String kMessageTyping = 'MessageTyping';
  static const String kAvatarLongPressed = 'AvatarLongPressed';

  static const String kConversationCleaned = 'ConversationCleaned';
  static const String kConversationUpdated = 'ConversationUpdated';

  static const String kSearchUpdated = 'SearchUpdated';

  static const String kRecordFinished = 'RecordFinished';
  static const String kPlayFinished = 'PlayFinished';

  static const String kSettingUpdated = 'SettingUpdated';

  static const String kFileUploadSuccess = 'FileUploadSuccess';
  static const String kFileUploadFailure = 'FileUploadFailure';

  static const String kFileDownloadSuccess = 'FileDownloadSuccess';
  static const String kFileDownloadFailure = 'FileDownloadFailure';

  // Cache File Management
  static const String kCacheFileFound = 'CacheFileFound';
  static const String kCacheScanFinished = 'CacheScanFinished';

  //
  //  PNF
  //

  static const String       kPortableNetworkStatusChanged =
      pnf.NotificationNames.kPortableNetworkStatusChanged;
  static const String       kPortableNetworkReceiveProgress =
      pnf.NotificationNames.kPortableNetworkReceiveProgress;
  static const String       kPortableNetworkReceived =
      pnf.NotificationNames.kPortableNetworkReceived;
  static const String       kPortableNetworkDecrypted =
      pnf.NotificationNames.kPortableNetworkDecrypted;
  static const String       kPortableNetworkSuccess =
      pnf.NotificationNames.kPortableNetworkSuccess;
  static const String       kPortableNetworkError =
      pnf.NotificationNames.kPortableNetworkError;

  //
  //  Live Player
  //

  static const String kVideoPlayerPlay = 'VideoPlayerPlay';

}
