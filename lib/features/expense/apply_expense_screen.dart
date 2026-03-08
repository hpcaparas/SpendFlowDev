import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_router.dart';
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
  final ScrollController _scrollCtrl = ScrollController();

  final FocusNode _departmentFocus = FocusNode();
  final FocusNode _typeFocus = FocusNode();
  final FocusNode _priceWithTaxFocus = FocusNode();
  final FocusNode _taxFocus = FocusNode();
  final FocusNode _remarksFocus = FocusNode();

  final GlobalKey _purchaseMethodKey = GlobalKey();
  final GlobalKey _departmentKey = GlobalKey();
  final GlobalKey _approversKey = GlobalKey();
  final GlobalKey _typeKey = GlobalKey();
  final GlobalKey _priceKey = GlobalKey();
  final GlobalKey _taxKey = GlobalKey();
  final GlobalKey _remarksKey = GlobalKey();
  final GlobalKey _receiptKey = GlobalKey();

  int? _userId;
  String _userName = "User";

  int? _purchaseMethodId;
  int? _departmentId;
  int? _typeId;

  final _priceWithTaxCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  List<Department> _departments = [];
  List<ExpenseType> _types = [];
  List<PurchaseMethod> _purchaseMethods = [];

  List<WorkflowStep> _workflowSteps = [];
  final Map<int, int> _approverSelectionsBySequence = {};

  File? _receiptFile;
  ImageProvider? _previewImage;

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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Choose receipt source",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  tileColor: const Color(0xFFF8FAFC),
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text("Camera"),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  tileColor: const Color(0xFFF8FAFC),
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text("Gallery"),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
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

    await Future.delayed(const Duration(milliseconds: 50));
    focusNode?.requestFocus();
  }

  Future<bool> _focusFirstMissingRequiredField() async {
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

    final focused = await _focusFirstMissingRequiredField();
    if (focused) return;

    if (!_formKey.currentState!.validate()) return;

    if (_userId == null) {
      setState(() => _error = "No logged-in user. Please login again.");
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Confirm submission"),
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
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Text("Expense submitted successfully ✅"),
        ),
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
          backgroundColor: const Color(0xFFF3F7FB),
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFEFF6FF),
                      Color(0xFFF8FAFC),
                      Color(0xFFF3F7FB),
                    ],
                  ),
                ),
              ),
              RefreshIndicator(
                onRefresh: _loadUserAndMetadata,
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      _buildErrorBanner(_error!),
                      const SizedBox(height: 12),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _sectionCard(
                            key: _purchaseMethodKey,
                            title: "Method of Purchase",
                            subtitle: "Choose how this expense was paid.",
                            child: Column(
                              children: _purchaseMethods
                                  .map(
                                    (m) => Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: _purchaseMethodId == m.id
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: _purchaseMethodId == m.id
                                              ? const Color(0xFF93C5FD)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: RadioListTile<int>(
                                        value: m.id,
                                        groupValue: _purchaseMethodId,
                                        onChanged: (v) => setState(
                                          () => _purchaseMethodId = v,
                                        ),
                                        title: Text(
                                          m.description,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _sectionCard(
                            key: _departmentKey,
                            title: "Department",
                            subtitle:
                                "Select the department this expense belongs to.",
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
                              decoration: _inputDecoration(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_workflowSteps.isNotEmpty) ...[
                            _sectionCard(
                              key: _approversKey,
                              title: "Approvers",
                              subtitle:
                                  "Select approvers only where multiple users share the same org role.",
                              child: Column(
                                children: _workflowSteps
                                    .where(_needsApproverSelection)
                                    .map((step) {
                                      final selected =
                                          _approverSelectionsBySequence[step
                                              .sequenceOrder];

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
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
                                              _approverSelectionsBySequence
                                                  .remove(step.sequenceOrder);
                                            } else {
                                              _approverSelectionsBySequence[step
                                                      .sequenceOrder] =
                                                  v;
                                            }
                                          }),
                                          validator: (v) {
                                            if (step.users.length > 1 &&
                                                v == null) {
                                              return "Approver required for Step ${step.sequenceOrder}";
                                            }
                                            return null;
                                          },
                                          decoration: _inputDecoration(
                                            label:
                                                "Step ${step.sequenceOrder} (${step.orgRoleDescription})",
                                            helper:
                                                "Multiple users share this org role; please choose one.",
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _sectionCard(
                            key: _typeKey,
                            title: "Type",
                            subtitle: "Choose the expense type classification.",
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
                              decoration: _inputDecoration(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _sectionCard(
                            key: _priceKey,
                            title: "Price With Tax",
                            subtitle: "Enter the final amount including tax.",
                            child: TextFormField(
                              focusNode: _priceWithTaxFocus,
                              controller: _priceWithTaxCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                hint: "Enter amount",
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? "Required"
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _sectionCard(
                            key: _taxKey,
                            title: "Tax",
                            subtitle: "Enter the tax component of the expense.",
                            child: TextFormField(
                              focusNode: _taxFocus,
                              controller: _taxCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(hint: "Enter tax"),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? "Required"
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _sectionCard(
                            key: _remarksKey,
                            title: "Remarks",
                            subtitle: "Add receipt name or supporting notes.",
                            child: TextFormField(
                              focusNode: _remarksFocus,
                              controller: _remarksCtrl,
                              maxLength: 250,
                              decoration: _inputDecoration(
                                hint: "Receipt name / remarks",
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? "Required"
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _sectionCard(
                            key: _receiptKey,
                            title: "Receipt Image",
                            subtitle:
                                "Image should contain tax, date, vendor name, and other necessary details.",
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _pickReceipt,
                                    icon: const Icon(
                                      Icons.upload_file_outlined,
                                    ),
                                    label: const Text(
                                      "Upload / Capture Receipt",
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (_previewImage != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: AspectRatio(
                                      aspectRatio: 1.3,
                                      child: Image(
                                        image: _previewImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 26,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(
                                          Icons.receipt_long_outlined,
                                          size: 32,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          "No receipt uploaded yet",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF14B8A6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.24),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  "Submit Expense",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "Expense Application",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Welcome, $_userName",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Create a new expense request, attach your receipt, and route it through the proper approval workflow.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? label,
    String? helper,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: label,
      helperText: helper,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.4),
      ),
    );
  }

  Widget _sectionCard({
    Key? key,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
