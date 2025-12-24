import 'package:flutter/material.dart';
import 'package:perform_test/data/datasource/api.dart';
import 'package:perform_test/presentation/large_image_page.dart';
import 'package:perform_test/presentation/profile/page/photos_feed_screen.dart';
import 'package:perform_test/presentation/atoms/page/bloc_ui_tab.dart';

class BottomTabs extends StatefulWidget {
  const BottomTabs({super.key, required this.datasource});
  final Datasource datasource;

  @override
  State<BottomTabs> createState() => _BottomTabsState();
}

class _BottomTabsState extends State<BottomTabs> {
  int _selectedIndex = 0;
  late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = [
      PhotosFeedScreen(datasource: widget.datasource),
      // LargeImagePage(datasource: widget.datasource),
      DummyTab(),
      BlocUITab(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.photo), label: 'Photos'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Likes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fire_truck),
            label: 'Performance',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

class DummyTab extends StatelessWidget {
  const DummyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dummy tab'),
        backgroundColor: const Color(0xFFFFB347),
      ),
      body: const Center(
        child: Text(
          'Just an empty dummy tab',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
