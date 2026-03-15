# Frida — Dynamic Instrumentation & Runtime Hooking

Frida = inject JavaScript into running processes → hook functions, intercept calls, bypass checks, extract secrets at runtime. Works on Android, iOS, Linux, Windows, macOS binaries.

## Install

```bash
# Frida tools (attacker machine):
pip install frida-tools --break-system-packages
pip install frida --break-system-packages

# Verify:
frida --version
frida-ps --version

# frida-server (target device — must match frida version exactly):
# Android: https://github.com/frida/frida/releases → frida-server-X.X.X-android-x86_64.xz
# Linux: frida-server-X.X.X-linux-x86_64.xz
# Get version: python3 -c "import frida; print(frida.__version__)"
```

---

## Phase 1: Setup — Android Target

```bash
# Extract frida-server for target arch:
xz -d frida-server-*-android-x86_64.xz
adb push frida-server-*-android-x86_64 /data/local/tmp/frida-server
adb shell chmod 755 /data/local/tmp/frida-server

# Start frida-server (as root on device):
adb shell su -c "/data/local/tmp/frida-server &"
# OR:
adb shell "/data/local/tmp/frida-server &"   # some emulators don't need su

# Verify connection:
frida-ps -U           # list processes on USB device
frida-ps -U | grep -i target_app

# Find app process name:
frida-ps -U -a -i   # installed apps with package name
```

---

## Phase 2: Setup — Linux/Native Process

```bash
# Attach to running process:
frida -p <PID> -l hook.js        # by PID
frida -n "processname" -l hook.js  # by name

# Spawn new process with Frida:
frida -f /path/to/binary -l hook.js --no-pause

# Attach to specific function before main:
frida -f /path/to/binary --no-pause -l hook.js

# frida-server for remote target:
# On target:
./frida-server -l 0.0.0.0:27042
# On attacker:
frida -H target_ip:27042 -n processname -l hook.js
```

---

## Phase 3: Core JavaScript API

```javascript
// hook.js — fundamental patterns

// ============================================================
// JAVA HOOKS (Android)
// ============================================================
Java.perform(function() {

    // Hook a method:
    var TargetClass = Java.use('com.example.app.TargetClass');
    TargetClass.methodName.implementation = function(arg1, arg2) {
        console.log('[*] methodName called: arg1=' + arg1 + ' arg2=' + arg2);
        var result = this.methodName(arg1, arg2);  // call original
        console.log('[*] methodName returned: ' + result);
        return result;
    };

    // Override return value (bypass check):
    TargetClass.checkLicense.implementation = function() {
        console.log('[*] checkLicense bypassed');
        return true;
    };

    // Hook overloaded method (specify signature):
    TargetClass.verify.overload('java.lang.String', 'int').implementation = function(s, i) {
        console.log('[*] verify(' + s + ', ' + i + ')');
        return this.verify(s, i);
    };

    // Enumerate all loaded classes:
    Java.enumerateLoadedClasses({
        onMatch: function(name) {
            if (name.includes('crypto') || name.includes('security')) {
                console.log('[Class] ' + name);
            }
        },
        onComplete: function() {}
    });

    // Trace all methods in a class:
    var methods = Java.use('com.example.app.CryptoHelper').class.getDeclaredMethods();
    methods.forEach(function(method) {
        console.log('[Method] ' + method.getName());
    });

    // Access static field:
    var MyClass = Java.use('com.example.app.Config');
    console.log('[*] SECRET_KEY = ' + MyClass.SECRET_KEY.value);

    // Create new object:
    var ArrayList = Java.use('java.util.ArrayList');
    var list = ArrayList.$new();
    list.add('item');

    // Call static method:
    var Utils = Java.use('com.example.app.Utils');
    var result = Utils.decrypt('encrypted_data');
    console.log('[*] Decrypted: ' + result);
});
```

---

## Phase 4: Native Hooks (C/C++ functions)

