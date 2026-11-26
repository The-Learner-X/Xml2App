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

bar() {
    local cur="$1"
    local tot="$2"
    local width=20
    local pct=$((cur * 100 / tot))
    local filled=$((cur * width / tot))
    local empty=$((width - filled))
    local done_bar=""
    local rem_bar=""

    for ((i = 0; i < filled; i++)); do done_bar+="#"; done
    for ((i = 0; i < empty; i++)); do rem_bar+="-"; done

    echo -e "\n${C_INFO}Progress:${C_RESET} ${C_OK}[${done_bar}${C_WARN}${rem_bar}${C_OK}]${C_RESET} ${C_BOLD}${pct}%${C_RESET} ${C_INFO}(${cur}/${tot})${C_RESET}"
}

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
bar 1 6

# 2. Request storage access for copying SDK files
step "2/6" "Requesting storage permissions..."
termux-setup-storage || true
sleep 2
echo -e "${C_OK}✔ Storage check complete.${C_RESET}"
bar 2 6

# 3. Create directory layout structure inside cloned repo
step "3/6" "Initializing project directories in $(p "$PROJECT_DIR")..."
mkdir -p res/layout res/values res/mipmap-hdpi src/com/my/helloapp build/gen build/obj
echo -e "${C_OK}✔ Directories ready at $(p "$PROJECT_DIR/res"), $(p "$PROJECT_DIR/src"), $(p "$PROJECT_DIR/build").${C_RESET}"
bar 3 6

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
bar 4 6

# 5. Generate build.sh and xml2app interactive command
step "5/6" "Creating $(p "$PROJECT_DIR/build.sh") and $(p 'xml2app') CLI..."
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

bar() {
    local cur="$1"
    local tot="$2"
    local width=20
    local pct=$((cur * 100 / tot))
    local filled=$((cur * width / tot))
    local empty=$((width - filled))
    local done_bar=""
    local rem_bar=""

    for ((i = 0; i < filled; i++)); do done_bar+="#"; done
    for ((i = 0; i < empty; i++)); do rem_bar+="-"; done

    echo -e "\n${C_INFO}Progress:${C_RESET} ${C_OK}[${done_bar}${C_WARN}${rem_bar}${C_OK}]${C_RESET} ${C_BOLD}${pct}%${C_RESET} ${C_INFO}(${cur}/${tot})${C_RESET}"
}

step() { echo -e "\n${C_STEP}▶ [$1]${C_RESET} ${C_BOLD}$2${C_RESET}"; }

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

PACKAGE="com.my.helloapp"
if [ -f "$PROJECT_DIR/app_name.txt" ] && [ -s "$PROJECT_DIR/app_name.txt" ]; then
    APP_NAME="$(head -n 1 "$PROJECT_DIR/app_name.txt")"
else
    APP_NAME="Hello App"
fi

echo -e "${C_INFO}🚀 Building ${C_BOLD}${APP_NAME}${C_RESET}${C_INFO} with Splash Screen in${C_RESET} $(p "$PROJECT_DIR")${C_INFO}...${C_RESET}"

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
bar 1 10

# Step 1: Workspace Reset
step "1/9" "Cleaning & preparing build workspace..."
rm -rf "$PROJECT_DIR/src" "$PROJECT_DIR/res" "$PROJECT_DIR/build"
mkdir -p "$PROJECT_DIR/src/com/my/helloapp"
mkdir -p "$PROJECT_DIR/res/values"
mkdir -p "$PROJECT_DIR/res/mipmap-hdpi"
mkdir -p "$PROJECT_DIR/build/obj"
mkdir -p "$PROJECT_DIR/build/gen"
echo -e "${C_OK}✔ Workspace initialized in $(p "$PROJECT_DIR").${C_RESET}"
bar 2 10

# Step 2: App Icon
step "2/9" "Generating app icon at $(p "$PROJECT_DIR/res/mipmap-hdpi/ic_launcher.png")..."
magick -size 72x72 xc:'#0f172a' -fill '#38bdf8' -gravity center -pointsize 32 -draw "text 0,0 'H'" res/mipmap-hdpi/ic_launcher.png
echo -e "${C_OK}✔ App icon created.${C_RESET}"
bar 3 10

