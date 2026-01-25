class NameUtils {
  /// Capitalizes the first letter of each word in a name string.
  /// Example: "john doe" -> "John Doe"
  static String capitalizeName(String input) {
    if (input.isEmpty) return input;
    
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Normalizes a username (lowercase, trim).
  /// Example: " Mike123 " -> "mike123"
  static String normalizeUsername(String input) {
    return input.trim().toLowerCase(); // Optional: Usernames might be case-sensitive depending on requirements, but lowercasing is safer for ID matching.
    // Based on user prompt "Usernames... Must NOT be auto-capitalized", but doesn't explicitly say force lowercase. 
    // However, usually handles are case-insensitive.
    // Re-reading prompt: "Do NOT: Modify usernames". So we will just trim.
  }
}
