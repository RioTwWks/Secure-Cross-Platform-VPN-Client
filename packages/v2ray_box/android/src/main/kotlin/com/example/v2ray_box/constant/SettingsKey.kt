package com.example.v2ray_box.constant

object SettingsKey {
    private const val KEY_PREFIX = "flutter."

    const val SERVICE_MODE = "${KEY_PREFIX}service-mode"
    const val ACTIVE_CONFIG_PATH = "${KEY_PREFIX}active_config_path"
    const val ACTIVE_PROFILE_NAME = "${KEY_PREFIX}active_profile_name"

    const val PER_APP_PROXY_MODE = "${KEY_PREFIX}per_app_proxy_mode"
    const val PER_APP_PROXY_INCLUDE_LIST = "${KEY_PREFIX}per_app_proxy_include_list"
    const val PER_APP_PROXY_EXCLUDE_LIST = "${KEY_PREFIX}per_app_proxy_exclude_list"

    const val DEBUG_MODE = "${KEY_PREFIX}debug_mode"
    const val DISABLE_MEMORY_LIMIT = "${KEY_PREFIX}disable_memory_limit"
    const val DYNAMIC_NOTIFICATION = "${KEY_PREFIX}dynamic_notification"
    const val SYSTEM_PROXY_ENABLED = "${KEY_PREFIX}system_proxy_enabled"

    const val STARTED_BY_USER = "${KEY_PREFIX}started_by_user"
    const val CONFIG_OPTIONS = "config_options_json"

    // Notification settings
    const val NOTIFICATION_STOP_BUTTON_TEXT = "${KEY_PREFIX}notification_stop_button_text"
    const val NOTIFICATION_TITLE = "${KEY_PREFIX}notification_title"
    const val NOTIFICATION_ICON_NAME = "${KEY_PREFIX}notification_icon_name"

    // Traffic storage
    const val TOTAL_UPLOAD_TRAFFIC = "${KEY_PREFIX}total_upload_traffic"
    const val TOTAL_DOWNLOAD_TRAFFIC = "${KEY_PREFIX}total_download_traffic"

    // Ping test URL
    const val PING_TEST_URL = "${KEY_PREFIX}ping_test_url"

    // Core engine selection
    const val CORE_ENGINE = "${KEY_PREFIX}core_engine"
    const val ACTIVE_RUNTIME_ENGINE = "${KEY_PREFIX}active_runtime_engine"
}
