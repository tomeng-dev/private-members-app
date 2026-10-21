import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../realtime/socket_service.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/applications/data/repositories/applications_repository_impl.dart';
import '../../features/applications/domain/repositories/applications_repository.dart';
import '../../features/profiles/data/profiles_repository.dart';
import '../../features/feed/data/feed_repository.dart';
import '../../features/messaging/data/messaging_repository.dart';
import '../../features/events/data/events_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../push/push_messaging_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(baseUrl: AppConfig.apiBaseUrl));

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl(ref.watch(apiClientProvider)));

final loginUseCaseProvider = Provider<LoginUseCase>((ref) => LoginUseCase(ref.watch(authRepositoryProvider)));

final applicationsRepositoryProvider = Provider<ApplicationsRepository>((ref) => ApplicationsRepositoryImpl(ref.watch(apiClientProvider)));

final profilesRepositoryProvider = Provider<ProfilesRepository>((ref) => ProfilesRepository(ref.watch(apiClientProvider)));

class AuthSessionNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLoggedIn(bool value) => state = value;
}

final authSessionProvider = NotifierProvider<AuthSessionNotifier, bool>(AuthSessionNotifier.new);

final feedRepositoryProvider = Provider<FeedRepository>((ref) => FeedRepository(ref.watch(apiClientProvider)));

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) => MessagingRepository(ref.watch(apiClientProvider)));

final eventsRepositoryProvider = Provider<EventsRepository>((ref) => EventsRepository(ref.watch(apiClientProvider)));

final socketServiceProvider = Provider<SocketService>((ref) => SocketService(ref.watch(apiClientProvider)));

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.watch(apiClientProvider)));

final pushMessagingProvider = Provider<PushMessagingService>((ref) => PushMessagingService(ref.watch(notificationsRepositoryProvider)));
