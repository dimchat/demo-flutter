import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../client/shared.dart';
import '../filesys/local.dart';
import '../filesys/paths.dart';
import '../widgets/styles.dart';

import 'png.dart';


class AvatarFactory {
  factory AvatarFactory() => _instance;
  static final AvatarFactory _instance = AvatarFactory._internal();
  AvatarFactory._internal();

  final Map<ID, _AvatarLoader> _avatarLoaders = WeakValueMap();

  _AvatarLoader _getAvatarLoader(ID identifier) {
    _AvatarLoader? loader = _avatarLoaders[identifier];
    if (loader == null) {
      loader = _AvatarLoader(identifier);
      _avatarLoaders[identifier] = loader;
    }
    return loader;
  }

  Widget getAvatarView(ID identifier, {double? width, double? height, GestureTapCallback? onTap}) {
    width ??= 32;
    height ??= 32;
    _AvatarLoader loader = _getAvatarLoader(identifier);
    return ClipRRect(
      borderRadius: BorderRadius.all(
        Radius.elliptical(width / 8, height / 8),
      ),
      child: _FacadeView(loader, width: width, height: height, onTap: onTap,),
    );
  }

}

/// Auto refresh avatar view
class _FacadeView extends StatefulWidget {
  const _FacadeView(this.loader, {this.width, this.height, this.onTap});

  final _AvatarLoader loader;

  final double? width;
  final double? height;

  final GestureTapCallback? onTap;

  @override
  State<StatefulWidget> createState() => _FacadeState();

}

class _FacadeState extends State<_FacadeView> implements lnc.Observer {
  _FacadeState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = userInfo?['ID'];
      Document? visa = userInfo?['document'];
      assert(identifier != null && visa != null, 'notification error: $notification');
      if (identifier == widget.loader.identifier) {
        Log.info('document updated, refreshing facade: $identifier');
        // update visa document and refresh
        widget.loader.setNeedsReload();
        _reload();
      }
    } else {
      assert(false, 'should not happen');
    }
  }

  void _reload() async {
    _AvatarLoader loader = widget.loader;
    await loader.load((count, total) {
      Log.info('received $count/$total bytes: $loader');
    });
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
    Widget? image = widget.loader.getImage(width: widget.width, height: widget.height);
    if (image == null) {
      return widget.loader.getNoImage(width: widget.width, height: widget.height);
    }
    return GestureDetector(
      onTap: widget.onTap,
      child: image,
    );
  }

}

///
///    Avatar Loader
///
class _AvatarLoader {
  _AvatarLoader(this.identifier);

  final ID identifier;

  PNGLoader? _imageLoader;

  ImageProvider? _imageProvider;

  @override
  String toString() {
    Type clazz = runtimeType;
    PortableNetworkFile? pnf = _imageLoader?.pnf;
    return '<$clazz url="${pnf?.url}" filename="${pnf?.filename}" />';
  }

  Widget? getImage({double? width, double? height}) {
    ImageProvider? provider = _imageProvider;
    if (provider == null) {
      return null;
    }
    return Image(image: provider, width: width, height: height, fit: BoxFit.cover,);
  }

  Widget getNoImage({double? width, double? height}) {
    double? size = width ?? height;
    if (identifier.type == EntityType.kStation) {
      return Icon(Styles.stationIcon, size: size, color: Styles.avatarColor);
    } else if (identifier.type == EntityType.kBot) {
      return Icon(Styles.botIcon, size: size, color: Styles.avatarColor);
    } else if (identifier.type == EntityType.kISP) {
      return Icon(Styles.ispIcon, size: size, color: Styles.avatarColor);
    } else if (identifier.type == EntityType.kICP) {
      return Icon(Styles.icpIcon, size: size, color: Styles.avatarColor);
    }
    if (identifier.isUser) {
      return Icon(Styles.userIcon, size: size, color: Styles.avatarDefaultColor);
    } else {
      return Icon(Styles.groupIcon, size: size, color: Styles.avatarDefaultColor);
    }
  }

  void setNeedsReload() {
    _imageLoader = null;
  }

  Future<void> load(ProgressCallback? onReceiveProgress) async {
    PNGLoader? loader = _imageLoader;
    if (loader != null) {
      // already loaded
      return;
    }
    // get visa document
    GlobalVariable shared = GlobalVariable();
    Visa? doc = await shared.facebook.getVisa(identifier);
    if (doc == null) {
      Log.warning('visa document not found: $identifier');
      return;
    }
    // get visa.avatar
    PortableNetworkFile? avatar = doc.avatar;
    if (avatar == null) {
      Log.warning('avatar not found: $doc');
      return;
    }
    // load avatar
    _imageLoader = loader = PNGLoader(avatar);
    LocalStorage local = LocalStorage();
    String cachesDirectory = await local.cachesDirectory;
    String avatarDirectory = Paths.append(cachesDirectory, 'avatar');
    _imageProvider = await loader.loadImage(avatarDirectory);
  }

}
