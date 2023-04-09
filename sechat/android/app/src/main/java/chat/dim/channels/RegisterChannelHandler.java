package chat.dim.channels;

import androidx.annotation.NonNull;

import chat.dim.GlobalVariable;
import chat.dim.Register;
import chat.dim.SharedFacebook;
import chat.dim.mkm.User;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import chat.dim.protocol.ID;

public class RegisterChannelHandler implements MethodChannel.MethodCallHandler {

    @Override
    public void onMethodCall(MethodCall call, @NonNull MethodChannel.Result result) {
        if (call.method.equals(ChannelMethods.CREATE_USER)) {
            String name = call.argument("name");
            String avatar = call.argument("avatar");
            System.out.println("generate user: " + name + ", avatar: " + avatar + ".");
            ID identifier = createUser(name, avatar);
            if (identifier == null) {
                result.error("-1", "failed to generate user", null);
            } else {
                result.success(identifier.toString());
            }
        } else {
            result.notImplemented();
        }
    }

    private static SharedFacebook getFacebook() {
        GlobalVariable shared = GlobalVariable.getInstance();
        return shared.facebook;
    }

    private ID createUser(String nickname, String avatarURL) {
        SharedFacebook facebook = getFacebook();
        Register userRegister = new Register(facebook.getDatabase());
        ID identifier = userRegister.createUser(nickname, avatarURL);
        if (identifier == null) {
            return null;
        }
        User user = facebook.getUser(identifier);
        assert user != null : "user error: " + identifier;
        facebook.setCurrentUser(user);
        return identifier;
    }
}
