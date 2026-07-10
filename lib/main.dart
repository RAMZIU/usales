import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'screens/top10_screen.dart';
import 'screens/produits_u_screen.dart';
import 'screens/croissance_screen.dart';
import 'screens/top_departement_screen.dart';
import 'screens/ods_daily_screen.dart';
import 'screens/stock_scanner_screen.dart';
import 'screens/magasins_screen.dart';
import 'screens/stock_rotation_screen.dart';
import 'screens/fingerprint_enrollment_screen.dart';
import 'screens/stock_negatif_screen.dart';
import 'screens/tickets_screen.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USALES',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF06616E),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF06616E),
          secondary: Color(0xFFE22019),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF06616E),
          centerTitle: false,
          titleSpacing: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Version actuelle
  final String _currentVersion = '2.2.0';
  final int _currentVersionCode = 1;
  
  // Version distante
  Map<String, dynamic>? _remoteVersion;
  bool _isChecking = false;
  bool _updateAvailable = false;
  String? _downloadUrl;
  
  final List<MenuItem> _menuItems = [
    MenuItem(icon: Icons.home, title: 'Accueil', color: const Color(0xFF06616E)),
    MenuItem(icon: Icons.store, title: 'CA Magasin J-1', color: const Color(0xFF06616E)),
    MenuItem(icon: Icons.emoji_events, title: 'TOP 10 Articles', color: const Color(0xFFE22019)),
    MenuItem(icon: Icons.timeline, title: 'Suivi Daily', color: const Color(0xFF06616E)),
    MenuItem(icon: Icons.category, title: 'Produits U', color: const Color(0xFFF59E0B)),
    MenuItem(icon: Icons.trending_up, title: 'Croissance', color: const Color(0xFF8B5CF6)),
    MenuItem(icon: Icons.dashboard, title: 'TOP par Dépt', color: const Color(0xFFEC4899)),
    MenuItem(icon: Icons.qr_code_scanner, title: 'Scanner Stock', color: const Color(0xFF8B5CF6)),
    MenuItem(icon: Icons.search, title: 'Recherche Article', color: const Color(0xFF06616E)),
    MenuItem(icon: Icons.fingerprint, title: 'Empreinte Digital', color: const Color(0xFF8B5CF6)),
   MenuItem(icon: Icons.warning_amber, title: 'Stock Négatif', color: const Color(0xFFEF4444)),
MenuItem(icon: Icons.receipt, title: 'Top Tickets', color: const Color(0xFFF59E0B)),

  ];

  @override
  void initState() {
    super.initState();
    // Vérification au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  // Vérifier les mises à jour en direct sur version.json
  Future<void> _checkForUpdates({bool showNoUpdateMessage = false}) async {
    if (!mounted) return;
    
    setState(() {
      _isChecking = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://gist.githubusercontent.com/RAMZIU/256727578cdc9f728fc39fc2259111ee/raw/version.json'),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        _remoteVersion = jsonDecode(response.body);
        final remoteVersionCode = _remoteVersion?['version_code'] ?? 0;
        
        setState(() {
          _updateAvailable = remoteVersionCode > _currentVersionCode;
          _downloadUrl = _remoteVersion?['download_url'];
        });
        
        // Afficher un message si l'utilisateur a demandé une vérification
        if (showNoUpdateMessage) {
          if (_updateAvailable) {
            _showUpdateDialog();
          } else {
            _showInfoSnackBar('✅ Version à jour', 'Vous utilisez la dernière version ($_currentVersion)');
          }
        }
      } else {
        if (showNoUpdateMessage) {
          _showInfoSnackBar('⚠️ Erreur', 'Impossible de vérifier les mises à jour');
        }
      }
    } catch (e) {
      print('Erreur vérification version: $e');
      if (showNoUpdateMessage) {
        _showInfoSnackBar('⚠️ Erreur', 'Erreur de connexion: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  // SnackBar d'information simple
  void _showInfoSnackBar(String title, String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(title.contains('✅') ? Icons.check_circle : Icons.info_outline, 
                 color: title.contains('✅') ? Colors.green : Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('$title: $message', style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Dialogue de mise à jour
  void _showUpdateDialog() {
    if (!mounted) return;
    
    final List<dynamic> whatsNew = _remoteVersion?['whats_new'] ?? [];
    final String newVersion = _remoteVersion?['version'] ?? 'Nouvelle version';
    
    if (newVersion == _currentVersion) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.system_update_alt, color: Colors.orange, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Nouvelle version disponible',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF06616E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Version actuelle :', style: TextStyle(fontSize: 13)),
                    Text(_currentVersion, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.arrow_forward, size: 16),
                    Text(newVersion, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06616E))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (whatsNew.isNotEmpty) ...[
                const Text('📋 Nouveautés :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...whatsNew.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 13)),
                      Expanded(child: Text(item.toString(), style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _launchUpdateUrl();
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Télécharger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06616E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Ouvrir le lien de téléchargement
  Future<void> _launchUpdateUrl() async {
    if (!mounted) return;
    
    if (_downloadUrl == null || _downloadUrl!.isEmpty) {
      _showInfoSnackBar('⚠️ Erreur', 'Aucun lien de téléchargement disponible');
      return;
    }

    final Uri url = Uri.parse(_downloadUrl!);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_download, color: Color(0xFF06616E)),
              SizedBox(width: 10),
              Text('Téléchargement'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pour installer la mise à jour :'),
              SizedBox(height: 16),
              Text('1️⃣ Cliquez sur "Ouvrir" ci-dessous'),
              Text('2️⃣ Téléchargez le fichier APK'),
              Text('3️⃣ Ouvrez le fichier pour installer'),
              SizedBox(height: 16),
              Text('⚠️ Important :', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Activez "Sources inconnues" dans les paramètres'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    _showCopyLinkDialog();
                  }
                } catch (e) {
                  _showCopyLinkDialog();
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Ouvrir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06616E),
              ),
            ),
          ],
        );
      },
    );
  }

  // Dialogue pour copier le lien
  void _showCopyLinkDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Téléchargement manuel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Copiez ce lien et ouvrez-le dans votre navigateur :'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _downloadUrl ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _downloadUrl ?? ''));
                Navigator.of(context).pop();
                _showInfoSnackBar('✅ Copié', 'Lien copié dans le presse-papier');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copier'),
            ),
          ],
        );
      },
    );
  }

  // Dialogue d'information de version
  void _showVersionInfo() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF06616E)),
              SizedBox(width: 10),
              Text('À propos'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.code),
                title: const Text('Version'),
                trailing: Text(_currentVersion, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.update),
                title: const Text('Vérifier les mises à jour'),
                trailing: _isChecking 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: () => _checkForUpdates(showNoUpdateMessage: true),
                        tooltip: 'Vérifier',
                      ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void navigateToScreen(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text(
          'USALES',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  _updateAvailable ? Icons.system_update_alt : Icons.info_outline,
                  color: _updateAvailable ? Colors.orange : const Color(0xFF06616E),
                  size: 22,
                ),
                onPressed: _showVersionInfo,
                tooltip: 'Version $_currentVersion',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              if (_updateAvailable)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06616E), Color(0xFF0A8A9A)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.analytics, color: Colors.white, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      'USALES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tableau de bord',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _menuItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _buildDrawerItem(
                      index: index,
                      item: _menuItems[index],
                      isSelected: _selectedIndex == index,
                    );
                  },
                ),
              ),
              // Version dans le footer du drawer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          'Version $_currentVersion',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 16),
                        if (_isChecking)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          InkWell(
                            onTap: () => _checkForUpdates(showNoUpdateMessage: true),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06616E).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 14, color: Color(0xFF06616E)),
                                  SizedBox(width: 4),
                                  Text('Vérifier', style: TextStyle(fontSize: 11, color: Color(0xFF06616E))),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_updateAvailable) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showUpdateDialog,
                          icon: const Icon(Icons.system_update_alt, size: 16),
                          label: Text('Version ${_remoteVersion?['version']} disponible'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildCurrentScreen(),
    );
  }

  Widget _buildDrawerItem({
    required int index,
    required MenuItem item,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Icon(
        item.icon,
        color: isSelected ? item.color : Colors.grey[600],
        size: 24,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? item.color : Colors.grey[800],
          fontSize: 15,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: item.color, size: 20)
          : null,
      tileColor: isSelected ? item.color.withOpacity(0.1) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return HomeWelcomeScreen(onNavigate: navigateToScreen);
      case 1:
        return const MagasinsScreen();
      case 2:
        return const Top10Screen();
      case 3:
        return const ODSDailyScreen();
      case 4:
        return const ProduitsUScreen();
      case 5:
        return const CroissanceScreen();
      case 6:
        return const TopDepartementScreen();
      case 7:
        return const StockScannerScreen();
      case 8:
        return const StockRotationScreen();
      case 9:
        return const FingerprintEnrollmentScreen();
      case 10:
        return const StockNegatifScreen();
      case 11:
        return const TicketsScreen();
      default:
        return const SizedBox();
    }
  }
}

