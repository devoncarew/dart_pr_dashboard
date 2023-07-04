import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtable/vtable.dart';

import '../issue_utils.dart';
import 'filter/filter.dart';
import 'misc.dart';

class IssueTable extends StatefulWidget {
  final List<Issue> issues;
  final List<User> googlers;
  final ValueNotifier<SearchFilter?> filterStream;
  late final Set<String> googlerUsers;

  IssueTable({
    super.key,
    required this.issues,
    required this.googlers,
    required this.filterStream,
  }) {
    googlerUsers =
        googlers.map((googler) => googler.login).whereType<String>().toSet();
    // sort by age initially
    issues.sort((a, b) => compareDates(b.createdAt, a.createdAt));
  }

  @override
  State<IssueTable> createState() => _IssueTableState();
}

class _IssueTableState extends State<IssueTable> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ValueListenableBuilder(
        valueListenable: widget.filterStream,
        builder: (context, filter, child) {
          final pullRequests = widget.issues
              .where((issue) => filter?.appliesTo(issue, getMatch) ?? true)
              .toList();
          return VTable<Issue>(
            items: pullRequests,
            tableDescription: '${pullRequests.length} PRs',
            rowHeight: 64.0,
            includeCopyToClipboardAction: true,
            onDoubleTap: (issue) => launchUrl(Uri.parse(issue.htmlUrl)),
            columns: [
              VTableColumn(
                label: 'PR',
                width: 200,
                grow: 1,
                alignment: Alignment.topLeft,
                transformFunction: (issue) => issue.title,
                styleFunction: rowStyle,
              ),
              VTableColumn(
                label: 'Age (days)',
                width: 50,
                grow: 0.2,
                alignment: Alignment.topRight,
                transformFunction: (Issue issue) => daysSince(issue.createdAt),
                styleFunction: rowStyle,
                compareFunction: (a, b) =>
                    compareDates(b.createdAt, a.createdAt),
                validators: [oldPrValidator],
              ),
              VTableColumn(
                label: 'Updated (days)',
                width: 50,
                grow: 0.2,
                alignment: Alignment.topRight,
                transformFunction: (Issue issue) => daysSince(issue.updatedAt),
                styleFunction: rowStyle,
                compareFunction: (a, b) =>
                    compareDates(b.updatedAt, a.updatedAt),
                validators: [probablyStaleValidator],
              ),
              VTableColumn(
                label: 'Labels',
                width: 120,
                grow: 0.8,
                alignment: Alignment.topLeft,
                transformFunction: (issue) =>
                    (issue.labels).map((e) => "'${e.name}'").join(', '),
                renderFunction:
                    (BuildContext context, Issue issue, String out) {
                  return ClipRect(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: (issue.labels).map(LabelWidget.new).toList(),
                    ),
                  );
                },
              ),
              VTableColumn(
                label: 'Reactions',
                width: 120,
                grow: 0.8,
                alignment: Alignment.topLeft,
                transformFunction: (issue) => issue.upvotes.toString(),
                compareFunction: (a, b) => a.upvotes.compareTo(b.upvotes),
              ),
            ],
          );
        },
      ),
    );
  }
}

const TextStyle draftPrStyle = TextStyle(color: Colors.grey);

TextStyle? rowStyle(Issue issue) {
  if (issue.draft == true) return draftPrStyle;

  return null;
}

int compareDates(DateTime? a, DateTime? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

class LabelWidget extends StatelessWidget {
  final IssueLabel label;

  const LabelWidget(
    this.label, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = Color(int.parse('FF${label.color}', radix: 16));

    return Material(
      color: chipColor,
      shape: const StadiumBorder(),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Text(
          label.name,
          style: TextStyle(
            color: isLightColor(chipColor)
                ? Colors.grey.shade900
                : Colors.grey.shade100,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

bool isLightColor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.light;

ValidationResult? oldPrValidator(Issue issue) {
  final createdAt = issue.createdAt;
  if (createdAt == null) return null;

  final days = DateTime.now().difference(createdAt).inDays;
  if (days > 365) {
    return ValidationResult.warning('PR is objectively pretty old');
  }

  return null;
}

ValidationResult? probablyStaleValidator(Issue issue) {
  if (issue.draft == true) return null;

  final updatedAt = issue.updatedAt;
  if (updatedAt == null) return null;

  final days = DateTime.now().difference(updatedAt).inDays;
  if (days > 30) {
    return ValidationResult.warning('PR not updated recently');
  }

  return null;
}
