// ignore_for_file: unused_import

import 'dart:async';
import 'dart:ui';
import 'package:Picon/api_service.dart';
import 'package:Picon/booking_screen.dart';
import 'package:Picon/booking_status_screen.dart';
import 'package:Picon/contact_screen.dart';
import 'package:Picon/history_screen.dart';
import 'package:Picon/no_connection_screen.dart';
import 'package:Picon/notifications_screen.dart';
import 'package:Picon/portfolio_screen.dart';
import 'package:Picon/pricing_screen.dart';
import 'package:Picon/profile_page.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/connectivity_service.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:Picon/utils/realtime_service.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'login_screen.dart';
import 'order_summary_screen.dart';
import 'package:Picon/models/promotion.dart';
import 'package:Picon/models/order.dart';
import 'package:Picon/models/booking.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Model Class for Real History Data ---
enum HistoryItemType { order, booking }

class HistoryItem {
  final String title;
  final DateTime date;
  final IconData icon;
  final HistoryItemType type;
  final dynamic originalObject;

  HistoryItem({
    required this.title,
    required this.date,
    required this.icon,
    required this.type,
    this.originalObject,
  });
}
// --- End of Model Class ---

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userLastName;
  final String userEmail;
  final int userId;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.userLastName,
    required this.userEmail,
    required this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum CartMode { detail, batch }

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<String> _selectedImages = {};
  Future<List<String>>? _albumImagesFuture;
  File? _avatar;
  final Map<String, Map<String, dynamic>> _photoDetails = {};

  final ConnectivityService _connectivityService = ConnectivityService();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isOffline = false;

  // --- Updatable profile info ---
  late String _currentUserName;
  late String _currentUserLastName;
  late String _currentUserEmail;

  // --- New state variables for cart ---
  CartMode _selectedMode = CartMode.detail;
  bool _isExpress = false;
  double _totalPrice = 0.0;
  Map<String, double>? _prices;
  bool _isLoadingPrices = true;
  bool _isUploading = false;
  Future<List<Promotion>>? _promotionsFuture;
  Future<List<HistoryItem>>? _historyFuture;
  RealtimeService? _realtimeService;
  // --- End of new state variables ---


  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _currentUserLastName = widget.userLastName;
    _currentUserEmail = widget.userEmail;
    _albumImagesFuture = ApiService.getAlbumImages(widget.userId);
    _promotionsFuture = ApiService.fetchPromotions();
    _historyFuture = _fetchRecentHistory();
    _connectivitySubscription =
        _connectivityService.connectivityStream.listen((result) {
      if (result == ConnectivityResult.none) {
        if (!_isOffline && mounted) {
          setState(() {
            _isOffline = true;
          });
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const NoConnectionScreen()));
        }
      } else {
        if (_isOffline && mounted) {
          setState(() {
            _isOffline = false;
          });
        }
      }
    });
    _fetchPrices();
    _initRealtime();
  }

  void _initRealtime() {
    // On utilise l'URL de base de l'API mais avec le protocole ws
    final wsUrl = ApiService.rootUrl.replaceFirst('http', 'ws') + '/ws';
    _realtimeService = RealtimeService(
      wsUrl: wsUrl,
      onNotification: (type) {
        if (mounted) {
          print('Notification reçue: $type');
          if (type == 'PROMOTIONS_UPDATED') {
            setState(() {
              _promotionsFuture = ApiService.fetchPromotions();
            });
          } else if (type == 'DIMENSIONS_UPDATED') {
            _fetchPrices();
          } else if (type == 'FEATURED_UPDATED') {
            // Optionnel: ajouter un futur pour le contenu à la une si nécessaire
          }
        }
      },
    );
    _realtimeService?.connect();
  }

  Future<List<HistoryItem>> _fetchRecentHistory() async {
    try {
      final results = await Future.wait([
        ApiService.fetchMyOrders(),
        ApiService.fetchUserBookings(),
      ]);

      final List<Order> orders = results[0] as List<Order>;
      final List<Booking> bookings = results[1] as List<Booking>;

      final List<HistoryItem> items = [];

      for (var order in orders) {
        items.add(HistoryItem(
          title: "Commande #${order.id}",
          date: order.createdAt,
          icon: Icons.shopping_bag,
          type: HistoryItemType.order,
          originalObject: order,
        ));
      }

      for (var booking in bookings) {
        items.add(HistoryItem(
          title: booking.title,
          date: booking.startTime,
          icon: Icons.event,
          type: HistoryItemType.booking,
          originalObject: booking,
        ));
      }

      // Sort by date descending
      items.sort((a, b) => b.date.compareTo(a.date));

      // Limit to 5
      return items.take(5).toList();
    } catch (e) {
      print("Error fetching history: $e");
      return [];
    }
  }

  Future<void> _fetchPrices() async {
    try {
      final fetchedDimensions = await ApiService.fetchDimensions();
      if (mounted) {
        setState(() {
          _prices = {
            for (var dim in fetchedDimensions) dim.dimension: dim.price
          };
          // _calculateTotal(); // Note: if _calculateTotal is needed, ensure it exists
          _isLoadingPrices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erreur de chargement des prix: $e")));
        setState(() {
          _isLoadingPrices = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _realtimeService?.disconnect();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == 3) {
      // Index 3 is for Profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(
            userName: _currentUserName,
            userLastName: _currentUserLastName,
            userEmail: _currentUserEmail,
            avatar: _avatar,
            onAvatarChanged: (newAvatar) {
              setState(() {
                _avatar = newAvatar;
              });
            },
            onProfileUpdated: (newName, newLastName, newEmail) {
              setState(() {
                _currentUserName = newName;
                _currentUserLastName = newLastName;
                _currentUserEmail = newEmail;
              });
            },
          ),
        ),
      );
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _changeAvatar() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _avatar = File(pickedFile.path);
      });
    }
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _quickPhotoOrder() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 50);

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _isUploading = true;
      });

      try {
        final uploadedUrls = await ApiService.uploadPhotos(pickedFiles);
        setState(() {
          _selectedImages.addAll(uploadedUrls);
          _calculateTotal();
        });
        _onTabTapped(2); // Switch to the Commands tab
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi: ${e.toString()}'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          GeometricBackground(), // Using GeometricBackground
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFixedTopBar(context),
          ),
          Padding(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top +
                    kToolbarHeight), // Adjusted top padding
            child: _buildBody(),
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Envoi des photos...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildFloatingBottomNavBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _quickPhotoOrder,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      )
          .animate(
            onComplete: (controller) => controller.repeat(reverse: true),
          )
          .scale(
            delay: 1000.ms,
            duration: 500.ms,
            begin: const Offset(1, 1),
            end: const Offset(1.1, 1.1),
            curve: Curves.easeInOut,
          ),
    );
  }

  Widget _buildFixedTopBar(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20)), // Rounded bottom corners
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Increased blur
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary
                .withOpacity(0.4), // Slightly transparent primary color
            border: Border.all(
                color: Colors.white.withOpacity(0.2)), // Subtle border
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
              16.0,
              MediaQuery.of(context).padding.top + 4,
              16.0,
              4.0), // Reduced vertical padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(
                        userName: _currentUserName,
                        userLastName: _currentUserLastName,
                        userEmail: _currentUserEmail,
                        avatar: _avatar,
                        onAvatarChanged: (newAvatar) {
                          setState(() {
                            _avatar = newAvatar;
                          });
                        },
                        onProfileUpdated: (newName, newLastName, newEmail) {
                          setState(() {
                            _currentUserName = newName;
                            _currentUserLastName = newLastName;
                            _currentUserEmail = newEmail;
                          });
                        },
                      ),
                    ),
                  );
                },
                icon: CircleAvatar(
                  radius: 18,
                  backgroundImage: _avatar != null
                      ? FileImage(_avatar!) as ImageProvider
                      : null,
                  backgroundColor:
                      _avatar == null ? AppColors.accent : Colors.transparent,
                  child: _avatar == null
                      ? Text(
                          _currentUserName
                              .trim()
                              .split(' ')
                              .where((s) => s.isNotEmpty)
                              .map((s) => s[0])
                              .take(2)
                              .join()
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        )
                      : null,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/pro.png',
                    height: 30, // Smaller logo
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 2), // Reduced space
                  // Text(
                  //   'Hey, $_currentUserLastName!',
                  //   textAlign: TextAlign.center,
                  //   style: const TextStyle(
                  //     color: Colors.white,
                  //     fontSize: 11, // Smaller text
                  //   ),
                  // ),
                ],
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationsScreen()),
                  );
                },
                icon: const Icon(Icons.notifications_none,
                    color: Colors.white, size: 28), // Increased icon size
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final List<Widget> tabs = [
      _buildHomeTab(),
      _buildPhotosTab(),
      _buildCommandsTab(),
      _buildProfileTab(),
    ];
    return IndexedStack(
      index: _currentIndex,
      children: tabs,
    );
  }

  Widget _buildHomeTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 2), // 
              _buildTopCard(),
            ],
          ),
        ),
        SliverToBoxAdapter(child: _buildQuickActions()),
        _buildHistorySection(),
        const SliverToBoxAdapter(child: SizedBox(height: 24)), //padding en bas de la page des actions
        SliverToBoxAdapter(child: _buildAdCarousel()),
        const SliverToBoxAdapter(child: SizedBox(height: 140)), //padding en bas de la page des carousels
      ],
    );
  }

  Widget _buildPhotosTab() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.only(top: 100),
      child: FutureBuilder<List<String>>(
        future: _albumImagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune image trouvée.'));
          } else {
            final images = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16.0,
                crossAxisSpacing: 16.0,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final imageUrl = images[index];
                final isSelected = _selectedImages.contains(imageUrl);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedImages.remove(imageUrl);
                    } else {
                      _selectedImages.add(imageUrl);
                    }
                    _calculateTotal();
                  }),
                  child: Stack(
                    children: [
                      Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0)),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator()),
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                      if (isSelected)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.check_circle,
                              color: AppColors.accent, size: 30),
                        ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  void _clearCart() {
    setState(() {
      _selectedImages.clear();
      _photoDetails.clear();
      _calculateTotal(); // Recalculate total to 0
    });
  }

  Widget _buildCommandsTab() {
    if (_isLoadingPrices) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: AppColors.background,
      padding:
          const EdgeInsets.only(bottom: 140, top: 5), // Adjusted bottom padding
      child: Stack(
        // Added Stack for background
        children: [
          const Positioned.fill(
            child: GeometricBackground(), // Apply geometric background here
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SegmentedButton<CartMode>(
                  segments: const [
                    ButtonSegment(
                        value: CartMode.detail, label: Text('Par détail')),
                    ButtonSegment(
                        value: CartMode.batch, label: Text('Par lot')),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: (Set<CartMode> newSelection) {
                    setState(() {
                      _selectedMode = newSelection.first;
                      _calculateTotal();
                    });
                  },
                ),
              ),
              Expanded(
                child: _selectedImages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 80, color: AppColors.textSecondary),
                            SizedBox(height: 16),
                            Text(
                              'Votre panier est vide.\nSélectionnez des photos pour commencer une commande !',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : _selectedMode == CartMode.detail
                        ? _buildDetailCart()
                        : _buildBatchCart(),
              ),
              if (_selectedImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    children: [
                      TextButton.icon(
                        onPressed: _clearCart,
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        label: const Text('Vider le panier',
                            style: TextStyle(color: AppColors.error)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showValidationPopup,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Valider'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _calculateTotal() {
    if (_prices == null) return;

    double total = 0;
    for (final imageUrl in _selectedImages) {
      final details = _photoDetails[imageUrl];
      if (details != null) {
        final price = _prices?[details['size']] ?? 0;
        total += price * (details['quantity'] as int);
      }
    }

    if (_isExpress && _selectedImages.length <= 10) {
      total += 1500;
    }

    setState(() {
      _totalPrice = total;
    });
  }

  Widget _buildDetailCart() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _selectedImages.length,
      itemBuilder: (context, index) {
        final imageUrl = _selectedImages.elementAt(index);
        if (!_photoDetails.containsKey(imageUrl)) {
          _photoDetails[imageUrl] = {'size': '10x15 cm', 'quantity': 1};
        }
        final photoDetails = _photoDetails[imageUrl]!;
        final price = _prices![photoDetails['size']] ?? 0;
        final subtotal = price * (photoDetails['quantity'] as int);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            key: ValueKey(imageUrl),
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: (imageUrl.startsWith('http'))
                      ? Image.network(imageUrl,
                          width: 60, height: 60, fit: BoxFit.cover)
                      : Image.file(File(imageUrl),
                          width: 60, height: 60, fit: BoxFit.cover),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Photo ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${subtotal.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 236, 7, 7), // Blue background
                      shape: BoxShape.circle, // Circular shape
                    ),
                    child: const Icon(Icons.delete,
                        size: 18, color: Colors.white), // White icon
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedImages.remove(imageUrl);
                      _photoDetails.remove(imageUrl);
                      _calculateTotal();
                    });
                  },
                ),
              ],
            ),
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Taille :'),
                        DropdownButton<String>(
                          value: photoDetails['size'],
                          items: _prices!.keys
                              .map((size) => DropdownMenuItem(
                                  value: size, child: Text(size)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _photoDetails[imageUrl]!['size'] = value;
                                _calculateTotal();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quantité :'),
                        Row(
                          children: [
                            IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  if (photoDetails['quantity'] > 1) {
                                    setState(() {
                                      _photoDetails[imageUrl]!['quantity'] -= 1;
                                      _calculateTotal();
                                    });
                                  }
                                }),
                            Text('${photoDetails['quantity']}'),
                            IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  setState(() {
                                    _photoDetails[imageUrl]!['quantity'] += 1;
                                    _calculateTotal();
                                  });
                                }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBatchCart() {
    // For batch mode, we need a way to set dimensions for all photos
    String? commonSize;
    if (_photoDetails.isNotEmpty) {
      final sizes =
          _photoDetails.values.map((d) => d['size'] as String).toSet();
      if (sizes.length == 1) {
        commonSize = sizes.first;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(5.0),
          child: Align(
            alignment: Alignment.centerRight, // Align to the right
            child: SizedBox(
              width: 180, // Reduced width
              child: DropdownButtonFormField<String>(
                value: commonSize,
                decoration: InputDecoration(
                  labelText: 'Dimension', // Shorter label for smaller input
                  labelStyle: const TextStyle(fontSize: 12), // Smaller font size for the label
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), // Rounded borders
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced here
                  prefixIcon:
                      const Icon(Icons.straighten, size: 16), // Reduced here
                ),
                items: _prices!.keys
                    .map((size) =>
                        DropdownMenuItem(value: size, child: Text(size)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      for (final key in _photoDetails.keys) {
                        _photoDetails[key]!['size'] = value;
                      }
                      _calculateTotal();
                    });
                  }
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              final imageUrl = _selectedImages.elementAt(index);
              return Stack(
                children: [
                  (imageUrl.startsWith('http'))
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Image.file(File(imageUrl), fit: BoxFit.cover),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImages.remove(imageUrl);
                          _photoDetails.remove(imageUrl);
                          _calculateTotal();
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(
                              255, 238, 33, 6), // Blue background
                          borderRadius:
                              BorderRadius.circular(10), // Keep rounded corners
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close,
                            size: 12, color: Colors.white), // White icon
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showValidationPopup() {
    // Use a local variable for the state of the switch inside the dialog
    bool isExpressDelivery = _isExpress;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Mode de Livraison',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Livraison Xpress',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text:
                                'Votre commande sera traitée en priorité. Et il vous en coûtera ',
                            style: TextStyle(color: Colors.black87),
                          ),
                          TextSpan(
                            text: '1500 FCFA',
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 140, 0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' de plus.',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    value: isExpressDelivery,
                    onChanged: (bool value) {
                      setDialogState(() {
                        isExpressDelivery = value;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: <Widget>[
                TextButton(
                  child: const Text('Modifier'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white),
                  child: const Text('Suivant'),
                  onPressed: () {
                    // Update the main screen's state before navigating
                    setState(() {
                      _isExpress = isExpressDelivery;
                    });
                    Navigator.of(context).pop(); // Close the dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderSummaryScreen(
                          orderDetails: _photoDetails,
                          isExpress: _isExpress,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProfileTab() {
    return Container(); // This tab is no longer shown, replaced by ProfilePage
  }

  Widget _buildTopCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16.0, vertical: 8.0), // Consistent padding
      child: Card(
        clipBehavior: Clip.antiAlias, // Ensures content respects card borders
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8, // Slightly more prominent shadow
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9, // Common aspect ratio for images
              child: Image.asset(
                'assets/carousel/mxx.jpeg',
                fit: BoxFit.cover, // Fill the space, crop if necessary
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  // Text(
                  //   'Immortalisez vos moments précieux en un clic !',
                  //   style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  //     fontWeight: FontWeight.bold,
                  //     color: AppColors.textPrimary,
                  //   ),
                  //   textAlign: TextAlign.center,
                  // ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.help_outline, size: 24),
                    label: const Text("Comment ça marche ?",
                        style: TextStyle(fontSize: 16)),
                    onPressed: () => _showHowItWorksDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.primary, // Primary color for the button
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)), // Rounded corners
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 4,
                    ),
                  )
                      .animate()
                      .fade(duration: 800.ms, delay: 200.ms)
                      .slideY(begin: 0.2, curve: Curves.easeOut),
                ],
              ),
            ),
          ],
        ),
      )
          .animate()
          .fade(duration: 500.ms)
          .slideY(begin: 0.1, curve: Curves.easeOut),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6.0, 2.0, 16.0, 2.0), //padding en bas de la page des actions
      child: GridView.builder(
        shrinkWrap: true, // Important for nested scroll views
        physics:
            const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 items per row
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 0.85, // Adjust aspect ratio for better look
        ),
        itemCount: 6, // Total number of quick actions
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return _buildAnimatedQuickActionButton(
                icon: Icons.photo_album,
                label: 'Portfolio',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PortfolioScreen())),
                delay: 0.ms,
              );
            case 1:
              return _buildAnimatedQuickActionButton(
                icon: Icons.archive_outlined,
                label: 'Mes commandes',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HistoryScreen())),
                delay: 100.ms,
              );
            case 2:
              return _buildAnimatedQuickActionButton(
                icon: Icons.straighten,
                label: 'Prix & dimensions',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PricingScreen())),
                delay: 200.ms,
              );
            case 3:
              return _buildAnimatedQuickActionButton(
                icon: Icons.calendar_today, // Changed icon
                label: 'Réserver', // Changed label
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => BookingScreen())),
                delay: 300.ms,
              );
            case 4:
              return _buildAnimatedQuickActionButton(
                icon: Icons.checklist_rtl,
                label: 'Mes réservations',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => BookingStatusScreen())),
                delay: 400.ms,
              );
            case 5:
              return _buildAnimatedQuickActionButton(
                icon: Icons.chat_bubble_outline,
                label: 'Nous contacter',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ContactScreen())),
                delay: 500.ms,
              );
            default:
              return Container(); // Fallback
          }
        },
      ),
    );
  }

  Widget _buildAnimatedQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.4), // Glassmorphic background
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Inner blur
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.primary, size: 36), // Larger icon
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate()
          .fade(delay: delay, duration: 400.ms)
          .slideY(begin: 0.1, curve: Curves.easeOut),
    );
  }

  Widget _buildHistorySection() {

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16.0, 2.0, 16.0, 0.0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historique récent',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HistoryScreen())),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text("Voir tout"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<HistoryItem>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final recentHistory = snapshot.data ?? [];
                if (recentHistory.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Aucune activité récente.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: recentHistory.length,
                  itemBuilder: (context, index) {
                    final item = recentHistory[index];
                    return _buildHistoryCard(item, index);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(HistoryItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card.withOpacity(0.4),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Icon(item.icon, color: AppColors.primary),
              ),
              title: Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              subtitle: Text(
                DateFormat('dd MMM yyyy').format(item.date),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppColors.textSecondary),
              onTap: () {
                if (item.type == HistoryItemType.booking) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const BookingStatusScreen()));
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HistoryScreen()));
                }
              },
            ),
          ),
        ),
      ),
    )
        .animate()
        .fade(delay: (100 * index).ms, duration: 400.ms)
        .slideX(begin: 0.05, curve: Curves.easeOut);
  }

  Widget _buildAdCarousel() {
    final List<String> localImages = [
      'assets/carousel/Ajouter un sous-titre.png',
      'assets/carousel/car.jpg',
      'assets/carousel/car1.jpg',
      'assets/carousel/pflex.jpeg',
      'assets/carousel/Pink Modern Pink October Instagram Post  (1).png',
      'assets/carousel/Pink Modern Pink October Instagram Post  (2).png',
      'assets/carousel/Pink Modern Pink October Instagram Post .png',
      'assets/images/pro.png',
    ];

    Widget buildItem(String path, bool isAsset) {
      return Container(
        width: double.infinity,
        margin: EdgeInsets.zero, // Remove margins for edge-to-edge look
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.4), // Glassmorphic background
          borderRadius: BorderRadius.circular(20), // Increased border radius
          border:
              Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.0), // Fine blue border
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), // Add shadow for depth
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(20), // Match container's border radius
          child: isAsset
              ? Image.asset(path,
                  fit: BoxFit.cover, // Ensures the image fills the container
                  width: double.infinity,
                  height: double.infinity)
              : Image.network(path,
                  fit: BoxFit.cover, // Ensures the image fills the container
                  width: double.infinity,
                  height: double.infinity),
        ),
      ).animate().fade(duration: 500.ms).slideX(
          begin: 0.1,
          curve: Curves.easeOut); // Apply simple fade and slide animation
    }

    Widget buildLocalCarousel(String message) {
      return Column(
        children: [
          CarouselSlider.builder(
            itemCount: localImages.length,
            itemBuilder: (context, index, realIndex) =>
                buildItem(localImages[index], true),
            options: CarouselOptions(
                height: 150.0,
                viewportFraction: 0.92,
                enlargeCenterPage: false,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 4)),
          ),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(message,
                  style: const TextStyle(color: AppColors.textSecondary)),
            )
        ],
      );
    }

    return _isOffline
        ? buildLocalCarousel(
            "Impossible de charger les promotions. Mode hors-ligne.")
        : FutureBuilder<List<Promotion>>(
            future: _promotionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return buildLocalCarousel(
                    "Impossible de charger les promotions en ligne.");
              }
              final onlinePromotions = snapshot.data!;
              return CarouselSlider.builder(
                itemCount: onlinePromotions.length,
                itemBuilder: (context, index, realIndex) {
                  final promo = onlinePromotions[index];
                  // On gère l'URL de l'image (si relative au backend)
                  final imageUrl = promo.imageUrl.startsWith('http')
                      ? promo.imageUrl
                      : '${ApiService.rootUrl}${promo.imageUrl}';

                  return GestureDetector(
                    onTap: () async {
                      if (promo.targetUrl != null && promo.targetUrl!.isNotEmpty) {
                        final uri = Uri.parse(promo.targetUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      }
                    },
                    child: buildItem(imageUrl, false),
                  );
                },
                options: CarouselOptions(
                    height: 150.0,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 5),
                    enlargeCenterPage: false,
                    viewportFraction: 0.92),
              );
            },
          );
  }

  Widget _buildFloatingBottomNavBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            backgroundColor: Colors.white.withOpacity(0.3),
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textPrimary.withOpacity(0.6),
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.photo_album), label: 'Photos'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_cart), label: 'Commandes'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowItWorksDialog() {
    final steps = [
      {
        'icon': Icons.photo_library_outlined,
        'title': 'Sélectionnez vos photos',
        'subtitle':
            'Parcourez votre galerie et choisissez vos meilleurs souvenirs.',
      },
      {
        'icon': Icons.straighten_outlined,
        'title': 'Format et quantité',
        'subtitle':
            'Choisissez la taille d\'impression et le nombre de copies.',
      },
      {
        'icon': Icons.payment_outlined,
        'title': 'Validez et payez',
        'subtitle':
            'Vérifiez votre commande et payez en toute sécurité.',
      },
      {
        'icon': Icons.local_shipping_outlined,
        'title': 'Recevez votre commande',
        'subtitle':
            'Nous préparons vos photos et vous notifions dès qu\'elles sont prêtes !',
      },
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              content: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.92)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark ? Colors.white24 : AppColors.primary.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background architectural elements
                        const Positioned.fill(child: GeometricBackground()),

                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                "Comment ça marche ?",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: isDark ? Colors.white : AppColors.primary,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Steps with Timeline
                              Stack(
                                children: [
                                  // Timeline Line
                                  Positioned(
                                    left: 24,
                                    top: 40,
                                    bottom: 60,
                                    child: Container(
                                      width: 2,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            AppColors.primary.withOpacity(0.5),
                                            AppColors.primary.withOpacity(0.1),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    children: List.generate(steps.length, (idx) {
                                      final step = steps[idx];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 24.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Icon Hub
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.primary.withOpacity(0.3)
                                                    : Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primary.withOpacity(0.2),
                                                    blurRadius: 12,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  step['icon'] as IconData,
                                                  color: AppColors.primary,
                                                  size: 24,
                                                ),
                                              ),
                                            ).animate().scale(
                                              delay: (150 * idx).ms,
                                              duration: 400.ms,
                                              curve: Curves.elasticOut,
                                            ),
                                            const SizedBox(width: 20),
                                            // Content
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    step['title'] as String,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 18,
                                                      color: isDark ? Colors.white : AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    step['subtitle'] as String,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? Colors.white.withOpacity(0.95)
                                                          : AppColors.textPrimary,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ).animate().fadeIn(delay: (100 * idx).ms).slideX(begin: 0.1);
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Bottom Button
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    "C'EST PARTI !",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Top Right Close Button
                        Positioned(
                          top: 16,
                          right: 16,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black12,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
