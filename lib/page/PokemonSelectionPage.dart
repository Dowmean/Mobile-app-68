import 'package:assign2/page/PokemonController.dart';
import 'package:assign2/page/TeamController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PokemonSelectionPage extends StatelessWidget {
  PokemonSelectionPage({super.key});
  final poke = Get.put(PokemonController());
  final team = Get.put(TeamController());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Players'),
        automaticallyImplyLeading: false,
        actions: const [],
      ),
      body: Obx(() {
        if (poke.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            //Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: const [
                  Expanded(
                    child: Text('My Team',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            // Saved teams
            Obx(() => team.savedTeams.isEmpty
                ? Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No saved teams yet',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  )
                : SizedBox(
                    height: 110,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      scrollDirection: Axis.horizontal,
                      itemCount: team.savedTeams.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final t = team.savedTeams[i];
                        final imgs =
                            t.members.take(3).map((m) => m.image).toList();
                        return InkWell(
                          onTap: () => team.startEditSavedMembers(t.id),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: scheme.surfaceVariant.withOpacity(.25),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 10,
                                  right: 10,
                                  top: 8,
                                  child: Text(
                                    t.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 34),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (final url in imgs)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.network(url,
                                                  width: 46,
                                                  height: 46,
                                                  fit: BoxFit.contain),
                                            ),
                                          ),
                                        if (t.members.length > 3)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 6),
                                            child: Text(
                                              '+${t.members.length - 3}',
                                              style: TextStyle(
                                                  color:
                                                      scheme.onSurfaceVariant),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )),

            // TEAM BUILDER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              color: scheme.surfaceVariant.withOpacity(.1),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Team name :'),
                          const SizedBox(width: 10),
                          // กล่องใส่ชื่อกว้างพอประมาณ
                          Obx(() => SizedBox(
                                width: 420,
                                child: TextFormField(
                                  initialValue: team.teamName.value,
                                  onChanged: team.setTeamName,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              )),
                          const SizedBox(width: 10),
                          // ปุ่มรีเฟรชข้างช่องชื่อทีม
                          IconButton(
                            tooltip: 'Clear current picks',
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              team.reset();
                              team.setTeamName('');
                              poke.query.value = '';
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ช่องแสดงสมาชิกทีมจำนวน = team.limit
                      Row(
                        children: List.generate(team.limit, (index) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                left: index == 0 ? 0 : 8,
                                right: index == team.limit - 1 ? 0 : 8,
                              ),
                              child: _slot(context, index, scheme),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 16),

                      //ปุ่ม Create/Update แสดงเมื่อครบตาม limit 3
                      Obx(() {
                        final full = team.team.length == team.limit;
                        final editing = team.editingTeamId.value != null;
                        if (!full) return const SizedBox.shrink();

                        return Center(
                          child: SizedBox(
                            width: 150, //ขนาดปุ่ม
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              //icon: Icon(editing ? Icons.save : Icons.add,
                              //size: 18),
                              label: Text(editing ? 'Update' : 'OK'),
                              onPressed: () {
                                final name = team.teamName.value.trim();
                                if (name.isEmpty) {
                                  Get.snackbar(
                                      'Error', 'Team name cannot be empty.');
                                  return;
                                }
                                if (editing) {
                                  team.applyEditToSaved();
                                } else {
                                  team.createTeam(name);
                                }
                              },
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            //  Search
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Obx(() {
                final empty = poke.query.value.isEmpty;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    TextField(
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: empty ? '' : 'Search',
                        filled: true,
                        fillColor: scheme.surfaceVariant.withOpacity(.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => poke.query.value = v,
                    ),
                    if (empty)
                      const IgnorePointer(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search),
                            SizedBox(width: 8),
                            Text('Search'),
                          ],
                        ),
                      ),
                  ],
                );
              }),
            ),

            //Grid ของโปเกมอน
            Expanded(
              child: Obx(() => GridView.builder(
                    padding: const EdgeInsets.all(4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5, // 5 คอลัมน์
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0, // ความสูงของการ์ด
                    ),
                    itemCount: poke.filtered.length,
                    itemBuilder: (context, index) {
                      final p = poke.filtered[index];
                      final selected = team.isSelected(p);
                      return GestureDetector(
                        // เลือก/ยกเลิก จาก GRID เท่านั้น
                        onTap: () => team.toggle(p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  selected ? Colors.green : Colors.transparent,
                              width: 2,
                            ),
                            color: selected
                                ? Colors.green.withOpacity(.12)
                                : scheme.surfaceVariant.withOpacity(.25),
                          ),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: 10.0, left: 6, right: 6),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        p.image,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                Icons.broken_image_outlined),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0, vertical: 8.0),
                                  child: Text(
                                    _title(p.name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              if (selected)
                                const Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Icon(Icons.check_circle,
                                      color: Colors.green),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  )),
            ),
          ],
        );
      }),
    );
  }

  //สร้างช่องสมาชิกทีมทีละช่อง
  Widget _slot(BuildContext context, int index, ColorScheme scheme) {
    return Obx(() {
      final has = index < team.team.length;
      const double slotHeight = 136;

      if (!has) {
        // ช่องว่าง ไม่ต้องกดเลือกจากตรงนี้
        return Container(
          height: slotHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: scheme.surfaceVariant.withOpacity(.25),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 40, color: scheme.onSurfaceVariant),
            ],
          ),
        );
      }

      final p = team.team[index];
      return Container(
        height: slotHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: scheme.surfaceVariant.withOpacity(.2),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(p.image, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Text(
                      _title(p.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            // ปุ่มลบมุมขวาบน
            Positioned(
              right: 6,
              top: 6,
              child: InkWell(
                onTap: () => team.remove(p),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 139, 135, 135),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  String _title(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