```javascript
// ============================================================
// NATIVE HOOKS (C/C++ via Interceptor)
// ============================================================

// Hook exported function by name:
Interceptor.attach(Module.findExportByName(null, 'strcmp'), {
    onEnter: function(args) {
        try {
            var s1 = Memory.readUtf8String(args[0]);
            var s2 = Memory.readUtf8String(args[1]);
            if (s1 && s2 && s1.length > 3) {
                console.log('[strcmp] "' + s1 + '" == "' + s2 + '"');
            }
        } catch(e) {}
    },
    onLeave: function(retval) {
        // Force match (return 0 = strings equal):
        // retval.replace(0);
    }
});

// Hook function by address (when not exported):
var baseAddr = Module.findBaseAddress('libnative.so');
var funcAddr = baseAddr.add(0x1234);   // offset from r2/objdump analysis

Interceptor.attach(funcAddr, {
    onEnter: function(args) {
        console.log('[*] func@0x1234 called');
        console.log('[*] arg0 (int): ' + args[0].toInt32());
        console.log('[*] arg1 (str): ' + Memory.readUtf8String(args[1]));
        console.log('[*] arg2 (ptr): ' + args[2]);
    },
    onLeave: function(retval) {
        console.log('[*] returned: ' + retval.toInt32());
        retval.replace(1);   // override return value
    }
});

// Hook all calls to function (trampoline):
Interceptor.replace(funcAddr, new NativeCallback(function(arg0, arg1) {
    console.log('[*] Replaced function called! arg0=' + arg0);
    // Custom implementation:
    return 1;   // always return 1
}, 'int', ['int', 'pointer']));

// Read/write memory:
var addr = ptr('0x7f1234abcd');
console.log(Memory.readUtf8String(addr));
console.log(hexdump(addr, { length: 64 }));
Memory.writeUtf8String(addr, 'new_value');
Memory.writeByteArray(addr, [0x90, 0x90, 0x90]);  // NOP patch
```

---

## Phase 5: Cryptography Tracing

```javascript
// Hook Android crypto APIs to extract keys/plaintext:
Java.perform(function() {

    // Hook javax.crypto.Cipher (AES/DES/etc):
    var Cipher = Java.use('javax.crypto.Cipher');

    Cipher.doFinal.overload('[B').implementation = function(input) {
        console.log('[Cipher.doFinal] input hex: ' + bytesToHex(input));
        var result = this.doFinal(input);
        console.log('[Cipher.doFinal] output hex: ' + bytesToHex(result));
        return result;
    };

    // Hook SecretKeySpec (extract key material):
    var SecretKeySpec = Java.use('javax.crypto.spec.SecretKeySpec');
    SecretKeySpec.$init.overload('[B', 'java.lang.String').implementation = function(key, algorithm) {
        console.log('[SecretKeySpec] algorithm: ' + algorithm);
        console.log('[SecretKeySpec] key (hex): ' + bytesToHex(key));
        return this.$init(key, algorithm);
    };

    // Hook MessageDigest (SHA/MD5):
    var MessageDigest = Java.use('java.security.MessageDigest');
    MessageDigest.digest.overload('[B').implementation = function(input) {
        console.log('[MessageDigest] input: ' + bytesToHex(input));
        var result = this.digest(input);
        console.log('[MessageDigest] hash: ' + bytesToHex(result));
        return result;
    };

    // Helper:
    function bytesToHex(bytes) {
        var hex = '';
        for (var i = 0; i < bytes.length; i++) {
            hex += ('0' + (bytes[i] & 0xff).toString(16)).slice(-2);
        }
        return hex;
    }
});
```

---

## Phase 6: SSL Pinning Bypass

```javascript
// Universal SSL pinning bypass:
Java.perform(function() {
    // TrustManager bypass:
    var X509TrustManager = Java.use('javax.net.ssl.X509TrustManager');
    var SSLContext = Java.use('javax.net.ssl.SSLContext');

    // Create loose TrustManager:
    var TrustManager = Java.registerClass({
        name: 'com.bypass.TrustManager',
        implements: [X509TrustManager],
        methods: {
            checkClientTrusted: function(chain, authType) {},
            checkServerTrusted: function(chain, authType) {},
            getAcceptedIssuers: function() { return []; }
        }
    });

    var TrustManagers = [TrustManager.$new()];
    var sslContext = SSLContext.getInstance('TLS');
    sslContext.init(null, TrustManagers, null);

    // OkHttp3 pinning bypass:
    try {
        var OkHttpClient = Java.use('okhttp3.OkHttpClient');
        var builder = OkHttpClient.Builder.$new();
        builder.sslSocketFactory(sslContext.getSocketFactory(), TrustManager.$new());
        builder.hostnameVerifier(Java.use('javax.net.ssl.HttpsURLConnection').getDefaultHostnameVerifier());
        console.log('[*] OkHttp SSL bypass applied');
    } catch(e) {}

    // HttpsURLConnection bypass:
    var HttpsURLConnection = Java.use('javax.net.ssl.HttpsURLConnection');
    HttpsURLConnection.setDefaultSSLSocketFactory(sslContext.getSocketFactory());

    console.log('[*] SSL pinning bypass loaded');
});
```