# Step 3: Strings
step "3/9" "Writing string resources to $(p "$PROJECT_DIR/res/values/strings.xml")..."
cat << STRINGS > res/values/strings.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">${APP_NAME}</string>
</resources>
STRINGS
echo -e "${C_OK}✔ strings.xml generated ($(C_BOLD)${APP_NAME}${C_RESET}).${C_RESET}"
bar 4 10

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
bar 5 10

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
bar 6 10

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
bar 7 10

# Step 7: Align APK
step "7/9" "Aligning APK package..."
if command -v zipalign &> /dev/null; then
    zipalign -v -p 4 build/unaligned.apk build/aligned.apk >/dev/null
    echo -e "${C_OK}✔ Aligned to $(p 'build/aligned.apk').${C_RESET}"
else
    cp build/unaligned.apk build/aligned.apk
    echo -e "${C_WARN}⚠️ zipalign not found; copied $(p 'build/unaligned.apk') -> $(p 'build/aligned.apk').${C_RESET}"
fi
bar 8 10

# Step 8: Sign APK
step "8/9" "Signing APK with keystore..."
if [ ! -f "build/key.jks" ]; then
    echo -e "${C_INFO}🔑 Generating keystore at${C_RESET} $(p 'build/key.jks')${C_INFO}...${C_RESET}"
    keytool -genkey -v -keystore build/key.jks -alias key -keyalg RSA -keysize 2048 -validity 10000 -storepass 123456 -keypass 123456 -dname "CN=Android, O=Android, C=US" >/dev/null 2>&1 || true
fi

apksigner sign --ks build/key.jks --ks-pass pass:123456 --min-sdk-version 21 --out HelloApp.apk build/aligned.apk
echo -e "${C_OK}✔ Signed APK at $(p "$PROJECT_DIR/HelloApp.apk").${C_RESET}"
bar 9 10

# Step 9: Export APK
step "9/9" "Exporting APK to storage..."
if [ -d "/sdcard/Download" ]; then
    cp HelloApp.apk /sdcard/Download/HelloApp.apk
    echo -e "\n${C_OK}=== SUCCESS!${C_RESET} $(p "$PROJECT_DIR/HelloApp.apk") ${C_OK}saved to${C_RESET} $(p '/sdcard/Download/HelloApp.apk') ${C_OK}===${C_RESET}"
else
    echo -e "\n${C_OK}=== SUCCESS!${C_RESET} $(p "$PROJECT_DIR/HelloApp.apk") ${C_OK}built ===${C_RESET}"
fi
bar 10 10
BUILD_EOF

cat << XML2APP_EOF > xml2app
#!/bin/bash
set -e

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_PATH='\033[1;36m'
C_STEP='\033[1;35m'
C_INFO='\033[1;34m'
C_OK='\033[1;32m'
C_WARN='\033[1;33m'
C_ERR='\033[1;31m'

p() { echo -e "${C_PATH}$1${C_RESET}"; }

PROJECT_DIR="${PROJECT_DIR}"
[ -d "\$PWD/res" ] || [ -f "\$PWD/build.sh" ] && PROJECT_DIR="\$PWD"
cd "\$PROJECT_DIR"

change_app_name() {
    local current_name="Hello App"
    if [ -f "\$PROJECT_DIR/app_name.txt" ] && [ -s "\$PROJECT_DIR/app_name.txt" ]; then
        current_name="\$(head -n 1 "\$PROJECT_DIR/app_name.txt")"
    fi

    echo -e "\n\${C_STEP}▶ [F] Change App Name\${C_RESET}"
    echo -e "\${C_INFO}Current app name:\${C_RESET} \${C_BOLD}\${current_name}\${C_RESET}"
    read -r -p "\$(echo -e "\${C_BOLD}Enter new app name: \${C_RESET}")" new_name

    if [ -z "\$new_name" ]; then
        echo -e "\${C_WARN}⚠️ App name cannot be empty. Keeping '\${current_name}'.\${C_RESET}"
        return 0
    fi

    printf "%s\n" "\$new_name" > "\$PROJECT_DIR/app_name.txt"
    mkdir -p "\$PROJECT_DIR/res/values"
    cat << STRINGS_EOF > "\$PROJECT_DIR/res/values/strings.xml"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">\${new_name}</string>
</resources>
STRINGS_EOF
    echo -e "\${C_OK}✔ App name updated to '\${new_name}' in \$(p "\$PROJECT_DIR/app_name.txt") and \$(p "\$PROJECT_DIR/res/values/strings.xml").\${C_RESET}"
}

