import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';

class ODSDailyScreen extends StatefulWidget {
  const ODSDailyScreen({super.key});

  @override
  State<ODSDailyScreen> createState() => _ODSDailyScreenState();
}

class _ODSDailyScreenState extends State<ODSDailyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  int _refreshCounter = 0;
  
  List<dynamic> _caObjectifData = [];
  List<dynamic> _caSiteRayonData = [];
  List<dynamic> _traficClientData = [];
  List<dynamic> _totauxParMagasin = [];
  
  String _selectedFiltreCA = 'tous';
  String _selectedFiltreTrafic = 'tous';
  
  // Benchmark - Hiérarchie
  String? _selectedLevel; // 'departement', 'rayon', 'site', 'magasinDetail'
  String? _selectedDepartement;
  String? _selectedRayon;
  String _selectedSiteFilter = 'tous';
  String? _selectedMagasinForDetail; // Pour le détail par magasin dans l'onglet CA
  List<dynamic> _magasinRayonsDetail = []; // Rayons du magasin sélectionné
  
  // Structures de données
  Map<String, List<String>> _departementRayons = {};
  Map<String, double> _caByDepartement = {};
  Map<String, Map<String, double>> _caByRayonForDepartement = {};
  Map<String, Map<String, double>> _caBySiteForRayon = {};
  Map<String, Map<String, double>> _caByRayonForMagasin = {}; // CA par rayon pour chaque magasin
  
  String _lastUpdateCAObjectif = '';
  String _lastUpdateSiteRayon = '';
  String _lastUpdateTrafic = '';
  String _lastRefreshTime = '';

  static const String caObjectifBaseUrl = 'https://gist.githubusercontent.com/RAMZIU/482926d00798a29872eea7bd4d7fb75a/raw/ca_objectif_ecart.json';
  static const String caSiteRayonBaseUrl = 'https://gist.githubusercontent.com/RAMZIU/0236be375666e37312b723bd63d60525/raw/ca_site_rayon.json';
  static const String traficClientBaseUrl = 'https://gist.githubusercontent.com/RAMZIU/c4781fbd8469aab7d526eadf00fdaad6/raw/nb_client.json';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initDepartementRayons();
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initDepartementRayons() {
    _departementRayons = {
      'ELDPH': [
        'EPICERIE', 'LIQUIDES', 'ENTRETIEN', 'BEAUTE SANTE', 'PARAPHARMACIE'
      ],
      'PRODUITS FRAIS': [
        'BVP', 'PAT INDUSTRIELLE', 'SURGELES', 'FROMAGE A LA COUPE',
        'CREMERIE L.S.', 'FRUITS ET LEGUMES', 'FLEURS & PLANTES',
        'CHARC.TRAIT.SAUC.SECS LS', 'CHARCT.TRAIT.TRADT.', 'VOL.LS INDUST.',
        'BOUCH.LS.INDUST.', 'BOUCH.VOL.ATELIER', 'POISSONNERIE'
      ],
      'BAZAR': [
        'EQUIPEMENT DE LA MAISON', 'CULTURE', 'LOISIRS', 'BRICOLAGE JARDINAGE AUTO',
        'BAZAR A SERVICE', 'PRESSE'
      ],
      'TEXTILE/CHAUSSURE': [
        'VETEMENT', 'SOUS-VETEMENT', 'COLLANT-CHAUSSETTES', 'EQUIPEMENT',
        'CHAUSSURE', 'BIJOUTERIE', 'BOUTIQUE OR'
      ],
      'SERVICES': [
        'S.A.V.', 'VENTES DIVERSES', 'PRESTATIONS LS', 'LOTERIE NATIONALE',
        'CARTES CADEAUX U', 'VENTE DE SERVICES AR', 'VENTE DE SERVICES SANS AR',
        'CONSIGNE', 'LOCATION U'
      ],
      'STATION SERVICE': [
        'CARBURANT NE PAS UTILISER', 'GAZ NE PAS UTILISER', 'ENTRETIEN VOITURE NPUTIL',
        'CARBURANT', 'GAZ', 'ENTRETIEN VOITURE'
      ],
      'COMMERCES ASSOCIES': [
        'BOUTIQUE SPORT', 'PRESSE', 'BIJOUTERIE', 'BOUTIQUE CADEAU',
        'RETOUCHES', 'CORDONNERIE', 'CLES MINUTE', 'FLEURS', 'BAR CAFE',
        'PRESSING', 'LAVERIE TEINTURERIE', 'COIFFEUR', 'ESTHETICIEN',
        'BOUTIQUE PARAPHARMACIE', 'BOUTIQUE VETEMENT', 'BOUTIQUE CHAUSSURE',
        'BOUTIQUE PHOTO', 'AUTRES COMMERCES'
      ],
      'CAFETERIAS': [
        'BOISSONS', 'REPAS', 'SNACK'
      ],
      'PUB., ECONOMAT, CARTE U': [
        'ECONOMAT', 'COMMUNICATION', 'CARTE U'
      ],
      'EXPLOITATION PDV': [
        'FRAIS PERSONNEL HORS RAYONS'
      ],
      'LIBRE CENTRALE': [
        'LIBRE CENTRALE', 'PRESTATIONS CENTRALES', 'COTISATIONS'
      ],
      'DEFAUT': ['DEFAUT']
    };
  }

  String _getDepartementForRayon(String rayon) {
    for (var entry in _departementRayons.entries) {
      if (entry.value.contains(rayon)) {
        return entry.key;
      }
    }
    return '';
  }

  void _resetToDepartements() {
    setState(() {
      _selectedLevel = 'departement';
      _selectedDepartement = null;
      _selectedRayon = null;
      _selectedSiteFilter = 'tous';
      _selectedMagasinForDetail = null;
      _magasinRayonsDetail = [];
    });
  }

  void _selectDepartement(String departement) {
    setState(() {
      _selectedLevel = 'rayon';
      _selectedDepartement = departement;
      _selectedRayon = null;
    });
  }

  void _selectRayon(String rayon) {
    setState(() {
      _selectedLevel = 'site';
      _selectedRayon = rayon;
    });
  }

  void _selectMagasinForDetail(String magasin) {
    // Récupérer les rayons de ce magasin
    Map<String, double> rayonsCA = _caByRayonForMagasin[magasin] ?? {};
    List<MapEntry<String, double>> entries = rayonsCA.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    
    setState(() {
      _selectedMagasinForDetail = magasin;
      _magasinRayonsDetail = entries;
      _selectedLevel = 'magasinDetail';
    });
  }

  void _goBackFromMagasinDetail() {
    setState(() {
      _selectedMagasinForDetail = null;
      _magasinRayonsDetail = [];
      _selectedLevel = null;
    });
  }

  void _goBack() {
    if (_selectedLevel == 'magasinDetail') {
      _goBackFromMagasinDetail();
    } else if (_selectedLevel == 'site') {
      setState(() {
        _selectedLevel = 'rayon';
        _selectedRayon = null;
      });
    } else if (_selectedLevel == 'rayon') {
      setState(() {
        _selectedLevel = 'departement';
        _selectedDepartement = null;
      });
    }
  }

  void _calculateBenchmarkData() {
    // Calculer CA par département
    _caByDepartement = {};
    for (var item in _caSiteRayonData) {
      String rayon = item['rayon'] ?? '';
      String departement = _getDepartementForRayon(rayon);
      double ca = (item['ca_ttc'] ?? 0).toDouble();
      
      if (departement.isNotEmpty) {
        _caByDepartement[departement] = (_caByDepartement[departement] ?? 0) + ca;
      }
    }
    
    // Calculer CA par rayon pour chaque département
    _caByRayonForDepartement = {};
    for (var item in _caSiteRayonData) {
      String rayon = item['rayon'] ?? '';
      String departement = _getDepartementForRayon(rayon);
      double ca = (item['ca_ttc'] ?? 0).toDouble();
      
      if (departement.isNotEmpty) {
        _caByRayonForDepartement.putIfAbsent(departement, () => {});
        _caByRayonForDepartement[departement]![rayon] = 
            (_caByRayonForDepartement[departement]![rayon] ?? 0) + ca;
      }
    }
    
    // Calculer CA par site pour chaque rayon
    _caBySiteForRayon = {};
    for (var item in _caSiteRayonData) {
      String rayon = item['rayon'] ?? '';
      String site = item['magasin'] ?? '';
      double ca = (item['ca_ttc'] ?? 0).toDouble();
      
      if (rayon.isNotEmpty && site.isNotEmpty) {
        _caBySiteForRayon.putIfAbsent(rayon, () => {});
        _caBySiteForRayon[rayon]![site] = (_caBySiteForRayon[rayon]![site] ?? 0) + ca;
      }
    }
    
    // Calculer CA par rayon pour chaque magasin
    _caByRayonForMagasin = {};
    for (var item in _caSiteRayonData) {
      String rayon = item['rayon'] ?? '';
      String magasin = item['magasin'] ?? '';
      double ca = (item['ca_ttc'] ?? 0).toDouble();
      
      if (rayon.isNotEmpty && magasin.isNotEmpty) {
        _caByRayonForMagasin.putIfAbsent(magasin, () => {});
        _caByRayonForMagasin[magasin]![rayon] = 
            (_caByRayonForMagasin[magasin]![rayon] ?? 0) + ca;
      }
    }
  }

  String _getNoCacheUrl(String baseUrl) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return '$baseUrl?nocache=$timestamp&v=$_refreshCounter&r=$random';
  }

  Future<void> _reloadAllData() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
      _refreshCounter++;
      _caObjectifData = [];
      _caSiteRayonData = [];
      _traficClientData = [];
      _totauxParMagasin = [];
    });

    await Future.delayed(const Duration(milliseconds: 150));
    await _loadAllData(forceRefresh: true);
  }

  Future<void> _loadAllData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (forceRefresh) {
        await Future.wait([
          _loadCaObjectifData(forceRefresh: true),
          _loadCaSiteRayonData(forceRefresh: true),
          _loadTraficClientData(forceRefresh: true),
        ]);
        setState(() {
          _lastRefreshTime = _getFormattedTimestamp();
        });
      } else {
        await Future.wait([
          _loadCaObjectifData(),
          _loadCaSiteRayonData(),
          _loadTraficClientData(),
        ]);
      }
      
      _calculateBenchmarkData();
      _resetToDepartements();

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadCaObjectifData({bool forceRefresh = false}) async {
    try {
      String url = caObjectifBaseUrl;
      if (forceRefresh) url = _getNoCacheUrl(caObjectifBaseUrl);
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _caObjectifData = data['data'] ?? [];
          _lastUpdateCAObjectif = data['last_update'] ?? '';
        });
      }
    } catch (e) {
      print('Erreur CA Objectif: $e');
      rethrow;
    }
  }

  Future<void> _loadCaSiteRayonData({bool forceRefresh = false}) async {
    try {
      String url = caSiteRayonBaseUrl;
      if (forceRefresh) url = _getNoCacheUrl(caSiteRayonBaseUrl);
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _caSiteRayonData = data['details'] ?? [];
          _totauxParMagasin = data['totaux_par_magasin'] ?? [];
          _lastUpdateSiteRayon = data['last_update'] ?? '';
        });
      }
    } catch (e) {
      print('Erreur CA Site Rayon: $e');
      rethrow;
    }
  }

  Future<void> _loadTraficClientData({bool forceRefresh = false}) async {
    try {
      String url = traficClientBaseUrl;
      if (forceRefresh) url = _getNoCacheUrl(traficClientBaseUrl);
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _traficClientData = data['data'] ?? [];
          _lastUpdateTrafic = data['last_update'] ?? '';
        });
      }
    } catch (e) {
      print('Erreur Trafic Client: $e');
      rethrow;
    }
  }

  String _getFormattedTimestamp() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  List<dynamic> _getFilteredCAData() {
    List<dynamic> filtered;
    if (_selectedFiltreCA == 'tous') {
      filtered = List.from(_caObjectifData);
    } else {
      filtered = _caObjectifData.where((item) {
        String magasin = item['magasin'] ?? '';
        if (_selectedFiltreCA == 'HY') return magasin.startsWith('HY');
        if (_selectedFiltreCA == 'UE') return magasin.startsWith('UE');
        return true;
      }).toList();
    }
    
    // Trier par CA réalisé décroissant
    filtered.sort((a, b) {
      double caA = (a['ca_realise'] ?? 0).toDouble();
      double caB = (b['ca_realise'] ?? 0).toDouble();
      return caB.compareTo(caA);
    });
    
    return filtered;
  }

  List<dynamic> _getFilteredTraficData() {
    if (_selectedFiltreTrafic == 'tous') return _traficClientData;
    return _traficClientData.where((item) {
      String magasin = item['magasin'] ?? '';
      if (_selectedFiltreTrafic == 'HY') return magasin.startsWith('HY');
      if (_selectedFiltreTrafic == 'UE') return magasin.startsWith('UE');
      return true;
    }).toList();
  }

  Map<String, double> _getCAForRayonBySiteWithFilter(String rayon) {
    Map<String, double> result = _caBySiteForRayon[rayon] ?? {};
    
    if (_selectedSiteFilter == 'tous') return result;
    
    return result.entries
        .where((entry) {
          if (_selectedSiteFilter == 'HY') return entry.key.startsWith('HY');
          if (_selectedSiteFilter == 'UE') return entry.key.startsWith('UE');
          return true;
        })
        .fold({}, (map, entry) {
          map[entry.key] = entry.value;
          return map;
        });
  }

  double _getObjectifForSite(String site) {
    for (var item in _caObjectifData) {
      if (item['magasin'] == site) {
        return (item['ca_objectif'] ?? 0).toDouble();
      }
    }
    return 0;
  }

  double _getRealiseForSite(String site) {
    for (var item in _caObjectifData) {
      if (item['magasin'] == site) {
        return (item['ca_realise'] ?? 0).toDouble();
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        backgroundColor: const Color(0xFF06616E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: (_selectedLevel == 'magasinDetail') 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
                tooltip: 'Retour',
              )
            : null,
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _reloadAllData,
          ),
        ],
        bottom: (_selectedLevel != 'magasinDetail')
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.assessment), text: 'CA'),
                  Tab(icon: Icon(Icons.people), text: 'Trafic'),
                  Tab(icon: Icon(Icons.timeline), text: 'Benchmark'),
                ],
              )
            : null,
      ),
      body: _isLoading && !_isRefreshing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _selectedLevel == 'magasinDetail'
                  ? _buildMagasinDetailView()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCAView(),
                        _buildTraficView(),
                        _buildBenchmarkView(),
                      ],
                    ),
    );
  }

  // ============================================
  // VUE DÉTAIL MAGASIN (RAYONS)
  // ============================================
  
  Widget _buildMagasinDetailView() {
    // Récupérer les infos du magasin
    dynamic magasinInfo;
    double realise = 0;
    double objectif = 0;
    double taux = 0;
    
    for (var item in _caObjectifData) {
      if (item['magasin'] == _selectedMagasinForDetail) {
        magasinInfo = item;
        realise = (item['ca_realise'] ?? 0).toDouble();
        objectif = (item['ca_objectif'] ?? 0).toDouble();
        taux = objectif > 0 ? (realise / objectif) * 100 : 0;
        break;
      }
    }
    
    bool isHyper = _selectedMagasinForDetail?.startsWith('HY') ?? false;
    
    return RefreshIndicator(
      onRefresh: _reloadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header du magasin
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF06616E), Color(0xFF0A8A9A)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMagasinForDetail ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isHyper ? 'HYPERMARCHÉ' : 'SUPERMARCHÉ',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: taux >= 100 ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${taux.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailStat('CA Réalisé', '${(realise / 1000).toStringAsFixed(0)}K DH'),
                      ),
                      Expanded(
                        child: _buildDetailStat('Objectif', '${(objectif / 1000).toStringAsFixed(0)}K DH'),
                      ),
                      Expanded(
                        child: _buildDetailStat('Écart', '${((realise - objectif) / 1000).toStringAsFixed(0)}K DH',
                          color: realise >= objectif ? Colors.greenAccent : Colors.redAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: taux / 100,
                      backgroundColor: Colors.white30,
                      color: taux >= 100 ? Colors.green : Colors.orange,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            _buildInfoCard('Source Rayons: $_lastUpdateSiteRayon', const Color(0xFF4CAF50)),
            const SizedBox(height: 12),
            
            const Text(
              '📊 DÉTAIL PAR RAYON',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Graphique à barres des rayons
            if (_magasinRayonsDetail.isNotEmpty) ...[
              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _magasinRayonsDetail.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.1,
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < _magasinRayonsDetail.length) {
                              String name = _magasinRayonsDetail[value.toInt()].key;
                              if (name.length > 12) name = '${name.substring(0, 10)}...';
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Transform.rotate(
                                  angle: -0.4,
                                  child: Text(name, style: const TextStyle(fontSize: 9)),
                                ),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 70,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Text('${(value / 1000).toStringAsFixed(0)}K', style: const TextStyle(fontSize: 10)),
                          reservedSize: 45,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(_magasinRayonsDetail.length, (index) {
                      final ca = _magasinRayonsDetail[index].value;
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: ca,
                            color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                            width: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }),
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final total = rod.toY;
                          final rayon = _magasinRayonsDetail[groupIndex].key;
                          return BarTooltipItem(
                            '$rayon\n${(total / 1000).toStringAsFixed(1)}K DH',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const Text(
              'Liste des rayons',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            if (_magasinRayonsDetail.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('Aucun rayon trouvé pour ce magasin')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _magasinRayonsDetail.length,
                itemBuilder: (context, index) {
                  String rayon = _magasinRayonsDetail[index].key;
                  double ca = _magasinRayonsDetail[index].value;
                  double pourcentage = (ca / realise) * 100;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isHyper ? const Color(0xFF06616E).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  rayon,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(ca / 1000).toStringAsFixed(0)}K DH',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                  Text(
                                    '${pourcentage.toStringAsFixed(1)}%',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pourcentage / 100,
                              backgroundColor: Colors.grey[200],
                              color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  // ============================================
  // VUE CA
  // ============================================
  
  Widget _buildCAView() {
    List<dynamic> filteredData = _getFilteredCAData();
    
    double totalRealise = 0;
    double totalObjectif = 0;
    for (var item in filteredData) {
      totalRealise += (item['ca_realise'] ?? 0).toDouble();
      totalObjectif += (item['ca_objectif'] ?? 0).toDouble();
    }
    double tauxGlobal = totalObjectif > 0 ? (totalRealise / totalObjectif) * 100 : 0;

    double hyRealise = 0, hyObjectif = 0, ueRealise = 0, ueObjectif = 0;
    for (var item in _caObjectifData) {
      String magasin = item['magasin'] ?? '';
      double realise = (item['ca_realise'] ?? 0).toDouble();
      double objectif = (item['ca_objectif'] ?? 0).toDouble();
      if (magasin.startsWith('HY')) {
        hyRealise += realise;
        hyObjectif += objectif;
      } else if (magasin.startsWith('UE')) {
        ueRealise += realise;
        ueObjectif += objectif;
      }
    }

    return RefreshIndicator(
      onRefresh: _reloadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard('Source: $_lastUpdateCAObjectif', const Color(0xFF2196F3)),
            const SizedBox(height: 8),
            _buildFilterRow(),
            const SizedBox(height: 8),
            _buildBUCardsRow(hyRealise, hyObjectif, ueRealise, ueObjectif),
            const SizedBox(height: 8),
            _buildGlobalCard(tauxGlobal, totalRealise, totalObjectif),
            const SizedBox(height: 12),
            const Text('Détail par Magasin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredData.length,
              itemBuilder: (context, index) => _buildMagasinCard(filteredData[index], index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.update, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 11, color: color), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('Filtre : ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
            const SizedBox(width: 4),
            _buildFilterChip('TOUS', 'tous', _selectedFiltreCA == 'tous'),
            const SizedBox(width: 4),
            _buildFilterChip('HYPER', 'HY', _selectedFiltreCA == 'HY'),
            const SizedBox(width: 4),
            _buildFilterChip('SUPER', 'UE', _selectedFiltreCA == 'UE'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFiltreCA = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF06616E),
      side: BorderSide(color: Colors.grey[300]!),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  Widget _buildBUCardsRow(double hyRealise, double hyObjectif, double ueRealise, double ueObjectif) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 8) / 2;
        return Row(
          children: [
            SizedBox(width: cardWidth, child: _buildBUCard('HYPER', hyRealise, hyObjectif, const Color(0xFF06616E))),
            const SizedBox(width: 8),
            SizedBox(width: cardWidth, child: _buildBUCard('SUPER', ueRealise, ueObjectif, const Color(0xFFF59E0B))),
          ],
        );
      },
    );
  }

  Widget _buildBUCard(String title, double realise, double objectif, Color color) {
    double taux = objectif > 0 ? (realise / objectif) * 100 : 0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          const SizedBox(height: 2),
          Text('${taux.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text('${(realise / 1000).toStringAsFixed(0)}K / ${(objectif / 1000).toStringAsFixed(0)}K',
            style: TextStyle(fontSize: 9, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalCard(double tauxGlobal, double totalRealise, double totalObjectif) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF06616E), Color(0xFF0A8A9A)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('Taux atteinte global', style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text('${tauxGlobal.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGlobalStat('CA Réalisé', '${(totalRealise / 1000).toStringAsFixed(0)}K'),
              _buildDivider(),
              _buildGlobalStat('Objectif', '${(totalObjectif / 1000).toStringAsFixed(0)}K'),
              _buildDivider(),
              _buildGlobalStat('Écart', '${((totalRealise - totalObjectif) / 1000).toStringAsFixed(0)}K',
                color: totalRealise >= totalObjectif ? Colors.greenAccent : Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 20, width: 1, color: Colors.white30);
  }

  Widget _buildMagasinCard(dynamic item, int index) {
    final realise = (item['ca_realise'] ?? 0).toDouble();
    final objectif = (item['ca_objectif'] ?? 0).toDouble();
    final ecart = (item['ecart'] ?? 0).toDouble();
    final taux = objectif > 0 ? (realise / objectif) * 100 : 0;
    final bool isHyper = item['magasin']?.startsWith('HY') ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _selectMagasinForDetail(item['magasin']),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: isHyper ? const Color(0xFF06616E).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item['magasin'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: taux >= 100 ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(10)),
                    child: Text('${taux.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildStatColumn('CA Réalisé', '${(realise / 1000).toStringAsFixed(0)}K'),
                  _buildStatColumn('Objectif', '${(objectif / 1000).toStringAsFixed(0)}K'),
                  _buildStatColumn('Écart', '${(ecart / 1000).toStringAsFixed(0)}K', color: ecart >= 0 ? Colors.green : Colors.red),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: realise / objectif,
                  backgroundColor: Colors.grey[200],
                  color: taux >= 100 ? Colors.green : Colors.orange,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ],
      ),
    );
  }

  // ============================================
  // VUE TRAFIC
  // ============================================
  
  Widget _buildTraficView() {
    List<dynamic> filteredData = _getFilteredTraficData();

    return RefreshIndicator(
      onRefresh: _reloadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard('Source Trafic: $_lastUpdateTrafic', const Color(0xFF9C27B0)),
            const SizedBox(height: 12),
            const Text('Évolution du Trafic (Aujourd\'hui vs S-1)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildTraficLineChart(filteredData),
            const SizedBox(height: 16),
            const Text('Détail par Magasin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredData.length,
              itemBuilder: (context, index) => _buildTraficCard(filteredData[index], index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTraficLineChart(List<dynamic> data) {
    if (data.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Aucune donnée de trafic disponible')),
      );
    }

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < data.length) {
                    String name = data[value.toInt()]['magasin'] ?? '';
                    if (name.length > 12) name = '${name.substring(0, 10)}...';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.4,
                        child: Text(name, style: const TextStyle(fontSize: 9)),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 60,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 10)),
                reservedSize: 40,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(data.length, (index) {
                return FlSpot(index.toDouble(), (data[index]['nb_clients_jour'] ?? 0).toDouble());
              }),
              isCurved: true,
              color: const Color(0xFF06616E),
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF06616E).withOpacity(0.1)),
            ),
            LineChartBarData(
              spots: List.generate(data.length, (index) {
                return FlSpot(index.toDouble(), (data[index]['nb_clients_semaine_1'] ?? 0).toDouble());
              }),
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toInt()} clients',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTraficCard(dynamic item, int index) {
    final jour = (item['nb_clients_jour'] ?? 0) as int;
    final s1 = (item['nb_clients_semaine_1'] ?? 0) as int;
    final evolution = s1 > 0 ? ((jour - s1) / s1) * 100 : 0.0;
    final bool isHyper = item['magasin']?.startsWith('HY') ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isHyper ? const Color(0xFF06616E).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item['magasin'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: evolution >= 0 ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text('${evolution >= 0 ? "+" : ""}${evolution.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildTraficStat('Aujourd\'hui', '$jour'),
                _buildTraficStat('S-1', '$s1'),
                _buildTraficStat('Évolution', '${evolution.toStringAsFixed(0)}%', color: evolution >= 0 ? Colors.green : Colors.red),
              ],
            ),
            const SizedBox(height: 8),
            _buildSparkline(jour, s1),
          ],
        ),
      ),
    );
  }

  Widget _buildSparkline(int jour, int s1) {
    return Container(
      height: 40,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(0, s1.toDouble()),
                FlSpot(1, jour.toDouble()),
              ],
              isCurved: true,
              color: const Color(0xFF06616E),
              barWidth: 2,
              dotData: FlDotData(show: true),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
          minX: 0,
          maxX: 1,
          minY: 0,
          maxY: [jour, s1].reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
        ),
      ),
    );
  }

  Widget _buildTraficStat(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  // ============================================
  // VUE BENCHMARK - HIÉRARCHIE COMPLÈTE
  // ============================================
  
  Widget _buildBenchmarkView() {
    if (_selectedLevel == null) {
      _resetToDepartements();
    }
    
    if (_selectedLevel == 'departement') {
      return _buildDepartementView();
    } else if (_selectedLevel == 'rayon' && _selectedDepartement != null) {
      return _buildRayonViewForDepartement(_selectedDepartement!);
    } else if (_selectedLevel == 'site' && _selectedRayon != null) {
      return _buildSiteViewForRayon(_selectedRayon!);
    }
    
    return _buildDepartementView();
  }

  // Vue 1: Liste des départements
  Widget _buildDepartementView() {
    List<MapEntry<String, double>> entries = _caByDepartement.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    double totalGeneral = entries.fold(0.0, (sum, e) => sum + e.value);
    
    return RefreshIndicator(
      onRefresh: _reloadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard('Source Rayons: $_lastUpdateSiteRayon', const Color(0xFF4CAF50)),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF06616E), Color(0xFF0A8A9A)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    '📊 PERFORMANCE PAR DÉPARTEMENT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total général: ${(totalGeneral / 1000).toStringAsFixed(0)}K DH',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                String departement = entries[index].key;
                double ca = entries[index].value;
                double pourcentage = totalGeneral > 0 ? (ca / totalGeneral) * 100 : 0;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectDepartement(departement),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06616E).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF06616E),
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
                                      departement,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_departementRayons[departement]?.length ?? 0} rayons',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(ca / 1000).toStringAsFixed(0)}K DH',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF06616E),
                                    ),
                                  ),
                                  Text(
                                    '${pourcentage.toStringAsFixed(1)}%',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pourcentage / 100,
                              backgroundColor: Colors.grey[200],
                              color: const Color(0xFF06616E),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Vue 2: Rayons d'un département
  Widget _buildRayonViewForDepartement(String departement) {
    Map<String, double> rayons = _caByRayonForDepartement[departement] ?? {};
    List<MapEntry<String, double>> entries = rayons.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    double totalDepartement = entries.fold(0.0, (sum, e) => sum + e.value);
    
    return RefreshIndicator(
      onRefresh: _reloadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBack,
                  tooltip: 'Retour aux départements',
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF06616E), Color(0xFF0A8A9A)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Département',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          departement,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${(totalDepartement / 1000).toStringAsFixed(0)}K DH',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoCard('Source Rayons: $_lastUpdateSiteRayon', const Color(0xFF4CAF50)),
            const SizedBox(height: 12),
            
            const Text(
              'Rayons',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                String rayon = entries[index].key;
                double ca = entries[index].value;
                double pourcentage = totalDepartement > 0 ? (ca / totalDepartement) * 100 : 0;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectRayon(rayon),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  rayon,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(ca / 1000).toStringAsFixed(0)}K DH',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                  Text(
                                    '${pourcentage.toStringAsFixed(1)}%',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pourcentage / 100,
                              backgroundColor: Colors.grey[200],
                              color: const Color(0xFFF59E0B),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Vue 3: Sites pour un rayon
  Widget _buildSiteViewForRayon(String rayon) {
    Map<String, double> sites = _getCAForRayonBySiteWithFilter(rayon);
    List<MapEntry<String, double>> entries = sites.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    double totalRayon = entries.fold(0.0, (sum, e) => sum + e.value);
    String departement = _getDepartementForRayon(rayon);
    
    return RefreshIndicator(
      onRefresh: _reloadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBack,
                  tooltip: 'Retour aux rayons',
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF06616E), Color(0xFF0A8A9A)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (departement.isNotEmpty)
                          Text(
                            departement,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        Text(
                          rayon,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${(totalRayon / 1000).toStringAsFixed(0)}K DH',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoCard('Source Rayons: $_lastUpdateSiteRayon', const Color(0xFF4CAF50)),
            const SizedBox(height: 12),
            
            // Filtres sites
            _buildFilterSiteChips(),
            const SizedBox(height: 12),
            
            // Graphique
            if (entries.isNotEmpty) ...[
              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.1,
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < entries.length) {
                              String name = entries[value.toInt()].key;
                              if (name.length > 12) name = '${name.substring(0, 10)}...';
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Transform.rotate(
                                  angle: -0.4,
                                  child: Text(name, style: const TextStyle(fontSize: 9)),
                                ),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 70,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Text('${(value / 1000).toStringAsFixed(0)}K', style: const TextStyle(fontSize: 10)),
                          reservedSize: 45,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(entries.length, (index) {
                      final site = entries[index].key;
                      final ca = entries[index].value;
                      bool isHyper = site.startsWith('HY');
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: ca,
                            color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                            width: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }),
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final total = rod.toY;
                          final site = entries[groupIndex].key;
                          return BarTooltipItem(
                            '$site\n${(total / 1000).toStringAsFixed(1)}K DH',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const Text(
              'Détail par site',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            if (entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('Aucun site trouvé pour ce filtre')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  String site = entries[index].key;
                  double ca = entries[index].value;
                  double pourcentage = totalRayon > 0 ? (ca / totalRayon) * 100 : 0;
                  bool isHyper = site.startsWith('HY');
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isHyper ? const Color(0xFF06616E).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  site,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(ca / 1000).toStringAsFixed(0)}K DH',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF06616E),
                                    ),
                                  ),
                                  Text(
                                    '${pourcentage.toStringAsFixed(1)}%',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pourcentage / 100,
                              backgroundColor: Colors.grey[200],
                              color: const Color(0xFF06616E),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSiteChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Filtrer par site : ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
          const SizedBox(width: 4),
          _buildFilterSiteChip('TOUS', 'tous'),
          const SizedBox(width: 4),
          _buildFilterSiteChip('HYPER', 'HY'),
          const SizedBox(width: 4),
          _buildFilterSiteChip('SUPER', 'UE'),
        ],
      ),
    );
  }

  Widget _buildFilterSiteChip(String label, String value) {
    bool isSelected = _selectedSiteFilter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedSiteFilter = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF06616E),
      side: BorderSide(color: Colors.grey[300]!),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error ?? 'Erreur inconnue', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _reloadAllData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06616E)),
          ),
        ],
      ),
    );
  }
}