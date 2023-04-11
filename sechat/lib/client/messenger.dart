import 'package:dim_client/dim_client.dart';

class SharedMessenger extends ClientMessenger {
  SharedMessenger(super.session, super.facebook, super.mdb);

  @override
  void suspendInstantMessage(InstantMessage iMsg, Map info) {
    // TODO: implement suspendInstantMessage
  }

  @override
  void suspendReliableMessage(ReliableMessage rMsg, Map info) {
    // TODO: implement suspendReliableMessage
  }

}
