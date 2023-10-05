import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../models/chat_contact.dart';
import '../models/chat_group.dart';

/// Group Icon
class GroupImage extends StatefulWidget {
  const GroupImage(this.info, {super.key, this.width, this.height, this.onTap});

  final GroupInfo info;

  final double? width;
  final double? height;

  final GestureTapCallback? onTap;

  @override
  State<StatefulWidget> createState() => _GroupImageState();

}

class _GroupImageState extends State<GroupImage> implements lnc.Observer {
  _GroupImageState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kMembersUpdated);
    nc.addObserver(this, NotificationNames.kParticipantsUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kParticipantsUpdated);
    nc.removeObserver(this, NotificationNames.kMembersUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kMembersUpdated) {
      ID? identifier = info?['ID'];
      if (identifier == null) {
        Log.error('notification error: $notification');
      } else if (identifier == widget.info.identifier) {
        _reload();
      }
    } else if (name == NotificationNames.kParticipantsUpdated) {
      ID? identifier = info?['ID'];
      if (identifier == null) {
        Log.error('notification error: $notification');
      } else if (identifier == widget.info.identifier) {
        setState(() {
        });
      }
    }
  }

  void _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    List<ContactInfo> members = ContactInfo.fromList(widget.info.members);
    int count = members.length;
    double width;
    double height;
    if (count < 5) {
      width = 22;
      height = 22;
    } else {
      width = 15;
      height = 15;
    }
    List<Widget> images = [];
    ContactInfo info;
    Widget img;
    for (int i = 0; i < count; ++i) {
      info = members[i];
      info.reloadData();
      img = info.getImage(width: width, height: height);
      images.add(img);
    }
    double boxWidth = widget.width ?? 48;
    double boxHeight = widget.height ?? 48;
    BoxDecoration decoration = BoxDecoration(
      border: Border.all(color: CupertinoColors.systemGrey, width: 1, style: BorderStyle.solid),
      borderRadius: BorderRadius.circular(4),
    );
    /// Mosaics
    if (count > 6) {
      //
      //  Formations:
      //
      //      9:  A   B   C
      //          D   E   F
      //          G   H   I
      //
      //      8:    A   B
      //          C   D   E
      //          F   G   H
      //
      //      7:      A
      //          B   C   D
      //          E   F   G
      //
      if (count > 9) {
        count = 9;
      }
      return Container(
        decoration: decoration,
        width: boxWidth,
        height: boxHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (count >= 9)
                images[count - 9],
                if (count >= 8)
                images[count - 8],
                images[count - 7],
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                images[count - 6],
                images[count - 5],
                images[count - 4],
              ],),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                images[count - 3],
                images[count - 2],
                images[count - 1],
              ],
            ),
          ],
        ),
      );
    } else if (count > 4) {
      //
      //  Formations:
      //
      //      6:  A   B   C
      //          D   E   F
      //
      //      5:    A   B
      //          C   D   E
      //
      return Container(
        decoration: decoration,
        width: boxWidth,
        height: boxHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (count >=6)
                images[count - 6],
                images[count - 5],
                images[count - 4],
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                images[count - 3],
                images[count - 2],
                images[count - 1],
              ],
            ),
          ],
        ),
      );
    } else if (count > 2) {
      //
      //  Formations:
      //
      //      4:  A   B
      //          C   D
      //
      //      3:    A
      //          B   C
      //
      return Container(
        decoration: decoration,
        width: boxWidth,
        height: boxHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (count >= 4)
                images[count - 4],
                images[count - 3],
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                images[count - 2],
                images[count - 1],
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: decoration,
      width: boxWidth,
      height: boxHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (count > 0)
          images[0],
          if (count > 1)
          images[1],
        ],
      ),
    );
  }

}