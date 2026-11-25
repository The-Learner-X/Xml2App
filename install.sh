#!/bin/bash
set -e

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_PATH='\033[1;36m'   # Bold Cyan for file & folder paths
C_STEP='\033[1;35m'   # Bold Magenta for process/step headers
C_INFO='\033[1;34m'   # Bold Blue for status messages
C_OK='\033[1;32m'     # Bold Green for success
C_WARN='\033[1;33m'   # Bold Yellow for warnings
C_ERR='\033[1;31m'    # Bold Red for errors

p() { echo -e "${C_PATH}$1${C_RESET}"; }
step() { echo -e "\n${C_STEP}▶ [$1]${C_RESET} ${C_BOLD}$2${C_RESET}"; }

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo -e "\n${C_STEP}▶ Installing Tool${C_RESET} ${C_INFO}— Updating & upgrading Termux packages in${C_RESET} $(p "$PROJECT_DIR")${C_INFO}...${C_RESET}"
pkg update -y && pkg upgrade -y

echo -e "${C_INFO}=========================================${C_RESET}"
echo -e "${C_OK}  🚀 Setting up Xml2App Environment...    ${C_RESET}"
echo -e "${C_INFO}=========================================${C_RESET}"

# 1. Install required packages in Termux
step "1/6" "Installing required Termux packages..."
pkg install -y aapt2 openjdk-17 d8 apksigner zip unzip imagemagick git curl
echo -e "${C_OK}✔ Dependencies installed successfully.${C_RESET}"

# 2. Request storage access for copying SDK files
step "2/6" "Requesting storage permissions..."
termux-setup-storage || true
sleep 2
echo -e "${C_OK}✔ Storage check complete.${C_RESET}"

# 3. Create directory layout structure inside cloned repo
step "3/6" "Initializing project directories in $(p "$PROJECT_DIR")..."
mkdir -p res/layout res/values res/mipmap-hdpi src/com/my/app build/gen build/obj
echo -e "${C_OK}✔ Directories ready at $(p "$PROJECT_DIR/res"), $(p "$PROJECT_DIR/src"), $(p "$PROJECT_DIR/build").${C_RESET}"

# 4. Auto-locate or download android.jar and framework-res.apk
step "4/6" "Checking for Android SDK dependencies..."

if [ ! -f "android.jar" ]; then
    if [ -f "/sdcard/Download/android.jar" ]; then
        echo -e "${C_INFO}📥 Copying${C_RESET} $(p '/sdcard/Download/android.jar') ${C_INFO}->${C_RESET} $(p './android.jar')"
        cp /sdcard/Download/android.jar ./
        echo -e "${C_OK}✔ android.jar copied to $(p "$PROJECT_DIR/android.jar").${C_RESET}"
    else
        echo -e "${C_INFO}🌐 Downloading${C_RESET} $(p 'android.jar') ${C_INFO}...${C_RESET}"
        if ! curl -fSL -o android.jar https://repo1.maven.org/maven2/com/google/android/android/4.1.1.4/android-4.1.1.4.jar; then
            echo -e "${C_WARN}⚠️ Retrying download with curl -L...${C_RESET}"
            curl -L -o android.jar https://repo1.maven.org/maven2/com/google/android/android/4.1.1.4/android-4.1.1.4.jar
        fi
        echo -e "${C_OK}✔ android.jar downloaded to $(p "$PROJECT_DIR/android.jar").${C_RESET}"
    fi
else
    echo -e "${C_OK}✔ Found existing $(p "$PROJECT_DIR/android.jar").${C_RESET}"
fi

