import 'package:dim_client/dim_client.dart';

import '../models/channels.dart';
import 'messenger.dart';
import 'session.dart';
import 'shared.dart';
import 'utils/notification.dart';


class Client extends Terminal {
  Client(super.facebook, super.sdb);

  @override
  Future<ClientMessenger> connect(String host, int port) async {
    ChannelManager manager = ChannelManager();
    SessionChannel channel = manager.sessionChannel;
    await channel.connect(host, port).then((value) =>
        facebook.currentUser.then((user) {
          if (user != null) {
            channel.login(user.identifier);
          }
        }));
    return await super.connect(host, port);
  }

  @override
  ClientSession createSession(Station station, SocketAddress remote) {
    ClientSession session = SharedSession(station, remote, sdb);
    session.start();
    return session;
  }

  @override
  ClientMessenger createMessenger(ClientSession session, CommonFacebook facebook) {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger messenger = SharedMessenger(session, facebook, shared.mdb);
    GroupManager manager = GroupManager();
    manager.messenger = messenger;
    shared.messenger = messenger;
    return messenger;
  }

  @override
  Future<void> exitState(SessionState previous, SessionStateMachine ctx, int now) async {
    await super.exitState(previous, ctx, now);
    SessionState? current = ctx.currentState;
    NotificationCenter nc = NotificationCenter();
    nc.postNotification('ServerStateChanged', this, {
      'state': current?.index,
    });
  }

  //
  //  DeviceMixin
  //

  @override
  String get language => "zh-CN";

  @override
  String get displayName => "DIM";

  @override
  String get versionName => "1.0.1";

  @override
  String get systemVersion => "4.0";

  @override
  String get systemModel => "HMS";

  @override
  String get systemDevice => "hammerhead";

  @override
  String get deviceBrand => "HUAWEI";

  @override
  String get deviceBoard => "hammerhead";

  @override
  String get deviceManufacturer => "HUAWEI";

}
