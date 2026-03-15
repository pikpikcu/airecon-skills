# CTF Android Challenges

Android CTF = static reverse engineering of APK → find flag logic → bypass/extract.
All CLI-based: Jadx, APKTool, ADB, Frida, smali patching — no Android Studio required.

## Install

```bash
# Jadx — decompiler (Java source from APK)
sudo apt-get install -y jadx
# OR: wget https://github.com/skylot/jadx/releases/latest/download/jadx-<ver>.zip && unzip

# APKTool — smali disassembly + repackage
sudo apt-get install -y apktool

# ADB — Android Debug Bridge
sudo apt-get install -y adb

# Frida — dynamic instrumentation
pip install frida-tools --break-system-packages
# frida-server must be pushed to device/emulator

# Additional tools:
sudo apt-get install -y zipalign apksigner
pip install androguard --break-system-packages   # Python APK analysis
```

---

## Phase 1: APK Reconnaissance

```bash
# Extract APK (it's a ZIP):
unzip challenge.apk -d apk_contents/
ls apk_contents/

# Key files:
# AndroidManifest.xml  — permissions, activities, exported components
# classes.dex          — compiled Java bytecode (DEX format)
# classes2.dex         — multidex (if present)
# lib/                 — native .so libraries per ABI
# assets/              — raw assets (sometimes flag or encrypted data)
# res/                 — resources

# Decode manifest:
apktool d challenge.apk -o apk_decoded/
cat apk_decoded/AndroidManifest.xml

# Check for exported activities (attack surface):
grep -i "exported=\"true\"\|android:exported" apk_decoded/AndroidManifest.xml
```

---

## Phase 2: Static Analysis — Jadx

```bash
# Decompile to Java source:
jadx challenge.apk -d jadx_output/
ls jadx_output/sources/

# Search for flag patterns:
grep -r "flag\|CTF\|secret\|password\|key\|encrypt\|decrypt" jadx_output/sources/ -l
grep -r "flag{" jadx_output/sources/
grep -rn "BuildConfig\|SECRET\|API_KEY\|TOKEN" jadx_output/sources/

# Search for native library calls:
grep -rn "System.loadLibrary\|native " jadx_output/sources/

# Check shared preferences / SQLite usage:
grep -rn "SharedPreferences\|SQLiteDatabase\|getDatabase" jadx_output/sources/

# Jadx GUI (headless extract only):
jadx-gui challenge.apk &   # opens GUI — use if available
# CLI equivalent: jadx challenge.apk -d out/ --show-bad-code
```

---

## Phase 3: Smali Analysis (APKTool)

```bash
# Disassemble to smali (Dalvik assembly):
apktool d challenge.apk -o smali_output/
ls smali_output/smali/

# Find main activity:
grep -r "onCreate\|onStart" smali_output/smali/ -l

# Read specific class:
cat smali_output/smali/com/challenge/MainActivity.smali

# Search for string constants:
grep -r "const-string" smali_output/smali/ | grep -i "flag\|secret\|key"

# Search for comparison logic (flag check):
grep -rn "invoke-virtual.*equals\|if-eq\|if-ne" smali_output/smali/MainActivity.smali
```

---

## Phase 4: Native Library Analysis

```bash
# Extract and analyze .so files:
ls apk_contents/lib/x86_64/     # x86_64 for emulator
ls apk_contents/lib/arm64-v8a/  # ARM64 for device

# Static analysis:
file apk_contents/lib/x86_64/libnative.so
strings apk_contents/lib/x86_64/libnative.so | grep -i "flag\|secret\|check"
nm -D apk_contents/lib/x86_64/libnative.so   # exported symbols

# Disassemble native functions:
objdump -d apk_contents/lib/x86_64/libnative.so | grep -A30 "Java_.*check\|Java_.*verify\|Java_.*validate"

# Radare2 for deeper analysis:
r2 -A apk_contents/lib/x86_64/libnative.so
afl | grep Java_   # list JNI functions
pdf @ sym.Java_com_challenge_MainActivity_checkFlag
```

---

## Phase 5: Dynamic Analysis — ADB + Emulator

```bash
# Start Android emulator (from Android SDK):
emulator -avd <avd_name> -no-snapshot &

# OR use existing device:
adb devices    # list connected devices

# Install APK:
adb install challenge.apk

# Launch specific activity:
adb shell am start -n com.challenge.app/.MainActivity
adb shell am start -n com.challenge.app/.FlagActivity   # try exported activities

# Start activity with intent extras (bypass checks):
adb shell am start -n com.challenge.app/.CheckActivity \
  -e "password" "test" \
  --ei "code" 1337

# Content provider query (if exported):
adb shell content query --uri content://com.challenge.provider/flag

# Broadcast receiver:
adb shell am broadcast -a com.challenge.FLAG_ACTION -e key value

# Log output (filter app):
adb logcat | grep -i "flag\|secret\|challenge\|CTF"
adb logcat -s "MainActivity:V"   # verbose for MainActivity tag
```

---

## Phase 6: Frida Dynamic Instrumentation

