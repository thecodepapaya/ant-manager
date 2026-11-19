// Full engine flow against a deterministic local model server (no key needed; runs in CI).
import 'package:core/core.dart';
import 'package:test/test.dart';

import 'e2e_flow.dart';
import 'fake_llm_server.dart';

void main() {
  late FakeLlmServer server;
  tearDownAll(() => server.close());

  defineE2eFlow('e2e (fake model server)', endpoint: () async {
    server = await FakeLlmServer.start();
    return E2eEndpoint(kind: ProviderKind.custom, baseUrl: server.baseUrl, model: FakeLlmServer.model);
  });

  test('fake server saw every pipeline stage, and the image went to the vision call', () {
    final schemas = server.calls.map((c) => c.schema).toSet();
    expect(schemas, containsAll(['probe', 'importance', 'enrichment', 'image_description', 'fact_ops', 'workstreams',
        'report', 'win']));
    expect(server.of('image_description').single.imageCount, 1);
    expect(server.of('report'), hasLength(3));
  });
}
