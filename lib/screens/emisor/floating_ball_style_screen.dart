import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:connect/screens/emisor/floating_ball_reorder_screen.dart';
import 'package:connect/screens/emisor/svg_icon_gallery_screen.dart';
import 'package:connect/services/floating_ball_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/widgets/fs_media_section.dart';
import 'package:connect/widgets/color_input_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as vg;

class FloatingBallStyleScreen extends StatefulWidget {
  const FloatingBallStyleScreen({super.key});

  @override
  State<FloatingBallStyleScreen> createState() => _FloatingBallStyleScreenState();
}

class _FloatingBallStyleScreenState extends State<FloatingBallStyleScreen> {
  bool _loading = true;
  bool _mediaVisible = false;
  int _ballColor = 0xCC000000;
  String _ballIcon = 'info';
  String? _ballIconPngBase64;
  int _ballIconColor = 0xFFFFFFFF;
  int _ballIconSizeDp = 28;
  int _ballSizeDp = 56;
  bool _fullScreen = false;
  int _fsBgColor = 0xDD111111;
  int _fsButtonColor = 0x22111111;
  int _fsAppsButtonColor = 0x22111111;
  int _fsContentColor = 0xFFFFFFFF;
  int _fsIconColor = 0xFFFFFFFF;
  int _fsTextColor = 0xFFFFFFFF;
  bool _fsHideText = false;
  int _fsIconSizeDp = 34;
  int _fsTextSizeSp = 14;
  int _fsTileGapDp = 10;
  int _fsAppsTileGapDp = 10;
  int _fsTilePaddingDp = 0;
  int _fsStickyPaddingDp = 16;
  int _fsTileInnerGapDp = 10;
  int _fsTileHeightDp = 120;
  int _fsAppsTileHeightDp = 120;
  int _fsTileBorderColor = 0x22FFFFFF;
  int _fsAppsTileBorderColor = 0x22FFFFFF;
  int _fsAppsIconSizeDp = 34;
  int _fsContainerPaddingHorzDp = 16;
  int _fsContainerPaddingVertDp = 16;
  int _fsSystemCols = 1;
  int _fsAppsCols = 1;
  bool _fsBarEnabled = false;
  bool _fsCustomNotificationsEnabled = false;
  bool _fsConversationEnabled = false;
  int _customNotifsBgColor = 0xDD111111;
  int _customNotifsItemBgColor = 0x22111111;
  int _customNotifsItemBorderColor = 0x22FFFFFF;
  int _customNotifsTitleColor = 0xFFFFFFFF;
  int _customNotifsTextColor = 0xFFFFFFFF;
  int _customNotifsTitleSizeSp = 16;
  int _customNotifsTextSizeSp = 14;
  int _customNotifsButtonsIconHeightDp = 34;
  String _customNotifsDeleteIconId = 'delete';
  String? _customNotifsDeleteIconPngBase64;
  String _customNotifsDeleteText = 'Eliminar';
  bool _customNotifsButtonsHideText = false;
  int _customNotifsButtonsHeightDp = 52;
  int _customNotifsButtonsBgColor = 0xFF202020;
  int _customNotifsButtonsBorderColor = 0x22FFFFFF;
  int _customNotifsButtonsContentColor = 0xFFFFFFFF;
  String _customNotifsCloseIconId = 'close';
  String? _customNotifsCloseIconPngBase64;
  String _customNotifsCloseText = 'Cerrar';
  String _customNotifsClearAllIconId = 'delete';
  String? _customNotifsClearAllIconPngBase64;
  String _customNotifsClearAllText = 'Eliminar todo';
  int _conversationBgColor = 0xDD111111;
  int _conversationIncomingColor = 0x22111111;
  int _conversationOutgoingColor = 0x22FFFFFF;
  int _conversationTextColor = 0xFFFFFFFF;
  int _conversationTextSizeSp = 14;
  int _conversationTitleColor = 0xFFFFFFFF;
  int _conversationTitleSizeSp = 16;
  int _conversationCloseHeightDp = 52;
  int _conversationCloseBgColor = 0xFFDC2626;
  int _conversationCloseTextColor = 0xFFFFFFFF;
  int _conversationCloseBorderColor = 0x22FFFFFF;
  bool _conversationCloseHideText = false;
  String _conversationCloseText = 'Cerrar';
  String _conversationCloseIconId = 'close';
  String? _conversationCloseIconPngBase64;
  int _conversationReplyHeightDp = 52;
  int _conversationReplyBgColor = 0xFF202020;
  int _conversationReplyTextColor = 0xFFFFFFFF;
  int _conversationReplyBorderColor = 0x22FFFFFF;
  bool _conversationReplyHideText = false;
  String _conversationReplyText = 'Responder';
  String _conversationReplyIconId = 'reply';
  String? _conversationReplyIconPngBase64;
  int _conversationBottomButtonsGapDp = 10;
  int _conversationBottomButtonsPaddingHorzDp = 14;
  int _conversationBottomButtonsPaddingVertDp = 10;
  int _conversationHeaderAppIconSizeDp = 34;
  int _conversationCloseIconSizeDp = 20;
  int _conversationReplyIconSizeDp = 20;
  int _conversationReplyModalBgColor = 0xFF111111;
  int _conversationReplyModalTextColor = 0xFFFFFFFF;
  int _conversationReplyModalTextSizeSp = 16;
  String _conversationReplyModalSendIconId = 'send';
  String? _conversationReplyModalSendIconPngBase64;
  int _conversationReplyModalSendIconSizeDp = 22;
  int _conversationReplyModalSendBgColor = 0x00000000;
  int _conversationReplyModalSendBorderColor = 0x22FFFFFF;
  int _fsBarHeightDp = 54;
  int _fsBarBgColor = 0xCC111111;
  int _fsBarContentColor = 0xFFFFFFFF;
  int _fsBarIconSizeDp = 18;
  int _fsBarTextSizeSp = 14;
  int _fsBarPaddingHorzDp = 16;
  int _fsBarPaddingVertDp = 0;
  int _fsBarTimeColor = 0xFFFFFFFF;
  int _fsBarWifiIconColor = 0xFFFFFFFF;
  int _fsBarBtIconColor = 0xFFFFFFFF;
  int _fsBarDataIconColor = 0xFFFFFFFF;
  int _fsBarLocIconColor = 0xFFFFFFFF;
  int _fsBarBatteryIconColor = 0xFFFFFFFF;
  int _fsBarBatteryTextColor = 0xFFFFFFFF;
  int _fsBarRestoreIconColor = 0xFFFFFFFF;
  int _fsBarRestoreBgColor = 0x33FFFFFF;
  String _fsBarWifiIconId = 'wifi';
  String? _fsBarWifiIconPngBase64;
  String _fsBarBtIconId = 'bluetooth';
  String? _fsBarBtIconPngBase64;
  String _fsBarDataIconId = 'data';
  String? _fsBarDataIconPngBase64;
  String _fsBarLocIconId = 'location';
  String? _fsBarLocIconPngBase64;
  String _fsBarBatteryIconId = 'battery';
  String? _fsBarBatteryIconPngBase64;
  String _fsBarMediaRestoreIconId = 'play';
  String? _fsBarMediaRestoreIconPngBase64;
  bool _fsMediaAutoShow = true;
  int _fsCloseHeightDp = 120;
  int _fsCloseBgColor = 0xFFDC2626;
  int _fsCloseTextColor = 0xFFFFFFFF;
  bool _fsCloseHideText = false;
  String _fsCloseIconId = 'close';
  String? _fsCloseIconPngBase64;
  bool _fsCloseSticky = false;
  bool _fsCloseDisableStickyWhenMediaActive = true;
  String _fsCloseText = 'Cerrar';

  String _fsBackText = 'Back';
  String _fsHomeText = 'Home';
  String _fsRecentsText = 'Recientes';
  String _fsVolumeText = 'Volumen';
  String _fsBrightnessText = 'Brillo';
  String _fsSettingsText = 'Ajustes';

  String _fsBackIconId = 'back';
  String _fsHomeIconId = 'home';
  String _fsRecentsIconId = 'recent';
  String _fsVolumeIconId = 'volume';
  String _fsBrightnessIconId = 'brightness';
  String _fsSettingsIconId = 'settings';

  String? _fsBackIconPngBase64;
  String? _fsHomeIconPngBase64;
  String? _fsRecentsIconPngBase64;
  String? _fsVolumeIconPngBase64;
  String? _fsBrightnessIconPngBase64;
  String? _fsSettingsIconPngBase64;

  int _popupBgColor = 0xDD111111;
  int _popupButtonColor = 0x22111111;
  int _popupIconColor = 0xFFFFFFFF;
  int _popupIconSizeDp = 26;
  int _popupOffsetXDp = 0;
  int _popupOffsetYDp = 0;
  int _popupMediaOffsetXDp = 0;
  int _popupMediaOffsetYDp = 0;

  String _popupBackIconId = 'back';
  String _popupHomeIconId = 'home';
  String _popupRecentsIconId = 'recent';
  String _popupVolumeIconId = 'volume';
  String _popupBrightnessIconId = 'brightness';
  String _popupSettingsIconId = 'settings';

  String? _popupBackIconPngBase64;
  String? _popupHomeIconPngBase64;
  String? _popupRecentsIconPngBase64;
  String? _popupVolumeIconPngBase64;
  String? _popupBrightnessIconPngBase64;
  String? _popupSettingsIconPngBase64;

  int _mediaHeightDp = 320;
  int _mediaIconSizeDp = 34;
  int _mediaTitleSizeSp = 18;
  int _mediaSubtitleSizeSp = 14;
  String _mediaVolumeIconId = 'volume';
  String _mediaPrevIconId = 'skip_prev';
  String _mediaPlayIconId = 'play';
  String _mediaPauseIconId = 'pause';
  String _mediaNextIconId = 'skip_next';
  String? _mediaVolumeIconPngBase64;
  String? _mediaPrevIconPngBase64;
  String? _mediaPlayIconPngBase64;
  String? _mediaPauseIconPngBase64;
  String? _mediaNextIconPngBase64;