if [ ! -f "framework-res.apk" ]; then
    if [ -f "/sdcard/Download/framework-res.apk" ]; then
        echo -e "${C_INFO}📥 Copying${C_RESET} $(p '/sdcard/Download/framework-res.apk') ${C_INFO}->${C_RESET} $(p './framework-res.apk')"
        cp /sdcard/Download/framework-res.apk ./
        echo -e "${C_OK}✔ framework-res.apk copied to $(p "$PROJECT_DIR/framework-res.apk").${C_RESET}"
    elif [ -f "/system/framework/framework-res.apk" ]; then
        echo -e "${C_INFO}📥 Copying${C_RESET} $(p '/system/framework/framework-res.apk') ${C_INFO}->${C_RESET} $(p './framework-res.apk')"
        cp /system/framework/framework-res.apk ./
        echo -e "${C_OK}✔ framework-res.apk copied from $(p '/system/framework/framework-res.apk').${C_RESET}"
    else
        echo -e "${C_WARN}⚠️ Note:${C_RESET} $(p 'framework-res.apk') ${C_WARN}not found yet.${C_RESET}"
    fi
else
    echo -e "${C_OK}✔ Found existing $(p "$PROJECT_DIR/framework-res.apk").${C_RESET}"
fi

# 5. Generate build.sh
step "5/6" "Creating $(p "$PROJECT_DIR/build.sh")..."
cat << 'BUILD_EOF' > build.sh
#!/bin/bash
set -e

# ANSI color codes for terminal output
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_PATH='\033[1;36m'   # Bold Cyan for file & folder paths
C_STEP='\033[1;35m'   # Bold Magenta for process/step headers
C_INFO='\033[1;34m'   # Bold Blue for status messages
C_OK='\033[1;32m'     # Bold Green for success
C_WARN='\033[1;33m'   # Bold Yellow for warnings
C_ERR='\033[1;31m'    # Bold Red for errors

p() { echo -e "${C_PATH}$1${C_RESET}"; }
step() { echo -e "\n${C_STEP}▶ [$1]${C_RESET} ${C_BOLD}$2${C_RESET}"; }

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo -e "${C_INFO}🚀 Building Hello World App with Splash Screen in${C_RESET} $(p "$PROJECT_DIR")${C_INFO}...${C_RESET}"

# Step 0: SDK Check & Auto-Fetch
step "0/9" "Verifying SDK files ($(p 'framework-res.apk') & $(p 'android.jar'))..."

if [ ! -f "framework-res.apk" ]; then
    if [ -f "/system/framework/framework-res.apk" ]; then
        echo -e "${C_INFO}📦 Copying${C_RESET} $(p '/system/framework/framework-res.apk') ${C_INFO}->${C_RESET} $(p './framework-res.apk')"
        cp /system/framework/framework-res.apk ./
    elif [ -f "/sdcard/Download/framework-res.apk" ]; then
        echo -e "${C_INFO}📦 Copying${C_RESET} $(p '/sdcard/Download/framework-res.apk') ${C_INFO}->${C_RESET} $(p './framework-res.apk')"
        cp /sdcard/Download/framework-res.apk ./
    fi
fi

if [ ! -f "android.jar" ]; then
    if [ -f "/sdcard/Download/android.jar" ]; then
        echo -e "${C_INFO}📥 Copying${C_RESET} $(p '/sdcard/Download/android.jar') ${C_INFO}->${C_RESET} $(p './android.jar')"
        cp /sdcard/Download/android.jar ./
    else
        echo -e "${C_INFO}🌐 Downloading${C_RESET} $(p 'android.jar') ${C_INFO}...${C_RESET}"
        if ! curl -fSL -o android.jar https://repo1.maven.org/maven2/com/google/android/android/4.1.1.4/android-4.1.1.4.jar; then
            echo -e "${C_WARN}⚠️ Retrying download with curl -L...${C_RESET}"
            curl -L -o android.jar https://repo1.maven.org/maven2/com/google/android/android/4.1.1.4/android-4.1.1.4.jar
        fi
    fi
fi

