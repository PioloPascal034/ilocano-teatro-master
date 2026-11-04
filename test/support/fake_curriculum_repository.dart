import 'dart:async';

import 'package:ilocano_teatro_master/features/teacher/data/curriculum_repository.dart';
import 'package:ilocano_teatro_master/features/teacher/models/curriculum_models.dart';

class FakeCurriculumRepository implements CurriculumRepository {
  FakeCurriculumRepository({
    this.editor = true,
    List<CurriculumModule>? modules,
    this.permissionError,
    this.loadError,
    this.mutationError,
    this.loadWait,
    this.supportsLessonMetadata = true,
  }) : _modules = List<CurriculumModule>.of(modules ?? _sampleModules);

  bool editor;
  @override
  final bool supportsLessonMetadata;
  final Object? permissionError;
  final Object? loadError;
  final Object? mutationError;
  final Future<void>? loadWait;
  final List<CurriculumModule> _modules;
  final List<String> reorderRequests = [];

  List<CurriculumModule> get modules => List.unmodifiable(_modules);

  static final _sampleModules = <CurriculumModule>[
    const CurriculumModule(
      id: 'module-1',
      title: 'Introduction to Theater',
      description: 'A module description from the fake repository.',
      displayOrder: 1,
      isPublished: true,
      lessons: [
        CurriculumLesson(
          id: 'lesson-1',
          moduleId: 'module-1',
          title: 'What Is Theater?',
          objectives: 'Identify theater elements.',
          content: 'First lesson content.',
          lessonOrder: 1,
          isPublished: true,
        ),
        CurriculumLesson(
          id: 'lesson-2',
          moduleId: 'module-1',
          title: 'Stage and Audience',
          objectives: 'Describe the audience.',
          content: 'Second lesson content.',
          lessonOrder: 2,
          isPublished: false,
        ),
      ],
    ),
    const CurriculumModule(
      id: 'module-2',
      title: 'Unpublished Module',
      description: 'Editor-only content.',
      displayOrder: 2,
      isPublished: false,
      lessons: [],
    ),
  ];

  void _throwMutationError() {
    if (!editor) {
      throw StateError('Curriculum Editor permission is required.');
    }
    if (mutationError != null) throw mutationError!;
  }

  @override
  Future<bool> isCurriculumEditor() async {
    await loadWait;
    if (permissionError != null) throw permissionError!;
    return editor;
  }

  @override
  Future<List<CurriculumModule>> loadModules() async {
    await loadWait;
    if (loadError != null) throw loadError!;
    if (editor) return List.unmodifiable(_modules);
    return List.unmodifiable(
      _modules
          .where((module) => module.isPublished)
          .map(
            (module) => CurriculumModule(
              id: module.id,
              title: module.title,
              description: module.description,
              displayOrder: module.displayOrder,
              isPublished: module.isPublished,
              lessons: List.unmodifiable(
                module.lessons.where((lesson) => lesson.isPublished),
              ),
            ),
          ),
    );
  }

  @override
  Future<CurriculumModule> createModule({
    required String title,
    required String description,
  }) async {
    _throwMutationError();
    final module = CurriculumModule(
      id: 'module-${_modules.length + 1}',
      title: title,
      description: description,
      displayOrder: _modules.length + 1,
      isPublished: false,
      lessons: const [],
    );
    _modules.add(module);
    return module;
  }

  @override
  Future<void> updateModule({
    required String moduleId,
    required String title,
    required String description,
  }) async {
    _throwMutationError();
    final index = _modules.indexWhere((module) => module.id == moduleId);
    if (index < 0) throw StateError('Module not found.');
    final old = _modules[index];
    _modules[index] = CurriculumModule(
      id: old.id,
      title: title,
      description: description,
      displayOrder: old.displayOrder,
      isPublished: old.isPublished,
      lessons: old.lessons,
    );
  }

  @override
  Future<void> setModulePublished({
    required String moduleId,
    required bool isPublished,
  }) async {
    _throwMutationError();
    final index = _modules.indexWhere((module) => module.id == moduleId);
    if (index < 0) throw StateError('Module not found.');
    final old = _modules[index];
    _modules[index] = CurriculumModule(
      id: old.id,
      title: old.title,
      description: old.description,
      displayOrder: old.displayOrder,
      isPublished: isPublished,
      lessons: old.lessons,
    );
  }