pick_file_interactive() {
    local pattern="\$1"
    local search_root="\$2"
    local query=""
    local matches=()

    echo -e "\n\${C_INFO}🔎 Interactive File Search\${C_RESET} (\${C_WARN}pattern: \${pattern}\${C_RESET})"
    read -r -p "\$(echo -e "\${C_BOLD}Enter filename keyword (or press Enter to list recent matches): \${C_RESET}")" query

    if [ -n "\$query" ]; then
        mapfile -t matches < <(find "\$search_root" /sdcard -maxdepth 5 -iname "*\${query}*\${pattern}" 2>/dev/null | head -n 15 || true)
    else
        mapfile -t matches < <(find "\$search_root" /sdcard -maxdepth 4 -iname "*\${pattern}" 2>/dev/null | head -n 15 || true)
    fi

    if [ "\${#matches[@]}" -eq 0 ]; then
        echo -e "\${C_WARN}⚠️ No matching files found automatically.\${C_RESET}"
        read -r -p "\$(echo -e "\${C_BOLD}Enter full file path manually (or leave blank to cancel): \${C_RESET}")" manual_path
        if [ -n "\$manual_path" ] && [ -f "\$manual_path" ]; then
            SELECTED_FILE="\$manual_path"
            return 0
        fi
        SELECTED_FILE=""
        return 1
    fi

    echo -e "\n\${C_STEP}Found files:\${C_RESET}"
    local idx=1
    for f in "\${matches[@]}"; do
        echo -e "  \${C_BOLD}\${idx})\${C_RESET} \$(p "\$f")"
        idx=\$((idx + 1))
    done
    echo -e "  \${C_BOLD}0)\${C_RESET} Enter custom path / Cancel"

    read -r -p "\$(echo -e "\${C_BOLD}Select file number: \${C_RESET}")" choice
    if [[ "\$choice" =~ ^[0-9]+\$ ]] && [ "\$choice" -ge 1 ] && [ "\$choice" -le "\${#matches[@]}" ]; then
        SELECTED_FILE="\${matches[\$((choice - 1))]}"
        return 0
    elif [ "\$choice" = "0" ]; then
        read -r -p "\$(echo -e "\${C_BOLD}Enter full file path (or blank to cancel): \${C_RESET}")" manual_path
        if [ -n "\$manual_path" ] && [ -f "\$manual_path" ]; then
            SELECTED_FILE="\$manual_path"
            return 0
        fi
    fi

    SELECTED_FILE=""
    return 1
}

append_to_target() {
    local src_file="\$1"
    local dest_file="\$2"
    local mode="\${3:-append}"

    mkdir -p "\$(dirname "\$dest_file")"
    if [ "\$mode" = "replace" ]; then
        cp "\$src_file" "\$dest_file"
        echo -e "\${C_OK}✔ Replaced \$(p "\$dest_file") using \$(p "\$src_file").\${C_RESET}"
    else
        {
            echo ""
            echo "<!-- Appended from \$(basename "\$src_file") -->"
            cat "\$src_file"
        } >> "\$dest_file"
        echo -e "\${C_OK}✔ Appended \$(p "\$src_file") into \$(p "\$dest_file").\${C_RESET}"
    fi
}

