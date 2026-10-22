import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/watchlists/data/watchlist_repository.dart';
import 'package:tradex/features/ai_assistant/data/ai_repository.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';

void main() {
  test(
    'preview URL roles require the explicit demo entrypoint as well as debug mode',
    () {
      final admin = Uri.parse('/workspace?preview=admin');
      CustomerDataPolicy.allowDemo = false;
      expect(CustomerDataPolicy.developmentPreview(admin, debug: true), isNull);
      CustomerDataPolicy.allowDemo = true;
      expect(
        CustomerDataPolicy.developmentPreview(admin, debug: false),
        isNull,
      );
      expect(
        CustomerDataPolicy.developmentPreview(admin, debug: true),
        'admin',
      );
      expect(
        CustomerDataPolicy.developmentPreview(
          Uri.parse('/workspace?preview=anything'),
          debug: true,
        ),
        isNull,
      );
    },
  );
  test(
    'normal customer repositories never initialize sample account records',
    () async {
      CustomerDataPolicy.allowDemo = false;
      addTearDown(() => CustomerDataPolicy.allowDemo = true);
      final community = CommunityRepository();
      final messages = MessagesRepository();
      final ai = AiAssistantRepository();
      expect(community.forYouPosts, isEmpty);
      final insights = community.getPostInsights('missing-post');
      expect(insights.impressions, 0);
      expect(insights.engagements, 0);
      expect(community.suggestedTraders, isEmpty);
      expect(community.notifications, isEmpty);
      expect(community.allLiveRooms, isEmpty);
      expect(messages.threads, isEmpty);
      expect(messages.requests, isEmpty);
      expect(await WatchlistRepositoryImpl().getWatchlists(), isEmpty);
      expect(await WatchlistRepositoryImpl().getWatchlistTickers(), isEmpty);
      expect(await AiRepositoryImpl().getInsights(), isEmpty);
      expect(ai.insights, isEmpty);
      expect(ai.chartSetups, isEmpty);
      final auth = await SupabaseAuthBackendService.instance.signIn(
        role: UserRole.customer,
        emailOrHandle: 'trader@example.com',
        password: 'valid-pass-123',
      );
      expect(auth.isSuccess, isFalse);
      ai.sendPrompt('A real account prompt');
      expect(ai.activeThread.messages, isEmpty);
      community.dispose();
      messages.dispose();
      ai.dispose();
    },
  );
}
