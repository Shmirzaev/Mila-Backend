class AppConfig {
  const AppConfig._();

  static const String defaultBackendBaseUrl = String.fromEnvironment(
    'MILA_DEFAULT_BACKEND_URL',
    defaultValue: 'https://mila-web.onrender.com',
  );

  static const bool autoConnectOnLaunch = bool.fromEnvironment(
    'MILA_AUTO_CONNECT_ON_LAUNCH',
    defaultValue: true,
  );
}
