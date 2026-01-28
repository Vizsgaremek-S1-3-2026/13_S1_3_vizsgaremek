// lib/utils/web_protections_web.dart
import 'dart:js' as js;

class WebProtections {
  static void setup(void Function() onCheatDetected) {
    // Expose Dart function to JS with allowInterop for safety
    js.context['flutterTriggerAntiCheat'] = js.allowInterop(onCheatDetected);

    // Inject JS protection logic
    js.context.callMethod('eval', [
      """
      (function() {
        // 1. Disable Right-Click
        document.addEventListener('contextmenu', function(e) {
          e.preventDefault();
        }, false);

        // 2. Disable Selection and Copy/Paste
        document.onselectstart = function() { return false; };
        document.oncopy = function() { return false; };
        document.onpaste = function() { return false; };
        
        // 3. Detect DevTools Shortcuts and Block System Shortcuts
        document.addEventListener('keydown', function(e) {
          // F12 - DevTools
          if (e.keyCode == 123) {
            window.flutterTriggerAntiCheat();
            e.preventDefault();
            return false;
          }
          // Ctrl+Shift+I/J/C - DevTools
          if (e.ctrlKey && e.shiftKey && (e.keyCode == 73 || e.keyCode == 74 || e.keyCode == 67)) {
            window.flutterTriggerAntiCheat();
            e.preventDefault();
            return false;
          }
          // Ctrl+U (Source)
          if (e.ctrlKey && e.keyCode == 85) {
            window.flutterTriggerAntiCheat();
            e.preventDefault();
            return false;
          }
          
          // === NEW: Block common escape shortcuts ===
          
          // Alt+Tab (partial - triggers but we detect the blur)
          if (e.altKey && e.keyCode == 9) {
            e.preventDefault();
            return false;
          }
          
          // Ctrl+Tab / Ctrl+Shift+Tab (switch browser tabs)
          if (e.ctrlKey && e.keyCode == 9) {
            e.preventDefault();
            return false;
          }
          
          // Alt+F4 (close window)
          if (e.altKey && e.keyCode == 115) {
            e.preventDefault();
            return false;
          }
          
          // Ctrl+W (close tab)
          if (e.ctrlKey && e.keyCode == 87) {
            e.preventDefault();
            return false;
          }
          
          // Ctrl+N (new window)
          if (e.ctrlKey && e.keyCode == 78) {
            e.preventDefault();
            return false;
          }
          
          // Ctrl+T (new tab)
          if (e.ctrlKey && e.keyCode == 84) {
            e.preventDefault();
            return false;
          }
          
          // F5 / Ctrl+R (refresh)
          if (e.keyCode == 116 || (e.ctrlKey && e.keyCode == 82)) {
            e.preventDefault();
            return false;
          }
          
          // Escape (exit fullscreen - detect and warn)
          if (e.keyCode == 27) {
            // Let it through but the fullscreen change listener will catch it
          }
          
          // Meta/Win key combinations (limited browser support)
          if (e.metaKey) {
            e.preventDefault();
            return false;
          }
        }, true); // Use capture phase for higher priority

        // 4. Detect Fullscreen Exit (Robust)
        var fsEvents = ['fullscreenchange', 'webkitfullscreenchange', 'mozfullscreenchange', 'MSFullscreenChange'];
        fsEvents.forEach(function(eventName) {
          document.addEventListener(eventName, function() {
            var isInFullScreen = document.fullscreenElement || 
                                 document.webkitFullscreenElement || 
                                 document.mozFullScreenElement || 
                                 document.msFullscreenElement;
            if (!isInFullScreen) {
              window.flutterTriggerAntiCheat();
            }
          }, false);
        });

        // 5. Before Unload Warning
        window.onbeforeunload = function() {
          return "Biztosan elhagyod a tesztet? A folyamat megállhat.";
        };
        
        // 6. Blur detection (Alt+Tab, clicking outside)
        window.addEventListener('blur', function() {
          if (document.visibilityState !== 'hidden') {
            // Window lost focus but page still visible - possible Alt+Tab
            window.flutterTriggerAntiCheat();
          }
        });
        
        // 7. Visibility change detection (tab switch)
        document.addEventListener('visibilitychange', function() {
          if (document.hidden) {
            window.flutterTriggerAntiCheat();
          }
        });
        
        // === NEW: 8. Block Screen Sharing ===
        if (navigator.mediaDevices && navigator.mediaDevices.getDisplayMedia) {
          var originalGetDisplayMedia = navigator.mediaDevices.getDisplayMedia.bind(navigator.mediaDevices);
          navigator.mediaDevices.getDisplayMedia = function(constraints) {
            // Trigger anti-cheat when screen sharing is attempted
            if (window.flutterTriggerAntiCheat) {
              window.flutterTriggerAntiCheat();
            }
            // Reject the request with a permission denied error
            return Promise.reject(new DOMException('Screen sharing is disabled during test.', 'NotAllowedError'));
          };
        }
        
        // Also block getMediaDevices for screen capture
        if (navigator.mediaDevices && navigator.mediaDevices.getDisplayMedia) {
          // Override getUserMedia to block screen/display capture
          var originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
          navigator.mediaDevices.getUserMedia = function(constraints) {
            if (constraints && (constraints.video && constraints.video.displaySurface || 
                constraints.video && constraints.video.mediaSource === 'screen')) {
              if (window.flutterTriggerAntiCheat) {
                window.flutterTriggerAntiCheat();
              }
              return Promise.reject(new DOMException('Screen capture is disabled during test.', 'NotAllowedError'));
            }
            return originalGetUserMedia(constraints);
          };
        }
      })();
    """,
    ]);
  }

  static void enterFullScreen() {
    js.context.callMethod('eval', [
      """
      (function() {
        var el = document.documentElement;
        var requestMethod = el.requestFullScreen || el.webkitRequestFullScreen || el.mozRequestFullScreen || el.msRequestFullScreen;
        if (requestMethod) {
          requestMethod.call(el);
        }
      })();
      """,
    ]);
  }

  static void exitFullScreen() {
    js.context.callMethod('eval', [
      """
      (function() {
        var el = document;
        var requestMethod = el.exitFullscreen || el.webkitExitFullscreen || el.mozExitFullscreen || el.msExitFullscreen;
        if (requestMethod) {
          requestMethod.call(el);
        }
      })();
      """,
    ]);
  }
}
