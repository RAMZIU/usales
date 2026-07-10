import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CroissanceScreen extends StatefulWidget {
  const CroissanceScreen({super.key});

  @override
  State<CroissanceScreen> createState() => _CroissanceScreenState();
}

class _CroissanceScreenState extends State<CroissanceScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<dynamic> _croissanceData = [];
  String? _error;
  String _lastUpdate = '';
  String _period = '';

  // Votre Gist ID pour la croissance
  static const String croissanceUrl = 'https://gist.githubusercontent.com/RAMZIU/79ecaa9b1f55eb0402ec925fa21cf359/raw/croissance_produits_u.json';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Nouvelle méthode pour le refresh forcé
  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(croissanceUrl));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        
        setState(() {
          _croissanceData = data['data'] ?? [];
          _lastUpdate = data['last_update'] ?? '';
          _period = data['period'] ?? '15 derniers jours';
          _isRefreshing = false;
          _isLoading = false;
          _error = null;
        });
      } else {
        throw Exception('Erreur de chargement');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isRefreshing = false;
        _isLoading = false;
      });
      _loadMockData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(croissanceUrl));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        
        setState(() {
          _croissanceData = data['data'] ?? [];
          _lastUpdate = data['last_update'] ?? '';
          _period = data['period'] ?? '15 derniers jours';
          _isLoading = false;
        });
      } else {
        throw Exception('Erreur de chargement');
      }
    } catch (e) {
      _loadMockData();
    }
  }

  void _loadMockData() {
    // Données mockées en cas d'erreur de chargement
    final mockData = [
      {"date": "2026-05-15", "magasin": "HY Agadir", "ca": 9696.61}
    ];
    
    setState(() {
      _croissanceData = mockData;
      _period = "15 derniers jours";
      _lastUpdate = DateTime.now().toString();
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📈 Croissance Produits U',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF8B5CF6),
        elevation: 0,
        centerTitle: true,
        actions: [
          // Bouton refresh
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8B5CF6),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF8B5CF6),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info période et dernière mise à jour
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _period,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (_lastUpdate.isNotEmpty)
                      Text(
                        'Màj: ${_lastUpdate.substring(0, 10)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              if (_isLoading && !_isRefreshing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  ),
                )
              else if (_error != null)
                _buildErrorWidget()
              else if (_croissanceData.isEmpty)
                const Center(child: Text('Aucune donnée disponible'))
              else
                _buildCroissanceList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCroissanceList() {
    // Grouper les données par magasin
    Map<String, List<Map<String, dynamic>>> dataByStore = {};
    
    for (var item in _croissanceData) {
      String store = item['magasin'];
      if (!dataByStore.containsKey(store)) {
        dataByStore[store] = [];
      }
      dataByStore[store]!.add({
        'date': item['date'],
        'ca': item['ca'].toDouble(),
      });
    }
    
    // Trier les dates pour chaque magasin
    dataByStore.forEach((store, items) {
      items.sort((a, b) => a['date'].compareTo(b['date']));
    });
    
    // Convertir en liste et trier par CA total
    List<MapEntry<String, List<Map<String, dynamic>>>> storeList = 
        dataByStore.entries.toList();
    
    // Trier par CA total décroissant
    storeList.sort((a, b) {
      double totalA = a.value.fold(0, (sum, item) => sum + item['ca']);
      double totalB = b.value.fold(0, (sum, item) => sum + item['ca']);
      return totalB.compareTo(totalA);
    });
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: storeList.length,
      itemBuilder: (context, index) {
        final store = storeList[index];
        final storeName = store.key;
        final data = store.value;
        
        // Calculer l'évolution
        double firstCA = data.first['ca'];
        double lastCA = data.last['ca'];
        double evolution = firstCA > 0 ? ((lastCA - firstCA) / firstCA) * 100 : 0;
        double totalCA = data.fold(0, (sum, item) => sum + item['ca']);
        
        return _buildStoreCard(
          rank: index + 1,
          storeName: storeName,
          data: data,
          evolution: evolution,
          totalCA: totalCA,
        );
      },
    );
  }

  Widget _buildStoreCard({
    required int rank,
    required String storeName,
    required List<Map<String, dynamic>> data,
    required double evolution,
    required double totalCA,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: _buildRankBadge(rank),
          title: Text(
            storeName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Row(
            children: [
              Icon(
                evolution >= 0 ? Icons.trending_up : Icons.trending_down,
                size: 14,
                color: evolution >= 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                evolution >= 0 ? '+${evolution.toStringAsFixed(1)}%' : '${evolution.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: evolution >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.attach_money, size: 12, color: Colors.grey),
              const SizedBox(width: 2),
              Text(
                'Total: ${(totalCA / 1000).toStringAsFixed(0)}K DH',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(data.last['ca'] / 1000).toStringAsFixed(0)}K DH',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              Text(
                'Dernier jour',
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Évolution quotidienne',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.length,
                    itemBuilder: (context, idx) {
                      final item = data[idx];
                      final date = item['date'];
                      final ca = item['ca'];
                      final previousCA = idx > 0 ? data[idx - 1]['ca'] : ca;
                      final dailyEvolution = previousCA > 0 ? ((ca - previousCA) / previousCA) * 100 : 0;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                date.substring(5),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: ca / data.map((e) => e['ca']).reduce((a, b) => a > b ? a : b),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${(ca / 1000).toStringAsFixed(1)}K DH',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8B5CF6),
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                dailyEvolution == 0 
                                    ? ''
                                    : (dailyEvolution > 0 ? '+${dailyEvolution.toStringAsFixed(0)}%' : '${dailyEvolution.toStringAsFixed(0)}%'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: dailyEvolution >= 0 ? Colors.green : Colors.red,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Évolution sur la période: ${evolution >= 0 ? '+' : ''}${evolution.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 36,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text('🥇', style: TextStyle(fontSize: 11)),
        ),
      );
    } else if (rank == 2) {
      return Container(
        width: 36,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFFA9A9A9)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text('🥈', style: TextStyle(fontSize: 11)),
        ),
      );
    } else if (rank == 3) {
      return Container(
        width: 36,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFFB87333)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text('🥉', style: TextStyle(fontSize: 11)),
        ),
      );
    } else {
      return Container(
        width: 36,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            '#$rank',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
      );
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error ?? 'Erreur inconnue', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}