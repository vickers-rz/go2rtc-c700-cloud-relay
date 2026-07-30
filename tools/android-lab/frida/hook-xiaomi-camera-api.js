/*
 * Runtime probes for Xiaomi Home camera history and PTZ research.
 *
 * The script avoids dumping cookies/tokens. It is meant to be attached while
 * manually opening the C700 camera page, entering microSD history, downloading
 * one minute, and pressing PTZ direction controls.
 */

'use strict';

const TAG = '[xiaomi-camera-api]';

const TARGET_METHODS = [
  'callSmartHomeCameraAPI',
  'downloadM3U8ToMP4V2',
  'cancelDownloadM3U8ToMP4V2',
  'getVideoFileUrl',
  'sendP2PCommandToDevice',
  'sendP2PCommandToDeviceWithBase64Param',
  'bindP2PCommandReceiveCallback',
  'doAction',
  'setProperties',
  'getProperties',
  'callMethod',
];

const TARGET_TEXT = [
  'eventlist',
  'fileIdMetas',
  'M3U8',
  'M3U8ToMP4',
  'mp4',
  'MP4',
  'MHCameraSDK',
  'MISS_CMD_PLAYBACK',
  'MISS_CMD_MOTOR',
  'MOTOR_REQ',
  'PLAYBACK_REQ',
  'business.smartcamera',
  'rtmj:',
  '1144207113',
  'VIDEO_',
];

const HOOKED_METHOD_KEYS = {};

function now() {
  return new Date().toISOString();
}

