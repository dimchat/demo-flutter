/* license: https://mit-license.org
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2019 Albert Moky
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
 * ==============================================================================
 */
package chat.dim.database;

import chat.dim.protocol.ID;
import chat.dim.protocol.InstantMessage;

public interface MessageTable {

    //---- conversations

    /**
     *  Get how many chat boxes
     *
     * @return conversations count
     */
    int numberOfConversations();

    /**
     *  Get chat box info
     *
     * @param index - sorted index
     * @return conversation ID
     */
    ID conversationAtIndex(int index);

    /**
     *  Remove one chat box
     *
     * @param index - chat box index
     * @return true on row(s) affected
     */
    boolean removeConversationAtIndex(int index);

    /**
     *  Remove the chat box
     *
     * @param entity - conversation ID
     * @return true on row(s) affected
     */
    boolean removeConversation(ID entity);

    //-------- messages

    /**
     *  Get message count in this conversation for an entity
     *
     * @param entity - conversation ID
     * @return total count
     */
    int numberOfMessages(ID entity);

    /**
     *  Get unread message count in this conversation for an entity
     *
     * @param entity - conversation ID
     * @return unread count
     */
    int numberOfUnreadMessages(ID entity);

    /**
     *  Clear unread flag in this conversation for an entity
     *
     * @param entity - conversation ID
     * @return true on row(s) affected
     */
    boolean clearUnreadMessages(ID entity);

    /**
     *  Get last message of this conversation
     *
     * @param entity - conversation ID
     * @return instant message
     */
    InstantMessage lastMessage(ID entity);

    /**
     *  Get last received message from all conversations
     *
     * @param user - current user ID
     * @return instant message
     */
    InstantMessage lastReceivedMessage(ID user);

    /**
     *  Get message at index of this conversation
     *
     * @param index - start from 0, latest first
     * @param entity - conversation ID
     * @return instant message
     */
    InstantMessage messageAtIndex(int index, ID entity);

    /**
     *  Save the new message to local storage
     *
     * @param iMsg - instant message
     * @param entity - conversation ID
     * @return true on success
     */
    boolean insertMessage(InstantMessage iMsg, ID entity);

    /**
     *  Delete the message
     *
     * @param iMsg - instant message
     * @param entity - conversation ID
     * @return true on row(s) affected
     */
    boolean removeMessage(InstantMessage iMsg, ID entity);

    /**
     *  Try to withdraw the message, maybe won't success
     *
     * @param iMsg - instant message
     * @param entity - conversation ID
     * @return true on success
     */
    boolean withdrawMessage(InstantMessage iMsg, ID entity);

    /**
     *  Update message state with receipt
     *
     * @param iMsg - message with receipt content
     * @param entity - conversation ID
     * @return true while target message found
     */
    boolean saveReceipt(InstantMessage iMsg, ID entity);
}
