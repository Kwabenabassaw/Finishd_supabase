import 'package:flutter/material.dart';

class CommunityAvatarList extends StatelessWidget {
  const CommunityAvatarList({super.key});

  @override
  Widget build(BuildContext context) {
    final avatars = [
      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSai1mBrKQfxAr27kfPwyhZ49L0jymPguzKCL_FIh1K7PgiNlRDJuoZ547lFWpWjiN7zfJ7Vg&s=10",
      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSdx0PHBRecFXceWASqeF31-wwycc7B0PmaGbU1FiAnaCWQcGt_zlpZQkPcKRXJ1EOk6rsFGw&s=10",
      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR_p_v1Q2-3z3y5r_4-2Z_D3-p_q-3z3y5r_4&s=10",
      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT_p_v1Q2-3z3y5r_4-2Z_D3-p_q-3z3y5r_4&s=10",
    ];
    final names = ['Movie Geeks', 'Action Fans', 'Sci-Fi Hub', 'Drama Club'];

    return SizedBox(
      height: 100, // Reduced from 140
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ), // Added horizontal padding
        itemCount: avatars.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.green, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28, // Reduced from 36
                    backgroundColor: Colors.grey[900],
                    backgroundImage: NetworkImage(avatars[index]),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  names[index],
                  style: const TextStyle(
                    fontSize: 12, // Reduced from 13
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