function redactString(value) {
  if (value === null || value === undefined) return value;
  let s = String(value);
  s = s.replace(/(serviceToken|passToken|ssecurity|nonce|cUserId|userId|auth|authorization|token|cookie|rc4_hash__)=([^&\s,"'}]+)/ig, '$1=<redacted>');
  s = s.replace(/("(?:serviceToken|passToken|ssecurity|nonce|cUserId|userId|auth|authorization|token|cookie|rc4_hash__)"\s*:\s*")([^"]+)(")/ig, '$1<redacted>$3');
  if (s.length > 1200) s = s.slice(0, 1200) + '...<truncated>';
  return s;
}

function safeValue(value) {
  try {
    if (value === null || value === undefined) return value;
    const type = typeof value;
    if (type === 'string' || type === 'number' || type === 'boolean') return redactString(value);
    return redactString(value.toString());
  } catch (e) {
    return '<unprintable>';
  }
}

function log(event, payload) {
  try {
    console.log(TAG + ' ' + JSON.stringify({ ts: now(), event: event, data: payload }));
  } catch (e) {
    console.log(TAG + ' ' + event + ' ' + redactString(String(payload)));
  }
}

function interesting(values) {
  const joined = values.map(function (v) { return safeValue(v); }).join(' ');
  return TARGET_TEXT.some(function (needle) {
    return joined.indexOf(needle) !== -1;
  });
}

function overloadSignature(overload) {
  return overload.argumentTypes.map(function (t) { return t.className; }).join(', ');
}

function hookMethod(className, methodName) {
  const key = className + '#' + methodName;
  if (HOOKED_METHOD_KEYS[key]) return false;

  let klass;
  try {
    klass = Java.use(className);
  } catch (e) {
    return false;
  }

  if (!klass[methodName] || !klass[methodName].overloads) return false;

  klass[methodName].overloads.forEach(function (overload) {
    const sig = overloadSignature(overload);
    const original = overload;
    original.implementation = function () {
      const args = [];
      for (let i = 0; i < arguments.length; i++) args.push(safeValue(arguments[i]));

      const shouldLog = methodName === 'callSmartHomeCameraAPI' ||
        methodName === 'downloadM3U8ToMP4V2' ||
        methodName === 'getVideoFileUrl' ||
        methodName === 'sendP2PCommandToDevice' ||
        methodName === 'sendP2PCommandToDeviceWithBase64Param' ||
        methodName === 'doAction' ||
        interesting(args);

      if (shouldLog) log('call', { className: className, methodName: methodName, signature: sig, args: args });

      try {
        const ret = original.apply(this, arguments);
        if (shouldLog) log('return', { className: className, methodName: methodName, value: safeValue(ret) });
        return ret;
      } catch (e) {
        log('throw', { className: className, methodName: methodName, error: safeValue(e) });
        throw e;
      }
    };
  });

  HOOKED_METHOD_KEYS[key] = true;
  log('hooked-method', { className: className, methodName: methodName, overloads: klass[methodName].overloads.length });
  return true;
}

function discoverAndHookBridgeMethods() {
  const classes = Java.enumerateLoadedClassesSync();
  let hooked = 0;

  classes.forEach(function (className) {
    const lower = className.toLowerCase();
    if (
      lower.indexOf('miot') === -1 &&
      lower.indexOf('camera') === -1 &&
      lower.indexOf('smarthome') === -1 &&
      lower.indexOf('react') === -1 &&
      lower.indexOf('bridge') === -1
    ) {
      return;
    }

    let klass;
    try {
      klass = Java.use(className);
      const declared = klass.class.getDeclaredMethods();
      for (let i = 0; i < declared.length; i++) {
        const text = declared[i].toString();
        TARGET_METHODS.forEach(function (methodName) {
          if (text.indexOf(methodName + '(') !== -1) {
            if (hookMethod(className, methodName)) hooked += 1;
          }
        });
      }
    } catch (e) {
      return;
    }
  });

  log('discovery-complete', { hookedMethods: hooked });
}

function hookFileWrites() {
  try {
    const FileOutputStream = Java.use('java.io.FileOutputStream');
    FileOutputStream.$init.overloads.forEach(function (overload) {
      const original = overload;
      original.implementation = function () {
        const args = [];
        for (let i = 0; i < arguments.length; i++) args.push(safeValue(arguments[i]));
        if (interesting(args) || args.join(' ').indexOf('.mp4') !== -1 || args.join(' ').indexOf('sdVideo') !== -1) {
          log('file-output-stream', { signature: overloadSignature(original), args: args });
        }
        return original.apply(this, arguments);
      };
    });
    log('hooked-file-output-stream', {});
  } catch (e) {
    log('hook-file-output-stream-failed', { error: safeValue(e) });
  }

  try {
    const File = Java.use('java.io.File');
    hookMethod('java.io.File', 'renameTo');
    File.$init.overloads.forEach(function (overload) {
      const original = overload;
      original.implementation = function () {
        const args = [];
        for (let i = 0; i < arguments.length; i++) args.push(safeValue(arguments[i]));
        if (interesting(args) || args.join(' ').indexOf('.mp4') !== -1 || args.join(' ').indexOf('sdVideo') !== -1) {
          log('file-init', { signature: overloadSignature(original), args: args });
        }
        return original.apply(this, arguments);
      };
    });
    log('hooked-file-init', {});
  } catch (e) {
    log('hook-file-init-failed', { error: safeValue(e) });
  }
}

function readableArrayToJson(value) {
  try {
    if (value === null || value === undefined) return value;
    if (!value.toArrayList) return safeValue(value);
    return safeValue(value.toArrayList().toString());
  } catch (e) {
    return safeValue(value);
  }
}

function hookReactNativeBridge() {
  try {
    const JavaMethodWrapper = Java.use('com.facebook.react.bridge.JavaMethodWrapper');
    const invoke = JavaMethodWrapper.invoke.overload('com.facebook.react.bridge.JSInstance', 'com.facebook.react.bridge.ReadableArray');
    invoke.implementation = function (jsInstance, params) {
      const methodText = safeValue(this.toString());
      const argsText = readableArrayToJson(params);
      if (interesting([methodText, argsText])) {
        log('rn-java-method-invoke', { method: methodText, args: argsText });
      }
      return invoke.call(this, jsInstance, params);
    };
    log('hooked-rn-java-method-wrapper', {});
  } catch (e) {
    log('hook-rn-java-method-wrapper-failed', { error: safeValue(e) });
  }

  try {
    const CatalystInstanceImpl = Java.use('com.facebook.react.bridge.CatalystInstanceImpl');
    CatalystInstanceImpl.callFunction.overloads.forEach(function (overload) {
      const original = overload;
      original.implementation = function () {
        const args = [];
        for (let i = 0; i < arguments.length; i++) args.push(safeValue(arguments[i]));
        if (interesting(args)) log('rn-call-function', { signature: overloadSignature(original), args: args });
        return original.apply(this, arguments);
      };
    });
    log('hooked-rn-catalyst-call-function', {});
  } catch (e) {
    log('hook-rn-catalyst-call-function-failed', { error: safeValue(e) });
  }

  try {
    const ReadableNativeArray = Java.use('com.facebook.react.bridge.ReadableNativeArray');
    const toString = ReadableNativeArray.toString.overload();
    toString.implementation = function () {
      const ret = toString.call(this);
      if (interesting([ret])) log('rn-readable-array', { value: safeValue(ret) });
      return ret;
    };
    log('hooked-rn-readable-array', {});
  } catch (e) {
    log('hook-rn-readable-array-failed', { error: safeValue(e) });
  }
}

function hookMediaAndContentWrites() {
  try {
    const MediaMuxer = Java.use('android.media.MediaMuxer');
    MediaMuxer.$init.overloads.forEach(function (overload) {
      const original = overload;
      original.implementation = function () {
        const args = [];
        for (let i = 0; i < arguments.length; i++) args.push(safeValue(arguments[i]));
        log('media-muxer-init', { signature: overloadSignature(original), args: args });
        return original.apply(this, arguments);
      };
    });

    ['start', 'stop', 'release'].forEach(function (methodName) {
      if (!MediaMuxer[methodName]) return;
      const original = MediaMuxer[methodName].overload();
      original.implementation = function () {
        log('media-muxer-' + methodName, {});
        return original.call(this);
      };
    });
    log('hooked-media-muxer', {});
  } catch (e) {
    log('hook-media-muxer-failed', { error: safeValue(e) });
  }

  try {
    const ContentResolver = Java.use('android.content.ContentResolver');
    ContentResolver.openOutputStream.overloads.forEach(function (overload) {
      const original = overload;
      original.implementation = function () {
        const args = [];
        for (let i = 0; i < arguments.length; i++) args.push(safeValue(arguments[i]));
        if (interesting(args) || args.join(' ').indexOf('media') !== -1) {
          log('content-open-output-stream', { signature: overloadSignature(original), args: args });
        }
        return original.apply(this, arguments);
      };
    });
    log('hooked-content-open-output-stream', {});
  } catch (e) {
    log('hook-content-open-output-stream-failed', { error: safeValue(e) });
  }
}

function hookOkHttp() {
  try {
    const RealCall = Java.use('okhttp3.RealCall');
    const execute = RealCall.execute.overload();
    execute.implementation = function () {
      const req = this.request();
      const url = safeValue(req.url().toString());
      if (interesting([url])) log('okhttp-execute', { url: url, method: safeValue(req.method()) });
      return execute.call(this);
    };
    const enqueue = RealCall.enqueue.overload('okhttp3.Callback');
    enqueue.implementation = function (cb) {
      const req = this.request();
      const url = safeValue(req.url().toString());
      if (interesting([url])) log('okhttp-enqueue', { url: url, method: safeValue(req.method()) });
      return enqueue.call(this, cb);
    };
    log('hooked-okhttp-realcall', {});
  } catch (e) {
    log('hook-okhttp-failed', { error: safeValue(e) });
  }
}

Java.perform(function () {
  log('script-loaded', {});
  hookFileWrites();
  hookMediaAndContentWrites();
  hookReactNativeBridge();
  hookOkHttp();
  discoverAndHookBridgeMethods();

  setInterval(function () {
    try {
      discoverAndHookBridgeMethods();
    } catch (e) {
      log('rediscovery-failed', { error: safeValue(e) });
    }
  }, 5000);
});
