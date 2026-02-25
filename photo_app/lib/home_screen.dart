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
import 'package:Picon/photo_preview_screen.dart';
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

// ── Utilitaires qualité d'impression ──────────────────────
enum PrintQuality { recommended, acceptable, unsuitable }

double _parseDimensionAspect(String dimension) {
  final matches = RegExp(r'(\d+([.,]\d+)?)').allMatches(dimension).toList();
  if (matches.length >= 2) {
    final w = double.tryParse(matches[0].group(1)!.replaceAll(',', '.')) ?? 1;
    final h = double.tryParse(matches[1].group(1)!.replaceAll(',', '.')) ?? 1;
    return h == 0 ? 1 : w / h;
  }
  return 1;
}

double _computeKeepFraction(Size imageSize, double targetAspect) {
  final imageAspect = imageSize.width / imageSize.height;
  if (imageAspect > targetAspect) return targetAspect / imageAspect;
  return imageAspect / targetAspect;
}

PrintQuality _computePrintQuality(double keepFraction) {
  if (keepFraction >= 0.90) return PrintQuality.recommended;
  if (keepFraction >= 0.75) return PrintQuality.acceptable;
  return PrintQuality.unsuitable;
}

IconData _qualityIcon(PrintQuality q) {
  switch (q) {
    case PrintQuality.recommended: return Icons.check_circle;
    case PrintQuality.acceptable:  return Icons.warning_amber_rounded;
    case PrintQuality.unsuitable:  return Icons.cancel;
  }
}

Color _qualityColor(PrintQuality q) {
  switch (q) {
    case PrintQuality.recommended: return const Color(0xFF2E7D32);
    case PrintQuality.acceptable:  return const Color(0xFFE65100);
    case PrintQuality.unsuitable:  return const Color(0xFFC62828);
  }
}

