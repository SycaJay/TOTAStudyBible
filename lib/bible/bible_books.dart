import 'package:njbibleapp/onboarding_flow.dart'
    show kNewTestamentBooks, kOldTestamentBooks;

/// Protestant canon, traditional English order (matches Bible tab + JSON assets).
const List<String> kOrderedBibleBooks = [
  ...kOldTestamentBooks,
  ...kNewTestamentBooks,
];
