import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../client/filesys/external.dart';
import '../client/shared.dart';
import '../models/contact.dart';
import '../widgets/alert.dart';
import '../widgets/audio.dart';
import '../widgets/picker.dart';

class ChatInputTray extends StatefulWidget {
  const ChatInputTray(this.info, {super.key});

  final ContactInfo info;

  @override
  State<StatefulWidget> createState() => _InputState();

}

class _InputState extends State<ChatInputTray> {

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isVoice = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!_isVoice)
        CupertinoButton(
          child: const Icon(CupertinoIcons.mic_circle),
          onPressed: () => setState(() {
            _isVoice = true;
          }),
        ),
      if (_isVoice)
        CupertinoButton(
          child: const Icon(CupertinoIcons.keyboard),
          onPressed: () => setState(() {
            _isVoice = false;
          }),
        ),
      if (!_isVoice)
        Expanded(
          flex: 1,
          child: CupertinoTextField(
            minLines: 1,
            maxLines: 8,
            controller: _controller,
            placeholder: 'Input text message',
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            focusNode: _focusNode,
            onTapOutside: (event) => _focusNode.unfocus(),
            onSubmitted: (value) => _sendText(context, _controller, widget.info),
            onChanged: (value) => setState(() {}),
          ),
        ),
      if (_isVoice)
        Expanded(
          flex: 1,
          child: RecordButton(widget.info.identifier,
            onComplected: (path, duration) => _sendVoice(context, path, duration, widget.info),
          ),
        ),
      if (_controller.text.isEmpty || _isVoice)
        CupertinoButton(
          child: const Icon(Icons.add_circle_outline),
          onPressed: () => _sendImage(context, widget.info),
        ),
      if (_controller.text.isNotEmpty && !_isVoice)
        CupertinoButton(
          child: const Icon(Icons.send),
          onPressed: () => _sendText(context, _controller, widget.info),
        ),
    ],
  );

}

//--------

void _sendText(BuildContext context, TextEditingController controller, ContactInfo chat) {
  String text = controller.text;
  if (text.isNotEmpty) {
    GlobalVariable shared = GlobalVariable();
    shared.emitter.sendText(text, chat.identifier);
  }
  controller.text = '';
}

void _sendImage(BuildContext context, ContactInfo chat) {
  openImagePicker(context, onRead: (path, jpeg) async {
    Uint8List thumbnail = await compressThumbnail(jpeg);
    GlobalVariable shared = GlobalVariable();
    shared.emitter.sendImage(jpeg, thumbnail, chat.identifier);
  });
}

void _sendVoice(BuildContext context, String path, double duration, ContactInfo chat) {
  ExternalStorage.loadBinary(path).then((data) {
    GlobalVariable shared = GlobalVariable();
    shared.emitter.sendVoice(data, duration, chat.identifier);
  }).onError((error, stackTrace) {
    Alert.show(context, 'Error', 'Failed to load voice file: $path');
  });
}