---

## Phase 7: Root Detection Bypass

```javascript
Java.perform(function() {
    // Common root detection methods:
    var methods_to_bypass = [
        ['com.scottyab.rootbeer.RootBeer', 'isRooted'],
        ['com.scottyab.rootbeer.RootBeer', 'detectRootManagementApps'],
        ['com.example.app.Utils', 'isDeviceRooted'],
        ['java.io.File', 'exists'],   // careful — very broad
    ];

    methods_to_bypass.forEach(function(pair) {
        try {
            var cls = Java.use(pair[0]);
            cls[pair[1]].implementation = function() {
                console.log('[*] Bypassing ' + pair[0] + '.' + pair[1]);
                return false;
            };
        } catch(e) { /* class not loaded */ }
    });

    // Bypass su binary check:
    var Runtime = Java.use('java.lang.Runtime');
    Runtime.exec.overload('java.lang.String').implementation = function(cmd) {
        if (cmd.includes('su') || cmd.includes('which')) {
            console.log('[*] Blocked exec: ' + cmd);
            throw Java.use('java.io.IOException').$new('File not found');
        }
        return this.exec(cmd);
    };
});
```

---

## Phase 8: Frida Stalker (Code Tracing)

```javascript
// Trace all instructions executed (Stalker):
// Use for: find which branch is taken, trace flag-check loop

Stalker.follow(Process.getCurrentThreadId(), {
    events: {
        call: true,   // CALL instructions
        ret: true,    // RET instructions
        exec: false,  // every instruction (very verbose)
    },
    onReceive: function(events) {
        var list = Stalker.parse(events);
        list.forEach(function(event) {
            console.log(JSON.stringify(event));
        });
    }
});

// Trace specific thread during function call:
var targetFunc = Module.findExportByName(null, 'check_flag');
Interceptor.attach(targetFunc, {
    onEnter: function() {
        Stalker.follow(this.threadId, {
            events: { call: true, ret: true },
            onReceive: function(events) {
                console.log(Stalker.parse(events));
            }
        });
    },
    onLeave: function() {
        Stalker.unfollow(this.threadId);
    }
});
```

---

## Phase 9: CLI Usage — frida-trace

```bash
# Auto-generate hooks for functions matching pattern:
frida-trace -U -n com.example.app -i "Java_*check*"   # native JNI funcs
frida-trace -U -n com.example.app -j '*!check*'        # Java methods
frida-trace -U -n com.example.app -j 'com.example.app.MainActivity!*'  # all methods

# Trace libc functions:
frida-trace -U -n com.example.app -i "strcmp" -i "strncmp" -i "memcmp"

# Output: generated JS handlers in __handlers__/ — edit to customize
# Default: logs function name + args
```

---

## Pro Tips

1. **Always hook `strcmp`/`memcmp`** — catches 80% of CTF flag checks instantly
2. **`Java.use` + `.implementation`** = override any Java method; `.overload()` for overloaded methods
3. **SSL pinning bypass** — load before app makes first HTTPS request; use `--no-pause` for spawned apps
4. **Frida-trace generates stubs** automatically — edit `__handlers__/` files to customize output
5. **`Module.findBaseAddress`** → add offset from `r2/objdump` → hook private functions
6. **Memory.readUtf8String** can crash on bad pointers — always wrap in `try/catch`
7. **Stalker** = slowest but most complete; use only for specific function tracing, not global

## Summary

Frida flow: `frida-ps -U` → find process → write `hook.js` → `Java.perform()` for Android Java, `Interceptor.attach()` for native → hook `strcmp`/crypto APIs → run `frida -U -n app -l hook.js` → observe intercepted args/return values → extract secrets or bypass checks.
