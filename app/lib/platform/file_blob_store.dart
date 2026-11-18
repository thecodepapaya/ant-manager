import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:path/path.dart' as p;

/// [BlobStore] on disk under `<app support>/ant_manager/blobs/<profileId>/`.
/// Pure `dart:io`: runs in the engine isolate.
class FileBlobStore implements BlobStore {
  FileBlobStore(this.root);
  final String root;

  @override
  Future<String> put(Uint8List bytes, {required String extension}) async {
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    final id = newId();
    // Two-level fan-out keeps directories small.
    final rel = p.join(id.substring(0, 2), '$id.$ext');
    final file = File(p.join(root, rel));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return rel;
  }

  @override
  Future<Uint8List> get(String path) => File(_resolve(path)).readAsBytes();

  @override
  Future<void> delete(String path) async {
    final f = File(_resolve(path));
    if (await f.exists()) await f.delete();
  }

  String _resolve(String rel) {
    final full = p.normalize(p.join(root, rel));
    if (!p.isWithin(root, full)) throw ArgumentError.value(rel, 'path', 'outside the blob store');
    return full;
  }
}
