/// Feed Types for personalized content
enum FeedType {
  forYou('for_you'),
  trending('trending'),
  following('following');

  final String value;
  const FeedType(this.value);
}