create_new_main_file() {
    echo -e "\n\${C_STEP}▶ [E] Create New Main File\${C_RESET}"
    echo -e "  \${C_BOLD}1)\${C_RESET} AndroidManifest (\$(p "\$PROJECT_DIR/AndroidManifest.xml"))"
    echo -e "  \${C_BOLD}2)\${C_RESET} Layout (\$(p "\$PROJECT_DIR/res/layout/"))"
    echo -e "  \${C_BOLD}3)\${C_RESET} Activity (\$(p "\$PROJECT_DIR/src/com/my/helloapp/"))"
    read -r -p "\$(echo -e "\${C_BOLD}Choose file type [1-3]: \${C_RESET}")" ftype

    case "\$ftype" in
        1)
            read -r -p "\$(echo -e "\${C_BOLD}Package name [default: com.my.helloapp]: \${C_RESET}")" pkg_name
            pkg_name="\${pkg_name:-com.my.helloapp}"
            cat << EOF > "\$PROJECT_DIR/AndroidManifest.xml"
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="\${pkg_name}"
    android:versionCode="1"
    android:versionName="1.0">

    <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="30" />

    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher"
        android:theme="@android:style/Theme.NoTitleBar"
        android:hasCode="true">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF
            echo -e "\${C_OK}✔ Created \$(p "\$PROJECT_DIR/AndroidManifest.xml").\${C_RESET}"
            ;;
        2)
            read -r -p "\$(echo -e "\${C_BOLD}Layout name without .xml [default: activity_main]: \${C_RESET}")" lay_name
            lay_name="\${lay_name:-activity_main}"
            mkdir -p "\$PROJECT_DIR/res/layout"
            local lay_path="\$PROJECT_DIR/res/layout/\${lay_name}.xml"
            cat << 'EOF' > "\$lay_path"
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:gravity="center"
    android:orientation="vertical"
    android:background="#0F172A">

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Xml2App Layout"
        android:textColor="#38BDF8"
        android:textSize="24sp" />

</LinearLayout>
EOF
            echo -e "\${C_OK}✔ Created layout \$(p "\$lay_path").\${C_RESET}"
            ;;
        3)
            read -r -p "\$(echo -e "\${C_BOLD}Activity class name without .java [default: MainActivity]: \${C_RESET}")" act_name
            act_name="\${act_name:-MainActivity}"
            mkdir -p "\$PROJECT_DIR/src/com/my/helloapp"
            local act_path="\$PROJECT_DIR/src/com/my/helloapp/\${act_name}.java"
            cat << EOF > "\$act_path"
package com.my.helloapp;

import android.app.Activity;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.TextView;

public class \${act_name} extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setBackgroundColor(0xFF0F172A);

        TextView tv = new TextView(this);
        tv.setText("\${act_name}");
        tv.setTextSize(26);
        tv.setTextColor(0xFF38BDF8);
        tv.setGravity(Gravity.CENTER);

        layout.addView(tv);
        setContentView(layout);
    }
}
EOF
            echo -e "\${C_OK}✔ Created activity \$(p "\$act_path").\${C_RESET}"
            ;;
        *)
            echo -e "\${C_WARN}⚠️ Invalid selection.\${C_RESET}"
            ;;
    esac
}

main_file_edits_menu() {
    while true; do
        echo -e "\n\${C_INFO}=========================================\${C_RESET}"
        echo -e "\${C_STEP}  1) Main File Edits or Create New File\${C_RESET}"
        echo -e "\${C_INFO}=========================================\${C_RESET}"
        echo -e "  \${C_BOLD}A)\${C_RESET} Edit AndroidManifest"
        echo -e "  \${C_BOLD}B)\${C_RESET} Activity"
        echo -e "  \${C_BOLD}C)\${C_RESET} Layout"
        echo -e "  \${C_BOLD}D)\${C_RESET} Change icon"
        echo -e "  \${C_BOLD}E)\${C_RESET} Create new file (AndroidManifest / Layout / Activity)"
        echo -e "  \${C_BOLD}F)\${C_RESET} Change app name"
        echo -e "  \${C_BOLD}0)\${C_RESET} Back to main menu"
        read -r -p "\$(echo -e "\${C_BOLD}Select option [A/B/C/D/E/F/0]: \${C_RESET}")" sub_opt

        case "\${sub_opt^^}" in
            A)
                if pick_file_interactive ".xml" "\$PROJECT_DIR"; then
                    echo -e "  \${C_BOLD}1)\${C_RESET} Append content to \$(p "\$PROJECT_DIR/AndroidManifest.xml")"
                    echo -e "  \${C_BOLD}2)\${C_RESET} Replace \$(p "\$PROJECT_DIR/AndroidManifest.xml")"
                    read -r -p "\$(echo -e "\${C_BOLD}Choose [1/2]: \${C_RESET}")" m_mode
                    if [ "\$m_mode" = "2" ]; then
                        append_to_target "\$SELECTED_FILE" "\$PROJECT_DIR/AndroidManifest.xml" "replace"
                    else
                        append_to_target "\$SELECTED_FILE" "\$PROJECT_DIR/AndroidManifest.xml" "append"
                    fi
                fi
                ;;
            B)
                if pick_file_interactive ".java" "\$PROJECT_DIR"; then
                    mkdir -p "\$PROJECT_DIR/src/com/my/helloapp"
                    local target_act="\$PROJECT_DIR/src/com/my/helloapp/\$(basename "\$SELECTED_FILE")"
                    append_to_target "\$SELECTED_FILE" "\$target_act" "replace"
                fi
                ;;
            C)
                if pick_file_interactive ".xml" "\$PROJECT_DIR"; then
                    mkdir -p "\$PROJECT_DIR/res/layout"
                    local target_lay="\$PROJECT_DIR/res/layout/\$(basename "\$SELECTED_FILE")"
                    append_to_target "\$SELECTED_FILE" "\$target_lay" "replace"
                fi
                ;;
            D)
                if pick_file_interactive ".png" "\$PROJECT_DIR"; then
                    mkdir -p "\$PROJECT_DIR/res/mipmap-hdpi"
                    cp "\$SELECTED_FILE" "\$PROJECT_DIR/res/mipmap-hdpi/ic_launcher.png"
                    echo -e "\${C_OK}✔ Updated app icon \$(p "\$PROJECT_DIR/res/mipmap-hdpi/ic_launcher.png") from \$(p "\$SELECTED_FILE").\${C_RESET}"
                fi
                ;;
            E)
                create_new_main_file
                ;;
            F)
                change_app_name
                ;;
            0)
                break
                ;;
            *)
                echo -e "\${C_WARN}⚠️ Invalid option. Please enter A, B, C, D, E, F, or 0.\${C_RESET}"
                ;;
        esac
    done
}

