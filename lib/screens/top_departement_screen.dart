import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TopDepartementScreen extends StatefulWidget {
  const TopDepartementScreen({super.key});

  @override
  State<TopDepartementScreen> createState() => _TopDepartementScreenState();
}

class _TopDepartementScreenState extends State<TopDepartementScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, dynamic> _topProduitsData = {};
  String? _error;
  String _lastUpdate = '';
  String _selectedDate = '';

  static const String topDepartementUrl = 'https://gist.githubusercontent.com/RAMZIU/9a9a87a1b37721f81e630d4a56f82e9b/raw/top_produits_par_departement.json';

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value.isNaN ? 0.0 : value;
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  String _safeString(dynamic value) {
    if (value == null) return 'N/A';
    if (value is String) return value.isEmpty ? 'N/A' : value;
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(topDepartementUrl));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // ✅ CORRECTION: data['data'] est un Map
        Map<String, dynamic> produitsData = {};
        
        if (data['data'] is Map) {
          final Map<String, dynamic> rawData = data['data'] as Map<String, dynamic>;
          
          for (var entry in rawData.entries) {
            final String departement = entry.key;
            final Map<String, dynamic> depValue = entry.value as Map<String, dynamic>;
            
            final List<dynamic> rawProduits = depValue['produits'] ?? [];
            final List<Map<String, dynamic>> produits = [];
            
            for (var produit in rawProduits) {
              if (produit is Map<String, dynamic>) {
                produits.add({
                  'article': _safeString(produit['article']),
                  'ean': _safeString(produit['ean']),
                  'quantite_vendue': _safeInt(produit['quantite_vendue']),
                  'ca': _safeDouble(produit['ca']),
                  'nb_magasins': _safeInt(produit['nb_magasins']),
                });
              }
            }
            
            produitsData[departement] = {
              'total_ca': _safeDouble(depValue['total_ca']),
              'produits': produits,
            };
          }
        }
        
        setState(() {
          _topProduitsData = produitsData;
          _lastUpdate = _safeString(data['last_update']);
          _selectedDate = _safeString(data['date']);
          _isRefreshing = false;
          _isLoading = false;
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
      final response = await http.get(Uri.parse(topDepartementUrl));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // ✅ CORRECTION: data['data'] est un Map
        Map<String, dynamic> produitsData = {};
        
        if (data['data'] is Map) {
          final Map<String, dynamic> rawData = data['data'] as Map<String, dynamic>;
          
          for (var entry in rawData.entries) {
            final String departement = entry.key;
            final Map<String, dynamic> depValue = entry.value as Map<String, dynamic>;
            
            final List<dynamic> rawProduits = depValue['produits'] ?? [];
            final List<Map<String, dynamic>> produits = [];
            
            for (var produit in rawProduits) {
              if (produit is Map<String, dynamic>) {
                produits.add({
                  'article': _safeString(produit['article']),
                  'ean': _safeString(produit['ean']),
                  'quantite_vendue': _safeInt(produit['quantite_vendue']),
                  'ca': _safeDouble(produit['ca']),
                  'nb_magasins': _safeInt(produit['nb_magasins']),
                });
              }
            }
            
            produitsData[departement] = {
              'total_ca': _safeDouble(depValue['total_ca']),
              'produits': produits,
            };
          }
        }
        
        setState(() {
          _topProduitsData = produitsData;
          _lastUpdate = _safeString(data['last_update']);
          _selectedDate = _safeString(data['date']);
          _isLoading = false;
        });
      } else {
        throw Exception('Erreur de chargement');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      _loadMockData();
    }
  }

  void _loadMockData() {
    final mockData = {
      "BAZAR": {
        "total_ca": 15095,
        "produits": [
          {"article": "CONGELATEUR CGC120SXK95L DAIKO", "ean": "6111275243734", "quantite_vendue": 2, "ca": 3798, "nb_magasins": 3},
          {"article": "SALON DE JARDIN DOUALA", "ean": "3368956341682", "quantite_vendue": 1, "ca": 3000, "nb_magasins": 1},
          {"article": "CONGELATEU CGC280SXK195L DAIKO", "ean": "6111275243758", "quantite_vendue": 1, "ca": 2999, "nb_magasins": 1},
        ]
      }
    };
    
    setState(() {
      _topProduitsData = mockData;
      _selectedDate = DateTime.now().subtract(const Duration(days: 1)).toString().substring(0, 10);
      _lastUpdate = DateTime.now().toString();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFFEC4899),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.dashboard, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Produits par Département',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEC4899),
                          ),
                        ),
                        Text(
                          'Meilleures ventes par rayon',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFEC4899),
                              ),
                            )
                          : const Icon(Icons.refresh, color: Color(0xFFEC4899)),
                      onPressed: _isRefreshing ? null : _refreshData,
                      tooltip: 'Rafraîchir',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Info date
              Row(
                children: [
                  if (_selectedDate.isNotEmpty && _selectedDate != 'N/A')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 10, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Date: $_selectedDate',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (_lastUpdate.isNotEmpty && _lastUpdate != 'N/A')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.update, size: 10, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Màj: ${_lastUpdate.substring(0, 16)}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Contenu
              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                      ),
                      SizedBox(height: 16),
                      Text('Chargement des données...'),
                    ],
                  ),
                )
              else if (_error != null)
                _buildErrorWidget()
              else if (_topProduitsData.isEmpty)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucune donnée disponible'),
                    ],
                  ),
                )
              else
                _buildDepartementList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartementList() {
    List<String> departements = _topProduitsData.keys.toList();
    
    departements.sort((a, b) {
      double totalA = _safeDouble(_topProduitsData[a]?['total_ca']);
      double totalB = _safeDouble(_topProduitsData[b]?['total_ca']);
      return totalB.compareTo(totalA);
    });
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: departements.length,
      itemBuilder: (context, index) {
        String departement = departements[index];
        Map<String, dynamic> depData = _topProduitsData[departement] ?? {};
        double totalCA = _safeDouble(depData['total_ca']);
        List<dynamic> produits = depData['produits'] ?? [];
        
        return _buildDepartementCard(
          rank: index + 1,
          departement: departement,
          totalCA: totalCA,
          produits: produits,
        );
      },
    );
  }

  Widget _buildDepartementCard({
    required int rank,
    required String departement,
    required double totalCA,
    required List<dynamic> produits,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: _buildRankBadge(rank),
          title: Text(
            departement,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${produits.length} produits | CA: ${(totalCA / 1000).toStringAsFixed(1)}K DH',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(totalCA / 1000).toStringAsFixed(0)}K DH',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFFEC4899),
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Produits',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: produits.length,
                    itemBuilder: (context, idx) {
                      final produit = produits[idx];
                      return _buildProduitCard(produit, idx + 1);
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_money, size: 14, color: Color(0xFFEC4899)),
                        const SizedBox(width: 8),
                        Text(
                          'Total département: ${(totalCA / 1000).toStringAsFixed(1)}K DH',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
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

  Widget _buildProduitCard(dynamic produit, int rank) {
    final article = _safeString(produit['article']);
    final ean = _safeString(produit['ean']);
    final quantite = _safeInt(produit['quantite_vendue']);
    final ca = _safeDouble(produit['ca']);
    final nbMagasins = _safeInt(produit['nb_magasins']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Color(0xFFEC4899),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  article,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Row(
              children: [
                const Icon(Icons.qr_code, size: 10, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'EAN: $ean',
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.production_quantity_limits, size: 10, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Qté: $quantite',
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.store, size: 10, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '$nbMagasins mag.',
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              'CA: ${(ca / 1000).toStringAsFixed(1)}K DH',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFFEC4899),
              ),
            ),
          ),
        ],
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
              backgroundColor: const Color(0xFFEC4899),
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