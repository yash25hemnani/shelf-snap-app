// Short relative time for lists: "Just now", "5 min ago", "3 h ago",
// "Yesterday", then the date ("3 Nov", or "3 Nov 2025" in another year)
String timeAgo(DateTime time, {DateTime? now}) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final current = now ?? DateTime.now();
  final diff = current.difference(time);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';

  // Calendar days, so 11pm yesterday reads as Yesterday and not "1 h ago"
  // the next morning
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(time.year, time.month, time.day);
  final days = today.difference(day).inDays;

  if (days == 0) return '${diff.inHours} h ago';
  if (days == 1) return 'Yesterday';

  final date = '${time.day} ${months[time.month - 1]}';
  return time.year == current.year ? date : '$date ${time.year}';
}
