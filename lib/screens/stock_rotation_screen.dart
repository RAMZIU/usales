import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class StockRotationScreen extends StatefulWidget { 
  const StockRotationScreen({super.key});  // ← CORRIGÉ
  
  @override
  State<StockRotationScreen> createState() => _StockRotationScreenState();
}

class _StockRotationScreenState extends State<StockRotationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<Map<String, dynamic>> _allArticles = [];
  List<Map<String, dynamic>> _filteredArticles = [];
  Map<String, dynamic>? _selectedArticle;
  List<Map<String, dynamic>> _articleBySite = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  
  // Statistiques globales (ajout du 30 jours)
  double _totalQteVendue7j = 0;
  double _totalQteVendue15j = 0;
  double _totalQteVendue30j = 0;
  double _totalMontantVente7j = 0;
  double _totalMontantVente15j = 0;
  double _totalMontantVente30j = 0;
  
  // Nouvelle URL
  static const String stockDataUrl = 'https://gist.githubusercontent.com/RAMZIU/2ad2df3cc59189c05ad74345c8b281a6/raw/ventes_periodes.csv';

  @override
  void initState() {
    super.initState();
    _loadStockData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredArticles = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _filteredArticles = _allArticles.where((article) {
        final articleName = (article['article'] ?? '').toLowerCase();
        final ean = (article['ean'] ?? '').toLowerCase();
        return articleName.contains(query) || ean.contains(query);
      }).toList();
      
      if (_filteredArticles.length > 20) {
        _filteredArticles = _filteredArticles.sublist(0, 20);
      }
    });
  }

  Future<void> _loadStockData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final response = await http.get(Uri.parse(stockDataUrl));
      
      if (response.statusCode == 200) {
        _parseCSVData(response.body);
        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _parseCSVData(String csvContent) {
    final lines = csvContent.split('\n');
    if (lines.isEmpty) return;
    
    final headers = lines[0].split(';');
    
    final List<Map<String, dynamic>> articles = [];
    
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      
      final values = lines[i].split(';');
      if (values.length < headers.length) continue;
      
      final article = <String, dynamic>{};
      for (int j = 0; j < headers.length; j++) {
        String key = headers[j].trim();
        String value = values[j].trim();
        
        switch (key) {
          case 'id_site':
            article['code_site'] = int.tryParse(value) ?? 0;
            article['id_site'] = int.tryParse(value) ?? 0;
            break;
          case 'site':
            article['site'] = value;
            break;
          case 'code_article':
            article['code_article'] = value;
            break;
          case 'article':
            article['article'] = value.replaceAll('"', '').trim();
            break;
          case 'ean':
            article['ean'] = value;
            break;
          case 'qte_stock':
            article['qte_stock'] = double.tryParse(value) ?? 0.0;
            break;
          case 'qte_vendue_7jr':
            article['qte_vendue_7jr'] = double.tryParse(value) ?? 0.0;
            break;
          case 'qte_vendue_15jr':
            article['qte_vendue_15jr'] = double.tryParse(value) ?? 0.0;
            break;
          case 'qte_vendue_30jr':
            article['qte_vendue_30jr'] = double.tryParse(value) ?? 0.0;
            break;
          case 'montant_7jr':
            article['montant_vente_7jr'] = double.tryParse(value) ?? 0.0;
            break;
          case 'montant_15jr':
            article['montant_vente_15jr'] = double.tryParse(value) ?? 0.0;
            break;
          case 'montant_30jr':
            article['montant_vente_30jr'] = double.tryParse(value) ?? 0.0;
            break;
          case 'taux_rotation':
            article['taux_rotation'] = double.tryParse(value) ?? 0.0;
            break;
          default:
            article[key] = value;
        }
      }
      articles.add(article);
    }
    
    setState(() {
      _allArticles = articles;
    });
  }
  
  void _selectArticle(Map<String, dynamic> article) {
    setState(() {
      _selectedArticle = article;
      _articleBySite = _allArticles
          .where((a) => a['article'] == article['article'])
          .toList();
      
      // Calculer les totaux
      _totalQteVendue7j = _articleBySite.fold<double>(0.0, (sum, item) => sum + (item['qte_vendue_7jr'] ?? 0.0));
      _totalQteVendue15j = _articleBySite.fold<double>(0.0, (sum, item) => sum + (item['qte_vendue_15jr'] ?? 0.0));
      _totalQteVendue30j = _articleBySite.fold<double>(0.0, (sum, item) => sum + (item['qte_vendue_30jr'] ?? 0.0));
      _totalMontantVente7j = _articleBySite.fold<double>(0.0, (sum, item) => sum + (item['montant_vente_7jr'] ?? 0.0));
      _totalMontantVente15j = _articleBySite.fold<double>(0.0, (sum, item) => sum + (item['montant_vente_15jr'] ?? 0.0));
      _totalMontantVente30j = _articleBySite.fold<double>(0.0, (sum, item) => sum + (item['montant_vente_30jr'] ?? 0.0));
      
      _searchController.clear();
      _filteredArticles = [];
      _isSearching = false;
      _searchFocusNode.unfocus();
    });
  }
  
  void _clearSelection() {
    setState(() {
      _selectedArticle = null;
      _articleBySite = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotation des Articles'),
        backgroundColor: const Color(0xFF06616E),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedArticle != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
              tooltip: 'Fermer',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _selectedArticle == null
                  ? _buildSearchView()
                  : _buildArticleDetailView(),
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
            onPressed: _loadStockData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06616E)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 4,
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Rechercher un article (nom ou EAN)...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF06616E)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _filteredArticles = [];
                          _isSearching = false;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF06616E), width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ),
        Expanded(
          child: _isSearching && _filteredArticles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Aucun article trouvé pour\n"${_searchController.text}"',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredArticles.length,
                  itemBuilder: (context, index) {
                    final article = _filteredArticles[index];
                    return _buildArticleSuggestionCard(article);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildArticleSuggestionCard(Map<String, dynamic> article) {
    final qteVendue = (article['qte_vendue_30jr'] ?? 0.0) as double;
    final montantVente = (article['montant_vente_30jr'] ?? 0.0) as double;
    final tauxRotation = (article['taux_rotation'] ?? 0.0) as double;
    final stock = (article['qte_stock'] ?? 0.0) as double;
    
    Color getTauxColor(double taux) {
      if (taux < 0) return Colors.red;
      if (taux > 10) return Colors.green;
      if (taux > 5) return Colors.orange;
      return Colors.blue;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => _selectArticle(article),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      article['article'] ?? 'Sans nom',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (stock < 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '⚠️ Stock négatif',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'EAN: ${article['ean'] ?? 'N/A'}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatBadge(
                    'Ventes 30j',
                    '${qteVendue.round()}',
                    Icons.shopping_cart,
                    const Color(0xFF06616E),
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    'CA 30j',
                    '${(montantVente / 1000).toStringAsFixed(1)}K DH',
                    Icons.attach_money,
                    Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    'Rotation',
                    tauxRotation < 0 ? 'N/A' : '${tauxRotation.toStringAsFixed(1)}x',
                    Icons.autorenew,
                    getTauxColor(tauxRotation),
                  ),
                ],
              ),
              if (qteVendue > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (qteVendue / 1000).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      color: const Color(0xFF06616E),
                      minHeight: 3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatBadge(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                  Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildArticleDetailView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildArticleHeader(),
          const SizedBox(height: 20),
          _buildSummaryCards(),
          const SizedBox(height: 20),
          _buildSalesChart(),
          const SizedBox(height: 20),
          _buildSiteDetailList(),
        ],
      ),
    );
  }
  
  Widget _buildArticleHeader() {
    final stock = (_selectedArticle?['qte_stock'] ?? 0.0) as double;
    final tauxRotation = (_selectedArticle?['taux_rotation'] ?? 0.0) as double;
    final alerteStock = stock < 0 ? 'Stock négatif' : (stock < 10 ? 'Stock faible' : 'Normal');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06616E), Color(0xFF0A8A9A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedArticle?['article'] ?? 'Sans nom',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'EAN: ${_selectedArticle?['ean'] ?? 'N/A'}',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderStat('Stock actuel', stock.toStringAsFixed(0)),
              _buildHeaderStat('Taux rotation', 
                  tauxRotation > 0 ? '${tauxRotation.toStringAsFixed(1)}x' : 'N/A'),
              _buildHeaderStat('Alerte', alerteStock),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Ventes 30 jours',
            '${_totalQteVendue30j.round()}',
            '${(_totalMontantVente30j / 1000).toStringAsFixed(1)}K DH',
            Icons.calendar_month,
            const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Ventes 15 jours',
            '${_totalQteVendue15j.round()}',
            '${(_totalMontantVente15j / 1000).toStringAsFixed(1)}K DH',
            Icons.date_range,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Ventes 7 jours',
            '${_totalQteVendue7j.round()}',
            '${(_totalMontantVente7j / 1000).toStringAsFixed(1)}K DH',
            Icons.today,
            const Color(0xFF06616E),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard(String title, String qte, String montant, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 9, color: Colors.grey[700])),
          const SizedBox(height: 2),
          Text(qte, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(montant, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ],
      ),
    );
  }
  
  Widget _buildSalesChart() {
    if (_articleBySite.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Aucune donnée de vente par site')),
      );
    }
    
    List<Map<String, dynamic>> sortedData = List.from(_articleBySite);
    sortedData.sort((a, b) => ((b['qte_vendue_30jr'] ?? 0.0) as double).compareTo((a['qte_vendue_30jr'] ?? 0.0) as double));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ventes par site (comparaison 7j/15j/30j)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 350,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: sortedData.map((e) => (e['qte_vendue_30jr'] ?? 0.0) as double).reduce((a, b) => a > b ? a : b) * 1.1,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < sortedData.length) {
                        String site = sortedData[value.toInt()]['site'] ?? '';
                        if (site.length > 12) site = '${site.substring(0, 10)}...';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Transform.rotate(
                            angle: -0.4,
                            child: Text(site, style: const TextStyle(fontSize: 8)),
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
                    getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 9)),
                    reservedSize: 40,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(sortedData.length, (index) {
                final qte30j = (sortedData[index]['qte_vendue_30jr'] ?? 0.0) as double;
                final qte15j = (sortedData[index]['qte_vendue_15jr'] ?? 0.0) as double;
                final qte7j = (sortedData[index]['qte_vendue_7jr'] ?? 0.0) as double;
                
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: qte7j,
                      color: const Color(0xFF06616E),
                      width: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: qte15j,
                      color: Colors.orange,
                      width: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: qte30j,
                      color: const Color(0xFF8B5CF6),
                      width: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }),
              gridData: FlGridData(show: true, drawVerticalLine: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildChartLegend('7 jours', const Color(0xFF06616E)),
            _buildChartLegend('15 jours', Colors.orange),
            _buildChartLegend('30 jours', const Color(0xFF8B5CF6)),
          ],
        ),
      ],
    );
  }
  
  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
  
  Widget _buildSiteDetailList() {
    if (_articleBySite.isEmpty) return const SizedBox();
    
    List<Map<String, dynamic>> sortedData = List.from(_articleBySite);
    sortedData.sort((a, b) => ((b['qte_vendue_30jr'] ?? 0.0) as double).compareTo((a['qte_vendue_30jr'] ?? 0.0) as double));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Détail par site',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedData.length,
          itemBuilder: (context, index) {
            final item = sortedData[index];
            final qte7j = (item['qte_vendue_7jr'] ?? 0.0) as double;
            final qte15j = (item['qte_vendue_15jr'] ?? 0.0) as double;
            final qte30j = (item['qte_vendue_30jr'] ?? 0.0) as double;
            final montant7j = (item['montant_vente_7jr'] ?? 0.0) as double;
            final montant15j = (item['montant_vente_15jr'] ?? 0.0) as double;
            final montant30j = (item['montant_vente_30jr'] ?? 0.0) as double;
            final stock = (item['qte_stock'] ?? 0.0) as double;
            final tauxRotation = (item['taux_rotation'] ?? 0.0) as double;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
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
                          child: Text(
                            item['site'] ?? 'Site inconnu',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (stock < 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Stock négatif',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPeriodRow('7 jours', qte7j, montant7j, Icons.today, const Color(0xFF06616E)),
                    const SizedBox(height: 6),
                    _buildPeriodRow('15 jours', qte15j, montant15j, Icons.date_range, Colors.orange),
                    const SizedBox(height: 6),
                    _buildPeriodRow('30 jours', qte30j, montant30j, Icons.calendar_month, const Color(0xFF8B5CF6)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSiteStat('Stock', stock.toStringAsFixed(0), Icons.inventory, Colors.blue),
                        _buildSiteStat('Rotation', tauxRotation > 0 ? '${tauxRotation.toStringAsFixed(1)}x' : 'N/A', Icons.autorenew, Colors.orange),
                      ],
                    ),
                    if (qte30j > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (qte30j / _totalQteVendue30j).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[200],
                            color: const Color(0xFF8B5CF6),
                            minHeight: 4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildPeriodRow(String period, double qte, double montant, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 65,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 2),
              Text(period, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Qté: ${qte.round()} | CA: ${(montant / 1000).toStringAsFixed(0)}K DH',
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSiteStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}