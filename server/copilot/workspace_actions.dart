import 'package:tradex/features/copilot/models/workspace.dart';
import 'package:tradex/features/copilot/models/workspace_mutations.dart';
import 'store.dart';

export 'package:tradex/features/copilot/models/workspace_mutations.dart'
    show requiredText;

class WorkspaceActions {
  WorkspaceActions(this.store);
  final WorkspaceStore store;

  Future<Json> apply(String owner, Json input) =>
      store.change(owner, (state) => WorkspaceMutations.apply(state, input));

  static Json savePage(Json state, Json input) =>
      WorkspaceMutations.savePage(state, input);
}
