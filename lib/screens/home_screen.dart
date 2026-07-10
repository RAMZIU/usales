import 'package:flutter/material.dart';
import 'magasins_screen.dart';
import 'top10_screen.dart';
import 'stats_clients_screen.dart';
import 'produits_u_screen.dart';
import 'croissance_screen.dart';
import 'top_produits_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  final List<MenuItem> _menuItems = [
    MenuItem(icon: Icons.store, title: 'Magasins', color: Color(0xFF06616E), screen: MagasinsScreen()),
    MenuItem(icon: Icons.emoji_events, title: 'TOP 10 Articles', color: Color(0xFFE22019), screen: Top10Screen()),
    MenuItem(icon: Icons.people, title: 'Stats Clients', color: Color(0xFF10B981), screen: StatsClientsScreen()),
    MenuItem(icon: Icons.category, title: 'Produits U', color: Color(0xFFF59E0B), screen: ProduitsUScreen()),
    MenuItem(icon: Icons.trending_up, title: 'Croissance', color: Color(0xFF8B5CF6), screen: CroissanceScreen()),
    MenuItem(icon: Icons.dashboard, title: 'TOP par Dépt', color: Color(0xFFEC4899), screen: TopProduitsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06616E), Color(0xFFE22019)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.analytics, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('U Express Analytics'),
          ],
        ),
      ),
      body: Row(
        children: [
          // Menu latéral
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'MENU',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                ..._menuItems.asMap().entries.map((entry) {
                  int index = entry.key;
                  MenuItem item = entry.value;
                  return _buildMenuItem(
                    index: index,
                    item: item,
                    isSelected: _selectedIndex == index,
                  );
                }),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'U Express KPI v1.0',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Zone de contenu
          Expanded(
            child: _menuItems[_selectedIndex].screen,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required int index,
    required MenuItem item,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? item.color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: item.color, width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(item.icon, color: isSelected ? item.color : Colors.grey[600], size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? item.color : Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.chevron_right, color: item.color, size: 20),
          ],
        ),
      ),
    );
  }
}

class MenuItem {
  final IconData icon;
  final String title;
  final Color color;
  final Widget screen;

  MenuItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.screen,
  });
}