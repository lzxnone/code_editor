import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/services/project_modules/gradle_ide_model.dart';

/// 结构化探测模型测试：取代旧的"文本正则解析"测试。
/// 这些用例断言的是"按字段读取 JSON 模型"，与 Gradle 输出措辞/语言/版本无关。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> singleProjectModel() => {
        'schema': 1,
        'gradleVersion': '8.14',
        'rootProject': 'demo',
        'projects': [
          {
            'path': ':',
            'name': 'demo',
            'buildFile': '/workspace/build.gradle',
            'plugins': ['org.gradle.api.plugins.JavaPlugin'],
            'sourceSets': ['main', 'test'],
            'configurations': ['compileClasspath', 'runtimeClasspath'],
            'javaVersion': '17',
            'tasks': [
              {
                'name': 'build',
                'path': ':build',
                'group': 'build',
                'description': 'Assembles and tests this project.',
                'type': 'org.gradle.api.DefaultTask',
              },
              {
                'name': 'test',
                'path': ':test',
                'group': 'verification',
                'description': null,
                'type': 'org.gradle.api.tasks.testing.Test',
              },
              {
                'name': 'tasks',
                'path': ':tasks',
                'group': 'help',
                'description': 'Displays the tasks runnable from root project.',
                'type': 'org.gradle.api.DefaultTask',
              },
            ],
          },
        ],
      };

  group('GradleIdeModel 结构化解析', () {
    test('单模块：任务字段、分组归一、id/命令生成与原命名习惯一致', () {
      final model = GradleIdeModel.fromJson(singleProjectModel());
      expect(model.schema, GradleIdeModel.schemaVersion);
      expect(model.gradleVersion, '8.14');
      expect(model.projects, hasLength(1));
      expect(model.projects.first.sourceSets, ['main', 'test']);
      expect(model.projects.first.javaVersion, '17');

      final tasks = model.toRunTasks('sh ./gradlew');
      expect(tasks, hasLength(3));

      final build = tasks.firstWhere((t) => t.name == 'build');
      expect(build.id, 'gradle_build');
      expect(build.command, 'sh ./gradlew build');
      expect(build.group, 'build');
      expect(build.description, 'Assembles and tests this project.');

      // 分组排序：application > build > android > verification > help
      expect(tasks.map((t) => t.name).toList(), ['build', 'test', 'tasks']);
      expect(tasks.firstWhere((t) => t.name == 'test').group, 'verification');
    });

    test('多模块：子项目任务使用 :path 作为名称与命令（保持既有 id 习惯）', () {
      final model = GradleIdeModel.fromJson({
        'schema': 1,
        'rootProject': 'demo',
        'projects': [
          {
            'path': ':',
            'name': 'demo',
            'tasks': [
              {'name': 'build', 'path': ':build', 'group': 'build'},
            ],
          },
          {
            'path': ':app',
            'name': 'app',
            'tasks': [
              {'name': 'assembleDebug', 'path': ':app:assembleDebug', 'group': 'build'},
            ],
          },
          {
            'path': ':core',
            'name': 'core',
            'tasks': [
              {'name': 'compileJava', 'path': ':core:compileJava', 'group': 'build'},
            ],
          },
        ],
      });

      final tasks = model.toRunTasks('gradle');
      final appTask = tasks.firstWhere((t) => t.name == ':app:assembleDebug');
      expect(appTask.command, 'gradle :app:assembleDebug');
      expect(appTask.id, 'gradle__app_assembleDebug');
      expect(appTask.moduleId, 'gradle');
      expect(tasks.firstWhere((t) => t.name == ':core:compileJava').id, 'gradle__core_compileJava');
    });

    test('空任务 / 缺字段 / 重复任务路径都能安全处理', () {
      final empty = GradleIdeModel.fromJson({'schema': 1, 'rootProject': 'demo', 'projects': []});
      expect(empty.toRunTasks('gradle'), isEmpty);

      final missing = GradleIdeModel.fromJson({'schema': 1});
      expect(missing.projects, isEmpty);

      final duplicated = GradleIdeModel.fromJson({
        'schema': 1,
        'rootProject': 'demo',
        'projects': [
          {
            'path': ':',
            'name': 'demo',
            'tasks': [
              {'name': 'build', 'path': ':build'},
              {'name': 'build', 'path': ':build'},
            ],
          },
        ],
      });
      expect(duplicated.toRunTasks('gradle'), hasLength(1));
    });

    test('schema 不匹配或内部错误时抛出 FormatException（上层归类为不可解析/执行失败）', () {
      expect(
        () => GradleIdeModel.fromJson({'schema': 0, 'error': 'Gradle 配置阶段抛错'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => GradleIdeModel.fromJson({'schema': 99}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
