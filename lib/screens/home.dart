/// Home dashboard: greeting, summary stats, search, and the teacher's classes.
library;

import 'package:flutter/material.dart' hide Badge;
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/attention.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'class_detail.dart';
import 'section_form.dart';
import 'settings.dart';
import 'student_profile.dart';

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _searchOpen = false;
  String _query = '';
  bool _backingUp = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTips());
  }

  /// First-run guidance, shown once and skippable.
  Future<void> _maybeShowTips() async {
    if (!mounted) return;
    final state = context.read<AppState>();
    if (!state.hydrated || state.tipsSeen) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to TugboTrack',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: AppFonts.bold,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Three tips before you start.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(height: 14),
              const _Tip(
                icon: Ionicons.lockClosed,
                title: 'Your MPIN protects every record',
                body: 'Learner names, grades, attendance and BMI stay on this '
                    'device behind your 6-digit MPIN.',
              ),
              const _Tip(
                icon: Ionicons.statsChart,
                title: 'Scores compute the grades',
                body: 'Add a class, its subjects and learners, then type scores. '
                    'WW, PT and TE percentages, transmutation and the final grade '
                    'are computed for you.',
              ),
              const _Tip(
                icon: Ionicons.checkmarkDone,
                title: 'Attendance in two taps',
                body: 'Open a class and tap “All present”, then mark only the '
                    'absentees. Backups are automatic every day.',
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Got it',
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) context.read<AppState>().markTipsSeen();
  }

  Future<void> _backupNow() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _backingUp = true);
    final file = await context.read<AppState>().backupNow();
    if (!mounted) return;
    setState(() => _backingUp = false);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          file == null
              ? 'Could not write a backup. Try again from Settings.'
              : 'Database backup saved on this device.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final schoolYear = state.activeSchoolYear ?? currentSchoolYear();
    final sectionList = state.classesOf(schoolYear);
    final archived = state.archivedClasses();
    final totalStudents = state.totalStudents;
    final subjectCount = sectionList.fold<int>(
      0,
      (sum, section) => sum + state.subjectsOf(section.id).length,
    );
    final today = todayIso();
    final markedToday =
        sectionList.where((s) => state.attendance['${s.id}::$today'] != null).length;

    final q = _query.trim().toLowerCase();
    final visibleList = q.isEmpty
        ? sectionList
        : sectionList
            .where((s) =>
                s.gradeLevel.toLowerCase().contains(q) ||
                s.section.toLowerCase().contains(q) ||
                s.schoolYear.toLowerCase().contains(q))
            .toList();
    // Learners are searched across every class, not just the active one.
    final learnerMatches = q.isEmpty
        ? <Student>[]
        : (state.students.values
            .where((student) =>
                !student.archived &&
                state.sections[student.sectionId] != null &&
                (student.fullName.toLowerCase().contains(q) ||
                    student.lrn.toLowerCase().contains(q)))
            .toList()
          ..sort((a, b) => a.fullName.toLowerCase().compareTo(
                b.fullName.toLowerCase(),
              )))
            .take(8)
            .toList();
    final attention = state.attention();
    final backupAge = state.backupAgeDays;

    return Screen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()},',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        color: AppColors.textSoft,
                      ),
                    ),
                    Text(
                      state.teacherName.isEmpty ? 'Teacher' : state.teacherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24,
                        fontWeight: AppFonts.extrabold,
                        color: AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tugbo Integrated School',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: AppFonts.medium,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.white,
                shape: CircleBorder(
                  side: BorderSide(color: AppColors.border, width: 1.5),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Ionicons.settingsOutline,
                      size: 22,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Ionicons.school,
                  value: '${sectionList.length}',
                  label: 'Classes',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Ionicons.people,
                  value: '$totalStudents',
                  label: 'Students',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Ionicons.book,
                  value: '$subjectCount',
                  label: 'Subjects',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            style: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Ionicons.calendarOutline,
                        size: 18, color: AppColors.navy),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'School Year $schoolYear',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          fontWeight: AppFonts.semibold,
                          color: AppColors.navyDark,
                        ),
                      ),
                    ),
                    if (archived.isNotEmpty)
                      GestureDetector(
                        onTap: () => _openArchived(state, archived),
                        child: Text(
                          '${archived.length} archived',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            fontWeight: AppFonts.semibold,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Segmented<int>(
                  options: [
                    for (final term in terms)
                      SegmentedOption(term, termLabel(term)),
                  ],
                  value: state.activeTerm,
                  onChange: (term) => context.read<AppState>().setActiveTerm(term),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Ionicons.checkmarkDone,
                        size: 16, color: AppColors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        markedToday == 0
                            ? 'Attendance not recorded today'
                            : 'Attendance recorded for $markedToday of '
                                '${sectionList.length} classes today',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (backupAge == null || backupAge >= 7) ...[
            const SizedBox(height: 10),
            AppCard(
              style: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF1D6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Ionicons.cloudOfflineOutline,
                        size: 18, color: AppColors.amber),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      backupAge == null
                          ? 'No database backup yet. Keep a copy in case the '
                              'phone is lost or replaced.'
                          : 'Last database backup was $backupAge days ago. '
                              'Back it up now.',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: AppColors.textSoft,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _backingUp ? null : _backupNow,
                    child: Text(_backingUp ? '…' : 'Back up'),
                  ),
                ],
              ),
            ),
          ],
          if (attention.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AttentionCard(
              items: attention.take(4).toList(),
              total: attention.length,
              onOpen: (item) {
                final sectionId = item.sectionId;
                if (sectionId == null) return;
                state.setActiveSection(sectionId);
                if (item.studentId != null &&
                    state.students.containsKey(item.studentId)) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          StudentProfileScreen(studentId: item.studentId!),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ClassDetailScreen(sectionId: sectionId),
                    ),
                  );
                }
              },
            ),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Classes',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: AppFonts.bold,
                  color: AppColors.navyDark,
                ),
              ),
              Row(
                children: [
                  Material(
                    color: _searchOpen ? AppColors.navy : AppColors.ice,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: _searchOpen ? AppColors.navy : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        setState(() {
                          _searchOpen = !_searchOpen;
                          if (!_searchOpen) {
                            _query = '';
                            _searchController.clear();
                          }
                        });
                      },
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          _searchOpen ? Ionicons.close : Ionicons.search,
                          size: 18,
                          color: _searchOpen ? AppColors.white : AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SectionFormScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: AppShadow.soft,
                        ),
                        child: const Row(
                          children: [
                            Icon(Ionicons.add, size: 20, color: AppColors.white),
                            SizedBox(width: 4),
                            Text(
                              'Add Class',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: AppFonts.semibold,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_searchOpen) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.blue, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Ionicons.search, size: 18, color: AppColors.textFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      autocorrect: false,
                      onChanged: (text) => setState(() => _query = text),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: AppFonts.medium,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        hintText: 'Search learner, class or school year',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14.5,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      child: Icon(
                        Ionicons.closeCircle,
                        size: 18,
                        color: AppColors.textFaint,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (sectionList.isEmpty)
            EmptyState(
              icon: Ionicons.schoolOutline,
              title: 'No classes yet',
              subtitle:
                  'Create your first class (grade level + section) to start organizing student records.',
              actionLabel: 'Create a class',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SectionFormScreen()),
              ),
            )
          else if (visibleList.isEmpty && learnerMatches.isEmpty)
            EmptyState(
              icon: Ionicons.searchOutline,
              title: 'No matches',
              subtitle:
                  'Nothing matches “${_query.trim()}”. Try a learner name, LRN, grade level or section.',
            )
          else ...[
            if (learnerMatches.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8, top: 2),
                child: Text(
                  'Learners',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: AppFonts.bold,
                    color: AppColors.navyDark,
                  ),
                ),
              ),
              for (final student in learnerMatches)
                _LearnerResult(
                  student: student,
                  section: state.sections[student.sectionId],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudentProfileScreen(studentId: student.id),
                    ),
                  ),
                ),
              if (visibleList.isNotEmpty) const SizedBox(height: 6),
            ],
            for (final section in visibleList)
              _ClassCard(section: section, today: today),
          ],
        ],
      ),
    );
  }

  /// Archived classes are kept with all of their records; this sheet restores
  /// one to the active list.
  Future<void> _openArchived(AppState state, List<Section> archived) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Archived classes',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: AppFonts.bold,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Archived classes and their records stay in the database.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: archived.length,
                  itemBuilder: (context, index) {
                    final section = archived[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        style: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section.title,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: AppFonts.semibold,
                                      color: AppColors.navyDark,
                                    ),
                                  ),
                                  Text(
                                    'SY ${section.schoolYear} · '
                                    '${state.studentsOf(section.id, includeArchived: true).length} learners',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      color: AppColors.textSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                state.archiveSection(section.id, archived: false);
                                Navigator.of(sheetContext).pop();
                              },
                              child: const Text('Restore'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.ice,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: AppFonts.semibold,
                    color: AppColors.navyDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: AppColors.textSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _attentionIcon(AttentionKind kind) {
  switch (kind) {
    case AttentionKind.missingBmi:
      return Ionicons.bodyOutline;
    case AttentionKind.frequentAbsence:
      return Ionicons.calendarClearOutline;
    case AttentionKind.noAssessments:
      return Ionicons.createOutline;
    case AttentionKind.failing:
      return Ionicons.trendingDownOutline;
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.items,
    required this.total,
    required this.onOpen,
  });

  final List<AttentionItem> items;
  final int total;
  final ValueChanged<AttentionItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      style: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Ionicons.alertCircleOutline,
                  size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Needs attention',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: AppFonts.bold,
                    color: AppColors.navyDark,
                  ),
                ),
              ),
              Badge(label: '$total', color: AppColors.amber, bg: const Color(0xFFFFF1D6)),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => onOpen(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(_attentionIcon(item.kind),
                          size: 16, color: AppColors.textSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                fontWeight: AppFonts.semibold,
                                color: AppColors.text,
                              ),
                            ),
                            Text(
                              item.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Ionicons.chevronForward,
                          size: 16, color: AppColors.textFaint),
                    ],
                  ),
                ),
              ),
            ),
          if (total > items.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${total - items.length} more in reports',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.5,
                  color: AppColors.textFaint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LearnerResult extends StatelessWidget {
  const _LearnerResult({
    required this.student,
    required this.section,
    required this.onTap,
  });

  final Student student;
  final Section? section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.ice,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initialsOf(student.fullName),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: AppFonts.bold,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          fontWeight: AppFonts.semibold,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        section == null
                            ? 'Class not found'
                            : '${section!.section} · ${section!.schoolYear}'
                                '${student.lrn.isEmpty ? '' : ' · ${student.lrn}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Ionicons.chevronForward,
                    size: 16, color: AppColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      style: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.ice,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.navy),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: AppFonts.extrabold,
              color: AppColors.navyDark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.section, required this.today});

  final Section section;
  final String today;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final kids = state.studentsOf(section.id);
    final subs = state.subjectsOf(section.id);
    final day = state.attendance['${section.id}::$today'];
    final marked = day?.statuses.length ?? 0;
    final badge = section.gradeLevel.replaceFirst('Grade ', 'G');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            state.setActiveSection(section.id);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ClassDetailScreen(sectionId: section.id)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.card,
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    badge,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: AppFonts.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${section.gradeLevel} — ${section.section}',
                        maxLines: 2,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15.5,
                          fontWeight: AppFonts.semibold,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'SY ${section.schoolYear} · ${kids.length} '
                        '${kids.length == 1 ? 'student' : 'students'}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          color: AppColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subs.isEmpty
                            ? 'No subjects yet'
                            : subs.map((s) => s.name).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: AppFonts.medium,
                          color: AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Text(
                      'Today',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                    Text(
                      marked > 0 ? 'Done' : '—',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: AppFonts.bold,
                        color: marked > 0 ? AppColors.green : AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(Ionicons.chevronForward, size: 20, color: AppColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