  final List<Map<String, dynamic>> _iconOptions = const [
    {'id': 'info', 'icon': Icons.info},
    {'id': 'apps', 'icon': Icons.apps},
    {'id': 'play', 'icon': Icons.play_arrow},
    {'id': 'settings', 'icon': Icons.settings},
    {'id': 'flash', 'icon': Icons.flash_on},
    {'id': 'star', 'icon': Icons.star},
    {'id': 'home', 'icon': Icons.home},
    {'id': 'back', 'icon': Icons.arrow_back},
    {'id': 'recent', 'icon': Icons.history},
    {'id': 'search', 'icon': Icons.search},
    {'id': 'add', 'icon': Icons.add},
    {'id': 'edit', 'icon': Icons.edit},
    {'id': 'delete', 'icon': Icons.delete},
    {'id': 'close', 'icon': Icons.close},
    {'id': 'phone', 'icon': Icons.phone},
    {'id': 'sms', 'icon': Icons.sms},
    {'id': 'email', 'icon': Icons.email},
    {'id': 'camera', 'icon': Icons.camera_alt},
    {'id': 'photo', 'icon': Icons.photo},
    {'id': 'music', 'icon': Icons.music_note},
    {'id': 'volume', 'icon': Icons.volume_up},
    {'id': 'wifi', 'icon': Icons.wifi},
    {'id': 'bluetooth', 'icon': Icons.bluetooth},
    {'id': 'data', 'icon': Icons.data_usage},
    {'id': 'location', 'icon': Icons.location_on},
    {'id': 'map', 'icon': Icons.map},
    {'id': 'calendar', 'icon': Icons.calendar_today},
    {'id': 'alarm', 'icon': Icons.alarm},
    {'id': 'timer', 'icon': Icons.timer},
    {'id': 'lock', 'icon': Icons.lock},
    {'id': 'unlock', 'icon': Icons.lock_open},
    {'id': 'share', 'icon': Icons.share},
    {'id': 'send', 'icon': Icons.send},
    {'id': 'download', 'icon': Icons.download},
    {'id': 'upload', 'icon': Icons.upload},
    {'id': 'refresh', 'icon': Icons.refresh},
    {'id': 'power', 'icon': Icons.power_settings_new},
    {'id': 'battery', 'icon': Icons.battery_full},
    {'id': 'bolt', 'icon': Icons.bolt},
    {'id': 'folder', 'icon': Icons.folder},
    {'id': 'file', 'icon': Icons.insert_drive_file},
    {'id': 'chat', 'icon': Icons.chat},
    {'id': 'help', 'icon': Icons.help},
    {'id': 'warning', 'icon': Icons.warning},
    {'id': 'check', 'icon': Icons.check_circle},
    {'id': 'qr', 'icon': Icons.qr_code},
    {'id': 'link', 'icon': Icons.link},
    {'id': 'key', 'icon': Icons.key},
    {'id': 'shield', 'icon': Icons.shield},
    {'id': 'game', 'icon': Icons.videogame_asset},
    {'id': 'tv', 'icon': Icons.tv},
    {'id': 'car', 'icon': Icons.directions_car},
    {'id': 'walk', 'icon': Icons.directions_walk},
    {'id': 'watch', 'icon': Icons.watch},
    {'id': 'light', 'icon': Icons.lightbulb},
    {'id': 'brightness', 'icon': Icons.brightness_6},
    {'id': 'bookmark', 'icon': Icons.bookmark},
    {'id': 'cloud', 'icon': Icons.cloud},
    {'id': 'person', 'icon': Icons.person},
    {'id': 'person_add', 'icon': Icons.person_add},
    {'id': 'favorite', 'icon': Icons.favorite},
    {'id': 'favorite_border', 'icon': Icons.favorite_border},
    {'id': 'notifications', 'icon': Icons.notifications},
    {'id': 'notifications_off', 'icon': Icons.notifications_off},
    {'id': 'camera_front', 'icon': Icons.camera_front},
    {'id': 'camera_rear', 'icon': Icons.camera_rear},
    {'id': 'mic', 'icon': Icons.mic},
    {'id': 'mic_off', 'icon': Icons.mic_off},
    {'id': 'pause', 'icon': Icons.pause},
    {'id': 'stop', 'icon': Icons.stop},
    {'id': 'skip_next', 'icon': Icons.skip_next},
    {'id': 'skip_prev', 'icon': Icons.skip_previous},
    {'id': 'fast_forward', 'icon': Icons.fast_forward},
    {'id': 'fast_rewind', 'icon': Icons.fast_rewind},
    {'id': 'tune', 'icon': Icons.tune},
    {'id': 'filter', 'icon': Icons.filter_alt},
    {'id': 'security', 'icon': Icons.security},
    {'id': 'verified', 'icon': Icons.verified_user},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    bool nextMediaVisible = _mediaVisible;
    int nextBallColor = _ballColor;
    String nextBallIcon = _ballIcon;
    String? nextBallIconPngBase64 = _ballIconPngBase64;
    int nextBallIconColor = _ballIconColor;
    int nextBallIconSizeDp = _ballIconSizeDp;
    int nextBallSizeDp = _ballSizeDp;
    bool nextFullScreen = _fullScreen;
    int nextFsBg = _fsBgColor;
    int nextFsBtn = _fsButtonColor;
    int nextFsAppsBtn = _fsAppsButtonColor;
    int nextFsContent = _fsContentColor;
    int nextFsIconColor = _fsIconColor;
    int nextFsTextColor = _fsTextColor;
    bool nextFsHideText = _fsHideText;
    int nextFsIconSizeDp = _fsIconSizeDp;
    int nextFsTextSizeSp = _fsTextSizeSp;
    int nextFsTileGapDp = _fsTileGapDp;
    int nextFsAppsTileGapDp = _fsAppsTileGapDp;
    int nextFsTilePaddingDp = _fsTilePaddingDp;
    int nextFsStickyPaddingDp = _fsStickyPaddingDp;
    int nextFsTileInnerGapDp = _fsTileInnerGapDp;
    int nextFsTileHeightDp = _fsTileHeightDp;
    int nextFsAppsTileHeightDp = _fsAppsTileHeightDp;
    int nextFsTileBorderColor = _fsTileBorderColor;
    int nextFsAppsTileBorderColor = _fsAppsTileBorderColor;
    int nextFsAppsIconSizeDp = _fsAppsIconSizeDp;
    int nextFsContainerPaddingHorzDp = _fsContainerPaddingHorzDp;
    int nextFsContainerPaddingVertDp = _fsContainerPaddingVertDp;
    int nextFsSystemCols = _fsSystemCols;
    int nextFsAppsCols = _fsAppsCols;
    bool nextFsBarEnabled = _fsBarEnabled;
    bool nextFsCustomNotificationsEnabled = _fsCustomNotificationsEnabled;
    bool nextFsConversationEnabled = _fsConversationEnabled;
    int nextCustomNotifsBgColor = _customNotifsBgColor;
    int nextCustomNotifsItemBgColor = _customNotifsItemBgColor;
    int nextCustomNotifsItemBorderColor = _customNotifsItemBorderColor;
    int nextCustomNotifsTitleColor = _customNotifsTitleColor;
    int nextCustomNotifsTextColor = _customNotifsTextColor;
    int nextCustomNotifsTitleSizeSp = _customNotifsTitleSizeSp;
    int nextCustomNotifsTextSizeSp = _customNotifsTextSizeSp;
    int nextCustomNotifsButtonsIconHeightDp = _customNotifsButtonsIconHeightDp;
    String nextCustomNotifsDeleteIconId = _customNotifsDeleteIconId;
    String? nextCustomNotifsDeleteIconPngBase64 = _customNotifsDeleteIconPngBase64;
    String nextCustomNotifsDeleteText = _customNotifsDeleteText;
    bool nextCustomNotifsButtonsHideText = _customNotifsButtonsHideText;
    int nextCustomNotifsButtonsHeightDp = _customNotifsButtonsHeightDp;
    int nextCustomNotifsButtonsBgColor = _customNotifsButtonsBgColor;
    int nextCustomNotifsButtonsBorderColor = _customNotifsButtonsBorderColor;
    int nextCustomNotifsButtonsContentColor = _customNotifsButtonsContentColor;
    String nextCustomNotifsCloseIconId = _customNotifsCloseIconId;
    String? nextCustomNotifsCloseIconPngBase64 = _customNotifsCloseIconPngBase64;
    String nextCustomNotifsCloseText = _customNotifsCloseText;
    String nextCustomNotifsClearAllIconId = _customNotifsClearAllIconId;
    String? nextCustomNotifsClearAllIconPngBase64 = _customNotifsClearAllIconPngBase64;
    String nextCustomNotifsClearAllText = _customNotifsClearAllText;
    int nextConversationBgColor = _conversationBgColor;
    int nextConversationIncomingColor = _conversationIncomingColor;
    int nextConversationOutgoingColor = _conversationOutgoingColor;
    int nextConversationTextColor = _conversationTextColor;
    int nextConversationTextSizeSp = _conversationTextSizeSp;
    int nextConversationTitleColor = _conversationTitleColor;
    int nextConversationTitleSizeSp = _conversationTitleSizeSp;
    int nextConversationCloseHeightDp = _conversationCloseHeightDp;
    int nextConversationCloseBgColor = _conversationCloseBgColor;
    int nextConversationCloseTextColor = _conversationCloseTextColor;
    int nextConversationCloseBorderColor = _conversationCloseBorderColor;
    bool nextConversationCloseHideText = _conversationCloseHideText;
    String nextConversationCloseText = _conversationCloseText;
    String nextConversationCloseIconId = _conversationCloseIconId;
    String? nextConversationCloseIconPngBase64 = _conversationCloseIconPngBase64;
    int nextConversationReplyHeightDp = _conversationReplyHeightDp;
    int nextConversationReplyBgColor = _conversationReplyBgColor;
    int nextConversationReplyTextColor = _conversationReplyTextColor;
    int nextConversationReplyBorderColor = _conversationReplyBorderColor;
    bool nextConversationReplyHideText = _conversationReplyHideText;
    String nextConversationReplyText = _conversationReplyText;
    String nextConversationReplyIconId = _conversationReplyIconId;
    String? nextConversationReplyIconPngBase64 = _conversationReplyIconPngBase64;
    int nextConversationBottomButtonsGapDp = _conversationBottomButtonsGapDp;
    int nextConversationBottomButtonsPaddingHorzDp =
        _conversationBottomButtonsPaddingHorzDp;
    int nextConversationBottomButtonsPaddingVertDp =
        _conversationBottomButtonsPaddingVertDp;
    int nextConversationHeaderAppIconSizeDp = _conversationHeaderAppIconSizeDp;
    int nextConversationCloseIconSizeDp = _conversationCloseIconSizeDp;
    int nextConversationReplyIconSizeDp = _conversationReplyIconSizeDp;
    int nextConversationReplyModalBgColor = _conversationReplyModalBgColor;
    int nextConversationReplyModalTextColor = _conversationReplyModalTextColor;
    int nextConversationReplyModalTextSizeSp = _conversationReplyModalTextSizeSp;
    String nextConversationReplyModalSendIconId = _conversationReplyModalSendIconId;
    String? nextConversationReplyModalSendIconPngBase64 =
        _conversationReplyModalSendIconPngBase64;
    int nextConversationReplyModalSendIconSizeDp =
        _conversationReplyModalSendIconSizeDp;
    int nextConversationReplyModalSendBgColor = _conversationReplyModalSendBgColor;
    int nextConversationReplyModalSendBorderColor =
        _conversationReplyModalSendBorderColor;
    int nextFsBarHeightDp = _fsBarHeightDp;
    int nextFsBarBgColor = _fsBarBgColor;
    int nextFsBarContentColor = _fsBarContentColor;
    int nextFsBarIconSizeDp = _fsBarIconSizeDp;
    int nextFsBarTextSizeSp = _fsBarTextSizeSp;
    int nextFsBarPaddingHorzDp = _fsBarPaddingHorzDp;
    int nextFsBarPaddingVertDp = _fsBarPaddingVertDp;
    int nextFsBarTimeColor = _fsBarTimeColor;
    int nextFsBarWifiIconColor = _fsBarWifiIconColor;
    int nextFsBarBtIconColor = _fsBarBtIconColor;
    int nextFsBarDataIconColor = _fsBarDataIconColor;
    int nextFsBarLocIconColor = _fsBarLocIconColor;
    int nextFsBarBatteryIconColor = _fsBarBatteryIconColor;
    int nextFsBarBatteryTextColor = _fsBarBatteryTextColor;
    int nextFsBarRestoreIconColor = _fsBarRestoreIconColor;
    int nextFsBarRestoreBgColor = _fsBarRestoreBgColor;
    String nextFsBarWifiIconId = _fsBarWifiIconId;
    String? nextFsBarWifiIconPngBase64 = _fsBarWifiIconPngBase64;
    String nextFsBarBtIconId = _fsBarBtIconId;
    String? nextFsBarBtIconPngBase64 = _fsBarBtIconPngBase64;
    String nextFsBarDataIconId = _fsBarDataIconId;
    String? nextFsBarDataIconPngBase64 = _fsBarDataIconPngBase64;
    String nextFsBarLocIconId = _fsBarLocIconId;
    String? nextFsBarLocIconPngBase64 = _fsBarLocIconPngBase64;
    String nextFsBarBatteryIconId = _fsBarBatteryIconId;
    String? nextFsBarBatteryIconPngBase64 = _fsBarBatteryIconPngBase64;
    String nextFsBarMediaRestoreIconId = _fsBarMediaRestoreIconId;
    String? nextFsBarMediaRestoreIconPngBase64 = _fsBarMediaRestoreIconPngBase64;
    bool nextFsMediaAutoShow = _fsMediaAutoShow;
    int nextFsCloseHeightDp = _fsCloseHeightDp;
    int nextFsCloseBg = _fsCloseBgColor;
    int nextFsCloseText = _fsCloseTextColor;
    bool nextFsCloseHideText = _fsCloseHideText;
    String nextFsCloseIconId = _fsCloseIconId;
    String? nextFsCloseIconPngBase64 = _fsCloseIconPngBase64;
    bool nextFsCloseSticky = _fsCloseSticky;
    bool nextFsCloseDisableStickyWhenMediaActive = _fsCloseDisableStickyWhenMediaActive;
    String nextFsCloseTextLabel = _fsCloseText;
    String nextFsBackText = _fsBackText;
    String nextFsHomeText = _fsHomeText;
    String nextFsRecentsText = _fsRecentsText;
    String nextFsVolumeText = _fsVolumeText;
    String nextFsBrightnessText = _fsBrightnessText;
    String nextFsSettingsText = _fsSettingsText;
    String nextFsBackIconId = _fsBackIconId;
    String nextFsHomeIconId = _fsHomeIconId;
    String nextFsRecentsIconId = _fsRecentsIconId;
    String nextFsVolumeIconId = _fsVolumeIconId;
    String nextFsBrightnessIconId = _fsBrightnessIconId;
    String nextFsSettingsIconId = _fsSettingsIconId;
    String? nextFsBackIconPngBase64 = _fsBackIconPngBase64;
    String? nextFsHomeIconPngBase64 = _fsHomeIconPngBase64;
    String? nextFsRecentsIconPngBase64 = _fsRecentsIconPngBase64;
    String? nextFsVolumeIconPngBase64 = _fsVolumeIconPngBase64;
    String? nextFsBrightnessIconPngBase64 = _fsBrightnessIconPngBase64;
    String? nextFsSettingsIconPngBase64 = _fsSettingsIconPngBase64;
    int nextPopupBgColor = _popupBgColor;
    int nextPopupButtonColor = _popupButtonColor;
    int nextPopupIconColor = _popupIconColor;
    int nextPopupIconSizeDp = _popupIconSizeDp;
    int nextPopupOffsetXDp = _popupOffsetXDp;
    int nextPopupOffsetYDp = _popupOffsetYDp;
    int nextPopupMediaOffsetXDp = _popupMediaOffsetXDp;
    int nextPopupMediaOffsetYDp = _popupMediaOffsetYDp;
    String nextPopupBackIconId = _popupBackIconId;
    String nextPopupHomeIconId = _popupHomeIconId;
    String nextPopupRecentsIconId = _popupRecentsIconId;
    String nextPopupVolumeIconId = _popupVolumeIconId;
    String nextPopupBrightnessIconId = _popupBrightnessIconId;
    String nextPopupSettingsIconId = _popupSettingsIconId;
    String? nextPopupBackIconPngBase64 = _popupBackIconPngBase64;
    String? nextPopupHomeIconPngBase64 = _popupHomeIconPngBase64;
    String? nextPopupRecentsIconPngBase64 = _popupRecentsIconPngBase64;
    String? nextPopupVolumeIconPngBase64 = _popupVolumeIconPngBase64;
    String? nextPopupBrightnessIconPngBase64 = _popupBrightnessIconPngBase64;
    String? nextPopupSettingsIconPngBase64 = _popupSettingsIconPngBase64;
    int nextMediaHeightDp = _mediaHeightDp;
    int nextMediaIconSizeDp = _mediaIconSizeDp;
    int nextMediaTitleSizeSp = _mediaTitleSizeSp;
    int nextMediaSubtitleSizeSp = _mediaSubtitleSizeSp;
    String nextMediaVolumeIconId = _mediaVolumeIconId;
    String nextMediaPrevIconId = _mediaPrevIconId;
    String nextMediaPlayIconId = _mediaPlayIconId;
    String nextMediaPauseIconId = _mediaPauseIconId;
    String nextMediaNextIconId = _mediaNextIconId;
    String? nextMediaVolumeIconPngBase64 = _mediaVolumeIconPngBase64;
    String? nextMediaPrevIconPngBase64 = _mediaPrevIconPngBase64;
    String? nextMediaPlayIconPngBase64 = _mediaPlayIconPngBase64;
    String? nextMediaPauseIconPngBase64 = _mediaPauseIconPngBase64;
    String? nextMediaNextIconPngBase64 = _mediaNextIconPngBase64;
    try {
      try {
        nextMediaVisible = await FloatingBallService.isFullScreenMediaAutoShowEnabled();
        print('[floating_ball_style] mediaVisible init autoShow=$nextMediaVisible');
      } catch (e) {
        print('[floating_ball_style] mediaVisible init error=$e');
      }
      nextBallColor = await FloatingBallService.getBallColor();
      nextBallIcon = await FloatingBallService.getBallIcon();
      nextBallIconPngBase64 = await FloatingBallService.getBallIconPngBase64();
      nextBallIconColor = await FloatingBallService.getBallIconColor();
      nextBallIconSizeDp = await FloatingBallService.getBallIconSizeDp();
      nextBallSizeDp = await FloatingBallService.getBallSizeDp();
      if (nextBallIconPngBase64 == null) {
        final iconData = _iconDataForId(nextBallIcon);
        final png = await _renderIconPngBase64(iconData);
        await FloatingBallService.setBallIconWithPng(
          iconId: nextBallIcon,
          iconPngBase64: png,
        );
        nextBallIconPngBase64 = png;
      }
      nextFullScreen = await FloatingBallService.isFullScreenEnabled();
      nextFsBg = await FloatingBallService.getFullScreenBgColor();
      nextFsBtn = await FloatingBallService.getFullScreenButtonColor();
      nextFsAppsBtn = await FloatingBallService.getFullScreenAppsButtonColor();
      nextFsContent = await FloatingBallService.getFullScreenContentColor();
      nextFsIconColor = await FloatingBallService.getFullScreenIconColor();
      nextFsTextColor = await FloatingBallService.getFullScreenTextColor();
      nextFsHideText = await FloatingBallService.isFullScreenHideTextEnabled();
      nextFsIconSizeDp = await FloatingBallService.getFullScreenIconSizeDp();
      nextFsTextSizeSp = await FloatingBallService.getFullScreenTextSizeSp();
      nextFsTileGapDp = await FloatingBallService.getFullScreenTileGapDp();
      nextFsAppsTileGapDp = await FloatingBallService.getFullScreenAppsTileGapDp();
      nextFsTilePaddingDp = await FloatingBallService.getFullScreenTilePaddingDp();
      nextFsStickyPaddingDp =
          await FloatingBallService.getFullScreenStickyPaddingDp();
      nextFsTileInnerGapDp = await FloatingBallService.getFullScreenTileInnerGapDp();
      nextFsTileHeightDp = await FloatingBallService.getFullScreenTileHeightDp();
      nextFsAppsTileHeightDp =
          await FloatingBallService.getFullScreenAppsTileHeightDp();
      nextFsTileBorderColor = await FloatingBallService.getFullScreenTileBorderColor();
      nextFsAppsTileBorderColor =
          await FloatingBallService.getFullScreenAppsTileBorderColor();
      nextFsAppsIconSizeDp = await FloatingBallService.getFullScreenAppsIconSizeDp();
      nextFsContainerPaddingHorzDp =
          await FloatingBallService.getFullScreenContainerPaddingHorzDp();
      nextFsContainerPaddingVertDp =
          await FloatingBallService.getFullScreenContainerPaddingVertDp();
      nextFsSystemCols = await FloatingBallService.getFullScreenSystemCols();
      nextFsAppsCols = await FloatingBallService.getFullScreenAppsCols();
      nextFsBarEnabled = await FloatingBallService.isFullScreenBarEnabled();
      nextFsCustomNotificationsEnabled =
          await FloatingBallService.isFullScreenCustomNotificationsEnabled();
      nextCustomNotifsBgColor =
          await FloatingBallService.getCustomNotificationsBgColor();
      nextCustomNotifsItemBgColor =
          await FloatingBallService.getCustomNotificationsItemBgColor();
      nextCustomNotifsItemBorderColor =
          await FloatingBallService.getCustomNotificationsItemBorderColor();
      nextCustomNotifsTitleColor =
          await FloatingBallService.getCustomNotificationsTitleColor();
      nextCustomNotifsTextColor =
          await FloatingBallService.getCustomNotificationsTextColor();
      nextCustomNotifsTitleSizeSp =
          await FloatingBallService.getCustomNotificationsTitleSizeSp();
      nextCustomNotifsTextSizeSp =
          await FloatingBallService.getCustomNotificationsTextSizeSp();
      nextCustomNotifsButtonsIconHeightDp =
          await FloatingBallService.getCustomNotificationsButtonsIconHeightDp();
      nextCustomNotifsDeleteIconId =
          await FloatingBallService.getCustomNotificationsDeleteIconId();
      nextCustomNotifsDeleteIconPngBase64 =
          await FloatingBallService.getCustomNotificationsDeleteIconPngBase64();
      nextCustomNotifsDeleteText =
          await FloatingBallService.getCustomNotificationsDeleteText();
      nextCustomNotifsButtonsHideText =
          await FloatingBallService.isCustomNotificationsButtonsHideTextEnabled();
      nextCustomNotifsButtonsHeightDp =
          await FloatingBallService.getCustomNotificationsButtonsHeightDp();
      nextCustomNotifsButtonsBgColor =
          await FloatingBallService.getCustomNotificationsButtonsBgColor();
      nextCustomNotifsButtonsBorderColor =
          await FloatingBallService.getCustomNotificationsButtonsBorderColor();
      nextCustomNotifsButtonsContentColor =
          await FloatingBallService.getCustomNotificationsButtonsContentColor();
      nextCustomNotifsCloseIconId =
          await FloatingBallService.getCustomNotificationsCloseIconId();
      nextCustomNotifsCloseIconPngBase64 =
          await FloatingBallService.getCustomNotificationsCloseIconPngBase64();
      nextCustomNotifsCloseText =
          await FloatingBallService.getCustomNotificationsCloseText();
      nextCustomNotifsClearAllIconId =
          await FloatingBallService.getCustomNotificationsClearAllIconId();
      nextCustomNotifsClearAllIconPngBase64 = await FloatingBallService
          .getCustomNotificationsClearAllIconPngBase64();
      nextCustomNotifsClearAllText =
          await FloatingBallService.getCustomNotificationsClearAllText();
      nextFsConversationEnabled =
          await FloatingBallService.isFullScreenConversationEnabled();
      nextConversationBgColor =
          await FloatingBallService.getConversationBgColor();
      nextConversationIncomingColor =
          await FloatingBallService.getConversationIncomingColor();
      nextConversationOutgoingColor =
          await FloatingBallService.getConversationOutgoingColor();
      nextConversationTextColor =
          await FloatingBallService.getConversationTextColor();
      nextConversationTextSizeSp =
          await FloatingBallService.getConversationTextSizeSp();
      nextConversationTitleColor =
          await FloatingBallService.getConversationTitleColor();
      nextConversationTitleSizeSp =
          await FloatingBallService.getConversationTitleSizeSp();
      nextConversationCloseHeightDp =
          await FloatingBallService.getConversationCloseHeightDp();
      nextConversationCloseBgColor =
          await FloatingBallService.getConversationCloseBgColor();
      nextConversationCloseTextColor =
          await FloatingBallService.getConversationCloseTextColor();
      nextConversationCloseBorderColor =
          await FloatingBallService.getConversationCloseBorderColor();
      nextConversationCloseHideText =
          await FloatingBallService.isConversationCloseHideTextEnabled();
      nextConversationCloseText =
          await FloatingBallService.getConversationCloseText();
      nextConversationCloseIconId =
          await FloatingBallService.getConversationCloseIconId();
      nextConversationCloseIconPngBase64 =
          await FloatingBallService.getConversationCloseIconPngBase64();
      nextConversationReplyHeightDp =
          await FloatingBallService.getConversationReplyHeightDp();
      nextConversationReplyBgColor =
          await FloatingBallService.getConversationReplyBgColor();
      nextConversationReplyTextColor =
          await FloatingBallService.getConversationReplyTextColor();
      nextConversationReplyBorderColor =
          await FloatingBallService.getConversationReplyBorderColor();
      nextConversationReplyHideText =
          await FloatingBallService.isConversationReplyHideTextEnabled();
      nextConversationReplyText =
          await FloatingBallService.getConversationReplyText();
      nextConversationReplyIconId =
          await FloatingBallService.getConversationReplyIconId();
      nextConversationReplyIconPngBase64 =
          await FloatingBallService.getConversationReplyIconPngBase64();
      nextConversationBottomButtonsGapDp =
          await FloatingBallService.getConversationBottomButtonsGapDp();
      nextConversationBottomButtonsPaddingHorzDp = await FloatingBallService
          .getConversationBottomButtonsPaddingHorzDp();
      nextConversationBottomButtonsPaddingVertDp = await FloatingBallService
          .getConversationBottomButtonsPaddingVertDp();
      nextConversationHeaderAppIconSizeDp =
          await FloatingBallService.getConversationHeaderAppIconSizeDp();
      nextConversationCloseIconSizeDp =
          await FloatingBallService.getConversationCloseIconSizeDp();
      nextConversationReplyIconSizeDp =
          await FloatingBallService.getConversationReplyIconSizeDp();
      nextConversationReplyModalBgColor =
          await FloatingBallService.getConversationReplyModalBgColor();
      nextConversationReplyModalTextColor =
          await FloatingBallService.getConversationReplyModalTextColor();
      nextConversationReplyModalTextSizeSp =
          await FloatingBallService.getConversationReplyModalTextSizeSp();
      nextConversationReplyModalSendIconId =
          await FloatingBallService.getConversationReplyModalSendIconId();
      nextConversationReplyModalSendIconPngBase64 = await FloatingBallService
          .getConversationReplyModalSendIconPngBase64();
      nextConversationReplyModalSendIconSizeDp =
          await FloatingBallService.getConversationReplyModalSendIconSizeDp();
      nextConversationReplyModalSendBgColor =
          await FloatingBallService.getConversationReplyModalSendBgColor();
      nextConversationReplyModalSendBorderColor =
          await FloatingBallService.getConversationReplyModalSendBorderColor();
      nextFsBarHeightDp = await FloatingBallService.getFullScreenBarHeightDp();
      nextFsBarBgColor = await FloatingBallService.getFullScreenBarBgColor();
      nextFsBarContentColor =
          await FloatingBallService.getFullScreenBarContentColor();
      nextFsBarIconSizeDp =
          await FloatingBallService.getFullScreenBarIconSizeDp();
      nextFsBarTextSizeSp =
          await FloatingBallService.getFullScreenBarTextSizeSp();
      nextFsBarPaddingHorzDp =
          await FloatingBallService.getFullScreenBarPaddingHorzDp();
      nextFsBarPaddingVertDp =
          await FloatingBallService.getFullScreenBarPaddingVertDp();
      nextFsBarTimeColor = await FloatingBallService.getFullScreenBarTimeColor();
      nextFsBarWifiIconColor =
          await FloatingBallService.getFullScreenBarWifiIconColor();
      nextFsBarBtIconColor = await FloatingBallService.getFullScreenBarBtIconColor();
      nextFsBarDataIconColor =
          await FloatingBallService.getFullScreenBarDataIconColor();
      nextFsBarLocIconColor = await FloatingBallService.getFullScreenBarLocIconColor();
      nextFsBarBatteryIconColor =
          await FloatingBallService.getFullScreenBarBatteryIconColor();
      nextFsBarBatteryTextColor =
          await FloatingBallService.getFullScreenBarBatteryTextColor();
      nextFsBarRestoreIconColor =
          await FloatingBallService.getFullScreenBarRestoreIconColor();
      nextFsBarRestoreBgColor =
          await FloatingBallService.getFullScreenBarRestoreBgColor();
      nextFsBarWifiIconId =
          await FloatingBallService.getFullScreenBarWifiIconId();
      nextFsBarWifiIconPngBase64 =
          await FloatingBallService.getFullScreenBarWifiIconPngBase64();
      nextFsBarBtIconId = await FloatingBallService.getFullScreenBarBtIconId();
      nextFsBarBtIconPngBase64 =
          await FloatingBallService.getFullScreenBarBtIconPngBase64();
      nextFsBarDataIconId =
          await FloatingBallService.getFullScreenBarDataIconId();
      nextFsBarDataIconPngBase64 =
          await FloatingBallService.getFullScreenBarDataIconPngBase64();
      nextFsBarLocIconId = await FloatingBallService.getFullScreenBarLocIconId();
      nextFsBarLocIconPngBase64 =
          await FloatingBallService.getFullScreenBarLocIconPngBase64();
      nextFsBarBatteryIconId =
          await FloatingBallService.getFullScreenBarBatteryIconId();
      nextFsBarBatteryIconPngBase64 =
          await FloatingBallService.getFullScreenBarBatteryIconPngBase64();
      nextFsBarMediaRestoreIconId =
          await FloatingBallService.getFullScreenBarMediaRestoreIconId();
      nextFsBarMediaRestoreIconPngBase64 =
          await FloatingBallService.getFullScreenBarMediaRestoreIconPngBase64();
      nextFsMediaAutoShow =
          await FloatingBallService.isFullScreenMediaAutoShowEnabled();
      nextFsCloseHeightDp = await FloatingBallService.getFullScreenCloseHeightDp();
      nextFsCloseBg = await FloatingBallService.getFullScreenCloseBgColor();
      nextFsCloseText = await FloatingBallService.getFullScreenCloseTextColor();
      nextFsCloseHideText =
          await FloatingBallService.isFullScreenCloseHideTextEnabled();
      nextFsCloseIconId = await FloatingBallService.getFullScreenCloseIconId();
      nextFsCloseIconPngBase64 =
          await FloatingBallService.getFullScreenCloseIconPngBase64();
      nextFsCloseSticky =
          await FloatingBallService.isFullScreenCloseStickyEnabled();
      nextFsCloseDisableStickyWhenMediaActive = await FloatingBallService
          .isFullScreenCloseDisableStickyWhenMediaActiveEnabled();
      nextFsCloseTextLabel = await FloatingBallService.getFullScreenCloseText();
      nextFsBackText = await FloatingBallService.getFullScreenBackText();
      nextFsHomeText = await FloatingBallService.getFullScreenHomeText();
      nextFsRecentsText = await FloatingBallService.getFullScreenRecentsText();
      nextFsVolumeText = await FloatingBallService.getFullScreenVolumeText();
      nextFsBrightnessText =
          await FloatingBallService.getFullScreenBrightnessText();
      nextFsSettingsText = await FloatingBallService.getFullScreenSettingsText();
      nextFsBackIconId = await FloatingBallService.getFullScreenBackIconId();
      nextFsHomeIconId = await FloatingBallService.getFullScreenHomeIconId();
      nextFsRecentsIconId = await FloatingBallService.getFullScreenRecentsIconId();
      nextFsVolumeIconId = await FloatingBallService.getFullScreenVolumeIconId();
      nextFsBrightnessIconId =
          await FloatingBallService.getFullScreenBrightnessIconId();
      nextFsSettingsIconId =
          await FloatingBallService.getFullScreenSettingsIconId();
      nextFsBackIconPngBase64 = await FloatingBallService.getFullScreenBackIconPngBase64();
      nextFsHomeIconPngBase64 = await FloatingBallService.getFullScreenHomeIconPngBase64();
      nextFsRecentsIconPngBase64 =
          await FloatingBallService.getFullScreenRecentsIconPngBase64();
      nextFsVolumeIconPngBase64 =
          await FloatingBallService.getFullScreenVolumeIconPngBase64();
      nextFsBrightnessIconPngBase64 =
          await FloatingBallService.getFullScreenBrightnessIconPngBase64();
      nextFsSettingsIconPngBase64 =
          await FloatingBallService.getFullScreenSettingsIconPngBase64();

      nextPopupBgColor = await FloatingBallService.getPopupBgColor();
      nextPopupButtonColor = await FloatingBallService.getPopupButtonColor();
      nextPopupIconColor = await FloatingBallService.getPopupIconColor();
      nextPopupIconSizeDp = await FloatingBallService.getPopupIconSizeDp();
      nextPopupOffsetXDp = await FloatingBallService.getPopupOffsetXDp();
      nextPopupOffsetYDp = await FloatingBallService.getPopupOffsetYDp();
      nextPopupMediaOffsetXDp = await FloatingBallService.getPopupMediaOffsetXDp();
      nextPopupMediaOffsetYDp = await FloatingBallService.getPopupMediaOffsetYDp();
      nextPopupBackIconId = await FloatingBallService.getPopupBackIconId();
      nextPopupHomeIconId = await FloatingBallService.getPopupHomeIconId();
      nextPopupRecentsIconId = await FloatingBallService.getPopupRecentsIconId();
      nextPopupVolumeIconId = await FloatingBallService.getPopupVolumeIconId();
      nextPopupBrightnessIconId = await FloatingBallService.getPopupBrightnessIconId();
      nextPopupSettingsIconId = await FloatingBallService.getPopupSettingsIconId();
      nextPopupBackIconPngBase64 = await FloatingBallService.getPopupBackIconPngBase64();
      nextPopupHomeIconPngBase64 = await FloatingBallService.getPopupHomeIconPngBase64();
      nextPopupRecentsIconPngBase64 = await FloatingBallService.getPopupRecentsIconPngBase64();
      nextPopupVolumeIconPngBase64 = await FloatingBallService.getPopupVolumeIconPngBase64();
      nextPopupBrightnessIconPngBase64 =
          await FloatingBallService.getPopupBrightnessIconPngBase64();
      nextPopupSettingsIconPngBase64 = await FloatingBallService.getPopupSettingsIconPngBase64();

      nextMediaHeightDp = await FloatingBallService.getMediaHeightDp();
      nextMediaIconSizeDp = await FloatingBallService.getMediaIconSizeDp();
      nextMediaTitleSizeSp = await FloatingBallService.getMediaTitleSizeSp();
      nextMediaSubtitleSizeSp = await FloatingBallService.getMediaSubtitleSizeSp();
      nextMediaVolumeIconId = await FloatingBallService.getMediaVolumeIconId();
      nextMediaPrevIconId = await FloatingBallService.getMediaPrevIconId();
      nextMediaPlayIconId = await FloatingBallService.getMediaPlayIconId();
      nextMediaPauseIconId = await FloatingBallService.getMediaPauseIconId();
      nextMediaNextIconId = await FloatingBallService.getMediaNextIconId();
      nextMediaVolumeIconPngBase64 =
          await FloatingBallService.getMediaVolumeIconPngBase64();
      nextMediaPrevIconPngBase64 =
          await FloatingBallService.getMediaPrevIconPngBase64();
      nextMediaPlayIconPngBase64 =
          await FloatingBallService.getMediaPlayIconPngBase64();
      nextMediaPauseIconPngBase64 =
          await FloatingBallService.getMediaPauseIconPngBase64();
      nextMediaNextIconPngBase64 =
          await FloatingBallService.getMediaNextIconPngBase64();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _mediaVisible = nextMediaVisible;
      _ballColor = nextBallColor;
      _ballIcon = nextBallIcon;
      _ballIconPngBase64 = nextBallIconPngBase64;
      _ballIconColor = nextBallIconColor;
      _ballIconSizeDp = nextBallIconSizeDp;
      _ballSizeDp = nextBallSizeDp;
      _fullScreen = nextFullScreen;
      _fsBgColor = nextFsBg;
      _fsButtonColor = nextFsBtn;
      _fsAppsButtonColor = nextFsAppsBtn;
      _fsContentColor = nextFsContent;
      _fsIconColor = nextFsIconColor;
      _fsTextColor = nextFsTextColor;
      _fsHideText = nextFsHideText;
      _fsIconSizeDp = nextFsIconSizeDp;
      _fsTextSizeSp = nextFsTextSizeSp;
      _fsTileGapDp = nextFsTileGapDp;
      _fsAppsTileGapDp = nextFsAppsTileGapDp;
      _fsTilePaddingDp = nextFsTilePaddingDp;
      _fsStickyPaddingDp = nextFsStickyPaddingDp;
      _fsTileInnerGapDp = nextFsTileInnerGapDp;
      _fsTileHeightDp = nextFsTileHeightDp;
      _fsAppsTileHeightDp = nextFsAppsTileHeightDp;
      _fsTileBorderColor = nextFsTileBorderColor;
      _fsAppsTileBorderColor = nextFsAppsTileBorderColor;
      _fsAppsIconSizeDp = nextFsAppsIconSizeDp;
      _fsContainerPaddingHorzDp = nextFsContainerPaddingHorzDp;
      _fsContainerPaddingVertDp = nextFsContainerPaddingVertDp;
      _fsSystemCols = nextFsSystemCols;
      _fsAppsCols = nextFsAppsCols;
      _fsBarEnabled = nextFsBarEnabled;
      _fsCustomNotificationsEnabled = nextFsCustomNotificationsEnabled;
      _fsConversationEnabled = nextFsConversationEnabled;
      _customNotifsBgColor = nextCustomNotifsBgColor;
      _customNotifsItemBgColor = nextCustomNotifsItemBgColor;
      _customNotifsItemBorderColor = nextCustomNotifsItemBorderColor;
      _customNotifsTitleColor = nextCustomNotifsTitleColor;
      _customNotifsTextColor = nextCustomNotifsTextColor;
      _customNotifsTitleSizeSp = nextCustomNotifsTitleSizeSp;
      _customNotifsTextSizeSp = nextCustomNotifsTextSizeSp;
      _customNotifsButtonsIconHeightDp = nextCustomNotifsButtonsIconHeightDp;
      _customNotifsDeleteIconId = nextCustomNotifsDeleteIconId;
      _customNotifsDeleteIconPngBase64 = nextCustomNotifsDeleteIconPngBase64;
      _customNotifsDeleteText = nextCustomNotifsDeleteText;
      _customNotifsButtonsHideText = nextCustomNotifsButtonsHideText;
      _customNotifsButtonsHeightDp = nextCustomNotifsButtonsHeightDp;
      _customNotifsButtonsBgColor = nextCustomNotifsButtonsBgColor;
      _customNotifsButtonsBorderColor = nextCustomNotifsButtonsBorderColor;
      _customNotifsButtonsContentColor = nextCustomNotifsButtonsContentColor;
      _customNotifsCloseIconId = nextCustomNotifsCloseIconId;
      _customNotifsCloseIconPngBase64 = nextCustomNotifsCloseIconPngBase64;
      _customNotifsCloseText = nextCustomNotifsCloseText;
      _customNotifsClearAllIconId = nextCustomNotifsClearAllIconId;
      _customNotifsClearAllIconPngBase64 = nextCustomNotifsClearAllIconPngBase64;
      _customNotifsClearAllText = nextCustomNotifsClearAllText;
      _conversationBgColor = nextConversationBgColor;
      _conversationIncomingColor = nextConversationIncomingColor;
      _conversationOutgoingColor = nextConversationOutgoingColor;
      _conversationTextColor = nextConversationTextColor;
      _conversationTextSizeSp = nextConversationTextSizeSp;
      _conversationTitleColor = nextConversationTitleColor;
      _conversationTitleSizeSp = nextConversationTitleSizeSp;
      _conversationCloseHeightDp = nextConversationCloseHeightDp;
      _conversationCloseBgColor = nextConversationCloseBgColor;
      _conversationCloseTextColor = nextConversationCloseTextColor;
      _conversationCloseBorderColor = nextConversationCloseBorderColor;
      _conversationCloseHideText = nextConversationCloseHideText;
      _conversationCloseText = nextConversationCloseText;
      _conversationCloseIconId = nextConversationCloseIconId;
      _conversationCloseIconPngBase64 = nextConversationCloseIconPngBase64;
      _conversationReplyHeightDp = nextConversationReplyHeightDp;
      _conversationReplyBgColor = nextConversationReplyBgColor;
      _conversationReplyTextColor = nextConversationReplyTextColor;
      _conversationReplyBorderColor = nextConversationReplyBorderColor;
      _conversationReplyHideText = nextConversationReplyHideText;
      _conversationReplyText = nextConversationReplyText;
      _conversationReplyIconId = nextConversationReplyIconId;
      _conversationReplyIconPngBase64 = nextConversationReplyIconPngBase64;
      _conversationBottomButtonsGapDp = nextConversationBottomButtonsGapDp;
      _conversationBottomButtonsPaddingHorzDp =
          nextConversationBottomButtonsPaddingHorzDp;
      _conversationBottomButtonsPaddingVertDp =
          nextConversationBottomButtonsPaddingVertDp;
      _conversationHeaderAppIconSizeDp = nextConversationHeaderAppIconSizeDp;
      _conversationCloseIconSizeDp = nextConversationCloseIconSizeDp;
      _conversationReplyIconSizeDp = nextConversationReplyIconSizeDp;
      _conversationReplyModalBgColor = nextConversationReplyModalBgColor;
      _conversationReplyModalTextColor = nextConversationReplyModalTextColor;
      _conversationReplyModalTextSizeSp = nextConversationReplyModalTextSizeSp;
      _conversationReplyModalSendIconId = nextConversationReplyModalSendIconId;
      _conversationReplyModalSendIconPngBase64 =
          nextConversationReplyModalSendIconPngBase64;
      _conversationReplyModalSendIconSizeDp =
          nextConversationReplyModalSendIconSizeDp;
      _conversationReplyModalSendBgColor = nextConversationReplyModalSendBgColor;
      _conversationReplyModalSendBorderColor =
          nextConversationReplyModalSendBorderColor;
      _fsBarHeightDp = nextFsBarHeightDp;
      _fsBarBgColor = nextFsBarBgColor;
      _fsBarContentColor = nextFsBarContentColor;
      _fsBarIconSizeDp = nextFsBarIconSizeDp;
      _fsBarTextSizeSp = nextFsBarTextSizeSp;
      _fsBarPaddingHorzDp = nextFsBarPaddingHorzDp;
      _fsBarPaddingVertDp = nextFsBarPaddingVertDp;
      _fsBarTimeColor = nextFsBarTimeColor;
      _fsBarWifiIconColor = nextFsBarWifiIconColor;
      _fsBarBtIconColor = nextFsBarBtIconColor;
      _fsBarDataIconColor = nextFsBarDataIconColor;
      _fsBarLocIconColor = nextFsBarLocIconColor;
      _fsBarBatteryIconColor = nextFsBarBatteryIconColor;
      _fsBarBatteryTextColor = nextFsBarBatteryTextColor;
      _fsBarRestoreIconColor = nextFsBarRestoreIconColor;
      _fsBarRestoreBgColor = nextFsBarRestoreBgColor;
      _fsBarWifiIconId = nextFsBarWifiIconId;
      _fsBarWifiIconPngBase64 = nextFsBarWifiIconPngBase64;
      _fsBarBtIconId = nextFsBarBtIconId;
      _fsBarBtIconPngBase64 = nextFsBarBtIconPngBase64;
      _fsBarDataIconId = nextFsBarDataIconId;
      _fsBarDataIconPngBase64 = nextFsBarDataIconPngBase64;
      _fsBarLocIconId = nextFsBarLocIconId;
      _fsBarLocIconPngBase64 = nextFsBarLocIconPngBase64;
      _fsBarBatteryIconId = nextFsBarBatteryIconId;
      _fsBarBatteryIconPngBase64 = nextFsBarBatteryIconPngBase64;
      _fsBarMediaRestoreIconId = nextFsBarMediaRestoreIconId;
      _fsBarMediaRestoreIconPngBase64 = nextFsBarMediaRestoreIconPngBase64;
      _fsMediaAutoShow = nextFsMediaAutoShow;
      _fsCloseHeightDp = nextFsCloseHeightDp;
      _fsCloseBgColor = nextFsCloseBg;
      _fsCloseTextColor = nextFsCloseText;
      _fsCloseHideText = nextFsCloseHideText;
      _fsCloseIconId = nextFsCloseIconId;
      _fsCloseIconPngBase64 = nextFsCloseIconPngBase64;
      _fsCloseSticky = nextFsCloseSticky;
      _fsCloseDisableStickyWhenMediaActive =
          nextFsCloseDisableStickyWhenMediaActive;
      _fsCloseText = nextFsCloseTextLabel;
      _fsBackText = nextFsBackText;
      _fsHomeText = nextFsHomeText;
      _fsRecentsText = nextFsRecentsText;
      _fsVolumeText = nextFsVolumeText;
      _fsBrightnessText = nextFsBrightnessText;
      _fsSettingsText = nextFsSettingsText;
      _fsBackIconId = nextFsBackIconId;
      _fsHomeIconId = nextFsHomeIconId;
      _fsRecentsIconId = nextFsRecentsIconId;
      _fsVolumeIconId = nextFsVolumeIconId;
      _fsBrightnessIconId = nextFsBrightnessIconId;
      _fsSettingsIconId = nextFsSettingsIconId;
      _fsBackIconPngBase64 = nextFsBackIconPngBase64;
      _fsHomeIconPngBase64 = nextFsHomeIconPngBase64;
      _fsRecentsIconPngBase64 = nextFsRecentsIconPngBase64;
      _fsVolumeIconPngBase64 = nextFsVolumeIconPngBase64;
      _fsBrightnessIconPngBase64 = nextFsBrightnessIconPngBase64;
      _fsSettingsIconPngBase64 = nextFsSettingsIconPngBase64;
      _popupBgColor = nextPopupBgColor;
      _popupButtonColor = nextPopupButtonColor;
      _popupIconColor = nextPopupIconColor;
      _popupIconSizeDp = nextPopupIconSizeDp;
      _popupOffsetXDp = nextPopupOffsetXDp;
      _popupOffsetYDp = nextPopupOffsetYDp;
      _popupMediaOffsetXDp = nextPopupMediaOffsetXDp;
      _popupMediaOffsetYDp = nextPopupMediaOffsetYDp;
      _popupBackIconId = nextPopupBackIconId;
      _popupHomeIconId = nextPopupHomeIconId;
      _popupRecentsIconId = nextPopupRecentsIconId;
      _popupVolumeIconId = nextPopupVolumeIconId;
      _popupBrightnessIconId = nextPopupBrightnessIconId;
      _popupSettingsIconId = nextPopupSettingsIconId;
      _popupBackIconPngBase64 = nextPopupBackIconPngBase64;
      _popupHomeIconPngBase64 = nextPopupHomeIconPngBase64;
      _popupRecentsIconPngBase64 = nextPopupRecentsIconPngBase64;
      _popupVolumeIconPngBase64 = nextPopupVolumeIconPngBase64;
      _popupBrightnessIconPngBase64 = nextPopupBrightnessIconPngBase64;
      _popupSettingsIconPngBase64 = nextPopupSettingsIconPngBase64;
      _mediaHeightDp = nextMediaHeightDp;
      _mediaIconSizeDp = nextMediaIconSizeDp;
      _mediaTitleSizeSp = nextMediaTitleSizeSp;
      _mediaSubtitleSizeSp = nextMediaSubtitleSizeSp;
      _mediaVolumeIconId = nextMediaVolumeIconId;
      _mediaPrevIconId = nextMediaPrevIconId;
      _mediaPlayIconId = nextMediaPlayIconId;
      _mediaPauseIconId = nextMediaPauseIconId;
      _mediaNextIconId = nextMediaNextIconId;
      _mediaVolumeIconPngBase64 = nextMediaVolumeIconPngBase64;
      _mediaPrevIconPngBase64 = nextMediaPrevIconPngBase64;
      _mediaPlayIconPngBase64 = nextMediaPlayIconPngBase64;
      _mediaPauseIconPngBase64 = nextMediaPauseIconPngBase64;
      _mediaNextIconPngBase64 = nextMediaNextIconPngBase64;
      _loading = false;
    });
  }

  String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<int?> _showColorPickerInt({
    required int currentArgb,
    required String title,
    required String label,
  }) async {
    Color? picked;
    return Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) {
          final viewInsets = MediaQuery.of(context).viewInsets;
          return Scaffold(
            appBar: AppBar(
              title: Text(title),
              backgroundColor: customColor[600],
              foregroundColor: Colors.white,
            ),
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 26,
                  top: 12,
                  bottom: 16 + viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ColorInputWidget(
                        initialColor: _colorToHex(Color(currentArgb)),
                        label: label,
                        onColorChanged: (_) {},
                        onParsedColorChanged: (c) => picked = c,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final c = picked;
                                if (c == null) return;
                                Navigator.of(context).pop(c.toARGB32());
                              },
                              child: const Text('Guardar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _colorDot(Color c) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    );
  }

  Future<void> _setBallColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _ballColor,
      title: 'Color de la bola',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _ballColor = picked);
    await FloatingBallService.setBallColor(picked);
  }

  Future<int?> _showIntSlider({
    required String title,
    required int current,
    required int min,
    required int max,
    required String suffix,
  }) async {
    int v = current.clamp(min, max);
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: v.toDouble(),
                            min: min.toDouble(),
                            max: max.toDouble(),
                            onChanged: (nv) => setModalState(() => v = nv.round()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$v$suffix'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, v),
                            child: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _showTextDialog({
    required String title,
    required String current,
  }) async {
    final c = TextEditingController(text: current);
    final res = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    return res;
  }

  Future<void> _setBallIconColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _ballIconColor,
      title: 'Color del icono de la bola',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _ballIconColor = picked);
    await FloatingBallService.setBallIconColor(picked);
  }

  Future<void> _setBallIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño del icono (bola)',
      current: _ballIconSizeDp,
      min: 10,
      max: 56,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _ballIconSizeDp = picked);
    await FloatingBallService.setBallIconSizeDp(picked);
  }

  Future<void> _setBallSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de la bola',
      current: _ballSizeDp,
      min: 36,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _ballSizeDp = picked);
    await FloatingBallService.setBallSizeDp(picked);
  }

  Future<void> _setPopupBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _popupBgColor,
      title: 'Color de fondo (popup)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _popupBgColor = picked);
    await FloatingBallService.setPopupBgColor(picked);
  }

  Future<void> _setPopupButtonColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _popupButtonColor,
      title: 'Color de botones (popup)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _popupButtonColor = picked);
    await FloatingBallService.setPopupButtonColor(picked);
  }

  Future<void> _setPopupIconColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _popupIconColor,
      title: 'Color de iconos (popup)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _popupIconColor = picked);
    await FloatingBallService.setPopupIconColor(picked);
  }

  Future<void> _setPopupIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de iconos (popup)',
      current: _popupIconSizeDp,
      min: 10,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _popupIconSizeDp = picked);
    await FloatingBallService.setPopupIconSizeDp(picked);
  }

  Future<void> _setPopupOffsetX() async {
    final picked = await _showIntSlider(
      title: 'Offset X (popup)',
      current: _popupOffsetXDp,
      min: -300,
      max: 300,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _popupOffsetXDp = picked);
    await FloatingBallService.setPopupOffsetXDp(picked);
  }

  Future<void> _setPopupOffsetY() async {
    final picked = await _showIntSlider(
      title: 'Offset Y (popup)',
      current: _popupOffsetYDp,
      min: -300,
      max: 300,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _popupOffsetYDp = picked);
    await FloatingBallService.setPopupOffsetYDp(picked);
  }

  Future<void> _setPopupMediaOffsetX() async {
    final picked = await _showIntSlider(
      title: 'Offset X (popup multimedia)',
      current: _popupMediaOffsetXDp,
      min: -400,
      max: 400,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _popupMediaOffsetXDp = picked);
    await FloatingBallService.setPopupMediaOffsetXDp(picked);
  }

  Future<void> _setPopupMediaOffsetY() async {
    final picked = await _showIntSlider(
      title: 'Offset Y (popup multimedia)',
      current: _popupMediaOffsetYDp,
      min: -600,
      max: 600,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _popupMediaOffsetYDp = picked);
    await FloatingBallService.setPopupMediaOffsetYDp(picked);
  }

  Future<void> _setFsBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBgColor,
      title: 'Color de fondo',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBgColor = picked);
    await FloatingBallService.setFullScreenBgColor(picked);
  }

  Future<void> _setFsButtonColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsButtonColor,
      title: 'Color de botones',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsButtonColor = picked);
    await FloatingBallService.setFullScreenButtonColor(picked);
  }

  Future<void> _setFsAppsButtonColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsAppsButtonColor,
      title: 'Color de botones (apps)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsAppsButtonColor = picked);
    await FloatingBallService.setFullScreenAppsButtonColor(picked);
  }

  Future<void> _setFsContentColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsContentColor,
      title: 'Color de iconos/textos',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsContentColor = picked);
    await FloatingBallService.setFullScreenContentColor(picked);
  }

  Future<void> _setFsIconColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsIconColor,
      title: 'Color de iconos',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsIconColor = picked);
    await FloatingBallService.setFullScreenIconColor(picked);
  }

  Future<void> _setFsTextColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsTextColor,
      title: 'Color de textos',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsTextColor = picked);
    await FloatingBallService.setFullScreenTextColor(picked);
  }

  Future<void> _toggleFsHideText(bool v) async {
    setState(() => _fsHideText = v);
    await FloatingBallService.setFullScreenHideTextEnabled(v);
  }

  Future<void> _toggleFsBarEnabled(bool v) async {
    setState(() => _fsBarEnabled = v);
    await FloatingBallService.setFullScreenBarEnabled(v);
  }

  Future<void> _toggleFsCustomNotificationsEnabled(bool v) async {
    setState(() => _fsCustomNotificationsEnabled = v);
    await FloatingBallService.setFullScreenCustomNotificationsEnabled(v);
  }

  Future<void> _toggleFsConversationEnabled(bool v) async {
    setState(() => _fsConversationEnabled = v);
    await FloatingBallService.setFullScreenConversationEnabled(v);
  }

  Future<void> _setCustomNotifsBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _customNotifsBgColor,
      title: 'Color de fondo (pantalla)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _customNotifsBgColor = picked);
    await FloatingBallService.setCustomNotificationsBgColor(picked);
  }

  Future<void> _setConversationBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationBgColor,
      title: 'Color de fondo (conversación)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationBgColor = picked);
    await FloatingBallService.setConversationBgColor(picked);
  }

  Future<void> _setCustomNotifsItemBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _customNotifsItemBgColor,
      title: 'Color de fondo (notificación)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _customNotifsItemBgColor = picked);
    await FloatingBallService.setCustomNotificationsItemBgColor(picked);
  }

  Future<void> _setConversationIncomingColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationIncomingColor,
      title: 'Color burbuja recibida',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationIncomingColor = picked);
    await FloatingBallService.setConversationIncomingColor(picked);
  }

  Future<void> _setCustomNotifsItemBorderColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _customNotifsItemBorderColor,
      title: 'Color de borde (notificación)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _customNotifsItemBorderColor = picked);
    await FloatingBallService.setCustomNotificationsItemBorderColor(picked);
  }

  Future<void> _setConversationOutgoingColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationOutgoingColor,
      title: 'Color burbuja enviada',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationOutgoingColor = picked);
    await FloatingBallService.setConversationOutgoingColor(picked);
  }

  Future<void> _setCustomNotifsTitleColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _customNotifsTitleColor,
      title: 'Color de título (notificación)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _customNotifsTitleColor = picked);
    await FloatingBallService.setCustomNotificationsTitleColor(picked);
  }

  Future<void> _setCustomNotifsTextColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _customNotifsTextColor,
      title: 'Color de texto (notificación)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _customNotifsTextColor = picked);
    await FloatingBallService.setCustomNotificationsTextColor(picked);
  }

  Future<void> _setConversationTextColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationTextColor,
      title: 'Color de texto (conversación)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationTextColor = picked);
    await FloatingBallService.setConversationTextColor(picked);
  }

  Future<void> _setCustomNotifsTitleSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de título (notificación)',
      current: _customNotifsTitleSizeSp,
      min: 8,
      max: 32,
      suffix: 'sp',
    );
    if (picked == null) return;
    setState(() => _customNotifsTitleSizeSp = picked);
    await FloatingBallService.setCustomNotificationsTitleSizeSp(picked);
  }

  Future<void> _setCustomNotifsTextSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de texto (notificación)',
      current: _customNotifsTextSizeSp,
      min: 8,
      max: 32,
      suffix: 'sp',
    );
    if (picked == null) return;
    setState(() => _customNotifsTextSizeSp = picked);
    await FloatingBallService.setCustomNotificationsTextSizeSp(picked);
  }

  Future<void> _setConversationTextSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de texto (conversación)',
      current: _conversationTextSizeSp,
      min: 8,
      max: 32,
      suffix: 'sp',
    );
    if (picked == null) return;
    setState(() => _conversationTextSizeSp = picked);
    await FloatingBallService.setConversationTextSizeSp(picked);
  }

  Future<void> _setConversationTitleColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationTitleColor,
      title: 'Color de título (conversación)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationTitleColor = picked);
    await FloatingBallService.setConversationTitleColor(picked);
  }

  Future<void> _setConversationTitleSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de título (conversación)',
      current: _conversationTitleSizeSp,
      min: 10,
      max: 32,
      suffix: 'sp',
    );
    if (picked == null) return;
    setState(() => _conversationTitleSizeSp = picked);
    await FloatingBallService.setConversationTitleSizeSp(picked);
  }

  Future<void> _setConversationCloseHeight() async {
    final picked = await _showIntSlider(
      title: 'Altura (botón Cerrar)',
      current: _conversationCloseHeightDp,
      min: 36,
      max: 160,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _conversationCloseHeightDp = picked);
    await FloatingBallService.setConversationCloseHeightDp(picked);
  }

  Future<void> _setConversationCloseBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationCloseBgColor,
      title: 'Color (botón Cerrar)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationCloseBgColor = picked);
    await FloatingBallService.setConversationCloseBgColor(picked);
  }

  Future<void> _setConversationCloseTextColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationCloseTextColor,
      title: 'Color de texto/icono (Cerrar)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationCloseTextColor = picked);
    await FloatingBallService.setConversationCloseTextColor(picked);
  }

  Future<void> _setConversationCloseBorderColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationCloseBorderColor,
      title: 'Color de borde (Cerrar)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationCloseBorderColor = picked);
    await FloatingBallService.setConversationCloseBorderColor(picked);
  }

  Future<void> _toggleConversationCloseHideText(bool v) async {
    setState(() => _conversationCloseHideText = v);
    await FloatingBallService.setConversationCloseHideTextEnabled(v);
  }

  Future<void> _setConversationCloseText() async {
    final picked = await _showTextDialog(
      title: 'Texto (Cerrar)',
      current: _conversationCloseText,
    );
    if (picked == null) return;
    setState(() => _conversationCloseText = picked);
    await FloatingBallService.setConversationCloseText(picked);
  }

  Future<void> _pickConversationCloseIcon() async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png = await _renderSvgFilePngBase64(
        entry.filePath,
        sizePx: 128,
        color: Colors.white,
      );
      if (png == null) return;
      await FloatingBallService.setConversationCloseIconWithPng(
        iconId: 'svg',
        iconPngBase64: png,
      );
      setState(() {
        _conversationCloseIconId = 'svg';
        _conversationCloseIconPngBase64 = png;
      });
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await FloatingBallService.setConversationCloseIconWithPng(
      iconId: id,
      iconPngBase64: png,
    );
    setState(() {
      _conversationCloseIconId = id;
      _conversationCloseIconPngBase64 = png;
    });
  }

  Future<void> _setConversationReplyHeight() async {
    final picked = await _showIntSlider(
      title: 'Altura (botón Responder)',
      current: _conversationReplyHeightDp,
      min: 36,
      max: 160,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _conversationReplyHeightDp = picked);
    await FloatingBallService.setConversationReplyHeightDp(picked);
  }

  Future<void> _setConversationReplyBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationReplyBgColor,
      title: 'Color (botón Responder)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationReplyBgColor = picked);
    await FloatingBallService.setConversationReplyBgColor(picked);
  }

  Future<void> _setConversationReplyTextColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationReplyTextColor,
      title: 'Color de texto/icono (Responder)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationReplyTextColor = picked);
    await FloatingBallService.setConversationReplyTextColor(picked);
  }

  Future<void> _setConversationReplyBorderColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationReplyBorderColor,
      title: 'Color de borde (Responder)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationReplyBorderColor = picked);
    await FloatingBallService.setConversationReplyBorderColor(picked);
  }

  Future<void> _setConversationBottomButtonsGap() async {
    final picked = await _showIntSlider(
      title: 'Espacio entre botones (inferiores)',
      current: _conversationBottomButtonsGapDp,
      min: 0,
      max: 60,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _conversationBottomButtonsGapDp = picked);
    await FloatingBallService.setConversationBottomButtonsGapDp(picked);
  }

  Future<void> _setConversationBottomButtonsPaddingHorz() async {
    final picked = await _showIntSlider(
      title: 'Padding horizontal (contenedor botones inferiores)',
      current: _conversationBottomButtonsPaddingHorzDp,
      min: 0,
      max: 60,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _conversationBottomButtonsPaddingHorzDp = picked);
    await FloatingBallService.setConversationBottomButtonsPaddingHorzDp(picked);
  }

  Future<void> _setConversationBottomButtonsPaddingVert() async {
    final picked = await _showIntSlider(
      title: 'Padding vertical (contenedor botones inferiores)',
      current: _conversationBottomButtonsPaddingVertDp,
      min: 0,
      max: 60,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _conversationBottomButtonsPaddingVertDp = picked);
    await FloatingBallService.setConversationBottomButtonsPaddingVertDp(picked);
  }

  Future<void> _toggleConversationReplyHideText(bool v) async {
    setState(() => _conversationReplyHideText = v);
    await FloatingBallService.setConversationReplyHideTextEnabled(v);
  }

  Future<void> _setConversationReplyText() async {
    final picked = await _showTextDialog(
      title: 'Texto (Responder)',
      current: _conversationReplyText,
    );
    if (picked == null) return;
    setState(() => _conversationReplyText = picked);
    await FloatingBallService.setConversationReplyText(picked);
  }

  Future<void> _pickConversationReplyIcon() async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png = await _renderSvgFilePngBase64(
        entry.filePath,
        sizePx: 128,
        color: Colors.white,
      );
      if (png == null) return;
      await FloatingBallService.setConversationReplyIconWithPng(
        iconId: 'svg',
        iconPngBase64: png,
      );
      setState(() {
        _conversationReplyIconId = 'svg';
        _conversationReplyIconPngBase64 = png;
      });
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await FloatingBallService.setConversationReplyIconWithPng(
      iconId: id,
      iconPngBase64: png,
    );
    setState(() {
      _conversationReplyIconId = id;
      _conversationReplyIconPngBase64 = png;
    });
  }

  Future<void> _setConversationHeaderAppIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño icono de app (header)',
      current: _conversationHeaderAppIconSizeDp,
      min: 12,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _conversationHeaderAppIconSizeDp = picked);
    await FloatingBallService.setConversationHeaderAppIconSizeDp(picked);
  }

  Future<void> _setConversationCloseIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño icono (Cerrar)',
      current: _conversationCloseIconSizeDp,
      min: 10,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _conversationCloseIconSizeDp = picked);
    await FloatingBallService.setConversationCloseIconSizeDp(picked);
  }

  Future<void> _setConversationReplyIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño icono (Responder)',
      current: _conversationReplyIconSizeDp,
      min: 10,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _conversationReplyIconSizeDp = picked);
    await FloatingBallService.setConversationReplyIconSizeDp(picked);
  }

  Future<void> _setConversationReplyModalBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationReplyModalBgColor,
      title: 'Color de fondo (modal Responder)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationReplyModalBgColor = picked);
    await FloatingBallService.setConversationReplyModalBgColor(picked);
  }

  Future<void> _setConversationReplyModalTextColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationReplyModalTextColor,
      title: 'Color de texto (modal Responder)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationReplyModalTextColor = picked);
    await FloatingBallService.setConversationReplyModalTextColor(picked);
  }

  Future<void> _setConversationReplyModalTextSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de texto (modal Responder)',
      current: _conversationReplyModalTextSizeSp,
      min: 8,
      max: 32,
      suffix: 'sp',
    );
    if (picked == null) return;
    setState(() => _conversationReplyModalTextSizeSp = picked);
    await FloatingBallService.setConversationReplyModalTextSizeSp(picked);
  }

  Future<void> _pickConversationReplyModalSendIcon() async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png = await _renderSvgFilePngBase64(
        entry.filePath,
        sizePx: 128,
        color: Colors.white,
      );
      if (png == null) return;
      await FloatingBallService.setConversationReplyModalSendIconWithPng(
        iconId: 'svg',
        iconPngBase64: png,
      );
      setState(() {
        _conversationReplyModalSendIconId = 'svg';
        _conversationReplyModalSendIconPngBase64 = png;
      });
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await FloatingBallService.setConversationReplyModalSendIconWithPng(
      iconId: id,
      iconPngBase64: png,
    );
    setState(() {
      _conversationReplyModalSendIconId = id;
      _conversationReplyModalSendIconPngBase64 = png;
    });
  }

  Future<void> _setConversationReplyModalSendIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño icono (Enviar)',
      current: _conversationReplyModalSendIconSizeDp,
      min: 10,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _conversationReplyModalSendIconSizeDp = picked);
    await FloatingBallService.setConversationReplyModalSendIconSizeDp(picked);
  }

  Future<void> _setConversationReplyModalSendBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationReplyModalSendBgColor,
      title: 'Color de fondo (Enviar)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationReplyModalSendBgColor = picked);
    await FloatingBallService.setConversationReplyModalSendBgColor(picked);
  }

  Future<void> _setConversationReplyModalSendBorderColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _conversationReplyModalSendBorderColor,
      title: 'Color de borde (Enviar)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _conversationReplyModalSendBorderColor = picked);
    await FloatingBallService.setConversationReplyModalSendBorderColor(picked);
  }

  Future<void> _setCustomNotifsButtonsIconHeight() async {
    final picked = await _showIntSlider(
      title: 'Altura de iconos (botones inferiores)',
      current: _customNotifsButtonsIconHeightDp,
      min: 18,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _customNotifsButtonsIconHeightDp = picked);
    await FloatingBallService.setCustomNotificationsButtonsIconHeightDp(picked);
  }

  Future<void> _toggleCustomNotifsButtonsHideText(bool v) async {
    setState(() => _customNotifsButtonsHideText = v);
    await FloatingBallService.setCustomNotificationsButtonsHideTextEnabled(v);
  }

  Future<void> _setCustomNotifsButtonsHeight() async {
    final picked = await _showIntSlider(
      title: 'Altura (botones inferiores)',
      current: _customNotifsButtonsHeightDp,
      min: 36,
      max: 160,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _customNotifsButtonsHeightDp = picked);
    await FloatingBallService.setCustomNotificationsButtonsHeightDp(picked);
  }

  Future<void> _setCustomNotifsButtonsBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _customNotifsButtonsBgColor,
      title: 'Color de fondo (botones inferiores)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _customNotifsButtonsBgColor = picked);
    await FloatingBallService.setCustomNotificationsButtonsBgColor(picked);
  }

  Future<void> _setCustomNotifsButtonsBorderColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _customNotifsButtonsBorderColor,
      title: 'Color de borde (botones inferiores)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _customNotifsButtonsBorderColor = picked);
    await FloatingBallService.setCustomNotificationsButtonsBorderColor(picked);
  }

  Future<void> _setCustomNotifsButtonsContentColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _customNotifsButtonsContentColor,
      title: 'Color de iconos/texto (botones inferiores)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _customNotifsButtonsContentColor = picked);
    await FloatingBallService.setCustomNotificationsButtonsContentColor(picked);
  }

  Future<void> _setCustomNotifsDeleteText() async {
    final picked = await _showTextDialog(
      title: 'Texto del botón Eliminar',
      current: _customNotifsDeleteText,
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => _customNotifsDeleteText = picked);
    await FloatingBallService.setCustomNotificationsDeleteText(picked);
  }

  Future<void> _pickCustomNotifsDeleteIcon() async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png =
          await _renderSvgFilePngBase64(entry.filePath, sizePx: 128, color: Colors.white);
      if (png == null) return;
      await FloatingBallService.setCustomNotificationsDeleteIconWithPng(
        iconId: 'svg',
        iconPngBase64: png,
      );
      setState(() {
        _customNotifsDeleteIconId = 'svg';
        _customNotifsDeleteIconPngBase64 = png;
      });
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await FloatingBallService.setCustomNotificationsDeleteIconWithPng(
      iconId: id,
      iconPngBase64: png,
    );
    setState(() {
      _customNotifsDeleteIconId = id;
      _customNotifsDeleteIconPngBase64 = png;
    });
  }

  Future<void> _setCustomNotifsCloseText() async {
    final picked = await _showTextDialog(
      title: 'Texto del botón Cerrar',
      current: _customNotifsCloseText,
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => _customNotifsCloseText = picked);
    await FloatingBallService.setCustomNotificationsCloseText(picked);
  }

  Future<void> _pickCustomNotifsCloseIcon() async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png =
          await _renderSvgFilePngBase64(entry.filePath, sizePx: 128, color: Colors.white);
      if (png == null) return;
      await FloatingBallService.setCustomNotificationsCloseIconWithPng(
        iconId: 'svg',
        iconPngBase64: png,
      );
      setState(() {
        _customNotifsCloseIconId = 'svg';
        _customNotifsCloseIconPngBase64 = png;
      });
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await FloatingBallService.setCustomNotificationsCloseIconWithPng(
      iconId: id,
      iconPngBase64: png,
    );
    setState(() {
      _customNotifsCloseIconId = id;
      _customNotifsCloseIconPngBase64 = png;
    });
  }

  Future<void> _setCustomNotifsClearAllText() async {
    final picked = await _showTextDialog(
      title: 'Texto del botón Eliminar todo',
      current: _customNotifsClearAllText,
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => _customNotifsClearAllText = picked);
    await FloatingBallService.setCustomNotificationsClearAllText(picked);
  }

  Future<void> _pickCustomNotifsClearAllIcon() async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png =
          await _renderSvgFilePngBase64(entry.filePath, sizePx: 128, color: Colors.white);
      if (png == null) return;
      await FloatingBallService.setCustomNotificationsClearAllIconWithPng(
        iconId: 'svg',
        iconPngBase64: png,
      );
      setState(() {
        _customNotifsClearAllIconId = 'svg';
        _customNotifsClearAllIconPngBase64 = png;
      });
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await FloatingBallService.setCustomNotificationsClearAllIconWithPng(
      iconId: id,
      iconPngBase64: png,
    );
    setState(() {
      _customNotifsClearAllIconId = id;
      _customNotifsClearAllIconPngBase64 = png;
    });
  }

  Future<void> _toggleFsMediaAutoShow(bool v) async {
    setState(() => _fsMediaAutoShow = v);
    await FloatingBallService.setFullScreenMediaAutoShowEnabled(v);
  }

  Future<void> _setFsBarHeight() async {
    final picked = await _showIntSlider(
      title: 'Altura de la Barra',
      current: _fsBarHeightDp,
      min: 36,
      max: 160,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsBarHeightDp = picked);
    await FloatingBallService.setFullScreenBarHeightDp(picked);
  }

  Future<void> _setFsBarBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarBgColor,
      title: 'Color de fondo (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarBgColor = picked);
    await FloatingBallService.setFullScreenBarBgColor(picked);
  }

  Future<void> _setFsBarContentColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarContentColor,
      title: 'Color de contenido (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarContentColor = picked);
    await FloatingBallService.setFullScreenBarContentColor(picked);
  }

  Future<void> _setFsBarIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de iconos (Barra)',
      current: _fsBarIconSizeDp,
      min: 10,
      max: 64,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsBarIconSizeDp = picked);
    await FloatingBallService.setFullScreenBarIconSizeDp(picked);
  }

  Future<void> _setFsBarTextSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de texto (Barra)',
      current: _fsBarTextSizeSp,
      min: 8,
      max: 32,
      suffix: 'sp',
    );
    if (picked == null) return;
    setState(() => _fsBarTextSizeSp = picked);
    await FloatingBallService.setFullScreenBarTextSizeSp(picked);
  }

  Future<void> _setFsBarPaddingHorz() async {
    final picked = await _showIntSlider(
      title: 'Padding horizontal (Barra)',
      current: _fsBarPaddingHorzDp,
      min: 0,
      max: 200,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsBarPaddingHorzDp = picked);
    await FloatingBallService.setFullScreenBarPaddingHorzDp(picked);
  }

  Future<void> _setFsBarPaddingVert() async {
    final picked = await _showIntSlider(
      title: 'Padding vertical (Barra)',
      current: _fsBarPaddingVertDp,
      min: 0,
      max: 30,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsBarPaddingVertDp = picked);
    await FloatingBallService.setFullScreenBarPaddingVertDp(picked);
  }

  Future<void> _setFsBarTimeColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarTimeColor,
      title: 'Color de la hora (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarTimeColor = picked);
    await FloatingBallService.setFullScreenBarTimeColor(picked);
  }

  Future<void> _setFsBarWifiIconColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarWifiIconColor,
      title: 'Color icono Wifi (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarWifiIconColor = picked);
    await FloatingBallService.setFullScreenBarWifiIconColor(picked);
  }

  Future<void> _setFsBarBtIconColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarBtIconColor,
      title: 'Color icono Bluetooth (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarBtIconColor = picked);
    await FloatingBallService.setFullScreenBarBtIconColor(picked);
  }

  Future<void> _setFsBarDataIconColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarDataIconColor,
      title: 'Color icono Datos (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarDataIconColor = picked);
    await FloatingBallService.setFullScreenBarDataIconColor(picked);
  }

  Future<void> _setFsBarLocIconColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarLocIconColor,
      title: 'Color icono Ubicación (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarLocIconColor = picked);
    await FloatingBallService.setFullScreenBarLocIconColor(picked);
  }

  Future<void> _setFsBarBatteryIconColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarBatteryIconColor,
      title: 'Color icono Batería (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarBatteryIconColor = picked);
    await FloatingBallService.setFullScreenBarBatteryIconColor(picked);
  }

  Future<void> _setFsBarBatteryTextColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarBatteryTextColor,
      title: 'Color texto Batería (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarBatteryTextColor = picked);
    await FloatingBallService.setFullScreenBarBatteryTextColor(picked);
  }

  Future<void> _setFsBarRestoreIconColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarRestoreIconColor,
      title: 'Color icono Restaurar (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarRestoreIconColor = picked);
    await FloatingBallService.setFullScreenBarRestoreIconColor(picked);
  }

  Future<void> _setFsBarRestoreBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsBarRestoreBgColor,
      title: 'Color fondo Restaurar (Barra)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsBarRestoreBgColor = picked);
    await FloatingBallService.setFullScreenBarRestoreBgColor(picked);
  }

  Future<void> _pickFsBarIcon(String which) async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png =
          await _renderSvgFilePngBase64(entry.filePath, sizePx: 128, color: Colors.white);
      if (png == null) return;
      await _applyFsBarIconWithPng(which: which, iconId: 'svg', png: png);
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await _applyFsBarIconWithPng(which: which, iconId: id, png: png);
  }

  Future<void> _applyFsBarIconWithPng({
    required String which,
    required String iconId,
    required String? png,
  }) async {
    if (which == 'wifi') {
      await FloatingBallService.setFullScreenBarWifiIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _fsBarWifiIconId = iconId;
        _fsBarWifiIconPngBase64 = png;
      });
    } else if (which == 'bt') {
      await FloatingBallService.setFullScreenBarBtIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _fsBarBtIconId = iconId;
        _fsBarBtIconPngBase64 = png;
      });
    } else if (which == 'data') {
      await FloatingBallService.setFullScreenBarDataIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _fsBarDataIconId = iconId;
        _fsBarDataIconPngBase64 = png;
      });
    } else if (which == 'loc') {
      await FloatingBallService.setFullScreenBarLocIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _fsBarLocIconId = iconId;
        _fsBarLocIconPngBase64 = png;
      });
    } else if (which == 'battery') {
      await FloatingBallService.setFullScreenBarBatteryIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _fsBarBatteryIconId = iconId;
        _fsBarBatteryIconPngBase64 = png;
      });
    } else if (which == 'restore') {
      await FloatingBallService.setFullScreenBarMediaRestoreIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _fsBarMediaRestoreIconId = iconId;
        _fsBarMediaRestoreIconPngBase64 = png;
      });
    }
  }

  Future<void> _setFsIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de iconos (pantalla completa)',
      current: _fsIconSizeDp,
      min: 10,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsIconSizeDp = picked);
    await FloatingBallService.setFullScreenIconSizeDp(picked);
  }

  Future<void> _setFsAppsIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de iconos (apps)',
      current: _fsAppsIconSizeDp,
      min: 10,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsAppsIconSizeDp = picked);
    await FloatingBallService.setFullScreenAppsIconSizeDp(picked);
  }

  Future<void> _setFsTileBorderColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsTileBorderColor,
      title: 'Color de borde (sistema)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsTileBorderColor = picked);
    await FloatingBallService.setFullScreenTileBorderColor(picked);
  }

  Future<void> _setFsAppsTileBorderColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsAppsTileBorderColor,
      title: 'Color de borde (apps)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsAppsTileBorderColor = picked);
    await FloatingBallService.setFullScreenAppsTileBorderColor(picked);
  }

  Future<void> _setFsTextSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de texto (pantalla completa)',
      current: _fsTextSizeSp,
      min: 8,
      max: 40,
      suffix: 'sp',
    );
    if (picked == null) return;
    setState(() => _fsTextSizeSp = picked);
    await FloatingBallService.setFullScreenTextSizeSp(picked);
  }

  Future<void> _setFsTileGap() async {
    final picked = await _showIntSlider(
      title: 'Espacio entre botones',
      current: _fsTileGapDp,
      min: 0,
      max: 40,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsTileGapDp = picked);
    await FloatingBallService.setFullScreenTileGapDp(picked);
  }

  Future<void> _setFsAppsTileGap() async {
    final picked = await _showIntSlider(
      title: 'Espacio entre apps',
      current: _fsAppsTileGapDp,
      min: 0,
      max: 40,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsAppsTileGapDp = picked);
    await FloatingBallService.setFullScreenAppsTileGapDp(picked);
  }

  Future<void> _setFsTilePadding() async {
    final picked = await _showIntSlider(
      title: 'Padding interno del botón',
      current: _fsTilePaddingDp,
      min: 0,
      max: 40,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsTilePaddingDp = picked);
    await FloatingBallService.setFullScreenTilePaddingDp(picked);
  }

  Future<void> _setFsStickyPadding() async {
    final picked = await _showIntSlider(
      title: 'Padding del sticky',
      current: _fsStickyPaddingDp,
      min: 0,
      max: 40,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsStickyPaddingDp = picked);
    await FloatingBallService.setFullScreenStickyPaddingDp(picked);
  }

  Future<void> _setFsContainerPaddingHorz() async {
    final picked = await _showIntSlider(
      title: 'Padding horizontal del contenedor',
      current: _fsContainerPaddingHorzDp,
      min: 0,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsContainerPaddingHorzDp = picked);
    await FloatingBallService.setFullScreenContainerPaddingHorzDp(picked);
  }

  Future<void> _setFsContainerPaddingVert() async {
    final picked = await _showIntSlider(
      title: 'Padding vertical del contenedor',
      current: _fsContainerPaddingVertDp,
      min: 0,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsContainerPaddingVertDp = picked);
    await FloatingBallService.setFullScreenContainerPaddingVertDp(picked);
  }

  Future<void> _setFsTileInnerGap() async {
    final picked = await _showIntSlider(
      title: 'Espacio entre icono y texto',
      current: _fsTileInnerGapDp,
      min: 0,
      max: 40,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsTileInnerGapDp = picked);
    await FloatingBallService.setFullScreenTileInnerGapDp(picked);
  }

  Future<void> _setFsTileHeight() async {
    final picked = await _showIntSlider(
      title: 'Altura de botones',
      current: _fsTileHeightDp,
      min: 60,
      max: 300,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsTileHeightDp = picked);
    await FloatingBallService.setFullScreenTileHeightDp(picked);
  }

  Future<void> _setFsAppsTileHeight() async {
    final picked = await _showIntSlider(
      title: 'Altura de apps',
      current: _fsAppsTileHeightDp,
      min: 60,
      max: 300,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsAppsTileHeightDp = picked);
    await FloatingBallService.setFullScreenAppsTileHeightDp(picked);
  }

  Future<void> _setFsSystemCols() async {
    final picked = await _showIntSlider(
      title: 'Columnas (botones del sistema)',
      current: _fsSystemCols,
      min: 1,
      max: 4,
      suffix: '',
    );
    if (picked == null) return;
    setState(() => _fsSystemCols = picked);
    await FloatingBallService.setFullScreenSystemCols(picked);
  }

  Future<void> _setFsAppsCols() async {
    final picked = await _showIntSlider(
      title: 'Columnas (apps)',
      current: _fsAppsCols,
      min: 1,
      max: 4,
      suffix: '',
    );
    if (picked == null) return;
    setState(() => _fsAppsCols = picked);
    await FloatingBallService.setFullScreenAppsCols(picked);
  }

  Future<void> _setFsCloseHeight() async {
    final picked = await _showIntSlider(
      title: 'Altura del botón Cerrar',
      current: _fsCloseHeightDp,
      min: 40,
      max: 240,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _fsCloseHeightDp = picked);
    await FloatingBallService.setFullScreenCloseHeightDp(picked);
  }

  Future<void> _setFsCloseText() async {
    final picked = await _showTextDialog(
      title: 'Texto del botón Cerrar',
      current: _fsCloseText,
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => _fsCloseText = picked);
    await FloatingBallService.setFullScreenCloseText(picked);
  }

  Future<void> _setFsCloseBgColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsCloseBgColor,
      title: 'Color del botón Cerrar (fondo)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsCloseBgColor = picked);
    await FloatingBallService.setFullScreenCloseBgColor(picked);
  }

  Future<void> _setFsCloseTextColor() async {
    final picked = await _showColorPickerInt(
      currentArgb: _fsCloseTextColor,
      title: 'Color del botón Cerrar (texto)',
      label: 'Color',
    );
    if (picked == null) return;
    setState(() => _fsCloseTextColor = picked);
    await FloatingBallService.setFullScreenCloseTextColor(picked);
  }

  IconData _iconDataForId(String id) {
    for (final opt in _iconOptions) {
      if (opt['id'] == id) return opt['icon'] as IconData;
    }
    return Icons.info;
  }

  Uint8List? _decodeBase64Bytes(String? raw) {
    final s = raw?.replaceAll(RegExp(r'\s+'), '').trim();
    if (s == null || s.isEmpty) return null;
    try {
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  Widget _buildPngIconPreview({
    required String? base64Png,
    required double size,
    required Color tint,
    IconData fallback = Icons.info,
  }) {
    final bytes = _decodeBase64Bytes(base64Png);
    if (bytes == null) {
      return Icon(fallback, color: tint, size: size);
    }
    return Image.memory(
      bytes,
      width: size,
      height: size,
      color: tint,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallback, color: tint, size: size);
      },
    );
  }

  Future<String?> _renderIconPngBase64(
    IconData icon, {
    int sizePx = 64,
    Color color = Colors.white,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: sizePx.toDouble(),
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color,
          ),
        ),
      )..layout();
      painter.paint(
        canvas,
        ui.Offset(
          (sizePx - painter.width) / 2,
          (sizePx - painter.height) / 2,
        ),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(sizePx, sizePx);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      return base64Encode(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<String?> _renderSvgFilePngBase64(
    String filePath, {
    int sizePx = 96,
    Color color = Colors.white,
  }) async {
    vg.PictureInfo? pictureInfo;
    try {
      final raw = await File(filePath).readAsString();
      pictureInfo = await vg.vg.loadPicture(
        vg.SvgStringLoader(raw),
        null,
        clipViewbox: true,
      );
      final src = pictureInfo.size;
      final scale = math.min(
        sizePx / (src.width == 0 ? 1 : src.width),
        sizePx / (src.height == 0 ? 1 : src.height),
      );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final outW = sizePx.toDouble();
      final outH = sizePx.toDouble();
      final drawW = src.width * scale;
      final drawH = src.height * scale;
      canvas.translate((outW - drawW) / 2, (outH - drawH) / 2);
      canvas.scale(scale, scale);
      canvas.drawPicture(pictureInfo.picture);
      final outPicture = recorder.endRecording();
      final image = await outPicture.toImage(sizePx, sizePx);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      final png = bytes.buffer.asUint8List();
      if (color == Colors.white) return base64Encode(png);

      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final recorder2 = ui.PictureRecorder();
      final canvas2 = ui.Canvas(recorder2);
      final paint = ui.Paint()
        ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn);
      canvas2.drawImage(frame.image, ui.Offset.zero, paint);
      final pic = recorder2.endRecording();
      final outImg = await pic.toImage(sizePx, sizePx);
      final outBytes = await outImg.toByteData(format: ui.ImageByteFormat.png);
      if (outBytes == null) return base64Encode(png);
      return base64Encode(outBytes.buffer.asUint8List());
    } catch (_) {
      return null;
    } finally {
      try {
        pictureInfo?.picture.dispose();
      } catch (_) {}
    }
  }

  Future<IconGalleryPick?> _pickIconFromGallery() async {
    final picked = await Navigator.push<IconGalleryPick>(
      context,
      MaterialPageRoute(
        builder: (context) => const SvgIconGalleryScreen(pickMode: true),
      ),
    );
    return picked;
  }

  Future<void> _setIcon(String iconId, IconData iconData) async {
    setState(() => _ballIcon = iconId);
    final png = await _renderIconPngBase64(iconData);
    await FloatingBallService.setBallIconWithPng(
      iconId: iconId,
      iconPngBase64: png,
    );
    setState(() => _ballIconPngBase64 = png);
  }

  Future<void> _pickBallIcon() async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png =
          await _renderSvgFilePngBase64(entry.filePath, sizePx: 128, color: Colors.white);
      if (png == null) return;
      await FloatingBallService.setBallIconWithPng(
        iconId: 'svg',
        iconPngBase64: png,
      );
      setState(() {
        _ballIcon = 'svg';
        _ballIconPngBase64 = png;
      });
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    await _setIcon(id, icon);
  }

  Future<void> _setFsButtonText(String which) async {
    String current;
    switch (which) {
      case 'back':
        current = _fsBackText;
        break;
      case 'home':
        current = _fsHomeText;
        break;
      case 'recents':
        current = _fsRecentsText;
        break;
      case 'volume':
        current = _fsVolumeText;
        break;
      case 'brightness':
        current = _fsBrightnessText;
        break;
      case 'settings':
        current = _fsSettingsText;
        break;
      default:
        return;
    }
    final picked = await _showTextDialog(title: 'Texto del botón', current: current);
    if (picked == null || picked.isEmpty) return;
    if (which == 'back') {
      setState(() => _fsBackText = picked);
      await FloatingBallService.setFullScreenBackText(picked);
    } else if (which == 'home') {
      setState(() => _fsHomeText = picked);
      await FloatingBallService.setFullScreenHomeText(picked);
    } else if (which == 'recents') {
      setState(() => _fsRecentsText = picked);
      await FloatingBallService.setFullScreenRecentsText(picked);
    } else if (which == 'volume') {
      setState(() => _fsVolumeText = picked);
      await FloatingBallService.setFullScreenVolumeText(picked);
    } else if (which == 'brightness') {
      setState(() => _fsBrightnessText = picked);
      await FloatingBallService.setFullScreenBrightnessText(picked);
    } else if (which == 'settings') {
      setState(() => _fsSettingsText = picked);
      await FloatingBallService.setFullScreenSettingsText(picked);
    }
  }

  Future<void> _pickFsButtonIcon(String which) async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png =
          await _renderSvgFilePngBase64(entry.filePath, sizePx: 128, color: Colors.white);
      if (png == null) return;
      await _applyFsIconWithPng(which: which, iconId: 'svg', png: png);
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await _applyFsIconWithPng(which: which, iconId: id, png: png);
  }

  Future<void> _applyFsIconWithPng({
    required String which,
    required String iconId,
    required String? png,
  }) async {
    if (which == 'back') {
      await FloatingBallService.setFullScreenBackIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _fsBackIconId = iconId;
        _fsBackIconPngBase64 = png;
      });
    } else if (which == 'home') {
      await FloatingBallService.setFullScreenHomeIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _fsHomeIconId = iconId;
        _fsHomeIconPngBase64 = png;
      });
    } else if (which == 'recents') {
      await FloatingBallService.setFullScreenRecentsIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _fsRecentsIconId = iconId;
        _fsRecentsIconPngBase64 = png;
      });
    } else if (which == 'volume') {
      await FloatingBallService.setFullScreenVolumeIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _fsVolumeIconId = iconId;
        _fsVolumeIconPngBase64 = png;
      });
    } else if (which == 'brightness') {
      await FloatingBallService.setFullScreenBrightnessIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _fsBrightnessIconId = iconId;
        _fsBrightnessIconPngBase64 = png;
      });
    } else if (which == 'settings') {
      await FloatingBallService.setFullScreenSettingsIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _fsSettingsIconId = iconId;
        _fsSettingsIconPngBase64 = png;
      });
    }
  }

  Future<void> _pickPopupButtonIcon(String which) async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png =
          await _renderSvgFilePngBase64(entry.filePath, sizePx: 128, color: Colors.white);
      if (png == null) return;
      await _applyPopupIconWithPng(which: which, iconId: 'svg', png: png);
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await _applyPopupIconWithPng(which: which, iconId: id, png: png);
  }

  Future<void> _applyPopupIconWithPng({
    required String which,
    required String iconId,
    required String? png,
  }) async {
    if (which == 'back') {
      await FloatingBallService.setPopupBackIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _popupBackIconId = iconId;
        _popupBackIconPngBase64 = png;
      });
    } else if (which == 'home') {
      await FloatingBallService.setPopupHomeIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _popupHomeIconId = iconId;
        _popupHomeIconPngBase64 = png;
      });
    } else if (which == 'recents') {
      await FloatingBallService.setPopupRecentsIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _popupRecentsIconId = iconId;
        _popupRecentsIconPngBase64 = png;
      });
    } else if (which == 'volume') {
      await FloatingBallService.setPopupVolumeIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _popupVolumeIconId = iconId;
        _popupVolumeIconPngBase64 = png;
      });
    } else if (which == 'brightness') {
      await FloatingBallService.setPopupBrightnessIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _popupBrightnessIconId = iconId;
        _popupBrightnessIconPngBase64 = png;
      });
    } else if (which == 'settings') {
      await FloatingBallService.setPopupSettingsIconWithPng(
        iconId: iconId,
        iconPngBase64: png,
      );
      setState(() {
        _popupSettingsIconId = iconId;
        _popupSettingsIconPngBase64 = png;
      });
    }
  }

  Future<void> _toggleFsCloseHideText(bool v) async {
    setState(() => _fsCloseHideText = v);
    await FloatingBallService.setFullScreenCloseHideTextEnabled(v);
  }

  Future<void> _pickFsCloseIcon() async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png =
          await _renderSvgFilePngBase64(entry.filePath, sizePx: 128, color: Colors.white);
      if (png == null) return;
      await FloatingBallService.setFullScreenCloseIconWithPng(
        iconId: 'svg',
        iconPngBase64: png,
      );
      setState(() {
        _fsCloseIconId = 'svg';
        _fsCloseIconPngBase64 = png;
      });
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await FloatingBallService.setFullScreenCloseIconWithPng(
      iconId: id,
      iconPngBase64: png,
    );
    setState(() {
      _fsCloseIconId = id;
      _fsCloseIconPngBase64 = png;
    });
  }

  Future<void> _toggleFsCloseSticky(bool v) async {
    setState(() => _fsCloseSticky = v);
    await FloatingBallService.setFullScreenCloseStickyEnabled(v);
  }

  Future<void> _toggleFsCloseDisableStickyWhenMediaActive(bool v) async {
    setState(() => _fsCloseDisableStickyWhenMediaActive = v);
    await FloatingBallService.setFullScreenCloseDisableStickyWhenMediaActiveEnabled(
      v,
    );
  }

  Future<void> _setMediaHeight() async {
    final picked = await _showIntSlider(
      title: 'Altura de multimedia',
      current: _mediaHeightDp,
      min: 140,
      max: 520,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _mediaHeightDp = picked);
    await FloatingBallService.setMediaHeightDp(picked);
  }

  Future<void> _setMediaIconSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño de iconos (multimedia)',
      current: _mediaIconSizeDp,
      min: 18,
      max: 120,
      suffix: 'dp',
    );
    if (picked == null) return;
    setState(() => _mediaIconSizeDp = picked);
    await FloatingBallService.setMediaIconSizeDp(picked);
  }

  Future<void> _setMediaTitleSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño del título (multimedia)',
      current: _mediaTitleSizeSp,
      min: 12,
      max: 40,
      suffix: 'sp',
    );
    if (picked == null) return;
    setState(() => _mediaTitleSizeSp = picked);
    await FloatingBallService.setMediaTitleSizeSp(picked);
  }

  Future<void> _setMediaSubtitleSize() async {
    final picked = await _showIntSlider(
      title: 'Tamaño del subtítulo (multimedia)',
      current: _mediaSubtitleSizeSp,
      min: 10,
      max: 36,
      suffix: 'sp',
    );
    if (picked == null) return;
    setState(() => _mediaSubtitleSizeSp = picked);
    await FloatingBallService.setMediaSubtitleSizeSp(picked);
  }

  Future<void> _pickMediaIcon(String which) async {
    final picked = await _pickIconFromGallery();
    if (picked == null) return;
    if (picked.type == IconGalleryPickType.svg) {
      final entry = picked.svg;
      if (entry == null) return;
      final png =
          await _renderSvgFilePngBase64(entry.filePath, sizePx: 128, color: Colors.white);
      if (png == null) return;
      await _applyMediaIconWithPng(which: which, iconId: 'svg', png: png);
      return;
    }
    final id = picked.flutterId;
    final icon = picked.flutterIcon;
    if (id == null || icon == null) return;
    final png = await _renderIconPngBase64(icon, sizePx: 96, color: Colors.white);
    await _applyMediaIconWithPng(which: which, iconId: id, png: png);
  }

  Future<void> _applyMediaIconWithPng({
    required String which,
    required String iconId,
    required String? png,
  }) async {
    if (which == 'volume') {
      await FloatingBallService.setMediaVolumeIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _mediaVolumeIconId = iconId;
        _mediaVolumeIconPngBase64 = png;
      });
    } else if (which == 'prev') {
      await FloatingBallService.setMediaPrevIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _mediaPrevIconId = iconId;
        _mediaPrevIconPngBase64 = png;
      });
    } else if (which == 'play') {
      await FloatingBallService.setMediaPlayIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _mediaPlayIconId = iconId;
        _mediaPlayIconPngBase64 = png;
      });
    } else if (which == 'pause') {
      await FloatingBallService.setMediaPauseIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _mediaPauseIconId = iconId;
        _mediaPauseIconPngBase64 = png;
      });
    } else if (which == 'next') {
      await FloatingBallService.setMediaNextIconWithPng(iconId: iconId, iconPngBase64: png);
      setState(() {
        _mediaNextIconId = iconId;
        _mediaNextIconPngBase64 = png;
      });
    }
  }

  Future<void> _toggleFullScreen(bool v) async {
    setState(() => _fullScreen = v);
    await FloatingBallService.setFullScreenEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar bola'),
        backgroundColor: customColor[700],
        actions: [
          IconButton(
            onPressed: () {
              final next = !_mediaVisible;
              print('[floating_ball_style] mediaVisible -> $next (from appbar)');
              setState(() {
                _mediaVisible = next;
              });
            },
            icon: Icon(_mediaVisible ? Icons.music_off : Icons.music_note),
            tooltip: _mediaVisible ? 'Ocultar multimedia' : 'Mostrar multimedia',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  FsMediaSection(
                    visible: _mediaVisible,
                    onVisibleChanged: (v) {
                      print('[floating_ball_style] mediaVisible -> $v (from section)');
                      setState(() {
                        _mediaVisible = v;
                      });
                    },
                  ),
                  Card(
                    elevation: 3,
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: customColor[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.bubble_chart, color: customColor[600], size: 24),
                      ),
                      title: const Text(
                        'Bola flotante',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Cambia el aspecto del botón flotante y el modo de visualización (popup o pantalla completa).',
                      ),
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Color(_ballColor),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Center(
                                child: _buildPngIconPreview(
                                  base64Png: _ballIconPngBase64,
                                  size: 22,
                                  tint: Color(_ballIconColor),
                                  fallback: _iconDataForId(_ballIcon),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Vista previa',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Color de la bola'),
                          subtitle: const Text('Color del fondo del botón flotante (incluye transparencia).'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _colorDot(Color(_ballColor)),
                              const SizedBox(width: 10),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: _setBallColor,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Icono'),
                          subtitle: const Text('Selecciona el icono que aparece dentro de la bola.'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPngIconPreview(
                                base64Png: _ballIconPngBase64,
                                size: 22,
                                tint: Color(_ballIconColor),
                                fallback: _iconDataForId(_ballIcon),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: _pickBallIcon,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Color del icono'),
                          subtitle: const Text('Color aplicado al icono (si el icono es PNG se tintará).'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _colorDot(Color(_ballIconColor)),
                              const SizedBox(width: 10),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: _setBallIconColor,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tamaño del icono'),
                          subtitle: Text('${_ballIconSizeDp}dp • Tamaño del icono dentro de la bola'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _setBallIconSize,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tamaño de la bola'),
                          subtitle: Text('${_ballSizeDp}dp • Diámetro del botón flotante'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _setBallSize,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pantalla completa'),
                          subtitle: const Text('Activa el modo de menú en pantalla completa (en lugar de popup).'),
                          value: _fullScreen,
                          onChanged: _toggleFullScreen,
                        ),
                      ],
                    ),
                  ),
                  if (!_fullScreen) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: customColor[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.dashboard, color: customColor[600], size: 24),
                        ),
                        title: const Text(
                          'Popup (modo compacto)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Personaliza el menú compacto que aparece junto a la bola (colores, posición e iconos).',
                        ),
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Color de fondo'),
                            subtitle: const Text('Color del panel del popup (incluye transparencia).'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _colorDot(Color(_popupBgColor)),
                                const SizedBox(width: 10),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: _setPopupBgColor,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Color de botones'),
                            subtitle: const Text('Color de las tarjetas/botones del popup.'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _colorDot(Color(_popupButtonColor)),
                                const SizedBox(width: 10),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: _setPopupButtonColor,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Color de iconos'),
                            subtitle: const Text('Color/tinte aplicado a los iconos del popup.'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _colorDot(Color(_popupIconColor)),
                                const SizedBox(width: 10),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: _setPopupIconColor,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Tamaño de iconos'),
                            subtitle: Text('${_popupIconSizeDp}dp • Tamaño de iconos del popup'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _setPopupIconSize,
                          ),
                          const SizedBox(height: 6),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Posición del popup'),
                            subtitle: const Text('Ajusta el desplazamiento del popup respecto a la bola.'),
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Offset X'),
                                subtitle: Text('${_popupOffsetXDp}dp • Horizontal'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _setPopupOffsetX,
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Offset Y'),
                                subtitle: Text('${_popupOffsetYDp}dp • Vertical'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _setPopupOffsetY,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Popup multimedia'),
                            subtitle: const Text('Posición del panel multimedia dentro del popup.'),
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Offset X'),
                                subtitle: Text('${_popupMediaOffsetXDp}dp • Horizontal'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _setPopupMediaOffsetX,
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Offset Y'),
                                subtitle: Text('${_popupMediaOffsetYDp}dp • Vertical'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _setPopupMediaOffsetY,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Iconos del popup'),
                            subtitle: const Text('Selecciona iconos para las acciones del popup.'),
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Back'),
                                subtitle: const Text('Acción: atrás'),
                                trailing: _buildPngIconPreview(
                                  base64Png: _popupBackIconPngBase64,
                                  size: 22,
                                  tint: Color(_popupIconColor),
                                  fallback: _iconDataForId(_popupBackIconId),
                                ),
                                onTap: () => _pickPopupButtonIcon('back'),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Home'),
                                subtitle: const Text('Acción: inicio'),
                                trailing: _buildPngIconPreview(
                                  base64Png: _popupHomeIconPngBase64,
                                  size: 22,
                                  tint: Color(_popupIconColor),
                                  fallback: _iconDataForId(_popupHomeIconId),
                                ),
                                onTap: () => _pickPopupButtonIcon('home'),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Recientes'),
                                subtitle: const Text('Acción: apps recientes'),
                                trailing: _buildPngIconPreview(
                                  base64Png: _popupRecentsIconPngBase64,
                                  size: 22,
                                  tint: Color(_popupIconColor),
                                  fallback: _iconDataForId(_popupRecentsIconId),
                                ),
                                onTap: () => _pickPopupButtonIcon('recents'),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Volumen'),
                                subtitle: const Text('Acción: controles de volumen'),
                                trailing: _buildPngIconPreview(
                                  base64Png: _popupVolumeIconPngBase64,
                                  size: 22,
                                  tint: Color(_popupIconColor),
                                  fallback: _iconDataForId(_popupVolumeIconId),
                                ),
                                onTap: () => _pickPopupButtonIcon('volume'),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Brillo'),
                                subtitle: const Text('Acción: controles de brillo'),
                                trailing: _buildPngIconPreview(
                                  base64Png: _popupBrightnessIconPngBase64,
                                  size: 22,
                                  tint: Color(_popupIconColor),
                                  fallback: _iconDataForId(_popupBrightnessIconId),
                                ),
                                onTap: () => _pickPopupButtonIcon('brightness'),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Ajustes'),
                                subtitle: const Text('Acción: abrir ajustes'),
                                trailing: _buildPngIconPreview(
                                  base64Png: _popupSettingsIconPngBase64,
                                  size: 22,
                                  tint: Color(_popupIconColor),
                                  fallback: _iconDataForId(_popupSettingsIconId),
                                ),
                                onTap: () => _pickPopupButtonIcon('settings'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_fullScreen) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: customColor[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.fullscreen, color: customColor[600], size: 24),
                        ),
                        title: const Text(
                          'Pantalla completa',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Personaliza el menú en pantalla completa: colores, distribución, barra, notificaciones, conversación y multimedia.',
                        ),
                        children: [
                          Column(
                            children: [
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('Diseño y distribución'),
                                subtitle: const Text(
                                  'Colores, tamaños y espaciados del menú principal en pantalla completa.',
                                ),
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Color de fondo'),
                                    subtitle: const Text(
                                      'Color de fondo de la pantalla completa (incluye transparencia).',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _colorDot(Color(_fsBgColor)),
                                        const SizedBox(width: 10),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                    onTap: _setFsBgColor,
                                  ),
                                  ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de botones (sistema)'),
                              subtitle: const Text('Color de fondo de los botones/tiles del sistema.'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsButtonColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _setFsButtonColor,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de botones (apps)'),
                              subtitle: const Text('Color de fondo de los botones/tiles de apps.'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsAppsButtonColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _setFsAppsButtonColor,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de borde (sistema)'),
                              subtitle: const Text('Borde de los botones del sistema (útil para resaltar).'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsTileBorderColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _setFsTileBorderColor,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de borde (apps)'),
                              subtitle: const Text('Borde de los botones de apps.'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsAppsTileBorderColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _setFsAppsTileBorderColor,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color base'),
                              subtitle: const Text('Color base para elementos del sistema (si no tienen color propio).'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsContentColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _setFsContentColor,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de iconos'),
                              subtitle: const Text('Color/tinte de iconos en pantalla completa.'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsIconColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _setFsIconColor,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de textos'),
                              subtitle: const Text('Color de los textos de los botones.'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsTextColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _setFsTextColor,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Ocultar textos'),
                              subtitle: const Text('Muestra solo iconos en los botones.'),
                              value: _fsHideText,
                              onChanged: _toggleFsHideText,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de iconos'),
                              subtitle: Text('${_fsIconSizeDp}dp • Tamaño de iconos del sistema'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsIconSize,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de iconos (apps)'),
                              subtitle: Text('${_fsAppsIconSizeDp}dp • Tamaño de iconos de apps'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsAppsIconSize,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de textos'),
                              subtitle: Text('${_fsTextSizeSp}sp • Tamaño de etiqueta'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsTextSize,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Espacio entre botones (sistema)'),
                              subtitle: Text('${_fsTileGapDp}dp • Separación entre tiles del sistema'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsTileGap,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Espacio entre apps'),
                              subtitle: Text('${_fsAppsTileGapDp}dp • Separación entre tiles de apps'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsAppsTileGap,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Padding del botón'),
                              subtitle: Text('${_fsTilePaddingDp}dp • Espacio interno del tile'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsTilePadding,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Padding del sticky'),
                              subtitle: Text('${_fsStickyPaddingDp}dp • Margen del área fija inferior'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsStickyPadding,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Padding contenedor horizontal'),
                              subtitle: Text('${_fsContainerPaddingHorzDp}dp • Márgenes laterales'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsContainerPaddingHorz,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Padding contenedor vertical'),
                              subtitle: Text('${_fsContainerPaddingVertDp}dp • Márgenes verticales'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsContainerPaddingVert,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Espacio icono-texto'),
                              subtitle: Text('${_fsTileInnerGapDp}dp • Separación entre icono y texto'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsTileInnerGap,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Altura de botones (sistema)'),
                              subtitle: Text('${_fsTileHeightDp}dp • Alto de tiles del sistema'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsTileHeight,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Altura de apps'),
                              subtitle: Text('${_fsAppsTileHeightDp}dp • Alto de tiles de apps'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsAppsTileHeight,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Columnas (botones del sistema)'),
                              subtitle: Text('$_fsSystemCols'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsSystemCols,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Columnas (apps)'),
                              subtitle: Text('$_fsAppsCols'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsAppsCols,
                            ),
                                ],
                              ),
                              const Divider(height: 22),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Barra superior'),
                              subtitle: const Text(
                                'Muestra una barra con estado del sistema y acceso a notificaciones.',
                              ),
                              children: [
                                SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Mostrar sección Barra'),
                              subtitle: const Text('Activa/desactiva la barra superior.'),
                              value: _fsBarEnabled,
                              onChanged: _toggleFsBarEnabled,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Altura'),
                              subtitle: Text('${_fsBarHeightDp}dp • Alto de la barra'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _fsBarEnabled ? _setFsBarHeight : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de fondo'),
                              subtitle: const Text('Fondo de la barra (incluye transparencia).'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsBarBgColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _fsBarEnabled ? _setFsBarBgColor : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de textos/iconos'),
                              subtitle: const Text('Color base de textos e iconos en la barra.'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsBarContentColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _fsBarEnabled ? _setFsBarContentColor : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de iconos'),
                              subtitle: Text('${_fsBarIconSizeDp}dp • Tamaño de iconos'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _fsBarEnabled ? _setFsBarIconSize : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de texto'),
                              subtitle: Text('${_fsBarTextSizeSp}sp • Tamaño del texto'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _fsBarEnabled ? _setFsBarTextSize : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Padding horizontal'),
                              subtitle: Text('${_fsBarPaddingHorzDp}dp • Márgenes laterales'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _fsBarEnabled ? _setFsBarPaddingHorz : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Padding vertical'),
                              subtitle: Text('${_fsBarPaddingVertDp}dp • Márgenes verticales'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _fsBarEnabled ? _setFsBarPaddingVert : null,
                            ),
                            const SizedBox(height: 6),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Colores'),
                              subtitle: const Text('Colores específicos para cada indicador.'),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Hora'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_fsBarTimeColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: _fsBarEnabled ? _setFsBarTimeColor : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono Wifi'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_fsBarWifiIconColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: _fsBarEnabled ? _setFsBarWifiIconColor : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono Bluetooth'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_fsBarBtIconColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: _fsBarEnabled ? _setFsBarBtIconColor : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono Datos móviles'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_fsBarDataIconColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: _fsBarEnabled ? _setFsBarDataIconColor : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono Ubicación'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_fsBarLocIconColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: _fsBarEnabled ? _setFsBarLocIconColor : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono Batería'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_fsBarBatteryIconColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: _fsBarEnabled ? _setFsBarBatteryIconColor : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto Batería'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_fsBarBatteryTextColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: _fsBarEnabled ? _setFsBarBatteryTextColor : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono Restaurar multimedia'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_fsBarRestoreIconColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: _fsBarEnabled ? _setFsBarRestoreIconColor : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Fondo Restaurar multimedia'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_fsBarRestoreBgColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: _fsBarEnabled ? _setFsBarRestoreBgColor : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Iconos'),
                              subtitle: const Text('Iconos personalizados (opcional).'),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Wifi'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsBarWifiIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsBarWifiIconColor),
                                    fallback: _iconDataForId(_fsBarWifiIconId),
                                  ),
                                  onTap: _fsBarEnabled ? () => _pickFsBarIcon('wifi') : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Bluetooth'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsBarBtIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsBarBtIconColor),
                                    fallback: _iconDataForId(_fsBarBtIconId),
                                  ),
                                  onTap: _fsBarEnabled ? () => _pickFsBarIcon('bt') : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Datos móviles'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsBarDataIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsBarDataIconColor),
                                    fallback: _iconDataForId(_fsBarDataIconId),
                                  ),
                                  onTap: _fsBarEnabled ? () => _pickFsBarIcon('data') : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Ubicación'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsBarLocIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsBarLocIconColor),
                                    fallback: _iconDataForId(_fsBarLocIconId),
                                  ),
                                  onTap: _fsBarEnabled ? () => _pickFsBarIcon('loc') : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Batería'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsBarBatteryIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsBarBatteryIconColor),
                                    fallback: _iconDataForId(_fsBarBatteryIconId),
                                  ),
                                  onTap: _fsBarEnabled ? () => _pickFsBarIcon('battery') : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Restaurar multimedia'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsBarMediaRestoreIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsBarRestoreIconColor),
                                    fallback: _iconDataForId(_fsBarMediaRestoreIconId),
                                  ),
                                  onTap: _fsBarEnabled ? () => _pickFsBarIcon('restore') : null,
                                ),
                              ],
                            ),
                              ],
                            ),
                            const Divider(height: 22),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Pantalla de notificaciones'),
                              subtitle: const Text(
                                'Estilo de la pantalla que se abre desde la barra (batería).',
                              ),
                              children: [
                                SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Pantalla de notificaciones personalizada'),
                              subtitle: const Text(
                                'Al tocar la batería se muestra una lista de notificaciones',
                              ),
                              value: _fsCustomNotificationsEnabled,
                              onChanged: _fsBarEnabled
                                  ? _toggleFsCustomNotificationsEnabled
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Abrir pantalla de notificaciones'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? () {
                                      Navigator.pushNamed(
                                        context,
                                        '/floating_ball_custom_notifications',
                                      );
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Botones inferiores',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Altura de iconos'),
                              subtitle: Text('${_customNotifsButtonsIconHeightDp}dp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsButtonsIconHeight
                                  : null,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Ocultar textos'),
                              subtitle: const Text('Solo iconos en botones inferiores'),
                              value: _customNotifsButtonsHideText,
                              onChanged: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _toggleCustomNotifsButtonsHideText
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Altura de botones'),
                              subtitle: Text('${_customNotifsButtonsHeightDp}dp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsButtonsHeight
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de fondo (botones)'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_customNotifsButtonsBgColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsButtonsBgColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de borde (botones)'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_customNotifsButtonsBorderColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsButtonsBorderColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de iconos/texto (botones)'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_customNotifsButtonsContentColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsButtonsContentColor
                                  : null,
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Botón Cerrar'),
                              subtitle: Text(_customNotifsCloseText),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _customNotifsCloseIconPngBase64,
                                    size: 22,
                                    tint: Color(_customNotifsButtonsContentColor),
                                    fallback: Icons.close,
                                  ),
                                  onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                      ? _pickCustomNotifsCloseIcon
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                      ? _setCustomNotifsCloseText
                                      : null,
                                ),
                              ],
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Botón Eliminar todo'),
                              subtitle: Text(_customNotifsClearAllText),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _customNotifsClearAllIconPngBase64,
                                    size: 22,
                                    tint: Color(_customNotifsButtonsContentColor),
                                    fallback: Icons.delete_forever,
                                  ),
                                  onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                      ? _pickCustomNotifsClearAllIcon
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                      ? _setCustomNotifsClearAllText
                                      : null,
                                ),
                              ],
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Icono del botón Eliminar'),
                              trailing: _buildPngIconPreview(
                                base64Png: _customNotifsDeleteIconPngBase64,
                                size: 22,
                                tint: Color(_fsCloseTextColor),
                                fallback: Icons.delete_forever,
                              ),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _pickCustomNotifsDeleteIcon
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Texto del botón Eliminar'),
                              subtitle: Text(_customNotifsDeleteText),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsDeleteText
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Estilo de notificaciones',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de fondo (pantalla)'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_customNotifsBgColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsBgColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de fondo (notificación)'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_customNotifsItemBgColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsItemBgColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de borde (notificación)'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_customNotifsItemBorderColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsItemBorderColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de título'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_customNotifsTitleColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsTitleColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de texto'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_customNotifsTextColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsTextColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de título'),
                              subtitle: Text('${_customNotifsTitleSizeSp}sp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsTitleSize
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de texto'),
                              subtitle: Text('${_customNotifsTextSizeSp}sp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: (_fsBarEnabled && _fsCustomNotificationsEnabled)
                                  ? _setCustomNotifsTextSize
                                  : null,
                            ),
                              ],
                            ),
                            const Divider(height: 22),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Botones inferiores'),
                              subtitle: const Text(
                                'Se aplica a: Conversación y Pantalla de notificaciones (botones inferiores).',
                              ),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Espacio entre botones'),
                                  subtitle: Text('${_conversationBottomButtonsGapDp}dp'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _setConversationBottomButtonsGap,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Padding horizontal del contenedor'),
                                  subtitle: Text('${_conversationBottomButtonsPaddingHorzDp}dp'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _setConversationBottomButtonsPaddingHorz,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Padding vertical del contenedor'),
                                  subtitle: Text('${_conversationBottomButtonsPaddingVertDp}dp'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _setConversationBottomButtonsPaddingVert,
                                ),
                              ],
                            ),
                            const Divider(height: 22),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Conversación'),
                              subtitle: const Text(
                                'Vista tipo chat (burbujas) para notificaciones compatibles.',
                              ),
                              children: [
                                SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Habilitar sección de conversación'),
                              subtitle: const Text(
                                'Usar vista de chat al abrir automáticamente una notificación compatible',
                              ),
                              value: _fsConversationEnabled,
                              onChanged: _fsBarEnabled ? _toggleFsConversationEnabled : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de fondo (pantalla conversación)'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_conversationBgColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap:
                                  (_fsBarEnabled && _fsConversationEnabled) ? _setConversationBgColor : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color burbuja recibida'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_conversationIncomingColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsConversationEnabled)
                                  ? _setConversationIncomingColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color burbuja enviada'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_conversationOutgoingColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsConversationEnabled)
                                  ? _setConversationOutgoingColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de texto (conversación)'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_conversationTextColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsConversationEnabled)
                                  ? _setConversationTextColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de texto (conversación)'),
                              subtitle: Text('${_conversationTextSizeSp}sp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: (_fsBarEnabled && _fsConversationEnabled)
                                  ? _setConversationTextSize
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Título (pantalla conversación)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de título'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_conversationTitleColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: (_fsBarEnabled && _fsConversationEnabled)
                                  ? _setConversationTitleColor
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de título'),
                              subtitle: Text('${_conversationTitleSizeSp}sp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: (_fsBarEnabled && _fsConversationEnabled)
                                  ? _setConversationTitleSize
                                  : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño icono de app (header)'),
                              subtitle: Text('${_conversationHeaderAppIconSizeDp}dp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: (_fsBarEnabled && _fsConversationEnabled)
                                  ? _setConversationHeaderAppIconSize
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Botón Cerrar'),
                              subtitle: Text(_conversationCloseText),
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Ocultar texto'),
                                  value: _conversationCloseHideText,
                                  onChanged: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _toggleConversationCloseHideText
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationCloseText
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _conversationCloseIconPngBase64,
                                    size: 22,
                                    tint: Color(_conversationCloseTextColor),
                                    fallback: _iconDataForId(_conversationCloseIconId),
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _pickConversationCloseIcon
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Tamaño icono'),
                                  subtitle: Text('${_conversationCloseIconSizeDp}dp'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationCloseIconSize
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Altura'),
                                  subtitle: Text('${_conversationCloseHeightDp}dp'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationCloseHeight
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de fondo'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_conversationCloseBgColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationCloseBgColor
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de texto/icono'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_conversationCloseTextColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationCloseTextColor
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de borde'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_conversationCloseBorderColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationCloseBorderColor
                                      : null,
                                ),
                              ],
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Botón Responder'),
                              subtitle: Text(_conversationReplyText),
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Ocultar texto'),
                                  value: _conversationReplyHideText,
                                  onChanged: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _toggleConversationReplyHideText
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyText
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _conversationReplyIconPngBase64,
                                    size: 22,
                                    tint: Color(_conversationReplyTextColor),
                                    fallback: _iconDataForId(_conversationReplyIconId),
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _pickConversationReplyIcon
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Tamaño icono'),
                                  subtitle: Text('${_conversationReplyIconSizeDp}dp'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyIconSize
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Altura'),
                                  subtitle: Text('${_conversationReplyHeightDp}dp'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyHeight
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de fondo'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_conversationReplyBgColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyBgColor
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de texto/icono'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_conversationReplyTextColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyTextColor
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de borde'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_conversationReplyBorderColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyBorderColor
                                      : null,
                                ),
                              ],
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Modal Responder'),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de fondo'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_conversationReplyModalBgColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyModalBgColor
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de texto'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(Color(_conversationReplyModalTextColor)),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyModalTextColor
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Tamaño de texto'),
                                  subtitle:
                                      Text('${_conversationReplyModalTextSizeSp}sp'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyModalTextSize
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Botón Enviar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _conversationReplyModalSendIconPngBase64,
                                    size: 22,
                                    tint: Color(_conversationReplyModalTextColor),
                                    fallback: _iconDataForId(
                                      _conversationReplyModalSendIconId,
                                    ),
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _pickConversationReplyModalSendIcon
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Tamaño icono'),
                                  subtitle: Text(
                                    '${_conversationReplyModalSendIconSizeDp}dp',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyModalSendIconSize
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de fondo'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(
                                        Color(_conversationReplyModalSendBgColor),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyModalSendBgColor
                                      : null,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Color de borde'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _colorDot(
                                        Color(_conversationReplyModalSendBorderColor),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: (_fsBarEnabled && _fsConversationEnabled)
                                      ? _setConversationReplyModalSendBorderColor
                                      : null,
                                ),
                              ],
                            ),
                              ],
                            ),
                            const Divider(height: 22),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Multimedia'),
                              subtitle: const Text(
                                'Configura el panel multimedia y sus iconos.',
                              ),
                              children: [
                                SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Mostrar automáticamente'),
                              subtitle: Text(
                                _fsBarEnabled
                                    ? 'Si se desactiva, solo se muestra el icono en la Barra'
                                    : 'Requiere Barra activa para mostrar el icono',
                              ),
                              value: _fsMediaAutoShow,
                              onChanged: _fsBarEnabled ? _toggleFsMediaAutoShow : null,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Altura'),
                              subtitle: Text('${_mediaHeightDp}dp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setMediaHeight,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño de iconos'),
                              subtitle: Text('${_mediaIconSizeDp}dp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setMediaIconSize,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño del título'),
                              subtitle: Text('${_mediaTitleSizeSp}sp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setMediaTitleSize,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tamaño del subtítulo'),
                              subtitle: Text('${_mediaSubtitleSizeSp}sp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setMediaSubtitleSize,
                            ),
                            const SizedBox(height: 6),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Iconos'),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Volumen'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _mediaVolumeIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_mediaVolumeIconId),
                                  ),
                                  onTap: () => _pickMediaIcon('volume'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Anterior'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _mediaPrevIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_mediaPrevIconId),
                                  ),
                                  onTap: () => _pickMediaIcon('prev'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Play'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _mediaPlayIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_mediaPlayIconId),
                                  ),
                                  onTap: () => _pickMediaIcon('play'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Pause'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _mediaPauseIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_mediaPauseIconId),
                                  ),
                                  onTap: () => _pickMediaIcon('pause'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Siguiente'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _mediaNextIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_mediaNextIconId),
                                  ),
                                  onTap: () => _pickMediaIcon('next'),
                                ),
                              ],
                            ),
                              ],
                            ),
                            const Divider(height: 22),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Botones del sistema'),
                              subtitle: const Text(
                                'Personaliza textos e iconos (Back, Home, Recientes, etc.).',
                              ),
                              children: [
                                ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Back'),
                              subtitle: Text(_fsBackText),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _setFsButtonText('back'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsBackIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_fsBackIconId),
                                  ),
                                  onTap: () => _pickFsButtonIcon('back'),
                                ),
                              ],
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Home'),
                              subtitle: Text(_fsHomeText),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _setFsButtonText('home'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsHomeIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_fsHomeIconId),
                                  ),
                                  onTap: () => _pickFsButtonIcon('home'),
                                ),
                              ],
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Volumen'),
                              subtitle: Text(_fsVolumeText),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _setFsButtonText('volume'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsVolumeIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_fsVolumeIconId),
                                  ),
                                  onTap: () => _pickFsButtonIcon('volume'),
                                ),
                              ],
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Brillo'),
                              subtitle: Text(_fsBrightnessText),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _setFsButtonText('brightness'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsBrightnessIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_fsBrightnessIconId),
                                  ),
                                  onTap: () => _pickFsButtonIcon('brightness'),
                                ),
                              ],
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Recientes'),
                              subtitle: Text(_fsRecentsText),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _setFsButtonText('recents'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsRecentsIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_fsRecentsIconId),
                                  ),
                                  onTap: () => _pickFsButtonIcon('recents'),
                                ),
                              ],
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Configuración'),
                              subtitle: Text(_fsSettingsText),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Texto'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _setFsButtonText('settings'),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Icono'),
                                  trailing: _buildPngIconPreview(
                                    base64Png: _fsSettingsIconPngBase64,
                                    size: 22,
                                    tint: Color(_fsIconColor),
                                    fallback: _iconDataForId(_fsSettingsIconId),
                                  ),
                                  onTap: () => _pickFsButtonIcon('settings'),
                                ),
                              ],
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Reordenar botones'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const FloatingBallReorderScreen(),
                                  ),
                                );
                              },
                            ),
                              ],
                            ),
                            const Divider(height: 22),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Botón Cerrar'),
                              subtitle: const Text('Configura el botón inferior para salir del menú.'),
                              children: [
                                ListTile(
                              contentPadding: EdgeInsets.zero,
                              enabled: !_fsCloseHideText,
                              title: const Text('Texto'),
                              subtitle: Text(_fsCloseText),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _fsCloseHideText ? null : _setFsCloseText,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Ocultar texto'),
                              subtitle: const Text('Muestra un icono en lugar del texto'),
                              value: _fsCloseHideText,
                              onChanged: _toggleFsCloseHideText,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Icono'),
                              trailing: _buildPngIconPreview(
                                base64Png: _fsCloseIconPngBase64,
                                size: 22,
                                tint: Color(_fsCloseTextColor),
                                fallback: _iconDataForId(_fsCloseIconId),
                              ),
                              onTap: _pickFsCloseIcon,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Altura'),
                              subtitle: Text('${_fsCloseHeightDp}dp'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _setFsCloseHeight,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de fondo'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsCloseBgColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _setFsCloseBgColor,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Color de texto'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _colorDot(Color(_fsCloseTextColor)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _setFsCloseTextColor,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Cerrar sticky'),
                              subtitle: const Text('Se fija abajo y el scroll pasa por detrás'),
                              value: _fsCloseSticky,
                              onChanged: _toggleFsCloseSticky,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Desactivar sticky con multimedia activa'),
                              subtitle: const Text('Si hay multimedia, el botón no se fija abajo'),
                              value: _fsCloseDisableStickyWhenMediaActive,
                              onChanged: _fsCloseSticky
                                  ? _toggleFsCloseDisableStickyWhenMediaActive
                                  : null,
                            ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              ),
            ),
    );
  }
}
