class UserModel {
  final String uid;
  final String email;
  final String username;
  final String firstName;
  final String? lastName;
  final String bio;
  final String description;
  final String profileImage;
  final int followersCount;
  final int followingCount;
  final DateTime? joinedAt;
  final String role; // 'user', 'creator', 'reviewer', 'admin'
  final String? creatorStatus; // 'pending', 'approved', 'rejected'
  final DateTime? creatorVerifiedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.firstName,
    this.lastName,
    this.bio = '',
    this.description = '',
    this.profileImage = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.joinedAt,
    this.role = 'user',
    this.creatorStatus,
    this.creatorVerifiedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'],
      bio: data['bio'] ?? '',
      description: data['description'] ?? '',
      profileImage: data['profileImage'] ?? '',
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      joinedAt: data['joinedAt'] is String
          ? DateTime.tryParse(data['joinedAt'])
          : (data['joinedAt'] is DateTime ? data['joinedAt'] : null),
      role: data['role'] ?? 'user',
      creatorStatus: data['creator_status'], // DB column name
      creatorVerifiedAt: data['creator_verified_at'] is String
          ? DateTime.tryParse(data['creator_verified_at'])
          : (data['creator_verified_at'] is DateTime
                ? data['creator_verified_at']
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'bio': bio,
      'description': description,
      'profileImage': profileImage,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'joinedAt': joinedAt?.toIso8601String(),
      'role': role,
      'creator_status': creatorStatus,
      'creator_verified_at': creatorVerifiedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? firstName,
    String? lastName,
    String? bio,
    String? description,
    String? profileImage,
    int? followersCount,
    int? followingCount,
    DateTime? joinedAt,
    String? role,
    String? creatorStatus,
    DateTime? creatorVerifiedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      bio: bio ?? this.bio,
      description: description ?? this.description,
      profileImage: profileImage ?? this.profileImage,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      joinedAt: joinedAt ?? this.joinedAt,
      role: role ?? this.role,
      creatorStatus: creatorStatus ?? this.creatorStatus,
      creatorVerifiedAt: creatorVerifiedAt ?? this.creatorVerifiedAt,
    );
  }

  String get displayName {
    if (lastName != null && lastName!.trim().isNotEmpty) {
      return '$firstName ${lastName!.trim()}'.trim();
    }
    return firstName;
  }

  String get initials {
    if (lastName != null && lastName!.trim().isNotEmpty) {
      return '${firstName[0]}${lastName![0]}'.toUpperCase();
    }
    if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : '';
  }
}
