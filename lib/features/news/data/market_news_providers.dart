import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/news/data/firebase_market_news_repository.dart';
import 'package:meu_gestor_financeiro/features/news/domain/market_news.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';

final Provider<DateTime Function()> marketNewsClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

final Provider<MarketNewsRepository> marketNewsRepositoryProvider =
    Provider<MarketNewsRepository>(
      (Ref ref) => FirebaseMarketNewsRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
      ),
    );

final FutureProvider<MarketNewsReadResult> marketNewsFeedsProvider =
    FutureProvider.autoDispose<MarketNewsReadResult>(
      (Ref ref) =>
          ref.watch(marketNewsRepositoryProvider).readFeeds(serverOnly: true),
    );
