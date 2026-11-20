/// Public project links shown in Settings → General → About (#127). The website and the GitHub issue
/// templates (`.github/ISSUE_TEMPLATE/`) use the same URLs.
library;

abstract final class ProjectLinks {
  static final repo = Uri.parse('https://github.com/thecodepapaya/ant-manager');
  static final bugReport = Uri.parse('$repo/issues/new?template=bug_report.yml');
  static final featureRequest = Uri.parse('$repo/issues/new?template=feature_request.yml');
}
