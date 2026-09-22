class ApiConstants {
  static const String defaultBaseUrl = 'http://192.168.1.110:8080';
  static const String defaultWsUrl = 'ws://192.168.1.110:8080';

  static String baseUrl = defaultBaseUrl;
  static String wsUrl = defaultWsUrl;

  // Auth & Subscription endpoints
  static String get loginUrl => '$baseUrl/api/v1/auth/login';
  static String get registerUrl => '$baseUrl/api/v1/auth/register';
  static String get meUrl => '$baseUrl/api/v1/auth/me';
  static String get mySubscriptionUrl => '$baseUrl/api/v1/subscription/my';

  // Device endpoints
  static String get devicesUrl => '$baseUrl/api/v1/devices';
  static String deleteDeviceUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId';
  static String deleteChildUrl(String childId) => '$baseUrl/api/v1/devices/children/$childId';
  static String get childrenUrl => '$baseUrl/api/v1/devices/children';
  static String pairCodeUrl(String childId) => '$baseUrl/api/v1/devices/children/$childId/pair-code';
  static String commandUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/command';
  static String deviceAppsUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/apps';
  static String blockAppUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/apps/block';
  static String deviceUsageUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/usage';
  static String deviceNotifsUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/notifications';
  static String screenTimeRulesUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/screen-time-rules';
  static String contactsUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/contacts';
  static String smsUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/sms';
  static String filesUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/files';
  static String callsUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/calls';
  static String riskAlertsUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/risk-alerts';
  static String markRiskAlertSafeUrl(String deviceId, dynamic alertId) => '$baseUrl/api/v1/devices/$deviceId/risk-alerts/$alertId/mark-safe';
  static String safeRiskPatternsUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/safe-patterns';

  // Location & Geofencing
  static String latestLocationUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/location/latest';
  static String locationHistoryUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/location/history';
  static String get geofencesUrl => '$baseUrl/api/v1/geofences';
  static String childGeofencesUrl(String childId) => '$baseUrl/api/v1/geofences/child/$childId';
  static String childGeofenceEventsUrl(String childId) => '$baseUrl/api/v1/geofences/events/$childId';
  static String deleteGeofenceUrl(String geofenceId) => '$baseUrl/api/v1/geofences/$geofenceId';

  // WebRTC ICE Servers config
  static String get webrtcConfigUrl => '$baseUrl/api/v1/webrtc/config';

  // Web Filter Endpoints
  static String webFilterRulesUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/web-filter';
  static String toggleWebFilterEngineUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/web-filter/toggle-engine';
  static String toggleAllWebFilterRulesUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/web-filter/toggle-all';
  static String toggleWebFilterRuleUrl(String deviceId, String ruleId) => '$baseUrl/api/v1/devices/$deviceId/web-filter/$ruleId/toggle';
  static String deleteWebFilterRuleUrl(String deviceId, String ruleId) => '$baseUrl/api/v1/devices/$deviceId/web-filter/$ruleId';
  static String seedWebFilterDefaultsUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/web-filter/seed-defaults';

  // Browser History & Safe Search
  static String browserHistoryUrl(String deviceId, {int limit = 100}) => '$baseUrl/api/v1/devices/$deviceId/browser-history?limit=$limit';
  static String browserHistoryStatsUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/browser-history/stats';
  static String clearBrowserHistoryUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/browser-history';
  static String quickBlockBrowserDomainUrl(String deviceId) => '$baseUrl/api/v1/devices/$deviceId/browser-history/quick-block';
}