String _qualityLabel(PrintQuality q) {
  switch (q) {
    case PrintQuality.recommended: return 'Recommandé';
    case PrintQuality.acceptable:  return 'Acceptable';
    case PrintQuality.unsuitable:  return 'Déconseillé';
  }
}
// ──────────────────────────────────────────────────────────

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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
  bool _isSuggesting = false;
  double _totalPrice = 0.0;
  Map<String, double>? _prices;
  bool _isLoadingPrices = true;
  bool _isUploading = false;
  Future<List<Promotion>>? _promotionsFuture;
  Future<List<HistoryItem>>? _historyFuture;
  RealtimeService? _realtimeService;
  List<dynamic> _featuredContents = []; // FeaturedContent depuis la BDD
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
    _loadFeaturedContents();
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
    WidgetsBinding.instance.addObserver(this);

    // Si un paiement vient d'être validé, on vide le panier après le premier rendu
    if (ApiService.shouldClearCart) {
      ApiService.shouldClearCart = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _clearCart());
    }
  }

  void _initRealtime() {
    // On utilise l'URL de base de l'API mais avec le protocole ws
    final wsUrl = ApiService.rootUrl.replaceFirst('http', 'ws') + '/ws';
    _realtimeService = RealtimeService(
      wsUrl: wsUrl,
      onNotification: (type) {
        if (mounted) {
      // ignore: avoid_print — notification realtimée: $type
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

  Future<void> _handleGlobalRefresh() async {
    // This reloads everything - like a fake hot reload (global refresh)
    final List<Future<dynamic>> detailTasks = [
      _fetchRecentHistory().then((history) => setState(() => _historyFuture = Future.value(history))),
      ApiService.getAlbumImages(widget.userId).then((images) => setState(() => _albumImagesFuture = Future.value(images))),
      ApiService.fetchPromotions().then((promos) => setState(() => _promotionsFuture = Future.value(promos))),
      _fetchPrices(),
      ApiService.getAuthDetails().then((details) {
        if (details != null && mounted) {
          setState(() {
            _currentUserName = details['firstname'] ?? _currentUserName;
            _currentUserLastName = details['lastname'] ?? _currentUserLastName;
            _currentUserEmail = details['email'] ?? _currentUserEmail;
          });
        }
      }),
    ];
    await Future.wait(detailTasks);
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
      // ignore: avoid_print — erreur récupération historique
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
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
        setState(() {
          _isLoadingPrices = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ApiService.shouldClearCart) {
      ApiService.shouldClearCart = false;
      _clearCart();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    _realtimeService?.disconnect();
    super.dispose();
  }

  /// Vide le panier après un paiement réussi.
  void _clearCart() {
    if (!mounted) return;
    setState(() {
      _selectedImages.clear();
      _photoDetails.clear();
      _totalPrice = 0.0;
      _isExpress = false;
    });
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Index 2 is for Profile (previously 3)
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
    List<XFile> pickedFiles = [];
    try {
      pickedFiles = await picker.pickMultiImage(imageQuality: 50);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Impossible d'ouvrir la galerie. Vérifiez les permissions."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _isUploading = true;
      });

      try {
        final uploadedUrls = await ApiService.uploadPhotos(pickedFiles);

        if (_prices != null && _prices!.isNotEmpty) {
          // Copies temporaires : n'affectent le panier QUE si l'utilisateur confirme
          final tempImages = uploadedUrls.toList();
          final tempDetails = <String, Map<String, dynamic>>{};

          final confirmed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoPreviewScreen(
                images: tempImages,
                photoDetails: tempDetails,
                prices: _prices!,
              ),
            ),
          );

          if (confirmed == true && mounted) {
            setState(() {
              _selectedImages.addAll(tempImages);
              for (final e in tempDetails.entries) {
                _photoDetails[e.key] = e.value;
              }
              _calculateTotal();
              _currentIndex = 1; // Onglet Commandes
            });
          }
        }
      } catch (e) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Aucune photo sélectionnée ou accès refusé à la galerie."),
          ),
        );
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
      _buildCommandsTab(),
      _buildProfileTab(),
    ];
    return IndexedStack(
      index: _currentIndex,
      children: tabs,
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _handleGlobalRefresh,
      color: AppColors.primary,
      backgroundColor: Colors.white,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 2), // 
                _buildTopCard(),
              ],
            ),
          ),
          SliverToBoxAdapter(child: _buildOrderNowButton()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          _buildHistorySection(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)), //padding en bas de la page des actions
          SliverToBoxAdapter(child: _buildAdCarousel()),
          const SliverToBoxAdapter(child: SizedBox(height: 140)), //padding en bas de la page des carousels
        ],
      ),
    );
  }

  Widget _buildPhotosTab() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.only(top: 100),
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _albumImagesFuture = ApiService.getAlbumImages(widget.userId);
          });
          await _albumImagesFuture;
        },
        color: AppColors.primary,
        child: FutureBuilder<List<String>>(
          future: _albumImagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('Aucune image trouvée.')),
                  ],
                ),
              );
            } else {
              final images = snapshot.data!;
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
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
                    onTap: () async {
                      if (isSelected) {
                        setState(() {
                          _selectedImages.remove(imageUrl);
                          _calculateTotal();
                        });
                      } else {
                        // Vérifier si la photo est incompatible avec tous les formats
                        if (_prices != null && _prices!.isNotEmpty) {
                          final size = await _loadImageSizeLocal(imageUrl);
                          double bestKeep = 0;
                          for (final dim in _prices!.keys) {
                            final k = _computeKeepFraction(size, _parseDimensionAspect(dim));
                            if (k > bestKeep) bestKeep = k;
                          }
                          if (_computePrintQuality(bestKeep) == PrintQuality.unsuitable && mounted) {
                            final continueAnyway = await _showNoCompatibleFormatDialog();
                            if (!continueAnyway) return;
                          }
                        }
                        setState(() {
                          _selectedImages.add(imageUrl);
                          _calculateTotal();
                        });
                      }
                    },
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
      ),
    );
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
                child: Column(
                  children: [
                    SegmentedButton<CartMode>(
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.primary,
                        selectedForegroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      segments: const [
                        ButtonSegment(
                            value: CartMode.detail,
                            label: Text('Par détail'),
                            icon: Icon(Icons.photo_library_outlined)),
                        ButtonSegment(
                            value: CartMode.batch,
                            label: Text('Par lot'),
                            icon: Icon(Icons.collections_outlined)),
                      ],
                      selected: {_selectedMode},
                      onSelectionChanged: (Set<CartMode> newSelection) {
                        setState(() {
                          _selectedMode = newSelection.first;
                          _calculateTotal();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_selectedMode),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              _selectedMode == CartMode.detail
                                  ? "Une photo pour Une dimension"
                                  : "Plusieurs photos pour une même dimension",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _fetchPrices();
                  },
                  color: AppColors.primary,
                  child: _selectedImages.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 200),
                            Center(
                              child: Column(
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
                            ),
                          ],
                        )
                      : _selectedMode == CartMode.detail
                          ? _buildDetailCart()
                          : _buildBatchCart(),
                ),
              ),
              if (_selectedImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          if (_prices == null || _prices!.isEmpty) return;
                          // Copie des détails pour la preview — ne s'applique que si confirmé
                          final tempImages = _selectedImages.toList();
                          final tempDetails = <String, Map<String, dynamic>>{
                            for (final e in _photoDetails.entries)
                              e.key: Map<String, dynamic>.from(e.value),
                          };
                          final confirmed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PhotoPreviewScreen(
                                images: tempImages,
                                photoDetails: tempDetails,
                                prices: _prices!,
                              ),
                            ),
                          );
                          if (confirmed == true && mounted) {
                            setState(() {
                              // Applique les modifications de formats/quantités validées
                              for (final e in tempDetails.entries) {
                                if (_photoDetails.containsKey(e.key)) {
                                  _photoDetails[e.key] = e.value;
                                }
                              }
                              _calculateTotal();
                            });
                          }
                        },
                        icon: const Icon(Icons.crop, color: AppColors.primary),
                        label: const Text(
                          'Prévisualiser / Recadrer',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _clearCart,
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        label: const Text('Vider le panier',
                            style: TextStyle(color: AppColors.error)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _validateWithUnsuitableCheck,
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
                        const Text('Format :',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        // Format en lecture seule — modifiable via Prévisualiser
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.straighten,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                photoDetails['size'] as String? ?? '—',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
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
              // Hint discret : comment modifier le format
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline,
                        size: 12, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Pour changer le format, utilisez "Prévisualiser / Recadrer"',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
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
    String? commonSize;
    if (_photoDetails.isNotEmpty) {
      final sizes =
          _photoDetails.values.map((d) => d['size'] as String).toSet();
      if (sizes.length == 1) commonSize = sizes.first;
    }

    return Column(
      children: [
        // ── Sélecteur dimension globale + Suggestion ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dropdown compact
              DropdownButtonFormField<String>(
                value: commonSize,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Format pour toutes les photos',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  prefixIcon: const Icon(Icons.straighten, size: 16),
                  isDense: true,
                ),
                items: _prices!.keys
                    .map((size) =>
                        DropdownMenuItem(value: size, child: Text(size, style: const TextStyle(fontSize: 13))))
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
              const SizedBox(height: 8),
              // Bouton Suggérer bien visible
              ElevatedButton.icon(
                onPressed: _isSuggesting ? null : _suggestBestDimension,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _isSuggesting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _isSuggesting
                      ? 'Analyse en cours...'
                      : 'Suggérer la meilleure dimension',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // ── Bannière synthèse qualité ──
        if (commonSize != null)
          _buildQualitySummaryBanner(commonSize!),

        // ── Grille de photos ──
        Expanded(
          child: commonSize == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Choisissez une dimension pour voir la compatibilité avec vos photos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    final imageUrl = _selectedImages.elementAt(index);
                    return _BatchPhotoTile(
                      imageUrl: imageUrl,
                      dimension: commonSize!,
                      onRemove: () {
                        setState(() {
                          _selectedImages.remove(imageUrl);
                          _photoDetails.remove(imageUrl);
                          _calculateTotal();
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Bannière de synthèse : combien de photos sont recommandées/acceptables/déconseillées
  Widget _buildQualitySummaryBanner(String dimension) {
    final targetAspect = _parseDimensionAspect(dimension);
    final images = _selectedImages.toList();

    return FutureBuilder<List<PrintQuality>>(
      future: Future.wait(images.map((url) async {
        final size = await _loadImageSizeLocal(url);
        final keep = _computeKeepFraction(size, targetAspect);
        return _computePrintQuality(keep);
      })),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final qualities = snap.data!;
        final nbRec = qualities.where((q) => q == PrintQuality.recommended).length;
        final nbAcc = qualities.where((q) => q == PrintQuality.acceptable).length;
        final nbUns = qualities.where((q) => q == PrintQuality.unsuitable).length;
        final hasIssues = nbUns > 0 || nbAcc > 0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hasIssues
                ? const Color(0xFFFFF8E1)
                : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasIssues
                  ? const Color(0xFFFFB300).withOpacity(0.5)
                  : const Color(0xFF2E7D32).withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (nbRec > 0)
                _SummaryChip(
                    count: nbRec,
                    quality: PrintQuality.recommended),
              if (nbAcc > 0)
                _SummaryChip(
                    count: nbAcc,
                    quality: PrintQuality.acceptable),
              if (nbUns > 0)
                _SummaryChip(
                    count: nbUns,
                    quality: PrintQuality.unsuitable),
              if (!hasIssues)
                Row(children: const [
                  Icon(Icons.check_circle,
                      size: 15, color: Color(0xFF2E7D32)),
                  SizedBox(width: 4),
                  Text('Toutes les photos sont compatibles !',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold)),
                ]),
            ],
          ),
        );
      },
    );
  }

  /// Charge la taille d'une image localement (cache simple)
  final Map<String, Size> _batchSizeCache = {};
  Future<Size> _loadImageSizeLocal(String imageUrl) async {
    if (_batchSizeCache.containsKey(imageUrl)) {
      return _batchSizeCache[imageUrl]!;
    }
    final completer = Completer<Size>();
    final ImageProvider provider = imageUrl.startsWith('http')
        ? NetworkImage(imageUrl)
        : FileImage(File(imageUrl)) as ImageProvider;
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final size = Size(
            info.image.width.toDouble(), info.image.height.toDouble());
        _batchSizeCache[imageUrl] = size;
        if (!completer.isCompleted) completer.complete(size);
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) completer.complete(const Size(1, 1));
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }


  // ── Suggestion automatique de la meilleure dimension ──────────────────
  Future<void> _suggestBestDimension() async {
    if (_prices == null || _prices!.isEmpty || _selectedImages.isEmpty) return;
    setState(() => _isSuggesting = true);

    final images = _selectedImages.toList();
    final sizes = await Future.wait(images.map(_loadImageSizeLocal));

    // Scorer chaque dimension disponible
    String? bestDimension;
    double bestScore = -1;
    int bestRec = -1;

    for (final dim in _prices!.keys) {
      final aspect = _parseDimensionAspect(dim);
      double score = 0;
      int rec = 0;
      for (final size in sizes) {
        final keep = _computeKeepFraction(size, aspect);
        final q = _computePrintQuality(keep);
        if (q == PrintQuality.recommended) { score += 1.0; rec++; }
        else if (q == PrintQuality.acceptable) { score += 0.6; }
      }
      if (score > bestScore || (score == bestScore && rec > bestRec)) {
        bestScore = score;
        bestRec = rec;
        bestDimension = dim;
      }
    }

    if (bestDimension == null || !mounted) {
      setState(() => _isSuggesting = false);
      return;
    }

    // Appliquer la meilleure dimension globale
    setState(() {
      for (final key in _photoDetails.keys) {
        _photoDetails[key]!['size'] = bestDimension;
      }
      _calculateTotal();
      _isSuggesting = false;
    });

    // Calculer les photos encore déconseillées + leur meilleure dimension individuelle
    final chosenAspect = _parseDimensionAspect(bestDimension!);
    final List<Map<String, dynamic>> unsuitablePhotos = [];

    for (int i = 0; i < images.length; i++) {
      final url = images[i];
      final size = sizes[i];
      final keep = _computeKeepFraction(size, chosenAspect);
      if (_computePrintQuality(keep) == PrintQuality.unsuitable) {
        // Trouver la meilleure dimension individuelle pour cette photo
        String? bestIndivDim;
        double bestIndivScore = -1;
        for (final dim in _prices!.keys) {
          final k = _computeKeepFraction(size, _parseDimensionAspect(dim));
          if (k > bestIndivScore) {
            bestIndivScore = k;
            bestIndivDim = dim;
          }
        }
        unsuitablePhotos.add({
          'url': url,
          'bestDim': bestIndivDim ?? bestDimension,
          'keepFraction': bestIndivScore,
        });
      }
    }

    if (!mounted) return;

    if (unsuitablePhotos.isEmpty) {
      // Toutes les photos sont ok
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('Meilleure dimension : $bestDimension — Toutes les photos sont compatibles !')),
        ]),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
    } else {
      // Certaines photos restent déconseillées
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne titre
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Format partiellement incompatible',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              // Bouton X
              GestureDetector(
                onTap: () => messenger.hideCurrentSnackBar(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // Message
            Text(
              'Dimension : $bestDimension — ${unsuitablePhotos.length} photo(s) restent déconseillées.',
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
            const SizedBox(height: 12),
            // Bouton Adapter
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  _showUnsuitableAdaptDialog(unsuitablePhotos, bestDimension!);
                },
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Adapter les photos déconseillées',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFE65100),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE65100),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 10),
      ));
    }
  }

  /// Bottom sheet : photos déconseillées avec leur meilleure dimension individuelle
  void _showUnsuitableAdaptDialog(
      List<Map<String, dynamic>> unsuitablePhotos, String globalDim) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Titre
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.tune, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Dimensions recommandées',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'Ces ${unsuitablePhotos.length} photo(s) sont incompatibles avec "$globalDim". '
                        'Voici la meilleure dimension pour chacune.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Liste des photos déconseillées
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: unsuitablePhotos.length,
                    itemBuilder: (_, i) {
                      final photo = unsuitablePhotos[i];
                      final url = photo['url'] as String;
                      final bestDim = photo['bestDim'] as String;
                      final keep = ((photo['keepFraction'] as double) * 100).toInt();
                      final q = _computePrintQuality(photo['keepFraction'] as double);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: url.startsWith('http')
                              ? Image.network(url, width: 56, height: 56, fit: BoxFit.cover)
                              : Image.file(File(url), width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        title: Row(children: [
                          Icon(_qualityIcon(q), size: 14, color: _qualityColor(q)),
                          const SizedBox(width: 6),
                          Text(bestDim,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Conservation : $keep%',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            if (q == PrintQuality.unsuitable)
                              const Text(
                                'Aucun format pleinement compatible — moins mauvaise option',
                                style: TextStyle(fontSize: 10, color: Color(0xFFC62828)),
                              ),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(_qualityLabel(q),
                              style: TextStyle(fontSize: 11, color: _qualityColor(q))),
                          backgroundColor: _qualityColor(q).withOpacity(0.1),
                          side: BorderSide(color: _qualityColor(q).withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    },
                  ),
                ),
                // Bouton Appliquer
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          // Appliquer la dimension optimale à chaque photo déconseillée
                          for (final p in unsuitablePhotos) {
                            final url = p['url'] as String;
                            final bestDim = p['bestDim'] as String;
                            if (_photoDetails.containsKey(url)) {
                              _photoDetails[url]!['size'] = bestDim;
                            }
                          }
                          // Passer en mode Détail car les photos ont maintenant des tailles différentes
                          _selectedMode = CartMode.detail;
                          _calculateTotal();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Dimensions appliquées — passage en mode Détail'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Appliquer & passer en mode Détail'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
    // ── Vérifier si des photos sont déconseillées avant de valider ─────────
  Future<void> _validateWithUnsuitableCheck() async {
    if (_selectedMode == CartMode.batch && _selectedImages.isNotEmpty) {
      final commonSizeSet = _photoDetails.values.map((d) => d['size'] as String).toSet();
      if (commonSizeSet.length == 1) {
        final dim = commonSizeSet.first;
        final aspect = _parseDimensionAspect(dim);
        final images = _selectedImages.toList();
        final sizes = await Future.wait(images.map(_loadImageSizeLocal));
        final hasUnsuitable = sizes.any((size) {
          final keep = _computeKeepFraction(size, aspect);
          return _computePrintQuality(keep) == PrintQuality.unsuitable;
        });
        if (hasUnsuitable && mounted) {
          final proceed = await _showUnsuitableWarningDialog();
          if (!proceed) return;
        }
      }
    }
    _showValidationPopup();
  }


  // ── Dialog : aucun format compatible pour cette photo ─────────────────
  Future<bool> _showNoCompatibleFormatDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(children: const [
              Icon(Icons.photo_camera_back_outlined, color: Color(0xFFC62828), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text('Photo peu adaptée à l\'impression',
                    style: TextStyle(fontSize: 16)),
              ),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Cette photo n\'a aucun format d\'impression compatible.\n\n'
                  'Sa résolution ou ses proportions sont trop éloignées de nos formats disponibles, '
                  'ce qui entraînerait une qualité d\'impression très dégradée pour tous les formats.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: Color(0xFFE65100)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Conseil : utilisez une photo avec une résolution plus élevée ou des proportions plus standard.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFE65100)),
                    ),
                  ),
                ]),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Ne pas ajouter',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Ajouter quand même'),
              ),
            ],
          ),
        ) ??
        false;
  }
  Future<bool> _showUnsuitableWarningDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828), size: 28),
              SizedBox(width: 8),
              Text('Format déconseillé', style: TextStyle(fontSize: 17)),
            ]),
            content: const Text(
              'Une ou plusieurs photos seront fortement recadrées avec ce format.\n\n'
              'La qualité d\'impression sera très dégradée.\n\n'
              'Voulez-vous quand même continuer, ou choisir un autre format ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Changer le format',
                    style: TextStyle(color: AppColors.primary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Continuer quand même'),
              ),
            ],
          ),
        ) ??
        false;
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

  Future<void> _loadFeaturedContents() async {
    try {
      final contents = await ApiService.fetchActiveFeaturedContents();
      if (mounted) setState(() => _featuredContents = contents);
    } catch (_) {}
  }

  Widget _buildTopCard() {
    // Si des contenus mis en avant sont disponibles depuis la BDD
    if (_featuredContents.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          child: Column(
            children: [
              // Diaporama automatique des images de la BDD
              CarouselSlider.builder(
                itemCount: _featuredContents.length,
                options: CarouselOptions(
                  height: 200,
                  autoPlay: true,
                  autoPlayInterval: const Duration(milliseconds: 3500),
                  autoPlayAnimationDuration: const Duration(milliseconds: 700),
                  autoPlayCurve: Curves.easeInOut,
                  viewportFraction: 1.0,
                  enlargeCenterPage: false,
                  enableInfiniteScroll: _featuredContents.length > 1,
                ),
                itemBuilder: (ctx, i, _) {
                  final fc = _featuredContents[i];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        fc.imageUrl.startsWith('/') 
                            ? '${ApiService.rootUrl}${fc.imageUrl}' 
                            : fc.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/carousel/mxx.jpeg',
                          fit: BoxFit.cover,
                        ),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                color: AppColors.primary.withOpacity(0.05),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                      ),
                      // Gradient + titre en bas
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent
                              ],
                            ),
                          ),
                          child: (fc.title as String).isNotEmpty
                              ? Text(
                                  fc.title as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      // Petit bouton d'action avec flèche en bas à droite
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () async {
                            final action = fc.buttonAction as String;
                            if (action.isNotEmpty) {
                              final url = Uri.parse(action);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.help_outline, size: 24),
                      label: const Text("Comment ça marche ?",
                          style: TextStyle(fontSize: 16)),
                      onPressed: () => _showHowItWorksDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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

    // Fallback : image locale si pas de contenu depuis la BDD
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                'assets/carousel/mxx.jpeg',
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.help_outline, size: 24),
                    label: const Text("Comment ça marche ?",
                        style: TextStyle(fontSize: 16)),
                    onPressed: () => _showHowItWorksDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.fromLTRB(6.0, 2.0, 16.0, 0.0), //padding en bas de la page des actions
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

  Widget _buildOrderNowButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _quickPhotoOrder,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2F5BFF),
                  Color(0xFF4CA3FF),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add_a_photo, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Passer ma Commande',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fade(duration: 450.ms)
              .scale(begin: const Offset(0.98, 0.98), duration: 450.ms)
              .shimmer(
                duration: 1800.ms,
                color: Colors.white.withOpacity(0.35),
              ),
        ),
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
                height: 260.0,
                viewportFraction: 0.92, // Back to standard fraction
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
    return SizedBox(
      height: 83,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            selectedFontSize: 11,
            unselectedFontSize: 10,
            iconSize: 22,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_cart), label: 'Commandes'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: 'Profil'),
            ],
          ),
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

