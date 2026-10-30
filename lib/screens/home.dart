/// Home dashboard: greeting, summary stats, search, and the teacher's classes.
library;

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'class_detail.dart';
import 'section_form.dart';
import 'settings.dart';

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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sectionList = state.sections.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final totalStudents = state.students.length;
    final today = todayIso();

    final q = _query.trim().toLowerCase();
    final visibleList = q.isEmpty
        ? sectionList
        : sectionList
            .where((s) =>
                s.gradeLevel.toLowerCase().contains(q) ||
                s.section.toLowerCase().contains(q) ||
                s.schoolYear.toLowerCase().contains(q))
            .toList();

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
                  value: '${state.subjects.length}',
                  label: 'Subjects',
                ),
              ),
            ],
          ),
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
                        hintText: 'Search grade, section or school year',
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
          else if (visibleList.isEmpty)
            EmptyState(
              icon: Ionicons.searchOutline,
              title: 'No matches',
              subtitle:
                  'Nothing matches “${_query.trim()}”. Try another grade level, section or school year.',
            )
          else
            for (final section in visibleList) _ClassCard(section: section, today: today),
        ],
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
