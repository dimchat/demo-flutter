# Secure Chat (Flutter version)

[![License](https://img.shields.io/github/license/dimpart/demo-flutter)](https://raw.githubusercontent.com/dimpart/demo-flutter/master/LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/dimpart/demo-flutter/pulls)
[![Platform](https://img.shields.io/badge/Platform-Flutter%203-brightgreen.svg)](https://github.com/dimpart/demo-flutter/wiki)
[![Issues](https://img.shields.io/github/issues/dimpart/demo-flutter.svg)](https://github.com/dimpart/demo-flutter/issues)
[![Repo Size](https://img.shields.io/github/repo-size/dimpart/demo-flutter)](https://github.com/dimpart/demo-flutter/archive/refs/heads/main.zip)
[![Tags](https://img.shields.io/github/tag/dimpart/demo-flutter)](https://github.com/dimpart/demo-flutter/tags)

[![Watchers](https://img.shields.io/github/watchers/dimpart/demo-flutter)](https://github.com/dimpart/demo-flutter/watchers)
[![Forks](https://img.shields.io/github/forks/dimpart/demo-flutter.svg)](https://github.com/dimpart/demo-flutter/network)
[![Stars](https://img.shields.io/github/stars/dimpart/demo-flutter.svg)](https://github.com/dimpart/demo-flutter/stargazers)
[![Followers](https://img.shields.io/github/followers/dimpart)](https://github.com/orgs/dimpart/followers)

## Environment

* Flutter 3.22.2
* Dart 3.4.3

### Dependencies

```bash
awk '
/  name: /{n=$2; gsub(/"/,"",n)}
/  version: /{v=$2; gsub(/"/,"",v); print n " | " v}
' pubspec.lock
```

**file**: dimpart/tarsier/pubspec.lock

| package | version |
| -------:|:------- |
args | 2.7.0
asn1lib | 1.6.5
async | 2.13.1
basic_utils | 5.7.0
bip32 | 2.0.0
bip39 | 1.0.6
boolean_selector | 2.1.2
bs58check | 1.0.2
castscreen | 1.0.2
characters | 1.4.1
chewie | 1.8.1
clock | 1.1.2
code_assets | 1.2.1
collection | 1.19.1
convert | 3.1.2
cross_file | 0.3.5+2
crypto | 3.0.7
csslib | 1.0.2
cupertino_icons | 1.0.8
dbus | 0.7.14
device_info_plus | 9.1.2
device_info_plus_platform_interface | 7.0.3
dim_client | 1.4.8
dim_client | 1.0.0
dim_plugins | 2.3.3
dimp | 2.3.3
dimsdk | 2.3.3
dio | 5.9.2
dio_web_adapter | 2.1.2
dkd | 2.3.3
encrypt | 5.0.3
fake_async | 1.3.3
fast_base58 | 0.2.1
ffi | 2.2.0
file | 7.0.1
file_selector_linux | 0.9.4
file_selector_macos | 0.9.5
file_selector_platform_interface | 2.7.0
file_selector_windows | 0.9.3+5
file_selector_windows | 0.0.0
flutter_image_compress | 2.3.0
flutter_image_compress_common | 1.0.6
flutter_image_compress_macos | 1.0.3
flutter_image_compress_ohos | 0.0.3
flutter_image_compress_platform_interface | 1.0.5
flutter_image_compress_web | 0.1.5
flutter_inappwebview | 6.1.5
flutter_inappwebview_android | 1.1.3
flutter_inappwebview_internal_annotations | 1.3.0
flutter_inappwebview_ios | 1.1.2
flutter_inappwebview_macos | 1.1.2
flutter_inappwebview_platform_interface | 1.3.0+1
flutter_inappwebview_web | 1.1.2
flutter_inappwebview_windows | 0.6.0
flutter_lints | 2.0.3
flutter_lints | 0.0.0
flutter_markdown | 0.7.7
flutter_plugin_android_lifecycle | 2.0.35
flutter_section_list | 1.1.1
flutter_staggered_grid_view | 0.7.0
flutter_staggered_grid_view | 0.0.0
flutter_staggered_grid_view | 0.0.0
get | 4.6.6
hex | 0.2.0
hooks | 2.0.2
html | 0.15.6
http | 1.6.0
http_parser | 4.1.2
image_gallery_saver | 2.0.3
image_picker | 1.1.2
image_picker_android | 0.8.13+19
image_picker_for_web | 3.1.1
image_picker_ios | 0.8.13+6
image_picker_linux | 0.2.2
image_picker_macos | 0.2.2+1
image_picker_platform_interface | 2.11.1
image_picker_windows | 0.2.2
intl | 0.20.2
jni | 1.0.0
jni_flutter | 1.0.1
js | 0.7.2
json_annotation | 4.12.0
leak_tracker | 11.0.2
leak_tracker_flutter_testing | 3.0.10
leak_tracker_testing | 3.0.2
lints | 2.1.1
lnc | 1.2.2
logging | 1.3.0
markdown | 7.3.0
matcher | 0.12.19
material_color_utilities | 0.13.0
meta | 1.18.0
mime | 2.0.0
mkm | 2.3.3
mutex | 3.1.0
nested | 1.0.0
object_key | 1.1.1
objective_c | 9.4.1
package_config | 2.2.0
package_info_plus | 8.3.1
package_info_plus_platform_interface | 3.2.1
path | 1.9.1
path_provider | 2.1.2
path_provider_android | 2.3.1
path_provider_foundation | 2.6.0
path_provider_linux | 2.2.1
path_provider_platform_interface | 2.1.3
path_provider_windows | 2.3.0
permission_handler | 12.0.0
permission_handler_android | 13.0.1
permission_handler_apple | 9.4.10
permission_handler_html | 0.1.3+5
permission_handler_platform_interface | 4.3.0
permission_handler_windows | 0.2.1
petitparser | 7.0.2
photo_view | 0.14.0
platform | 3.1.6
plugin_platform_interface | 2.1.8
pnf | 1.5.0
pointycastle | 3.9.1
provider | 6.1.5+1
pub_semver | 2.2.0
record_use | 0.6.0
shared_preferences | 2.2.2
shared_preferences_android | 2.4.26
shared_preferences_foundation | 2.5.6
shared_preferences_linux | 2.4.1
shared_preferences_platform_interface | 2.4.2
shared_preferences_web | 2.4.3
shared_preferences_windows | 2.4.1
shared_preferences_windows | 0.0.0
source_span | 1.10.2
sqflite | 2.4.3
sqflite_android | 2.4.3
sqflite_common | 2.5.11
sqflite_darwin | 2.4.3
sqflite_platform_interface | 2.4.1
stack_trace | 1.12.1
stargate | 1.2.0
startrek | 1.2.0
stream_channel | 2.1.4
string_scanner | 1.4.1
synchronized | 3.4.1
syntax_highlight | 0.4.0
term_glyph | 1.2.2
test_api | 0.7.11
tvbox | 1.0.0
typed_data | 1.4.0
url_launcher | 6.3.0
url_launcher_android | 6.3.32
url_launcher_ios | 6.4.1
url_launcher_linux | 3.2.2
url_launcher_macos | 3.2.5
url_launcher_platform_interface | 2.3.2
url_launcher_web | 2.4.3
url_launcher_windows | 3.1.5
vector_math | 2.2.0
video_player | 2.8.3
video_player_android | 2.5.3
video_player_avfoundation | 2.9.7
video_player_platform_interface | 6.7.0
video_player_web | 2.4.0
vm_service | 15.2.0
wakelock_plus | 1.3.3
wakelock_plus_platform_interface | 1.5.1
web | 1.1.1
win32 | 5.15.0
win32_registry | 1.1.5
xdg_directories | 1.1.0
xml | 6.6.1
yaml | 3.1.3

## FIX ME

### image\_gallery\_saver

* **file**: image\_gallery\_saver-2.0.3/android/build.gradle
* **line**: 5
* **line**: 23
* **line**: 33
* **line**: 37

```
group 'com.example.imagegallerysaver'
version '1.0-SNAPSHOT'

buildscript {
//    ext.kotlin_version = '1.7.10'
    ext.kotlin_version = '1.8.0'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
        kotlinOptions {
            jvmTarget = '1.8'
        }
    }
}

apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'

android {
    namespace "com.example.imageGallerySaver"

    compileSdkVersion 30

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }
    defaultConfig {
        minSdkVersion 16
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }
    lintOptions {
        disable 'InvalidPackage'
    }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
}    
```

* **file**: image\_gallery\_saver-2.0.3/android/src/main/AndroidManifest.xml
* **line**: 2

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
<!--  package="com.example.imagegallerysaver">-->
</manifest>
```

* **file**: image\_gallery\_saver-2.0.3/android/src/main/kotlin/com/example/imagegallerysaver/ImageGallerySaverPlugin.kt
* **line**: 21

```kt
import io.flutter.plugin.common.MethodChannel.Result
//import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File
```

### image\_picker\_android

* **file**: image_picker_android-0.8.13+19/android/build.gradle.kts
* **line**: 62

```
android {

    ...

    compileOptions {
//        sourceCompatibility = JavaVersion.VERSION_17
//        targetCompatibility = JavaVersion.VERSION_17
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    
    ...
    
}
```

### flutter\_image\_compress\_common

* **file**: flutter\_image\_compress\_common-1.0.6/android/build.gradle
* **line**: 21
* **line**: 48
* **line**: 52

```
group 'com.fluttercandies.flutter_image_compress'
version '1.0-SNAPSHOT'

buildscript {
    ext.kotlin_version = '1.8.20'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
        kotlinOptions {
            jvmTarget = '1.8'
        }
    }
}

apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'

android {
    if (project.android.hasProperty("namespace")) {
        namespace 'com.fluttercandies.flutter_image_compress'
    }

    compileSdkVersion 34

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        minSdkVersion 21
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    kotlinOptions {
//        jvmTarget = '11'
        jvmTarget = '1.8'
    }

//    compileOptions {
//        // Sets Java compatibility to Java 11
//        sourceCompatibility JavaVersion.VERSION_11
//        targetCompatibility JavaVersion.VERSION_11
//    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    implementation 'androidx.exifinterface:exifinterface:1.3.3'
    implementation 'androidx.heifwriter:heifwriter:1.0.0'
    implementation 'commons-io:commons-io:2.6'
}
```

### package\_info\_plus

* **file**: package\_info\_plus-7.0.0/android/build.gradle
* **line**: 33
* **line**: 41

```
android {
    compileSdk 34

    namespace 'dev.fluttercommunity.plus.packageinfo'

    compileOptions {
//        sourceCompatibility JavaVersion.VERSION_17
//        targetCompatibility JavaVersion.VERSION_17
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
//        jvmTarget = 17
        jvmTarget = "1.8"
    }
    
    ...
```

### shared\_preferences\_android

* **file**: shared\_preferences\_android-2.4.10/android/build.gradle
* **line**: 39
* **line**: 49

```
android {
    namespace 'io.flutter.plugins.sharedpreferences'
    compileSdk = flutter.compileSdkVersion

    compileOptions {
//        sourceCompatibility JavaVersion.VERSION_11
//        targetCompatibility JavaVersion.VERSION_11
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
//        jvmTarget = '11'
        jvmTarget = '1.8'
    }

    ...
```

### url\_launcher\_android

* **file**: url_launcher_android-6.3.32/android/build.gradle.kts
* **line**: 48

```
android {

    ...

    compileOptions {
//        sourceCompatibility = JavaVersion.VERSION_17
//        targetCompatibility = JavaVersion.VERSION_17
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    
    ...
    
}
```

### video\_player\_android

* **file**: video_player_android-2.9.6/android/build.gradle.kts
* **line**: 50

```
android {

    ...

    compileOptions {
//        sourceCompatibility = JavaVersion.VERSION_17
//        targetCompatibility = JavaVersion.VERSION_17
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    
    ...
    
}
```

### wakelock\_plus

* **file**: wakelock\_plus-1.3.2/android/build.gradle
* **line**: 30
* **line**: 40

```
android {
    namespace 'dev.fluttercommunity.plus.wakelock'
    compileSdk 34

    compileOptions {
//        sourceCompatibility JavaVersion.VERSION_17
//        targetCompatibility JavaVersion.VERSION_17
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
//        jvmTarget = '17'
        jvmTarget = '1.8'
    }
    
    ...
```

### flutter\_markdown

* **file**: flutter\_markdown-0.7.7+1/lib/src/style_sheet.dart
* **line**: 148
* **line**: 328

```dart
      blockquoteDecoration: BoxDecoration(
        // color: Colors.blue.shade100,
        color: theme.brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(2.0),
      ),
      
      ...
      
      blockquoteDecoration: BoxDecoration(
        // color: Colors.blue.shade100,
        color: theme.brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(2.0),
      ),
```

### asn1lib

* **file**: asn1lib-1.6.5/lib/src/asn1octetstring.dart
* **line**: 29

```dart
  ASN1OctetString(dynamic octets, {super.tag = OCTET_STRING_TYPE}) {
    if (octets is String) {
      // We now default to utf8 encoding
      // this.octets = Uint8List.fromList(octets.codeUnits);
      this.octets = utf8.encode(octets);
    } else if (octets is Uint8List) {
      this.octets = octets;
    } else if (octets is List<int>) {
      this.octets = Uint8List.fromList(octets);
    } else {
      throw ArgumentError(
        'Parameters octets should be either of type String or List<int>.',
      );
    }
  }
```

Copyright &copy; 2023-2026 Albert Moky
