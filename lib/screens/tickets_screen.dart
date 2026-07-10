import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  
  List<dynamic> _ticketsData = [];
  Map<String, dynamic> _totaux = {};
  String _lastUpdate = '';
  String _date = '';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const String ticketsUrl = 'https://gist.githubusercontent.com/RAMZIU/dac270782c942a2ec2e16b958e8dfd19/raw/tickets.json';

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
      final response = await http.get(Uri.parse(ticketsUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _ticketsData = data['data'] ?? [];
        _totaux = {
          'total_tickets': data['total_tickets'] ?? 0,
          'total_amount': data['total_amount_ttc'] ?? 0,
          'total_magasins': data['total_magasins'] ?? 0,
        };
        _lastUpdate = data['last_update'] ?? '';
        _date = data['date'] ?? '';
        
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();
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

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final response = await http.get(Uri.parse(ticketsUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _ticketsData = data['data'] ?? [];
        _totaux = {
          'total_tickets': data['total_tickets'] ?? 0,
          'total_amount': data['total_amount_ttc'] ?? 0,
          'total_magasins': data['total_magasins'] ?? 0,
        };
        _lastUpdate = data['last_update'] ?? '';
        _date = data['date'] ?? '';
        
        setState(() {
          _isRefreshing = false;
        });
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isRefreshing = false;
      });
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return date;
    } catch (e) {
      return date;
    }
  }

  void _showTicketPaper(Map<String, dynamic> ticket) {
    final articles = ticket['articles'] ?? [];
    
    double totalHT = 0.0;
    double totalTVA = 0.0;
    double totalTTC = 0.0;
    
    for (var article in articles) {
      totalHT += (article['mnt_ht'] ?? 0).toDouble();
      totalTVA += (article['mnt_tva'] ?? 0).toDouble();
      totalTTC += (article['mnt_ttc'] ?? 0).toDouble();
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06616E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '🧾 TICKET DE CAISSE',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF06616E)),
                      ),
                      const SizedBox(height: 4),
                      Text(ticket['magasin'] ?? 'Magasin inconnu', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text('Ticket #${ticket['num_ticket'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[600]!)),
                      Text('${_formatDate(ticket['dt_vente'])} à ${ticket['hr_vente'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[600]!)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(flex: 3, child: Text('Article', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(child: Text('Qté', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                    Expanded(child: Text('Prix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 4),
                
                ...articles.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['article'] ?? 'Article inconnu', style: const TextStyle(fontSize: 13)),
                            Text(item['rayon'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey[500]!)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${(item['qte_vente'] ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${(item['mnt_ttc'] ?? 0).toStringAsFixed(2)} DH',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                )),
                
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total HT', style: TextStyle(fontSize: 13)),
                  Text('${totalHT.toStringAsFixed(2)} DH', style: const TextStyle(fontSize: 13)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('TVA', style: TextStyle(fontSize: 13)),
                  Text('${totalTVA.toStringAsFixed(2)} DH', style: const TextStyle(fontSize: 13)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('TOTAL TTC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${totalTTC.toStringAsFixed(2)} DH', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF06616E))),
                ]),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                Center(
                  child: Column(
                    children: [
                      Text('Merci de votre visite !', style: TextStyle(fontSize: 12, color: Colors.grey[600]!)),
                      Text('U Express - ${ticket['magasin'] ?? ''}', style: TextStyle(fontSize: 10, color: Colors.grey[500]!)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06616E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Tickets'),
        backgroundColor: const Color(0xFF06616E),
        foregroundColor: Colors.white,
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
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]!),
                                const SizedBox(width: 8),
                                Text(
                                  'Tickets du ${_formatDate(_date)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]!),
                                ),
                                const Spacer(),
                                Icon(Icons.update, size: 14, color: Colors.grey[600]!),
                                const SizedBox(width: 4),
                                Text(
                                  _lastUpdate.isNotEmpty ? _lastUpdate.substring(0, 16).replaceAll('T', ' ') : '',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[400]!),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF06616E), Color(0xFF0A8A9A)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryItem(
                                  icon: Icons.receipt,
                                  label: 'Tickets',
                                  value: _totaux['total_tickets']?.toString() ?? '0',
                                ),
                                _buildSummaryItem(
                                  icon: Icons.attach_money,
                                  label: 'CA Total',
                                  value: '${((_totaux['total_amount'] ?? 0) / 1000).toStringAsFixed(0)}K DH',
                                ),
                                _buildSummaryItem(
                                  icon: Icons.store,
                                  label: 'Magasins',
                                  value: _totaux['total_magasins']?.toString() ?? '0',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        if (_ticketsData.isNotEmpty) ...[
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🏆 Top tickets par magasin',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _ticketsData.length,
                                  itemBuilder: (context, index) {
                                    final ticket = _ticketsData[index];
                                    final articles = ticket['articles'] ?? [];
                                    final nbArticles = articles.length;
                                    final magasin = ticket['magasin'] ?? 'Inconnu';
                                    final isHyper = magasin.startsWith('HY');
                                    final amount = (ticket['total_ticket_ttc'] ?? 0).toDouble();
                                    
                                    return _buildTicketCard(
                                      ticket: ticket,
                                      nbArticles: nbArticles,
                                      amount: amount,
                                      isHyper: isHyper,
                                      index: index,
                                    );
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

  Widget _buildSummaryItem({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.white),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildTicketCard({
    required Map<String, dynamic> ticket,
    required int nbArticles,
    required double amount,
    required bool isHyper,
    required int index,
  }) {
    final magasin = ticket['magasin'] ?? 'Inconnu';
    final numTicket = ticket['num_ticket'] ?? 'N/A';
    final articles = ticket['articles'] ?? [];
    final nbArticlesDisplay = articles.length;
    
    // Limiter le texte du magasin pour éviter l'overflow
    String displayMagasin = magasin;
    if (displayMagasin.length > 20) {
      displayMagasin = displayMagasin.substring(0, 18) + '...';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTicketPaper(ticket),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayMagasin,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isHyper ? const Color(0xFF06616E) : const Color(0xFFF59E0B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (index == 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '🏆',
                                  style: TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '#$numTicket',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]!),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${ticket['hr_vente'] ?? ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]!),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$nbArticlesDisplay articles',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]!),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06616E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(amount).toStringAsFixed(0)} DH',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF06616E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ],
              ),
              
              if (nbArticlesDisplay > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: articles.take(3).map<Widget>((article) {
                    String articleName = article['article'] ?? '';
                    if (articleName.length > 25) {
                      articleName = articleName.substring(0, 22) + '...';
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        articleName,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
                if (nbArticlesDisplay > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${nbArticlesDisplay - 3} autres...',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]!),
                    ),
                  ),
              ],
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
          Text(_error ?? 'Erreur inconnue', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06616E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}