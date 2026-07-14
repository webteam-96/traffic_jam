/// Named handles for the Figma-exported assets in assets/figma/.
/// Hashes come from the `const img… = ".../<hash>"` map at the top of each
/// screen's design-context file. Shared (chrome) assets + Home assets live here;
/// per-screen assets are referenced directly by their hash where used.
class Assets {
  Assets._();

  // App chrome (present on every main tab)
  static const logo = 'a9a8f2553c76cc72efa1cac2ecb12769f360ac7b.png';
  static const avatar = '2ed01d15290981ad2e667d9c2afed787ad4f0a8d.png';
  static const iconMenu = '66ab44b45b241a26de6e7167c230628086c0e369.svg';
  static const iconBell = '5e3ad7757540d74c304fe727ad17190c07d70b94.svg';

  // Bottom-nav icons
  static const navHome = '33a540ef4a349447ad7dfd52be4fe0ad54f213b2.svg';
  static const navPanchang = '04851c13fb08eefe57a4e5e58a5d3abce1d09ec1.svg';
  static const navMyChart = '4b4965e72bbda90913daf1fae9e9852bc3eddcbc.svg';
  static const navAskJay = '80b45eff730e342f22ffeb88995555a51e29cab8.svg';
  static const navProfile = '63db53386953a9525fc47c94448712389f3faf11.svg';

  // Home — action hub (2x2)
  static const iconKundli = 'bac51b087919aca875173b486b37985133b23d06.svg';
  static const iconPanchangAction = '78d62b6f4556619f5cf45ac23f99af07bb3f50ff.svg';
  static const iconNotifications = '113f6affeeed41b624ec8933b0e23da291b13e20.svg';
  static const iconCleanupTransits = 'fb57b3dbcbfaf6cf0b1961a1c62b642d074817db.svg';

  // Home — Today's Panchang calendar glyph
  static const iconCalendar = '7dd64fdd48addc9d45bf2d952ec43cbd0e3ed6eb.svg';

  // Home — Cosmic Foundations educational grid
  static const iconZodiac = '5d5c5fae92496afadd932997afebab1291d106d8.svg';
  static const iconPlanets = '75896a12554c21cd06175b7d70ca491fec88f29e.svg';
  static const iconHouses = '5b65ed8453b3769b29f6b4dad13439436a2d7631.svg';
  static const iconElements = 'f2e8552b8188b8a05022d80a299d56e0ab0fa9be.svg';
  static const iconNakshatras = '9f22f652ce7f4fb76811cd0d90c81488bed33c9b.svg';
  static const iconYog = 'cd8d373fa3706ef57e38fc44f90bbeebc0651a21.svg';

  // Home — misc
  static const iconFab = '07274a8bcf6b669f45334a773ee88ff24043e56a.svg';
  static const imgConsultation = 'd4723afd532649cf7e9db4265b4871e8be77653c.png';
}
