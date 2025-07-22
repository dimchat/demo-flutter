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
import 'package:dim_client/sdk.dart';


///  Search command: {
///      type : 0x88,
///      sn   : 123,
///
///      command  : "search",        // or "users"
///      keywords : "{keywords}",    // keyword string
///
///      start    : 0,
///      limit    : 50,
///
///      station  : "{STATION_ID}",  // station ID
///      users    : ["{ID}"]         // user ID list
///  }
abstract interface class SearchCommand implements Command {

  // ignore_for_file: constant_identifier_names
  static const String SEARCH = 'search';
  static const String ONLINE_USERS = 'users';

  String? get keywords;
  set keywords(String? words);
  void setKeywords(List<String> keywords);

  int get start;
  set start(int value);

  int get limit;
  set limit(int value);

  ID? get station;
  set station(ID? sid);

  ///  Get user ID list
  ///
  /// @return ID string list
  List<ID> get users;

  //
  //  Factory
  //

  static SearchCommand fromKeywords(String keywords) {
    assert(keywords.isNotEmpty, 'keywords should not be empty');
    String cmd;
    if (keywords == SearchCommand.ONLINE_USERS) {
      cmd = SearchCommand.ONLINE_USERS;
      keywords = '';
    } else {
      cmd = SearchCommand.SEARCH;
    }
    return BaseSearchCommand.from(cmd, keywords);
  }

}

class BaseSearchCommand extends BaseCommand implements SearchCommand {
  BaseSearchCommand(super.dict);

  BaseSearchCommand.from(String name, String keywords) : super.fromName(name) {
    if (keywords.isNotEmpty) {
      this['keywords'] = keywords;
    }
  }

  @override
  String? get keywords {
    String? words = getString('keywords');
    if (words == null && cmd == SearchCommand.ONLINE_USERS) {
      words = SearchCommand.ONLINE_USERS;
    }
    return words;
  }

  @override
  set keywords(String? words) {
    if (words == null) {
      remove('keywords');
    } else {
      this['keywords'] = keywords;
    }
  }

  @override
  void setKeywords(List<String> keywords) {
    if (keywords.isEmpty) {
      remove('keywords');
    } else {
      this['keywords'] = keywords.join(' ');
    }
  }

  @override
  int get start => getInt('start') ?? 0;

  @override
  set start(int value) => this['start'] = value;

  @override
  int get limit => this['limit'] ?? 0;

  @override
  set limit(int value) => this['limit'] = value;

  @override
  ID? get station => ID.parse(this['station']);

  @override
  set station(ID? sid) {
    if (sid == null) {
      remove('station');
    } else {
      this['station'] = sid.toString();
    }
  }

  @override
  List<ID> get users {
    var array = this['users'];
    return array == null ? [] : ID.convert(array);
  }

}
