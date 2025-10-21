import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum StageStatus { pending, inProgress, done }

class Stage {
  final String id;
  String name;
  StageStatus status;

  Stage({
    required this.id,
    required this.name,
    this.status = StageStatus.pending,
  });

  Stage copyWith({String? name, StageStatus? status}) => Stage(
        id: id,
        name: name ?? this.name,
        status: status ?? this.status,
      );
}

class Operation {
  final String id;
  final String? operationCode;
  final String? businessFieldId;
  final String clientName;
  final String productType;
  final String paperType;
  final double length;
  final double width;
  final double height;
  final int quantity;
  final String printing;
  final double? price;
  final DateTime createdAt;
  final List<Stage> stages;

  Operation({
    required this.id,
    this.operationCode,
    this.businessFieldId,
    required this.clientName,
    required this.productType,
    required this.paperType,
    required this.length,
    required this.width,
    required this.height,
    required this.quantity,
    required this.printing,
    this.price,
    required this.createdAt,
    required this.stages,
  });
}

class ManufacturingProvider extends ChangeNotifier {
  // Ephemeral in-memory store for demo
  final List<Operation> _operations = [];
  List<Operation> get operations => List.unmodifiable(_operations);

  // Available default stages (can be augmented)
  final List<String> defaultStageNames = const [
    'تصميم',
    'اعتماد السعر',
    'شراء الورق',
    'تجهيز الطباعة',
    'طباعة أوفست',
    'سلوفان مط',
    'سلوفان لامع',
    'سبوت يوفي',
    'بصمة',
    'كوفراج',
    'تجميع وتلزيق',
    'تسليم نهائي',
  ];

  // Working set while creating a new operation
  final List<Stage> _workingStages = [];
  List<Stage> get workingStages => List.unmodifiable(_workingStages);

  ManufacturingProvider() {
    resetWorkingStages();
  }

  void resetWorkingStages() {
    _workingStages
      ..clear()
      ..addAll(defaultStageNames
          .map((n) => Stage(id: const Uuid().v4(), name: n)));
    notifyListeners();
  }

  void setWorkingFromNames(List<String> names) {
    _workingStages
      ..clear()
      ..addAll(names.map((n) => Stage(id: const Uuid().v4(), name: n)));
    notifyListeners();
  }

  void addCustomStage(String name) {
    if (name.trim().isEmpty) return;
    _workingStages.add(Stage(id: const Uuid().v4(), name: name.trim()));
    notifyListeners();
  }

  void removeStage(String id) {
    _workingStages.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void updateStageStatus(String id, StageStatus status) {
    final idx = _workingStages.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    _workingStages[idx] = _workingStages[idx].copyWith(status: status);
    notifyListeners();
  }

  void reorderStage(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _workingStages.removeAt(oldIndex);
    _workingStages.insert(newIndex, item);
    notifyListeners();
  }

  void toggleInclude(String id, bool include) {
    // For this demo, inclusion is represented by presence; toggle translates to remove/add.
    if (include) return; // no-op: inclusion is default if exists
    removeStage(id);
  }

  void saveOperation({
    String? operationCode,
    String? businessFieldId,
    required String clientName,
    required String productType,
    required String paperType,
    required double length,
    required double width,
    required double height,
    required int quantity,
    required String printing,
    double? price,
  }) {
    final op = Operation(
      id: const Uuid().v4(),
      operationCode: operationCode,
      businessFieldId: businessFieldId,
      clientName: clientName,
      productType: productType,
      paperType: paperType,
      length: length,
      width: width,
      height: height,
      quantity: quantity,
      printing: printing,
      stages: _workingStages.map((s) => s.copyWith()).toList(),
      price: price,
      createdAt: DateTime.now(),
    );
    _operations.add(op);
    notifyListeners();
  }
}