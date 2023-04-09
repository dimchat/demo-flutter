package chat.dim.channels;

import androidx.annotation.NonNull;

import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import chat.dim.GlobalVariable;
import chat.dim.SharedFacebook;
import chat.dim.mkm.Station;
import chat.dim.mkm.User;
import chat.dim.protocol.ID;
import chat.dim.type.Pair;

public class FacebookChannelHandler implements MethodChannel.MethodCallHandler {

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (call.method.equals(ChannelMethods.CURRENT_USER)) {
            Map<String, Object> current = getCurrentUserInfo();
            if (current == null) {
                result.error("-1", "failed to get current user", null);
            } else {
                result.success(current);
            }
        } else if (call.method.equals(ChannelMethods.CONTACTS_OF_USER)) {
            String user = call.argument("user");
            List<?> contacts = getContacts(ID.parse(user));
            if (contacts == null) {
                result.error("-1", "user ID error", null);
            } else {
                result.success(contacts);
            }
        } else {
            result.notImplemented();
        }
    }

    private static SharedFacebook getFacebook() {
        GlobalVariable shared = GlobalVariable.getInstance();
        return shared.facebook;
    }

    private Map<String, Object> getCurrentUserInfo() {
        SharedFacebook facebook = getFacebook();
        User user = facebook.getCurrentUser();
        if (user == null) {
            return null;
        }
        ID identifier = user.getIdentifier();
        String name = facebook.getName(identifier);
        Pair<String, URL> avatar = facebook.getAvatar(identifier);
        // build user info
        Map<String, Object> info = new HashMap<>();
        if (identifier != null) {
            info.put("identifier", identifier.toString());
        }
        if (name != null) {
            info.put("name", name);
        }
        if (avatar.first != null) {
            info.put("avatar", avatar.first);
        } else if (avatar.second != null) {
            info.put("avatar", avatar.second.toString());
        }
        return info;
    }

    private List<?> getContacts(ID user) {
        SharedFacebook facebook = getFacebook();
        if (user == null) {
            User current = facebook.getCurrentUser();
            if (current == null) {
                return null;
            }
            user = current.getIdentifier();
            assert user != null : "current suer error: " + current;
        }
        List<ID> contacts = facebook.getContacts(user);
        // TODO: test
        if (contacts.size() == 0) {
            System.out.println("build test contacts");
            contacts = new ArrayList<>();
            contacts.add(ID.ANYONE);
            contacts.add(ID.EVERYONE);
            contacts.add(ID.FOUNDER);
            contacts.add(Station.ANY);
            contacts.add(Station.EVERY);
        }
        List<Map<String, Object>> results = new ArrayList<>();
        Map<String, Object> item;
        Pair<String, URL> avatar;
        for (ID cid : contacts) {
            item = new HashMap<>();
            item.put("identifier", cid.toString());
            item.put("type", cid.getType());
            item.put("name", facebook.getName(cid));
            avatar = facebook.getAvatar(cid);
            if (avatar.first != null) {
                item.put("avatar", avatar.first);
            } else if (avatar.second != null) {
                item.put("avatar", avatar.second.toString());
            }
            results.add(item);
        }
        return results;
    }
}
