// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

const String kAdSenseViewType = 'adsense-banner';

bool _registered = false;

void registerAdSenseViewFactory(String publisherId, String adSlot) {
  if (_registered) return;
  _registered = true;
  ui_web.platformViewRegistry.registerViewFactory(
    kAdSenseViewType,
    (int viewId) {
      final ins = html.document.createElement('ins')
        ..className = 'adsbygoogle'
        ..style.cssText = 'display:block;width:100%;height:100%;';
      ins
        ..setAttribute('data-ad-client', publisherId)
        ..setAttribute('data-ad-slot', adSlot)
        ..setAttribute('data-ad-format', 'auto')
        ..setAttribute('data-full-width-responsive', 'true');
      return ins;
    },
  );
}
