import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Top10Screen extends StatefulWidget {
  const Top10Screen({super.key});

  @override
  State<Top10Screen> createState() => _Top10ScreenState();
}

class _Top10ScreenState extends State<Top10Screen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<dynamic> _top10Data = [];
  String? _error;
  String _lastUpdate = '';

  static const String top10Url = 'https://gist.githubusercontent.com/RAMZIU/cc9805bfb9079e84c7b15be88ad8f4d1/raw/top10_articles.json';

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
      final response = await http.get(Uri.parse(top10Url));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        
        setState(() {
          _top10Data = data['data'] ?? [];
          _lastUpdate = data['last_update'] ?? '';
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
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(top10Url));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        
        setState(() {
          _top10Data = data['data'] ?? [];
          _lastUpdate = data['last_update'] ?? '';
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFFE22019),
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
                        colors: [Color(0xFFE22019), Color(0xFFC0392B)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
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
                          'TOP 10 Articles',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE22019),
                          ),
                        ),
                        Text(
                          'Meilleures ventes du jour',
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
                      color: const Color(0xFFE22019).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFE22019),
                              ),
                            )
                          : const Icon(Icons.refresh, color: Color(0xFFE22019)),
                      onPressed: _isRefreshing ? null : _refreshData,
                      tooltip: 'Rafraîchir',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Info dernière mise à jour
              if (_lastUpdate.isNotEmpty)
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
              
              const SizedBox(height: 20),
              
              // Contenu principal
              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE22019)),
                      ),
                      SizedBox(height: 16),
                      Text('Chargement des données...'),
                    ],
                  ),
                )
              else if (_error != null)
                _buildErrorWidget()
              else if (_top10Data.isEmpty)
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
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _top10Data.length,
                  itemBuilder: (context, index) {
                    final article = _top10Data[index];
                    return _buildArticleCard(article, index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard(dynamic article, int index) {
    final rang = article['rang'] ?? index + 1;
    final articleName = article['article'] ?? 'N/A';
    final ean = article['ean'] ?? 'N/A';
    final quantite = article['quantite_totale'] ?? 0;
    final ca = (article['ca_total'] ?? 0).toDouble();
    final nbVendus = article['nb_magasins_vendus'] ?? 0;
    final nbTotal = article['nb_magasins_total'] ?? 0;
    final taux = article['taux_distribution'] ?? 0;
    final magasinsVendus = List<String>.from(article['magasins_vendus'] ?? []);
    final magasinsManquants = List<String>.from(article['magasins_manquants'] ?? []);

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
          leading: _buildRankBadge(rang),
          title: Text(
            articleName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EAN: $ean',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.production_quantity_limits, size: 12, color: Colors.grey),
                  const SizedBox(width: 2),
                  Text('Qté: $quantite', style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 12),
                  const Icon(Icons.store, size: 12, color: Colors.grey),
                  const SizedBox(width: 2),
                  Text('$nbVendus/$nbTotal mag', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(ca / 1000).toStringAsFixed(0)}K DH',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFFE22019),
                ),
              ),
              Text(
                'CA Total',
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
                  // Taux de distribution
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '✅ Distribution: $nbVendus/$nbTotal ($taux%)',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Magasins où présent
                  if (magasinsVendus.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.store, size: 14, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                'Présent (${magasinsVendus.length}) :',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: magasinsVendus.map((m) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  m,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 10),
                  
                  // Magasins où absent
                  if (magasinsManquants.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.error, size: 14, color: Colors.red),
                              const SizedBox(width: 6),
                              Text(
                                'Absent (${magasinsManquants.length}) :',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: magasinsManquants.map((m) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  m,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }).toList(),
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
              backgroundColor: const Color(0xFFE22019),
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