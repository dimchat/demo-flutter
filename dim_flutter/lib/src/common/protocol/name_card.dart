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

///  Name card content: {
///      type : 0x33,
///      sn   : 123,
///
///      ID     : "{ID}",        // contact's ID
///      name   : "{nickname}}", // contact's name
///      avatar : "{URL}",       // avatar url
///      meta   : {...}          // contact's meta (OPTIONAL)
///  }
abstract class NameCard implements Content {

  static const int kNameCard = (0x33); // 0011 0011

  ID get identifier;

  String get name;

  String? get avatar;

  Meta? get meta;

  static NameCard create(ID identifier, {Meta? meta, String? name, String? avatar}) =>
      NameCardContent.from(identifier, meta: meta, name: name, avatar: avatar);

}

class NameCardContent extends BaseContent implements NameCard {
  NameCardContent(super.dict);

  NameCardContent.from(ID identifier, {Meta? meta, String? name, String? avatar})
      : super.fromType(NameCard.kNameCard) {
    this['ID'] = identifier.toString();
    if (meta != null) {
      this['meta'] = meta.toMap();
    }
    if (name != null) {
      this['name'] = name;
    }
    if (avatar != null) {
      this['avatar'] = avatar;
    }
  }

  @override
  ID get identifier => ID.parse(this['ID'])!;

  @override
  Meta? get meta => Meta.parse(this['meta']);

  @override
  String get name => getString('name') ?? '';

  @override
  String? get avatar => getString('avatar');

}