if [ ! -f "framework-res.apk" ] || [ ! -f "android.jar" ]; then
    echo -e "${C_ERR}❌ Error:${C_RESET} $(p 'framework-res.apk') or $(p 'android.jar') missing in $(p "$PROJECT_DIR") or $(p '/sdcard/Download/')!"
    exit 1
fi
echo -e "${C_OK}✔ SDK files verified.${C_RESET}"

PACKAGE="com.my.helloapp"
APP_NAME="Hello App"

# Step 1: Workspace Reset
step "1/9" "Cleaning & preparing build workspace..."
rm -rf "$PROJECT_DIR/src" "$PROJECT_DIR/res" "$PROJECT_DIR/build"
mkdir -p "$PROJECT_DIR/src/com/my/helloapp"
mkdir -p "$PROJECT_DIR/res/values"
mkdir -p "$PROJECT_DIR/res/mipmap-hdpi"
mkdir -p "$PROJECT_DIR/build/obj"
mkdir -p "$PROJECT_DIR/build/gen"
echo -e "${C_OK}✔ Workspace initialized in $(p "$PROJECT_DIR").${C_RESET}"

# Step 2: App Icon
step "2/9" "Generating app icon at $(p "$PROJECT_DIR/res/mipmap-hdpi/ic_launcher.png")..."
magick -size 72x72 xc:'#0f172a' -fill '#38bdf8' -gravity center -pointsize 32 -draw "text 0,0 'H'" res/mipmap-hdpi/ic_launcher.png
echo -e "${C_OK}✔ App icon created.${C_RESET}"

# Step 3: Strings
step "3/9" "Writing string resources to $(p "$PROJECT_DIR/res/values/strings.xml")..."
cat << 'STRINGS' > res/values/strings.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Hello App</string>
</resources>
STRINGS
echo -e "${C_OK}✔ strings.xml generated.${C_RESET}"

# Step 4: AndroidManifest.xml
step "4/9" "Writing manifest to $(p "$PROJECT_DIR/AndroidManifest.xml")..."
cat << 'MANIFEST' > AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.my.helloapp"
    android:versionCode="1"
    android:versionName="1.0">

    <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="30" />

    <application 
        android:label="@string/app_name" 
        android:icon="@mipmap/ic_launcher"
        android:theme="@android:style/Theme.NoTitleBar"
        android:hasCode="true">

        <activity android:name=".SplashActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <activity android:name=".MainActivity" android:exported="false" />
    </application>
</manifest>
MANIFEST
echo -e "${C_OK}✔ AndroidManifest.xml generated.${C_RESET}"

# Step 5: Java Sources
step "5/9" "Writing Java activities to $(p "$PROJECT_DIR/src/com/my/helloapp/")..."
cat << 'SPLASH' > src/com/my/helloapp/SplashActivity.java
package com.my.helloapp;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.TextView;

public class SplashActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setBackgroundColor(0xFF0F172A);

        TextView splashText = new TextView(this);
        splashText.setText("App");
        splashText.setTextSize(42);
        splashText.setTextColor(0xFF38BDF8);
        splashText.setTypeface(null, Typeface.BOLD);
        splashText.setGravity(Gravity.CENTER);

        layout.addView(splashText);
        setContentView(layout);

        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                startActivity(new Intent(SplashActivity.this, MainActivity.class));
                finish();
            }
        }, 2000);
    }
}
SPLASH

cat << 'MAIN' > src/com/my/helloapp/MainActivity.java
package com.my.helloapp;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.TextView;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setBackgroundColor(0xFF1E293B);

        TextView helloText = new TextView(this);
        helloText.setText("Hello world");
        helloText.setTextSize(28);
        helloText.setTextColor(Color.WHITE);
        helloText.setGravity(Gravity.CENTER);

        layout.addView(helloText);
        setContentView(layout);
    }
}
MAIN
echo -e "${C_OK}✔ SplashActivity.java & MainActivity.java written.${C_RESET}"

