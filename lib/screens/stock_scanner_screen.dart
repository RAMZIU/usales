import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';

class StockScannerScreen extends StatefulWidget {
  const StockScannerScreen({super.key});

  @override
  State<StockScannerScreen> createState() => _StockScannerScreenState();
}

class _StockScannerScreenState extends State<StockScannerScreen> {
  bool _isLoading = true;
  bool _isScanning = false;
  bool _isRefreshing = false;
  String? _error;
  String _lastUpdate = '';
  String _lastRefresh = '';
  
  List<Map<String, dynamic>> _allSalesData = [];
  List<Map<String, dynamic>> _searchResults = [];
  String? _lastScannedEAN;
  
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _eanController = TextEditingController();
  
  // URL vers le fichier CSV
  static const String salesCsvUrl = 'https://gist.githubusercontent.com/RAMZIU/2ad2df3cc59189c05ad74345c8b281a6/raw/ventes_periodes.csv';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _eanController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _loadSalesData(forceRefresh: false);
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Erreur: $e');
      setState(() => _error = e.toString());
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
      _searchResults = [];
      _lastScannedEAN = null;
      _eanController.clear();
    });

    try {
      await _loadSalesData(forceRefresh: true);
      
      setState(() {
        _isRefreshing = false;
        _lastRefresh = DateTime.now().toString();
      });
      
      _showSnackBar('✅ Données rafraîchies ! ${_allSalesData.length} produits chargés');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isRefreshing = false;
      });
      _showSnackBar('❌ Erreur lors du rafraîchissement');
    }
  }

  Future<void> _loadSalesData({required bool forceRefresh}) async {
    print('🔄 Chargement des données... Force refresh: $forceRefresh');
    
    // Ajout d'un timestamp pour éviter le cache
    String url = salesCsvUrl;
    if (forceRefresh) {
      url = '$salesCsvUrl?nocache=${DateTime.now().millisecondsSinceEpoch}';
    }
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final String csvString = response.body;
      final List<String> lines = csvString.split('\n');
      
      if (lines.isEmpty) {
        throw Exception('Fichier CSV vide');
      }
      
      // Lire les en-têtes
      final List<String> headers = _parseCSVLine(lines[0]);
      print('📋 En-têtes trouvés: $headers');
      
      final List<Map<String, dynamic>> data = [];
      
      // Index des colonnes (basé sur votre CSV)
      final int siteIndex = headers.indexWhere((h) => h.toLowerCase() == 'site');
      final int codeSiteIndex = headers.indexWhere((h) => h.toLowerCase() == 'code_site');
      final int codeArticleIndex = headers.indexWhere((h) => h.toLowerCase() == 'code_article');
      final int articleIndex = headers.indexWhere((h) => h.toLowerCase() == 'article');
      final int eanIndex = headers.indexWhere((h) => h.toLowerCase() == 'ean');
      final int qteStockIndex = headers.indexWhere((h) => h.toLowerCase() == 'qte_stock');
      final int qte7jrIndex = headers.indexWhere((h) => h.toLowerCase() == 'qte_vendue_7jr');
      final int qte15jrIndex = headers.indexWhere((h) => h.toLowerCase() == 'qte_vendue_15jr');
      final int qte30jrIndex = headers.indexWhere((h) => h.toLowerCase() == 'qte_vendue_30jr');
      final int montant7jrIndex = headers.indexWhere((h) => h.toLowerCase() == 'montant_7jr');
      final int montant15jrIndex = headers.indexWhere((h) => h.toLowerCase() == 'montant_15jr');
      final int montant30jrIndex = headers.indexWhere((h) => h.toLowerCase() == 'montant_30jr');
      final int tauxRotationIndex = headers.indexWhere((h) => h.toLowerCase() == 'taux_rotation');
      
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        
        final List<String> values = _parseCSVLine(lines[i]);
        if (values.length != headers.length) {
          print('⚠️ Ligne $i: ${values.length} colonnes au lieu de ${headers.length}');
          continue;
        }
        
        final Map<String, dynamic> row = {};
        
        // Ne garder que les colonnes nécessaires (on ignore qte_stock)
        if (codeSiteIndex != -1) row['code_site'] = values[codeSiteIndex].trim();
        if (siteIndex != -1) row['site'] = values[siteIndex].trim();
        if (codeArticleIndex != -1) row['code_article'] = values[codeArticleIndex].trim();
        if (articleIndex != -1) row['article'] = values[articleIndex].trim();
        if (eanIndex != -1) row['ean'] = values[eanIndex].trim();
        
        // Données de ventes (on ignore les stocks négatifs pour l'affichage)
        if (qte7jrIndex != -1) row['qte_vendue_7jr'] = double.tryParse(values[qte7jrIndex].trim()) ?? 0;
        if (qte15jrIndex != -1) row['qte_vendue_15jr'] = double.tryParse(values[qte15jrIndex].trim()) ?? 0;
        if (qte30jrIndex != -1) row['qte_vendue_30jr'] = double.tryParse(values[qte30jrIndex].trim()) ?? 0;
        if (montant7jrIndex != -1) row['montant_vente_7jr'] = double.tryParse(values[montant7jrIndex].trim()) ?? 0;
        if (montant15jrIndex != -1) row['montant_vente_15jr'] = double.tryParse(values[montant15jrIndex].trim()) ?? 0;
        if (montant30jrIndex != -1) row['montant_vente_30jr'] = double.tryParse(values[montant30jrIndex].trim()) ?? 0;
        if (tauxRotationIndex != -1) row['taux_rotation'] = double.tryParse(values[tauxRotationIndex].trim()) ?? 0;
        
        // Stock (optionnel, pour info)
        if (qteStockIndex != -1) {
          double stock = double.tryParse(values[qteStockIndex].trim()) ?? 0;
          if (stock >= 0) row['qte_stock'] = stock;
        }
        
        data.add(row);
      }
      
      setState(() {
        _allSalesData = data;
        _lastUpdate = DateTime.now().toString();
      });
      
      print('✅ CSV chargé: ${data.length} lignes');
    } else {
      throw Exception('Erreur chargement CSV: ${response.statusCode}');
    }
  }

  List<String> _parseCSVLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();
    
    for (int i = 0; i < line.length; i++) {
      String char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ';' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    
    return result;
  }

  void _searchByEAN(String ean) {
    if (ean.isEmpty) {
      _showSnackBar('Code EAN invalide');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    // Recherche dans TOUS les sites
    final results = _allSalesData.where((item) {
      return item['ean'] == ean;
    }).toList();
    
    setState(() {
      _searchResults = results;
      _lastScannedEAN = ean;
      _isLoading = false;
    });
    
    if (results.isEmpty) {
      _showSnackBar('❌ Produit non trouvé (EAN: $ean)');
    } else {
      _showSnackBar('✅ ${results.length} magasin(s) trouvé(s) pour EAN: $ean');
    }
  }

  void _onBarcodeCapture(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? ean = barcodes.first.rawValue;
      if (ean != null && ean.isNotEmpty) {
        setState(() {
          _eanController.text = ean;
          _isScanning = false;
        });
        _searchByEAN(ean);
        _scannerController.stop();
      }
    }
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _searchResults = [];
      _lastScannedEAN = null;
      _eanController.clear();
    });
    _scannerController.start();
  }

  void _stopScanning() {
    setState(() => _isScanning = false);
    _scannerController.stop();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    if (value is int) return value.toString();
    if (value is double) {
      if (value == value.toInt()) return value.toInt().toString();
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Scanner Ventes Multi-Sites'),
        backgroundColor: const Color(0xFF06616E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Rafraîchir',
          ),
          if (_isScanning)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopScanning,
              tooltip: 'Fermer scanner',
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _error != null 
              ? _buildErrorWidget() 
              : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_isScanning) {
      return _buildScannerView();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.update, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '📈 ${_allSalesData.length} produits',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                if (_lastRefresh.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '| Refresh: ${_lastRefresh.substring(0, 16)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Recherche manuelle
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search, size: 28, color: Color(0xFF06616E)),
                      const SizedBox(width: 12),
                      const Text(
                        'Recherche par EAN',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _eanController,
                          decoration: InputDecoration(
                            hintText: 'Saisir le code EAN (13 chiffres)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            prefixIcon: const Icon(Icons.qr_code),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 13,
                          onSubmitted: (value) => _searchByEAN(value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _searchByEAN(_eanController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06616E),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Rechercher'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Scanner
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 48, color: Color(0xFF06616E)),
                  const SizedBox(height: 12),
                  const Text(
                    'Scanner un code-barres',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Voir les ventes du produit dans TOUS les magasins',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startScanning,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Ouvrir le scanner'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06616E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Résultats
          if (_searchResults.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF06616E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Color(0xFF06616E), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📊 Ventes pour EAN: $_lastScannedEAN',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_searchResults.length} magasin(s)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final product = _searchResults[index];
                final hasVentes = (product['qte_vendue_30jr'] ?? 0) > 0;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF06616E).withOpacity(0.1),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Color(0xFF06616E), fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      product['site'] ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      product['code_article'] ?? 'Code inconnu',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasVentes ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasVentes ? 'En vente' : 'Sans vente',
                        style: TextStyle(fontSize: 10, color: hasVentes ? Colors.green : Colors.orange),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Article', product['article'] ?? 'N/A'),
                            const Divider(),
                            _buildDetailRow('Code Article', product['code_article'] ?? 'N/A'),
                            const Divider(),
                            _buildDetailRow('📊 Ventes 7 jours', '${_formatNumber(product['qte_vendue_7jr'])} unités'),
                            const Divider(),
                            _buildDetailRow('📊 Ventes 15 jours', '${_formatNumber(product['qte_vendue_15jr'])} unités'),
                            const Divider(),
                            _buildDetailRow('📊 Ventes 30 jours', '${_formatNumber(product['qte_vendue_30jr'])} unités'),
                            const Divider(),
                            _buildDetailRow('💰 CA 7 jours', '${_formatNumber(product['montant_vente_7jr'])} DH'),
                            const Divider(),
                            _buildDetailRow('💰 CA 15 jours', '${_formatNumber(product['montant_vente_15jr'])} DH'),
                            const Divider(),
                            _buildDetailRow('💰 CA 30 jours', '${_formatNumber(product['montant_vente_30jr'])} DH'),
                            if (product.containsKey('taux_rotation') && (product['taux_rotation'] ?? 0) > 0) ...[
                              const Divider(),
                              _buildDetailRow('🔄 Taux rotation', '${_formatNumber(product['taux_rotation'])}'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else if (_lastScannedEAN != null && _searchResults.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun résultat trouvé pour EAN: $_lastScannedEAN',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vérifiez le code ou essayez de rafraîchir les données',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onBarcodeCapture,
              ),
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.center_focus_strong, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Centrer le code-barres dans le cadre', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error ?? 'Erreur inconnue'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06616E)),
            child: const Text('Rafraîchir'),
          ),
        ],
      ),
    );
  }
}