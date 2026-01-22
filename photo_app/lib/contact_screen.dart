import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:photo_app/utils/colors.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactez-nous'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ContactInfoTile(
              icon: Icons.location_on,
              title: 'Notre Studio',
              subtitle: 'Rue de la Photo, Lomé, Togo',
            ),
            const SizedBox(height: 24),
            const _ContactInfoTile(
              icon: Icons.phone,
              title: 'Téléphone',
              subtitle: '+228 90 00 00 00 / +228 91 00 00 00',
            ),
            const SizedBox(height: 24),
            const _ContactInfoTile(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'contact@studiophoto.com',
            ),
            const SizedBox(height: 24),
            const _ContactInfoTile(
              icon: Icons.access_time,
              title: 'Horaires d\'ouverture',
              subtitle: 'Lundi - Samedi\n09:00 - 18:00',
            ),
            const SizedBox(height: 48),
            Text(
              'Suivez-nous',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SocialButton(icon: FontAwesomeIcons.facebook, url: 'https://facebook.com/your-page'),
                _SocialButton(icon: FontAwesomeIcons.twitter, url: 'https://twitter.com/your-handle'),
                _SocialButton(icon: FontAwesomeIcons.instagram, url: 'https://instagram.com/your-profile'),
                _SocialButton(icon: FontAwesomeIcons.linkedin, url: 'https://linkedin.com/in/your-profile'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ContactInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 32),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String url;

  const _SocialButton({required this.icon, required this.url});

  Future<void> _launchUrl(BuildContext context) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: FaIcon(icon, color: AppColors.primary, size: 36),
      onPressed: () => _launchUrl(context),
      iconSize: 40,
    );
  }
}