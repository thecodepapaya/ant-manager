import 'dart:convert';

import '../data/app_db.dart';
import '../data/profile_db.dart';
import '../domain/enums.dart';
import '../ports/ports.dart';
import 'llm.dart';
import 'register.dart';

/// Route → model id from the profile's TaskRoutes (unset → Default, #75) → model + provider from the app db
/// → client, with the API key and header values read from the SecretStore.
class DbModelRouter implements ModelRouter {
  DbModelRouter({required this.appDb, required this.profileDb, required this.secrets});

  final AppDb appDb;
  final ProfileDb profileDb;
  final SecretStore secrets;

  @override
  Future<ResolvedModel> resolve(LlmRoute route) async {
    final routes = {
      for (final r in await profileDb.select(profileDb.taskRoutes).get())
        if (r.modelId != null) r.route: r.modelId!,
    };
    final modelId = routes[route] ?? routes[LlmRoute.defaultRoute];
    if (modelId == null) throw LlmFailure('No default model configured. Choose one in Settings → Models.');

    final model = await (appDb.select(appDb.models)..where((m) => m.id.equals(modelId))).getSingleOrNull();
    if (model == null) {
      throw LlmFailure('The model for the ${route.name} route was removed. Choose another in Settings → Models.');
    }
    final provider = await (appDb.select(appDb.providers)..where((p) => p.id.equals(model.providerId))).getSingle();

    final apiKey = provider.credentialRef == null ? null : await secrets.read(provider.credentialRef!);
    final headerRefs = (jsonDecode(provider.headers) as Map).cast<String, String>();
    final headers = {for (final e in headerRefs.entries) e.key: await secrets.read(e.value) ?? ''};

    return ResolvedModel(
      client: createClient(provider, apiKey: apiKey, headers: headers),
      modelName: model.modelName,
      info: ModelInfo(
        name: model.modelName,
        vision: model.vision,
        contextLength: model.contextLength,
        inputPricePerMTok: model.inputPricePerMTok,
        outputPricePerMTok: model.outputPricePerMTok,
      ),
    );
  }
}
