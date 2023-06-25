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


abstract class InstantMessageDBI {

  ///  Get stored messages
  ///
  /// @param chat  - conversation ID
  /// @param start - start position for loading message
  /// @param limit - max count for loading message
  /// @return partial messages and remaining count, 0 means there are all messages cached
  Future<Pair<List<InstantMessage>, int>> getInstantMessages(ID chat,
      {int start = 0, int? limit});

  ///  Save the message
  ///
  /// @param chat - conversation ID
  /// @param iMsg - instant message
  /// @return true on success
  Future<bool> saveInstantMessage(ID chat, InstantMessage iMsg);

  ///  Delete the message
  ///
  /// @param chat - conversation ID
  /// @param iMsg - instant message
  /// @return true on row(s) affected
  Future<bool> removeInstantMessage(ID chat, InstantMessage iMsg);

  ///  Delete all messages in this conversation
  ///
  /// @param chat - conversation ID
  /// @return true on row(s) affected
  Future<bool> removeInstantMessages(ID chat);

}


abstract class TraceDBI {

  ///  Get traces for message
  ///
  /// @param sender    - message's sender
  /// @param sn        - message's serial number
  /// @param signature - message's signature
  /// @return MTA list
  Future<List<String>> getTraces(ID sender, int sn, String? signature);

  ///  Save message trace (response)
  ///
  /// @param trace     - response: '{"ID": "{MTA_ID}", "time": 0}'
  /// @param cid       - conversation ID
  /// @param sender    - original message's sender
  /// @param sn        - original message's serial number
  /// @param signature - original message's signature (last 8 characters)
  /// @return false on error
  Future<bool> addTrace(String trace, ID cid,
      {required ID sender, required int sn, required String? signature});

  ///  Remove traces for message
  ///  (call when message delete)
  ///
  /// @param sender    - message's sender
  /// @param sn        - message's serial number
  /// @param signature - message's signature
  /// @return false on error
  Future<bool> removeTraces(ID sender, int sn, String? signature);

  ///  Remove all traces in the conversation
  ///  (call when conversation cleared)
  ///
  /// @param cid       - conversation ID
  /// @return false on error
  Future<bool> removeAllTraces(ID cid);

}
