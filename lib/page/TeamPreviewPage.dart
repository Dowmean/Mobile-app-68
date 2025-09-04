import 'package:assign2/page/TeamController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
 // เพื่ออ้างถึงคลาส Pokemon (ถ้าจำเป็น)

class TeamPreviewPage extends StatelessWidget {
  TeamPreviewPage({super.key});

  final TeamController teamController = Get.find<TeamController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Preview')),
      body: Obx(() {
        final team = teamController.team;
        if (team.isEmpty) {
          return const Center(child: Text('No players selected'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: team.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = team[i]; // p is Pokemon
            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(p.image),
                onBackgroundImageError: (_, __) {},
              ),
              title: Text(
                _titleCase(p.name),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              subtitle: Text('ID: ${p.id}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Remove from team',
                onPressed: () => teamController.remove(p),
              ),
            );
          },
        );
      }),
    );
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
