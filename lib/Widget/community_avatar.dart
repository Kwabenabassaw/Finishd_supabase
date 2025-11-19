import 'package:flutter/material.dart';

class CommunityAvatarList extends StatelessWidget {
  const CommunityAvatarList({super.key});

  @override
  Widget build(BuildContext context) {
    final avatars = [
      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSai1mBrKQfxAr27kfPwyhZ49L0jymPguzKCL_FIh1K7PgiNlRDJuoZ547lFWpWjiN7zfJ7Vg&s=10",
      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSdx0PHBRecFXceWASqeF31-wwycc7B0PmaGbU1FiAnaCWQcGt_zlpZQkPcKRXJ1EOk6rsFGw&s=10"
    ];
    final names = ['Steve', 'Gray Man', 'Nowhere', 'Mission Impossible', 'Tomorrow'];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: avatars.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(avatars[index]),
                ),
                const SizedBox(height: 4),
                Text(
                  names[index],
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
