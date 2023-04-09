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

import java.util.ArrayList;
import java.util.List;

import chat.dim.Facebook;
import chat.dim.Messenger;
import chat.dim.core.TwinsHelper;
import chat.dim.cpu.CustomizedContentHandler;
import chat.dim.cpu.CustomizedContentProcessor;
import chat.dim.dkd.AppCustomizedContent;
import chat.dim.dkd.BaseTextContent;
import chat.dim.protocol.Content;
import chat.dim.protocol.ContentType;
import chat.dim.protocol.CustomizedContent;
import chat.dim.protocol.ID;
import chat.dim.protocol.ReliableMessage;

/**
 *  Handler for App Customized Content
 */
public abstract class AppContentHandler extends TwinsHelper implements CustomizedContentHandler {

    // Application ID for customized content
    public static final String APP_ID = "chat.dim.sechat";

    public static String FMT_ACT_NOT_SUPPORT = CustomizedContentProcessor.FMT_ACT_NOT_SUPPORT;
    //public static String FMT_ACT_NOT_SUPPORT = "Customized Content (app: %s, mod: %s, act: %s) not support yet!";

    protected AppContentHandler(Facebook facebook, Messenger messenger) {
        super(facebook, messenger);
    }

    @Override
    public List<Content> handleAction(String act, ID sender, CustomizedContent content, ReliableMessage rMsg) {
        String app = content.getApplication();
        String mod = content.getModule();
        String text = String.format(FMT_ACT_NOT_SUPPORT, app, mod, act);
        return respondText(text, content.getGroup());
    }

    protected List<Content> respondText(String text, ID group) {
        Content res = new BaseTextContent(text);
        if (group != null) {
            res.setGroup(group);
        }
        List<Content> responses = new ArrayList<>();
        responses.add(res);
        return responses;
    }

    /**
     *  Create application customized content
     *
     * @param mod - module name
     * @param act - action name
     * @return application customized content
     */
    public static CustomizedContent create(String mod, String act) {
        return new AppCustomizedContent(ContentType.APPLICATION, APP_ID, mod, act);
    }
}
