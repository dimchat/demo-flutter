import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dim_client/dim_client.dart';

import '../client/facebook.dart';
import '../client/filesys/paths.dart';
import '../client/http/ftp.dart';
import '../client/shared.dart';
import '../widgets/alert.dart';
import 'styles.dart';

class AccountPage extends StatefulWidget {
  const AccountPage(this.user, {super.key});

  final User user;

  static void open(BuildContext context) {
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (user == null) {
         Alert.show(context, 'Error', 'Current user not found');
      } else {
        showCupertinoDialog(
          context: context,
          builder: (context) => AccountPage(user),
        );
      }
    });
  }

  @override
  State<StatefulWidget> createState() => _AccountState();

}

class _AccountState extends State<AccountPage> {

  String? _nickname;
  String? _avatarPath;
  Uri? _avatarUrl;

  // static final Uri _upWaiting = Uri.parse('https://chat.dim.sechat/up/waiting');
  // static final Uri _upError = Uri.parse('https://chat.dim.sechat/up/error');

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    SharedFacebook facebook = shared.facebook;
    ID identifier = widget.user.identifier;
    String name = await facebook.getName(identifier);
    var pair = await facebook.getAvatar(identifier);
    setState(() {
      _nickname = name;
      _avatarPath = pair.first;
      _avatarUrl = pair.second;
    });
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
        const CupertinoSliverNavigationBar(
          // This title is visible in both collapsed and expanded states.
          // When the "middle" parameter is omitted, the widget provided
          // in the "largeTitle" parameter is used instead in the collapsed state.
          largeTitle: Text('Edit Profile'),
        ),
        // This widget fills the remaining space in the viewport.
        // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
        SliverFillRemaining(
          hasScrollBody: false,
          fillOverscroll: true,
          child: _body(context),
        ),
      ],
    ),
  );

  Widget _body(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 32,),
      _avatarImage(),
      const SizedBox(height: 16,),
      _nicknameText(),
      const SizedBox(height: 8,),
      _idLabel(),
      const SizedBox(height: 32,),
      _saveButton(context),
      const SizedBox(height: 8,),
      _exportButton(context),
      const SizedBox(height: 64,),
    ],
  );

  Widget _avatarImage() => ClipOval(
    child: Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: [
        Container(width: 256, height: 256, color: Styles.backgroundColor,),
        if (_avatarPath != null)
          Image.file(File(_avatarPath!), width: 256, height: 256, fit: BoxFit.cover,),
        SizedBox(
          width: 256,
          child: TextButton(
            onPressed: () => _editAvatar(context),
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(Colors.lightGreen),
              foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
            ),
            child: const Text('Edit'),
          ),
        )
      ],
    ),
  );

  Widget _nicknameText() => SizedBox(
    width: 160,
    child: CupertinoTextField(
      textAlign: TextAlign.center,
      controller: TextEditingController(text: _nickname),
      placeholder: 'your nickname',
      padding: const EdgeInsets.only(left: 10, right: 10,),
      style: const TextStyle(
        fontSize: 20,
        height: 1.6,
      ),
      onChanged: (value) => _nickname = value,
    ),
  );

  Widget _idLabel() => Expanded(
    child: Text(widget.user.identifier.string,
      style: const TextStyle(fontSize: 12,
        color: Colors.teal,
      ),
    ),
  );

  Widget _saveButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: Colors.orange,
      child: const Text('Save'),
      onPressed: () => _saveInfo(context),
    ),
  );

  Widget _exportButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: Colors.red,
      child: const Text('Export'),
      onPressed: () => _exportKey(context),
    ),
  );

  void _editAvatar(BuildContext context) {
    showCupertinoModalPopup(context: context, builder: (context) {
      return CupertinoActionSheet(
        title: const Text('Photo'),
        message: const Text('Take a photo from your camera or album'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => _openPicker(context, true),
            child: const Text('Camera'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _openPicker(context, false),
            child: const Text('Album'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            isDestructiveAction: true,
            child: const Text('Cancel'),
          ),
        ],
      );
    });
  }

  void _openPicker(BuildContext context, bool camera) {
    Navigator.pop(context);
    ImagePicker picker = ImagePicker();
    ImageSource source = camera ? ImageSource.camera : ImageSource.gallery;
    picker.pickImage(source: source).then((file) {
      if (file == null) {
        Log.error('failed to get image file');
      } else {
        String path = file.path;
        String? ext = Paths.extension(path);
        if (ext == null || ext.toLowerCase() != 'png') {
          ext = 'jpeg';
        }
        setState(() {
          _avatarPath = path;
          // _avatarUrl = _upWaiting;
        });
        file.readAsBytes().then((data) {
          Log.debug('image file length: ${data.length}, path: ${file.path}');
          FileTransfer ftp = FileTransfer();
          String filename = FileTransfer.filenameFromData(data, 'avatar.$ext');
          ftp.uploadAvatar(data, filename, widget.user.identifier).then((url) {
            if (url == null) {
              Log.warning('failed to upload avatar: $filename');
              // _avatarUrl = _upError;
            } else {
              Log.warning('avatar uploaded: $filename -> $url');
              _avatarUrl = url;
            }
          }).onError((error, stackTrace) {
            Alert.show(context, 'Upload Failed', '$error');
          });
        }).onError((error, stackTrace) {
          Alert.show(context, 'Image File Error', '$error');
        });
      }
    }).onError((error, stackTrace) {
      Alert.show(context, '${camera ? 'Camera' : 'Gallery'} Error', '$error');
    });
  }

  void _saveInfo(BuildContext context) async {
    // 1. get old visa document
    User user = widget.user;
    Visa? visa = await user.visa
        .onError((error, stackTrace) {
          Alert.show(context, 'Error', 'Failed to get visa');
          return null;
        });
    if (visa?.key == null) {
      assert(false, 'should not happen');
      Document? doc = Document.create(Document.kVisa, user.identifier);
      assert(doc is Visa, 'failed to create visa document');
      visa = doc as Visa;
      PrivateKey? key = PrivateKey.generate(AsymmetricKey.kRSA);
      assert(key is EncryptKey, 'failed to create visa key');
      visa.key = key as EncryptKey;
    }
    // 2. get sign key
    GlobalVariable shared = GlobalVariable();
    SharedFacebook facebook = shared.facebook;
    SignKey? sKey = await facebook.getPrivateKeyForVisaSignature(user.identifier)
        .onError((error, stackTrace) {
          Alert.show(context, 'Error', 'Failed to get private key');
          return null;
        });
    if (visa == null || sKey == null) {
      assert(false, 'should not happen');
      return;
    }
    // 3. set name & avatar url in visa document and sign it
    visa.name = _nickname;
    visa.avatar = _avatarUrl?.toString();
    var sig = visa.sign(sKey);
    assert(sig != null, 'failed to sign visa: $user, $visa');
    // 4. save it
    bool ok = await facebook.saveDocument(visa)
        .onError((error, stackTrace) {
          Alert.show(context, 'Error', 'Failed to save visa document');
          return false;
        });
    assert(ok, 'failed to save visa: $user, $visa');
    // TODO: broadcast this document to all friends
    shared.messenger?.broadcastDocument();
  }

  void _exportKey(BuildContext context) {
    Alert.show(context, 'Coming soon', 'Export private key');
  }

}
