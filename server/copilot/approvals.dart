import 'dart:convert';

import 'package:tradex/features/copilot/models/workspace.dart';
import 'agent_tools.dart';
import 'computer.dart';
import 'store.dart';
import 'workspace_actions.dart';

class ApprovalService {
  ApprovalService(this.store, {this.computer});
  final WorkspaceStore store;
  final ComputerBridge? computer;

  Future<bool> decide(
    String owner,
    String threadId,
    String approvalId,
    bool approve,
  ) async {
    Json? computerResult;
    if (approve) {
      final claimed = await store.change<Json?>(owner, (state) {
        final thread = recordById(state, 'threads', threadId);
        final request = (thread['approvals'] as List)
            .cast<Json>()
            .where((a) => a['id'] == approvalId)
            .firstOrNull;
        if (request == null ||
            request['kind'] != 'propose_computer_action' ||
            request['status'] != 'pending') {
          return null;
        }
        if (DateTime.parse(
          request['createdAt'],
        ).add(const Duration(hours: 1)).isBefore(DateTime.now())) {
          throw const CopilotFailure(
            'This approval expired. Decline it and request a fresh action.',
            409,
          );
        }
        request['status'] = 'executing';
        return {...request, 'specialistId': thread['specialistId']};
      });
      if (claimed != null) {
        try {
          final args = claimed['arguments'] as Json;
          if (computer == null ||
              ![
                'navigate',
                'click',
                'type',
                'key',
                'scroll',
                'files_write',
                'exec',
              ].contains(args['action'])) {
            throw const CopilotFailure('Computer action unavailable.');
          }
          computerResult = await computer!.perform(
            owner,
            claimed['specialistId'],
            args['action'],
            jsonDecode(textOf(args, 'input', '{}')) as Json,
            agent: true,
          );
        } catch (error) {
          computerResult = {
            'error': error is CopilotFailure
                ? error.message
                : 'Computer action failed. Review activity before requesting another attempt.',
          };
        }
      }
    }
    return store.change(owner, (state) {
      final thread = recordById(state, 'threads', threadId);
      final approval = (thread['approvals'] as List)
          .cast<Json>()
          .where((a) => a['id'] == approvalId)
          .firstOrNull;
      if (approval == null) {
        throw const CopilotFailure('Review request not found.', 404);
      }
      // A repeated click must not repeat a save or external action.
      if (approval['status'] != 'pending' &&
          !(approval['status'] == 'executing' && computerResult != null)) {
        return false;
      }
      final expires = DateTime.parse(
        approval['createdAt'],
      ).add(const Duration(hours: 1));
      if (approve &&
          computerResult == null &&
          expires.isBefore(DateTime.now())) {
        throw const CopilotFailure(
          'This approval expired. Decline it and request a fresh draft.',
          409,
        );
      }
      final specialist = recordById(
        state,
        'specialists',
        thread['specialistId'],
      );
      final args = Map<String, dynamic>.from(approval['arguments']);
      Json result = {'declined': true};
      if (approve) {
        switch (approval['kind']) {
          case 'propose_computer_action':
            result =
                computerResult ??
                {
                  'error':
                      'Computer action interrupted. Review the computer before retrying.',
                };
          case 'propose_page':
            if (!(specialist['spaceIds'] as List).contains(args['spaceId'])) {
              throw const CopilotFailure(
                'Access to this space was removed.',
                403,
              );
            }
            if (textOf(args, 'id').isNotEmpty &&
                !(specialist['spaceIds'] as List).contains(
                  recordById(state, 'pages', args['id'])['spaceId'],
                )) {
              throw const CopilotFailure(
                'Access to the original page was removed.',
                403,
              );
            }
            result = WorkspaceActions.savePage(state, args);
          case 'propose_memory':
            if (specialist['memory'] != true ||
                state['settings']['memory'] != true) {
              throw const CopilotFailure('Memory permission was removed.', 403);
            }
            result = {
              'id': newId(),
              'text': requiredText(args, 'text', max: 4000),
              'createdAt': now(),
            };
            (state['memories'] as List).add(result);
          case 'propose_skill':
            if (specialist['learning'] != true) {
              throw const CopilotFailure('Learning is disabled.', 403);
            }
            result = {
              'id': newId(),
              'title': requiredText(args, 'title', max: 200),
              'instructions': requiredText(args, 'instructions'),
              'evidence': requiredText(args, 'evidence'),
              'specialistId': specialist['id'],
              'threadId': threadId,
              'published': false,
            };
            (state['skills'] as List).add(result);
          case 'mcp':
            final connection = recordById(
              state,
              'connections',
              approval['connectionId'],
            );
            if (state['settings']['apps'] != true ||
                specialist['apps'] != true ||
                connection['enabled'] != true ||
                connection['url'] != approval['url'] ||
                connection['specialistId'] != specialist['id'] ||
                ((connection['allTools'] == false ||
                        (connection['allowedTools'] as List).isNotEmpty) &&
                    !(connection['allowedTools'] as List).contains(
                      approval['name'],
                    ))) {
              throw const CopilotFailure(
                'Connection permissions changed. Decline and request the action again.',
                403,
              );
            }
            result = {
              'authorized': true,
              'execution':
                  'Forwarded to the model continuation. If interrupted, verify the destination before retrying.',
            };
        }
      }
      approval['status'] = approve ? 'approved' : 'declined';
      approval['decidedAt'] = now();
      approval['result'] = result;
      final continuation =
          thread.putIfAbsent('continuation', () => <Json>[]) as List;
      continuation.add(
        approval['kind'] == 'mcp'
            ? {
                'type': 'mcp_approval_response',
                'approval_request_id': approval['requestId'],
                'approve': approve,
              }
            : functionResult(approval['callId'], result),
      );
      final ready = !(thread['approvals'] as List).any(
        (a) => a['status'] == 'pending' || a['status'] == 'executing',
      );
      if (ready) thread['status'] = 'ready';
      return ready;
    });
  }
}
