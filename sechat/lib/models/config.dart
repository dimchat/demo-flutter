
class Config {
  static Config? _instance;
  Config._internal() {
    _instance = this;
    // TODO: start a background thread to query 'https://dim.chat/sechat/gsp.js'
    //       for updating configurations
  }
  factory Config() => _instance ?? Config._internal();

  get aboutURL {
    return 'https://dim.chat/';
  }

  get termsURL {
    return 'https://wallet.dim.chat/dimchat/sechat/privacy.html';
  }

  get uploadAPI {
    return 'http://106.52.25.169:8081/{ID}/upload?md5={MD5}&salt={SALT}';
  }
}
