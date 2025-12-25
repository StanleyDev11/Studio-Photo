import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import 'order_summary_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final int userId;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<String> _selectedImages = {}; // Images sélectionnées pour commande
  Future<List<String>>? _albumImagesFuture; // Liste des images chargées
  File? _avatar; // Avatar personnalisé
  final Map<String, Map<String, dynamic>> _photoDetails =
      {}; // Détails des photos

  @override
  void initState() {
    super.initState();
    _albumImagesFuture = fetchAlbumImages(widget.userId); // Charger les images
  }

  // Méthode pour récupérer les images depuis l'API
  Future<List<String>> fetchAlbumImages(int userId) async {
    final url = Uri.parse(
        'http://10.0.2.2/studio/get_album_images.php?user_id=$userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return List<String>.from(data['images']);
        } else {
          throw Exception(data['message'] ?? 'Erreur inconnue');
        }
      } else {
        throw Exception('Erreur du serveur : ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau : $e');
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

  void _submitOrder(Map<String, Map<String, dynamic>> photoDetails) {
    // Exemple : Afficher un message pour confirmer la commande
    print('Commandes soumises : $photoDetails');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Commande soumise avec succès !')),
    );
    setState(() {
      _selectedImages.clear();
    });
  }

  Widget _buildPhotosTab() {
    return FutureBuilder<List<String>>(
      future: _albumImagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Erreur : ${snapshot.error}'),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('Aucune image trouvée.'),
          );
        } else {
          final images = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(12.0),
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
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedImages.remove(imageUrl);
                    } else {
                      _selectedImages.add(imageUrl);
                    }
                  });
                },
                child: Stack(
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green[400],
                          size: 30,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildCommandsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Vos Commandes',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              final imageUrl = _selectedImages.elementAt(index);

              if (!_photoDetails.containsKey(imageUrl)) {
                _photoDetails[imageUrl] = {
                  'size': '10x15 cm',
                  'quantity': 1,
                };
              }

              final photoDetails = _photoDetails[imageUrl]!;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.network(
                        imageUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Taille :'),
                          DropdownButton<String>(
                            value: photoDetails['size'],
                            items: ['10x15 cm', '15x20 cm', '20x30 cm']
                                .map((size) => DropdownMenuItem(
                                      value: size,
                                      child: Text(size),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _photoDetails[imageUrl]!['size'] = value;
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
                                    });
                                  }
                                },
                              ),
                              Text('${photoDetails['quantity']}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  setState(() {
                                    _photoDetails[imageUrl]!['quantity'] += 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              if (_selectedImages.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aucune image sélectionnée.')),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderSummaryScreen(
                      orderDetails: _photoDetails,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Voir le récapitulatif'),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _changeAvatar,
            child: CircleAvatar(
              radius: 60,
              backgroundImage: _avatar != null
                  ? FileImage(_avatar!)
                  : const AssetImage('assets/images/default_avatar.png')
                      as ImageProvider,
              child: _avatar == null
                  ? const Icon(Icons.camera_alt, size: 30, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.userName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            label: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildPhotosTab(),
      _buildCommandsTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio Photo'),
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_album),
            label: 'Photos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Commandes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
