package com.example.connect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.animation.ValueAnimator
import android.content.Context
import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.BitmapFactory
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.bluetooth.BluetoothAdapter
import android.media.AudioManager
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.text.format.DateFormat
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.accessibilityservice.AccessibilityService
import android.util.Base64
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date
import kotlin.math.abs
import kotlin.math.roundToInt

class FloatingBallService : Service() {
    companion object {
        const val ACTION_START = "com.example.connect.FLOATING_BALL_START"
        const val ACTION_UPDATE_CONFIG = "com.example.connect.FLOATING_BALL_UPDATE_CONFIG"
        const val ACTION_DISMISS_MENU = "com.example.connect.FLOATING_BALL_DISMISS_MENU"
        private const val CHANNEL_ID = "floating_ball_channel"
        private const val NOTIFICATION_ID = 10031
        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val KEY_ENABLED = "flutter.floating_ball_enabled"
        private const val KEY_APPS_JSON = "flutter.floating_ball_selected_apps_json"
        private const val KEY_USE_AS_RECEPTOR = "flutter.use_as_receptor"
        private const val KEY_BALL_COLOR = "flutter.floating_ball_color"
        private const val KEY_BALL_ICON = "flutter.floating_ball_icon"
        private const val KEY_BALL_ICON_PNG_BASE64 = "flutter.floating_ball_icon_png_base64"
        private const val KEY_BALL_ICON_COLOR = "flutter.floating_ball_ball_icon_color"
        private const val KEY_BALL_ICON_SIZE_DP = "flutter.floating_ball_ball_icon_size_dp"
        private const val KEY_BALL_SIZE_DP = "flutter.floating_ball_ball_size_dp"
        private const val KEY_FULLSCREEN = "flutter.floating_ball_fullscreen"
        private const val KEY_GESTURES_ENABLED = "flutter.floating_ball_gestures_enabled"
        private const val KEY_GESTURE_LONG_PRESS_MS = "flutter.floating_ball_gesture_long_press_ms"
        private const val KEY_GESTURE_UP_ACTION = "flutter.floating_ball_gesture_up_action"
        private const val KEY_GESTURE_UP_APP = "flutter.floating_ball_gesture_up_app"
        private const val KEY_GESTURE_RIGHT_ACTION = "flutter.floating_ball_gesture_right_action"
        private const val KEY_GESTURE_RIGHT_APP = "flutter.floating_ball_gesture_right_app"
        private const val KEY_GESTURE_DOWN_ACTION = "flutter.floating_ball_gesture_down_action"
        private const val KEY_GESTURE_DOWN_APP = "flutter.floating_ball_gesture_down_app"
        private const val KEY_GESTURE_LEFT_ACTION = "flutter.floating_ball_gesture_left_action"
        private const val KEY_GESTURE_LEFT_APP = "flutter.floating_ball_gesture_left_app"
        private const val KEY_GESTURE_VIBRATION_MS = "flutter.floating_ball_gesture_vibration_ms"
        private const val KEY_GESTURE_VIBRATION_AMPLITUDE = "flutter.floating_ball_gesture_vibration_amplitude"
        private const val KEY_GESTURE_NOTIFICATIONS_USE_CUSTOM_SCREEN = "flutter.floating_ball_gesture_notifications_use_custom_screen"
        private const val KEY_FS_BG_COLOR = "flutter.floating_ball_fs_bg_color"
        private const val KEY_FS_BUTTON_COLOR = "flutter.floating_ball_fs_button_color"
        private const val KEY_FS_CONTENT_COLOR = "flutter.floating_ball_fs_content_color"
        private const val KEY_FS_ICON_COLOR = "flutter.floating_ball_fs_icon_color"
        private const val KEY_FS_TEXT_COLOR = "flutter.floating_ball_fs_text_color"
        private const val KEY_FS_HIDE_TEXT = "flutter.floating_ball_fs_hide_text"
        private const val KEY_FS_ICON_SIZE_DP = "flutter.floating_ball_fs_icon_size_dp"
        private const val KEY_FS_TEXT_SIZE_SP = "flutter.floating_ball_fs_text_size_sp"
        private const val KEY_FS_TILE_GAP_DP = "flutter.floating_ball_fs_tile_gap_dp"
        private const val KEY_FS_TILE_PADDING_DP = "flutter.floating_ball_fs_tile_padding_dp"
        private const val KEY_FS_STICKY_PADDING_DP = "flutter.floating_ball_fs_sticky_padding_dp"
        private const val KEY_FS_TILE_INNER_GAP_DP = "flutter.floating_ball_fs_tile_inner_gap_dp"
        private const val KEY_FS_TILE_HEIGHT_DP = "flutter.floating_ball_fs_tile_height_dp"
        private const val KEY_FS_TILE_BORDER_COLOR = "flutter.floating_ball_fs_tile_border_color"
        private const val KEY_FS_CONTAINER_PADDING_HORZ_DP = "flutter.floating_ball_fs_container_padding_horz_dp"
        private const val KEY_FS_CONTAINER_PADDING_VERT_DP = "flutter.floating_ball_fs_container_padding_vert_dp"
        private const val KEY_FS_SYSTEM_COLS = "flutter.floating_ball_fs_system_cols"
        private const val KEY_FS_APPS_COLS = "flutter.floating_ball_fs_apps_cols"
        private const val KEY_FS_APPS_BUTTON_COLOR = "flutter.floating_ball_fs_apps_button_color"
        private const val KEY_FS_APPS_TILE_GAP_DP = "flutter.floating_ball_fs_apps_tile_gap_dp"
        private const val KEY_FS_APPS_TILE_HEIGHT_DP = "flutter.floating_ball_fs_apps_tile_height_dp"
        private const val KEY_FS_APPS_TILE_BORDER_COLOR = "flutter.floating_ball_fs_apps_tile_border_color"
        private const val KEY_FS_APPS_ICON_SIZE_DP = "flutter.floating_ball_fs_apps_icon_size_dp"
        private const val KEY_FS_BAR_ENABLED = "flutter.floating_ball_fs_bar_enabled"
        private const val KEY_FS_CUSTOM_NOTIFICATIONS_ENABLED = "flutter.floating_ball_fs_custom_notifications_enabled"
        private const val KEY_CUSTOM_NOTIFS_BG_COLOR = "flutter.floating_ball_custom_notifications_bg_color"
        private const val KEY_CUSTOM_NOTIFS_ITEM_BG_COLOR = "flutter.floating_ball_custom_notifications_item_bg_color"
        private const val KEY_CUSTOM_NOTIFS_ITEM_BORDER_COLOR = "flutter.floating_ball_custom_notifications_item_border_color"
        private const val KEY_CUSTOM_NOTIFS_TITLE_COLOR = "flutter.floating_ball_custom_notifications_title_color"
        private const val KEY_CUSTOM_NOTIFS_TEXT_COLOR = "flutter.floating_ball_custom_notifications_text_color"
        private const val KEY_CUSTOM_NOTIFS_TITLE_SIZE_SP = "flutter.floating_ball_custom_notifications_title_size_sp"
        private const val KEY_CUSTOM_NOTIFS_TEXT_SIZE_SP = "flutter.floating_ball_custom_notifications_text_size_sp"
        private const val KEY_CUSTOM_NOTIFS_BUTTONS_ICON_HEIGHT_DP = "flutter.floating_ball_custom_notifications_buttons_icon_height_dp"
        private const val KEY_CUSTOM_NOTIFS_DELETE_ICON_ID = "flutter.floating_ball_custom_notifications_delete_icon_id"
        private const val KEY_CUSTOM_NOTIFS_DELETE_ICON_PNG_BASE64 = "flutter.floating_ball_custom_notifications_delete_icon_png_base64"
        private const val KEY_CUSTOM_NOTIFS_DELETE_TEXT = "flutter.floating_ball_custom_notifications_delete_text"
        private const val KEY_CUSTOM_NOTIFS_BUTTONS_HIDE_TEXT = "flutter.floating_ball_custom_notifications_buttons_hide_text"
        private const val KEY_CUSTOM_NOTIFS_BUTTONS_HEIGHT_DP = "flutter.floating_ball_custom_notifications_buttons_height_dp"
        private const val KEY_CUSTOM_NOTIFS_BUTTONS_BG_COLOR = "flutter.floating_ball_custom_notifications_buttons_bg_color"
        private const val KEY_CUSTOM_NOTIFS_BUTTONS_BORDER_COLOR = "flutter.floating_ball_custom_notifications_buttons_border_color"
        private const val KEY_CUSTOM_NOTIFS_BUTTONS_CONTENT_COLOR = "flutter.floating_ball_custom_notifications_buttons_content_color"
        private const val KEY_CUSTOM_NOTIFS_CLOSE_ICON_ID = "flutter.floating_ball_custom_notifications_close_icon_id"
        private const val KEY_CUSTOM_NOTIFS_CLOSE_ICON_PNG_BASE64 = "flutter.floating_ball_custom_notifications_close_icon_png_base64"
        private const val KEY_CUSTOM_NOTIFS_CLOSE_TEXT = "flutter.floating_ball_custom_notifications_close_text"
        private const val KEY_CUSTOM_NOTIFS_CLEAR_ALL_ICON_ID = "flutter.floating_ball_custom_notifications_clear_all_icon_id"
        private const val KEY_CUSTOM_NOTIFS_CLEAR_ALL_ICON_PNG_BASE64 = "flutter.floating_ball_custom_notifications_clear_all_icon_png_base64"
        private const val KEY_CUSTOM_NOTIFS_CLEAR_ALL_TEXT = "flutter.floating_ball_custom_notifications_clear_all_text"
        private const val KEY_CONVERSATION_BOTTOM_BUTTONS_GAP_DP = "flutter.floating_ball_conversation_bottom_buttons_gap_dp"
        private const val KEY_CONVERSATION_BOTTOM_BUTTONS_PADDING_HORZ_DP = "flutter.floating_ball_conversation_bottom_buttons_padding_horz_dp"
        private const val KEY_CONVERSATION_BOTTOM_BUTTONS_PADDING_VERT_DP = "flutter.floating_ball_conversation_bottom_buttons_padding_vert_dp"
        private const val KEY_FS_BAR_HEIGHT_DP = "flutter.floating_ball_fs_bar_height_dp"
        private const val KEY_FS_BAR_BG_COLOR = "flutter.floating_ball_fs_bar_bg_color"
        private const val KEY_FS_BAR_CONTENT_COLOR = "flutter.floating_ball_fs_bar_content_color"
        private const val KEY_FS_BAR_ICON_SIZE_DP = "flutter.floating_ball_fs_bar_icon_size_dp"
        private const val KEY_FS_BAR_TEXT_SIZE_SP = "flutter.floating_ball_fs_bar_text_size_sp"
        private const val KEY_FS_BAR_PADDING_HORZ_DP = "flutter.floating_ball_fs_bar_padding_horz_dp"
        private const val KEY_FS_BAR_PADDING_VERT_DP = "flutter.floating_ball_fs_bar_padding_vert_dp"
        private const val KEY_FS_BAR_WIFI_ICON_ID = "flutter.floating_ball_fs_bar_wifi_icon_id"
        private const val KEY_FS_BAR_WIFI_ICON_PNG_BASE64 = "flutter.floating_ball_fs_bar_wifi_icon_png_base64"
        private const val KEY_FS_BAR_BT_ICON_ID = "flutter.floating_ball_fs_bar_bt_icon_id"
        private const val KEY_FS_BAR_BT_ICON_PNG_BASE64 = "flutter.floating_ball_fs_bar_bt_icon_png_base64"
        private const val KEY_FS_BAR_DATA_ICON_ID = "flutter.floating_ball_fs_bar_data_icon_id"
        private const val KEY_FS_BAR_DATA_ICON_PNG_BASE64 = "flutter.floating_ball_fs_bar_data_icon_png_base64"
        private const val KEY_FS_BAR_LOC_ICON_ID = "flutter.floating_ball_fs_bar_loc_icon_id"
        private const val KEY_FS_BAR_LOC_ICON_PNG_BASE64 = "flutter.floating_ball_fs_bar_loc_icon_png_base64"
        private const val KEY_FS_BAR_BATTERY_ICON_ID = "flutter.floating_ball_fs_bar_battery_icon_id"
        private const val KEY_FS_BAR_BATTERY_ICON_PNG_BASE64 = "flutter.floating_ball_fs_bar_battery_icon_png_base64"
        private const val KEY_FS_BAR_MEDIA_RESTORE_ICON_ID = "flutter.floating_ball_fs_bar_media_restore_icon_id"
        private const val KEY_FS_BAR_MEDIA_RESTORE_ICON_PNG_BASE64 = "flutter.floating_ball_fs_bar_media_restore_icon_png_base64"
        private const val KEY_FS_BAR_TIME_COLOR = "flutter.floating_ball_fs_bar_time_color"
        private const val KEY_FS_BAR_WIFI_ICON_COLOR = "flutter.floating_ball_fs_bar_wifi_icon_color"
        private const val KEY_FS_BAR_BT_ICON_COLOR = "flutter.floating_ball_fs_bar_bt_icon_color"
        private const val KEY_FS_BAR_DATA_ICON_COLOR = "flutter.floating_ball_fs_bar_data_icon_color"
        private const val KEY_FS_BAR_LOC_ICON_COLOR = "flutter.floating_ball_fs_bar_loc_icon_color"
        private const val KEY_FS_BAR_BATTERY_ICON_COLOR = "flutter.floating_ball_fs_bar_battery_icon_color"
        private const val KEY_FS_BAR_BATTERY_TEXT_COLOR = "flutter.floating_ball_fs_bar_battery_text_color"
        private const val KEY_FS_BAR_RESTORE_ICON_COLOR = "flutter.floating_ball_fs_bar_restore_icon_color"
        private const val KEY_FS_BAR_RESTORE_BG_COLOR = "flutter.floating_ball_fs_bar_restore_bg_color"
        private const val KEY_FS_MEDIA_AUTO_SHOW = "flutter.floating_ball_fs_media_auto_show"
        private const val KEY_FS_CLOSE_HEIGHT_DP = "flutter.floating_ball_fs_close_height_dp"
        private const val KEY_FS_CLOSE_BG_COLOR = "flutter.floating_ball_fs_close_bg_color"
        private const val KEY_FS_CLOSE_TEXT_COLOR = "flutter.floating_ball_fs_close_text_color"
        private const val KEY_FS_CLOSE_HIDE_TEXT = "flutter.floating_ball_fs_close_hide_text"
        private const val KEY_FS_CLOSE_ICON_ID = "flutter.floating_ball_fs_close_icon_id"
        private const val KEY_FS_CLOSE_ICON_PNG_BASE64 = "flutter.floating_ball_fs_close_icon_png_base64"
        private const val KEY_FS_CLOSE_STICKY = "flutter.floating_ball_fs_close_sticky"
        private const val KEY_FS_CLOSE_DISABLE_STICKY_WHEN_MEDIA_ACTIVE = "flutter.floating_ball_fs_close_disable_sticky_when_media_active"
        private const val KEY_FS_CLOSE_TEXT = "flutter.floating_ball_fs_close_text"
        private const val KEY_FS_BACK_TEXT = "flutter.floating_ball_fs_back_text"
        private const val KEY_FS_HOME_TEXT = "flutter.floating_ball_fs_home_text"
        private const val KEY_FS_RECENTS_TEXT = "flutter.floating_ball_fs_recents_text"
        private const val KEY_FS_VOLUME_TEXT = "flutter.floating_ball_fs_volume_text"
        private const val KEY_FS_SETTINGS_TEXT = "flutter.floating_ball_fs_settings_text"
        private const val KEY_FS_BRIGHTNESS_TEXT = "flutter.floating_ball_fs_brightness_text"
        private const val KEY_FS_BACK_ICON_ID = "flutter.floating_ball_fs_back_icon_id"
        private const val KEY_FS_HOME_ICON_ID = "flutter.floating_ball_fs_home_icon_id"
        private const val KEY_FS_RECENTS_ICON_ID = "flutter.floating_ball_fs_recents_icon_id"
        private const val KEY_FS_VOLUME_ICON_ID = "flutter.floating_ball_fs_volume_icon_id"
        private const val KEY_FS_SETTINGS_ICON_ID = "flutter.floating_ball_fs_settings_icon_id"
        private const val KEY_FS_BRIGHTNESS_ICON_ID = "flutter.floating_ball_fs_brightness_icon_id"
        private const val KEY_FS_BACK_ICON_PNG_BASE64 = "flutter.floating_ball_fs_back_icon_png_base64"
        private const val KEY_FS_HOME_ICON_PNG_BASE64 = "flutter.floating_ball_fs_home_icon_png_base64"
        private const val KEY_FS_RECENTS_ICON_PNG_BASE64 = "flutter.floating_ball_fs_recents_icon_png_base64"
        private const val KEY_FS_VOLUME_ICON_PNG_BASE64 = "flutter.floating_ball_fs_volume_icon_png_base64"
        private const val KEY_FS_SETTINGS_ICON_PNG_BASE64 = "flutter.floating_ball_fs_settings_icon_png_base64"
        private const val KEY_FS_BRIGHTNESS_ICON_PNG_BASE64 = "flutter.floating_ball_fs_brightness_icon_png_base64"
        private const val KEY_FS_ORDER_JSON = "flutter.floating_ball_fs_order_json"
        private const val KEY_FS_APP_LABELS_JSON = "flutter.floating_ball_fs_app_labels_json"

        private const val KEY_POPUP_BG_COLOR = "flutter.floating_ball_popup_bg_color"
        private const val KEY_POPUP_BUTTON_COLOR = "flutter.floating_ball_popup_button_color"
        private const val KEY_POPUP_ICON_COLOR = "flutter.floating_ball_popup_icon_color"
        private const val KEY_POPUP_ICON_SIZE_DP = "flutter.floating_ball_popup_icon_size_dp"
        private const val KEY_POPUP_OFFSET_X_DP = "flutter.floating_ball_popup_offset_x_dp"
        private const val KEY_POPUP_OFFSET_Y_DP = "flutter.floating_ball_popup_offset_y_dp"
        private const val KEY_POPUP_MEDIA_OFFSET_X_DP = "flutter.floating_ball_popup_media_offset_x_dp"
        private const val KEY_POPUP_MEDIA_OFFSET_Y_DP = "flutter.floating_ball_popup_media_offset_y_dp"
        private const val KEY_POPUP_BACK_ICON_ID = "flutter.floating_ball_popup_back_icon_id"
        private const val KEY_POPUP_HOME_ICON_ID = "flutter.floating_ball_popup_home_icon_id"
        private const val KEY_POPUP_RECENTS_ICON_ID = "flutter.floating_ball_popup_recents_icon_id"
        private const val KEY_POPUP_VOLUME_ICON_ID = "flutter.floating_ball_popup_volume_icon_id"
        private const val KEY_POPUP_BRIGHTNESS_ICON_ID = "flutter.floating_ball_popup_brightness_icon_id"
        private const val KEY_POPUP_SETTINGS_ICON_ID = "flutter.floating_ball_popup_settings_icon_id"
        private const val KEY_POPUP_BACK_ICON_PNG_BASE64 = "flutter.floating_ball_popup_back_icon_png_base64"
        private const val KEY_POPUP_HOME_ICON_PNG_BASE64 = "flutter.floating_ball_popup_home_icon_png_base64"
        private const val KEY_POPUP_RECENTS_ICON_PNG_BASE64 = "flutter.floating_ball_popup_recents_icon_png_base64"
        private const val KEY_POPUP_VOLUME_ICON_PNG_BASE64 = "flutter.floating_ball_popup_volume_icon_png_base64"
        private const val KEY_POPUP_BRIGHTNESS_ICON_PNG_BASE64 = "flutter.floating_ball_popup_brightness_icon_png_base64"
        private const val KEY_POPUP_SETTINGS_ICON_PNG_BASE64 = "flutter.floating_ball_popup_settings_icon_png_base64"

        private const val ACTION_ACTIVE_NOTIFICATIONS_CHANGED = "com.example.connect.ACTIVE_NOTIFICATIONS_CHANGED"

        private const val KEY_MEDIA_HEIGHT_DP = "flutter.floating_ball_media_height_dp"
        private const val KEY_MEDIA_ICON_SIZE_DP = "flutter.floating_ball_media_icon_size_dp"
        private const val KEY_MEDIA_TITLE_SIZE_SP = "flutter.floating_ball_media_title_size_sp"
        private const val KEY_MEDIA_SUBTITLE_SIZE_SP = "flutter.floating_ball_media_subtitle_size_sp"
        private const val KEY_MEDIA_VOLUME_ICON_ID = "flutter.floating_ball_media_volume_icon_id"
        private const val KEY_MEDIA_PREV_ICON_ID = "flutter.floating_ball_media_prev_icon_id"
        private const val KEY_MEDIA_PLAY_ICON_ID = "flutter.floating_ball_media_play_icon_id"
        private const val KEY_MEDIA_PAUSE_ICON_ID = "flutter.floating_ball_media_pause_icon_id"
        private const val KEY_MEDIA_NEXT_ICON_ID = "flutter.floating_ball_media_next_icon_id"
        private const val KEY_MEDIA_VOLUME_ICON_PNG_BASE64 = "flutter.floating_ball_media_volume_icon_png_base64"
        private const val KEY_MEDIA_PREV_ICON_PNG_BASE64 = "flutter.floating_ball_media_prev_icon_png_base64"
        private const val KEY_MEDIA_PLAY_ICON_PNG_BASE64 = "flutter.floating_ball_media_play_icon_png_base64"
        private const val KEY_MEDIA_PAUSE_ICON_PNG_BASE64 = "flutter.floating_ball_media_pause_icon_png_base64"
        private const val KEY_MEDIA_NEXT_ICON_PNG_BASE64 = "flutter.floating_ball_media_next_icon_png_base64"

        private const val PREFS_MEDIA_CACHE = "bt_media_cache_v1"
        private const val KEY_MEDIA_JSON = "media_json"
        private const val KEY_MEDIA_UPDATED_AT_MS = "updatedAtMs"
        private const val PREFS_LOCAL_MEDIA_CACHE = "local_media_cache_v1"
        private const val KEY_PRIORITIZE_LOCAL_MEDIA = "flutter.prioritize_local_media"

        private const val PREFS_VOLUME_CACHE = "bt_volume_cache_v1"
        private const val KEY_VOLUME_PCT = "pct"
        private const val KEY_VOLUME_UPDATED_AT_MS = "updatedAtMs"
        private const val PREFS_POS = "FloatingBallPrefs"
        private const val KEY_POS_X = "pos_x"
        private const val KEY_POS_Y = "pos_y"

        fun resolveBallIconRes(iconId: String): Int {
            return when (iconId) {
                "info" -> android.R.drawable.ic_dialog_info
                "apps" -> android.R.drawable.ic_menu_view
                "play" -> android.R.drawable.ic_media_play
                "pause" -> android.R.drawable.ic_media_pause
                "skip_next" -> android.R.drawable.ic_media_next
                "skip_prev" -> android.R.drawable.ic_media_previous
                "settings" -> android.R.drawable.ic_menu_manage
                "flash" -> android.R.drawable.ic_lock_idle_charging
                "star" -> android.R.drawable.star_big_on
                "home" -> android.R.drawable.ic_menu_myplaces
                "back" -> android.R.drawable.ic_media_previous
                "recent" -> android.R.drawable.ic_menu_recent_history
                "search" -> android.R.drawable.ic_menu_search
                "add" -> android.R.drawable.ic_menu_add
                "edit" -> android.R.drawable.ic_menu_edit
                "delete" -> android.R.drawable.ic_menu_delete
                "close" -> android.R.drawable.ic_menu_close_clear_cancel
                "phone" -> android.R.drawable.ic_menu_call
                "sms" -> android.R.drawable.sym_action_chat
                "email" -> android.R.drawable.ic_dialog_email
                "camera" -> android.R.drawable.ic_menu_camera
                "photo" -> android.R.drawable.ic_menu_gallery
                "music" -> android.R.drawable.ic_media_play
                "volume" -> android.R.drawable.ic_lock_silent_mode_off
                "brightness" -> android.R.drawable.ic_lock_idle_charging
                "wifi" -> android.R.drawable.ic_menu_manage
                "bluetooth" -> android.R.drawable.ic_menu_manage
                "data" -> android.R.drawable.ic_menu_send
                "location" -> android.R.drawable.ic_menu_mylocation
                "map" -> android.R.drawable.ic_menu_mapmode
                "calendar" -> android.R.drawable.ic_menu_my_calendar
                "alarm" -> android.R.drawable.ic_lock_idle_alarm
                "timer" -> android.R.drawable.ic_lock_idle_alarm
                "lock" -> android.R.drawable.ic_lock_lock
                "unlock" -> android.R.drawable.ic_lock_idle_lock
                "share" -> android.R.drawable.ic_menu_share
                "send" -> android.R.drawable.ic_menu_send
                "download" -> android.R.drawable.ic_menu_save
                "upload" -> android.R.drawable.ic_menu_send
                "refresh" -> android.R.drawable.ic_popup_sync
                "power" -> android.R.drawable.ic_lock_power_off
                "battery" -> android.R.drawable.ic_lock_idle_low_battery
                "bolt" -> android.R.drawable.ic_lock_idle_charging
                "folder" -> android.R.drawable.ic_menu_agenda
                "file" -> android.R.drawable.ic_menu_save
                "chat" -> android.R.drawable.sym_action_chat
                "help" -> android.R.drawable.ic_menu_help
                "warning" -> android.R.drawable.ic_dialog_alert
                "check" -> android.R.drawable.checkbox_on_background
                "qr" -> android.R.drawable.ic_menu_camera
                "link" -> android.R.drawable.ic_menu_share
                "key" -> android.R.drawable.ic_secure
                "shield" -> android.R.drawable.ic_secure
                "game" -> android.R.drawable.ic_media_play
                "tv" -> android.R.drawable.ic_media_play
                "car" -> android.R.drawable.ic_menu_directions
                "walk" -> android.R.drawable.ic_menu_directions
                "watch" -> android.R.drawable.ic_lock_idle_alarm
                "light" -> android.R.drawable.ic_lock_idle_charging
                "bookmark" -> android.R.drawable.star_big_on
                "cloud" -> android.R.drawable.ic_popup_sync
                else -> android.R.drawable.ic_dialog_info
            }
        }
    }

