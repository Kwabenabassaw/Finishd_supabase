import 'package:flutter/material.dart';

// 💡 The logic to show the share drawer is defined here.
void showShareBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: false, // Don't allow it to take up the whole screen
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(25.0),
      ),
    ),
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Very important: makes it wrap content
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              "Share To",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            
            // Share Options Grid
            SizedBox(
              height: 100, // Fixed height for the horizontal list
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildShareOption(Icons.message, "SMS", Colors.green),
                  _buildShareOption(Icons.email, "Email", Colors.red),
                  _buildShareOption(Icons.facebook, "Facebook", Colors.blue),
                  _buildShareOption(Icons.alternate_email, "Twitter", Colors.lightBlue),
                  _buildShareOption(Icons.share, "More", Colors.black),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Helper widget to build the individual share icons
Widget _buildShareOption(IconData icon, String label, Color color) {
  return Padding(
    padding: const EdgeInsets.only(right: 20.0),
    child: Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}