while true; do
    echo -e "\n\${C_INFO}=========================================\${C_RESET}"
    echo -e "\${C_OK}  🎛️  Xml2App Interactive Mode (\${C_PATH}xml2app\${C_OK})\${C_RESET}"
    echo -e "\${C_INFO}=========================================\${C_RESET}"
    echo -e "  \${C_BOLD}1)\${C_RESET} Main file edits or create new file (A-F)"
    echo -e "  \${C_BOLD}2)\${C_RESET} Compile app now (\$(p './build.sh'))"
    echo -e "  \${C_BOLD}3)\${C_RESET} Show ready message"
    echo -e "  \${C_BOLD}4)\${C_RESET} Exit"
    read -r -p "\$(echo -e "\${C_BOLD}Select option [1-4]: \${C_RESET}")" menu_opt

    case "\$menu_opt" in
        1)
            main_file_edits_menu
            ;;
        2)
            "\$PROJECT_DIR/build.sh"
            ;;
        3)
            echo -e "\n\${C_INFO}=========================================\${C_RESET}"
            echo -e " \${C_OK}Tool install succesfully now run \"./build.sh\" to compile app\${C_RESET}"
            echo -e "\${C_INFO}=========================================\${C_RESET}"
            ;;
        4)
            break
            ;;
        *)
            echo -e "\${C_WARN}⚠️ Please enter a number between 1 and 4.\${C_RESET}"
            ;;
    esac
done
XML2APP_EOF

echo -e "${C_OK}✔ Created $(p "$PROJECT_DIR/build.sh") and $(p "$PROJECT_DIR/xml2app").${C_RESET}"
bar 5 6

# 6. Set executable permissions & install xml2app into $PREFIX/bin
step "6/6" "Setting executable permissions and registering $(p 'xml2app') command..."
chmod +x "$PROJECT_DIR/build.sh" "$PROJECT_DIR/xml2app"
if [ -n "$PREFIX" ] && [ -d "$PREFIX/bin" ]; then
    cp "$PROJECT_DIR/xml2app" "$PREFIX/bin/xml2app"
    chmod +x "$PREFIX/bin/xml2app"
    echo -e "${C_OK}✔ Installed $(p "$PREFIX/bin/xml2app") (run $(p 'xml2app') anytime).${C_RESET}"
fi
bar 6 6

echo -e "\n${C_INFO}=========================================${C_RESET}"
echo -e " ${C_OK}Tool install succesfully now run \"./build.sh\" to compile app${C_RESET}"
echo -e " ${C_INFO}Tip: Run $(p 'xml2app') anytime to open interactive file/build menu.${C_RESET}"
echo -e "${C_INFO}=========================================${C_RESET}"
