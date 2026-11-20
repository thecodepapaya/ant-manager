import '../../domain/enums.dart';
import '../source.dart';
import 'git_repo.dart';
import 'github.dart';
import 'gitlab.dart';

/// Registers the code-hosting sources: local git, GitHub, GitHub Enterprise, GitLab.
void registerCodeSources(SourceRegistry r) {
  r.register(SourceKind.gitRepo, GitRepoSource.new);
  r.register(SourceKind.github, () => GitHubSource(kind: SourceKind.github));
  r.register(SourceKind.githubEnterprise, () => GitHubSource(kind: SourceKind.githubEnterprise));
  r.register(SourceKind.gitlab, GitLabSource.new);
}
