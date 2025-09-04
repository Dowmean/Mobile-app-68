import 'package:assign2/page/PokemonController.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SavedTeam {
  final int id;
  final String name;
  final List<Pokemon> members;

  SavedTeam({required this.id, required this.name, required this.members});

  SavedTeam copyWith({int? id, String? name, List<Pokemon>? members}) =>
      SavedTeam(id: id ?? this.id, name: name ?? this.name, members: members ?? this.members);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'members': members.map((p) => p.toMap()).toList(),
      };

  factory SavedTeam.fromMap(Map<String, dynamic> m) => SavedTeam(
        id: m['id'] as int,
        name: m['name'] as String,
        members: ((m['members'] as List?) ?? const [])
            .map((e) => Pokemon.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class TeamController extends GetxController {
  final team = <Pokemon>[].obs;
  final teamName = 'My Team'.obs;

  /// บังคับให้ทีมมีสมาชิก 3ตัวพอดี
  final int limit = 3;

  final GetStorage _box = GetStorage();

  static const _kTeamFull = 'teamFull';
  static const _kTeamName = 'teamName';
  static const _kSavedTeams = 'savedTeams';

  final savedTeams = <SavedTeam>[].obs;

  /// id ทีมที่กำลังแก้ไขอยู่ (null = ไม่ได้แก้ทีมที่บันทึก)
  final Rxn<int> editingTeamId = Rxn<int>();

  @override
  void onInit() {
    super.onInit();

    // load working team ค้างไว้ (ตัดให้ไม่เกิน limit)
    final savedList = _box.read<List>(_kTeamFull) ?? const [];
    final saved = savedList
        .map((e) => Pokemon.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
        .take(limit)
        .toList();
    if (saved.isNotEmpty) team.assignAll(saved);

    teamName.value = _box.read<String>(_kTeamName) ?? teamName.value;

    ever(team, (_) => _persist());
    ever(teamName, (v) => _box.write(_kTeamName, v));

    // load saved teams ทั้งหมด
    final rawSavedTeams = _box.read<List>(_kSavedTeams) ?? const [];
    final loaded = rawSavedTeams
        .map((e) => SavedTeam.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (loaded.isNotEmpty) savedTeams.assignAll(loaded);
  }

  //Working team
  void toggle(Pokemon p) {
    if (team.contains(p)) {
      team.remove(p);
    } else {
      if (team.length >= limit) {
        Get.snackbar('Limit reached', 'You must have exactly $limit Pokémon.');
        return;
      }
      team.add(p);
    }
  }

  void remove(Pokemon p) => team.remove(p);
  bool isSelected(Pokemon p) => team.contains(p);

  void reset() {
    team.clear();
    editingTeamId.value = null; // ออกจากโหมดแก้ไข
    _box.remove(_kTeamFull);
  }

  void setTeamName(String v) => teamName.value = v;

  void _persist() => _box.write(_kTeamFull, team.map((p) => p.toMap()).toList());

  // Saved teams 
  void createTeam(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar('Invalid name', 'Please enter a team name.');
      return;
    }
    if (team.length != limit) {
      Get.snackbar('Invalid team', 'Select exactly $limit Pokémon before saving.');
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch;
    final newTeam = SavedTeam(
      id: id,
      name: trimmed,
      members: List<Pokemon>.from(team.take(limit)),
    );
    savedTeams.add(newTeam);
    _persistSavedTeams();
    Get.snackbar('Saved', 'Team "$trimmed" has been created.');
  }

  void renameSavedTeam(int id, String newName) {
    final idx = savedTeams.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    savedTeams[idx] = savedTeams[idx].copyWith(name: newName.trim());
    savedTeams.refresh();
    _persistSavedTeams();
  }

  void _persistSavedTeams() {
    _box.write(_kSavedTeams, savedTeams.map((t) => t.toMap()).toList());
  }

  /// โหลดทีมที่บันทึกไว้มาเป็นทีมปัจจุบันเพื่อแก้ไขสมาชิก (ตัดเหลือ limit)
  void startEditSavedMembers(int id) {
    final idx = savedTeams.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = savedTeams[idx];
    team.assignAll(t.members.take(limit).toList());
    teamName.value = t.name;
    editingTeamId.value = id;
    Get.snackbar('Editing', 'Edit members, then press Update Team.');
  }

  /// บันทึกการแก้ไขกลับไปยัง saved team (ต้องครบ 3 ตัว)
  void applyEditToSaved() {
    final id = editingTeamId.value;
    if (id == null) return;
    if (team.length != limit) {
      Get.snackbar('Invalid team', 'Team must contain exactly $limit Pokémon.');
      return;
    }
    final idx = savedTeams.indexWhere((t) => t.id == id);
    if (idx < 0) return;

    savedTeams[idx] = savedTeams[idx].copyWith(
      name: teamName.value.trim().isEmpty ? savedTeams[idx].name : teamName.value.trim(),
      members: List<Pokemon>.from(team.take(limit)),
    );
    savedTeams.refresh();
    _persistSavedTeams();
    editingTeamId.value = null;
    Get.snackbar('Updated', 'Team updated successfully.');
  }

  /// แทนที่สมาชิกตำแหน่ง [index] ด้วย [newP] กันซ้ำ
  void replaceAt(int index, Pokemon newP) {
    if (index < 0 || index >= team.length) return;
    final dupIdx = team.indexWhere((e) => e.id == newP.id);
    if (dupIdx != -1 && dupIdx != index) {
      Get.snackbar('Duplicate', '${newP.name} is already in the team.');
      return;
    }
    team[index] = newP;
    team.refresh();
    _persist();
  }

  /// อัปเดต saved team โดยกำหนดชื่อ + สมาชิกใหม่ (ต้องครบ 3 ตัว)
  void updateSavedTeam(int id, String newName, List<Pokemon> newMembers) {
    final idx = savedTeams.indexWhere((t) => t.id == id);
    if (idx < 0) return;

    if (newMembers.length != limit) {
      Get.snackbar('Invalid team', 'Team must contain exactly $limit Pokémon.');
      return;
    }

    final name = (newName.trim().isEmpty) ? savedTeams[idx].name : newName.trim();
    final members = newMembers.take(limit).toList();

    savedTeams[idx] = savedTeams[idx].copyWith(name: name, members: members);
    savedTeams.refresh();
    _persistSavedTeams();
    Get.snackbar('Updated', 'Team updated successfully.');
  }

  void deleteSavedTeam(int id) {}
}
