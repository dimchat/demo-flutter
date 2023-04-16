import 'package:dim_client/dim_client.dart';

import 'http/ftp.dart';

class SharedFacebook extends ClientFacebook {
  SharedFacebook(super.adb);

  Future<Pair<String?, Uri?>> getAvatar(ID user) async {
    String? urlString;
    Document? doc = await getDocument(user, '*');
    if (doc != null) {
      if (doc is Visa) {
        urlString = doc.avatar;
      } else {
        urlString = doc.getProperty('avatar');
      }
    }
    String? path;
    Uri? url;
    if (urlString != null && urlString.contains('://')) {
      try {
        url = Uri.parse(urlString);
        FileTransfer ftp = FileTransfer();
        // TODO: observe notification: 'FileUploadSuccess'
        path = await ftp.downloadAvatar(url);
      } catch (e) {
        Log.error('failed to get avatar path: $urlString, error: $e');
      }
    }
    return Pair(path, url);
  }

}
