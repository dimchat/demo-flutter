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
package chat.dim.model;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import chat.dim.protocol.AudioContent;
import chat.dim.protocol.Command;
import chat.dim.protocol.Content;
import chat.dim.protocol.FileContent;
import chat.dim.protocol.GroupCommand;
import chat.dim.protocol.ID;
import chat.dim.protocol.ImageContent;
import chat.dim.protocol.LoginCommand;
import chat.dim.protocol.PageContent;
import chat.dim.protocol.TextContent;
import chat.dim.protocol.VideoContent;
import chat.dim.protocol.group.ExpelCommand;
import chat.dim.protocol.group.InviteCommand;
import chat.dim.protocol.group.QueryCommand;
import chat.dim.protocol.group.QuitCommand;
import chat.dim.protocol.group.ResetCommand;
import chat.dim.utils.ArrayUtils;

public abstract class MessageBuilder {

    protected abstract String getName(ID identifier);

    public String getContentText(Content content) {
        String text = (String) content.get("text");
        if (text != null) {
            return text;
        }
        if (content instanceof TextContent) {
            // Text
            return ((TextContent) content).getText();
        } else if (content instanceof FileContent) {
            // File: Image, Audio, Video
            if (content instanceof ImageContent) {
                ImageContent image = (ImageContent) content;
                text = String.format("[Image:%s]", image.getFilename());
            } else if (content instanceof AudioContent) {
                AudioContent audio = (AudioContent) content;
                text = String.format("[Voice:%s]", audio.getFilename());
            } else if (content instanceof VideoContent) {
                VideoContent video = (VideoContent) content;
                text = String.format("[Movie:%s]", video.getFilename());
            } else {
                FileContent file = (FileContent) content;
                text = String.format("[File:%s]", file.getFilename());
            }
        } else if (content instanceof PageContent) {
            // Web page
            PageContent page = (PageContent) content;
            text = String.format("[URL:%s]", page.getURL());
        } else {
            text = String.format("Current version doesn't support this message type: %s", content.getType());
        }
        // store message text
        content.put("text", text);
        return text;
    }

    public String getCommandText(Command content, ID commander) {
        String text = (String) content.get("text");
        if (text != null) {
            return text;
        }
        if (content instanceof GroupCommand) {
            text = getGroupCommandText((GroupCommand) content, commander);
        //} else if (content instanceof HistoryCommand) {
            // TODO: process history command
        } else if (content instanceof LoginCommand) {
            text = getLoginCommandText((LoginCommand) content, commander);
        } else {
            text = String.format("Current version doesn't support this command: %s", content.getCmd());
        }
        // store message text
        content.put("text", text);
        return text;
    }

    //-------- System commands

    private String getLoginCommandText(LoginCommand content, ID commander) {
        assert commander != null : "commander error";
        ID identifier = content.getIdentifier();
        Map<String, Object> station = content.getStation();
        return String.format("%s login: %s", getName(identifier), station);
    }

    //...

    //-------- Group Commands

    private String getGroupCommandText(GroupCommand content, ID commander) {
        if (content instanceof InviteCommand) {
            return getInviteCommandText((InviteCommand) content, commander);
        }
        if (content instanceof ExpelCommand) {
            return getExpelCommandText((ExpelCommand) content, commander);
        }
        if (content instanceof QuitCommand) {
            return getQuitCommandText((QuitCommand) content, commander);
        }
        if (content instanceof ResetCommand) {
            return getResetCommandText((ResetCommand) content, commander);
        }
        if (content instanceof QueryCommand) {
            return getQueryCommandText((QueryCommand) content, commander);
        }
        return String.format("unsupported group command: %s", content);
    }

    @SuppressWarnings("unchecked")
    private String getInviteCommandText(InviteCommand content, ID commander) {
        List<String> addedList = (List<String>) content.get("added");
        if (addedList == null) {
            addedList = new ArrayList<>();
        }
        List<ID> members = ID.convert(addedList);
        List<String> names = new ArrayList<>();
        for (ID item : members) {
            names.add(getName(item));
        }
        String string = ArrayUtils.join(", ", names);
        return String.format("%s has invited members: %s", getName(commander), string);
    }

    @SuppressWarnings("unchecked")
    private String getExpelCommandText(ExpelCommand content, ID commander) {
        List<String> removedList = (List<String>) content.get("removed");
        if (removedList == null) {
            removedList = new ArrayList<>();
        }
        List<ID> members = ID.convert(removedList);
        List<String> names = new ArrayList<>();
        for (ID item : members) {
            names.add(getName(item));
        }
        String string = ArrayUtils.join(", ", names);
        return String.format("%s has removed members: %s", getName(commander), string);
    }

    private String getQuitCommandText(QuitCommand content, ID commander) {
        assert content.getGroup() != null : "quit command error: " + content;
        return String.format("%s has quit group chat.", getName(commander));
    }

    @SuppressWarnings("unchecked")
    private String getResetCommandText(ResetCommand content, ID commander) {
        List<String> addedList = (List<String>) content.get("added");
        List<String> removedList = (List<String>) content.get("removed");

        String string = "";
        if (removedList != null && removedList.size() > 0) {
            List<ID> members = ID.convert(removedList);
            List<String> names = new ArrayList<>();
            for (ID item : members) {
                names.add(getName(item));
            }
            string = string + ", removed: " + ArrayUtils.join(", ", names);
        }
        if (addedList != null && addedList.size() > 0) {
            List<ID> members = ID.convert(addedList);
            List<String> names = new ArrayList<>();
            for (ID item : members) {
                names.add(getName(item));
            }
            string = string + ", added: " + ArrayUtils.join(", ", names);
        }
        return String.format("%s has updated members %s", getName(commander), string);
    }

    private String getQueryCommandText(QueryCommand content, ID commander) {
        assert content.getGroup() != null : "quit command error: " + content;
        return String.format("%s was querying group info, responding...", getName(commander));
    }
}
