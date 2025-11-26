import 'package:flutter/material.dart';

// Mock data for the friends list
final List<Map<String, String>> mockFriends = [
  {'name': 'Alice Howard', 'image': 'https://placehold.co/100x100/A855F7/FFFFFF?text=AH'},
  {'name': 'Edwin Mensah', 'image': 'https://placehold.co/100x100/3B82F6/FFFFFF?text=EM'},
  {'name': 'Abigail Williams', 'image': 'https://placehold.co/100x100/EC4899/FFFFFF?text=AW'},
  {'name': 'Josh Anderson', 'image': 'https://placehold.co/100x100/F59E0B/FFFFFF?text=JA'},
  {'name': 'Jenna Alberts', 'image': 'https://placehold.co/100x100/10B981/FFFFFF?text=JA'},
  {'name': 'Fred Bosh', 'image': 'https://placehold.co/100x100/EF4444/FFFFFF?text=FB'},
  {'name': 'Devin Jones', 'image': 'https://placehold.co/100x100/F97316/FFFFFF?text=DJ'},
  {'name': 'Emelia Ben', 'image': 'https://placehold.co/100x100/8B5CF6/FFFFFF?text=EB'},
  {'name': 'Teressa Adams', 'image': 'https://placehold.co/100x100/06B6D4/FFFFFF?text=TA'},
  {'name': 'Justice Freeman', 'image': 'https://placehold.co/100x100/14B8A6/FFFFFF?text=JF'},
];

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize TabController for the two segments
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Helper Widget for the Friend List Item ---
  Widget _buildFriendListItem(Map<String, String> friend,IconData icon) {
    // Custom color used for the active/interaction elements
    const Color primaryGreen = Color(0xFF10B981);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: CircleAvatar(
        radius: 28,
        // Using NetworkImage for mock avatar images
        backgroundImage: NetworkImage(friend['image']!), 
        backgroundColor: Colors.grey.shade200,
      ),
      title: Text(
        friend['name']!,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      trailing: GestureDetector(
        onTap: () {
          // Action when tapping the add/friend icon
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tapped on ${friend['name']!}')),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(
            icon, // Icon closely matching the image
            color: primaryGreen,
            size: 28,
          ),
        ),
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // Custom purple/pink color for the segmented control indicator
    

    return Scaffold(
     
      appBar: AppBar(
        // Set the background color to white/transparent
        
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Friends',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // Handle search action
            },
          ),
          const SizedBox(width: 8),
        ],
        // The bottom property is used to integrate the custom segmented control
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1.0),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              
             
           
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3.0,
              tabs: const [
                Tab(text: 'My Friends'),
                Tab(text: 'Find Friends'),
              ],
            ),
          ),
        ),
      ),
      
      body: TabBarView(
        controller: _tabController,
        children: [
          // Content for 'My Friends' tab
          ListView.builder(
            itemCount: mockFriends.length,
            itemBuilder: (context, index) {
              return _buildFriendListItem(mockFriends[index],Icons.add );
            },
          ),
          
          // Content for 'Find Friends' tab
          ListView.builder(
            itemCount: mockFriends.length,
            itemBuilder: (context, index) {
              return _buildFriendListItem(mockFriends[index],Icons.message);
            },
          ),
        ],
      ),
    );
  }
}