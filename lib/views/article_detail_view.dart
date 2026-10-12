import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/education_article.dart';

class ArticleDetailView extends StatelessWidget {
  const ArticleDetailView({super.key, required this.article});

  final EducationArticle article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Edukasi Kesehatan',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Gambar Utama dengan Shadow & Border Radius
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  article.imageUrl!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 20),

            // 2. Category Chip & Estimasi Waktu Baca
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    article.category.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  '3 mnt baca',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Judul Artikel
            Text(
              article.title,
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),

            // 4. Highlight Box (Kotak Pesan Penting)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Penting: Kesehatan keluarga berawal dari kebersihan lingkungan sekitar kita.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Isi Konten Artikel
            Text(
              article.content,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: const Color(0xFF4A4A4A),
                height: 1.7, // Spasi baris agar nyaman dibaca
              ),
            ),
          ],
        ),
      ),
    );
  }
}