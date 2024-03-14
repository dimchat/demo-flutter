import 'manager.dart';

class FileTransferChannel extends SafeChannel {
  FileTransferChannel(super.name);

  /// root directory for local storage
  String? _cachesDirectory;
  String? _temporaryDirectory;

  Future<String?> get cachesDirectory async {
    String? dir = _cachesDirectory;
    if (dir == null) {
      dir = await invoke(ChannelMethods.getCachesDirectory, null);
      _cachesDirectory = dir;
    }
    return dir;
  }
  Future<String?> get temporaryDirectory async {
    String? dir = _temporaryDirectory;
    if (dir == null) {
      dir = await invoke(ChannelMethods.getTemporaryDirectory, null);
      _temporaryDirectory = dir;
    }
    return dir;
  }

}
