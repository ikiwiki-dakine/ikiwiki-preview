- Using a separate Firefox profile:
  - Profile Manager <http://kb.mozillazine.org/Profile_Manager>
  - Profilist plugin: <https://addons.mozilla.org/en-US/firefox/addon/profilist/>
- Security features to disable:
  - disable CSP: <http://stackoverflow.com/questions/27323631/how-to-override-content-security-policy-while-including-script-in-browser-js-con>
  - xframe options: <https://stackoverflow.com/questions/12881789/disable-x-frame-option-on-client-side>


See addon:
- <https://addons.mozilla.org/en-US/firefox/addon/ignore-x-frame-options-header/>.
  Make sure to use <https://addons.mozilla.org/en-US/firefox/addon/crxviewer/>
  to check that the source code of the extension matches
  <https://github.com/ThomazPom/Moz-Ext-Ignore-X-Frame-Options/blob/3aca6f43e808604475a4abea5a5c28c87ce6c807/background.js>.
  Once installed, disable automatic updates.