```bash
# Push frida-server to emulator/device:
# Download: https://github.com/frida/frida/releases (match arch: x86_64/arm64)
adb push frida-server-<ver>-android-x86_64 /data/local/tmp/frida-server
adb shell chmod 755 /data/local/tmp/frida-server
adb shell /data/local/tmp/frida-server &

# List processes:
frida-ps -U    # USB device
frida-ps -e    # emulator

# Hook Java method to intercept flag check:
frida -U -n com.challenge.app -l hook.js
```

```javascript
// hook.js — intercept checkFlag return value
Java.perform(function() {
    var MainActivity = Java.use('com.challenge.app.MainActivity');

    // Hook checkFlag method:
    MainActivity.checkFlag.implementation = function(input) {
        console.log('[*] checkFlag called with: ' + input);
        var result = this.checkFlag(input);
        console.log('[*] checkFlag returned: ' + result);
        return result;
    };

    // Force return true (bypass check):
    MainActivity.checkFlag.overload('java.lang.String').implementation = function(input) {
        console.log('[*] Bypassing checkFlag, input: ' + input);
        return true;
    };

    // Hook string comparison to see expected value:
    var String = Java.use('java.lang.String');
    String.equals.implementation = function(other) {
        var result = this.equals(other);
        if (this.toString().length > 3) {
            console.log('[*] String.equals: "' + this + '" == "' + other + '" -> ' + result);
        }
        return result;
    };
});
```

```javascript
// hook.js — dump native function args (JNI)
Interceptor.attach(Module.findExportByName("libnative.so", "Java_com_challenge_MainActivity_checkFlag"), {
    onEnter: function(args) {
        // args[0] = JNIEnv*, args[1] = jclass/jobject, args[2+] = actual args
        console.log('[*] Native checkFlag called');
        console.log('[*] arg2: ' + Java.vm.getEnv().getStringUtfChars(args[2], null).readCString());
    },
    onLeave: function(retval) {
        console.log('[*] Native checkFlag returned: ' + retval);
        retval.replace(1);   // force return 1 (true)
    }
});
```

---

## Phase 7: Smali Patching (Bypass)

```bash
# Patch APK to bypass flag check:

# 1. Decompile:
apktool d challenge.apk -o patched/

# 2. Find the check in smali:
grep -n "invoke-virtual.*checkFlag\|if-eqz\|if-nez" patched/smali/com/challenge/MainActivity.smali

# 3. Patch: change conditional jump to unconditional
# if-eqz v0, :cond_fail  →  goto :cond_success
# Edit smali file:
sed -i 's/if-eqz v0, :cond_fail/goto :cond_success/' patched/smali/com/challenge/MainActivity.smali

# 4. Recompile:
apktool b patched/ -o patched_challenge.apk

# 5. Sign APK (required for installation):
keytool -genkey -v -keystore debug.keystore -alias alias_name -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"
apksigner sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android patched_challenge.apk

# 6. Install:
adb uninstall com.challenge.app
adb install patched_challenge.apk
```

---

## Phase 8: Common CTF Android Patterns

```bash
# Pattern 1: Flag in strings.xml
grep -r "flag\|CTF" apk_decoded/res/values/strings.xml

# Pattern 2: Flag in assets file
cat apk_contents/assets/flag.txt
strings apk_contents/assets/data.bin

# Pattern 3: Encrypted flag — find key in code
grep -rn "AES\|DES\|Base64\|decrypt" jadx_output/sources/ -l
# Look for hardcoded key/IV near decrypt call

# Pattern 4: Flag from server after auth bypass
# Use Frida to intercept HTTP response:
Java.perform(function() {
    var OkHttpClient = Java.use('okhttp3.OkHttpClient');
    // Hook response interception
});

# Pattern 5: Flag via exported content provider
adb shell content query --uri content://com.challenge.provider/secrets
adb shell content query --uri content://com.challenge.provider/users

# Pattern 6: Flag in SQLite database
adb shell run-as com.challenge.app ls /data/data/com.challenge.app/databases/
adb shell run-as com.challenge.app cp /data/data/com.challenge.app/databases/app.db /sdcard/
adb pull /sdcard/app.db .
sqlite3 app.db ".tables"
sqlite3 app.db "SELECT * FROM flags;"

# Pattern 7: React Native bundle
unzip challenge.apk -d rn/ && cat rn/assets/index.android.bundle | grep -o "flag{[^}]*}"
# OR prettify:
node -e "const f=require('fs'); console.log(f.readFileSync('index.android.bundle','utf8'));" | grep flag
```

---

## Pro Tips

1. **Always Jadx first** — source decompilation reveals flag logic in 60% of challenges
2. **Check `assets/`** — flags often stored in plaintext or base64 in asset files
3. **Frida `String.equals` hook** — intercepts all comparisons → reveals expected flag character by character
4. **Exported activities** — test with `adb shell am start` + random intents before reversing
5. **Native library** — use `strings` on `.so` first; JNI function names start with `Java_`
6. **React Native apps** — decompile is just reading `index.android.bundle` JavaScript
7. **Root detection bypass** — Frida hook `RootBeer.isRooted()` or `Su.exists()` to return false

## Summary

Android CTF flow: `unzip` → `jadx` decompile → `grep flag` in sources → check `assets/` → analyze `lib/*.so` with `strings/objdump/r2` → dynamic: `adb install` + `frida` hook comparisons → smali patch to bypass if needed → `cat /data/data/app/databases/*.db`.
