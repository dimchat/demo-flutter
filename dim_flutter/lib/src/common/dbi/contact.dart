/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */
import 'package:dim_client/dim_client.dart';

class ContactRemark {
  ContactRemark(this.identifier, {required this.alias, required this.description});

  final ID identifier;
  String alias;
  String description;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz id="$identifier" alias="$alias" desc="$description" />';
  }

  static ContactRemark empty(ID identifier) =>
      ContactRemark(identifier, alias: '', description: '');

}


abstract class RemarkDBI {

  Future<List<ContactRemark>> allRemarks({required ID user});

  Future<ContactRemark?> getRemark(ID contact, {required ID user});

  Future<bool> setRemark(ContactRemark remark, {required ID user});

}


abstract class BlockedDBI {

  Future<List<ID>> getBlockList({required ID user});

  Future<bool> saveBlockList(List<ID> contacts, {required ID user});

  Future<bool> addBlocked(ID contact, {required ID user});

  Future<bool> removeBlocked(ID contact, {required ID user});

}


abstract class MutedDBI {

  Future<List<ID>> getMuteList({required ID user});

  Future<bool> saveMuteList(List<ID> contacts, {required ID user});

  Future<bool> addMuted(ID contact, {required ID user});

  Future<bool> removeMuted(ID contact, {required ID user});

}
