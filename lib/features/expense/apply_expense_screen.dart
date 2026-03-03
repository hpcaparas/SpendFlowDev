import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_router.dart';
import '../profile/profile_menu.dart';
import 'apply_expense_service.dart';
import 'models/expense_models.dart';

class ApplyExpenseScreen extends StatefulWidget {
  const ApplyExpenseScreen({super.key});

  @override
  State<ApplyExpenseScreen> createState() => _ApplyExpenseScreenState();
}

class _ApplyExpenseScreenState extends State<ApplyExpenseScreen> {
  final _svc = ApplyExpenseService();

  final _formKey = GlobalKey<FormState>();

  // ✅ for scrolling to first invalid field
  final ScrollController _scrollCtrl = ScrollController();

  // ✅ Focus nodes (first invalid required field will be focused)
  final FocusNode _departmentFocus = FocusNode();
  final FocusNode _typeFocus = FocusNode();
  final FocusNode _priceWithTaxFocus = FocusNode();
  final FocusNode _taxFocus = FocusNode();
  final FocusNode _remarksFocus = FocusNode();

  // ✅ Keys to find widget positions for scrolling
  final GlobalKey _purchaseMethodKey = GlobalKey();
  final GlobalKey _departmentKey = GlobalKey();
  final GlobalKey _approversKey = GlobalKey();
  final GlobalKey _typeKey = GlobalKey();
  final GlobalKey _priceKey = GlobalKey();
  final GlobalKey _taxKey = GlobalKey();
  final GlobalKey _remarksKey = GlobalKey();
  final GlobalKey _receiptKey = GlobalKey();

  // form fields
  int? _userId;
  String _userName = "User";

  int? _purchaseMethodId;
  int? _departmentId;
  int? _typeId;

  final _priceWithTaxCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  // metadata
  List<Department> _departments = [];
  List<ExpenseType> _types = [];
  List<PurchaseMethod> _purchaseMethods = [];

  // workflow
  List<WorkflowStep> _workflowSteps = [];
  final Map<int, int> _approverSelectionsBySequence = {}; // seq -> userId

  // image
  File? _receiptFile;
  ImageProvider? _previewImage;

  // ui state
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _scrollCtrl.dispose();

    _departmentFocus.dispose();
    _typeFocus.dispose();
    _priceWithTaxFocus.dispose();
    _taxFocus.dispose();
    _remarksFocus.dispose();