# Step 6: Compile & Link Resources + Java -> DEX
step "6/9" "Compiling resources, Java classes & DEX bytecode..."
rm -f HelloApp.apk

aapt2 compile --dir res -o build/resources.zip
aapt2 link -o build/unaligned.apk -I framework-res.apk --manifest AndroidManifest.xml build/resources.zip --java build/gen
javac --release 11 -d build/obj -classpath android.jar:build/gen src/com/my/helloapp/*.java build/gen/com/my/helloapp/R.java

JAVA_LIB_OPT=""
if [ -d "$PREFIX/lib/jvm/java-17-openjdk" ]; then
    JAVA_LIB_OPT="--lib $PREFIX/lib/jvm/java-17-openjdk"
elif [ -n "$JAVA_HOME" ] && [ -d "$JAVA_HOME" ]; then
    JAVA_LIB_OPT="--lib $JAVA_HOME"
fi

d8 --output build/ --classpath android.jar $JAVA_LIB_OPT $(find build/obj -name "*.class")
cd build && zip -uj unaligned.apk classes.dex >/dev/null && cd ..
echo -e "${C_OK}✔ Compiled resources ($(p 'build/resources.zip')) and injected $(p 'build/classes.dex').${C_RESET}"

# Step 7: Align APK
step "7/9" "Aligning APK package..."
if command -v zipalign &> /dev/null; then
    zipalign -v -p 4 build/unaligned.apk build/aligned.apk >/dev/null
    echo -e "${C_OK}✔ Aligned to $(p 'build/aligned.apk').${C_RESET}"
else
    cp build/unaligned.apk build/aligned.apk
    echo -e "${C_WARN}⚠️ zipalign not found; copied $(p 'build/unaligned.apk') -> $(p 'build/aligned.apk').${C_RESET}"
fi

# Step 8: Sign APK
step "8/9" "Signing APK with keystore..."
if [ ! -f "build/key.jks" ]; then
    echo -e "${C_INFO}🔑 Generating keystore at${C_RESET} $(p 'build/key.jks')${C_INFO}...${C_RESET}"
    keytool -genkey -v -keystore build/key.jks -alias key -keyalg RSA -keysize 2048 -validity 10000 -storepass 123456 -keypass 123456 -dname "CN=Android, O=Android, C=US" >/dev/null 2>&1 || true
fi

apksigner sign --ks build/key.jks --ks-pass pass:123456 --min-sdk-version 21 --out HelloApp.apk build/aligned.apk
echo -e "${C_OK}✔ Signed APK at $(p "$PROJECT_DIR/HelloApp.apk").${C_RESET}"

# Step 9: Export APK
step "9/9" "Exporting APK to storage..."
if [ -d "/sdcard/Download" ]; then
    cp HelloApp.apk /sdcard/Download/HelloApp.apk
    echo -e "\n${C_OK}=== SUCCESS!${C_RESET} $(p "$PROJECT_DIR/HelloApp.apk") ${C_OK}saved to${C_RESET} $(p '/sdcard/Download/HelloApp.apk') ${C_OK}===${C_RESET}"
else
    echo -e "\n${C_OK}=== SUCCESS!${C_RESET} $(p "$PROJECT_DIR/HelloApp.apk") ${C_OK}built ===${C_RESET}"
fi
BUILD_EOF

echo -e "${C_OK}✔ Created $(p "$PROJECT_DIR/build.sh").${C_RESET}"

# 6. Set executable permissions
step "6/6" "Setting executable permissions..."
chmod +x "$PROJECT_DIR/build.sh"
echo -e "${C_OK}✔ Made $(p "$PROJECT_DIR/build.sh") executable.${C_RESET}"

echo -e "\n${C_INFO}=========================================${C_RESET}"
echo -e " ${C_OK}Tool install succesfully now run \"./build.sh\" to compile app${C_RESET}"
echo -e "${C_INFO}=========================================${C_RESET}"
