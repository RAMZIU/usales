import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class StockNegatifScreen extends StatefulWidget {
  const StockNegatifScreen({super.key});

  @override
  State<StockNegatifScreen> createState() => _StockNegatifScreenState();
}

class _StockNegatifScreenState extends State<StockNegatifScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  
  // Données stock_negatif.json
  Map<String, dynamic>? _data;
  List<dynamic> _details = [];
  List<dynamic> _totauxParSite = [];
  int _totalArticles = 0;
  int _totalSites = 0;
  int _totalRayons = 0;
  String _lastUpdate = '';
  
  // Données negatif_dep.json (articles uniques par département)
  Map<String, dynamic>? _dataDep;
  List<dynamic> _totauxParDepartement = [];
  int _totalArticlesUniques = 0;
  int _totalDepartements = 0;
  String _lastUpdateDep = '';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // URLs des Gists
  static const String gistUrlStock =
      'https://gist.githubusercontent.com/RAMZIU/75296b3ac07aa44061eb5fbb793a860f/raw/stock_negatif.json';
  static const String gistUrlDep =
      'https://gist.githubusercontent.com/RAMZIU/a0685c3897ddcc8996252c5134aba25d/raw/negatif_dep.json';

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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Charger les deux fichiers en parallèle
      final results = await Future.wait([
        http.get(Uri.parse(gistUrlStock)),
        http.get(Uri.parse(gistUrlDep)),
      ]);

      // Traiter stock_negatif.json
      if (results[0].statusCode == 200) {
        _data = jsonDecode(results[0].body);
        _details = _data?['details'] ?? [];
        _totauxParSite = _data?['totaux_par_site'] ?? [];
        _totalArticles = _data?['total_articles_stock_negatif'] ?? 0;
        _totalSites = _data?['total_sites_touches'] ?? 0;
        _totalRayons = _details.length;
        _lastUpdate = _data?['last_update'] ?? '';
      } else {
        throw Exception('Erreur HTTP stock: ${results[0].statusCode}');
      }

      // Traiter negatif_dep.json
      if (results[1].statusCode == 200) {
        _dataDep = jsonDecode(results[1].body);
        _totauxParDepartement = _dataDep?['data'] ?? [];
        _totalArticlesUniques = _dataDep?['total_articles_uniques_stock_negatif'] ?? 0;
        _totalDepartements = _dataDep?['total_departements'] ?? 0;
        _lastUpdateDep = _dataDep?['last_update'] ?? '';
      } else {
        throw Exception('Erreur HTTP départements: ${results[1].statusCode}');
      }

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

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final results = await Future.wait([
        http.get(Uri.parse(gistUrlStock)),
        http.get(Uri.parse(gistUrlDep)),
      ]);

      if (results[0].statusCode == 200) {
        _data = jsonDecode(results[0].body);
        _details = _data?['details'] ?? [];
        _totauxParSite = _data?['totaux_par_site'] ?? [];
        _totalArticles = _data?['total_articles_stock_negatif'] ?? 0;
        _totalSites = _data?['total_sites_touches'] ?? 0;
        _totalRayons = _details.length;
        _lastUpdate = _data?['last_update'] ?? '';
      }

      if (results[1].statusCode == 200) {
        _dataDep = jsonDecode(results[1].body);
        _totauxParDepartement = _dataDep?['data'] ?? [];
        _totalArticlesUniques = _dataDep?['total_articles_uniques_stock_negatif'] ?? 0;
        _totalDepartements = _dataDep?['total_departements'] ?? 0;
        _lastUpdateDep = _dataDep?['last_update'] ?? '';
      }

      setState(() {
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isRefreshing = false;
      });
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  void _showDepartementDetails(String deptName, int codeDept) {
    // Filtrer les détails par département
    final deptDetails = _details.where((item) => item['departement'] == deptName).toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.category, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deptName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Code: $codeDept',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Détail par site et rayon',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: deptDetails.length,
                  itemBuilder: (context, index) {
                    final item = deptDetails[index];
                    return _buildRayonDetailCard(item, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSiteDetails(String siteName) {
    final siteDetails = _details.where((item) => item['site'] == siteName).toList();
    final totalForSite = _totauxParSite.firstWhere(
      (item) => item['site'] == siteName,
      orElse: () => {'total_articles_stock_negatif': 0},
    )['total_articles_stock_negatif'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          siteName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$totalForSite articles en stock négatif',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Détail par rayon',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: siteDetails.length,
                  itemBuilder: (context, index) {
                    final item = siteDetails[index];
                    return _buildRayonDetailCard(item, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRayonDetailCard(Map<String, dynamic> item, int index) {
    final rayon = item['rayon'] ?? 'Rayon inconnu';
    final codeRayon = item['code_rayon'] ?? '';
    final nbArticles = item['nb_articles_stock_negatif'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
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
                    rayon,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Code: $codeRayon',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$nbArticles',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Négatif'),
        backgroundColor: const Color(0xFF06616E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des données...'),
                ],
              ),
            )
          : _error != null
              ? _buildErrorWidget()
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Carte récapitulative
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildSummaryCard(),
                        ),
                        const SizedBox(height: 20),

                        // Dernière mise à jour
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.update,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Mise à jour: ${_formatDate(_lastUpdate)}',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Graphique à barres des DÉPARTEMENTS (ARTICLES UNIQUES)
                        if (_totauxParDepartement.isNotEmpty) ...[
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 14, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '⚠️ Chaque article est compté UNE SEULE FOIS par département (même s\'il apparaît dans plusieurs magasins)',
                                          style: TextStyle(fontSize: 10, color: Colors.orange),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '📊 Classement par département (articles uniques)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 320,
                                  child: _buildDepartementBarChart(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Liste des départements avec détails
                        if (_totauxParDepartement.isNotEmpty) ...[
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🏷️ Départements concernés',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _totauxParDepartement.length,
                                  itemBuilder: (context, index) {
                                    final item = _totauxParDepartement[index];
                                    return _buildDepartementCard(item, index);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Graphique à barres des sites
                        if (_totauxParSite.isNotEmpty) ...[
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '📊 Classement par site',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 320,
                                  child: _buildBarChart(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Liste des sites avec détails
                        if (_totauxParSite.isNotEmpty) ...[
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🏪 Sites concernés',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _totauxParSite.length,
                                  itemBuilder: (context, index) {
                                    final item = _totauxParSite[index];
                                    return _buildSiteCard(item, index);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDepartementBarChart() {
    final displayData = _totauxParDepartement.length > 8
        ? _totauxParDepartement.sublist(0, 8)
        : List.from(_totauxParDepartement);

    final maxValue = displayData
            .map((e) => (e['nb_articles_uniques_stock_negatif'] ?? 0) as int)
            .reduce((a, b) => a > b ? a : b)
            .toDouble() *
        1.1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < displayData.length) {
                  String dept = displayData[value.toInt()]['departement'] ?? '';
                  if (dept.length > 12) dept = '${dept.substring(0, 10)}...';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Transform.rotate(
                      angle: -0.4,
                      child: Text(
                        dept,
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
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
              getTitlesWidget: (value, meta) =>
                  Text('${value.toInt()}', style: const TextStyle(fontSize: 10)),
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(displayData.length, (index) {
          final total = (displayData[index]['nb_articles_uniques_stock_negatif'] ?? 0)
              .toDouble();

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: total,
                color: const Color(0xFFEF4444),
                width: 24,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
            showingTooltipIndicators: [],
          );
        }),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final total = rod.toY.toInt();
              final dept = displayData[groupIndex]['departement'] ?? '';
              return BarTooltipItem(
                '$dept\n$total articles uniques',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final displayData = _totauxParSite.length > 8
        ? _totauxParSite.sublist(0, 8)
        : List.from(_totauxParSite);

    final maxValue = displayData
            .map((e) => (e['total_articles_stock_negatif'] ?? 0) as int)
            .reduce((a, b) => a > b ? a : b)
            .toDouble() *
        1.1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < displayData.length) {
                  String site = displayData[value.toInt()]['site'] ?? '';
                  if (site.length > 12) site = '${site.substring(0, 10)}...';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Transform.rotate(
                      angle: -0.4,
                      child: Text(
                        site,
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
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
              getTitlesWidget: (value, meta) =>
                  Text('${value.toInt()}', style: const TextStyle(fontSize: 10)),
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(displayData.length, (index) {
          final total = (displayData[index]['total_articles_stock_negatif'] ?? 0)
              .toDouble();
          final site = displayData[index]['site'] ?? '';
          final isHyper = site.startsWith('HY');

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: total,
                color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                width: 24,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
            showingTooltipIndicators: [],
          );
        }),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final total = rod.toY.toInt();
              final site = displayData[groupIndex]['site'] ?? '';
              return BarTooltipItem(
                '$site\n$total articles',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06616E), Color(0xFF0A8A9A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.inventory,
                label: 'Articles négatifs',
                value: _totalArticles.toString(),
                color: Colors.white,
              ),
              _buildSummaryItem(
                icon: Icons.category,
                label: 'Articles uniques',
                value: _totalArticlesUniques.toString(),
                color: Colors.white,
              ),
              _buildSummaryItem(
                icon: Icons.store,
                label: 'Sites',
                value: _totalSites.toString(),
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _totalArticles > 0 ? 1.0 : 0,
            backgroundColor: Colors.white30,
            color: Colors.red,
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          const Text(
            '⚠️ Alerte stock négatif',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildDepartementCard(Map<String, dynamic> item, int index) {
    final total = item['nb_articles_uniques_stock_negatif'] ?? 0;
    final departement = item['departement'] ?? 'Département inconnu';
    final codeDepartement = item['code_departement'] ?? '';
    final percentage = _totalArticlesUniques > 0 ? (total / _totalArticlesUniques) * 100 : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDepartementDetails(departement, codeDepartement),
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
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
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
                        Text(
                          'Code: $codeDepartement',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$total articles',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[200],
                  color: Colors.red,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteCard(Map<String, dynamic> item, int index) {
    final total = item['total_articles_stock_negatif'] ?? 0;
    final site = item['site'] ?? 'Site inconnu';
    final isHyper = site.startsWith('HY');
    final percentage = _totalArticles > 0 ? (total / _totalArticles) * 100 : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSiteDetails(site),
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
                      color: (isHyper
                              ? const Color(0xFF06616E)
                              : const Color(0xFFF59E0B))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isHyper
                              ? const Color(0xFF06616E)
                              : const Color(0xFFF59E0B),
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
                          site,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isHyper
                                ? const Color(0xFF06616E)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${percentage.toStringAsFixed(1)}% du total',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$total articles',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[200],
                  color: Colors.red,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Erreur inconnue',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06616E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}