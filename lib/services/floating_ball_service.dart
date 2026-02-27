import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FloatingBallService {
  static const MethodChannel _channel =
      MethodChannel('com.example.connect/floating_ball');

  static const String _keyEnabled = 'floating_ball_enabled';
  static const String _keySelectedAppsJson = 'floating_ball_selected_apps_json';
  static const String _keyBallColor = 'floating_ball_color';
  static const String _keyBallIcon = 'floating_ball_icon';
  static const String _keyBallIconPngBase64 = 'floating_ball_icon_png_base64';
  static const String _keyBallIconColor = 'floating_ball_ball_icon_color';
  static const String _keyBallIconSizeDp = 'floating_ball_ball_icon_size_dp';
  static const String _keyBallSizeDp = 'floating_ball_ball_size_dp';
  static const String _keyFullScreen = 'floating_ball_fullscreen';
  static const String _keyFullScreenBgColor = 'floating_ball_fs_bg_color';
  static const String _keyFullScreenButtonColor = 'floating_ball_fs_button_color';
  static const String _keyFullScreenContentColor = 'floating_ball_fs_content_color';
  static const String _keyFullScreenIconColor = 'floating_ball_fs_icon_color';
  static const String _keyFullScreenTextColor = 'floating_ball_fs_text_color';
  static const String _keyFullScreenHideText = 'floating_ball_fs_hide_text';
  static const String _keyFullScreenIconSizeDp = 'floating_ball_fs_icon_size_dp';
  static const String _keyFullScreenTextSizeSp = 'floating_ball_fs_text_size_sp';
  static const String _keyFullScreenTileGapDp = 'floating_ball_fs_tile_gap_dp';
  static const String _keyFullScreenTilePaddingDp =
      'floating_ball_fs_tile_padding_dp';
  static const String _keyFullScreenStickyPaddingDp =
      'floating_ball_fs_sticky_padding_dp';
  static const String _keyFullScreenTileInnerGapDp =
      'floating_ball_fs_tile_inner_gap_dp';
  static const String _keyFullScreenTileHeightDp =
      'floating_ball_fs_tile_height_dp';
  static const String _keyFullScreenTileBorderColor =
      'floating_ball_fs_tile_border_color';
  static const String _keyFullScreenContainerPaddingHorzDp =
      'floating_ball_fs_container_padding_horz_dp';
  static const String _keyFullScreenContainerPaddingVertDp =
      'floating_ball_fs_container_padding_vert_dp';
  static const String _keyFullScreenAppsButtonColor =
      'floating_ball_fs_apps_button_color';
  static const String _keyFullScreenAppsTileGapDp =
      'floating_ball_fs_apps_tile_gap_dp';
  static const String _keyFullScreenAppsTileHeightDp =
      'floating_ball_fs_apps_tile_height_dp';
  static const String _keyFullScreenAppsTileBorderColor =
      'floating_ball_fs_apps_tile_border_color';
  static const String _keyFullScreenAppsIconSizeDp =
      'floating_ball_fs_apps_icon_size_dp';
  static const String _keyFullScreenSystemCols = 'floating_ball_fs_system_cols';
  static const String _keyFullScreenAppsCols = 'floating_ball_fs_apps_cols';
  static const String _keyFullScreenBarEnabled = 'floating_ball_fs_bar_enabled';
  static const String _keyFullScreenBarHeightDp =
      'floating_ball_fs_bar_height_dp';
  static const String _keyFullScreenBarBgColor = 'floating_ball_fs_bar_bg_color';
  static const String _keyFullScreenBarContentColor =
      'floating_ball_fs_bar_content_color';
  static const String _keyFullScreenBarIconSizeDp =
      'floating_ball_fs_bar_icon_size_dp';
  static const String _keyFullScreenBarTextSizeSp =
      'floating_ball_fs_bar_text_size_sp';
  static const String _keyFullScreenBarPaddingHorzDp =
      'floating_ball_fs_bar_padding_horz_dp';
  static const String _keyFullScreenBarPaddingVertDp =
      'floating_ball_fs_bar_padding_vert_dp';
  static const String _keyFullScreenBarWifiIconId =
      'floating_ball_fs_bar_wifi_icon_id';
  static const String _keyFullScreenBarWifiIconPngBase64 =
      'floating_ball_fs_bar_wifi_icon_png_base64';
  static const String _keyFullScreenBarBtIconId = 'floating_ball_fs_bar_bt_icon_id';
  static const String _keyFullScreenBarBtIconPngBase64 =
      'floating_ball_fs_bar_bt_icon_png_base64';
  static const String _keyFullScreenBarDataIconId =
      'floating_ball_fs_bar_data_icon_id';
  static const String _keyFullScreenBarDataIconPngBase64 =
      'floating_ball_fs_bar_data_icon_png_base64';
  static const String _keyFullScreenBarLocIconId = 'floating_ball_fs_bar_loc_icon_id';
  static const String _keyFullScreenBarLocIconPngBase64 =
      'floating_ball_fs_bar_loc_icon_png_base64';
  static const String _keyFullScreenBarBatteryIconId =
      'floating_ball_fs_bar_battery_icon_id';
  static const String _keyFullScreenBarBatteryIconPngBase64 =
      'floating_ball_fs_bar_battery_icon_png_base64';
  static const String _keyFullScreenBarMediaRestoreIconId =
      'floating_ball_fs_bar_media_restore_icon_id';
  static const String _keyFullScreenBarMediaRestoreIconPngBase64 =
      'floating_ball_fs_bar_media_restore_icon_png_base64';
  static const String _keyFullScreenBarTimeColor = 'floating_ball_fs_bar_time_color';
  static const String _keyFullScreenBarWifiIconColor =
      'floating_ball_fs_bar_wifi_icon_color';
  static const String _keyFullScreenBarBtIconColor =
      'floating_ball_fs_bar_bt_icon_color';
  static const String _keyFullScreenBarDataIconColor =
      'floating_ball_fs_bar_data_icon_color';
  static const String _keyFullScreenBarLocIconColor =
      'floating_ball_fs_bar_loc_icon_color';
  static const String _keyFullScreenBarBatteryIconColor =
      'floating_ball_fs_bar_battery_icon_color';
  static const String _keyFullScreenBarBatteryTextColor =
      'floating_ball_fs_bar_battery_text_color';
  static const String _keyFullScreenBarRestoreIconColor =
      'floating_ball_fs_bar_restore_icon_color';
  static const String _keyFullScreenBarRestoreBgColor =
      'floating_ball_fs_bar_restore_bg_color';
  static const String _keyFullScreenCustomNotificationsEnabled =
      'floating_ball_fs_custom_notifications_enabled';
  static const String _keyCustomNotificationsBgColor =
      'floating_ball_custom_notifications_bg_color';
  static const String _keyCustomNotificationsItemBgColor =
      'floating_ball_custom_notifications_item_bg_color';
  static const String _keyCustomNotificationsItemBorderColor =
      'floating_ball_custom_notifications_item_border_color';
  static const String _keyCustomNotificationsTitleColor =
      'floating_ball_custom_notifications_title_color';
  static const String _keyCustomNotificationsTextColor =
      'floating_ball_custom_notifications_text_color';
  static const String _keyCustomNotificationsTitleSizeSp =
      'floating_ball_custom_notifications_title_size_sp';
  static const String _keyCustomNotificationsTextSizeSp =
      'floating_ball_custom_notifications_text_size_sp';
  static const String _keyCustomNotificationsButtonsIconHeightDp =
      'floating_ball_custom_notifications_buttons_icon_height_dp';
  static const String _keyCustomNotificationsDeleteIconId =
      'floating_ball_custom_notifications_delete_icon_id';
  static const String _keyCustomNotificationsDeleteIconPngBase64 =
      'floating_ball_custom_notifications_delete_icon_png_base64';
  static const String _keyCustomNotificationsDeleteText =
      'floating_ball_custom_notifications_delete_text';
  static const String _keyCustomNotificationsButtonsHideText =
      'floating_ball_custom_notifications_buttons_hide_text';
  static const String _keyCustomNotificationsButtonsHeightDp =
      'floating_ball_custom_notifications_buttons_height_dp';
  static const String _keyCustomNotificationsButtonsBgColor =
      'floating_ball_custom_notifications_buttons_bg_color';
  static const String _keyCustomNotificationsButtonsBorderColor =
      'floating_ball_custom_notifications_buttons_border_color';
  static const String _keyCustomNotificationsButtonsContentColor =
      'floating_ball_custom_notifications_buttons_content_color';
  static const String _keyCustomNotificationsCloseIconId =
      'floating_ball_custom_notifications_close_icon_id';
  static const String _keyCustomNotificationsCloseIconPngBase64 =
      'floating_ball_custom_notifications_close_icon_png_base64';
  static const String _keyCustomNotificationsCloseText =
      'floating_ball_custom_notifications_close_text';
  static const String _keyCustomNotificationsClearAllIconId =
      'floating_ball_custom_notifications_clear_all_icon_id';
  static const String _keyCustomNotificationsClearAllIconPngBase64 =
      'floating_ball_custom_notifications_clear_all_icon_png_base64';
  static const String _keyCustomNotificationsClearAllText =
      'floating_ball_custom_notifications_clear_all_text';
  static const String _keyFullScreenMediaAutoShow =
      'floating_ball_fs_media_auto_show';
  static const String _keyFullScreenCloseHeightDp =
      'floating_ball_fs_close_height_dp';
  static const String _keyFullScreenCloseBgColor =
      'floating_ball_fs_close_bg_color';
  static const String _keyFullScreenCloseTextColor =
      'floating_ball_fs_close_text_color';
  static const String _keyFullScreenCloseHideText =
      'floating_ball_fs_close_hide_text';
  static const String _keyFullScreenCloseIconId =
      'floating_ball_fs_close_icon_id';
  static const String _keyFullScreenCloseIconPngBase64 =
      'floating_ball_fs_close_icon_png_base64';
  static const String _keyFullScreenCloseSticky =
      'floating_ball_fs_close_sticky';
  static const String _keyFullScreenCloseDisableStickyWhenMediaActive =
      'floating_ball_fs_close_disable_sticky_when_media_active';
  static const String _keyFullScreenCloseText = 'floating_ball_fs_close_text';
  static const String _keyFullScreenBackText = 'floating_ball_fs_back_text';
  static const String _keyFullScreenHomeText = 'floating_ball_fs_home_text';
  static const String _keyFullScreenRecentsText =
      'floating_ball_fs_recents_text';
  static const String _keyFullScreenVolumeText = 'floating_ball_fs_volume_text';
  static const String _keyFullScreenSettingsText =
      'floating_ball_fs_settings_text';
  static const String _keyFullScreenBrightnessText =
      'floating_ball_fs_brightness_text';

  static const String _keyPopupBgColor = 'floating_ball_popup_bg_color';
  static const String _keyPopupButtonColor = 'floating_ball_popup_button_color';
  static const String _keyPopupIconColor = 'floating_ball_popup_icon_color';
  static const String _keyPopupIconSizeDp = 'floating_ball_popup_icon_size_dp';
  static const String _keyPopupOffsetXDp = 'floating_ball_popup_offset_x_dp';
  static const String _keyPopupOffsetYDp = 'floating_ball_popup_offset_y_dp';
  static const String _keyPopupMediaOffsetXDp = 'floating_ball_popup_media_offset_x_dp';
  static const String _keyPopupMediaOffsetYDp = 'floating_ball_popup_media_offset_y_dp';
  static const String _keyPopupBackIconId = 'floating_ball_popup_back_icon_id';
  static const String _keyPopupHomeIconId = 'floating_ball_popup_home_icon_id';
  static const String _keyPopupRecentsIconId = 'floating_ball_popup_recents_icon_id';
  static const String _keyPopupVolumeIconId = 'floating_ball_popup_volume_icon_id';
  static const String _keyPopupBrightnessIconId =
      'floating_ball_popup_brightness_icon_id';
  static const String _keyPopupSettingsIconId =
      'floating_ball_popup_settings_icon_id';
  static const String _keyPopupBackIconPngBase64 =
      'floating_ball_popup_back_icon_png_base64';
  static const String _keyPopupHomeIconPngBase64 =
      'floating_ball_popup_home_icon_png_base64';
  static const String _keyPopupRecentsIconPngBase64 =
      'floating_ball_popup_recents_icon_png_base64';
  static const String _keyPopupVolumeIconPngBase64 =
      'floating_ball_popup_volume_icon_png_base64';
  static const String _keyPopupBrightnessIconPngBase64 =
      'floating_ball_popup_brightness_icon_png_base64';
  static const String _keyPopupSettingsIconPngBase64 =
      'floating_ball_popup_settings_icon_png_base64';

  static const String _keyMediaHeightDp = 'floating_ball_media_height_dp';
  static const String _keyMediaIconSizeDp = 'floating_ball_media_icon_size_dp';
  static const String _keyMediaTitleSizeSp = 'floating_ball_media_title_size_sp';
  static const String _keyMediaSubtitleSizeSp =
      'floating_ball_media_subtitle_size_sp';
  static const String _keyMediaVolumeIconId = 'floating_ball_media_volume_icon_id';
  static const String _keyMediaPrevIconId = 'floating_ball_media_prev_icon_id';
  static const String _keyMediaPlayIconId = 'floating_ball_media_play_icon_id';
  static const String _keyMediaPauseIconId = 'floating_ball_media_pause_icon_id';
  static const String _keyMediaNextIconId = 'floating_ball_media_next_icon_id';
  static const String _keyMediaVolumeIconPngBase64 =
      'floating_ball_media_volume_icon_png_base64';
  static const String _keyMediaPrevIconPngBase64 =
      'floating_ball_media_prev_icon_png_base64';
  static const String _keyMediaPlayIconPngBase64 =
      'floating_ball_media_play_icon_png_base64';
  static const String _keyMediaPauseIconPngBase64 =
      'floating_ball_media_pause_icon_png_base64';
  static const String _keyMediaNextIconPngBase64 =
      'floating_ball_media_next_icon_png_base64';

  static const String _keyFullScreenBackIconId = 'floating_ball_fs_back_icon_id';
  static const String _keyFullScreenHomeIconId = 'floating_ball_fs_home_icon_id';
  static const String _keyFullScreenRecentsIconId =
      'floating_ball_fs_recents_icon_id';
  static const String _keyFullScreenVolumeIconId =
      'floating_ball_fs_volume_icon_id';
  static const String _keyFullScreenSettingsIconId =
      'floating_ball_fs_settings_icon_id';
  static const String _keyFullScreenBrightnessIconId =
      'floating_ball_fs_brightness_icon_id';
  static const String _keyFullScreenBackIconPngBase64 =
      'floating_ball_fs_back_icon_png_base64';
  static const String _keyFullScreenHomeIconPngBase64 =
      'floating_ball_fs_home_icon_png_base64';
  static const String _keyFullScreenRecentsIconPngBase64 =
      'floating_ball_fs_recents_icon_png_base64';
  static const String _keyFullScreenVolumeIconPngBase64 =
      'floating_ball_fs_volume_icon_png_base64';
  static const String _keyFullScreenSettingsIconPngBase64 =
      'floating_ball_fs_settings_icon_png_base64';
  static const String _keyFullScreenBrightnessIconPngBase64 =
      'floating_ball_fs_brightness_icon_png_base64';

  static const String _keyFullScreenOrderJson = 'floating_ball_fs_order_json';
  static const String _keyFullScreenAppLabelsJson =
      'floating_ball_fs_app_labels_json';

  static const String _keyGesturesEnabled = 'floating_ball_gestures_enabled';
  static const String _keyGestureLongPressMs =
      'floating_ball_gesture_long_press_ms';
  static const String _keyGestureUpAction = 'floating_ball_gesture_up_action';
  static const String _keyGestureUpApp = 'floating_ball_gesture_up_app';
  static const String _keyGestureRightAction =
      'floating_ball_gesture_right_action';
  static const String _keyGestureRightApp = 'floating_ball_gesture_right_app';
  static const String _keyGestureDownAction =
      'floating_ball_gesture_down_action';
  static const String _keyGestureDownApp = 'floating_ball_gesture_down_app';
  static const String _keyGestureLeftAction = 'floating_ball_gesture_left_action';
  static const String _keyGestureLeftApp = 'floating_ball_gesture_left_app';
  static const String _keyGestureVibrationMs =
      'floating_ball_gesture_vibration_ms';
  static const String _keyGestureVibrationAmplitude =
      'floating_ball_gesture_vibration_amplitude';
  static const String _keyGestureNotificationsUseCustomScreen =
      'floating_ball_gesture_notifications_use_custom_screen';

  static const int _defaultBallColor = 0xCC000000;
  static const String _defaultBallIcon = 'info';
  static const int _defaultBallIconColor = 0xFFFFFFFF;
  static const int _defaultBallIconSizeDp = 28;
  static const int _defaultBallSizeDp = 56;
  static const bool _defaultFullScreen = true;
  static const bool _defaultGesturesEnabled = false;
  static const int _defaultGestureLongPressMs = 450;
  static const String _defaultGestureUpAction = 'notifications';
  static const String _defaultGestureRightAction = 'home';
  static const String _defaultGestureDownAction = 'recents';
  static const String _defaultGestureLeftAction = 'back';
  static const int _defaultGestureVibrationMs = 35;
  static const int _defaultGestureVibrationAmplitude = 180;
  static const bool _defaultGestureNotificationsUseCustomScreen = false;
  static const int _defaultFullScreenBgColor = 0xDD111111;
  static const int _defaultFullScreenButtonColor = 0x22111111;
  static const int _defaultFullScreenContentColor = 0xFFFFFFFF;
  static const bool _defaultFullScreenHideText = false;
  static const int _defaultFullScreenIconSizeDp = 34;
  static const int _defaultFullScreenTextSizeSp = 14;
  static const int _defaultFullScreenTileGapDp = 10;
  static const int _defaultFullScreenTilePaddingDp = 0;
  static const int _defaultFullScreenStickyPaddingDp = 16;
  static const int _defaultFullScreenTileInnerGapDp = 10;
  static const int _defaultFullScreenTileHeightDp = 120;
  static const int _defaultFullScreenTileBorderColor = 0x22FFFFFF;
  static const int _defaultFullScreenContainerPaddingHorzDp = 16;
  static const int _defaultFullScreenContainerPaddingVertDp = 16;
  static const int _defaultFullScreenAppsButtonColor = _defaultFullScreenButtonColor;
  static const int _defaultFullScreenAppsTileGapDp = _defaultFullScreenTileGapDp;
  static const int _defaultFullScreenAppsTileHeightDp = _defaultFullScreenTileHeightDp;
  static const int _defaultFullScreenAppsTileBorderColor =
      _defaultFullScreenTileBorderColor;
  static const int _defaultFullScreenAppsIconSizeDp = _defaultFullScreenIconSizeDp;
  static const int _defaultFullScreenSystemCols = 1;
  static const int _defaultFullScreenAppsCols = 1;
  static const bool _defaultFullScreenBarEnabled = false;
  static const bool _defaultFullScreenCustomNotificationsEnabled = false;
  static const int _defaultCustomNotificationsBgColor = _defaultFullScreenBgColor;
  static const int _defaultCustomNotificationsItemBgColor =
      _defaultFullScreenButtonColor;
  static const int _defaultCustomNotificationsItemBorderColor =
      _defaultFullScreenTileBorderColor;
  static const int _defaultCustomNotificationsTitleColor = 0xFFFFFFFF;
  static const int _defaultCustomNotificationsTextColor = 0xFFFFFFFF;
  static const int _defaultCustomNotificationsTitleSizeSp = 16;
  static const int _defaultCustomNotificationsTextSizeSp = 14;
  static const int _defaultCustomNotificationsButtonsIconHeightDp = 34;
  static const String _defaultCustomNotificationsDeleteIconId = 'delete';
  static const String _defaultCustomNotificationsDeleteText = 'Eliminar';
  static const bool _defaultCustomNotificationsButtonsHideText = false;
  static const int _defaultCustomNotificationsButtonsHeightDp = 52;
  static const int _defaultCustomNotificationsButtonsBgColor = 0xFF202020;
  static const int _defaultCustomNotificationsButtonsBorderColor = 0x22FFFFFF;
  static const int _defaultCustomNotificationsButtonsContentColor = 0xFFFFFFFF;
  static const String _defaultCustomNotificationsCloseIconId = 'close';
  static const String _defaultCustomNotificationsCloseText = 'Cerrar';
  static const String _defaultCustomNotificationsClearAllIconId = 'delete';
  static const String _defaultCustomNotificationsClearAllText = 'Eliminar todo';
  static const int _defaultFullScreenBarHeightDp = 54;
  static const int _defaultFullScreenBarBgColor = 0xCC111111;
  static const int _defaultFullScreenBarContentColor = 0xFFFFFFFF;
  static const int _defaultFullScreenBarIconSizeDp = 18;
  static const int _defaultFullScreenBarTextSizeSp = 14;
  static const int _defaultFullScreenBarPaddingHorzDp = 16;
  static const int _defaultFullScreenBarPaddingVertDp = 0;
  static const String _defaultFullScreenBarWifiIconId = 'wifi';
  static const String _defaultFullScreenBarBtIconId = 'bluetooth';
  static const String _defaultFullScreenBarDataIconId = 'data';
  static const String _defaultFullScreenBarLocIconId = 'location';
  static const String _defaultFullScreenBarBatteryIconId = 'battery';
  static const String _defaultFullScreenBarMediaRestoreIconId = 'play';
  static const int _defaultFullScreenBarRestoreBgColor = 0x33FFFFFF;
  static const bool _defaultFullScreenMediaAutoShow = true;
  static const int _defaultFullScreenCloseHeightDp = 120;
  static const int _defaultFullScreenCloseBgColor = 0xFFDC2626;
  static const int _defaultFullScreenCloseTextColor = 0xFFFFFFFF;
  static const bool _defaultFullScreenCloseHideText = false;
  static const String _defaultFullScreenCloseIconId = 'close';
  static const bool _defaultFullScreenCloseSticky = false;
  static const bool _defaultFullScreenCloseDisableStickyWhenMediaActive = true;
  static const String _defaultFullScreenCloseText = 'Cerrar';
  static const String _defaultFullScreenBackText = 'Back';
  static const String _defaultFullScreenHomeText = 'Home';
  static const String _defaultFullScreenRecentsText = 'Recientes';
  static const String _defaultFullScreenVolumeText = 'Volumen';
  static const String _defaultFullScreenSettingsText = 'Ajustes';
  static const String _defaultFullScreenBrightnessText = 'Brillo';
  static const int _defaultPopupBgColor = _defaultFullScreenBgColor;
  static const int _defaultPopupButtonColor = _defaultFullScreenButtonColor;
  static const int _defaultPopupIconColor = _defaultFullScreenContentColor;
  static const int _defaultPopupIconSizeDp = 26;
  static const int _defaultPopupOffsetXDp = 0;
  static const int _defaultPopupOffsetYDp = 0;
  static const int _defaultPopupMediaOffsetXDp = 0;
  static const int _defaultPopupMediaOffsetYDp = 0;
  static const int _defaultMediaHeightDp = 320;
  static const int _defaultMediaIconSizeDp = 34;
  static const int _defaultMediaTitleSizeSp = 18;
  static const int _defaultMediaSubtitleSizeSp = 14;
  static const String _defaultMediaVolumeIconId = 'volume';
  static const String _defaultMediaPrevIconId = 'skip_prev';
  static const String _defaultMediaPlayIconId = 'play';
  static const String _defaultMediaPauseIconId = 'pause';
  static const String _defaultMediaNextIconId = 'skip_next';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<void> setEnabledTrue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, true);
  }

  static Future<void> setEnabledFalse() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    await _channel.invokeMethod('disable');
  }

  static Future<List<String>> getSelectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySelectedAppsJson);
    if (raw == null || raw.trim().isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> setSelectedApps(List<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = packages.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    cleaned.sort();
    await prefs.setString(_keySelectedAppsJson, jsonEncode(cleaned));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getBallColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBallColor) ?? _defaultBallColor;
  }

  static Future<void> setBallColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBallColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getBallIcon() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBallIcon) ?? _defaultBallIcon;
  }

  static Future<String?> getBallIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyBallIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setBallIconPngBase64(String? base64Png) async {
    final prefs = await SharedPreferences.getInstance();
    if (base64Png == null || base64Png.trim().isEmpty) {
      await prefs.remove(_keyBallIconPngBase64);
    } else {
      await prefs.setString(_keyBallIconPngBase64, base64Png);
    }
  }

  static Future<void> setBallIcon(String iconId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBallIcon, iconId);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<void> setBallIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBallIcon, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyBallIconPngBase64);
    } else {
      await prefs.setString(_keyBallIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getBallIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBallIconColor) ?? _defaultBallIconColor;
  }

  static Future<void> setBallIconColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBallIconColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getBallIconSizeDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyBallIconSizeDp) ?? _defaultBallIconSizeDp)
        .clamp(10, 56);
  }

  static Future<void> setBallIconSizeDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBallIconSizeDp, dp.clamp(10, 56));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getBallSizeDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyBallSizeDp) ?? _defaultBallSizeDp).clamp(36, 120);
  }

  static Future<void> setBallSizeDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBallSizeDp, dp.clamp(36, 120));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isFullScreenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullScreen) ?? _defaultFullScreen;
  }

  static Future<void> setFullScreenEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreen, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBgColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBgColor) ?? _defaultFullScreenBgColor;
  }

  static Future<void> setFullScreenBgColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBgColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenButtonColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenButtonColor) ?? _defaultFullScreenButtonColor;
  }

  static Future<void> setFullScreenButtonColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenButtonColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenContentColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenContentColor) ?? _defaultFullScreenContentColor;
  }

  static Future<void> setFullScreenContentColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenContentColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenIconColor) ??
        (prefs.getInt(_keyFullScreenContentColor) ?? _defaultFullScreenContentColor);
  }

  static Future<void> setFullScreenIconColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenIconColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenTextColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenTextColor) ??
        (prefs.getInt(_keyFullScreenContentColor) ?? _defaultFullScreenContentColor);
  }

  static Future<void> setFullScreenTextColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenTextColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isFullScreenHideTextEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullScreenHideText) ?? _defaultFullScreenHideText;
  }

  static Future<void> setFullScreenHideTextEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreenHideText, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenIconSizeDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenIconSizeDp) ?? _defaultFullScreenIconSizeDp)
        .clamp(10, 120);
  }

  static Future<void> setFullScreenIconSizeDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenIconSizeDp, dp.clamp(10, 120));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenTextSizeSp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenTextSizeSp) ?? _defaultFullScreenTextSizeSp)
        .clamp(8, 40);
  }

  static Future<void> setFullScreenTextSizeSp(int sp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenTextSizeSp, sp.clamp(8, 40));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenTileGapDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenTileGapDp) ?? _defaultFullScreenTileGapDp)
        .clamp(0, 40);
  }

  static Future<void> setFullScreenTileGapDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenTileGapDp, dp.clamp(0, 40));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenTilePaddingDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenTilePaddingDp) ?? _defaultFullScreenTilePaddingDp)
        .clamp(0, 40);
  }

  static Future<void> setFullScreenTilePaddingDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenTilePaddingDp, dp.clamp(0, 40));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenStickyPaddingDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenStickyPaddingDp) ??
            _defaultFullScreenStickyPaddingDp)
        .clamp(0, 40);
  }

  static Future<void> setFullScreenStickyPaddingDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenStickyPaddingDp, dp.clamp(0, 40));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenTileInnerGapDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenTileInnerGapDp) ??
            _defaultFullScreenTileInnerGapDp)
        .clamp(0, 40);
  }

  static Future<void> setFullScreenTileInnerGapDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenTileInnerGapDp, dp.clamp(0, 40));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenTileHeightDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenTileHeightDp) ??
            _defaultFullScreenTileHeightDp)
        .clamp(60, 300);
  }

  static Future<void> setFullScreenTileHeightDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenTileHeightDp, dp.clamp(60, 300));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenTileBorderColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenTileBorderColor) ??
        _defaultFullScreenTileBorderColor;
  }

  static Future<void> setFullScreenTileBorderColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenTileBorderColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenContainerPaddingHorzDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenContainerPaddingHorzDp) ??
            _defaultFullScreenContainerPaddingHorzDp)
        .clamp(0, 120);
  }

  static Future<void> setFullScreenContainerPaddingHorzDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenContainerPaddingHorzDp, dp.clamp(0, 120));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenContainerPaddingVertDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenContainerPaddingVertDp) ??
            _defaultFullScreenContainerPaddingVertDp)
        .clamp(0, 120);
  }

  static Future<void> setFullScreenContainerPaddingVertDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenContainerPaddingVertDp, dp.clamp(0, 120));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenAppsButtonColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenAppsButtonColor) ??
        (prefs.getInt(_keyFullScreenButtonColor) ??
            _defaultFullScreenAppsButtonColor);
  }

  static Future<void> setFullScreenAppsButtonColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenAppsButtonColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenAppsTileGapDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenAppsTileGapDp) ??
            (prefs.getInt(_keyFullScreenTileGapDp) ??
                _defaultFullScreenAppsTileGapDp))
        .clamp(0, 40);
  }

  static Future<void> setFullScreenAppsTileGapDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenAppsTileGapDp, dp.clamp(0, 40));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenAppsTileHeightDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenAppsTileHeightDp) ??
            (prefs.getInt(_keyFullScreenTileHeightDp) ??
                _defaultFullScreenAppsTileHeightDp))
        .clamp(60, 300);
  }

  static Future<void> setFullScreenAppsTileHeightDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenAppsTileHeightDp, dp.clamp(60, 300));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenAppsTileBorderColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenAppsTileBorderColor) ??
        (prefs.getInt(_keyFullScreenTileBorderColor) ??
            _defaultFullScreenAppsTileBorderColor);
  }

  static Future<void> setFullScreenAppsTileBorderColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenAppsTileBorderColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenAppsIconSizeDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenAppsIconSizeDp) ??
            (prefs.getInt(_keyFullScreenIconSizeDp) ??
                _defaultFullScreenAppsIconSizeDp))
        .clamp(10, 120);
  }

  static Future<void> setFullScreenAppsIconSizeDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenAppsIconSizeDp, dp.clamp(10, 120));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenSystemCols() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenSystemCols) ?? _defaultFullScreenSystemCols)
        .clamp(1, 4);
  }

  static Future<void> setFullScreenSystemCols(int cols) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenSystemCols, cols.clamp(1, 4));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenAppsCols() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenAppsCols) ?? _defaultFullScreenAppsCols)
        .clamp(1, 4);
  }

  static Future<void> setFullScreenAppsCols(int cols) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenAppsCols, cols.clamp(1, 4));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isFullScreenBarEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullScreenBarEnabled) ??
        _defaultFullScreenBarEnabled;
  }

  static Future<void> setFullScreenBarEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreenBarEnabled, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isFullScreenCustomNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullScreenCustomNotificationsEnabled) ??
        _defaultFullScreenCustomNotificationsEnabled;
  }

  static Future<void> setFullScreenCustomNotificationsEnabled(
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreenCustomNotificationsEnabled, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsBgColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCustomNotificationsBgColor) ??
        _defaultCustomNotificationsBgColor;
  }

  static Future<void> setCustomNotificationsBgColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsBgColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsItemBgColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCustomNotificationsItemBgColor) ??
        _defaultCustomNotificationsItemBgColor;
  }

  static Future<void> setCustomNotificationsItemBgColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsItemBgColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsItemBorderColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCustomNotificationsItemBorderColor) ??
        _defaultCustomNotificationsItemBorderColor;
  }

  static Future<void> setCustomNotificationsItemBorderColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsItemBorderColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsTitleColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCustomNotificationsTitleColor) ??
        _defaultCustomNotificationsTitleColor;
  }

  static Future<void> setCustomNotificationsTitleColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsTitleColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsTextColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCustomNotificationsTextColor) ??
        _defaultCustomNotificationsTextColor;
  }

  static Future<void> setCustomNotificationsTextColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsTextColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsTitleSizeSp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyCustomNotificationsTitleSizeSp) ??
            _defaultCustomNotificationsTitleSizeSp)
        .clamp(8, 32);
  }

  static Future<void> setCustomNotificationsTitleSizeSp(int sp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsTitleSizeSp, sp.clamp(8, 32));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsTextSizeSp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyCustomNotificationsTextSizeSp) ??
            _defaultCustomNotificationsTextSizeSp)
        .clamp(8, 32);
  }

  static Future<void> setCustomNotificationsTextSizeSp(int sp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsTextSizeSp, sp.clamp(8, 32));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsButtonsIconHeightDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyCustomNotificationsButtonsIconHeightDp) ??
            _defaultCustomNotificationsButtonsIconHeightDp)
        .clamp(18, 120);
  }

  static Future<void> setCustomNotificationsButtonsIconHeightDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyCustomNotificationsButtonsIconHeightDp,
      dp.clamp(18, 120),
    );
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getCustomNotificationsDeleteIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyCustomNotificationsDeleteIconId) ??
            _defaultCustomNotificationsDeleteIconId)
        .trim()
        .isEmpty
        ? _defaultCustomNotificationsDeleteIconId
        : (prefs.getString(_keyCustomNotificationsDeleteIconId) ??
                _defaultCustomNotificationsDeleteIconId)
            .trim();
  }

  static Future<String?> getCustomNotificationsDeleteIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomNotificationsDeleteIconPngBase64);
  }

  static Future<void> setCustomNotificationsDeleteIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomNotificationsDeleteIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyCustomNotificationsDeleteIconPngBase64);
    } else {
      await prefs.setString(_keyCustomNotificationsDeleteIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getCustomNotificationsDeleteText() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyCustomNotificationsDeleteText) ??
            _defaultCustomNotificationsDeleteText)
        .trim()
        .isEmpty
        ? _defaultCustomNotificationsDeleteText
        : (prefs.getString(_keyCustomNotificationsDeleteText) ??
                _defaultCustomNotificationsDeleteText)
            .trim();
  }

  static Future<void> setCustomNotificationsDeleteText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomNotificationsDeleteText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isCustomNotificationsButtonsHideTextEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCustomNotificationsButtonsHideText) ??
        _defaultCustomNotificationsButtonsHideText;
  }

  static Future<void> setCustomNotificationsButtonsHideTextEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCustomNotificationsButtonsHideText, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsButtonsHeightDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyCustomNotificationsButtonsHeightDp) ??
            _defaultCustomNotificationsButtonsHeightDp)
        .clamp(36, 160);
  }

  static Future<void> setCustomNotificationsButtonsHeightDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsButtonsHeightDp, dp.clamp(36, 160));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsButtonsBgColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCustomNotificationsButtonsBgColor) ??
        _defaultCustomNotificationsButtonsBgColor;
  }

  static Future<void> setCustomNotificationsButtonsBgColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsButtonsBgColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsButtonsBorderColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCustomNotificationsButtonsBorderColor) ??
        _defaultCustomNotificationsButtonsBorderColor;
  }

  static Future<void> setCustomNotificationsButtonsBorderColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsButtonsBorderColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getCustomNotificationsButtonsContentColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCustomNotificationsButtonsContentColor) ??
        _defaultCustomNotificationsButtonsContentColor;
  }

  static Future<void> setCustomNotificationsButtonsContentColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomNotificationsButtonsContentColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getCustomNotificationsCloseIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyCustomNotificationsCloseIconId) ??
            _defaultCustomNotificationsCloseIconId)
        .trim()
        .isEmpty
        ? _defaultCustomNotificationsCloseIconId
        : (prefs.getString(_keyCustomNotificationsCloseIconId) ??
                _defaultCustomNotificationsCloseIconId)
            .trim();
  }

  static Future<String?> getCustomNotificationsCloseIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomNotificationsCloseIconPngBase64);
  }

  static Future<void> setCustomNotificationsCloseIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomNotificationsCloseIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyCustomNotificationsCloseIconPngBase64);
    } else {
      await prefs.setString(_keyCustomNotificationsCloseIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getCustomNotificationsCloseText() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyCustomNotificationsCloseText) ??
            _defaultCustomNotificationsCloseText)
        .trim()
        .isEmpty
        ? _defaultCustomNotificationsCloseText
        : (prefs.getString(_keyCustomNotificationsCloseText) ??
                _defaultCustomNotificationsCloseText)
            .trim();
  }

  static Future<void> setCustomNotificationsCloseText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomNotificationsCloseText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getCustomNotificationsClearAllIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyCustomNotificationsClearAllIconId) ??
            _defaultCustomNotificationsClearAllIconId)
        .trim()
        .isEmpty
        ? _defaultCustomNotificationsClearAllIconId
        : (prefs.getString(_keyCustomNotificationsClearAllIconId) ??
                _defaultCustomNotificationsClearAllIconId)
            .trim();
  }

  static Future<String?> getCustomNotificationsClearAllIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomNotificationsClearAllIconPngBase64);
  }

  static Future<void> setCustomNotificationsClearAllIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomNotificationsClearAllIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyCustomNotificationsClearAllIconPngBase64);
    } else {
      await prefs.setString(_keyCustomNotificationsClearAllIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getCustomNotificationsClearAllText() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyCustomNotificationsClearAllText) ??
            _defaultCustomNotificationsClearAllText)
        .trim()
        .isEmpty
        ? _defaultCustomNotificationsClearAllText
        : (prefs.getString(_keyCustomNotificationsClearAllText) ??
                _defaultCustomNotificationsClearAllText)
            .trim();
  }

  static Future<void> setCustomNotificationsClearAllText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomNotificationsClearAllText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarHeightDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenBarHeightDp) ?? _defaultFullScreenBarHeightDp)
        .clamp(36, 160);
  }

  static Future<void> setFullScreenBarHeightDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarHeightDp, dp.clamp(36, 160));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarBgColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarBgColor) ?? _defaultFullScreenBarBgColor;
  }

  static Future<void> setFullScreenBarBgColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarBgColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarContentColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarContentColor) ??
        _defaultFullScreenBarContentColor;
  }

  static Future<void> setFullScreenBarContentColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarContentColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarIconSizeDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenBarIconSizeDp) ??
            _defaultFullScreenBarIconSizeDp)
        .clamp(10, 64);
  }

  static Future<void> setFullScreenBarIconSizeDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarIconSizeDp, dp.clamp(10, 64));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarTextSizeSp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenBarTextSizeSp) ??
            _defaultFullScreenBarTextSizeSp)
        .clamp(8, 32);
  }

  static Future<void> setFullScreenBarTextSizeSp(int sp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarTextSizeSp, sp.clamp(8, 32));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarPaddingHorzDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenBarPaddingHorzDp) ??
            _defaultFullScreenBarPaddingHorzDp)
        .clamp(0, 200);
  }

  static Future<void> setFullScreenBarPaddingHorzDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarPaddingHorzDp, dp.clamp(0, 200));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarPaddingVertDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenBarPaddingVertDp) ??
            _defaultFullScreenBarPaddingVertDp)
        .clamp(0, 30);
  }

  static Future<void> setFullScreenBarPaddingVertDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarPaddingVertDp, dp.clamp(0, 30));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarTimeColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarTimeColor) ??
        (prefs.getInt(_keyFullScreenBarContentColor) ??
            _defaultFullScreenBarContentColor);
  }

  static Future<void> setFullScreenBarTimeColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarTimeColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarWifiIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarWifiIconColor) ??
        (prefs.getInt(_keyFullScreenBarContentColor) ??
            _defaultFullScreenBarContentColor);
  }

  static Future<void> setFullScreenBarWifiIconColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarWifiIconColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarBtIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarBtIconColor) ??
        (prefs.getInt(_keyFullScreenBarContentColor) ??
            _defaultFullScreenBarContentColor);
  }

  static Future<void> setFullScreenBarBtIconColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarBtIconColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarDataIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarDataIconColor) ??
        (prefs.getInt(_keyFullScreenBarContentColor) ??
            _defaultFullScreenBarContentColor);
  }

  static Future<void> setFullScreenBarDataIconColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarDataIconColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarLocIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarLocIconColor) ??
        (prefs.getInt(_keyFullScreenBarContentColor) ??
            _defaultFullScreenBarContentColor);
  }

  static Future<void> setFullScreenBarLocIconColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarLocIconColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarBatteryIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarBatteryIconColor) ??
        (prefs.getInt(_keyFullScreenBarContentColor) ??
            _defaultFullScreenBarContentColor);
  }

  static Future<void> setFullScreenBarBatteryIconColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarBatteryIconColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarBatteryTextColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarBatteryTextColor) ??
        (prefs.getInt(_keyFullScreenBarContentColor) ??
            _defaultFullScreenBarContentColor);
  }

  static Future<void> setFullScreenBarBatteryTextColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarBatteryTextColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarRestoreIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarRestoreIconColor) ??
        (prefs.getInt(_keyFullScreenBarContentColor) ??
            _defaultFullScreenBarContentColor);
  }

  static Future<void> setFullScreenBarRestoreIconColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarRestoreIconColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenBarRestoreBgColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenBarRestoreBgColor) ??
        _defaultFullScreenBarRestoreBgColor;
  }

  static Future<void> setFullScreenBarRestoreBgColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenBarRestoreBgColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isFullScreenMediaAutoShowEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullScreenMediaAutoShow) ??
        _defaultFullScreenMediaAutoShow;
  }

  static Future<void> setFullScreenMediaAutoShowEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreenMediaAutoShow, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBarWifiIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBarWifiIconId) ??
        _defaultFullScreenBarWifiIconId;
  }

  static Future<String?> getFullScreenBarWifiIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenBarWifiIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenBarWifiIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBarWifiIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenBarWifiIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenBarWifiIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBarBtIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBarBtIconId) ??
        _defaultFullScreenBarBtIconId;
  }

  static Future<String?> getFullScreenBarBtIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenBarBtIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenBarBtIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBarBtIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenBarBtIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenBarBtIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBarDataIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBarDataIconId) ??
        _defaultFullScreenBarDataIconId;
  }

  static Future<String?> getFullScreenBarDataIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenBarDataIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenBarDataIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBarDataIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenBarDataIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenBarDataIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBarLocIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBarLocIconId) ??
        _defaultFullScreenBarLocIconId;
  }

  static Future<String?> getFullScreenBarLocIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenBarLocIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenBarLocIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBarLocIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenBarLocIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenBarLocIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBarBatteryIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBarBatteryIconId) ??
        _defaultFullScreenBarBatteryIconId;
  }

  static Future<String?> getFullScreenBarBatteryIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenBarBatteryIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenBarBatteryIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBarBatteryIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenBarBatteryIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenBarBatteryIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBarMediaRestoreIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBarMediaRestoreIconId) ??
        _defaultFullScreenBarMediaRestoreIconId;
  }

  static Future<String?> getFullScreenBarMediaRestoreIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenBarMediaRestoreIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenBarMediaRestoreIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBarMediaRestoreIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenBarMediaRestoreIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenBarMediaRestoreIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenCloseHeightDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyFullScreenCloseHeightDp) ??
            _defaultFullScreenCloseHeightDp)
        .clamp(40, 240);
  }

  static Future<void> setFullScreenCloseHeightDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenCloseHeightDp, dp.clamp(40, 240));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isFullScreenCloseHideTextEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullScreenCloseHideText) ??
        _defaultFullScreenCloseHideText;
  }

  static Future<void> setFullScreenCloseHideTextEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreenCloseHideText, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenCloseIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenCloseIconId) ??
        _defaultFullScreenCloseIconId;
  }

  static Future<String?> getFullScreenCloseIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenCloseIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenCloseIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenCloseIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenCloseIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenCloseIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenCloseText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenCloseText) ?? _defaultFullScreenCloseText;
  }

  static Future<void> setFullScreenCloseText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenCloseText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBackText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBackText) ?? _defaultFullScreenBackText;
  }

  static Future<void> setFullScreenBackText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBackText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenHomeText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenHomeText) ?? _defaultFullScreenHomeText;
  }

  static Future<void> setFullScreenHomeText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenHomeText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenRecentsText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenRecentsText) ??
        _defaultFullScreenRecentsText;
  }

  static Future<void> setFullScreenRecentsText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenRecentsText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenVolumeText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenVolumeText) ??
        _defaultFullScreenVolumeText;
  }

  static Future<void> setFullScreenVolumeText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenVolumeText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenSettingsText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenSettingsText) ??
        _defaultFullScreenSettingsText;
  }

  static Future<void> setFullScreenSettingsText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenSettingsText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBrightnessText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBrightnessText) ??
        _defaultFullScreenBrightnessText;
  }

  static Future<void> setFullScreenBrightnessText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBrightnessText, text.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBackIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBackIconId) ?? 'back';
  }

  static Future<String?> getFullScreenBackIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenBackIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenBackIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBackIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenBackIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenBackIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenHomeIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenHomeIconId) ?? 'home';
  }

  static Future<String?> getFullScreenHomeIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenHomeIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenHomeIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenHomeIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenHomeIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenHomeIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenRecentsIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenRecentsIconId) ?? 'recent';
  }

  static Future<String?> getFullScreenRecentsIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenRecentsIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenRecentsIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenRecentsIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenRecentsIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenRecentsIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenVolumeIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenVolumeIconId) ?? 'volume';
  }

  static Future<String?> getFullScreenVolumeIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenVolumeIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenVolumeIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenVolumeIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenVolumeIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenVolumeIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenSettingsIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenSettingsIconId) ?? 'settings';
  }

  static Future<String?> getFullScreenSettingsIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenSettingsIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenSettingsIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenSettingsIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenSettingsIconPngBase64);
    } else {
      await prefs.setString(_keyFullScreenSettingsIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getFullScreenBrightnessIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullScreenBrightnessIconId) ?? 'brightness';
  }

  static Future<String?> getFullScreenBrightnessIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyFullScreenBrightnessIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setFullScreenBrightnessIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullScreenBrightnessIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyFullScreenBrightnessIconPngBase64);
    } else {
      await prefs.setString(
        _keyFullScreenBrightnessIconPngBase64,
        iconPngBase64,
      );
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<List<String>> getFullScreenOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFullScreenOrderJson);
    if (raw == null || raw.trim().isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> setFullScreenOrder(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    await prefs.setString(_keyFullScreenOrderJson, jsonEncode(cleaned));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<Map<String, String>> getFullScreenAppLabels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFullScreenAppLabelsJson);
    if (raw == null || raw.trim().isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final out = <String, String>{};
        decoded.forEach((k, v) {
          final kk = k.toString().trim();
          final vv = v.toString().trim();
          if (kk.isNotEmpty && vv.isNotEmpty) out[kk] = vv;
        });
        return out;
      }
      return <String, String>{};
    } catch (_) {
      return <String, String>{};
    }
  }

  static Future<void> setFullScreenAppLabel(String packageName, String? label) async {
    final pkg = packageName.trim();
    if (pkg.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = await getFullScreenAppLabels();
    final next = Map<String, String>.from(existing);
    final v = label?.trim();
    if (v == null || v.isEmpty) {
      next.remove(pkg);
    } else {
      next[pkg] = v;
    }
    await prefs.setString(_keyFullScreenAppLabelsJson, jsonEncode(next));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenCloseBgColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenCloseBgColor) ??
        _defaultFullScreenCloseBgColor;
  }

  static Future<void> setFullScreenCloseBgColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenCloseBgColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getFullScreenCloseTextColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFullScreenCloseTextColor) ??
        _defaultFullScreenCloseTextColor;
  }

  static Future<void> setFullScreenCloseTextColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFullScreenCloseTextColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isFullScreenCloseStickyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullScreenCloseSticky) ??
        _defaultFullScreenCloseSticky;
  }

  static Future<void> setFullScreenCloseStickyEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreenCloseSticky, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isFullScreenCloseDisableStickyWhenMediaActiveEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFullScreenCloseDisableStickyWhenMediaActive) ??
        _defaultFullScreenCloseDisableStickyWhenMediaActive;
  }

  static Future<void> setFullScreenCloseDisableStickyWhenMediaActiveEnabled(
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreenCloseDisableStickyWhenMediaActive, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getPopupBgColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPopupBgColor) ?? _defaultPopupBgColor;
  }

  static Future<void> setPopupBgColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPopupBgColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getPopupButtonColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPopupButtonColor) ?? _defaultPopupButtonColor;
  }

  static Future<void> setPopupButtonColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPopupButtonColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getPopupIconColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPopupIconColor) ?? _defaultPopupIconColor;
  }

  static Future<void> setPopupIconColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPopupIconColor, argb);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getPopupIconSizeDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyPopupIconSizeDp) ?? _defaultPopupIconSizeDp).clamp(10, 120);
  }

  static Future<void> setPopupIconSizeDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPopupIconSizeDp, dp.clamp(10, 120));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getPopupOffsetXDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyPopupOffsetXDp) ?? _defaultPopupOffsetXDp).clamp(-300, 300);
  }

  static Future<void> setPopupOffsetXDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPopupOffsetXDp, dp.clamp(-300, 300));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getPopupOffsetYDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyPopupOffsetYDp) ?? _defaultPopupOffsetYDp).clamp(-300, 300);
  }

  static Future<void> setPopupOffsetYDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPopupOffsetYDp, dp.clamp(-300, 300));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getPopupMediaOffsetXDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyPopupMediaOffsetXDp) ?? _defaultPopupMediaOffsetXDp)
        .clamp(-400, 400);
  }

  static Future<void> setPopupMediaOffsetXDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPopupMediaOffsetXDp, dp.clamp(-400, 400));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getPopupMediaOffsetYDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyPopupMediaOffsetYDp) ?? _defaultPopupMediaOffsetYDp)
        .clamp(-600, 600);
  }

  static Future<void> setPopupMediaOffsetYDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPopupMediaOffsetYDp, dp.clamp(-600, 600));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getPopupBackIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPopupBackIconId) ?? 'back';
  }

  static Future<String?> getPopupBackIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyPopupBackIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setPopupBackIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPopupBackIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyPopupBackIconPngBase64);
    } else {
      await prefs.setString(_keyPopupBackIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getPopupHomeIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPopupHomeIconId) ?? 'home';
  }

  static Future<String?> getPopupHomeIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyPopupHomeIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setPopupHomeIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPopupHomeIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyPopupHomeIconPngBase64);
    } else {
      await prefs.setString(_keyPopupHomeIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getPopupRecentsIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPopupRecentsIconId) ?? 'recent';
  }

  static Future<String?> getPopupRecentsIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyPopupRecentsIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setPopupRecentsIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPopupRecentsIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyPopupRecentsIconPngBase64);
    } else {
      await prefs.setString(_keyPopupRecentsIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getPopupVolumeIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPopupVolumeIconId) ?? 'volume';
  }

  static Future<String?> getPopupVolumeIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyPopupVolumeIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setPopupVolumeIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPopupVolumeIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyPopupVolumeIconPngBase64);
    } else {
      await prefs.setString(_keyPopupVolumeIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getPopupBrightnessIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPopupBrightnessIconId) ?? 'brightness';
  }

  static Future<String?> getPopupBrightnessIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyPopupBrightnessIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setPopupBrightnessIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPopupBrightnessIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyPopupBrightnessIconPngBase64);
    } else {
      await prefs.setString(_keyPopupBrightnessIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getPopupSettingsIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPopupSettingsIconId) ?? 'settings';
  }

  static Future<String?> getPopupSettingsIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyPopupSettingsIconPngBase64);
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  static Future<void> setPopupSettingsIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPopupSettingsIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyPopupSettingsIconPngBase64);
    } else {
      await prefs.setString(_keyPopupSettingsIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getMediaHeightDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyMediaHeightDp) ?? _defaultMediaHeightDp).clamp(140, 520);
  }

  static Future<void> setMediaHeightDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMediaHeightDp, dp.clamp(140, 520));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getMediaIconSizeDp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyMediaIconSizeDp) ?? _defaultMediaIconSizeDp).clamp(18, 120);
  }

  static Future<void> setMediaIconSizeDp(int dp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMediaIconSizeDp, dp.clamp(18, 120));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getMediaTitleSizeSp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyMediaTitleSizeSp) ?? _defaultMediaTitleSizeSp).clamp(12, 40);
  }

  static Future<void> setMediaTitleSizeSp(int sp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMediaTitleSizeSp, sp.clamp(12, 40));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getMediaSubtitleSizeSp() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyMediaSubtitleSizeSp) ?? _defaultMediaSubtitleSizeSp)
        .clamp(10, 36);
  }

  static Future<void> setMediaSubtitleSizeSp(int sp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMediaSubtitleSizeSp, sp.clamp(10, 36));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getMediaVolumeIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaVolumeIconId) ?? _defaultMediaVolumeIconId;
  }

  static Future<String?> getMediaVolumeIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaVolumeIconPngBase64);
  }

  static Future<void> setMediaVolumeIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMediaVolumeIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyMediaVolumeIconPngBase64);
    } else {
      await prefs.setString(_keyMediaVolumeIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getMediaPrevIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaPrevIconId) ?? _defaultMediaPrevIconId;
  }

  static Future<String?> getMediaPrevIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaPrevIconPngBase64);
  }

  static Future<void> setMediaPrevIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMediaPrevIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyMediaPrevIconPngBase64);
    } else {
      await prefs.setString(_keyMediaPrevIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getMediaPlayIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaPlayIconId) ?? _defaultMediaPlayIconId;
  }

  static Future<String?> getMediaPlayIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaPlayIconPngBase64);
  }

  static Future<void> setMediaPlayIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMediaPlayIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyMediaPlayIconPngBase64);
    } else {
      await prefs.setString(_keyMediaPlayIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getMediaPauseIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaPauseIconId) ?? _defaultMediaPauseIconId;
  }

  static Future<String?> getMediaPauseIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaPauseIconPngBase64);
  }

  static Future<void> setMediaPauseIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMediaPauseIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyMediaPauseIconPngBase64);
    } else {
      await prefs.setString(_keyMediaPauseIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getMediaNextIconId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaNextIconId) ?? _defaultMediaNextIconId;
  }

  static Future<String?> getMediaNextIconPngBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMediaNextIconPngBase64);
  }

  static Future<void> setMediaNextIconWithPng({
    required String iconId,
    required String? iconPngBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMediaNextIconId, iconId);
    if (iconPngBase64 == null || iconPngBase64.trim().isEmpty) {
      await prefs.remove(_keyMediaNextIconPngBase64);
    } else {
      await prefs.setString(_keyMediaNextIconPngBase64, iconPngBase64);
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isGesturesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGesturesEnabled) ?? _defaultGesturesEnabled;
  }

  static Future<void> setGesturesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGesturesEnabled, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getGestureLongPressMs() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyGestureLongPressMs) ?? _defaultGestureLongPressMs)
        .clamp(150, 2000);
  }

  static Future<void> setGestureLongPressMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGestureLongPressMs, ms.clamp(150, 2000));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getGestureUpAction() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGestureUpAction) ?? _defaultGestureUpAction;
  }

  static Future<void> setGestureUpAction(String action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGestureUpAction, action.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String?> getGestureUpApp() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyGestureUpApp);
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  static Future<void> setGestureUpApp(String? packageName) async {
    final prefs = await SharedPreferences.getInstance();
    if (packageName == null || packageName.trim().isEmpty) {
      await prefs.remove(_keyGestureUpApp);
    } else {
      await prefs.setString(_keyGestureUpApp, packageName.trim());
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getGestureRightAction() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGestureRightAction) ?? _defaultGestureRightAction;
  }

  static Future<void> setGestureRightAction(String action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGestureRightAction, action.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String?> getGestureRightApp() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyGestureRightApp);
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  static Future<void> setGestureRightApp(String? packageName) async {
    final prefs = await SharedPreferences.getInstance();
    if (packageName == null || packageName.trim().isEmpty) {
      await prefs.remove(_keyGestureRightApp);
    } else {
      await prefs.setString(_keyGestureRightApp, packageName.trim());
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getGestureDownAction() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGestureDownAction) ?? _defaultGestureDownAction;
  }

  static Future<void> setGestureDownAction(String action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGestureDownAction, action.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String?> getGestureDownApp() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyGestureDownApp);
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  static Future<void> setGestureDownApp(String? packageName) async {
    final prefs = await SharedPreferences.getInstance();
    if (packageName == null || packageName.trim().isEmpty) {
      await prefs.remove(_keyGestureDownApp);
    } else {
      await prefs.setString(_keyGestureDownApp, packageName.trim());
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String> getGestureLeftAction() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGestureLeftAction) ?? _defaultGestureLeftAction;
  }

  static Future<void> setGestureLeftAction(String action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGestureLeftAction, action.trim());
    await _channel.invokeMethod('updateConfig');
  }

  static Future<String?> getGestureLeftApp() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyGestureLeftApp);
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  static Future<void> setGestureLeftApp(String? packageName) async {
    final prefs = await SharedPreferences.getInstance();
    if (packageName == null || packageName.trim().isEmpty) {
      await prefs.remove(_keyGestureLeftApp);
    } else {
      await prefs.setString(_keyGestureLeftApp, packageName.trim());
    }
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getGestureVibrationMs() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyGestureVibrationMs) ?? _defaultGestureVibrationMs)
        .clamp(0, 500);
  }

  static Future<void> setGestureVibrationMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGestureVibrationMs, ms.clamp(0, 500));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<int> getGestureVibrationAmplitude() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyGestureVibrationAmplitude) ??
            _defaultGestureVibrationAmplitude)
        .clamp(1, 255);
  }

  static Future<void> setGestureVibrationAmplitude(int amplitude) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGestureVibrationAmplitude, amplitude.clamp(1, 255));
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isGestureNotificationsUseCustomScreenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGestureNotificationsUseCustomScreen) ??
        _defaultGestureNotificationsUseCustomScreen;
  }

  static Future<void> setGestureNotificationsUseCustomScreenEnabled(
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGestureNotificationsUseCustomScreen, enabled);
    await _channel.invokeMethod('updateConfig');
  }

  static Future<bool> isOverlayPermissionGranted() async {
    final res = await _channel.invokeMethod('isOverlayPermissionGranted');
    return res == true;
  }

  static Future<void> openOverlayPermissionSettings() async {
    await _channel.invokeMethod('openOverlayPermissionSettings');
  }

  static Future<bool> isAccessibilityEnabled() async {
    final res = await _channel.invokeMethod('isAccessibilityEnabled');
    return res == true;
  }

  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  static Future<bool> isBatteryOptimizationIgnored() async {
    final res = await _channel.invokeMethod('isBatteryOptimizationIgnored');
    return res == true;
  }

  static Future<void> requestBatteryOptimizationPermission() async {
    await _channel.invokeMethod('requestBatteryOptimizationPermission');
  }

  static Future<void> enableAndStart() async {
    await setEnabledTrue();
    await _channel.invokeMethod('enableAndStart');
  }
}
