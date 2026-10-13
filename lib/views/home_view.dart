import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/education_article.dart';
import '../services/api_service.dart';
import 'article_detail_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.apiService,
    required this.onOpenReports,
  });

  final ApiService apiService;
  final VoidCallback onOpenReports;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late Future<List<EducationArticle>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    // Memanggil API sesuai perbaikan di awal
    _articlesFuture = widget.apiService.getArticles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Memberikan latar belakang abu-abu terang di luar frame mobile
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480), // Membatasi lebar maksimum layaknya layar HP
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Utama
                  const _HeroBanner(),
                  
                  const SizedBox(height: 24),
                  Text(
                    'Edukasi Kesehatan',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Panduan air bersih dan sanitasi lingkungan',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Daftar Artikel
                  FutureBuilder<List<EducationArticle>>(
                    future: _articlesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Gagal memuat data: ${snapshot.error}',
                            style: GoogleFonts.dmSans(color: Colors.red),
                          ),
                        );
                      }
                      
                      final articles = snapshot.data ?? [];
                      if (articles.isEmpty) {
                        return const Center(
                          child: Text('Belum ada artikel edukasi.'),
                        );
                      }

                      return Column(
                        children: articles.map((article) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ArticleTile(
                            article: article,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ArticleDetailView(article: article),
                              ),
                            ),
                          ),
                        )).toList(),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Klinik Sanitasi - Puskesmas Sumbersari',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// Banner Merah di Atas (Logo sudah pakai gambar lokal Anda)
// ==========================================================
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.jpg', // Sesuai dengan folder assets Anda
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: Icon(Icons.health_and_safety, color: Color(0xFFD32F2F)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KLINIK SANITASI',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'PUSKESMAS SUMBERSARI',
                    style: GoogleFonts.dmSans(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Lingkungan sehat,\nberawal dari kita.',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Akses informasi sanitasi dan sampaikan masalah lingkungan kepada petugas kami.',
            style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// Card Artikel (Desain Asli)
// ==========================================================
class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article, required this.onTap});

  final EducationArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: article.imageUrl != null && article.imageUrl!.isNotEmpty
              ? Image.network(
                  article.imageUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.article, color: Colors.grey),
                ),
        ),
        title: Text(
          article.category.toUpperCase(),
          style: GoogleFonts.dmSans(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              article.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}