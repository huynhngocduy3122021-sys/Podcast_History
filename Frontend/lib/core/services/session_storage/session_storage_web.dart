// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class SessionStorage {
  static String? getItem(String key) => html.window.localStorage[key];
  static void setItem(String key, String value) {
    html.window.localStorage[key] = value;
  }
  static void removeItem(String key) {
    html.window.localStorage.remove(key);
  }
}