    private var wm: WindowManager? = null
    private var ballView: View? = null
    private var ballLp: WindowManager.LayoutParams? = null
    private var ballIconView: ImageView? = null
    private var menuView: View? = null
    private var menuLp: WindowManager.LayoutParams? = null
    private var modalHostView: FrameLayout? = null
    private var modalHostLp: WindowManager.LayoutParams? = null
    private var volumeModalView: View? = null
    private var brightnessModalView: View? = null
    private var fsBarView: View? = null
    private var fsBarTick: Runnable? = null
    private var fsBarTimeTv: TextView? = null
    private var fsBarRestoreIv: ImageView? = null
    private var fsBarWifiIv: ImageView? = null
    private var fsBarBtIv: ImageView? = null
    private var fsBarDataIv: ImageView? = null
    private var fsBarLocIv: ImageView? = null
    private var fsBarBatteryIv: ImageView? = null
    private var fsBarBatteryTv: TextView? = null
    private var fsFullScreenContent: LinearLayout? = null
    private var fsScrollView: ScrollView? = null
    private var fsNotifsList: LinearLayout? = null
    private var fsNotifsEmptyTv: TextView? = null
    private var fsNotifsScrollView: ScrollView? = null
    private val fsNotifsRowByKey = HashMap<String, View>()
    private var fsNotifsTick: Runnable? = null
    private var fsNotifsVisible: Boolean = false
    private var fsNotifsRowDragging: Boolean = false
    private var fsNotifsEventsReceiver: BroadcastReceiver? = null
    private var fsMediaDismissedByUser: Boolean = false
    private var fsBlockScrollForMediaDrag: Boolean = false
    private var lastMediaStateRequestAtMs: Long = 0L

