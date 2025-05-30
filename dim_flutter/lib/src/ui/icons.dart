import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


abstract class AppIcons {

  //
  //  Icons
  //  ~~~~~
  //  https://api.flutter.dev/flutter/cupertino/CupertinoIcons-class.html#constants
  //  https://api.flutter.dev/flutter/material/Icons-class.html
  //

  static const IconData stationIcon = CupertinoIcons.cloud;
  static const IconData     ispIcon = CupertinoIcons.cloud_moon;
  static const IconData     botIcon = Icons.support_agent;
  static const IconData     icpIcon = Icons.room_service_outlined;
  static const IconData    userIcon = CupertinoIcons.person;
  static const IconData   groupIcon = CupertinoIcons.group;

  // Tabs
  static const IconData    chatsTabIcon = CupertinoIcons.chat_bubble_2;
  static const IconData contactsTabIcon = CupertinoIcons.group;
  static const IconData servicesTabIcon = CupertinoIcons.compass;
  // static const IconData settingsTabIcon = CupertinoIcons.gear;
  static const IconData       meTabIcon = CupertinoIcons.person;

  // Chat Box
  static const IconData   chatDetailIcon = Icons.more_horiz;
  static const IconData      chatMicIcon = CupertinoIcons.mic;
  static const IconData chatKeyboardIcon = CupertinoIcons.keyboard;
  static const IconData chatFunctionIcon = Icons.add_circle_outline;
  static const IconData     chatSendIcon = Icons.send;
  static const IconData      noImageIcon = CupertinoIcons.photo;
  static const IconData       cameraIcon = CupertinoIcons.camera;
  static const IconData        albumIcon = CupertinoIcons.photo;
  static const IconData     saveFileIcon = CupertinoIcons.floppy_disk;
  static const IconData   encryptingIcon = CupertinoIcons.lock;
  static const IconData   decryptingIcon = CupertinoIcons.lock_open;
  static const IconData decryptErrorIcon = CupertinoIcons.slash_circle;
  // Audio
  static const IconData    waitAudioIcon = CupertinoIcons.cloud_download;
  static const IconData    playAudioIcon = CupertinoIcons.play;
  static const IconData playingAudioIcon = CupertinoIcons.volume_up;
  // Video
  static const IconData    playVideoIcon = CupertinoIcons.play;
  static const IconData      airPlayIcon = Icons.airplay;
  static const IconData        livesIcon = Icons.live_tv;
  static const IconData  unavailableIcon = CupertinoIcons.slash_circle;
  // Msg Status
  static const IconData   msgDefaultIcon = CupertinoIcons.ellipsis;
  static const IconData msgEncryptedIcon = CupertinoIcons.lock;
  static const IconData   msgWaitingIcon = CupertinoIcons.ellipsis;
  static const IconData      msgSentIcon = Icons.done;
  static const IconData   msgBlockedIcon = Icons.block;
  static const IconData  msgReceivedIcon = Icons.done_all;
  static const IconData   msgExpiredIcon = CupertinoIcons.refresh;

  static const IconData    encryptedIcon = CupertinoIcons.padlock_solid;

  static const IconData      webpageIcon = CupertinoIcons.link;
  static const IconData        mutedIcon = CupertinoIcons.bell_slash;

  static const IconData    plainTextIcon = CupertinoIcons.doc_plaintext;
  static const IconData     richTextIcon = CupertinoIcons.doc_richtext;

  static const IconData      forwardIcon = CupertinoIcons.arrow_right;

  // Search
  static const IconData searchIcon = CupertinoIcons.search;

  // Contacts
  static const IconData newFriendsIcon = CupertinoIcons.person_add;
  static const IconData  blockListIcon = CupertinoIcons.person_crop_square_fill;
  static const IconData   muteListIcon = CupertinoIcons.app_badge;
  static const IconData groupChatsIcon = CupertinoIcons.person_2;

  static const IconData      adminIcon = Icons.admin_panel_settings_outlined;
  static const IconData invitationIcon = Icons.contact_mail_outlined;

  static const IconData     reportIcon = CupertinoIcons.bell;
  static const IconData  addFriendIcon = CupertinoIcons.person_add;
  static const IconData    sendMsgIcon = CupertinoIcons.chat_bubble;
  static const IconData     recallIcon = CupertinoIcons.arrow_uturn_down;
  static const IconData      shareIcon = CupertinoIcons.share;
  static const IconData  clearChatIcon = CupertinoIcons.delete;
  static const IconData     deleteIcon = CupertinoIcons.delete;
  static const IconData     removeIcon = Icons.remove_circle_outline;

  static const IconData      closeIcon = CupertinoIcons.clear_thick;

  static const IconData       quitIcon = CupertinoIcons.escape;
  static const IconData  groupChatIcon = CupertinoIcons.group;
  static const IconData       plusIcon = CupertinoIcons.add;
  static const IconData      minusIcon = CupertinoIcons.minus;
  static const IconData   selectedIcon = CupertinoIcons.checkmark;

  // Settings
  static const IconData exportAccountIcon = CupertinoIcons.lock_shield;
  // static const IconData exportAccountIcon = Icons.vpn_key_outlined;
  // static const IconData exportAccountIcon = Icons.account_balance_wallet_outlined;
  static const IconData          burnIcon = CupertinoIcons.timer;

  static const IconData       storageIcon = CupertinoIcons.square_stack_3d_up;
  // static const IconData       storageIcon = Icons.storage;
  static const IconData         cacheIcon = CupertinoIcons.folder;
  static const IconData     temporaryIcon = CupertinoIcons.trash;

  static const IconData    setNetworkIcon = CupertinoIcons.cloud;
  static const IconData setWhitePaperIcon = CupertinoIcons.doc;
  // static const IconData setOpenSourceIcon = Icons.code;
  static const IconData setOpenSourceIcon = CupertinoIcons.chevron_left_slash_chevron_right;
  static const IconData      setTermsIcon = CupertinoIcons.doc_checkmark;
  static const IconData      setAboutIcon = CupertinoIcons.info;

  static const IconData    brightnessIcon = CupertinoIcons.brightness;
  static const IconData       sunriseIcon = CupertinoIcons.sunrise;
  static const IconData        sunsetIcon = CupertinoIcons.sunset_fill;

  static const IconData      languageIcon = Icons.language;

  static const IconData  notificationIcon = CupertinoIcons.app_badge;

  // Relay Stations
  static const IconData         refreshIcon = Icons.forward_5;
  static const IconData  currentStationIcon = CupertinoIcons.cloud_upload_fill;
  static const IconData   chosenStationIcon = CupertinoIcons.cloud_fill;

  // Register
  static const IconData    agreeIcon = CupertinoIcons.check_mark;
  static const IconData disagreeIcon = CupertinoIcons.clear;

  static const IconData updateDocIcon = CupertinoIcons.cloud_upload;

}