    _priceWithTaxCtrl.dispose();
    _taxCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserAndMetadata();
  }

  Future<void> _loadUserAndMetadata() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString("user");
      if (raw == null) throw Exception("No logged-in user. Please login.");

      final user = jsonDecode(raw) as Map<String, dynamic>;
      _userId = (user["id"] as num).toInt();
      _userName = (user["name"] ?? "User").toString();

      final results = await Future.wait([
        _svc.fetchDepartments(),
        _svc.fetchTypes(),
        _svc.fetchPurchaseMethods(),
      ]);

      setState(() {
        _departments = results[0] as List<Department>;
        _types = results[1] as List<ExpenseType>;
        _purchaseMethods = results[2] as List<PurchaseMethod>;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onDepartmentChanged(int? deptId) async {
    setState(() {
      _departmentId = deptId;
      _workflowSteps = [];
      _approverSelectionsBySequence.clear();
      _error = null;
    });

    if (deptId == null) return;

    setState(() => _loading = true);
    try {
      final steps = await _svc.fetchWorkflowSteps(deptId);

      for (final step in steps) {
        if (step.users.isEmpty) {
          throw Exception(
            "No approver found for org role ${step.orgRoleCode}. Please contact your administrator.",
          );
        }
        if (step.users.length == 1) {
          _approverSelectionsBySequence[step.sequenceOrder] =
              step.users.first.id;
        }
      }

      setState(() => _workflowSteps = steps);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<File> _compressToJpg(File input) async {
    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      "receipt_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    final bytes = await FlutterImageCompress.compressWithFile(
      input.path,
      format: CompressFormat.jpeg,
      quality: 75,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (bytes == null) throw Exception("Failed to compress image.");

    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes);
    return outFile;
  }

  Future<void> _pickReceipt() async {
    setState(() => _error = null);

    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text("Camera"),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 100);
    if (picked == null) return;

    setState(() => _loading = true);
    try {
      final rawFile = File(picked.path);
      final compressed = await _compressToJpg(rawFile);

      setState(() {
        _receiptFile = compressed;
        _previewImage = FileImage(compressed);
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _needsApproverSelection(WorkflowStep step) => step.users.length > 1;

  List<Map<String, dynamic>> _buildFinalApprovalSteps() {
    final priceWithTax = double.tryParse(_priceWithTaxCtrl.text.trim()) ?? 0;

    final finalSteps = <Map<String, dynamic>>[];

    for (final step in _workflowSteps) {
      final stepLimit = step.amountLimit;
      final isProcessor = step.stepType.toUpperCase() == "PROCESSING";

      if (isProcessor || priceWithTax > stepLimit) {
        final selectedUserId = (step.users.length == 1)
            ? step.users.first.id
            : _approverSelectionsBySequence[step.sequenceOrder];

        if (selectedUserId == null) {
          throw Exception(
            "Please select an approver for Step ${step.sequenceOrder} (${step.orgRoleDescription}).",
          );
        }

        finalSteps.add({
          "orgRoleId": step.orgRoleId,
          "scope": step.scope,
          "stepType": step.stepType,
          "selectedUserId": selectedUserId,
        });
      }
    }

    return finalSteps;
  }

  // ✅ scroll to a specific widget key, then focus (if provided)
  Future<void> _scrollToKey(GlobalKey key, {FocusNode? focusNode}) async {
    final ctx = key.currentContext;
    if (ctx == null) {
      focusNode?.requestFocus();
      return;
    }

    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.12,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // give it a beat so the UI settles before requesting focus
    await Future.delayed(const Duration(milliseconds: 50));
    focusNode?.requestFocus();
  }

  // ✅ find first missing required field and focus it
  Future<bool> _focusFirstMissingRequiredField() async {
    // Order matters: this is the order we will focus.
    if (_purchaseMethodId == null) {
      setState(() => _error = "Method of Purchase is required.");
      await _scrollToKey(_purchaseMethodKey);
      return true;
    }

    if (_departmentId == null) {
      setState(() => _error = "Department is required.");
      await _scrollToKey(_departmentKey, focusNode: _departmentFocus);
      return true;
    }

    // Only required if there are multi-user steps that need selection
    final needsApprover =
        _workflowSteps.any((s) => s.users.length > 1) &&
        _workflowSteps.where((s) => s.users.length > 1).any((s) {
          return _approverSelectionsBySequence[s.sequenceOrder] == null;
        });

    if (needsApprover) {
      setState(() => _error = "Please select the required approver(s).");
      await _scrollToKey(_approversKey);
      return true;
    }

    if (_typeId == null) {
      setState(() => _error = "Type is required.");
      await _scrollToKey(_typeKey, focusNode: _typeFocus);
      return true;
    }

    if (_priceWithTaxCtrl.text.trim().isEmpty) {
      setState(() => _error = "Price With Tax is required.");
      await _scrollToKey(_priceKey, focusNode: _priceWithTaxFocus);
      return true;
    }

    if (_taxCtrl.text.trim().isEmpty) {
      setState(() => _error = "Tax is required.");
      await _scrollToKey(_taxKey, focusNode: _taxFocus);
      return true;
    }

    if (_remarksCtrl.text.trim().isEmpty) {
      setState(() => _error = "Remarks is required.");
      await _scrollToKey(_remarksKey, focusNode: _remarksFocus);
      return true;
    }

    if (_receiptFile == null) {
      setState(() => _error = "Please upload a receipt image.");
      await _scrollToKey(_receiptKey);
      return true;
    }

    return false;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    // ✅ Focus the first missing required field (and stop)
    final focused = await _focusFirstMissingRequiredField();
    if (focused) return;

    // ✅ still keep validators (for any additional field-level rules)
    if (!_formKey.currentState!.validate()) return;

    if (_userId == null) {
      setState(() => _error = "No logged-in user. Please login again.");
      return;
    }

    // Confirmation
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirm"),
        content: const Text("Are you sure you want to apply for this Expense?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final approvalSteps = _buildFinalApprovalSteps();

      await _svc.submitExpense(
        userId: _userId!,
        departmentId: _departmentId!,
        typeId: _typeId!,
        purchaseMethodId: _purchaseMethodId!,
        priceWithTax: _priceWithTaxCtrl.text.trim(),
        tax: _taxCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim(),
        receiptFile: _receiptFile!,
        approvalSteps: approvalSteps,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense submitted successfully ✅")),
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: RefreshIndicator(
            onRefresh: _loadUserAndMetadata,
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  "Welcome, $_userName",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Purchase Methods
                      _sectionCard(
                        key: _purchaseMethodKey,
                        title: "Method of Purchase",
                        child: Column(
                          children: _purchaseMethods
                              .map(
                                (m) => RadioListTile<int>(
                                  value: m.id,
                                  groupValue: _purchaseMethodId,
                                  onChanged: (v) =>
                                      setState(() => _purchaseMethodId = v),
                                  title: Text(m.description),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Department (int? + focus)
                      _sectionCard(
                        key: _departmentKey,
                        title: "Department",
                        child: DropdownButtonFormField<int?>(
                          focusNode: _departmentFocus,
                          value: _departmentId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text("Select Department"),
                            ),
                            ..._departments.map(
                              (d) => DropdownMenuItem<int?>(
                                value: d.id,
                                child: Text(d.name),
                              ),
                            ),
                          ],
                          onChanged: (v) => _onDepartmentChanged(v),
                          validator: (v) =>
                              v == null ? "Department is required" : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Approvers
                      if (_workflowSteps.isNotEmpty) ...[
                        _sectionCard(
                          key: _approversKey,
                          title: "Approvers",
                          child: Column(
                            children: _workflowSteps.where(_needsApproverSelection).map((
                              step,
                            ) {
                              final selected =
                                  _approverSelectionsBySequence[step
                                      .sequenceOrder];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DropdownButtonFormField<int?>(
                                  value: selected,
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text("Select Approver"),
                                    ),
                                    ...step.users.map(
                                      (u) => DropdownMenuItem<int?>(
                                        value: u.id,
                                        child: Text(u.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    if (v == null) {
                                      _approverSelectionsBySequence.remove(
                                        step.sequenceOrder,
                                      );
                                    } else {
                                      _approverSelectionsBySequence[step
                                              .sequenceOrder] =
                                          v;
                                    }
                                  }),
                                  validator: (v) {
                                    if (step.users.length > 1 && v == null) {
                                      return "Approver required for Step ${step.sequenceOrder}";
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    labelText:
                                        "Step ${step.sequenceOrder} (${step.orgRoleDescription})",
                                    helperText:
                                        "Multiple users share this org role; please choose one.",
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Type (int? + focus)
                      _sectionCard(
                        key: _typeKey,
                        title: "Type",
                        child: DropdownButtonFormField<int?>(
                          focusNode: _typeFocus,
                          value: _typeId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text("Select Purchase Type"),
                            ),
                            ..._types.map(
                              (t) => DropdownMenuItem<int?>(
                                value: t.id,
                                child: Text(t.name),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _typeId = v),
                          validator: (v) =>
                              v == null ? "Type is required" : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Price With Tax
                      _sectionCard(
                        key: _priceKey,
                        title: "Price With Tax",
                        child: TextFormField(
                          focusNode: _priceWithTaxFocus,
                          controller: _priceWithTaxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: "Enter amount",
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Required"
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tax
                      _sectionCard(
                        key: _taxKey,
                        title: "Tax",
                        child: TextFormField(
                          focusNode: _taxFocus,
                          controller: _taxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: "Enter tax",
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Required"
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Remarks
                      _sectionCard(
                        key: _remarksKey,
                        title: "Remarks",
                        child: TextFormField(
                          focusNode: _remarksFocus,
                          controller: _remarksCtrl,
                          maxLength: 250,
                          decoration: const InputDecoration(
                            hintText: "Receipt name / remarks",
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Required"
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Receipt
                      _sectionCard(
                        key: _receiptKey,
                        title: "Receipt Image",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickReceipt,
                              icon: const Icon(Icons.upload_file),
                              label: const Text("Upload / Capture Receipt"),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Image should contain tax, date, vendor name, and other necessary details.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_previewImage != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image(
                                  image: _previewImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: const Text("Submit"),
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_loading)
          Container(
            color: Colors.black.withOpacity(0.40),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _sectionCard({
    Key? key,
    required String title,
    required Widget child,
  }) {
    return Card(
      key: key,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
