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

///  Command message: {
///      type : 0x88,
///      sn   : 123,
///
///      command  : "search",        // or "users"
///      keywords : "{keywords}",    // keyword string
///
///      start    : 0,
///      limit    : 20,
///
///      station  : "{STATION_ID}",  // station ID
///      users    : ["{ID}"]         // user ID list
///  }
class SearchCommand extends BaseCommand {
  SearchCommand(super.dict);

  SearchCommand.fromKeywords(String keywords)
      : super.fromName(keywords == kOnlineUsers ? kOnlineUsers : kSearch) {
    if (keywords != kOnlineUsers) {
      this['keywords'] = keywords;
    }
  }

  static const String kSearch = 'search';
  static const String kOnlineUsers = 'users';
  
  String? get keywords {
    String? words = getString('keywords');
    if (words == null && cmd == kOnlineUsers) {
      words = kOnlineUsers;
    }
    return words;
  }
  set keywords(String? words) {
    if (words == null) {
      remove('keywords');
    } else {
      this['keywords'] = keywords;
    }
  }
  void setKeywords(List<String> keywords) {
    if (keywords.isEmpty) {
      remove('keywords');
    } else {
      this['keywords'] = keywords.join(' ');
    }
  }

  int get start => getInt('start');
  set start(int value) => this['start'] = value;

  int get limit => this['limit'] ?? 20;
  set limit(int value) => this['limit'] = value;

  ID? get station => ID.parse(this['station']);
  set station(ID? sid) {
    if (sid == null) {
      remove('station');
    } else {
      this['station'] = sid.string;
    }
  }

  ///  Get user ID list
  ///
  /// @return ID string list
  List<ID> get users {
    var array = this['users'];
    return array == null ? [] : ID.convert(array);
  }

}
