import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ProduitsUScreen extends StatefulWidget {
  const ProduitsUScreen({super.key});

  @override
  State<ProduitsUScreen> createState() => _ProduitsUScreenState();
}

class _ProduitsUScreenState extends State<ProduitsUScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _produitsUData = [];
  double _totalCA = 0;
  String? _error;
  String _lastUpdate = '';
  String _selectedDate = '';

  // Gist URL pour les produits U
  static const String produitsUUrl = 'https://gist.githubusercontent.com/RAMZIU/83b23aeefa91b25b95bdd1a8e71a161f/raw/produits_u.json';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Rafraîchissement avec rechargement depuis le Gist
  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(produitsUUrl));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        
        final List<dynamic> rawData = data['data'] ?? [];
        final List<Map<String, dynamic>> produitsData = [];
        
        for (var item in rawData) {
          produitsData.add({
            'magasin': item['magasin']?.toString() ?? 'N/A',
            'ca': (item['ca'] ?? 0).toDouble(),
          });
        }
        
        final totalCA = produitsData.fold(0.0, (sum, item) => sum + (item['ca'] as double));
        
        setState(() {
          _produitsUData = produitsData;
          _totalCA = totalCA;
          _lastUpdate = data['last_update'] ?? '';
          _selectedDate = data['date'] ?? '';
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
      final response = await http.get(Uri.parse(produitsUUrl));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        
        final List<dynamic> rawData = data['data'] ?? [];
        final List<Map<String, dynamic>> produitsData = [];
        
        for (var item in rawData) {
          produitsData.add({
            'magasin': item['magasin']?.toString() ?? 'N/A',
            'ca': (item['ca'] ?? 0).toDouble(),
          });
        }
        
        final totalCA = produitsData.fold(0.0, (sum, item) => sum + (item['ca'] as double));
        
        setState(() {
          _produitsUData = produitsData;
          _totalCA = totalCA;
          _lastUpdate = data['last_update'] ?? '';
          _selectedDate = data['date'] ?? '';
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
    final mockData = [
      {"magasin": "HY Casa Zenata", "ca": 20071.83},
      {"magasin": "HY Agadir", "ca": 13861.86},
      {"magasin": "UE Rabat Annakhil", "ca": 7057.79},
      {"magasin": "UE Salé Marina", "ca": 6578.81},
      {"magasin": "UE Rabat Square", "ca": 6487.23},
      {"magasin": "UE Rabat Mega Mall", "ca": 3675.31},
      {"magasin": "UE Casa Ain Sebaa", "ca": 1597.88},
    ];
    
    setState(() {
      _produitsUData = mockData;
      _totalCA = mockData.fold(0.0, (sum, item) => sum + (item['ca'] as double));
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
        color: const Color(0xFFF59E0B),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec titre et bouton refresh
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.category,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Produits U',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        Text(
                          'CA par magasin - Marque U',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bouton refresh
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFF59E0B),
                              ),
                            )
                          : const Icon(Icons.refresh, color: Color(0xFFF59E0B)),
                      onPressed: _isRefreshing ? null : _refreshData,
                      tooltip: 'Rafraîchir',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Info date et mise à jour
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
              
              // Contenu principal
              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                      ),
                      SizedBox(height: 16),
                      Text('Chargement des données...'),
                    ],
                  ),
                )
              else if (_error != null)
                _buildErrorWidget()
              else if (_produitsUData.isEmpty)
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
              else ...[
                // Carte Total
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL PRODUITS U',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(_totalCA / 1000).toStringAsFixed(1)} K DH',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_totalCA.toStringAsFixed(0)} MAD',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                const Text(
                  'Classement par Magasin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 12),
                
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _produitsUData.length,
                  itemBuilder: (context, index) {
                    final item = _produitsUData[index];
                    final magasin = item['magasin'] ?? 'N/A';
                    final ca = (item['ca'] ?? 0).toDouble();
                    final pourcentage = _totalCA > 0 ? (ca / _totalCA) * 100 : 0;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _showDetailDialog(magasin, ca, pourcentage);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _buildRankBadge(index + 1),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          magasin,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${pourcentage.toStringAsFixed(1)}% du total',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${(ca / 1000).toStringAsFixed(1)}K DH',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      ),
                                      Text(
                                        '${ca.toStringAsFixed(0)} MAD',
                                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ca / _totalCA,
                                  backgroundColor: Colors.grey[200],
                                  color: const Color(0xFFF59E0B),
                                  minHeight: 5,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text('🥇', style: TextStyle(fontSize: 12)),
        ),
      );
    } else if (rank == 2) {
      return Container(
        width: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFFA9A9A9)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text('🥈', style: TextStyle(fontSize: 12)),
        ),
      );
    } else if (rank == 3) {
      return Container(
        width: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFFB87333)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text('🥉', style: TextStyle(fontSize: 12)),
        ),
      );
    } else {
      return Container(
        width: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            '#$rank',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      );
    }
  }

  void _showDetailDialog(String magasin, double ca, double pourcentage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.category,
                    color: Color(0xFFF59E0B),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  magasin,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Produits U',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('CA Produits U', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '${(ca / 1000).toStringAsFixed(1)}K DH',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Part du marché', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '${pourcentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
              backgroundColor: const Color(0xFFF59E0B),
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