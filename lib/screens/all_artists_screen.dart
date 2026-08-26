import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_image.dart';
import 'artist_screen.dart';

class ArtistInfo {
  final String name;
  final String imageUrl;

  const ArtistInfo(this.name, this.imageUrl);
}

const List<ArtistInfo> kAllArtists = [
  // Indian Artists
  ArtistInfo('Arijit Singh', 'https://c.saavncdn.com/artists/Arijit_Singh_004_20241118063717_500x500.jpg'),
  ArtistInfo('Shreya Ghoshal', 'https://c.saavncdn.com/artists/Shreya_Ghoshal_007_20241101074144_500x500.jpg'),
  ArtistInfo('Kishore Kumar', 'https://c.saavncdn.com/artists/Kishore_Kumar_500x500.jpg'),
  ArtistInfo('Lata Mangeshkar', 'https://c.saavncdn.com/artists/Lata_Mangeshkar_004_20230623105323_500x500.jpg'),
  ArtistInfo('Udit Narayan', 'https://c.saavncdn.com/artists/Udit_Narayan_004_20241029065120_500x500.jpg'),
  ArtistInfo('Alka Yagnik', 'https://c.saavncdn.com/artists/Alka_Yagnik_002_20220314192930_500x500.jpg'),
  ArtistInfo('Kumar Sanu', 'https://c.saavncdn.com/artists/Kumar_Sanu_500x500.jpg'),
  ArtistInfo('AR Rahman', 'https://c.saavncdn.com/artists/AR_Rahman_002_20210120084455_500x500.jpg'),
  ArtistInfo('KK', 'https://c.saavncdn.com/artists/KK_500x500.jpg'),
  ArtistInfo('Sonu Nigam', 'https://c.saavncdn.com/artists/Sonu_Nigam_003_20260813182013_500x500.jpg'),
  ArtistInfo('Badshah', 'https://c.saavncdn.com/artists/Badshah_006_20241118064015_500x500.jpg'),
  ArtistInfo('Diljit Dosanjh', 'https://c.saavncdn.com/artists/Diljit_Dosanjh_005_20231025073054_500x500.jpg'),
  ArtistInfo('AP Dhillon', 'https://c.saavncdn.com/artists/AP_Dhillon_004_20251023102150_500x500.jpg'),
  
  // Global Artists
  ArtistInfo('Taylor Swift', 'https://c.saavncdn.com/artists/Taylor_Swift_003_20200226074119_500x500.jpg'),
  ArtistInfo('The Weeknd', 'https://c.saavncdn.com/artists/The_Weeknd_002_20241003071400_500x500.jpg'),
  ArtistInfo('Justin Bieber', 'https://c.saavncdn.com/artists/Justin_Bieber_005_20201127112218_500x500.jpg'),
  ArtistInfo('Ed Sheeran', 'https://c.saavncdn.com/artists/Ed_Sheeran_002_20250625073038_500x500.jpg'),
  ArtistInfo('Drake', 'https://c.saavncdn.com/artists/Drake_006_20260520062317_500x500.jpg'),
  ArtistInfo('Eminem', 'https://c.saavncdn.com/artists/Eminem_003_20240403152835_500x500.jpg'),
  ArtistInfo('Billie Eilish', 'https://c.saavncdn.com/artists/Billie_Eilish_20190211151539_500x500.jpg'),
  ArtistInfo('Ariana Grande', 'https://c.saavncdn.com/artists/Ariana_Grande_007_20260616180049_500x500.jpg'),
  ArtistInfo('Post Malone', 'https://c.saavncdn.com/artists/Post_Malone_004_20190911070147_500x500.jpg'),
  ArtistInfo('Dua Lipa', 'https://c.saavncdn.com/artists/Dua_Lipa_004_20231120090922_500x500.jpg'),
  ArtistInfo('Bruno Mars', 'https://c.saavncdn.com/artists/Bruno_Mars_003_20260324060413_500x500.jpg'),
];

class AllArtistsScreen extends StatelessWidget {
  const AllArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Artists'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          childAspectRatio: 0.75, // Adjust height for the text below image
        ),
        itemCount: kAllArtists.length,
        itemBuilder: (context, index) {
          final artist = kAllArtists[index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ArtistScreen(artistId: artist.name),
                ),
              );
            },
            child: Column(
              children: [
                Expanded(
                  child: ClipOval(
                    child: PremiumImage(
                      imageUrl: artist.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 1000,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  artist.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
