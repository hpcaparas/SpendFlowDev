class Department {
  final int id;
  final String name;

  Department({required this.id, required this.name});

  factory Department.fromJson(Map<String, dynamic> json) => Department(
    id: (json["id"] as num).toInt(),
    name: (json["name"] ?? "").toString(),
  );
}

class ExpenseType {
  final int id;
  final String name;

  ExpenseType({required this.id, required this.name});

  factory ExpenseType.fromJson(Map<String, dynamic> json) => ExpenseType(
    id: (json["id"] as num).toInt(),
    name: (json["name"] ?? "").toString(),
  );
}

class PurchaseMethod {
  final int id;
  final String description;

  PurchaseMethod({required this.id, required this.description});

  factory PurchaseMethod.fromJson(Map<String, dynamic> json) => PurchaseMethod(
    id: (json["id"] as num).toInt(),
    description: (json["description"] ?? "").toString(),
  );
}

class StepUser {
  final int id;
  final String name;

  StepUser({required this.id, required this.name});

  factory StepUser.fromJson(Map<String, dynamic> json) => StepUser(
    id: (json["id"] as num).toInt(),
    name: (json["name"] ?? "").toString(),
  );
}

class WorkflowStep {
  final int sequenceOrder;
  final int orgRoleId;
  final String orgRoleCode;
  final String orgRoleDescription;
  final String scope; // DEPARTMENT / COMPANY
  final String stepType; // APPROVAL / PROCESSING
  final double amountLimit;
  final List<StepUser> users;

  WorkflowStep({
    required this.sequenceOrder,
    required this.orgRoleId,
    required this.orgRoleCode,
    required this.orgRoleDescription,
    required this.scope,
    required this.stepType,
    required this.amountLimit,
    required this.users,
  });

  factory WorkflowStep.fromJson(Map<String, dynamic> json) => WorkflowStep(
    sequenceOrder: (json["sequenceOrder"] as num).toInt(),
    orgRoleId: (json["orgRoleId"] as num).toInt(),
    orgRoleCode: (json["orgRoleCode"] ?? "").toString(),
    orgRoleDescription: (json["orgRoleDescription"] ?? "").toString(),
    scope: (json["scope"] ?? "DEPARTMENT").toString(),
    stepType: (json["stepType"] ?? "APPROVAL").toString(),
    amountLimit: (json["amountLimit"] == null)
        ? 0
        : (json["amountLimit"] as num).toDouble(),
    users: ((json["users"] ?? []) as List)
        .map((u) => StepUser.fromJson(u as Map<String, dynamic>))
        .toList(),
  );
}