  @override
  Future<CurriculumLesson> createLesson({
    required String moduleId,
    required String title,
    required String? objectives,
    required String content,
    Map<String, String> sections = const <String, String>{},
    String overview = '',
    int? estimatedReadingMinutes,
  }) async {
    _throwMutationError();
    final moduleIndex = _modules.indexWhere((module) => module.id == moduleId);
    if (moduleIndex < 0) throw StateError('Module not found.');
    final module = _modules[moduleIndex];
    final lesson = CurriculumLesson(
      id: 'lesson-new-${module.lessons.length + 1}',
      moduleId: moduleId,
      title: title,
      objectives: objectives,
      content: content,
      sections: sections,
      overview: overview,
      estimatedReadingMinutes: estimatedReadingMinutes,
      lessonOrder: module.lessons.length + 1,
      isPublished: false,
    );
    _replaceLessons(moduleIndex, [...module.lessons, lesson]);
    return lesson;
  }

  @override
  Future<void> updateLesson({
    required String lessonId,
    required String title,
    required String? objectives,
    required String content,
    Map<String, String> sections = const <String, String>{},
    String overview = '',
    int? estimatedReadingMinutes,
  }) async {
    _throwMutationError();
    for (var i = 0; i < _modules.length; i++) {
      final lessons = [..._modules[i].lessons];
      final index = lessons.indexWhere((lesson) => lesson.id == lessonId);
      if (index < 0) continue;
      final old = lessons[index];
      lessons[index] = CurriculumLesson(
        id: old.id,
        moduleId: old.moduleId,
        title: title,
        objectives: objectives,
        content: content,
        sections: sections,
        overview: overview,
        estimatedReadingMinutes: estimatedReadingMinutes,
        lessonOrder: old.lessonOrder,
        isPublished: old.isPublished,
      );
      _replaceLessons(i, lessons);
      return;
    }
    throw StateError('Lesson not found.');
  }

  @override
  Future<void> setLessonPublished({
    required String lessonId,
    required bool isPublished,
  }) async {
    _throwMutationError();
    for (var i = 0; i < _modules.length; i++) {
      final lessons = [..._modules[i].lessons];
      final index = lessons.indexWhere((lesson) => lesson.id == lessonId);
      if (index < 0) continue;
      final old = lessons[index];
      lessons[index] = CurriculumLesson(
        id: old.id,
        moduleId: old.moduleId,
        title: old.title,
        objectives: old.objectives,
        content: old.content,
        sections: old.sections,
        overview: old.overview,
        estimatedReadingMinutes: old.estimatedReadingMinutes,
        lessonOrder: old.lessonOrder,
        isPublished: isPublished,
      );
      _replaceLessons(i, lessons);
      return;
    }
    throw StateError('Lesson not found.');
  }

  @override
  Future<void> reorderLessons({
    required String moduleId,
    required List<String> lessonIds,
  }) async {
    _throwMutationError();
    reorderRequests
      ..clear()
      ..addAll(lessonIds);
    final index = _modules.indexWhere((module) => module.id == moduleId);
    if (index < 0) throw StateError('Module not found.');
    final lessonsById = {
      for (final lesson in _modules[index].lessons) lesson.id: lesson,
    };
    if (lessonIds.length != lessonsById.length ||
        lessonIds.toSet().length != lessonsById.length ||
        lessonIds.any((id) => !lessonsById.containsKey(id))) {
      throw ArgumentError(
        'Reorder request must include every lesson exactly once.',
      );
    }
    _replaceLessons(index, [
      for (var i = 0; i < lessonIds.length; i++)
        _copyLesson(lessonsById[lessonIds[i]]!, lessonOrder: i + 1),
    ]);
  }

  void _replaceLessons(int moduleIndex, List<CurriculumLesson> lessons) {
    final old = _modules[moduleIndex];
    _modules[moduleIndex] = CurriculumModule(
      id: old.id,
      title: old.title,
      description: old.description,
      displayOrder: old.displayOrder,
      isPublished: old.isPublished,
      lessons: List.unmodifiable(lessons),
    );
  }

  CurriculumLesson _copyLesson(
    CurriculumLesson lesson, {
    required int lessonOrder,
  }) => CurriculumLesson(
    id: lesson.id,
    moduleId: lesson.moduleId,
    title: lesson.title,
    objectives: lesson.objectives,
    content: lesson.content,
    sections: lesson.sections,
    overview: lesson.overview,
    estimatedReadingMinutes: lesson.estimatedReadingMinutes,
    lessonOrder: lessonOrder,
    isPublished: lesson.isPublished,
  );
}
