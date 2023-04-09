/* license: https://mit-license.org
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2022 Albert Moky
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
package chat.dim.cpu.customized;

import java.util.List;

import chat.dim.Facebook;
import chat.dim.Messenger;
import chat.dim.protocol.Content;
import chat.dim.protocol.CustomizedContent;
import chat.dim.protocol.ID;
import chat.dim.protocol.ReliableMessage;

/**
 *  Drift Bottle Game
 *  ~~~~~~~~~~~~~~~~~
 *
 *  Handler for customized content
 */
public class DriftBottleHandler extends AppContentHandler {

    // module name
    public static final String MOD_NAME = "drift_bottle";

    // action names
    public static final String ACT_THROW = "throw";
    public static final String ACT_CATCH = "catch";

    public DriftBottleHandler(Facebook facebook, Messenger messenger) {
        super(facebook, messenger);
    }

    @Override
    public List<Content> handleAction(String act, ID sender, CustomizedContent content, ReliableMessage rMsg) {
        if (act == null) {
            throw new IllegalArgumentException("action name empty: " + content);
        } else if (act.equals(ACT_THROW)) {
            // action "throw"
            return doThrow(sender, content, rMsg);
        } else if (act.equals(ACT_CATCH)) {
            // action "catch"
            return doCatch(sender, content, rMsg);
        }
        // TODO: define your actions here
        // ...

        return super.handleAction(act, sender, content, rMsg);
    }

    //
    //  Actions
    //

    private List<Content> doThrow(ID sender, CustomizedContent content, ReliableMessage rMsg) {
        // TODO: handle customized action with message content
        return null;
    }

    private List<Content> doCatch(ID sender, CustomizedContent content, ReliableMessage rMsg) {
        // TODO: handle customized action with message content
        return null;
    }
}
