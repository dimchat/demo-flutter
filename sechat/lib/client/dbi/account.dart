import 'package:dim_client/dim_client.dart';

abstract class PrivateKeyTable implements PrivateKeyDBI {

  ///  Save private key for user
  ///
  /// @param user - user ID
  /// @param key - private key
  /// @param type - 'M' for matching meta.key; or 'P' for matching profile.key
  /// @param sign - whether use for signature
  /// @param decrypt - whether use for decryption
  /// @return false on error
  Future<bool> storePrivateKey(PrivateKey key, String type, ID user,
      {required int sign, required int decrypt});
}

abstract class MetaTable implements MetaDBI {

}

abstract class DocumentTable implements DocumentDBI {

}

abstract class UserTable implements UserDBI {

  Future<bool> addUser(ID user);

  Future<bool> removeUser(ID user);

  Future<bool> setCurrentUser(ID user);

  Future<ID?> getCurrentUser();

}

abstract class ContactTable implements UserDBI {

  Future<bool> addContact(ID contact, {required ID user});

  Future<bool> removeContact(ID contact, {required ID user});

}

abstract class GroupTable implements GroupDBI {

  Future<bool> addMember(ID member, {required ID group});

  Future<bool> removeMember(ID member, {required ID group});

  Future<bool> removeGroup(ID group);

}
