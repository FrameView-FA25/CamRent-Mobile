import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/booking/booking_list_screen.dart';
import '../profile/profile_screen.dart';
import '../services/api_service.dart';
import '../screens/staff/staff_main_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
  
  // Static method to reload cart from anywhere
  static void reloadCart() {
    _MainScreenState._instance?._reloadCartInternal();
  }
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // Global key to access BookingListScreen state for reloading
  final GlobalKey<State<BookingListScreen>> _bookingListKey = GlobalKey<State<BookingListScreen>>();
  
  // Static reference to allow reloading cart from anywhere
  static _MainScreenState? _instance;
  
  @override
  void initState() {
    super.initState();
    _instance = this;
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    // Check if user is Staff, redirect to StaffMainScreen if so
    final isStaffUser = await ApiService.isStaff();
    if (isStaffUser) {
      // Staff role - redirect to StaffMainScreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const StaffMainScreen()),
          );
        }
      });
    }
  }
  
  @override
  void dispose() {
    _instance = null;
    super.dispose();
  }
  
  void _reloadCartInternal() {
    final state = _bookingListKey.currentState;
    if (state != null) {
      try {
        debugPrint('MainScreen: Reloading cart via static method');
        (state as dynamic).reloadCart();
      } catch (e) {
        debugPrint('MainScreen: Error calling reloadCart: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      BookingListScreen(key: _bookingListKey),
      const ProfileScreen(),
    ];
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            final previousIndex = _currentIndex;
            setState(() {
              _currentIndex = index;
            });
            
            // Reload cart when switching to cart tab
            if (index == 1 && previousIndex != 1) {
              // Use a small delay to ensure the widget is built
              Future.delayed(const Duration(milliseconds: 100), () {
                final state = _bookingListKey.currentState;
                if (state != null) {
                  // Call reloadCart if it exists
                  try {
                    debugPrint('MainScreen: Attempting to reload cart');
                    // Use dynamic call to access reloadCart method
                    (state as dynamic).reloadCart();
                  } catch (e) {
                    debugPrint('MainScreen: Error calling reloadCart: $e');
                  }
                }
              });
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Giỏ hàng',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Hồ sơ',
            ),
          ],
        ),
      ),
    );
  }
}