// ── Miniature photo avec indicateur de qualité (mode lot) ──────────────
class _BatchPhotoTile extends StatelessWidget {
  final String imageUrl;
  final String dimension;
  final VoidCallback onRemove;

  const _BatchPhotoTile({
    required this.imageUrl,
    required this.dimension,
    required this.onRemove,
  });

  Future<PrintQuality> _computeQuality() async {
    final completer = Completer<Size>();
    final ImageProvider provider = imageUrl.startsWith('http')
        ? NetworkImage(imageUrl)
        : FileImage(File(imageUrl)) as ImageProvider;
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
        if (!completer.isCompleted) completer.complete(size);
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) completer.complete(const Size(1, 1));
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    final size = await completer.future;
    final aspect = _parseDimensionAspect(dimension);
    final keep = _computeKeepFraction(size, aspect);
    return _computePrintQuality(keep);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageUrl.startsWith('http')
              ? Image.network(imageUrl, fit: BoxFit.cover)
              : Image.file(File(imageUrl), fit: BoxFit.cover),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4, left: 4,
            child: FutureBuilder<PrintQuality>(
              future: _computeQuality(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                  );
                }
                final q = snap.data!;
                return Tooltip(
                  message: _qualityLabel(q),
                  child: Icon(_qualityIcon(q), size: 18, color: _qualityColor(q),
                      shadows: const [Shadow(color: Colors.black45, blurRadius: 4)]),
                );
              },
            ),
          ),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFEE2106), borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip de synthèse qualité ───────────────────────────────
class _SummaryChip extends StatelessWidget {
  final int count;
  final PrintQuality quality;

  const _SummaryChip({required this.count, required this.quality});

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(quality);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_qualityIcon(quality), size: 15, color: color),
        const SizedBox(width: 4),
        Text('$count ${_qualityLabel(quality)}',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