    private val mainHandler = Handler(Looper.getMainLooper())
    private var accessibilityWatchdog: Runnable? = null
    private var lastAccessibilityEnabled: Boolean? = null
    private var lastAccessibilityPromptAtMs: Long = 0L
    private var selectedApps: List<String> = emptyList()
    private var ballColor: Int = 0xCC000000.toInt()
    private var ballIconId: String = "info"
    private var ballIconPngBase64: String? = null
    private var ballIconColor: Int = 0xFFFFFFFF.toInt()
    private var ballIconSizeDp: Int = 28
    private var ballSizeDp: Int = 56
    private var fullScreenMenu: Boolean = true
    private var gesturesEnabled: Boolean = false
    private var gestureLongPressMs: Int = 450
    private var gestureUpAction: String = "notifications"
    private var gestureRightAction: String = "home"
    private var gestureDownAction: String = "recents"
    private var gestureLeftAction: String = "back"
    private var gestureUpApp: String? = null
    private var gestureRightApp: String? = null
    private var gestureDownApp: String? = null
    private var gestureLeftApp: String? = null
    private var gestureVibrationMs: Int = 35
    private var gestureVibrationAmplitude: Int = 180
    private var gestureNotificationsUseCustomScreen: Boolean = false
    private var fsBgColor: Int = 0xDD111111.toInt()
    private var fsButtonColor: Int = 0x22111111.toInt()
    private var fsContentColor: Int = 0xFFFFFFFF.toInt()
    private var fsIconColor: Int = 0xFFFFFFFF.toInt()
    private var fsTextColor: Int = 0xFFFFFFFF.toInt()
    private var fsHideText: Boolean = false
    private var fsIconSizeDp: Int = 34
    private var fsTextSizeSp: Int = 14
    private var fsTileGapDp: Int = 10
    private var fsTilePaddingDp: Int = 0
    private var fsStickyPaddingDp: Int = 16
    private var fsTileInnerGapDp: Int = 10
    private var fsTileHeightDp: Int = 120
    private var fsTileBorderColor: Int = 0x22FFFFFF.toInt()
    private var fsAppsButtonColor: Int = 0x22111111.toInt()
    private var fsAppsTileGapDp: Int = 10
    private var fsAppsTileHeightDp: Int = 120
    private var fsAppsTileBorderColor: Int = 0x22FFFFFF.toInt()
    private var fsAppsIconSizeDp: Int = 34
    private var fsContainerPaddingHorzDp: Int = 16
    private var fsContainerPaddingVertDp: Int = 16
    private var fsSystemCols: Int = 1
    private var fsAppsCols: Int = 1
    private var fsBarEnabled: Boolean = false
    private var fsCustomNotificationsEnabled: Boolean = false
    private var cnBgColor: Int = 0xDD111111.toInt()
    private var cnItemBgColor: Int = 0x22111111.toInt()
    private var cnItemBorderColor: Int = 0x22FFFFFF.toInt()
    private var cnTitleColor: Int = 0xFFFFFFFF.toInt()
    private var cnTextColor: Int = 0xFFFFFFFF.toInt()
    private var cnTitleSizeSp: Int = 16
    private var cnTextSizeSp: Int = 14
    private var cnButtonsIconHeightDp: Int = 34
    private var cnDeleteIconId: String = "delete"
    private var cnDeleteIconPngBase64: String? = null
    private var cnDeleteText: String = "Eliminar"
    private var cnButtonsHideText: Boolean = false
    private var cnButtonsHeightDp: Int = 52
    private var cnButtonsBgColor: Int = 0xFF202020.toInt()
    private var cnButtonsBorderColor: Int = 0x22FFFFFF.toInt()
    private var cnButtonsContentColor: Int = 0xFFFFFFFF.toInt()
    private var cnCloseIconId: String = "close"
    private var cnCloseIconPngBase64: String? = null
    private var cnCloseText: String = "Cerrar"
    private var cnClearAllIconId: String = "delete"
    private var cnClearAllIconPngBase64: String? = null
    private var cnClearAllText: String = "Eliminar todo"
    private var convBottomButtonsGapDp: Int = 10
    private var convBottomButtonsPaddingHorzDp: Int = 14
    private var convBottomButtonsPaddingVertDp: Int = 10
    private var fsBarHeightDp: Int = 54
    private var fsBarBgColor: Int = 0xCC111111.toInt()
    private var fsBarContentColor: Int = 0xFFFFFFFF.toInt()
    private var fsBarIconSizeDp: Int = 18
    private var fsBarTextSizeSp: Int = 14
    private var fsBarPaddingHorzDp: Int = 16
    private var fsBarPaddingVertDp: Int = 0
    private var fsBarWifiIconId: String = "wifi"
    private var fsBarWifiIconPngBase64: String? = null
    private var fsBarBtIconId: String = "bluetooth"
    private var fsBarBtIconPngBase64: String? = null
    private var fsBarDataIconId: String = "data"
    private var fsBarDataIconPngBase64: String? = null
    private var fsBarLocIconId: String = "location"
    private var fsBarLocIconPngBase64: String? = null
    private var fsBarBatteryIconId: String = "battery"
    private var fsBarBatteryIconPngBase64: String? = null
    private var fsBarMediaRestoreIconId: String = "play"
    private var fsBarMediaRestoreIconPngBase64: String? = null
    private var fsBarTimeColor: Int = 0xFFFFFFFF.toInt()
    private var fsBarWifiIconColor: Int = 0xFFFFFFFF.toInt()
    private var fsBarBtIconColor: Int = 0xFFFFFFFF.toInt()
    private var fsBarDataIconColor: Int = 0xFFFFFFFF.toInt()
    private var fsBarLocIconColor: Int = 0xFFFFFFFF.toInt()
    private var fsBarBatteryIconColor: Int = 0xFFFFFFFF.toInt()
    private var fsBarBatteryTextColor: Int = 0xFFFFFFFF.toInt()
    private var fsBarRestoreIconColor: Int = 0xFFFFFFFF.toInt()
    private var fsBarRestoreBgColor: Int = 0x33FFFFFF
    private var fsMediaAutoShow: Boolean = true
    private var fsCloseHeightDp: Int = 120
    private var fsCloseBgColor: Int = 0xFFDC2626.toInt()
    private var fsCloseTextColor: Int = 0xFFFFFFFF.toInt()
    private var fsCloseHideText: Boolean = false
    private var fsCloseIconId: String = "close"
    private var fsCloseIconPngBase64: String? = null
    private var fsCloseSticky: Boolean = false
    private var fsCloseDisableStickyWhenMediaActive: Boolean = true
    private var fsCloseText: String = "Cerrar"
    private var fsBackText: String = "Back"
    private var fsHomeText: String = "Home"
    private var fsRecentsText: String = "Recientes"
    private var fsVolumeText: String = "Volumen"
    private var fsSettingsText: String = "Ajustes"
    private var fsBrightnessText: String = "Brillo"
    private var fsBackIconId: String = "back"
    private var fsHomeIconId: String = "home"
    private var fsRecentsIconId: String = "recent"
    private var fsVolumeIconId: String = "volume"
    private var fsSettingsIconId: String = "settings"
    private var fsBrightnessIconId: String = "brightness"
    private var fsBackIconPngBase64: String? = null
    private var fsHomeIconPngBase64: String? = null
    private var fsRecentsIconPngBase64: String? = null
    private var fsVolumeIconPngBase64: String? = null
    private var fsSettingsIconPngBase64: String? = null
    private var fsBrightnessIconPngBase64: String? = null
    private var fsOrder: List<String> = emptyList()
    private var fsAppLabels: Map<String, String> = emptyMap()
    private var useAsReceptor: Boolean = false
    private var mediaModalView: View? = null
    private var mediaModalTick: Runnable? = null
    private var popupBgColor: Int = 0xDD111111.toInt()
    private var popupButtonColor: Int = 0x22111111.toInt()
    private var popupIconColor: Int = 0xFFFFFFFF.toInt()
    private var popupIconSizeDp: Int = 26
    private var popupOffsetXDp: Int = 0
    private var popupOffsetYDp: Int = 0
    private var popupMediaOffsetXDp: Int = 0
    private var popupMediaOffsetYDp: Int = 0
    private var popupBackIconId: String = "back"
    private var popupHomeIconId: String = "home"
    private var popupRecentsIconId: String = "recent"
    private var popupVolumeIconId: String = "volume"
    private var popupBrightnessIconId: String = "brightness"
    private var popupSettingsIconId: String = "settings"
    private var popupBackIconPngBase64: String? = null
    private var popupHomeIconPngBase64: String? = null
    private var popupRecentsIconPngBase64: String? = null
    private var popupVolumeIconPngBase64: String? = null
    private var popupBrightnessIconPngBase64: String? = null
    private var popupSettingsIconPngBase64: String? = null
    private var mediaHeightDp: Int = 320
    private var mediaIconSizeDp: Int = 34
    private var mediaTitleSizeSp: Int = 18
    private var mediaSubtitleSizeSp: Int = 14
    private var mediaVolumeIconId: String = "volume"
    private var mediaPrevIconId: String = "skip_prev"
    private var mediaPlayIconId: String = "play"
    private var mediaPauseIconId: String = "pause"
    private var mediaNextIconId: String = "skip_next"
    private var mediaVolumeIconPngBase64: String? = null
    private var mediaPrevIconPngBase64: String? = null
    private var mediaPlayIconPngBase64: String? = null
    private var mediaPauseIconPngBase64: String? = null
    private var mediaNextIconPngBase64: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildForegroundNotification())
        loadConfig()
        ensureBall()
        startAccessibilityWatchdog()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                loadConfig()
                ensureBall()
                applyBallStyle()
            }
            ACTION_UPDATE_CONFIG -> {
                loadConfig()
                ensureBall()
                applyBallStyle()
                rebuildMenuIfVisible()
            }
            ACTION_DISMISS_MENU -> {
                hideMenu()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        try { stopAccessibilityWatchdog() } catch (_: Exception) {}
        try { hideMenu() } catch (_: Exception) {}
        try { removeBall() } catch (_: Exception) {}
        try { scheduleRestartIfEnabled() } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun scheduleRestartIfEnabled() {
        val enabled = isEnabled()
        if (!enabled) return
        val i = Intent(applicationContext, FloatingBallService::class.java).setAction(ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            applicationContext.startForegroundService(i)
        } else {
            applicationContext.startService(i)
        }
    }

    private fun isEnabled(): Boolean {
        return try {
            val prefs = getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            prefs.getBoolean(KEY_ENABLED, false)
        } catch (_: Exception) {
            false
        }
    }

    private fun loadConfig() {
        selectedApps = readSelectedApps()
        loadStyleConfig()
    }

    private fun loadStyleConfig() {
        try {
            val prefs = getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            ballColor = readColor(prefs, KEY_BALL_COLOR, 0xCC000000.toInt())
            ballIconId = prefs.getString(KEY_BALL_ICON, "info") ?: "info"
            ballIconPngBase64 = prefs.getString(KEY_BALL_ICON_PNG_BASE64, null)
            ballIconColor = readColor(prefs, KEY_BALL_ICON_COLOR, 0xFFFFFFFF.toInt())
            ballIconSizeDp = readIntPref(prefs, KEY_BALL_ICON_SIZE_DP, 28)
            ballSizeDp = readIntPref(prefs, KEY_BALL_SIZE_DP, 56)
            fullScreenMenu = prefs.getBoolean(KEY_FULLSCREEN, true)
            gesturesEnabled = readBoolPref(prefs, KEY_GESTURES_ENABLED, false)
            gestureLongPressMs = readIntPref(prefs, KEY_GESTURE_LONG_PRESS_MS, 450).coerceIn(150, 2000)
            gestureUpAction = (prefs.getString(KEY_GESTURE_UP_ACTION, "notifications") ?: "notifications").trim().ifEmpty { "notifications" }
            gestureRightAction = (prefs.getString(KEY_GESTURE_RIGHT_ACTION, "home") ?: "home").trim().ifEmpty { "home" }
            gestureDownAction = (prefs.getString(KEY_GESTURE_DOWN_ACTION, "recents") ?: "recents").trim().ifEmpty { "recents" }
            gestureLeftAction = (prefs.getString(KEY_GESTURE_LEFT_ACTION, "back") ?: "back").trim().ifEmpty { "back" }
            gestureUpApp = prefs.getString(KEY_GESTURE_UP_APP, null)?.trim().orEmpty().ifEmpty { null }
            gestureRightApp = prefs.getString(KEY_GESTURE_RIGHT_APP, null)?.trim().orEmpty().ifEmpty { null }
            gestureDownApp = prefs.getString(KEY_GESTURE_DOWN_APP, null)?.trim().orEmpty().ifEmpty { null }
            gestureLeftApp = prefs.getString(KEY_GESTURE_LEFT_APP, null)?.trim().orEmpty().ifEmpty { null }
            gestureVibrationMs = readIntPref(prefs, KEY_GESTURE_VIBRATION_MS, 35).coerceIn(0, 500)
            gestureVibrationAmplitude = readIntPref(prefs, KEY_GESTURE_VIBRATION_AMPLITUDE, 180).coerceIn(1, 255)
            gestureNotificationsUseCustomScreen =
                readBoolPref(prefs, KEY_GESTURE_NOTIFICATIONS_USE_CUSTOM_SCREEN, false)
            fsBgColor = readColor(prefs, KEY_FS_BG_COLOR, 0xDD111111.toInt())
            fsButtonColor = readColor(prefs, KEY_FS_BUTTON_COLOR, 0x22111111.toInt())
            fsContentColor = readColor(prefs, KEY_FS_CONTENT_COLOR, 0xFFFFFFFF.toInt())
            fsIconColor = readColor(prefs, KEY_FS_ICON_COLOR, fsContentColor)
            fsTextColor = readColor(prefs, KEY_FS_TEXT_COLOR, fsContentColor)
            fsHideText = prefs.getBoolean(KEY_FS_HIDE_TEXT, false)
            fsIconSizeDp = readIntPref(prefs, KEY_FS_ICON_SIZE_DP, 34)
            fsAppsIconSizeDp = readIntPref(prefs, KEY_FS_APPS_ICON_SIZE_DP, fsIconSizeDp).coerceIn(10, 120)
            fsTextSizeSp = readIntPref(prefs, KEY_FS_TEXT_SIZE_SP, 14)
            fsTileGapDp = readIntPref(prefs, KEY_FS_TILE_GAP_DP, 10)
            fsTilePaddingDp = readIntPref(prefs, KEY_FS_TILE_PADDING_DP, 0)
            fsStickyPaddingDp = readIntPref(prefs, KEY_FS_STICKY_PADDING_DP, 16)
            fsTileInnerGapDp = readIntPref(prefs, KEY_FS_TILE_INNER_GAP_DP, 10)
            fsTileHeightDp = readIntPref(prefs, KEY_FS_TILE_HEIGHT_DP, 120)
            fsTileBorderColor = readColor(prefs, KEY_FS_TILE_BORDER_COLOR, 0x22FFFFFF.toInt())
            fsAppsButtonColor = readColor(prefs, KEY_FS_APPS_BUTTON_COLOR, fsButtonColor)
            fsAppsTileGapDp = readIntPref(prefs, KEY_FS_APPS_TILE_GAP_DP, fsTileGapDp).coerceIn(0, 40)
            fsAppsTileHeightDp = readIntPref(prefs, KEY_FS_APPS_TILE_HEIGHT_DP, fsTileHeightDp).coerceIn(60, 300)
            fsAppsTileBorderColor = readColor(prefs, KEY_FS_APPS_TILE_BORDER_COLOR, fsTileBorderColor)
            fsContainerPaddingHorzDp = readIntPref(prefs, KEY_FS_CONTAINER_PADDING_HORZ_DP, 16).coerceIn(0, 120)
            fsContainerPaddingVertDp = readIntPref(prefs, KEY_FS_CONTAINER_PADDING_VERT_DP, 16).coerceIn(0, 120)
            fsSystemCols = readIntPref(prefs, KEY_FS_SYSTEM_COLS, 1).coerceIn(1, 4)
            fsAppsCols = readIntPref(prefs, KEY_FS_APPS_COLS, 1).coerceIn(1, 4)
            fsBarEnabled = prefs.getBoolean(KEY_FS_BAR_ENABLED, false)
            fsCustomNotificationsEnabled =
                readBoolPref(prefs, KEY_FS_CUSTOM_NOTIFICATIONS_ENABLED, false)
            cnBgColor = readColor(prefs, KEY_CUSTOM_NOTIFS_BG_COLOR, fsBgColor)
            cnItemBgColor = readColor(prefs, KEY_CUSTOM_NOTIFS_ITEM_BG_COLOR, fsButtonColor)
            cnItemBorderColor = readColor(prefs, KEY_CUSTOM_NOTIFS_ITEM_BORDER_COLOR, fsTileBorderColor)
            cnTitleColor = readColor(prefs, KEY_CUSTOM_NOTIFS_TITLE_COLOR, 0xFFFFFFFF.toInt())
            cnTextColor = readColor(prefs, KEY_CUSTOM_NOTIFS_TEXT_COLOR, 0xFFFFFFFF.toInt())
            cnTitleSizeSp = readIntPref(prefs, KEY_CUSTOM_NOTIFS_TITLE_SIZE_SP, 16).coerceIn(8, 32)
            cnTextSizeSp = readIntPref(prefs, KEY_CUSTOM_NOTIFS_TEXT_SIZE_SP, 14).coerceIn(8, 32)
            cnButtonsIconHeightDp = readIntPref(prefs, KEY_CUSTOM_NOTIFS_BUTTONS_ICON_HEIGHT_DP, 34).coerceIn(10, 120)
            cnDeleteIconId = (prefs.getString(KEY_CUSTOM_NOTIFS_DELETE_ICON_ID, "delete") ?: "delete").trim().ifEmpty { "delete" }
            cnDeleteIconPngBase64 = prefs.getString(KEY_CUSTOM_NOTIFS_DELETE_ICON_PNG_BASE64, null)
            cnDeleteText = (prefs.getString(KEY_CUSTOM_NOTIFS_DELETE_TEXT, "Eliminar") ?: "Eliminar").trim().ifEmpty { "Eliminar" }
            cnButtonsHideText = prefs.getBoolean(KEY_CUSTOM_NOTIFS_BUTTONS_HIDE_TEXT, false)
            cnButtonsHeightDp = readIntPref(prefs, KEY_CUSTOM_NOTIFS_BUTTONS_HEIGHT_DP, 52).coerceIn(36, 160)
            cnButtonsBgColor = readColor(prefs, KEY_CUSTOM_NOTIFS_BUTTONS_BG_COLOR, 0xFF202020.toInt())
            cnButtonsBorderColor = readColor(prefs, KEY_CUSTOM_NOTIFS_BUTTONS_BORDER_COLOR, 0x22FFFFFF.toInt())
            cnButtonsContentColor = readColor(prefs, KEY_CUSTOM_NOTIFS_BUTTONS_CONTENT_COLOR, 0xFFFFFFFF.toInt())
            cnCloseIconId = (prefs.getString(KEY_CUSTOM_NOTIFS_CLOSE_ICON_ID, "close") ?: "close").trim().ifEmpty { "close" }
            cnCloseIconPngBase64 = prefs.getString(KEY_CUSTOM_NOTIFS_CLOSE_ICON_PNG_BASE64, null)
            cnCloseText = (prefs.getString(KEY_CUSTOM_NOTIFS_CLOSE_TEXT, "Cerrar") ?: "Cerrar").trim().ifEmpty { "Cerrar" }
            cnClearAllIconId = (prefs.getString(KEY_CUSTOM_NOTIFS_CLEAR_ALL_ICON_ID, "delete") ?: "delete").trim().ifEmpty { "delete" }
            cnClearAllIconPngBase64 = prefs.getString(KEY_CUSTOM_NOTIFS_CLEAR_ALL_ICON_PNG_BASE64, null)
            cnClearAllText = (prefs.getString(KEY_CUSTOM_NOTIFS_CLEAR_ALL_TEXT, "Eliminar todo") ?: "Eliminar todo").trim().ifEmpty { "Eliminar todo" }
            convBottomButtonsGapDp = readIntPref(prefs, KEY_CONVERSATION_BOTTOM_BUTTONS_GAP_DP, 10).coerceIn(0, 60)
            convBottomButtonsPaddingHorzDp = readIntPref(prefs, KEY_CONVERSATION_BOTTOM_BUTTONS_PADDING_HORZ_DP, 14).coerceIn(0, 60)
            convBottomButtonsPaddingVertDp = readIntPref(prefs, KEY_CONVERSATION_BOTTOM_BUTTONS_PADDING_VERT_DP, 10).coerceIn(0, 60)
            fsBarHeightDp = readIntPref(prefs, KEY_FS_BAR_HEIGHT_DP, 54).coerceIn(36, 160)
            fsBarBgColor = readColor(prefs, KEY_FS_BAR_BG_COLOR, 0xCC111111.toInt())
            fsBarContentColor = readColor(prefs, KEY_FS_BAR_CONTENT_COLOR, 0xFFFFFFFF.toInt())
            fsBarIconSizeDp = readIntPref(prefs, KEY_FS_BAR_ICON_SIZE_DP, 18).coerceIn(10, 64)
            fsBarTextSizeSp = readIntPref(prefs, KEY_FS_BAR_TEXT_SIZE_SP, 14).coerceIn(8, 32)
            fsBarPaddingHorzDp = readIntPref(prefs, KEY_FS_BAR_PADDING_HORZ_DP, 30).coerceIn(0, 200)
            fsBarPaddingVertDp = readIntPref(prefs, KEY_FS_BAR_PADDING_VERT_DP, 0).coerceIn(0, 30)
            fsBarWifiIconId = (prefs.getString(KEY_FS_BAR_WIFI_ICON_ID, "wifi") ?: "wifi").trim().ifEmpty { "wifi" }
            fsBarWifiIconPngBase64 = prefs.getString(KEY_FS_BAR_WIFI_ICON_PNG_BASE64, null)
            fsBarBtIconId = (prefs.getString(KEY_FS_BAR_BT_ICON_ID, "bluetooth") ?: "bluetooth").trim().ifEmpty { "bluetooth" }
            fsBarBtIconPngBase64 = prefs.getString(KEY_FS_BAR_BT_ICON_PNG_BASE64, null)
            fsBarDataIconId = (prefs.getString(KEY_FS_BAR_DATA_ICON_ID, "data") ?: "data").trim().ifEmpty { "data" }
            fsBarDataIconPngBase64 = prefs.getString(KEY_FS_BAR_DATA_ICON_PNG_BASE64, null)
            fsBarLocIconId = (prefs.getString(KEY_FS_BAR_LOC_ICON_ID, "location") ?: "location").trim().ifEmpty { "location" }
            fsBarLocIconPngBase64 = prefs.getString(KEY_FS_BAR_LOC_ICON_PNG_BASE64, null)
            fsBarBatteryIconId = (prefs.getString(KEY_FS_BAR_BATTERY_ICON_ID, "battery") ?: "battery").trim().ifEmpty { "battery" }
            fsBarBatteryIconPngBase64 = prefs.getString(KEY_FS_BAR_BATTERY_ICON_PNG_BASE64, null)
            fsBarMediaRestoreIconId = (prefs.getString(KEY_FS_BAR_MEDIA_RESTORE_ICON_ID, "play") ?: "play").trim().ifEmpty { "play" }
            fsBarMediaRestoreIconPngBase64 = prefs.getString(KEY_FS_BAR_MEDIA_RESTORE_ICON_PNG_BASE64, null)
            fsBarTimeColor = readColor(prefs, KEY_FS_BAR_TIME_COLOR, fsBarContentColor)
            fsBarWifiIconColor = readColor(prefs, KEY_FS_BAR_WIFI_ICON_COLOR, fsBarContentColor)
            fsBarBtIconColor = readColor(prefs, KEY_FS_BAR_BT_ICON_COLOR, fsBarContentColor)
            fsBarDataIconColor = readColor(prefs, KEY_FS_BAR_DATA_ICON_COLOR, fsBarContentColor)
            fsBarLocIconColor = readColor(prefs, KEY_FS_BAR_LOC_ICON_COLOR, fsBarContentColor)
            fsBarBatteryIconColor = readColor(prefs, KEY_FS_BAR_BATTERY_ICON_COLOR, fsBarContentColor)
            fsBarBatteryTextColor = readColor(prefs, KEY_FS_BAR_BATTERY_TEXT_COLOR, fsBarContentColor)
            fsBarRestoreIconColor = readColor(prefs, KEY_FS_BAR_RESTORE_ICON_COLOR, fsBarContentColor)
            fsBarRestoreBgColor = readColor(prefs, KEY_FS_BAR_RESTORE_BG_COLOR, 0x33FFFFFF)
            fsMediaAutoShow = prefs.getBoolean(KEY_FS_MEDIA_AUTO_SHOW, true)
            fsCloseHeightDp = readIntPref(prefs, KEY_FS_CLOSE_HEIGHT_DP, 120)
            fsCloseBgColor = readColor(prefs, KEY_FS_CLOSE_BG_COLOR, 0xFFDC2626.toInt())
            fsCloseTextColor = readColor(prefs, KEY_FS_CLOSE_TEXT_COLOR, 0xFFFFFFFF.toInt())
            fsCloseHideText = prefs.getBoolean(KEY_FS_CLOSE_HIDE_TEXT, false)
            fsCloseIconId = (prefs.getString(KEY_FS_CLOSE_ICON_ID, "close") ?: "close").trim().ifEmpty { "close" }
            fsCloseIconPngBase64 = prefs.getString(KEY_FS_CLOSE_ICON_PNG_BASE64, null)
            fsCloseSticky = prefs.getBoolean(KEY_FS_CLOSE_STICKY, false)
            fsCloseDisableStickyWhenMediaActive = prefs.getBoolean(KEY_FS_CLOSE_DISABLE_STICKY_WHEN_MEDIA_ACTIVE, true)
            fsCloseText = (prefs.getString(KEY_FS_CLOSE_TEXT, "Cerrar") ?: "Cerrar").trim().ifEmpty { "Cerrar" }
            fsBackText = (prefs.getString(KEY_FS_BACK_TEXT, "Back") ?: "Back").trim().ifEmpty { "Back" }
            fsHomeText = (prefs.getString(KEY_FS_HOME_TEXT, "Home") ?: "Home").trim().ifEmpty { "Home" }
            fsRecentsText = (prefs.getString(KEY_FS_RECENTS_TEXT, "Recientes") ?: "Recientes").trim().ifEmpty { "Recientes" }
            fsVolumeText = (prefs.getString(KEY_FS_VOLUME_TEXT, "Volumen") ?: "Volumen").trim().ifEmpty { "Volumen" }
            fsSettingsText = (prefs.getString(KEY_FS_SETTINGS_TEXT, "Ajustes") ?: "Ajustes").trim().ifEmpty { "Ajustes" }
            fsBrightnessText = (prefs.getString(KEY_FS_BRIGHTNESS_TEXT, "Brillo") ?: "Brillo").trim().ifEmpty { "Brillo" }
            fsBackIconId = (prefs.getString(KEY_FS_BACK_ICON_ID, "back") ?: "back").trim().ifEmpty { "back" }
            fsHomeIconId = (prefs.getString(KEY_FS_HOME_ICON_ID, "home") ?: "home").trim().ifEmpty { "home" }
            fsRecentsIconId = (prefs.getString(KEY_FS_RECENTS_ICON_ID, "recent") ?: "recent").trim().ifEmpty { "recent" }
            fsVolumeIconId = (prefs.getString(KEY_FS_VOLUME_ICON_ID, "volume") ?: "volume").trim().ifEmpty { "volume" }
            fsSettingsIconId = (prefs.getString(KEY_FS_SETTINGS_ICON_ID, "settings") ?: "settings").trim().ifEmpty { "settings" }
            fsBrightnessIconId = (prefs.getString(KEY_FS_BRIGHTNESS_ICON_ID, "brightness") ?: "brightness").trim().ifEmpty { "brightness" }
            fsBackIconPngBase64 = prefs.getString(KEY_FS_BACK_ICON_PNG_BASE64, null)
            fsHomeIconPngBase64 = prefs.getString(KEY_FS_HOME_ICON_PNG_BASE64, null)
            fsRecentsIconPngBase64 = prefs.getString(KEY_FS_RECENTS_ICON_PNG_BASE64, null)
            fsVolumeIconPngBase64 = prefs.getString(KEY_FS_VOLUME_ICON_PNG_BASE64, null)
            fsSettingsIconPngBase64 = prefs.getString(KEY_FS_SETTINGS_ICON_PNG_BASE64, null)
            fsBrightnessIconPngBase64 = prefs.getString(KEY_FS_BRIGHTNESS_ICON_PNG_BASE64, null)
            fsOrder = readStringListJson(prefs.getString(KEY_FS_ORDER_JSON, null))
            fsAppLabels = readStringMapJson(prefs.getString(KEY_FS_APP_LABELS_JSON, null))
            useAsReceptor = prefs.getBoolean(KEY_USE_AS_RECEPTOR, false)

            popupBgColor = readColor(prefs, KEY_POPUP_BG_COLOR, fsBgColor)
            popupButtonColor = readColor(prefs, KEY_POPUP_BUTTON_COLOR, fsButtonColor)
            popupIconColor = readColor(prefs, KEY_POPUP_ICON_COLOR, fsIconColor)
            popupIconSizeDp = readIntPref(prefs, KEY_POPUP_ICON_SIZE_DP, 26).coerceIn(10, 120)
            popupOffsetXDp = readIntPref(prefs, KEY_POPUP_OFFSET_X_DP, 0).coerceIn(-300, 300)
            popupOffsetYDp = readIntPref(prefs, KEY_POPUP_OFFSET_Y_DP, 0).coerceIn(-300, 300)
            popupMediaOffsetXDp = readIntPref(prefs, KEY_POPUP_MEDIA_OFFSET_X_DP, 0).coerceIn(-400, 400)
            popupMediaOffsetYDp = readIntPref(prefs, KEY_POPUP_MEDIA_OFFSET_Y_DP, 0).coerceIn(-600, 600)
            popupBackIconId = (prefs.getString(KEY_POPUP_BACK_ICON_ID, fsBackIconId) ?: fsBackIconId).trim().ifEmpty { fsBackIconId }
            popupHomeIconId = (prefs.getString(KEY_POPUP_HOME_ICON_ID, fsHomeIconId) ?: fsHomeIconId).trim().ifEmpty { fsHomeIconId }
            popupRecentsIconId = (prefs.getString(KEY_POPUP_RECENTS_ICON_ID, fsRecentsIconId) ?: fsRecentsIconId).trim().ifEmpty { fsRecentsIconId }
            popupVolumeIconId = (prefs.getString(KEY_POPUP_VOLUME_ICON_ID, fsVolumeIconId) ?: fsVolumeIconId).trim().ifEmpty { fsVolumeIconId }
            popupBrightnessIconId = (prefs.getString(KEY_POPUP_BRIGHTNESS_ICON_ID, fsBrightnessIconId) ?: fsBrightnessIconId).trim().ifEmpty { fsBrightnessIconId }
            popupSettingsIconId = (prefs.getString(KEY_POPUP_SETTINGS_ICON_ID, fsSettingsIconId) ?: fsSettingsIconId).trim().ifEmpty { fsSettingsIconId }
            popupBackIconPngBase64 = prefs.getString(KEY_POPUP_BACK_ICON_PNG_BASE64, null) ?: fsBackIconPngBase64
            popupHomeIconPngBase64 = prefs.getString(KEY_POPUP_HOME_ICON_PNG_BASE64, null) ?: fsHomeIconPngBase64
            popupRecentsIconPngBase64 = prefs.getString(KEY_POPUP_RECENTS_ICON_PNG_BASE64, null) ?: fsRecentsIconPngBase64
            popupVolumeIconPngBase64 = prefs.getString(KEY_POPUP_VOLUME_ICON_PNG_BASE64, null) ?: fsVolumeIconPngBase64
            popupBrightnessIconPngBase64 = prefs.getString(KEY_POPUP_BRIGHTNESS_ICON_PNG_BASE64, null) ?: fsBrightnessIconPngBase64
            popupSettingsIconPngBase64 = prefs.getString(KEY_POPUP_SETTINGS_ICON_PNG_BASE64, null) ?: fsSettingsIconPngBase64

            mediaHeightDp = readIntPref(prefs, KEY_MEDIA_HEIGHT_DP, 320)
            mediaIconSizeDp = readIntPref(prefs, KEY_MEDIA_ICON_SIZE_DP, 34)
            mediaTitleSizeSp = readIntPref(prefs, KEY_MEDIA_TITLE_SIZE_SP, 18)
            mediaSubtitleSizeSp = readIntPref(prefs, KEY_MEDIA_SUBTITLE_SIZE_SP, 14)
            mediaVolumeIconId = (prefs.getString(KEY_MEDIA_VOLUME_ICON_ID, "volume") ?: "volume").trim().ifEmpty { "volume" }
            mediaPrevIconId = (prefs.getString(KEY_MEDIA_PREV_ICON_ID, "skip_prev") ?: "skip_prev").trim().ifEmpty { "skip_prev" }
            mediaPlayIconId = (prefs.getString(KEY_MEDIA_PLAY_ICON_ID, "play") ?: "play").trim().ifEmpty { "play" }
            mediaPauseIconId = (prefs.getString(KEY_MEDIA_PAUSE_ICON_ID, "pause") ?: "pause").trim().ifEmpty { "pause" }
            mediaNextIconId = (prefs.getString(KEY_MEDIA_NEXT_ICON_ID, "skip_next") ?: "skip_next").trim().ifEmpty { "skip_next" }
            mediaVolumeIconPngBase64 = prefs.getString(KEY_MEDIA_VOLUME_ICON_PNG_BASE64, null)
            mediaPrevIconPngBase64 = prefs.getString(KEY_MEDIA_PREV_ICON_PNG_BASE64, null)
            mediaPlayIconPngBase64 = prefs.getString(KEY_MEDIA_PLAY_ICON_PNG_BASE64, null)
            mediaPauseIconPngBase64 = prefs.getString(KEY_MEDIA_PAUSE_ICON_PNG_BASE64, null)
            mediaNextIconPngBase64 = prefs.getString(KEY_MEDIA_NEXT_ICON_PNG_BASE64, null)
        } catch (_: Exception) {
        }
    }

    private fun readIntPref(prefs: android.content.SharedPreferences, key: String, defaultValue: Int): Int {
        return try {
            val v = prefs.all[key]
            when (v) {
                is Int -> v
                is Long -> v.toInt()
                is String -> v.toLongOrNull()?.toInt() ?: defaultValue
                else -> defaultValue
            }
        } catch (_: Exception) {
            defaultValue
        }
    }

    private fun readBoolPref(prefs: android.content.SharedPreferences, key: String, defaultValue: Boolean): Boolean {
        return try {
            val v = prefs.all[key]
            when (v) {
                is Boolean -> v
                is String -> v.equals("true", ignoreCase = true) || v == "1"
                is Int -> v != 0
                is Long -> v != 0L
                else -> defaultValue
            }
        } catch (_: Exception) {
            defaultValue
        }
    }

    private fun readStringListJson(raw: String?): List<String> {
        val s = raw?.trim().orEmpty()
        if (s.isEmpty()) return emptyList()
        return try {
            val arr = JSONArray(s)
            val out = ArrayList<String>(arr.length())
            for (i in 0 until arr.length()) {
                val v = arr.optString(i, "").trim()
                if (v.isNotEmpty()) out.add(v)
            }
            out
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun readStringMapJson(raw: String?): Map<String, String> {
        val s = raw?.trim().orEmpty()
        if (s.isEmpty()) return emptyMap()
        return try {
            val obj = JSONObject(s)
            val out = HashMap<String, String>()
            val it = obj.keys()
            while (it.hasNext()) {
                val k = it.next().trim()
                val v = obj.optString(k, "").trim()
                if (k.isNotEmpty() && v.isNotEmpty()) out[k] = v
            }
            out
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun decodePngBase64(raw: String?): android.graphics.Bitmap? {
        var s = raw?.trim().orEmpty()
        if (s.isEmpty()) return null
        if (s.startsWith("data:", ignoreCase = true) && s.contains(",")) {
            s = s.substringAfter(",").trim()
        }
        return try {
            val bytes = Base64.decode(s, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (_: Exception) {
            null
        }
    }

    private fun readColor(prefs: android.content.SharedPreferences, key: String, defaultArgb: Int): Int {
        return try {
            val v = prefs.all[key]
            when (v) {
                is Int -> v
                is Long -> v.toInt()
                is String -> v.toLongOrNull()?.toInt() ?: defaultArgb
                else -> defaultArgb
            }
        } catch (_: Exception) {
            try {
                prefs.getLong(key, defaultArgb.toLong()).toInt()
            } catch (_: Exception) {
                defaultArgb
            }
        }
    }

    private fun decodeBallIconBitmap(): android.graphics.Bitmap? {
        val raw = ballIconPngBase64?.trim().orEmpty()
        if (raw.isEmpty()) return null
        return try {
            val bytes = Base64.decode(raw, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (_: Exception) {
            null
        }
    }

    private fun readSelectedApps(): List<String> {
        val raw = try {
            val prefs = getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            prefs.getString(KEY_APPS_JSON, null)
        } catch (_: Exception) {
            null
        } ?: return emptyList()

        return try {
            val arr = JSONArray(raw)
            val out = ArrayList<String>(arr.length())
            for (i in 0 until arr.length()) {
                val pkg = arr.optString(i, "").trim()
                if (pkg.isNotEmpty()) out.add(pkg)
            }
            out
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun ensureBall() {
        if (!isEnabled()) return
        if (!canDrawOverlays()) return
        if (ballView != null) return
        val windowManager = wm ?: return

        val sizePx = dp(ballSizeDp.coerceIn(36, 120))
        val container = FrameLayout(this)

        val bg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(ballColor)
            setStroke(dp(2), Color.parseColor("#33FFFFFF"))
        }
        container.background = bg
        container.layoutParams = FrameLayout.LayoutParams(sizePx, sizePx)

        val icon = ImageView(this).apply {
            val bmp = decodeBallIconBitmap()
            if (bmp != null) setImageBitmap(bmp) else setImageResource(resolveBallIconRes(ballIconId))
            setColorFilter(ballIconColor)
            val maxPx = (sizePx - dp(8)).coerceAtLeast(dp(10))
            val iconPx = dp(ballIconSizeDp).coerceAtMost(maxPx)
            layoutParams = FrameLayout.LayoutParams(iconPx, iconPx, Gravity.CENTER)
        }
        container.addView(icon)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val initial = readSavedPosition()
        val lp = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = initial.first
            y = initial.second
        }

        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var moved = false
        var repositioning = false
        var longPressRunnable: Runnable? = null
        var snapBackAnimator: ValueAnimator? = null

        fun startSnapBack(targetX: Int, targetY: Int) {
            val fromX = lp.x
            val fromY = lp.y
            if (fromX == targetX && fromY == targetY) return
            snapBackAnimator?.cancel()
            val anim = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 140L
                interpolator = DecelerateInterpolator()
                addUpdateListener { a ->
                    val t = a.animatedFraction
                    lp.x = (fromX + ((targetX - fromX).toFloat() * t)).roundToInt()
                    lp.y = (fromY + ((targetY - fromY).toFloat() * t)).roundToInt()
                    try { windowManager.updateViewLayout(container, lp) } catch (_: Exception) {}
                }
            }
            snapBackAnimator = anim
            try {
                anim.start()
            } catch (_: Exception) {
            }
        }

        container.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startX = lp.x
                    startY = lp.y
                    moved = false
                    repositioning = false
                    snapBackAnimator?.cancel()
                    longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                    longPressRunnable = null
                    if (gesturesEnabled) {
                        val r = Runnable {
                            repositioning = true
                        }
                        longPressRunnable = r
                        mainHandler.postDelayed(r, gestureLongPressMs.toLong())
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dxF = event.rawX - downX
                    val dyF = event.rawY - downY
                    if (gesturesEnabled) {
                        if (!repositioning) {
                            if (abs(dxF) > dp(10).toFloat() || abs(dyF) > dp(10).toFloat()) {
                                longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                                longPressRunnable = null
                            }
                            lp.x = startX + dxF.toInt()
                            lp.y = startY + dyF.toInt()
                            try { windowManager.updateViewLayout(container, lp) } catch (_: Exception) {}
                            return@setOnTouchListener true
                        }
                    }

                    val dx = dxF.toInt()
                    val dy = dyF.toInt()
                    if (abs(dx) > dp(3) || abs(dy) > dp(3)) moved = true
                    lp.x = startX + dx
                    lp.y = startY + dy
                    try { windowManager.updateViewLayout(container, lp) } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (gesturesEnabled) {
                        longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                        longPressRunnable = null

                        val dxF = event.rawX - downX
                        val dyF = event.rawY - downY
                        val tapSlop = dp(8)
                        val gestureThreshold = dp(36)

                        if (repositioning) {
                            savePosition(lp.x, lp.y)
                            repositioning = false
                            return@setOnTouchListener true
                        }

                        val absDx = abs(dxF).toInt()
                        val absDy = abs(dyF).toInt()
                        startSnapBack(startX, startY)
                        if (absDx <= tapSlop && absDy <= tapSlop) {
                            toggleMenu(startX, startY)
                            return@setOnTouchListener true
                        }

                        if (absDx >= gestureThreshold || absDy >= gestureThreshold) {
                            val isHorizontal = absDx > absDy
                            val action = if (isHorizontal) {
                                if (dxF > 0) gestureRightAction else gestureLeftAction
                            } else {
                                if (dyF > 0) gestureDownAction else gestureUpAction
                            }
                            val pkg = if (isHorizontal) {
                                if (dxF > 0) gestureRightApp else gestureLeftApp
                            } else {
                                if (dyF > 0) gestureDownApp else gestureUpApp
                            }
                            performGestureVibration()
                            performGestureAction(action, pkg)
                        }
                        return@setOnTouchListener true
                    }

                    savePosition(lp.x, lp.y)
                    if (!moved) toggleMenu(lp.x, lp.y)
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    if (gesturesEnabled && !repositioning) {
                        longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                        longPressRunnable = null
                        startSnapBack(startX, startY)
                        return@setOnTouchListener true
                    }
                    false
                }
                else -> false
            }
        }

        ballView = container
        ballLp = lp
        ballIconView = icon
        try {
            windowManager.addView(container, lp)
        } catch (_: Exception) {
            ballView = null
            ballLp = null
            ballIconView = null
        }
    }

    private fun applyBallStyle() {
        mainHandler.post {
            val v = ballView as? FrameLayout ?: return@post
            val sizePx = dp(ballSizeDp.coerceIn(36, 120))
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(ballColor)
                setStroke(dp(2), Color.parseColor("#33FFFFFF"))
            }
            v.background = bg
            val icon = ballIconView ?: (v.getChildAt(0) as? ImageView)
            val bmp = decodeBallIconBitmap()
            if (bmp != null) icon?.setImageBitmap(bmp) else icon?.setImageResource(resolveBallIconRes(ballIconId))
            icon?.setColorFilter(ballIconColor)
            try {
                val maxPx = (sizePx - dp(8)).coerceAtLeast(dp(10))
                val iconPx = dp(ballIconSizeDp).coerceAtMost(maxPx)
                val lp = icon?.layoutParams
                if (lp != null) {
                    lp.width = iconPx
                    lp.height = iconPx
                    icon.layoutParams = lp
                }
            } catch (_: Exception) {
            }
            try {
                v.invalidate()
                icon?.invalidate()
                val windowManager = wm
                val lp = ballLp
                if (windowManager != null && lp != null) {
                    lp.width = sizePx
                    lp.height = sizePx
                    windowManager.updateViewLayout(v, lp)
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun removeBall() {
        val windowManager = wm ?: return
        val v = ballView ?: return
        try { windowManager.removeView(v) } catch (_: Exception) {}
        ballView = null
        ballLp = null
        ballIconView = null
    }

    private fun toggleMenu(anchorX: Int, anchorY: Int) {
        if (menuView != null) {
            hideMenu()
        } else {
            if (fullScreenMenu) {
                showFullScreenMenu()
            } else {
                if (useAsReceptor && readSelectedMediaStateOrNull() != null) {
                    showMediaPopupMenu()
                } else {
                    showPopupMenu(anchorX, anchorY)
                }
            }
        }
    }

    private fun ensureModalHost(): FrameLayout? {
        val windowManager = wm ?: return null
        val existing = modalHostView
        if (existing != null) return existing

        val root = FrameLayout(this)
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }

        modalHostView = root
        modalHostLp = lp
        try {
            windowManager.addView(root, lp)
        } catch (_: Exception) {
            modalHostView = null
            modalHostLp = null
            return null
        }
        return root
    }

    private fun maybeRemoveModalHost() {
        val root = modalHostView ?: return
        if (volumeModalView != null || brightnessModalView != null) return
        val windowManager = wm
        try {
            if (windowManager != null) windowManager.removeView(root)
        } catch (_: Exception) {
        }
        modalHostView = null
        modalHostLp = null
    }

    private fun performGestureVibration() {
        val dur = gestureVibrationMs.coerceIn(0, 500)
        if (dur <= 0) return
        val amp = gestureVibrationAmplitude.coerceIn(1, 255)
        try {
            val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            } ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(VibrationEffect.createOneShot(dur.toLong(), amp))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(dur.toLong())
            }
        } catch (_: Exception) {
        }
    }

    private fun performNotificationsGestureAction() {
        if (gestureNotificationsUseCustomScreen) {
            openCustomNotificationsScreen()
            return
        }
        val ok = try {
            FloatingBallAccessibilityService.performGlobalActionSafe(AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS) ||
                FloatingBallAccessibilityService.performGlobalActionSafe(AccessibilityService.GLOBAL_ACTION_QUICK_SETTINGS)
        } catch (_: Exception) {
            false
        }
        if (!ok) {
            Toast.makeText(this, "Activa el servicio de accesibilidad de Connect", Toast.LENGTH_SHORT).show()
            maybeOpenAccessibilitySettings()
        }
    }

    private fun openCustomNotificationsScreen() {
        if (!fsCustomNotificationsEnabled) return
        fsNotifsVisible = true
        showFullScreenMenu()
    }

    private fun performGestureAction(actionId: String, packageName: String?) {
        when (actionId) {
            "back" -> performGlobal(AccessibilityService.GLOBAL_ACTION_BACK)
            "home" -> performGlobal(AccessibilityService.GLOBAL_ACTION_HOME)
            "recents" -> performGlobal(AccessibilityService.GLOBAL_ACTION_RECENTS)
            "notifications" -> performNotificationsGestureAction()
            "settings" -> {
                try {
                    val i = Intent(Settings.ACTION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(i)
                } catch (_: Exception) {
                }
            }
            "volume" -> {
                val host = ensureModalHost() ?: return
                showVolumeModal(host)
            }
            "brightness" -> {
                val host = ensureModalHost() ?: return
                showBrightnessModal(host)
            }
            "app" -> {
                val pkg = packageName?.trim().orEmpty()
                if (pkg.isNotEmpty()) launchPackage(pkg)
            }
        }
    }

    private fun isSelectedMediaPlayingFresh(): Boolean {
        return try {
            val now = System.currentTimeMillis()
            val obj = readSelectedMediaFreshOrNull(now) ?: return false
            obj.optBoolean("isPlaying", false)
        } catch (_: Exception) {
            false
        }
    }

    private fun readSelectedMediaFreshOrNull(now: Long): JSONObject? {
        val flutterPrefs = getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
        val prioritizeLocal = readBoolPref(flutterPrefs, KEY_PRIORITIZE_LOCAL_MEDIA, false)
        val remoteConnected = try { BtClassicServerService.connectedPeers > 0 } catch (_: Exception) { false }
        val remoteFresh = remoteConnected && isMediaFresh(PREFS_MEDIA_CACHE, now)
        val localFresh = isMediaFresh(PREFS_LOCAL_MEDIA_CACHE, now)
        val useLocal = if (prioritizeLocal) localFresh || !remoteFresh else !remoteFresh && localFresh
        return readMediaJsonOrNull(if (useLocal) PREFS_LOCAL_MEDIA_CACHE else PREFS_MEDIA_CACHE, onlyFresh = true, now = now)
            ?: readMediaJsonOrNull(if (useLocal) PREFS_MEDIA_CACHE else PREFS_LOCAL_MEDIA_CACHE, onlyFresh = true, now = now)
    }

    private fun readSelectedMediaStateOrNull(): JSONObject? {
        return try {
            val now = System.currentTimeMillis()
            val flutterPrefs = getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val prioritizeLocal = readBoolPref(flutterPrefs, KEY_PRIORITIZE_LOCAL_MEDIA, false)
            val remoteConnected = try { BtClassicServerService.connectedPeers > 0 } catch (_: Exception) { false }
            val remoteFresh = remoteConnected && isMediaFresh(PREFS_MEDIA_CACHE, now)
            val localFresh = isMediaFresh(PREFS_LOCAL_MEDIA_CACHE, now)
            if (!remoteFresh && !localFresh) return null
            val useLocal = if (prioritizeLocal) localFresh || !remoteFresh else !remoteFresh && localFresh

            val (selectedPrefs, fallbackPrefs) = if (useLocal) {
                Pair(PREFS_LOCAL_MEDIA_CACHE, PREFS_MEDIA_CACHE)
            } else {
                Pair(PREFS_MEDIA_CACHE, PREFS_LOCAL_MEDIA_CACHE)
            }

            readMediaJsonOrNull(selectedPrefs, onlyFresh = true, now = now)
                ?: readMediaJsonOrNull(fallbackPrefs, onlyFresh = true, now = now)
        } catch (_: Exception) {
            null
        }
    }

    private fun readLocalVolumePctOrNull(): Int? {
        return try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager ?: return null
            val stream = android.media.AudioManager.STREAM_MUSIC
            val level = audio.getStreamVolume(stream)
            val max = audio.getStreamMaxVolume(stream)
            if (max <= 0) return null
            ((level.toDouble() / max.toDouble()) * 100.0).toInt().coerceIn(0, 100)
        } catch (_: Exception) {
            null
        }
    }

    private fun readSelectedVolumePctFreshOrNull(): Int? {
        return try {
            val now = System.currentTimeMillis()
            val flutterPrefs = getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val prioritizeLocal = readBoolPref(flutterPrefs, KEY_PRIORITIZE_LOCAL_MEDIA, false)
            val remoteConnected = try { BtClassicServerService.connectedPeers > 0 } catch (_: Exception) { false }
            val remoteFresh = remoteConnected && isMediaFresh(PREFS_MEDIA_CACHE, now)
            val localFresh = isMediaFresh(PREFS_LOCAL_MEDIA_CACHE, now)
            val useLocal = if (prioritizeLocal) localFresh || !remoteFresh else !remoteFresh && localFresh
            if (useLocal) return readLocalVolumePctOrNull()

            val prefs = getSharedPreferences(PREFS_VOLUME_CACHE, Context.MODE_PRIVATE)
            val updatedAtMs = prefs.getLong(KEY_VOLUME_UPDATED_AT_MS, 0L)
            if (updatedAtMs <= 0L || now - updatedAtMs > 15_000L) return null
            prefs.getInt(KEY_VOLUME_PCT, 0).coerceIn(0, 100)
        } catch (_: Exception) {
            null
        }
    }

    private fun isMediaFresh(prefsName: String, now: Long): Boolean {
        return try {
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_MEDIA_JSON, null)
            val updatedAtMs = prefs.getLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
            !json.isNullOrBlank() && updatedAtMs > 0L && now - updatedAtMs <= 15_000L
        } catch (_: Exception) {
            false
        }
    }

    private fun shouldUseLocalMediaForControls(now: Long): Boolean {
        return try {
            val flutterPrefs = getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val prioritizeLocal = readBoolPref(flutterPrefs, KEY_PRIORITIZE_LOCAL_MEDIA, false)
            val remoteConnected = try { BtClassicServerService.connectedPeers > 0 } catch (_: Exception) { false }
            val remoteFresh = remoteConnected && isMediaFresh(PREFS_MEDIA_CACHE, now)
            val localFresh = isMediaFresh(PREFS_LOCAL_MEDIA_CACHE, now)
            if (prioritizeLocal) {
                localFresh || !remoteFresh
            } else {
                !remoteFresh && localFresh
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun getMediaUpdatedAtMs(prefsName: String): Long {
        return try {
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            prefs.getLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
        } catch (_: Exception) {
            0L
        }
    }

    private fun readMediaJsonOrNull(prefsName: String, onlyFresh: Boolean, now: Long): JSONObject? {
        return try {
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_MEDIA_JSON, null)
            val updatedAtMs = prefs.getLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
            if (json.isNullOrBlank() || updatedAtMs <= 0L) return null
            if (onlyFresh && now - updatedAtMs > 15_000L) return null
            JSONObject(json)
        } catch (_: Exception) {
            null
        }
    }

    private fun sendBtServerJson(payloadJson: String) {
        try {
            val i = Intent(this, BtClassicServerService::class.java)
                .setAction(BtClassicServerService.ACTION_SEND_TO_PEERS)
                .putExtra(BtClassicServerService.EXTRA_JSON, payloadJson)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
        } catch (_: Exception) {
        }
    }

    private fun sendMediaCommand(command: String) {
        try {
            val payload = JSONObject()
            payload.put("type", "media_command")
            payload.put("command", command)
            payload.put("time", System.currentTimeMillis())
            sendBtServerJson(payload.toString())
        } catch (_: Exception) {
        }
    }

    private fun sendMediaCommand(command: String, positionMs: Long) {
        try {
            val payload = JSONObject()
            payload.put("type", "media_command")
            payload.put("command", command)
            payload.put("positionMs", positionMs)
            payload.put("time", System.currentTimeMillis())
            sendBtServerJson(payload.toString())
        } catch (_: Exception) {
        }
    }

    private fun sendVolumeCommand(pct: Int) {
        try {
            val payload = JSONObject()
            payload.put("type", "volume_command")
            payload.put("pct", pct.coerceIn(0, 100))
            payload.put("time", System.currentTimeMillis())
            sendBtServerJson(payload.toString())
        } catch (_: Exception) {
        }
    }

    private fun sendVolumeRequest() {
        try {
            val payload = JSONObject()
            payload.put("type", "volume_request")
            payload.put("time", System.currentTimeMillis())
            sendBtServerJson(payload.toString())
        } catch (_: Exception) {
        }
    }

    private fun formatMs(ms: Long): String {
        if (ms <= 0L) return "0:00"
        val totalSeconds = (ms / 1000L).coerceAtLeast(0L)
        val seconds = (totalSeconds % 60L).toInt()
        val totalMinutes = (totalSeconds / 60L).toInt()
        val minutes = totalMinutes % 60
        val hours = totalMinutes / 60
        val ss = if (seconds < 10) "0$seconds" else seconds.toString()
        return if (hours > 0) {
            val mm = if (minutes < 10) "0$minutes" else minutes.toString()
            "$hours:$mm:$ss"
        } else {
            "$minutes:$ss"
        }
    }

    private fun showMediaPopupMenu() {
        if (!canDrawOverlays()) return
        val windowManager = wm ?: return
        hideMenu()

        val root = FrameLayout(this).apply {
            isClickable = true
            setOnClickListener { }
        }

        fun buttonBgDrawable(): GradientDrawable {
            return GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(fsButtonColor)
                setStroke(dp(1), Color.parseColor("#22FFFFFF"))
            }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(fsBgColor)
                setStroke(dp(1), Color.parseColor("#22FFFFFF"))
            }
            background = bg
            setPadding(dp(16), dp(16), dp(16), dp(16))
            isClickable = true
            setOnClickListener { }
        }

        val mediaProgressBar = android.widget.ProgressBar(
            this,
            null,
            android.R.attr.progressBarStyleHorizontal
        ).apply {
            max = 1000
            progress = 0
        }

        var lastDurationMs = 0L
        var scrubbing = false
        fun progressToPct(x: Float, widthPx: Int): Int {
            if (widthPx <= 0) return 0
            val ratio = (x / widthPx.toFloat()).coerceIn(0f, 1f)
            return (ratio * 1000f).toInt().coerceIn(0, 1000)
        }
        mediaProgressBar.setOnTouchListener { v, ev ->
            val dur = lastDurationMs
            if (dur <= 0L) return@setOnTouchListener false
            val w = v.width
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                    scrubbing = true
                    mediaProgressBar.progress = progressToPct(ev.x, w)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val pct = progressToPct(ev.x, w)
                    mediaProgressBar.progress = pct
                    val posMs = ((pct.toDouble() / 1000.0) * dur.toDouble()).toLong().coerceIn(0L, dur)
                    sendMediaCommand("seekTo", posMs)
                    scrubbing = false
                    true
                }
                else -> false
            }
        }

        card.addView(
            mediaProgressBar,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(8)
            )
        )

        val controlsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val rowLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(62)).apply {
            topMargin = dp(14)
        }

        fun buildControlButton(
            iconId: String,
            iconPngBase64: String?,
            onClick: () -> Unit
        ): FrameLayout {
            val box = FrameLayout(this).apply {
                background = buttonBgDrawable()
                isClickable = true
                setOnClickListener { onClick() }
            }
            val iv = ImageView(this).apply {
                val bmp = decodePngBase64(iconPngBase64)
                if (bmp != null) {
                    setImageBitmap(bmp)
                } else {
                    setImageResource(resolveBallIconRes(iconId))
                }
                setColorFilter(fsIconColor)
            }
            val iconPx = dp(mediaIconSizeDp.coerceIn(16, 120)).coerceAtMost(dp(40))
            box.addView(iv, FrameLayout.LayoutParams(iconPx, iconPx, Gravity.CENTER))
            box.tag = iv
            return box
        }

        val volumeContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        val volumeSeek = SeekBar(this).apply {
            max = 100
            progress = readSelectedVolumePctFreshOrNull() ?: 0
            visibility = View.GONE
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (!fromUser) return
                    sendVolumeCommand(progress)
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }

        val btnVolume = buildControlButton(mediaVolumeIconId, mediaVolumeIconPngBase64) {
            sendVolumeRequest()
            volumeSeek.visibility = if (volumeSeek.visibility == View.VISIBLE) View.GONE else View.VISIBLE
            val pct = readSelectedVolumePctFreshOrNull()
            if (pct != null) volumeSeek.progress = pct
        }
        val btnPrev = buildControlButton(mediaPrevIconId, mediaPrevIconPngBase64) {
            sendMediaCommand("previous")
        }
        val btnPlayPause = buildControlButton(mediaPlayIconId, mediaPlayIconPngBase64) {
            sendMediaCommand("toggle")
        }
        val btnNext = buildControlButton(mediaNextIconId, mediaNextIconPngBase64) {
            sendMediaCommand("next")
        }

        val btnLp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f).apply {
            rightMargin = dp(10)
        }
        controlsRow.addView(btnVolume, btnLp)
        controlsRow.addView(btnPrev, btnLp)
        controlsRow.addView(btnPlayPause, btnLp)
        controlsRow.addView(btnNext, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f))

        volumeContainer.addView(controlsRow, rowLp)
        volumeContainer.addView(
            volumeSeek,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(10)
            }
        )
        card.addView(volumeContainer)

        root.addView(card, FrameLayout.LayoutParams(dp(340), FrameLayout.LayoutParams.WRAP_CONTENT))

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            val ball = ballLp
            val anchorX = ball?.x ?: 0
            val anchorY = ball?.y ?: 0
            val dm = resources.displayMetrics
            val cardW = dp(340)
            val estH = dp(130)
            val posX = (anchorX + dp(60) + dp(popupMediaOffsetXDp)).coerceIn(0, (dm.widthPixels - cardW).coerceAtLeast(0))
            val posY = (anchorY - dp(10) + dp(popupMediaOffsetYDp)).coerceIn(0, (dm.heightPixels - estH).coerceAtLeast(0))
            x = posX
            y = posY
        }

        fun refreshUi() {
            val media = readSelectedMediaStateOrNull()
            if (media == null) {
                hideMenu()
                return
            }
            val isPlaying = media.optBoolean("isPlaying", false)
            val dur = try { media.optLong("durationMs", 0L) } catch (_: Exception) { 0L }
            val pos = try { media.optLong("positionMs", 0L) } catch (_: Exception) { 0L }
            lastDurationMs = dur
            val pct = if (dur > 0L) ((pos.toDouble() / dur.toDouble()) * 1000.0).toInt().coerceIn(0, 1000) else 0
            if (!scrubbing) mediaProgressBar.progress = pct

            val iv = (btnPlayPause.tag as? ImageView)
            val playPauseRes = if (isPlaying) resolveBallIconRes(mediaPauseIconId) else resolveBallIconRes(mediaPlayIconId)
            if (decodePngBase64(if (isPlaying) mediaPauseIconPngBase64 else mediaPlayIconPngBase64) != null) {
                val bmp = decodePngBase64(if (isPlaying) mediaPauseIconPngBase64 else mediaPlayIconPngBase64)
                if (bmp != null) iv?.setImageBitmap(bmp)
            } else {
                iv?.setImageResource(playPauseRes)
            }

            val vol = readSelectedVolumePctFreshOrNull()
            if (vol != null && volumeSeek.visibility == View.VISIBLE) {
                volumeSeek.progress = vol
            }
        }

        mediaModalView = card
        menuView = root
        menuLp = lp
        try {
            windowManager.addView(root, lp)
        } catch (_: Exception) {
            mediaModalView = null
            menuView = null
            menuLp = null
            return
        }

        refreshUi()
        val tick = object : Runnable {
            override fun run() {
                if (menuView == null || mediaModalView == null) return
                refreshUi()
                mainHandler.postDelayed(this, 1000L)
            }
        }
        mediaModalTick = tick
        mainHandler.postDelayed(tick, 1000L)
    }

    private fun hideMediaPopupModal(root: FrameLayout) {
        try {
            mediaModalTick?.let { mainHandler.removeCallbacks(it) }
        } catch (_: Exception) {
        }
        mediaModalTick = null
        val v = mediaModalView ?: return
        val parent = v.parent
        if (parent is android.view.ViewGroup) {
            try { parent.removeView(v) } catch (_: Exception) {}
        } else {
            try { root.removeView(v) } catch (_: Exception) {}
        }
        mediaModalView = null
    }

    private fun showPopupMenu(anchorX: Int, anchorY: Int) {
        if (!canDrawOverlays()) return
        val windowManager = wm ?: return
        hideMenu()

        val root = FrameLayout(this).apply {
            isClickable = true
            setOnClickListener { hideMenu() }
        }

        val menu = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(popupBgColor)
                setStroke(dp(1), Color.parseColor("#22FFFFFF"))
            }
            background = bg
            isClickable = true
            setOnClickListener { }
        }

        val pad = dp(12)
        menu.setPadding(pad, pad, pad, pad)

        val scroll = ScrollView(this).apply {
            isFillViewport = true
            isClickable = true
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            isClickable = true
        }

        fun buttonBgDrawable(): GradientDrawable {
            return GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(popupButtonColor)
                setStroke(dp(1), Color.parseColor("#22FFFFFF"))
            }
        }

        val boxSize = dp(54)
        val iconSizePx = dp(popupIconSizeDp.coerceIn(10, 120)).coerceAtMost(boxSize - dp(18))

        fun buildPopupButton(
            iconId: String?,
            iconPngBase64: String?,
            appIcon: Drawable?,
            dismissOnClick: Boolean = true,
            onClick: () -> Unit
        ): View {
            val box = FrameLayout(this).apply {
                background = buttonBgDrawable()
                isClickable = true
                setOnClickListener {
                    if (dismissOnClick) hideMenu()
                    onClick()
                }
            }
            val iv = ImageView(this).apply {
                if (appIcon != null) {
                    setImageDrawable(appIcon)
                } else {
                    val bmp = decodePngBase64(iconPngBase64)
                    if (bmp != null) {
                        setImageBitmap(bmp)
                    } else {
                        setImageResource(resolveBallIconRes(iconId ?: "info"))
                    }
                    setColorFilter(popupIconColor)
                }
            }
            box.addView(iv, FrameLayout.LayoutParams(iconSizePx, iconSizePx, Gravity.CENTER))
            box.layoutParams = LinearLayout.LayoutParams(boxSize, boxSize).apply {
                bottomMargin = dp(10)
            }
            return box
        }

        content.addView(
            buildPopupButton(popupBackIconId, popupBackIconPngBase64, null) {
                performGlobal(AccessibilityService.GLOBAL_ACTION_BACK)
            }
        )
        content.addView(
            buildPopupButton(popupHomeIconId, popupHomeIconPngBase64, null) {
                performGlobal(AccessibilityService.GLOBAL_ACTION_HOME)
            }
        )
        content.addView(
            buildPopupButton(popupRecentsIconId, popupRecentsIconPngBase64, null) {
                performGlobal(AccessibilityService.GLOBAL_ACTION_RECENTS)
            }
        )
        content.addView(
            buildPopupButton(popupVolumeIconId, popupVolumeIconPngBase64, null, dismissOnClick = false) {
                showVolumeModal(root)
            }
        )
        content.addView(
            buildPopupButton(popupBrightnessIconId, popupBrightnessIconPngBase64, null, dismissOnClick = false) {
                showBrightnessModal(root)
            }
        )
        content.addView(
            buildPopupButton(popupSettingsIconId, popupSettingsIconPngBase64, null) {
                try {
                    val i = Intent(Settings.ACTION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(i)
                } catch (_: Exception) {
                }
            }
        )

        if (selectedApps.isNotEmpty()) {
            val divider = View(this).apply {
                setBackgroundColor(Color.parseColor("#22FFFFFF"))
            }
            content.addView(
                divider,
                LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(1)).apply {
                    topMargin = dp(6)
                    bottomMargin = dp(12)
                }
            )
        }

        for (pkg in selectedApps) {
            val icon = try {
                packageManager.getApplicationIcon(pkg)
            } catch (_: Exception) {
                null
            } ?: continue
            content.addView(
                buildPopupButton(null, null, icon) {
                    launchPackage(pkg)
                }
            )
        }

        scroll.addView(
            content,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            )
        )
        menu.addView(
            scroll,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                ((boxSize + dp(10)) * 6) - dp(10)
            )
        )

        val menuX = (anchorX + dp(60) + dp(popupOffsetXDp)).coerceAtLeast(0)
        val menuY = (anchorY - dp(10) + dp(popupOffsetYDp)).coerceAtLeast(0)
        root.addView(
            menu,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.TOP or Gravity.START
                leftMargin = menuX
                topMargin = menuY
            }
        )

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }

        menuView = root
        menuLp = lp
        try {
            windowManager.addView(root, lp)
            mainHandler.postDelayed({ hideMenu() }, 4500L)
        } catch (_: Exception) {
            menuView = null
            menuLp = null
        }
    }

    private data class FsItem(
        val id: String,
        val title: String,
        val iconId: String? = null,
        val iconPngBase64: String? = null,
        val appIcon: Drawable? = null,
        val onClick: () -> Unit
    )

    private fun showFullScreenMenu() {
        if (!canDrawOverlays()) return
        val windowManager = wm ?: return
        val desiredNotifsVisible = fsNotifsVisible
        hideMenu()
        fsNotifsVisible = desiredNotifsVisible

        val mediaStateAtStart = if (useAsReceptor) readSelectedMediaStateOrNull() else null

        val root = FrameLayout(this).apply {
            setBackgroundColor(fsBgColor)
            isClickable = true
            setOnClickListener { if (mediaModalView == null) hideMenu() }
        }
        if (fsNotifsVisible && fsCustomNotificationsEnabled) {
            root.setBackgroundColor(cnBgColor)
        }

        val tileHeightSystem = dp(fsTileHeightDp.coerceIn(60, 300))
        val tileHeightApps = dp(fsAppsTileHeightDp.coerceIn(60, 300))
        val closeHeight = dp(fsCloseHeightDp.coerceIn(40, 240))
        val stickyCloseEnabled = fsCloseSticky && (mediaStateAtStart == null || !fsCloseDisableStickyWhenMediaActive)
        val stickyOuterPad = dp(fsStickyPaddingDp.coerceIn(0, 40))
        val scrollPadH = dp(fsContainerPaddingHorzDp.coerceIn(0, 120))
        val scrollPadV = dp(fsContainerPaddingVertDp.coerceIn(0, 120))
        val shell = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(
            shell,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        )

        stopFsBarTick()
        fsBarView = null
        fsBarTimeTv = null
        fsBarRestoreIv = null
        fsBarWifiIv = null
        fsBarBtIv = null
        fsBarDataIv = null
        fsBarLocIv = null
        fsBarBatteryIv = null
        fsBarBatteryTv = null

        if (fsBarEnabled) {
            shell.addView(buildFsBarView())
            startFsBarTick()
        }

        fsNotifsList = null
        fsNotifsEmptyTv = null
        fsNotifsScrollView = null
        fsNotifsRowByKey.clear()
        stopFsNotifsTick()

        val body = FrameLayout(this).apply { isClickable = true }
        shell.addView(body, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))

        if (fsNotifsVisible && fsCustomNotificationsEnabled) {
            fsScrollView = null
            fsFullScreenContent = null
            fsBlockScrollForMediaDrag = false
            fsMediaDismissedByUser = false

            val notifs = buildFsNotificationsSectionView(scrollPadH, scrollPadV)
            body.addView(
                notifs,
                FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
            )
            refreshFsNotifs()
            startFsNotifsTick()
            ensureFsNotifsEventsReceiverRegistered()

            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val lp = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = 0
                y = 0
            }

            menuView = root
            menuLp = lp
            try {
                windowManager.addView(root, lp)
            } catch (_: Exception) {
                menuView = null
                menuLp = null
            }
            return
        }

        val scroll = ScrollView(this).apply {
            isFillViewport = true
            setPadding(scrollPadH, scrollPadV, scrollPadH, scrollPadV)
            isClickable = true
        }
        fsScrollView = scroll
        fsBlockScrollForMediaDrag = false
        scroll.setOnTouchListener { _, _ -> fsBlockScrollForMediaDrag }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            isClickable = true
        }
        fsFullScreenContent = content
        if (mediaStateAtStart == null) {
            fsMediaDismissedByUser = false
        }
        scroll.addView(
            content,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        )
        body.addView(
            scroll,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        )

        if (useAsReceptor && fsMediaAutoShow && mediaStateAtStart != null && !fsMediaDismissedByUser) {
            val mediaView = try {
                android.view.LayoutInflater.from(this).inflate(R.layout.widget_media_style3, content, false)
            } catch (_: Exception) {
                null
            }
            if (mediaView != null) {
                val heightPx = dp(mediaHeightDp.coerceIn(160, 900))
                mediaView.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, heightPx).apply {
                    bottomMargin = dp(16)
                }

                val bgIv = mediaView.findViewById<ImageView>(R.id.widget_bg)
                val titleTv = mediaView.findViewById<TextView>(R.id.widget_title)
                val subtitleTv = mediaView.findViewById<TextView>(R.id.widget_subtitle)
                val textArea = mediaView.findViewById<View>(R.id.widget_text_area)
                val progressBar = mediaView.findViewById<android.widget.ProgressBar>(R.id.widget_progress)
                val timeCurrentTv = mediaView.findViewById<TextView>(R.id.widget_time_current)
                val timeAppTv = mediaView.findViewById<TextView>(R.id.widget_time_app)
                val timeTotalTv = mediaView.findViewById<TextView>(R.id.widget_time_total)
                val volumeBtn = mediaView.findViewById<ImageView>(R.id.widget_volume_btn)
                val volumePanel = mediaView.findViewById<View>(R.id.widget_volume_panel)
                val volumeProgress = mediaView.findViewById<android.widget.ProgressBar>(R.id.widget_volume_progress)
                val prevBtn = mediaView.findViewById<ImageView>(R.id.widget_prev)
                val playPauseBtn = mediaView.findViewById<ImageView>(R.id.widget_play_pause)
                val nextBtn = mediaView.findViewById<ImageView>(R.id.widget_next)

                titleTv?.setTextColor(Color.WHITE)
                subtitleTv?.setTextColor(Color.WHITE)
                titleTv?.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, mediaTitleSizeSp.coerceIn(10, 40).toFloat())
                subtitleTv?.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, mediaSubtitleSizeSp.coerceIn(8, 30).toFloat())
                progressBar?.scaleY = 1.4f

                val iconPad = ((dp(88) - dp(mediaIconSizeDp.coerceIn(16, 88))) / 2).coerceAtLeast(0)
                fun bindIcon(iv: ImageView?, iconId: String, iconPngBase64: String?) {
                    if (iv == null) return
                    val bmp = decodePngBase64(iconPngBase64)
                    if (bmp != null) {
                        iv.setImageBitmap(bmp)
                    } else {
                        iv.setImageResource(resolveBallIconRes(iconId))
                    }
                    iv.setColorFilter(Color.WHITE)
                    iv.setPadding(iconPad, iconPad, iconPad, iconPad)
                }
                bindIcon(volumeBtn, mediaVolumeIconId, mediaVolumeIconPngBase64)
                bindIcon(prevBtn, mediaPrevIconId, mediaPrevIconPngBase64)
                bindIcon(nextBtn, mediaNextIconId, mediaNextIconPngBase64)

                fun setPlayPauseIcon(isPlaying: Boolean) {
                    if (playPauseBtn == null) return
                    val iconId = if (isPlaying) mediaPauseIconId else mediaPlayIconId
                    val iconPng = if (isPlaying) mediaPauseIconPngBase64 else mediaPlayIconPngBase64
                    val bmp = decodePngBase64(iconPng)
                    if (bmp != null) {
                        playPauseBtn.setImageBitmap(bmp)
                    } else {
                        playPauseBtn.setImageResource(resolveBallIconRes(iconId))
                    }
                    playPauseBtn.setColorFilter(Color.WHITE)
                    playPauseBtn.setPadding(iconPad, iconPad, iconPad, iconPad)
                }

                fun setVolumeExpanded(expanded: Boolean) {
                    volumePanel?.visibility = if (expanded) View.VISIBLE else View.GONE
                    titleTv?.visibility = if (expanded) View.GONE else View.VISIBLE
                    subtitleTv?.visibility = if (expanded) View.GONE else View.VISIBLE
                }
                setVolumeExpanded(false)

                fun bindVolumeSegment(viewId: Int, pct: Int) {
                    val tv = mediaView.findViewById<View>(viewId) ?: return
                    tv.isClickable = true
                    tv.setOnClickListener { sendVolumeCommand(pct) }
                }
                bindVolumeSegment(R.id.widget_vol_0, 0)
                bindVolumeSegment(R.id.widget_vol_10, 10)
                bindVolumeSegment(R.id.widget_vol_20, 20)
                bindVolumeSegment(R.id.widget_vol_30, 30)
                bindVolumeSegment(R.id.widget_vol_40, 40)
                bindVolumeSegment(R.id.widget_vol_50, 50)
                bindVolumeSegment(R.id.widget_vol_60, 60)
                bindVolumeSegment(R.id.widget_vol_70, 70)
                bindVolumeSegment(R.id.widget_vol_80, 80)
                bindVolumeSegment(R.id.widget_vol_90, 90)
                bindVolumeSegment(R.id.widget_vol_100, 100)

                volumeBtn?.setOnClickListener {
                    val expanded = volumePanel?.visibility == View.VISIBLE
                    setVolumeExpanded(!expanded)
                    sendVolumeRequest()
                }
                prevBtn?.setOnClickListener { sendMediaCommand("previous") }
                nextBtn?.setOnClickListener { sendMediaCommand("next") }
                playPauseBtn?.setOnClickListener { sendMediaCommand("toggle") }

                var swiping = false
                val dismissThresholdPx = dp(110).toFloat()
                fun dismissMedia(animated: Boolean) {
                    val t = mediaModalTick
                    if (t != null) {
                        mainHandler.removeCallbacks(t)
                        mediaModalTick = null
                    }
                    mediaModalView = null
                    fsMediaDismissedByUser = true
                    updateFsBarNow()

                    val parent = mediaView.parent as? android.view.ViewGroup
                    if (!animated) {
                        try { parent?.removeView(mediaView) } catch (_: Exception) {}
                        mediaView.translationX = 0f
                        mediaView.alpha = 1f
                        return
                    }

                    val endX = ((mediaView.width.takeIf { it > 0 } ?: resources.displayMetrics.widthPixels) + dp(24)).toFloat()
                    mediaView.animate().cancel()
                    mediaView.animate()
                        .translationX(endX)
                        .alpha(0f)
                        .setDuration(180L)
                        .withEndAction {
                            try { parent?.removeView(mediaView) } catch (_: Exception) {}
                            mediaView.translationX = 0f
                            mediaView.alpha = 1f
                        }
                        .start()
                }

                val gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
                    override fun onDown(e: MotionEvent): Boolean = true

                    override fun onScroll(e1: MotionEvent?, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean {
                        if (e1 == null) return false
                        val dx = e2.x - e1.x
                        val dy = e2.y - e1.y
                        if (!swiping) {
                            if (abs(dx) < dp(6) || abs(dx) < abs(dy)) return false
                            swiping = true
                        }
                        if (dx <= 0f) return true
                        val endX = (mediaView.width.takeIf { it > 0 } ?: resources.displayMetrics.widthPixels).toFloat()
                        val clampedDx = dx.coerceIn(0f, endX)
                        mediaView.translationX = clampedDx
                        val frac = (clampedDx / (endX * 0.85f)).coerceIn(0f, 1f)
                        mediaView.alpha = (1f - (0.35f * frac)).coerceIn(0.65f, 1f)
                        return true
                    }

                    override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                        if (e1 == null) return false
                        val dx = e2.x - e1.x
                        if (dx > dismissThresholdPx && abs(velocityX) > abs(velocityY) && abs(velocityX) > 500f) {
                            dismissMedia(true)
                            return true
                        }
                        return false
                    }
                })
                val dragHandle = textArea ?: titleTv ?: subtitleTv
                dragHandle?.setOnTouchListener { _, ev ->
                    if (volumePanel?.visibility == View.VISIBLE) return@setOnTouchListener false
                    val handled = gestureDetector.onTouchEvent(ev)
                    when (ev.actionMasked) {
                        MotionEvent.ACTION_DOWN -> {
                            fsBlockScrollForMediaDrag = false
                            fsScrollView?.requestDisallowInterceptTouchEvent(false)
                            handled
                        }
                        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                            fsBlockScrollForMediaDrag = false
                            fsScrollView?.requestDisallowInterceptTouchEvent(false)
                            val tx = mediaView.translationX
                            if (tx > dismissThresholdPx) {
                                dismissMedia(true)
                                swiping = false
                                true
                            } else {
                                if (tx != 0f) {
                                    mediaView.animate().cancel()
                                    mediaView.animate().translationX(0f).alpha(1f).setDuration(160L).start()
                                }
                                swiping = false
                                false
                            }
                        }
                        else -> {
                            if (swiping) {
                                fsBlockScrollForMediaDrag = true
                                fsScrollView?.requestDisallowInterceptTouchEvent(true)
                                true
                            } else {
                                handled
                            }
                        }
                    }
                }

                var lastDurationMs = 0L
                var scrubbing = false
                fun progressToPct(x: Float, widthPx: Int): Int {
                    if (widthPx <= 0) return 0
                    val ratio = (x / widthPx.toFloat()).coerceIn(0f, 1f)
                    return (ratio * 1000f).toInt().coerceIn(0, 1000)
                }
                progressBar?.setOnTouchListener { v, ev ->
                    val dur = lastDurationMs
                    if (dur <= 0L) return@setOnTouchListener false
                    val w = v.width
                    when (ev.actionMasked) {
                        MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                            scrubbing = true
                            val pct = progressToPct(ev.x, w)
                            progressBar.progress = pct
                            timeCurrentTv?.text = formatMs(((pct.toDouble() / 1000.0) * dur.toDouble()).toLong())
                            true
                        }
                        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                            val pct = progressToPct(ev.x, w)
                            progressBar.progress = pct
                            val posMs = ((pct.toDouble() / 1000.0) * dur.toDouble()).toLong().coerceIn(0L, dur)
                            sendMediaCommand("seekTo", posMs)
                            scrubbing = false
                            true
                        }
                        else -> false
                    }
                }

                fun refresh() {
                    val media = readSelectedMediaStateOrNull()
                    if (media == null) {
                        hideMenu()
                        return
                    }
                    val isPlaying = media.optBoolean("isPlaying", false)

                    val title = media.optString("title", "").trim().ifEmpty { "Sin reproducción" }
                    val artist = media.optString("artist", "").trim()
                    val appName = media.optString("appName", "").trim()
                    titleTv?.text = title
                    subtitleTv?.text = (artist.ifEmpty { appName }).ifEmpty { "" }

                    val dur = try { media.optLong("durationMs", 0L) } catch (_: Exception) { 0L }
                    val pos = try { media.optLong("positionMs", 0L) } catch (_: Exception) { 0L }
                    lastDurationMs = dur
                    val pct = if (dur > 0L) ((pos.toDouble() / dur.toDouble()) * 1000.0).toInt().coerceIn(0, 1000) else 0
                    progressBar?.max = 1000
                    if (!scrubbing) progressBar?.progress = pct
                    setPlayPauseIcon(isPlaying)

                    if (!scrubbing) timeCurrentTv?.text = formatMs(pos)
                    timeTotalTv?.text = formatMs(dur)
                    timeAppTv?.text = appName

                    val artB64 = media.optString("artBase64", "").trim()
                    if (artB64.isNotEmpty()) {
                        val bmp = try {
                            val bytes = Base64.decode(artB64, Base64.DEFAULT)
                            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                        } catch (_: Exception) {
                            null
                        }
                        if (bmp != null) bgIv?.setImageBitmap(bmp)
                    } else {
                        val now = System.currentTimeMillis()
                        val useLocal = shouldUseLocalMediaForControls(now)
                        val connected = try { BtClassicServerService.connectedPeers > 0 } catch (_: Exception) { false }
                        if (!useLocal && connected && now - lastMediaStateRequestAtMs > 1500L) {
                            lastMediaStateRequestAtMs = now
                            sendMediaCommand("request_state")
                        }
                    }

                    val vol = readSelectedVolumePctFreshOrNull()
                    if (vol != null) {
                        volumeProgress?.max = 100
                        volumeProgress?.progress = vol
                    }
                }

                mediaModalView = mediaView
                refresh()
                sendVolumeRequest()
                val tick = object : Runnable {
                    override fun run() {
                        if (menuView == null || mediaModalView == null) return
                        refresh()
                        mainHandler.postDelayed(this, 1000L)
                    }
                }
                mediaModalTick = tick
                mainHandler.postDelayed(tick, 1000L)

                content.addView(mediaView)
            }
        }

        val byId = HashMap<String, FsItem>()
        byId["back"] = FsItem(
            id = "back",
            title = fsBackText,
            iconId = fsBackIconId,
            iconPngBase64 = fsBackIconPngBase64
        ) {
            hideMenu()
            performGlobal(AccessibilityService.GLOBAL_ACTION_BACK)
        }
        byId["home"] = FsItem(
            id = "home",
            title = fsHomeText,
            iconId = fsHomeIconId,
            iconPngBase64 = fsHomeIconPngBase64
        ) {
            hideMenu()
            performGlobal(AccessibilityService.GLOBAL_ACTION_HOME)
        }
        byId["volume"] = FsItem(
            id = "volume",
            title = fsVolumeText,
            iconId = fsVolumeIconId,
            iconPngBase64 = fsVolumeIconPngBase64
        ) {
            showVolumeModal(root)
        }
        byId["brightness"] = FsItem(
            id = "brightness",
            title = fsBrightnessText,
            iconId = fsBrightnessIconId,
            iconPngBase64 = fsBrightnessIconPngBase64
        ) {
            showBrightnessModal(root)
        }
        byId["recents"] = FsItem(
            id = "recents",
            title = fsRecentsText,
            iconId = fsRecentsIconId,
            iconPngBase64 = fsRecentsIconPngBase64
        ) {
            hideMenu()
            performGlobal(AccessibilityService.GLOBAL_ACTION_RECENTS)
        }
        byId["settings"] = FsItem(
            id = "settings",
            title = fsSettingsText,
            iconId = fsSettingsIconId,
            iconPngBase64 = fsSettingsIconPngBase64
        ) {
            hideMenu()
            try {
                val i = Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(i)
            } catch (_: Exception) {
            }
        }

        for (pkg in selectedApps) {
            val label = (fsAppLabels[pkg] ?: resolveAppLabel(pkg)).trim()
            if (label.isBlank()) continue
            val appIcon = try {
                packageManager.getApplicationIcon(pkg)
            } catch (_: Exception) {
                null
            }
            val id = "pkg:$pkg"
            byId[id] = FsItem(id = id, title = label, appIcon = appIcon) {
                hideMenu()
                launchPackage(pkg)
            }
        }

        val defaultOrder = listOf("back", "home", "volume", "brightness", "recents", "settings")
        val order = if (fsOrder.isNotEmpty()) fsOrder else defaultOrder

        val used = HashSet<String>()
        val systemItems = ArrayList<FsItem>()
        val appItems = ArrayList<FsItem>()
        fun addOrdered(id: String) {
            if (!used.add(id)) return
            val it = byId[id] ?: return
            if (id.startsWith("pkg:")) appItems.add(it) else systemItems.add(it)
        }

        for (id in order) addOrdered(id)
        for (id in defaultOrder) addOrdered(id)
        for (pkg in selectedApps) addOrdered("pkg:$pkg")

        val gapSystem = dp(fsTileGapDp.coerceIn(0, 40))
        val gapApps = dp(fsAppsTileGapDp.coerceIn(0, 40))

        fun addGrid(
            items: List<FsItem>,
            cols: Int,
            tileHeightPx: Int,
            gapPx: Int,
            buttonColor: Int,
            borderColor: Int,
            iconSizeDp: Int
        ) {
            val safeCols = cols.coerceIn(1, 4)
            var idx = 0
            while (idx < items.size) {
                val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
                for (c in 0 until safeCols) {
                    val lp = LinearLayout.LayoutParams(0, tileHeightPx, 1f).apply {
                        bottomMargin = gapPx
                        if (c < safeCols - 1) marginEnd = gapPx
                    }
                    if (idx < items.size) {
                        row.addView(buildFsTile(items[idx], tileHeightPx, buttonColor, borderColor, iconSizeDp), lp)
                        idx++
                    } else {
                        row.addView(View(this), lp)
                    }
                }
                content.addView(row)
            }
        }

        addGrid(systemItems, fsSystemCols, tileHeightSystem, gapSystem, fsButtonColor, fsTileBorderColor, fsIconSizeDp)
        addGrid(appItems, fsAppsCols, tileHeightApps, gapApps, fsAppsButtonColor, fsAppsTileBorderColor, fsAppsIconSizeDp)

        val closeButton = buildFsCloseButton().apply {
            setOnClickListener { hideMenu() }
            isClickable = true
        }
        if (stickyCloseEnabled) {
            shell.addView(
                closeButton,
                LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, closeHeight).apply {
                    leftMargin = stickyOuterPad
                    rightMargin = stickyOuterPad
                    bottomMargin = stickyOuterPad
                }
            )
        } else {
            content.addView(
                closeButton,
                LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, closeHeight).apply {
                    topMargin = dp(6)
                    bottomMargin = dp(10)
                }
            )
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }

        menuView = root
        menuLp = lp
        try {
            windowManager.addView(root, lp)
        } catch (_: Exception) {
            menuView = null
            menuLp = null
        }
    }

    private fun buildFsTile(
        item: FsItem,
        tileHeightPx: Int,
        buttonColor: Int,
        borderColor: Int,
        iconSizeDp: Int
    ): View {
        val tile = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            isClickable = true
            val bg = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(buttonColor)
                setStroke(dp(1), borderColor)
            }
            background = bg
            val pad = dp(fsTilePaddingDp.coerceIn(0, 40))
            if (pad > 0) setPadding(pad, pad, pad, pad)
            setOnClickListener { item.onClick() }
        }

        val icon = ImageView(this).apply {
            val sizePx = dp(iconSizeDp.coerceIn(10, 120))
            val maxPx = tileHeightPx - dp(10)
            val iconPx = sizePx.coerceAtMost(maxPx.coerceAtLeast(dp(10)))
            layoutParams = LinearLayout.LayoutParams(iconPx, iconPx).apply {
                bottomMargin = if (fsHideText) 0 else dp(fsTileInnerGapDp.coerceIn(0, 40))
            }
        }
        if (item.appIcon != null) {
            icon.setImageDrawable(item.appIcon)
        } else {
            val bmp = decodePngBase64(item.iconPngBase64)
            if (bmp != null) {
                icon.setImageBitmap(bmp)
            } else {
                val res = resolveBallIconRes(item.iconId ?: "info")
                icon.setImageResource(res)
            }
            icon.setColorFilter(fsIconColor)
        }
        tile.addView(icon)

        if (!fsHideText) {
            val tv = TextView(this).apply {
                text = item.title
                setTextColor(fsTextColor)
                textSize = fsTextSizeSp.coerceIn(8, 40).toFloat()
                maxLines = 2
                gravity = Gravity.CENTER
                setPadding(dp(10), 0, dp(10), 0)
            }
            tile.addView(tv)
        }
        return tile
    }

    private fun buildFsCloseButton(): View {
        return FrameLayout(this).apply {
            val bg = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(fsCloseBgColor)
                setStroke(dp(1), Color.parseColor("#22FFFFFF"))
            }
            background = bg
            isClickable = true
            if (fsCloseHideText) {
                val iv = ImageView(this@FloatingBallService).apply {
                    val bmp = decodePngBase64(fsCloseIconPngBase64)
                    if (bmp != null) {
                        setImageBitmap(bmp)
                    } else {
                        setImageResource(resolveBallIconRes(fsCloseIconId))
                    }
                    setColorFilter(fsCloseTextColor)
                }
                addView(
                    iv,
                    FrameLayout.LayoutParams(dp(34), dp(34)).apply {
                        gravity = Gravity.CENTER
                    }
                )
            } else {
                val tv = TextView(this@FloatingBallService).apply {
                    text = fsCloseText
                    setTextColor(fsCloseTextColor)
                    textSize = 16f
                    gravity = Gravity.CENTER
                }
                addView(
                    tv,
                    FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                )
            }
        }
    }

    private fun readBatteryPctOrNull(): Int? {
        return try {
            val i = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return null
            val level = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = i.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            if (level < 0 || scale <= 0) return null
            ((level.toDouble() / scale.toDouble()) * 100.0).toInt().coerceIn(0, 100)
        } catch (_: Exception) {
            null
        }
    }

    private fun isWifiEnabledSafe(): Boolean {
        return try {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            wifi?.isWifiEnabled == true
        } catch (_: Exception) {
            false
        }
    }

    private fun isBluetoothEnabledSafe(): Boolean {
        return try {
            BluetoothAdapter.getDefaultAdapter()?.isEnabled == true
        } catch (_: Exception) {
            false
        }
    }

    private fun isMobileDataEnabledSafe(): Boolean {
        return try {
            val v = try { Settings.Global.getInt(contentResolver, "mobile_data", 0) } catch (_: Exception) { -1 }
            if (v == 1) return true
            if (v == 0) return false

            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
            val net = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(net) ?: return false
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) && caps.hasCapability(
                NetworkCapabilities.NET_CAPABILITY_INTERNET
            )
        } catch (_: Exception) {
            false
        }
    }

    private fun isLocationEnabledSafe(): Boolean {
        return try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) || lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } catch (_: Exception) {
            false
        }
    }

    private fun updateFsBarNow() {
        val timeTv = fsBarTimeTv
        val wifiIv = fsBarWifiIv
        val btIv = fsBarBtIv
        val dataIv = fsBarDataIv
        val locIv = fsBarLocIv
        val batteryIv = fsBarBatteryIv
        val batteryTv = fsBarBatteryTv
        val restoreIv = fsBarRestoreIv
        if (timeTv == null || wifiIv == null || btIv == null || dataIv == null || locIv == null || batteryIv == null || batteryTv == null || restoreIv == null) {
            return
        }

        val now = Date()
        timeTv.text = DateFormat.format("HH:mm", now).toString()

        wifiIv.visibility = if (isWifiEnabledSafe()) View.VISIBLE else View.GONE
        btIv.visibility = if (isBluetoothEnabledSafe()) View.VISIBLE else View.GONE
        dataIv.visibility = if (isMobileDataEnabledSafe()) View.VISIBLE else View.GONE
        locIv.visibility = if (isLocationEnabledSafe()) View.VISIBLE else View.GONE

        val pct = readBatteryPctOrNull()
        batteryTv.text = if (pct != null) "${pct}%" else "—"

        val mediaState = if (useAsReceptor) readSelectedMediaStateOrNull() else null
        if (mediaState == null) fsMediaDismissedByUser = false
        val canOpenMedia = useAsReceptor && mediaState != null && mediaModalView == null
        restoreIv.visibility = if (canOpenMedia) View.VISIBLE else View.GONE
    }

    private fun startFsBarTick() {
        val prev = fsBarTick
        if (prev != null) mainHandler.removeCallbacks(prev)
        val tick = object : Runnable {
            override fun run() {
                if (menuView == null || fsBarView == null) return
                updateFsBarNow()
                mainHandler.postDelayed(this, 1000L)
            }
        }
        fsBarTick = tick
        mainHandler.post(tick)
    }

    private fun stopFsBarTick() {
        val t = fsBarTick ?: return
        mainHandler.removeCallbacks(t)
        fsBarTick = null
    }

    private fun buildFsBarView(): View {
        val heightPx = dp(fsBarHeightDp.coerceIn(36, 160))
        val padH = dp(fsBarPaddingHorzDp.coerceIn(0, 200))
        val padV = dp(fsBarPaddingVertDp.coerceIn(0, 30))
        val iconPx = dp(fsBarIconSizeDp.coerceIn(10, 64))

        fun buildIconView(
            iconId: String,
            iconPngBase64: String?,
            tintColor: Int,
            marginStartDp: Int
        ): ImageView {
            return ImageView(this).apply {
                val bmp = decodePngBase64(iconPngBase64)
                if (bmp != null) {
                    setImageBitmap(bmp)
                } else {
                    setImageResource(resolveBallIconRes(iconId))
                }
                setColorFilter(tintColor)
                layoutParams = LinearLayout.LayoutParams(iconPx, iconPx).apply {
                    marginStart = dp(marginStartDp)
                }
            }
        }

        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(fsBarBgColor)
            setPadding(padH, padV, padH, padV)
            isClickable = true
            minimumHeight = heightPx
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val timeTv = TextView(this).apply {
            setTextColor(fsBarTimeColor)
            textSize = fsBarTextSizeSp.coerceIn(8, 32).toFloat()
            includeFontPadding = false
            text = "00:00"
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }

        val left = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }

        val right = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }

        val restorePad = dp(6)
        val restoreSize = iconPx + (restorePad * 2)
        val restoreBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(10).toFloat()
            setColor(fsBarRestoreBgColor)
        }
        val restoreIv = ImageView(this).apply {
            val bmp = decodePngBase64(fsBarMediaRestoreIconPngBase64)
            if (bmp != null) {
                setImageBitmap(bmp)
            } else {
                setImageResource(resolveBallIconRes(fsBarMediaRestoreIconId))
            }
            setColorFilter(fsBarRestoreIconColor)
            background = restoreBg
            setPadding(restorePad, restorePad, restorePad, restorePad)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            visibility = View.GONE
            isClickable = true
            setOnClickListener { ensureFsMediaVisible() }
            layoutParams = LinearLayout.LayoutParams(restoreSize, restoreSize).apply {
                marginStart = dp(10)
            }
        }
        val wifiIv = buildIconView(fsBarWifiIconId, fsBarWifiIconPngBase64, fsBarWifiIconColor, 10)
        val btIv = buildIconView(fsBarBtIconId, fsBarBtIconPngBase64, fsBarBtIconColor, 10)
        val dataIv = buildIconView(fsBarDataIconId, fsBarDataIconPngBase64, fsBarDataIconColor, 10)
        val locIv = buildIconView(fsBarLocIconId, fsBarLocIconPngBase64, fsBarLocIconColor, 10)
        val batteryIv = buildIconView(fsBarBatteryIconId, fsBarBatteryIconPngBase64, fsBarBatteryIconColor, 10)
        val batteryTv = TextView(this).apply {
            setTextColor(fsBarBatteryTextColor)
            textSize = fsBarTextSizeSp.coerceIn(8, 32).toFloat()
            includeFontPadding = false
            text = "—"
            setPadding(dp(2), 0, 0, 0)
            isClickable = true
        }
        batteryIv.isClickable = true
        val openCustomNotifsClick = View.OnClickListener {
            if (fsCustomNotificationsEnabled) {
                fsNotifsVisible = !fsNotifsVisible
                showFullScreenMenu()
            }
        }
        batteryIv.setOnClickListener(openCustomNotifsClick)
        batteryTv.setOnClickListener(openCustomNotifsClick)

        left.addView(timeTv)
        left.addView(restoreIv)
        right.addView(wifiIv)
        right.addView(btIv)
        right.addView(dataIv)
        right.addView(locIv)
        right.addView(batteryIv)
        right.addView(batteryTv)

        val spacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
        }

        bar.addView(left)
        bar.addView(spacer)
        bar.addView(right)

        fsBarView = bar
        fsBarTimeTv = timeTv
        fsBarRestoreIv = restoreIv
        fsBarWifiIv = wifiIv
        fsBarBtIv = btIv
        fsBarDataIv = dataIv
        fsBarLocIv = locIv
        fsBarBatteryIv = batteryIv
        fsBarBatteryTv = batteryTv

        return bar
    }

    private fun startFsNotifsTick() {
        val prev = fsNotifsTick
        if (prev != null) mainHandler.removeCallbacks(prev)
        val tick = object : Runnable {
            override fun run() {
                if (menuView == null) return
                if (!fsNotifsVisible) return
                if (fsNotifsList == null) return
                if (fsNotifsRowDragging) return
                refreshFsNotifs()
                mainHandler.postDelayed(this, 2500L)
            }
        }
        fsNotifsTick = tick
        mainHandler.post(tick)
    }

    private fun stopFsNotifsTick() {
        val t = fsNotifsTick ?: return
        mainHandler.removeCallbacks(t)
        fsNotifsTick = null
    }

    private fun ensureFsNotifsEventsReceiverRegistered() {
        if (fsNotifsEventsReceiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != ACTION_ACTIVE_NOTIFICATIONS_CHANGED) return
                if (menuView == null) return
                if (!fsNotifsVisible) return
                if (fsNotifsList == null) return
                if (fsNotifsRowDragging) return
                mainHandler.post { refreshFsNotifs() }
            }
        }
        fsNotifsEventsReceiver = r
        try {
            val f = IntentFilter(ACTION_ACTIVE_NOTIFICATIONS_CHANGED)
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(r, f, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(r, f)
            }
        } catch (_: Exception) {
            fsNotifsEventsReceiver = null
        }
    }

    private fun unregisterFsNotifsEventsReceiver() {
        val r = fsNotifsEventsReceiver ?: return
        try {
            unregisterReceiver(r)
        } catch (_: Exception) {
        }
        fsNotifsEventsReceiver = null
    }

    private fun isNotificationListenerEnabled(): Boolean {
        return try {
            val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            val cn = ComponentName(packageName, NotificationListener::class.java.name)
            val id = cn.flattenToString()
            flat != null && flat.contains(id)
        } catch (_: Exception) {
            false
        }
    }

    private data class FsNotifRowRefs(
        val appTv: TextView,
        val textsBox: LinearLayout
    )

    private fun buildFsNotificationsSectionView(padH: Int, padV: Int): View {
        val section = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            isClickable = true
        }

        val contentBox = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padH, padV, padH, padV)
            isClickable = true
        }

        val emptyTv = TextView(this).apply {
            setTextColor(cnTextColor)
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, cnTextSizeSp.toFloat())
            includeFontPadding = false
            text = ""
            visibility = View.GONE
        }
        contentBox.addView(
            emptyTv,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = dp(10)
            }
        )

        val scroll = ScrollView(this).apply {
            isFillViewport = true
            isClickable = true
        }
        val list = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            isClickable = true
        }
        scroll.addView(
            list,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        )
        val swipeRefresh = SwipeRefreshLayout(this).apply {
            isClickable = true
            setProgressBackgroundColorSchemeColor(cnBgColor)
            setColorSchemeColors(cnButtonsContentColor)
            setOnRefreshListener {
                refreshFsNotifs()
                mainHandler.postDelayed({ isRefreshing = false }, 240L)
            }
        }
        swipeRefresh.addView(
            scroll,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        )
        contentBox.addView(swipeRefresh, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        section.addView(contentBox, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))

        val btnHeightPx = dp(cnButtonsHeightDp.coerceIn(36, 160))
        val btnIconSizePx = dp(cnButtonsIconHeightDp.coerceIn(10, 120))
        val btnCornerPx = dp(14).toFloat()
        val btnGapPx = dp(convBottomButtonsGapDp.coerceIn(0, 60))

        fun buildBottomButton(
            iconId: String,
            iconPngBase64: String?,
            label: String,
            onClick: () -> Unit
        ): View {
            val b = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                isClickable = true
                val d = GradientDrawable().apply {
                    cornerRadius = btnCornerPx
                    setColor(cnButtonsBgColor)
                    setStroke(dp(1), cnButtonsBorderColor)
                }
                background = d
            }

            val iv = ImageView(this).apply {
                val bmp = decodePngBase64(iconPngBase64)
                if (bmp != null) {
                    setImageBitmap(bmp)
                } else {
                    setImageResource(resolveBallIconRes(iconId))
                }
                setColorFilter(cnButtonsContentColor)
            }
            b.addView(iv, LinearLayout.LayoutParams(btnIconSizePx, btnIconSizePx))

            if (!cnButtonsHideText) {
                val tv = TextView(this).apply {
                    text = label
                    setTextColor(cnButtonsContentColor)
                    setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, cnTextSizeSp.coerceIn(8, 32).toFloat())
                    includeFontPadding = false
                    setPadding(dp(10), 0, 0, 0)
                }
                b.addView(tv)
            }

            b.setOnClickListener { onClick() }
            return b
        }

        val buttonsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            isClickable = true
        }
        val closeBtn = buildBottomButton(
            iconId = cnCloseIconId,
            iconPngBase64 = cnCloseIconPngBase64,
            label = cnCloseText
        ) {
            fsNotifsVisible = false
            hideMenu()
        }
        val clearAllBtn = buildBottomButton(
            iconId = cnClearAllIconId,
            iconPngBase64 = cnClearAllIconPngBase64,
            label = cnClearAllText
        ) {
            val enabled = isNotificationListenerEnabled()
            val running = NotificationListener.isRunning
            if (enabled && !running) {
                try { NotificationListener.forceRebind(applicationContext) } catch (_: Exception) {}
            }
            try { NotificationListener.cancelAllSystemNotifications() } catch (_: Exception) {}
            try { sendBroadcast(Intent(ACTION_ACTIVE_NOTIFICATIONS_CHANGED)) } catch (_: Exception) {}
            mainHandler.postDelayed({ refreshFsNotifs() }, 220L)
        }
        buttonsRow.addView(
            closeBtn,
            LinearLayout.LayoutParams(0, btnHeightPx, 1f)
        )
        buttonsRow.addView(View(this), LinearLayout.LayoutParams(btnGapPx, 1))
        buttonsRow.addView(
            clearAllBtn,
            LinearLayout.LayoutParams(0, btnHeightPx, 1f)
        )
        val buttonsBox = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(
                dp(convBottomButtonsPaddingHorzDp.coerceIn(0, 60)),
                dp(convBottomButtonsPaddingVertDp.coerceIn(0, 60)),
                dp(convBottomButtonsPaddingHorzDp.coerceIn(0, 60)),
                dp(convBottomButtonsPaddingVertDp.coerceIn(0, 60))
            )
            isClickable = true
        }
        buttonsBox.addView(
            buttonsRow,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        )
        section.addView(
            buttonsBox,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        )

        fsNotifsList = list
        fsNotifsEmptyTv = emptyTv
        fsNotifsScrollView = scroll
        fsNotifsRowByKey.clear()
        return section
    }

    private fun refreshFsNotifs() {
        val list = fsNotifsList ?: return
        val emptyTv = fsNotifsEmptyTv

        val enabled = isNotificationListenerEnabled()
        val running = try { NotificationListener.isRunning } catch (_: Exception) { false }
        if (enabled && !running) {
            try { NotificationListener.forceRebind(applicationContext) } catch (_: Exception) {}
        }

        val items = try { NotificationListener.getActiveNotificationsSnapshot() } catch (_: Exception) { emptyList() }
        if (!enabled) {
            emptyTv?.text = "Activa el permiso de acceso a notificaciones para ver notificaciones del dispositivo."
            emptyTv?.visibility = View.VISIBLE
            fsNotifsRowByKey.clear()
            list.removeAllViews()
            return
        }
        if (items.isEmpty()) {
            emptyTv?.text = ""
            emptyTv?.visibility = View.GONE
            fsNotifsRowByKey.clear()
            list.removeAllViews()
            return
        }
        emptyTv?.visibility = View.GONE

        val iconSizePx = dp(44)
        val iconRadius = dp(10).toFloat()
        val rowPadH = dp(fsContainerPaddingHorzDp.coerceIn(0, 120))
        val rowPadV = dp(12)
        val gap = dp(12)
        val deletePx = dp(28)
        val swipeThreshold = dp(90)

        fun buildDeleteIcon(): ImageView {
            return ImageView(this).apply {
                val bmp = decodePngBase64(cnDeleteIconPngBase64)
                if (bmp != null) {
                    setImageBitmap(bmp)
                } else {
                    setImageResource(resolveBallIconRes(cnDeleteIconId))
                }
                setColorFilter(cnTextColor)
                layoutParams = LinearLayout.LayoutParams(deletePx, deletePx).apply {
                    gravity = Gravity.TOP
                }
            }
        }

        fun setLines(refs: FsNotifRowRefs, entry: NotificationListener.ActiveNotificationEntry) {
            refs.appTv.text = entry.appName.trim().ifEmpty { "Notificación" }
            while (refs.textsBox.childCount > 1) {
                refs.textsBox.removeViewAt(1)
            }
            fun addLine(s: String) {
                val t = s.trim()
                if (t.isEmpty()) return
                val tv = TextView(this).apply {
                    this.text = t
                    setTextColor(cnTextColor)
                    setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, cnTextSizeSp.toFloat())
                    includeFontPadding = false
                }
                refs.textsBox.addView(tv)
            }
            addLine(entry.title)
            addLine(entry.text)
            addLine(entry.subText ?: "")
        }

        fun buildRow(entry: NotificationListener.ActiveNotificationEntry): View {
            val key = entry.key.trim()
            val swipeHost = FrameLayout(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = dp(10) }
                isClickable = true
            }

            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                val d = GradientDrawable().apply {
                    cornerRadius = dp(14).toFloat()
                    setColor(cnItemBgColor)
                    setStroke(dp(1), cnItemBorderColor)
                }
                background = d
                setPadding(rowPadH, rowPadV, rowPadH, rowPadV)
                isClickable = true
            }

            val iconB64 = entry.appIcon
            val bmp = decodePngBase64(iconB64)
            if (bmp != null) {
                val holder = FrameLayout(this).apply {
                    val d = GradientDrawable().apply {
                        cornerRadius = iconRadius
                        setColor(Color.TRANSPARENT)
                    }
                    background = d
                    outlineProvider = ViewOutlineProvider.BACKGROUND
                    clipToOutline = true
                    layoutParams = LinearLayout.LayoutParams(iconSizePx, iconSizePx).apply {
                        marginEnd = gap
                    }
                }
                val iv = ImageView(this).apply {
                    setImageBitmap(bmp)
                    scaleType = ImageView.ScaleType.CENTER_CROP
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                }
                holder.addView(iv)
                row.addView(holder)
            }

            val texts = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            val appTv = TextView(this).apply {
                setTextColor(cnTitleColor)
                setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, cnTitleSizeSp.toFloat())
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                includeFontPadding = false
                maxLines = 1
            }
            texts.addView(appTv)
            row.addView(texts)

            val del = buildDeleteIcon().apply {
                isClickable = true
                setOnClickListener {
                    if (key.isNotEmpty()) {
                        try { NotificationListener.cancelNotificationByKey(key) } catch (_: Exception) {}
                        mainHandler.postDelayed({ refreshFsNotifs() }, 120L)
                    }
                }
            }
            row.addView(del, LinearLayout.LayoutParams(deletePx, deletePx).apply { marginStart = dp(10) })

            swipeHost.addView(row, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT))

            val refs = FsNotifRowRefs(appTv = appTv, textsBox = texts)
            swipeHost.tag = refs
            setLines(refs, entry)

            var downX = 0f
            var downY = 0f
            var dragging = false
            val touchSlop = ViewConfiguration.get(this).scaledTouchSlop.toFloat()
            row.setOnTouchListener { v, ev ->
                val scrollView = fsNotifsScrollView
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        downX = ev.rawX
                        downY = ev.rawY
                        dragging = false
                        fsNotifsRowDragging = false
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = ev.rawX - downX
                        val dy = ev.rawY - downY
                        if (!dragging) {
                            val absDx = kotlin.math.abs(dx)
                            val absDy = kotlin.math.abs(dy)
                            if (absDy > touchSlop && absDy > absDx) {
                                fsNotifsRowDragging = false
                                scrollView?.requestDisallowInterceptTouchEvent(false)
                                return@setOnTouchListener false
                            }
                            if (absDx > touchSlop && absDx > absDy) {
                                dragging = true
                                fsNotifsRowDragging = true
                                scrollView?.requestDisallowInterceptTouchEvent(true)
                            } else {
                                return@setOnTouchListener true
                            }
                        }
                        val w = v.width.coerceAtLeast(1).toFloat()
                        val clamped = dx.coerceIn(-w, 0f)
                        v.translationX = clamped
                        true
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        if (!dragging) return@setOnTouchListener false
                        fsNotifsRowDragging = false
                        scrollView?.requestDisallowInterceptTouchEvent(false)
                        val tx = v.translationX
                        if (-tx > swipeThreshold) {
                            val w = v.width.coerceAtLeast(1).toFloat()
                            v.animate().translationX(-w).setDuration(140L).withEndAction {
                                if (key.isNotEmpty()) {
                                    try { NotificationListener.cancelNotificationByKey(key) } catch (_: Exception) {}
                                }
                                try { list.removeView(swipeHost) } catch (_: Exception) {}
                                fsNotifsRowByKey.remove(key)
                                mainHandler.postDelayed({ refreshFsNotifs() }, 120L)
                            }.start()
                        } else {
                            v.animate().translationX(0f).setDuration(140L).start()
                        }
                        true
                    }
                    else -> false
                }
            }

            return swipeHost
        }

        val nextKeys = ArrayList<String>(items.size)
        for (e in items) {
            val k = e.key.trim()
            if (k.isNotEmpty()) nextKeys.add(k)
        }
        val nextKeySet = HashSet(nextKeys)
        val toRemove = ArrayList<String>()
        for (k in fsNotifsRowByKey.keys) {
            if (!nextKeySet.contains(k)) toRemove.add(k)
        }
        for (k in toRemove) {
            val v = fsNotifsRowByKey.remove(k)
            if (v != null) {
                try { list.removeView(v) } catch (_: Exception) {}
            }
        }

        var insertAt = 0
        for (entry in items) {
            val key = entry.key.trim()
            if (key.isEmpty()) continue
            val existing = fsNotifsRowByKey[key]
            val host = if (existing == null) {
                val created = buildRow(entry)
                fsNotifsRowByKey[key] = created
                created
            } else {
                val refs = existing.tag as? FsNotifRowRefs
                if (refs != null) setLines(refs, entry)
                existing
            }
            val currentIndex = list.indexOfChild(host)
            if (currentIndex < 0) {
                list.addView(host, insertAt.coerceIn(0, list.childCount))
            } else if (currentIndex != insertAt) {
                list.removeViewAt(currentIndex)
                list.addView(host, insertAt.coerceIn(0, list.childCount))
            }
            insertAt++
        }
    }

    private fun ensureFsMediaVisible() {
        if (!useAsReceptor) return
        if (mediaModalView != null) return
        val content = fsFullScreenContent ?: return
        val state = readSelectedMediaStateOrNull() ?: return
        createFsMediaView(content, state, 0)
        fsMediaDismissedByUser = false
        updateFsBarNow()
    }

    private fun createFsMediaView(parent: LinearLayout, initialState: JSONObject, index: Int) {
        val mediaView = try {
            android.view.LayoutInflater.from(this).inflate(R.layout.widget_media_style3, parent, false)
        } catch (_: Exception) {
            null
        } ?: return

        val heightPx = dp(mediaHeightDp.coerceIn(160, 900))
        mediaView.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, heightPx).apply {
            bottomMargin = dp(16)
        }

        val bgIv = mediaView.findViewById<ImageView>(R.id.widget_bg)
        val titleTv = mediaView.findViewById<TextView>(R.id.widget_title)
        val subtitleTv = mediaView.findViewById<TextView>(R.id.widget_subtitle)
        val textArea = mediaView.findViewById<View>(R.id.widget_text_area)
        val progressBar = mediaView.findViewById<android.widget.ProgressBar>(R.id.widget_progress)
        val timeCurrentTv = mediaView.findViewById<TextView>(R.id.widget_time_current)
        val timeAppTv = mediaView.findViewById<TextView>(R.id.widget_time_app)
        val timeTotalTv = mediaView.findViewById<TextView>(R.id.widget_time_total)
        val volumeBtn = mediaView.findViewById<ImageView>(R.id.widget_volume_btn)
        val volumePanel = mediaView.findViewById<View>(R.id.widget_volume_panel)
        val volumeProgress = mediaView.findViewById<android.widget.ProgressBar>(R.id.widget_volume_progress)
        val prevBtn = mediaView.findViewById<ImageView>(R.id.widget_prev)
        val playPauseBtn = mediaView.findViewById<ImageView>(R.id.widget_play_pause)
        val nextBtn = mediaView.findViewById<ImageView>(R.id.widget_next)

        titleTv?.setTextColor(Color.WHITE)
        subtitleTv?.setTextColor(Color.WHITE)
        titleTv?.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, mediaTitleSizeSp.coerceIn(10, 40).toFloat())
        subtitleTv?.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, mediaSubtitleSizeSp.coerceIn(8, 30).toFloat())
        progressBar?.scaleY = 1.4f

        val iconPad = ((dp(88) - dp(mediaIconSizeDp.coerceIn(16, 88))) / 2).coerceAtLeast(0)
        fun bindIcon(iv: ImageView?, iconId: String, iconPngBase64: String?) {
            if (iv == null) return
            val bmp = decodePngBase64(iconPngBase64)
            if (bmp != null) {
                iv.setImageBitmap(bmp)
            } else {
                iv.setImageResource(resolveBallIconRes(iconId))
            }
            iv.setColorFilter(Color.WHITE)
            iv.setPadding(iconPad, iconPad, iconPad, iconPad)
        }
        bindIcon(volumeBtn, mediaVolumeIconId, mediaVolumeIconPngBase64)
        bindIcon(prevBtn, mediaPrevIconId, mediaPrevIconPngBase64)
        bindIcon(nextBtn, mediaNextIconId, mediaNextIconPngBase64)

        fun setPlayPauseIcon(isPlaying: Boolean) {
            if (playPauseBtn == null) return
            val iconId = if (isPlaying) mediaPauseIconId else mediaPlayIconId
            val iconPng = if (isPlaying) mediaPauseIconPngBase64 else mediaPlayIconPngBase64
            val bmp = decodePngBase64(iconPng)
            if (bmp != null) {
                playPauseBtn.setImageBitmap(bmp)
            } else {
                playPauseBtn.setImageResource(resolveBallIconRes(iconId))
            }
            playPauseBtn.setColorFilter(Color.WHITE)
            playPauseBtn.setPadding(iconPad, iconPad, iconPad, iconPad)
        }

        fun setVolumeExpanded(expanded: Boolean) {
            volumePanel?.visibility = if (expanded) View.VISIBLE else View.GONE
            titleTv?.visibility = if (expanded) View.GONE else View.VISIBLE
            subtitleTv?.visibility = if (expanded) View.GONE else View.VISIBLE
        }
        setVolumeExpanded(false)

        fun bindVolumeSegment(viewId: Int, pct: Int) {
            val tv = mediaView.findViewById<View>(viewId) ?: return
            tv.isClickable = true
            tv.setOnClickListener { sendVolumeCommand(pct) }
        }
        bindVolumeSegment(R.id.widget_vol_0, 0)
        bindVolumeSegment(R.id.widget_vol_10, 10)
        bindVolumeSegment(R.id.widget_vol_20, 20)
        bindVolumeSegment(R.id.widget_vol_30, 30)
        bindVolumeSegment(R.id.widget_vol_40, 40)
        bindVolumeSegment(R.id.widget_vol_50, 50)
        bindVolumeSegment(R.id.widget_vol_60, 60)
        bindVolumeSegment(R.id.widget_vol_70, 70)
        bindVolumeSegment(R.id.widget_vol_80, 80)
        bindVolumeSegment(R.id.widget_vol_90, 90)
        bindVolumeSegment(R.id.widget_vol_100, 100)

        volumeBtn?.setOnClickListener {
            val expanded = volumePanel?.visibility == View.VISIBLE
            setVolumeExpanded(!expanded)
            sendVolumeRequest()
        }
        prevBtn?.setOnClickListener { sendMediaCommand("previous") }
        nextBtn?.setOnClickListener { sendMediaCommand("next") }
        playPauseBtn?.setOnClickListener { sendMediaCommand("toggle") }

        var swiping = false
        val dismissThresholdPx = dp(110).toFloat()
        fun dismissMedia(animated: Boolean) {
            val t = mediaModalTick
            if (t != null) {
                mainHandler.removeCallbacks(t)
                mediaModalTick = null
            }
            mediaModalView = null
            fsMediaDismissedByUser = true
            updateFsBarNow()

            val p = mediaView.parent as? android.view.ViewGroup
            if (!animated) {
                try { p?.removeView(mediaView) } catch (_: Exception) {}
                mediaView.translationX = 0f
                mediaView.alpha = 1f
                return
            }

            val endX = ((mediaView.width.takeIf { it > 0 } ?: resources.displayMetrics.widthPixels) + dp(24)).toFloat()
            mediaView.animate().cancel()
            mediaView.animate()
                .translationX(endX)
                .alpha(0f)
                .setDuration(180L)
                .withEndAction {
                    try { p?.removeView(mediaView) } catch (_: Exception) {}
                    mediaView.translationX = 0f
                    mediaView.alpha = 1f
                }
                .start()
        }

        val gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent): Boolean = true

            override fun onScroll(e1: MotionEvent?, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean {
                if (e1 == null) return false
                val dx = e2.x - e1.x
                val dy = e2.y - e1.y
                if (!swiping) {
                    if (abs(dx) < dp(6) || abs(dx) < abs(dy)) return false
                    swiping = true
                }
                if (dx <= 0f) return true
                val endX = (mediaView.width.takeIf { it > 0 } ?: resources.displayMetrics.widthPixels).toFloat()
                val clampedDx = dx.coerceIn(0f, endX)
                mediaView.translationX = clampedDx
                mediaView.alpha = (1f - (clampedDx / endX)).coerceIn(0.15f, 1f)
                return true
            }

            override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                if (e1 == null) return false
                val dx = e2.x - e1.x
                if (dx > dismissThresholdPx || velocityX > 1800f) {
                    dismissMedia(animated = true)
                    return true
                }
                return false
            }
        })

        val dragHandle = textArea ?: titleTv ?: subtitleTv
        dragHandle?.setOnTouchListener { _, event ->
            if (volumePanel?.visibility == View.VISIBLE) return@setOnTouchListener false
            val handled = gestureDetector.onTouchEvent(event)
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    fsBlockScrollForMediaDrag = false
                    fsScrollView?.requestDisallowInterceptTouchEvent(false)
                    handled
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    fsBlockScrollForMediaDrag = false
                    fsScrollView?.requestDisallowInterceptTouchEvent(false)
                    if (!swiping) return@setOnTouchListener false
                    val dx = mediaView.translationX
                    if (dx > dismissThresholdPx) {
                        dismissMedia(animated = true)
                    } else {
                        mediaView.animate().cancel()
                        mediaView.animate().translationX(0f).alpha(1f).setDuration(140L).start()
                    }
                    swiping = false
                    true
                }
                else -> {
                    if (swiping) {
                        fsBlockScrollForMediaDrag = true
                        fsScrollView?.requestDisallowInterceptTouchEvent(true)
                        true
                    } else {
                        handled
                    }
                }
            }
        }

        var lastDurationMs = 0L
        var scrubbing = false
        fun progressToPct(x: Float, widthPx: Int): Int {
            if (widthPx <= 0) return 0
            val ratio = (x / widthPx.toFloat()).coerceIn(0f, 1f)
            return (ratio * 1000f).toInt().coerceIn(0, 1000)
        }
        progressBar?.setOnTouchListener { v, ev ->
            val dur = lastDurationMs
            if (dur <= 0L) return@setOnTouchListener false
            val w = v.width
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                    scrubbing = true
                    val pct = progressToPct(ev.x, w)
                    progressBar.progress = pct
                    timeCurrentTv?.text = formatMs(((pct.toDouble() / 1000.0) * dur.toDouble()).toLong())
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val pct = progressToPct(ev.x, w)
                    progressBar.progress = pct
                    val posMs = ((pct.toDouble() / 1000.0) * dur.toDouble()).toLong().coerceIn(0L, dur)
                    sendMediaCommand("seekTo", posMs)
                    scrubbing = false
                    true
                }
                else -> false
            }
        }

        fun refreshUiFrom(state: JSONObject) {
            try {
                val title = state.optString("title", "").trim().ifEmpty { "Sin reproducción" }
                val subtitle = state.optString("artist", "").trim()
                val durationMs = try { state.optLong("durationMs", 0L) } catch (_: Exception) { 0L }
                val positionMs = try { state.optLong("positionMs", 0L) } catch (_: Exception) { 0L }
                val isPlaying = state.optBoolean("isPlaying", false)
                titleTv?.text = title
                subtitleTv?.text = subtitle
                setPlayPauseIcon(isPlaying)
                val pct = if (durationMs > 0L) {
                    val clamped = positionMs.coerceIn(0L, durationMs)
                    ((clamped.toDouble() / durationMs.toDouble()) * 1000.0).toInt().coerceIn(0, 1000)
                } else {
                    0
                }
                lastDurationMs = durationMs
                progressBar?.max = 1000
                if (!scrubbing) progressBar?.progress = pct
                if (!scrubbing) timeCurrentTv?.text = formatMs(positionMs)
                timeTotalTv?.text = formatMs(durationMs)
                timeAppTv?.text = state.optString("appName", "").trim()
                val artB64 = state.optString("artBase64", "").trim()
                if (artB64.isNotEmpty()) {
                    val bmp = decodePngBase64(artB64)
                    if (bmp != null) {
                        bgIv?.setImageBitmap(bmp)
                    } else {
                        val now = System.currentTimeMillis()
                        val useLocal = shouldUseLocalMediaForControls(now)
                        val connected = try { BtClassicServerService.connectedPeers > 0 } catch (_: Exception) { false }
                        if (!useLocal && connected && now - lastMediaStateRequestAtMs > 1500L) {
                            lastMediaStateRequestAtMs = now
                            sendMediaCommand("request_state")
                        }
                    }
                } else {
                    val now = System.currentTimeMillis()
                    val useLocal = shouldUseLocalMediaForControls(now)
                    val connected = try { BtClassicServerService.connectedPeers > 0 } catch (_: Exception) { false }
                    if (!useLocal && connected && now - lastMediaStateRequestAtMs > 1500L) {
                        lastMediaStateRequestAtMs = now
                        sendMediaCommand("request_state")
                    }
                }
            } catch (_: Exception) {
            }

            val vol = readSelectedVolumePctFreshOrNull()
            if (vol != null) {
                volumeProgress?.max = 100
                volumeProgress?.progress = vol
            }
        }

        mediaModalView = mediaView
        fsMediaDismissedByUser = false
        refreshUiFrom(initialState)
        sendVolumeRequest()
        val tick = object : Runnable {
            override fun run() {
                if (menuView == null || mediaModalView == null) return
                val st = readSelectedMediaStateOrNull()
                if (st != null) refreshUiFrom(st)
                mainHandler.postDelayed(this, 1000L)
            }
        }
        mediaModalTick = tick
        mainHandler.postDelayed(tick, 1000L)

        parent.addView(mediaView, index.coerceIn(0, parent.childCount))
    }

    private fun showVolumeModal(root: FrameLayout) {
        if (volumeModalView != null) return
        val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return

        val scrim = FrameLayout(this).apply {
            setBackgroundColor(0x99000000.toInt())
            isClickable = true
            setOnClickListener { hideVolumeModal(root) }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(fsBgColor)
                setStroke(dp(1), Color.parseColor("#22FFFFFF"))
            }
            background = bg
            setPadding(dp(16), dp(16), dp(16), dp(16))
            isClickable = true
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val title = TextView(this).apply {
            text = "Volumen"
            setTextColor(fsContentColor)
            textSize = 16f
        }
        val close = TextView(this).apply {
            text = "Cerrar"
            setTextColor(fsContentColor)
            textSize = 14f
            setPadding(dp(12), dp(8), dp(12), dp(8))
            isClickable = true
            setOnClickListener { hideVolumeModal(root) }
        }
        header.addView(title, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(close)
        card.addView(header)

        val entries = listOf(
            Pair("Sistema", AudioManager.STREAM_SYSTEM),
            Pair("Multimedia", AudioManager.STREAM_MUSIC),
            Pair("Notificaciones", AudioManager.STREAM_NOTIFICATION),
            Pair("Llamadas", AudioManager.STREAM_VOICE_CALL),
            Pair("Timbre", AudioManager.STREAM_RING),
            Pair("Alarmas", AudioManager.STREAM_ALARM),
        )

        for ((label, stream) in entries) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(0, dp(10), 0, 0)
            }
            val tv = TextView(this).apply {
                text = label
                setTextColor(fsContentColor)
                textSize = 14f
            }
            val max = audio.getStreamMaxVolume(stream)
            val cur = audio.getStreamVolume(stream)
            val seek = SeekBar(this).apply {
                this.max = max
                progress = cur
                setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                    override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                        if (!fromUser) return
                        try { audio.setStreamVolume(stream, progress, 0) } catch (_: Exception) {}
                    }
                    override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                    override fun onStopTrackingTouch(seekBar: SeekBar?) {}
                })
            }
            row.addView(tv)
            row.addView(seek)
            card.addView(row)
        }

        scrim.addView(
            card,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.CENTER
                leftMargin = dp(18)
                rightMargin = dp(18)
            }
        )

        volumeModalView = scrim
        root.addView(scrim, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
    }

    private fun hideVolumeModal(root: FrameLayout) {
        val v = volumeModalView ?: return
        try { root.removeView(v) } catch (_: Exception) {}
        volumeModalView = null
        if (root === modalHostView) maybeRemoveModalHost()
    }

    private fun showBrightnessModal(root: FrameLayout) {
        if (brightnessModalView != null) return

        val scrim = FrameLayout(this).apply {
            setBackgroundColor(0x99000000.toInt())
            isClickable = true
            setOnClickListener { hideBrightnessModal(root) }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(fsBgColor)
                setStroke(dp(1), Color.parseColor("#22FFFFFF"))
            }
            background = bg
            setPadding(dp(16), dp(16), dp(16), dp(16))
            isClickable = true
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val title = TextView(this).apply {
            text = "Brillo"
            setTextColor(fsContentColor)
            textSize = 16f
        }
        val close = TextView(this).apply {
            text = "Cerrar"
            setTextColor(fsContentColor)
            textSize = 14f
            setPadding(dp(12), dp(8), dp(12), dp(8))
            isClickable = true
            setOnClickListener { hideBrightnessModal(root) }
        }
        header.addView(title, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(close)
        card.addView(header)

        val current = try {
            Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS).coerceIn(0, 255)
        } catch (_: Exception) {
            128
        }

        val hasWrite = try {
            Settings.System.canWrite(this)
        } catch (_: Exception) {
            false
        }

        if (!hasWrite) {
            val hint = TextView(this).apply {
                text = "Para cambiar el brillo del dispositivo debes permitir 'Modificar ajustes del sistema'."
                setTextColor(fsContentColor)
                textSize = 12f
                setPadding(0, dp(10), 0, dp(10))
            }
            val allow = TextView(this).apply {
                text = "Permitir"
                setTextColor(fsContentColor)
                textSize = 14f
                setPadding(dp(12), dp(8), dp(12), dp(8))
                isClickable = true
                val bg = GradientDrawable().apply {
                    cornerRadius = dp(10).toFloat()
                    setColor(fsButtonColor)
                    setStroke(dp(1), Color.parseColor("#22FFFFFF"))
                }
                background = bg
                setOnClickListener {
                    try {
                        val i = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(i)
                    } catch (_: Exception) {
                    }
                }
            }
            card.addView(hint)
            card.addView(allow)
        }

        val valueRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(12), 0, 0)
        }
        val valueLabel = TextView(this).apply {
            text = current.toString()
            setTextColor(fsContentColor)
            textSize = 12f
        }
        valueRow.addView(TextView(this).apply {
            text = "0"
            setTextColor(fsContentColor)
            textSize = 12f
        })
        valueRow.addView(View(this), LinearLayout.LayoutParams(0, 0, 1f))
        valueRow.addView(valueLabel)
        card.addView(valueRow)

        val seek = SeekBar(this).apply {
            max = 255
            progress = current
        }
        seek.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val p = progress.coerceIn(0, 255)
                valueLabel.text = p.toString()
                try {
                    if (Settings.System.canWrite(this@FloatingBallService)) {
                        Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL)
                        Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, p)
                    } else {
                        val lp = menuLp
                        val windowManager = wm
                        val v = menuView
                        if (lp != null && windowManager != null && v != null) {
                            lp.screenBrightness = (p / 255f).coerceIn(0.01f, 1f)
                            try { windowManager.updateViewLayout(v, lp) } catch (_: Exception) {}
                        }
                    }
                } catch (_: Exception) {
                }
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
        card.addView(seek, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(10)
        })

        scrim.addView(
            card,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.CENTER
                leftMargin = dp(18)
                rightMargin = dp(18)
            }
        )

        brightnessModalView = scrim
        root.addView(
            scrim,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        )
    }

    private fun hideBrightnessModal(root: FrameLayout) {
        val v = brightnessModalView ?: return
        try { root.removeView(v) } catch (_: Exception) {}
        brightnessModalView = null
        if (root === modalHostView) maybeRemoveModalHost()
    }

    private fun rebuildMenuIfVisible() {
        val m = menuView ?: return
        val desiredNotifsVisible = fsNotifsVisible
        hideMenu()
        fsNotifsVisible = desiredNotifsVisible
        val ball = ballLp
        if (ball != null) {
            if (fullScreenMenu) {
                showFullScreenMenu()
            } else {
                showPopupMenu(ball.x, ball.y)
            }
        } else {
            try { wm?.removeView(m) } catch (_: Exception) {}
        }
    }

    private fun hideMenu() {
        val windowManager = wm ?: return
        val v = menuView ?: return
        val root = v as? FrameLayout
        if (root != null && volumeModalView != null) hideVolumeModal(root) else volumeModalView = null
        if (root != null && brightnessModalView != null) hideBrightnessModal(root) else brightnessModalView = null
        if (root != null && mediaModalView != null) hideMediaPopupModal(root) else mediaModalView = null
        stopFsBarTick()
        stopFsNotifsTick()
        unregisterFsNotifsEventsReceiver()
        fsBarView = null
        fsBarTimeTv = null
        fsBarRestoreIv = null
        fsBarWifiIv = null
        fsBarBtIv = null
        fsBarDataIv = null
        fsBarLocIv = null
        fsBarBatteryIv = null
        fsBarBatteryTv = null
        fsFullScreenContent = null
        fsScrollView = null
        fsNotifsList = null
        fsNotifsEmptyTv = null
        fsNotifsScrollView = null
        fsNotifsRowByKey.clear()
        fsNotifsRowDragging = false
        fsNotifsVisible = false
        fsMediaDismissedByUser = false
        fsBlockScrollForMediaDrag = false
        try { windowManager.removeView(v) } catch (_: Exception) {}
        menuView = null
        menuLp = null
    }

    private fun performGlobal(action: Int) {
        val ok = FloatingBallAccessibilityService.performGlobalActionSafe(action)
        if (!ok) {
            Toast.makeText(this, "Activa el servicio de accesibilidad de Connect", Toast.LENGTH_SHORT).show()
            maybeOpenAccessibilitySettings()
        }
    }

    private fun isFloatingBallAccessibilityEnabled(): Boolean {
        return try {
            val flat = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            val cn = ComponentName(packageName, FloatingBallAccessibilityService::class.java.name)
            val id = cn.flattenToString()
            flat != null && flat.contains(id)
        } catch (_: Exception) {
            false
        }
    }

    private fun maybeOpenAccessibilitySettings() {
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastAccessibilityPromptAtMs < 30_000L) return
        lastAccessibilityPromptAtMs = now
        if (isFloatingBallAccessibilityEnabled()) return
        try {
            val i = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(i)
        } catch (_: Exception) {
        }
    }

    private fun startAccessibilityWatchdog() {
        if (accessibilityWatchdog != null) return
        val tick = object : Runnable {
            override fun run() {
                val enabled = isFloatingBallAccessibilityEnabled()
                val prev = lastAccessibilityEnabled
                if (prev == null || prev != enabled) {
                    lastAccessibilityEnabled = enabled
                    try {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        nm?.notify(NOTIFICATION_ID, buildForegroundNotification())
                    } catch (_: Exception) {
                    }
                }
                mainHandler.postDelayed(this, 8000L)
            }
        }
        accessibilityWatchdog = tick
        mainHandler.post(tick)
    }

    private fun stopAccessibilityWatchdog() {
        val t = accessibilityWatchdog ?: return
        mainHandler.removeCallbacks(t)
        accessibilityWatchdog = null
    }

    private fun resolveAppLabel(pkg: String): String {
        return try {
            val pm = packageManager
            val ai = pm.getApplicationInfo(pkg, 0)
            pm.getApplicationLabel(ai).toString()
        } catch (_: Exception) {
            ""
        }
    }

    private fun launchPackage(pkg: String) {
        try {
            val launch = packageManager.getLaunchIntentForPackage(pkg) ?: return
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launch)
        } catch (_: Exception) {
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun buildForegroundNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openAppPi = PendingIntent.getActivity(
            this,
            1001,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        val accessibilityEnabled = isFloatingBallAccessibilityEnabled()
        val b = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle("Bola flotante activa")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openAppPi)

        if (accessibilityEnabled) {
            b.setContentText("Se muestra sobre otras aplicaciones")
        } else {
            b.setContentText("Activa accesibilidad para Back/Home/Recientes")
            val openAccIntent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val openAccPi = PendingIntent.getActivity(
                this,
                1002,
                openAccIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
            b.addAction(android.R.drawable.ic_menu_manage, "Accesibilidad", openAccPi)
        }

        return b.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        val ch = NotificationChannel(CHANNEL_ID, "Bola flotante", NotificationManager.IMPORTANCE_LOW)
        nm.createNotificationChannel(ch)
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    }

    private fun dp(value: Int): Int {
        val density = resources.displayMetrics.density
        return (value.toFloat() * density).toInt()
    }

    private fun savePosition(x: Int, y: Int) {
        try {
            val prefs = getSharedPreferences(PREFS_POS, Context.MODE_PRIVATE)
            prefs.edit().putInt(KEY_POS_X, x).putInt(KEY_POS_Y, y).apply()
        } catch (_: Exception) {
        }
    }

    private fun readSavedPosition(): Pair<Int, Int> {
        return try {
            val prefs = getSharedPreferences(PREFS_POS, Context.MODE_PRIVATE)
            val x = prefs.getInt(KEY_POS_X, dp(8))
            val y = prefs.getInt(KEY_POS_Y, dp(140))
            Pair(x, y)
        } catch (_: Exception) {
            Pair(dp(8), dp(140))
        }
    }
}
