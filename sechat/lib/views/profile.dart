import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import '../client/constants.dart';
import '../client/shared.dart';
import '../models/contact.dart';
import '../models/conversation.dart';
import '../widgets/alert.dart';
import '../widgets/tableview.dart';
import 'chat_box.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage(this.info, this.fromWhere, {super.key});

  final ContactInfo info;
  final ID? fromWhere;

  static void open(BuildContext context, ID identifier, {ID? fromWhere}) {
    ContactInfo.fromID(identifier).then((info) {
      showCupertinoDialog(
        context: context,
        builder: (context) => ProfilePage(info, fromWhere),
      );
    }).onError((error, stackTrace) {
      Alert.show(context, 'Error', '$error');
    });
    // query for update
    GlobalVariable shared = GlobalVariable();
    shared.messenger?.queryDocument(identifier);
    if (identifier.isGroup) {
      shared.messenger?.queryMembers(identifier);
    }
  }

  static Widget cell(ContactInfo info) => _ProfileTableCell(info);

  @override
  State<StatefulWidget> createState() => _ProfileState();

}

class _ProfileState extends State<ProfilePage> implements lnc.Observer {
  _ProfileState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  bool _isFriend = false;

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    nc.removeObserver(this, NotificationNames.kContactsUpdated);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = userInfo?['ID'];
      assert(identifier != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        Log.info('document updated: $identifier');
        if (mounted) {
          setState(() {
            // update name in title
          });
        }
      }
    } else if (name == NotificationNames.kContactsUpdated) {
      ID? contact = userInfo?['contact'];
      Log.info('contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
    } else {
      Log.error('notification error: $notification');
    }
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('current user not found, failed to reload data');
    } else {
      Log.debug('reloading profile: ${widget.info}');
      List<ID> contacts = await shared.facebook.getContacts(user.identifier);
      if (mounted) {
        setState(() {
          _isFriend = contacts.contains(widget.info.identifier);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    // A ScrollView that creates custom scroll effects using slivers.
    child: CustomScrollView(
      // A list of sliver widgets.
      slivers: <Widget>[
        CupertinoSliverNavigationBar(
          // This title is visible in both collapsed and expanded states.
          // When the "middle" parameter is omitted, the widget provided
          // in the "largeTitle" parameter is used instead in the collapsed state.
          largeTitle: Text(widget.info.name),
        ),
        // This widget fills the remaining space in the viewport.
        // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
        SliverFillRemaining(
          hasScrollBody: false,
          fillOverscroll: true,
          child: SingleChildScrollView(
            child: _body(context),
          ),
        ),
      ],
    ),
  );

  Widget _body(BuildContext context) => Column(
    children: [
      const SizedBox(height: 32,),
      _avatarImage(),
      const SizedBox(height: 8,),
      SizedBox(width: 300,
        child: _idLabel(),
      ),
      const SizedBox(height: 32,),
      if (!_isFriend)
        _addButton(context),
      if (_isFriend)
        Column(
          children: [
            _sendButton(context),
            const SizedBox(height: 8,),
            if (widget.fromWhere != null)
            _clearButton(context),
            if (widget.fromWhere == null)
            _deleteButton(context),
          ],
        ),
      const SizedBox(height: 64,),
    ],
  );

  Widget _avatarImage() => widget.info.getImage(width: 256, height: 256);

  Widget _idLabel() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('ID: ',
        style: TextStyle(fontSize: 12,
          color: Colors.blueGrey,
          fontWeight: FontWeight.bold,
        ),
      ),
      Expanded(
        child: SelectableText(widget.info.identifier.string,
          style: const TextStyle(fontSize: 12,
            color: Colors.teal,
          ),
        ),
      ),
    ],
  );

  Widget _addButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: CupertinoColors.systemOrange,
      child: const Text('Add Contact'),
      onPressed: () => _addContact(context, widget.info),
    ),
  );

  Widget _sendButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: CupertinoColors.systemBlue,
      child: const Text('Send Message'),
      onPressed: () => _sendMessage(context, widget.info, widget.fromWhere),
    ),
  );

  Widget _clearButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: CupertinoColors.systemYellow,
      child: const Text('Clear History'),
      onPressed: () => _clearHistory(context, widget.info),
    ),
  );

  Widget _deleteButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: CupertinoColors.systemRed,
      child: Text(widget.info.identifier.isUser ? 'Delete Contact' : 'Delete Group'),
      onPressed: () => _deleteContact(context, widget.info),
    ),
  );

}

