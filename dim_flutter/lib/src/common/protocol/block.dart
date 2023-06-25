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

/// Block Protocol
/// ~~~~~~~~~~~~~~
/// Ignore all messages in this conversation,
/// which ID(user/group) contains in 'list'.
/// If value of 'list' is None, means querying block-list from station
///
///  Command message: {
///      type : 0x88,
///      sn   : 123,
///
///      command : "block",
///      list    : []       // block-list
///  }
class BlockCommand extends BaseCommand {
  BlockCommand(super.dict);

  static const String kBlock  = 'block';

  BlockCommand.fromList(List<ID> contacts) : super.fromName(kBlock) {
    list = contacts;
  }

  List<ID> get list {
    List<ID>? array = this['list'];
    if (array == null) {
      return [];
    }
    return ID.convert(array);
  }

  set list(List<ID> contacts) {
    this['list'] = ID.revert(contacts);
  }

}
