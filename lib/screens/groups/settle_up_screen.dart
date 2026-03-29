import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';

class SettleUpScreen extends StatefulWidget {
  const SettleUpScreen({
    super.key,
    required this.roomId,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.maxAmount,
    required this.userWillPay,
  });

  final String roomId;
  final String counterpartyId;
  final String counterpartyName;
  final double maxAmount;
  final bool userWillPay;

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  final service = FirestoreService();
  final amountController = TextEditingController();

  bool _saving = false;
  bool _currentUserPaid = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    amountController.text = widget.maxAmount.toStringAsFixed(2);
    _currentUserPaid = widget.userWillPay;
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currentUserId = service.uid;
    if (currentUserId == null) {
      setState(() => _error = 'Please login again');
      return;
    }

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than Rs 0');
      return;
    }

    if (amount - widget.maxAmount > 0.01) {
      setState(
        () =>
            _error = 'Amount cannot be more than Rs ${widget.maxAmount.toStringAsFixed(2)}',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await service.settleUp(
        roomId: widget.roomId,
        fromUserId: _currentUserPaid ? currentUserId : widget.counterpartyId,
        toUserId: _currentUserPaid ? widget.counterpartyId : currentUserId,
        amount: amount,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      setState(() => _error = 'Failed to save the settlement');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final headline = 'Settle with ${widget.counterpartyName}';
    final helper = _currentUserPaid
        ? 'Record a payment you made to ${widget.counterpartyName}.'
        : 'Record a payment ${widget.counterpartyName} made to you.';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Text(
                      headline,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.cardSoft, AppColors.bg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outstanding Balance',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs ${widget.maxAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      helper,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Who paid?',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _payerChip(
                            label: 'You paid',
                            selected: _currentUserPaid,
                            onTap: () => setState(() => _currentUserPaid = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _payerChip(
                            label: '${widget.counterpartyName} paid',
                            selected: !_currentUserPaid,
                            onTap: () => setState(() => _currentUserPaid = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Settlement Amount',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        prefixText: 'Rs ',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _quickAmountChip(widget.maxAmount / 4),
                        _quickAmountChip(widget.maxAmount / 2),
                        _quickAmountChip(widget.maxAmount),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.danger.withOpacity(0.5)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Save Settlement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _payerChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : AppColors.cardSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.black : AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _quickAmountChip(double amount) {
    final safeAmount = amount <= 0 ? widget.maxAmount : amount;
    return ActionChip(
      onPressed: () {
        amountController.text = safeAmount.toStringAsFixed(2);
        setState(() {});
      },
      backgroundColor: AppColors.cardSoft,
      side: const BorderSide(color: AppColors.border),
      label: Text(
        'Rs ${safeAmount.toStringAsFixed(2)}',
        style: const TextStyle(color: AppColors.text),
      ),
    );
  }
}
