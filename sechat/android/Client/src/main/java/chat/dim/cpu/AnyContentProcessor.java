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
package chat.dim.cpu;

import java.util.List;

import chat.dim.Messenger;
import chat.dim.Facebook;
import chat.dim.protocol.AudioContent;
import chat.dim.protocol.Content;
import chat.dim.protocol.Envelope;
import chat.dim.protocol.FileContent;
import chat.dim.protocol.ImageContent;
import chat.dim.protocol.PageContent;
import chat.dim.protocol.ReceiptCommand;
import chat.dim.protocol.ReliableMessage;
import chat.dim.protocol.TextContent;
import chat.dim.protocol.VideoContent;

public class AnyContentProcessor extends BaseContentProcessor {

    public AnyContentProcessor(Facebook facebook, Messenger messenger) {
        super(facebook, messenger);
    }

    @Override
    public List<Content> process(Content content, ReliableMessage rMsg) {
        String text;

        // File: Image, Audio, Video
        if (content instanceof FileContent) {
            if (content instanceof ImageContent) {
                // Image
                text = "Image received";
            } else if (content instanceof AudioContent) {
                // Audio
                text = "Voice message received";
            } else if (content instanceof VideoContent) {
                // Video
                text = "Movie received";
            } else {
                // other file
                text = "File received";
            }
        } else if (content instanceof TextContent) {
            // Text
            text = "Text message received";
        } else if (content instanceof PageContent) {
            // Web page
            text = "Web page received";
        } else {
            // Other
            return super.process(content, rMsg);
        }

        Object group = content.getGroup();
        if (group != null) {
            // DON'T response group message for disturb reason
            return null;
        }

        // response
        Envelope env = rMsg.getEnvelope();
        long sn = content.getSerialNumber();
        String signature = rMsg.getString("signature");
        ReceiptCommand receipt = new ReceiptCommand(text, env, sn, signature);
        //receipt.put("signature", signature);
        return respondContent(receipt);
    }
}