void _sendMessage(BuildContext ctx, ContactInfo info, ID? fromWhere) {
  if (info.identifier == fromWhere) {
    // this page is open from a chat box
    Navigator.pop(ctx);
  } else {
    ChatBox.open(ctx, info);
  }
}

void _addContact(BuildContext ctx, ContactInfo info) {
  GlobalVariable shared = GlobalVariable();
  shared.facebook.currentUser.then((user) {
    if (user == null) {
      Log.error('current user not found, failed to add contact: $info');
      Alert.show(ctx, 'Error', 'Current user not found');
    } else {
      Alert.confirm(ctx, 'Confirm', 'Do you want to add this friend?',
        okAction: () => _doAdd(ctx, info.identifier, user.identifier),
      );
    }
  });
}
void _doAdd(BuildContext ctx, ID contact, ID user) {
  GlobalVariable shared = GlobalVariable();
  shared.database.addContact(contact, user: user)
      .then((ok) {
    if (ok) {
      // Navigator.pop(context);
    } else {
      Alert.show(ctx, 'Error', 'Failed to add contact');
    }
  });
}

void _clearHistory(BuildContext ctx, ContactInfo info) {
  String msg;
  if (info.identifier.isUser) {
    msg = 'Are you sure want to clear chat history of this friend?';
  } else {
    msg = 'Are you sure want to clear chat history of this group?';
  }
  Alert.confirm(ctx, 'Confirm', msg,
    okAction: () => _doClear(ctx, info.identifier),
  );
}
void _doClear(BuildContext ctx, ID chat) {
  Amanuensis clerk = Amanuensis();
  clerk.clearConversation(chat).then((ok) {
    if (ok) {
      Navigator.pop(ctx);
    } else {
      Alert.show(ctx, 'Error', 'Failed to clear chat history');
    }
  });
}

void _deleteContact(BuildContext ctx, ContactInfo info) {
  GlobalVariable shared = GlobalVariable();
  shared.facebook.currentUser.then((user) {
    if (user == null) {
      Log.error('current user not found, failed to add contact: $info');
      Alert.show(ctx, 'Error', 'Current user not found');
    } else {
      String msg;
      if (info.identifier.isUser) {
        msg = 'Are you sure to remove this friend?\n'
            'This action will clear chat history too.';
      } else {
        msg = 'Are you sure to remove this group?\n'
            'This action will clear chat history too.';
      }
      Alert.confirm(ctx, 'Confirm', msg,
        okAction: () => _doRemove(ctx, info.identifier, user.identifier),
      );
    }
  });
}
void _doRemove(BuildContext ctx, ID contact, ID user) {
  Amanuensis clerk = Amanuensis();
  clerk.removeConversation(contact).onError((error, stackTrace) {
    Alert.show(ctx, 'Error', 'Failed to remove conversation');
    return false;
  });
  GlobalVariable shared = GlobalVariable();
  shared.database.removeContact(contact, user: user).then((ok) {
    if (ok) {
      Navigator.pop(ctx);
    } else {
      Alert.show(ctx, 'Error', 'Failed to remove contact');
    }
  });
}

//
//  Profile Table Cell
//

class _ProfileTableCell extends StatefulWidget {
  const _ProfileTableCell(this.info);

  final ContactInfo info;

  @override
  State<StatefulWidget> createState() => _ProfileTableState();

}

class _ProfileTableState extends State<_ProfileTableCell> implements lnc.Observer {
  _ProfileTableState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    assert(name == NotificationNames.kDocumentUpdated, 'notification error: $notification');
    ID? identifier = info?['ID'];
    if (identifier == null) {
      Log.error('notification error: $notification');
    } else if (identifier == widget.info.identifier) {
      await _reload();
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
        //
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => TableView.cell(
      leading: widget.info.getImage(),
      title: Text(widget.info.name),
      subtitle: Text(widget.info.identifier.string),
      onTap: () {
        ProfilePage.open(context, widget.info.identifier);
      }
  );

}
