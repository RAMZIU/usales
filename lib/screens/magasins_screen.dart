import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class MagasinsScreen extends StatefulWidget {
  const MagasinsScreen({super.key});

  @override
  State<MagasinsScreen> createState() => _MagasinsScreenState();
}

class _MagasinsScreenState extends State<MagasinsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<dynamic> _magasins = [];
  List<dynamic> _filteredMagasins = [];
  String? _error;
  String _lastUpdate = '';      // Date de dernière mise à jour des données
  String _studyDate = '';        // Date d'étude (ex: 2026-06-01)
  String _searchQuery = '';
  
  // Filtres
  String _selectedFilter = 'tous';
  bool _showOnlyActive = false;
  
  // Données de performance
  Map<String, Map<String, dynamic>> _performanceData = {};
  Map<String, dynamic> _totaux = {};
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // URLs Gist
  static const String magasinsUrl = 'https://gist.githubusercontent.com/RAMZIU/31822fea165e22e24b68ca2ce3b52964/raw/magasins.json';
  static const String statsUrl = 'https://gist.githubusercontent.com/RAMZIU/f528c64b5ffbbc49922ad295d48b926c/raw/statistiques_clients.json';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
      // VIDER LES DONNÉES EXISTANTES
      _magasins = [];
      _filteredMagasins = [];
      _performanceData = {};
      _totaux = {};
      _lastUpdate = '';
      _studyDate = '';
    });

    try {
      await Future.wait([_loadMagasins(), _loadPerformanceData()]);
      _applyFilters();
      setState(() {
        _isRefreshing = false;
        _isLoading = false;
      });
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isRefreshing = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([_loadMagasins(), _loadPerformanceData()]);
      _applyFilters();
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMagasins() async {
    try {
      final dio = Dio();
      final response = await dio.get(magasinsUrl);
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data);
        } else {
          data = response.data;
        }
        
        _magasins = data['data'] ?? [];
        _lastUpdate = data['last_update'] ?? '';
        
        print('✅ Magasins chargés: ${_magasins.length}');
        
        // Si pas de données, ne pas utiliser de mock
        if (_magasins.isEmpty) {
          _error = 'Aucune donnée de magasins disponible';
        }
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur chargement magasins: $e');
      _magasins = [];
      _error = 'Impossible de charger les magasins. Vérifiez votre connexion.';
      rethrow;
    }
  }

  Future<void> _loadPerformanceData() async {
    try {
      final dio = Dio();
      final response = await dio.get(statsUrl);
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data;
        if (response.data is String) {
          data = jsonDecode(response.data);
        } else {
          data = response.data;
        }
        
        // Récupérer la date d'étude
        _studyDate = data['date'] ?? '';
        
        // Récupérer les totaux
        _totaux = data['totaux'] ?? {};
        
        // Récupérer les données de performance
        final List<dynamic> statsData = data['data'] ?? [];
        _performanceData = {};
        
        for (var stat in statsData) {
          final String magasin = stat['magasin']?.toString() ?? '';
          if (magasin.isNotEmpty) {
            _performanceData[magasin] = {
              'ca': (stat['ca_total_ttc'] ?? 0).toDouble(),
              'clients': (stat['nb_clients'] ?? 0).toDouble(),
              'panier': (stat['panier_moyen'] ?? 0).toDouble(),
            };
          }
        }
        
        print('✅ Performance chargée: ${_performanceData.length} magasins');
        
        // Si pas de données, ne pas utiliser de mock
        if (_performanceData.isEmpty && statsData.isEmpty) {
          _error = 'Aucune donnée de performance disponible';
        }
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur chargement performance: $e');
      _performanceData = {};
      _totaux = {};
      _error = 'Impossible de charger les performances. Vérifiez votre connexion.';
      rethrow;
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(_magasins);
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((m) {
        final nom = m['nom']?.toString().toLowerCase() ?? '';
        final code = m['id']?.toString() ?? m['code']?.toString() ?? '';
        return nom.contains(_searchQuery.toLowerCase()) ||
               code.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    if (_showOnlyActive) {
      filtered = filtered.where((m) {
        final String nom = m['nom']?.toString() ?? '';
        final perf = _performanceData[nom];
        return perf != null && (perf['ca'] > 0 || perf['clients'] > 0);
      }).toList();
    }
    
    if (_selectedFilter == 'ca') {
      filtered.sort((a, b) {
        final String nomA = a['nom']?.toString() ?? '';
        final String nomB = b['nom']?.toString() ?? '';
        final caA = _performanceData[nomA]?['ca'] ?? 0;
        final caB = _performanceData[nomB]?['ca'] ?? 0;
        return caB.compareTo(caA);
      });
    } else if (_selectedFilter == 'clients') {
      filtered.sort((a, b) {
        final String nomA = a['nom']?.toString() ?? '';
        final String nomB = b['nom']?.toString() ?? '';
        final clientsA = _performanceData[nomA]?['clients'] ?? 0;
        final clientsB = _performanceData[nomB]?['clients'] ?? 0;
        return clientsB.compareTo(clientsA);
      });
    } else if (_selectedFilter == 'panier') {
      filtered.sort((a, b) {
        final String nomA = a['nom']?.toString() ?? '';
        final String nomB = b['nom']?.toString() ?? '';
        final panierA = _performanceData[nomA]?['panier'] ?? 0;
        final panierB = _performanceData[nomB]?['panier'] ?? 0;
        return panierB.compareTo(panierA);
      });
    }
    
    setState(() {
      _filteredMagasins = filtered;
    });
  }

  double _getTotalCA() {
    return _totaux['total_ca']?.toDouble() ?? 0;
  }

  double _getTotalClients() {
    return _totaux['total_clients']?.toDouble() ?? 0;
  }

  double _getPanierMoyenGlobal() {
    return _totaux['panier_moyen_global']?.toDouble() ?? 0;
  }

  double _getMaxCA() {
    double maxCA = 0;
    for (var m in _filteredMagasins) {
      final String nom = m['nom']?.toString() ?? '';
      final ca = _performanceData[nom]?['ca'] ?? 0;
      if (ca > maxCA) maxCA = ca;
    }
    return maxCA;
  }

  double _getMaxClients() {
    double maxClients = 0;
    for (var m in _filteredMagasins) {
      final String nom = m['nom']?.toString() ?? '';
      final clients = _performanceData[nom]?['clients'] ?? 0;
      if (clients > maxClients) maxClients = clients;
    }
    return maxClients;
  }

  // Formater la date d'étude
  String _formatStudyDate() {
    if (_studyDate.isEmpty) return '';
    try {
      final parts = _studyDate.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return _studyDate;
    } catch (e) {
      return _studyDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header stylisé avec bouton refresh
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF06616E), Color(0xFF0A8A9A)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.store,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'U Express KPI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Performance des magasins',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bouton refresh
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: _isRefreshing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh, color: Colors.white),
                            onPressed: _isRefreshing ? null : _refreshData,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // AFFICHAGE DE LA DATE D'ÉTUDE
                    if (_studyDate.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Données du ${_formatStudyDate()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Barre de recherche stylisée
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _applyFilters();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Rechercher un magasin...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF06616E)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Filtres
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('📊 Tous', 'tous'),
                  _buildFilterChip('💰 CA élevé', 'ca'),
                  _buildFilterChip('👥 Plus clients', 'clients'),
                  _buildFilterChip('🛒 Panier moyen', 'panier'),
                  _buildFilterChip('✅ Actifs uniquement', 'active', isToggle: true),
                ],
              ),
            ),
          ),
          
          // Stats rapides
          if (_filteredMagasins.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    Icons.store,
                    '${_filteredMagasins.length}',
                    'Magasins',
                    const Color(0xFF06616E),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey[200]),
                  _buildStatCard(
                    Icons.attach_money,
                    '${(_getTotalCA() / 1000).toStringAsFixed(0)}K',
                    'CA Total',
                    const Color(0xFF10B981),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey[200]),
                  _buildStatCard(
                    Icons.people,
                    '${_getTotalClients().toStringAsFixed(0)}',
                    'Clients',
                    const Color(0xFF3B82F6),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey[200]),
                  _buildStatCard(
                    Icons.shopping_cart,
                    '${_getPanierMoyenGlobal().toStringAsFixed(0)} DH',
                    'Panier moyen',
                    const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Liste des magasins
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06616E)),
                        ),
                        SizedBox(height: 16),
                        Text('Chargement des données...'),
                      ],
                    ),
                  )
                : _error != null
                    ? _buildErrorWidget()
                    : _filteredMagasins.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.inbox,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucune donnée disponible',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _studyDate.isNotEmpty 
                                      ? 'Pas de données pour le ${_formatStudyDate()}'
                                      : 'Vérifiez votre connexion et réessayez',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _refreshData,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Réessayer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF06616E),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshData,
                            color: const Color(0xFF06616E),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _filteredMagasins.length,
                              itemBuilder: (context, index) {
                                final magasin = _filteredMagasins[index];
                                final String nom = magasin['nom']?.toString() ?? '';
                                final performance = _performanceData[nom] ?? {};
                                return FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: _buildMagasinCard(magasin, index, performance),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isToggle = false}) {
    final isSelected = isToggle ? _showOnlyActive : _selectedFilter == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (isToggle) {
              _showOnlyActive = selected;
            } else {
              _selectedFilter = selected ? value : 'tous';
            }
            _applyFilters();
          });
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF06616E).withOpacity(0.15),
        checkmarkColor: const Color(0xFF06616E),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF06616E) : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF06616E) : Colors.grey[300]!,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildMagasinCard(dynamic magasin, int index, Map<String, dynamic> performance) {
    final nom = magasin['nom']?.toString() ?? '';
    final code = magasin['id']?.toString() ?? magasin['code']?.toString() ?? '';
    final ca = performance['ca'] ?? 0;
    final clients = performance['clients'] ?? 0;
    final panier = performance['panier'] ?? 0;
    
    // Couleur selon performance
    Color cardColor;
    if (ca > 400000) {
      cardColor = const Color(0xFF10B981);
    } else if (ca > 200000) {
      cardColor = const Color(0xFF3B82F6);
    } else if (ca > 50000) {
      cardColor = const Color(0xFFF59E0B);
    } else if (ca > 0) {
      cardColor = const Color(0xFFF97316);
    } else {
      cardColor = const Color(0xFFEF4444);
    }
    
    final maxCA = _getMaxCA();
    final caPercentage = maxCA > 0 ? (ca / maxCA) : 0;
    final maxClients = _getMaxClients();
    final clientsPercentage = maxClients > 0 ? (clients / maxClients) : 0;
    
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _showMagasinDetails(magasin, cardColor, performance);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cardColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nom,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Code: $code',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(ca / 1000).toStringAsFixed(0)}K DH',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: cardColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${clients.toStringAsFixed(0)} clients',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: clientsPercentage,
                                backgroundColor: Colors.grey[200],
                                color: const Color(0xFF3B82F6),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_cart, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${panier.toStringAsFixed(0)} DH',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: caPercentage,
                                backgroundColor: Colors.grey[200],
                                color: cardColor,
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMagasinDetails(dynamic magasin, Color color, Map<String, dynamic> performance) {
    final nom = magasin['nom']?.toString() ?? '';
    final code = magasin['id']?.toString() ?? magasin['code']?.toString() ?? '';
    final ca = performance['ca'] ?? 0;
    final clients = performance['clients'] ?? 0;
    final panier = performance['panier'] ?? 0;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.store, color: color, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nom,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          'Code site: $code',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Indicateurs de performance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildDetailItem(
                icon: Icons.attach_money,
                label: 'Chiffre d\'affaires',
                value: '${(ca / 1000).toStringAsFixed(1)}K DH',
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 8),
              _buildDetailItem(
                icon: Icons.people,
                label: 'Nombre de clients',
                value: clients.toStringAsFixed(0),
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 8),
              _buildDetailItem(
                icon: Icons.shopping_cart,
                label: 'Panier moyen',
                value: '${panier.toStringAsFixed(0)} DH',
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Erreur inconnue',
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06616E),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}