class MenuItem {
  final IconData icon;
  final String title;
  final Color color;

  MenuItem({
    required this.icon,
    required this.title,
    required this.color,
  });
}

// ============================================
// ÉCRAN D'ACCUEIL CORRIGÉ
// ============================================

class HomeWelcomeScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const HomeWelcomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF06616E).withOpacity(0.06),
            Colors.white,
            const Color(0xFFE22019).withOpacity(0.03),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06616E), Color(0xFF0A8A9A)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06616E).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.analytics,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'USALES',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF06616E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE22019).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Votre outil de pilotage',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE22019),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06616E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.star, size: 16, color: Color(0xFF06616E)),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              
              const SizedBox(height: 20),
              
              const Text(
                '📊 Fonctionnalités',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF06616E),
                ),
              ),
              const SizedBox(height: 20),
              
              // Grille des fonctionnalités
              LayoutBuilder(
                builder: (context, constraints) {
                  final double cardWidth = (constraints.maxWidth - 16) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildCard(context, Icons.store, 'CA Magasin', const Color(0xFF06616E), 1, cardWidth),
                      _buildCard(context, Icons.emoji_events, 'TOP 10', const Color(0xFFE22019), 2, cardWidth),
                      _buildCard(context, Icons.timeline, 'Suivi Daily', const Color(0xFF0A8A9A), 3, cardWidth),
                      _buildCard(context, Icons.category, 'Produits U', const Color(0xFFF59E0B), 4, cardWidth),
                      _buildCard(context, Icons.trending_up, 'Croissance', const Color(0xFF8B5CF6), 5, cardWidth),
                      _buildCard(context, Icons.dashboard, 'TOP par Dépt', const Color(0xFFEC4899), 6, cardWidth),
                      _buildCard(context, Icons.qr_code_scanner, 'Scanner Stock', const Color(0xFF10B981), 7, cardWidth),
                      _buildCard(context, Icons.search, 'Recherche Article', const Color(0xFF06616E), 8, cardWidth),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Message de navigation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF06616E).withOpacity(0.1),
                      const Color(0xFFE22019).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF06616E).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06616E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Ouvrez le menu ☰',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF06616E),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, IconData icon, String title, Color color, int index, double width) {
    return GestureDetector(
      onTap: () => onNavigate(index),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}