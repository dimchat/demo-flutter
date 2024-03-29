package chat.dim.http;

import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.ProgressBar;

import androidx.core.content.FileProvider;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

import chat.dim.dim_flutter.R;
import chat.dim.threading.BackgroundThreads;
import chat.dim.utils.Log;

public class UpdateManager {

   private final Context mContext;
   private boolean intercept = false;

   private int progress;
   private ProgressBar mProgress;

   private static final int SHOW_UPGRADE = 0;
   private static final int DOWN_UPDATE = 1;
   private static final int DOWN_OVER = 2;

   public UpdateManager(Context context) {
      mContext = context;
   }

   private boolean isNewest() {
      VersionManager man = VersionManager.getInstance();
      JSONObject info = man.downloadNewestInfo();
      if (info == null) {
         // assert false : "failed to download newest info";
         Log.error("failed to download newest info");
         return true;
      }
      boolean newest = man.isNewest(mContext);
      if (Log.LEVEL == Log.DEBUG) {
         // TEST:
         if (newest) {
            newest = false;
         }
      }
      return newest;
   }
   private String getNewVersion() {
      VersionManager man = VersionManager.getInstance();
      String version = man.getNewestVersionName();
      if (Log.LEVEL == Log.DEBUG) {
         // TEST:
         if (version == null) {
            version = "0.1.0";
         }
      }
      return version;
   }
   private String getNewBuild() {
      VersionManager man = VersionManager.getInstance();
      int build = man.getNewestVersionCode();
      return "Build " + build;
   }

   private String getApkUrl() {
      VersionManager man = VersionManager.getInstance();
      String url = man.getNewestApk();
      if (Log.LEVEL == Log.DEBUG) {
         // TEST:
         if (url == null) {
            url = "http://192.168.31.152/sechat.apk";
         }
      }
      return url;
   }

   private File getSaveDir() {
      File dir = mContext.getExternalCacheDir();
      Log.debug("upgrade file dir: " + dir + "/tmp");
      return new File(dir, "tmp");
   }
   private File getSavePath() {
      File dir = getSaveDir();
      Log.debug("upgrade file path: " + dir + "/release.apk");
      return new File(dir, "release.apk");
   }

   public void checkUpdateInfo() {
      Log.warning("checkUpdateInfo");
      BackgroundThreads.wait(() -> {
         if (isNewest()) {
            Log.warning("Already updated.");
         } else {
            mHandler.sendEmptyMessage(SHOW_UPGRADE);
         }
      });
   }

   private void showUpdateDialog() {
      AlertDialog.Builder builder = new AlertDialog.Builder(mContext);
      builder.setTitle("Upgrade (" + getNewVersion() + ", " + getNewBuild() + ")");
      builder.setMessage("New version is available, please download to upgrade.");
      builder.setPositiveButton("Download", (dialog, which) -> showDownloadDialog());
      //builder.setNegativeButton("Later", (dialog, which) -> dialog.dismiss());
      builder.setNegativeButton("Home", (dialog, which) -> goHome());

      builder.create().show();
   }

   private void goHome() {
      Uri url = Uri.parse("http://tarsier.dim.chat/");
      Intent intent = new Intent(Intent.ACTION_VIEW, url);
      Intent chooser = Intent.createChooser(intent, "Open With");
      mContext.startActivity(chooser);
   }

   private void showDownloadDialog() {
      AlertDialog.Builder builder = new AlertDialog.Builder(mContext);
      builder.setTitle("Upgrade (" + getNewVersion() + ")");
      LayoutInflater inflater = LayoutInflater.from(mContext);
      View v = inflater.inflate(R.layout.progress, null);
      mProgress = v.findViewById(R.id.progress);
      builder.setView(v);
      builder.setNegativeButton("Cancel", (dialog, which) -> intercept = true);
      builder.create().show();

      // start downloading
      Thread downLoadThread = new Thread(mDownApkRunnable);
      downLoadThread.start();
   }

   private final Runnable mDownApkRunnable = new Runnable() {

      @Override
      public void run() {
         URL url;
         try {
            url = new URL(getApkUrl());
            Log.info("trying to download apk: " + url);
            HttpURLConnection conn = (HttpURLConnection) url
                    .openConnection();
            conn.connect();
            int length = conn.getContentLength();
            InputStream ins = conn.getInputStream();
            File file = getSaveDir();
            if (!file.exists()) {
               boolean ok = file.mkdirs();
               assert ok : "failed to create dir: " ;
            }
            File apkFile = getSavePath();
            FileOutputStream fos = new FileOutputStream(apkFile);
            int count = 0;
            byte[] buf = new byte[1024];
            while (!intercept) {
               int len = ins.read(buf);
               count += len;
               progress = (int) (((float) count / length) * 100);

               mHandler.sendEmptyMessage(DOWN_UPDATE);
               if (len <= 0) {
                  mHandler.sendEmptyMessage(DOWN_OVER);
                  break;
               }
               fos.write(buf, 0, len);
            }
            fos.close();
            ins.close();

         } catch (Exception e) {
            e.printStackTrace();
         } catch (Error e) {
            e.printStackTrace();
         }
      }
   };

   private void installAPK() {
      File apkFile = getSavePath();
      if (apkFile.exists()) {
         Log.warning("apk exists: " + apkFile);
      } else {
         Log.error("apk not exists: " + apkFile);
         return;
      }
      Uri apkPath;
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
         apkPath = FileProvider.getUriForFile(mContext,
                 "chat.dim.tarsier.provider", apkFile);
      } else {
         apkPath = Uri.fromFile(apkFile);
      }
      Log.warning("perform install: " + apkPath);
      Intent intent = new Intent(Intent.ACTION_VIEW);
      intent.setDataAndType(apkPath, "application/vnd.android.package-archive");
      intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      mContext.startActivity(intent);
   }

   private final Handler mHandler = new Handler(Looper.getMainLooper()) {
      public void handleMessage(android.os.Message msg) {
         switch (msg.what) {

            case SHOW_UPGRADE:
               showUpdateDialog();
               break;

            case DOWN_UPDATE:
               mProgress.setProgress(progress);
               break;

            case DOWN_OVER:
               installAPK();
               break;

            default:
               break;
         }
      }

   };
}
