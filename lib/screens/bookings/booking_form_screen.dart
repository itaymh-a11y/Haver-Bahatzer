import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/kennel_constants.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';
import '../../providers/vacation_provider.dart';
import '../../widgets/bookings/dog_multi_selector.dart';
import '../../widgets/bookings/kennel_selector.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_snackbar.dart';
import '../../widgets/common/loading_overlay.dart';

enum BookingFormMode { add, edit }

class BookingFormScreen extends StatefulWidget {
  final Booking? booking;
  final DateTime? initialDate;
  final BookingType? initialType;
  final List<String>? initialDogIds;
  final String? initialKennelId;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  /// After saving a new boarding booking, clear soft hold on this intro.
  final String? clearSoftHoldIntroId;

  const BookingFormScreen({
    super.key,
    this.booking,
    this.initialDate,
    this.initialType,
    this.initialDogIds,
    this.initialKennelId,
    this.initialStartDate,
    this.initialEndDate,
    this.clearSoftHoldIntroId,
  });

  BookingFormMode get mode =>
      booking == null ? BookingFormMode.add : BookingFormMode.edit;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late BookingType _selectedType;
  late List<String> _selectedDogIds;
  late String? _selectedKennelId;
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay? _meetingTime;
  late TextEditingController _priceController;
  late TextEditingController _dailyRateController;
  late TextEditingController _changedDailyRateController;
  late TextEditingController _paymentAmountController;
  late bool _chargeCheckoutDay;
  late bool _hasRateChange;
  DateTime? _rateChangeStartDate;
  late bool _hasKennelChange;
  DateTime? _kennelChangeStartDate;
  String? _kennelChangeKennelId;
  late bool _hasSoftHold;
  late DateTime _softHoldStartDate;
  late DateTime _softHoldEndDate;
  String? _softHoldKennelId;
  late bool _isPaid;
  late bool _splitPayment;
  DateTime? _paymentDate;
  PaymentMethod? _paymentMethod;
  late List<PaymentRecord> _editablePayments;

  final _dateFormat = DateFormat('dd/MM/yyyy', 'he');
  final FocusNode _priceFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    _selectedType =
        b?.type ?? widget.initialType ?? BookingType.boarding;
    _selectedDogIds = List.from(b?.dogIds ?? widget.initialDogIds ?? []);
    _selectedKennelId = b?.kennelId ?? widget.initialKennelId;
    _startDate = b?.startDate ??
        widget.initialStartDate ??
        widget.initialDate ??
        DateTime.now();
    _endDate = b?.endDate ??
        widget.initialEndDate ??
        widget.initialDate ??
        DateTime.now();
    _priceController =
        TextEditingController(text: b?.totalPrice?.toStringAsFixed(0) ?? '');
    _dailyRateController =
        TextEditingController(text: b?.bookingDailyRate?.toStringAsFixed(0) ?? '');
    _changedDailyRateController = TextEditingController(
      text: b?.rateChangeDailyRate?.toStringAsFixed(0) ?? '',
    );
    _paymentAmountController = TextEditingController();
    _chargeCheckoutDay = b?.chargeCheckoutDay ?? true;
    _hasRateChange = b?.rateChangeStartDate != null && b?.rateChangeDailyRate != null;
    _rateChangeStartDate = b?.rateChangeStartDate;
    _hasKennelChange = b?.hasKennelChange ?? false;
    _kennelChangeStartDate = b?.kennelChangeStartDate;
    _kennelChangeKennelId = b?.kennelChangeKennelId;
    _hasSoftHold = b?.hasSoftHold ?? false;
    _softHoldStartDate = b?.softHoldStartDate ?? _startDate;
    _softHoldEndDate = b?.softHoldEndDate ?? _startDate;
    _softHoldKennelId = b?.softHoldKennelId;
    _isPaid = b?.isPaid ?? false;
    _splitPayment = false;
    _paymentDate = DateTime.now();
    _paymentMethod = b?.paymentMethod;
    _editablePayments = List<PaymentRecord>.from(b?.payments ?? const []);

    if (b != null) {
      _splitPayment = !b.isFullyPaid && b.paidAmount > 0;
      if (b.payments.isNotEmpty) {
        _paymentMethod = b.payments.last.method;
        _paymentDate = b.payments.last.paidAt;
      }
    }

    if (b?.meetingTime != null) {
      final parts = b!.meetingTime!.split(':');
      if (parts.length == 2) {
        _meetingTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _priceFocusNode.dispose();
    _priceController.dispose();
    _dailyRateController.dispose();
    _changedDailyRateController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('he', 'IL'),
    );
    if (picked == null) return;
    setState(() => _paymentDate = picked);
  }

  Future<void> _pickRateChangeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rateChangeStartDate ?? _startDate,
      firstDate: _startDate,
      lastDate: _endDate,
      locale: const Locale('he', 'IL'),
    );
    if (picked == null) return;
    setState(() {
      _rateChangeStartDate = picked;
      _recalcPrice();
    });
  }

  Future<void> _pickKennelChangeDate() async {
    final firstChangeDay = _startDate.add(const Duration(days: 1));
    if (firstChangeDay.isAfter(_endDate)) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _kennelChangeStartDate ?? firstChangeDay,
      firstDate: firstChangeDay,
      lastDate: _endDate,
      locale: const Locale('he', 'IL'),
    );
    if (picked == null) return;
    setState(() => _kennelChangeStartDate = picked);
  }

  void _clampKennelChangeDate() {
    if (_kennelChangeStartDate == null) return;
    final firstChangeDay = _startDate.add(const Duration(days: 1));
    if (firstChangeDay.isAfter(_endDate)) {
      _kennelChangeStartDate = null;
      _hasKennelChange = false;
      _kennelChangeKennelId = null;
      return;
    }
    if (_kennelChangeStartDate!.isBefore(firstChangeDay)) {
      _kennelChangeStartDate = firstChangeDay;
    } else if (_kennelChangeStartDate!.isAfter(_endDate)) {
      _kennelChangeStartDate = _endDate;
    }
  }

  Future<void> _editPaymentAt(int index) async {
    final existing = _editablePayments[index];
    final amountController =
        TextEditingController(text: existing.amount.toStringAsFixed(0));
    var selectedMethod = existing.method;
    var selectedDate = existing.paidAt;

    final updated = await showDialog<PaymentRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('עריכת תשלום'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: AppStrings.amountPaidNow,
                  prefixText: '₪',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: selectedMethod,
                decoration:
                    const InputDecoration(labelText: AppStrings.paymentMethod),
                items: PaymentMethod.values
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.hebrewLabel),
                        ))
                    .toList(),
                onChanged: (m) {
                  if (m != null) setLocal(() => selectedMethod = m);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.paymentDate),
                trailing: Text(
                  _dateFormat.format(selectedDate),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    locale: const Locale('he', 'IL'),
                  );
                  if (picked != null) setLocal(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () {
                final amount =
                    double.tryParse(amountController.text.replaceAll(',', '.'));
                if (amount == null || amount <= 0) return;
                Navigator.pop(
                  ctx,
                  PaymentRecord(
                    amount: amount,
                    method: selectedMethod,
                    paidAt: selectedDate,
                  ),
                );
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );

    if (updated == null) return;
    setState(() {
      _editablePayments[index] = updated;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final first = isStart ? DateTime(2020) : _startDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
      locale: const Locale('he', 'IL'),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
      if (_rateChangeStartDate != null) {
        if (_rateChangeStartDate!.isBefore(_startDate)) {
          _rateChangeStartDate = _startDate;
        } else if (_rateChangeStartDate!.isAfter(_endDate)) {
          _rateChangeStartDate = _endDate;
        }
      }
      _clampKennelChangeDate();
    });
    _recalcPrice();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _meetingTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _meetingTime = picked);
  }

  Future<void> _pickSoftHoldDate({required bool isStart}) async {
    final initial = isStart ? _softHoldStartDate : _softHoldEndDate;
    final first = isStart ? DateTime(2020) : _softHoldStartDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(2100),
      locale: const Locale('he', 'IL'),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _softHoldStartDate = picked;
        if (_softHoldEndDate.isBefore(_softHoldStartDate)) {
          _softHoldEndDate = _softHoldStartDate;
        }
      } else {
        _softHoldEndDate = picked;
      }
    });
  }

  void _recalcPrice() {
    if (_selectedType != BookingType.boarding) return;
    final dogs = context.read<DogProvider>().dogs;
    final defaultDailyRate = dogs
        .where((d) => _selectedDogIds.contains(d.id))
        .fold<double>(0, (sum, d) => sum + (d.dailyRate ?? 0));
    var baseDailyRate =
        double.tryParse(_dailyRateController.text.replaceAll(',', '.'));
    if (baseDailyRate == null || baseDailyRate <= 0) {
      baseDailyRate = defaultDailyRate;
      if (baseDailyRate > 0) {
        _dailyRateController.text = baseDailyRate.toStringAsFixed(0);
      }
    }
    if (baseDailyRate <= 0) return;

    final rawDays =
        _endDate.difference(_startDate).inDays + (_chargeCheckoutDay ? 1 : 0);
    final billableDays = rawDays < 1 ? 1 : rawDays;

    var totalPrice = 0.0;
    final changedDailyRate = double.tryParse(
      _changedDailyRateController.text.replaceAll(',', '.'),
    );

    if (_hasRateChange &&
        _rateChangeStartDate != null &&
        changedDailyRate != null &&
        changedDailyRate > 0) {
      for (int i = 0; i < billableDays; i++) {
        final day = _startDate.add(Duration(days: i));
        totalPrice += day.isBefore(_rateChangeStartDate!)
            ? baseDailyRate
            : changedDailyRate;
      }
    } else {
      totalPrice = baseDailyRate * billableDays;
    }

    if (_priceFocusNode.hasFocus) return;
    _priceController.text = totalPrice.toStringAsFixed(0);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final vacationProvider = context.read<VacationProvider>();

    if (_selectedType == BookingType.boarding) {
      if (vacationProvider.boardingRangeBlocked(_startDate, _endDate)) {
        if (mounted) showErrorSnackbar(context, AppStrings.conflictVacation);
        return;
      }
    } else if (_selectedType == BookingType.introMeeting) {
      if (vacationProvider.isDayBlocked(_startDate)) {
        final continueAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(AppStrings.introDuringVacationTitle),
            content: const Text(AppStrings.introDuringVacationMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(AppStrings.continueAction),
              ),
            ],
          ),
        );
        if (continueAnyway != true) return;
      }
    }

    final provider = context.read<BookingProvider>();

    // Conflict detection
    final dogConflict = provider.checkDogConflict(
      _selectedDogIds,
      _startDate,
      _endDate,
      excludeId: widget.booking?.id,
    );
    if (dogConflict != null) {
      if (mounted) showErrorSnackbar(context, dogConflict);
      return;
    }

    if (_selectedType == BookingType.boarding && _selectedKennelId != null) {
      if (_hasKennelChange) {
        if (_kennelChangeStartDate == null ||
            !_kennelChangeStartDate!.isAfter(_startDate)) {
          if (mounted) {
            showErrorSnackbar(context, AppStrings.kennelChangeDateInvalid);
          }
          return;
        }
        if (_kennelChangeKennelId == null ||
            _kennelChangeKennelId == _selectedKennelId) {
          if (mounted) {
            showErrorSnackbar(context, AppStrings.kennelChangeSameKennel);
          }
          return;
        }
      }

      final kennelsToCheck = <String>{_selectedKennelId!};
      if (_hasKennelChange && _kennelChangeKennelId != null) {
        kennelsToCheck.add(_kennelChangeKennelId!);
      }

      for (final kennelId in kennelsToCheck) {
        final kennel = KennelConstants.findById(kennelId);
        if (kennel == null) continue;

        if (_selectedDogIds.length > kennel.maxDogs) {
          if (mounted) {
            showErrorSnackbar(
              context,
              AppStrings.kennelMaxDogsExceeded(kennel.maxDogs),
            );
          }
          return;
        }

        if (kennel.sameOwnerRequired && _selectedDogIds.length > 1) {
          final dogs = context.read<DogProvider>().dogs;
          final ownerPhones = dogs
              .where((d) => _selectedDogIds.contains(d.id))
              .map((d) => d.ownerPhone)
              .toSet();
          if (ownerPhones.length > 1) {
            if (mounted) {
              showErrorSnackbar(context, AppStrings.conflictSameOwner);
            }
            return;
          }
        }
      }

      final kennelConflict = provider.checkKennelConflict(
        dogIds: _selectedDogIds,
        start: _startDate,
        end: _endDate,
        kennelId: _selectedKennelId,
        kennelChangeStartDate:
            _hasKennelChange ? _kennelChangeStartDate : null,
        kennelChangeKennelId:
            _hasKennelChange ? _kennelChangeKennelId : null,
        excludeId: widget.booking?.id,
      );
      if (kennelConflict != null) {
        if (mounted) showErrorSnackbar(context, kennelConflict);
        return;
      }

      final softHoldConflicts = provider.findSoftHoldConflicts(
        dogIds: _selectedDogIds,
        start: _startDate,
        end: _endDate,
        kennelId: _selectedKennelId!,
        kennelChangeStartDate:
            _hasKennelChange ? _kennelChangeStartDate : null,
        kennelChangeKennelId:
            _hasKennelChange ? _kennelChangeKennelId : null,
        excludeId: widget.booking?.id,
      );
      if (softHoldConflicts.isNotEmpty) {
        final dateFormat = DateFormat('dd/MM/yyyy', 'he');
        final dogs = context.read<DogProvider>().dogs;
        final lines = softHoldConflicts.map((c) {
          final names = c.introBooking.dogIds
              .map((id) {
                final idx = dogs.indexWhere((d) => d.id == id);
                return idx != -1 ? dogs[idx].name : id;
              })
              .join(', ');
          final kennel = KennelConstants.findById(
                  c.introBooking.softHoldKennelId!)
              ?.hebrewName;
          final range =
              '${dateFormat.format(c.introBooking.softHoldStartDate!)} – ${dateFormat.format(c.introBooking.softHoldEndDate!)}';
          final alt = c.alternativeKennelId == null
              ? AppStrings.softHoldNoAltKennel
              : '${AppStrings.softHoldAltKennel}: ${KennelConstants.findById(c.alternativeKennelId!)?.hebrewName ?? c.alternativeKennelId}';
          return '$names\n$kennel • $range\n$alt';
        }).join('\n\n');

        final continueSoft = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(AppStrings.softHoldOverlapTitle),
            content: Text('$lines\n\n${AppStrings.softHoldOverlapContinue}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(AppStrings.continueAction),
              ),
            ],
          ),
        );
        if (continueSoft != true) return;
      }

      final hasSameDayCheckout = provider.hasSameDayTurnoverWarning(
        kennelId: _selectedKennelId,
        start: _startDate,
        kennelChangeStartDate:
            _hasKennelChange ? _kennelChangeStartDate : null,
        kennelChangeKennelId:
            _hasKennelChange ? _kennelChangeKennelId : null,
        excludeId: widget.booking?.id,
      );
      if (hasSameDayCheckout) {
        final continueAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(AppStrings.sameDayTurnoverTitle),
            content: const Text(AppStrings.sameDayTurnoverMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(AppStrings.continueAction),
              ),
            ],
          ),
        );
        if (continueAnyway != true) return;
      }

      final intactOverlaps = provider.findIntactOppositeSexOverlaps(
        dogIds: _selectedDogIds,
        start: _startDate,
        end: _endDate,
        allDogs: context.read<DogProvider>().dogs,
        excludeId: widget.booking?.id,
      );
      if (intactOverlaps.isNotEmpty) {
        final dateFormat = DateFormat('dd/MM/yyyy', 'he');
        final lines = intactOverlaps.map((overlap) {
          final range = dateFormat.format(overlap.overlapStart) ==
                  dateFormat.format(overlap.overlapEnd)
              ? dateFormat.format(overlap.overlapStart)
              : '${dateFormat.format(overlap.overlapStart)} – ${dateFormat.format(overlap.overlapEnd)}';
          return AppStrings.intactOppositeSexOverlapLine(
            maleDogName: overlap.maleDogName,
            femaleDogName: overlap.femaleDogName,
            dateRange: range,
          );
        }).join('\n\n');

        final continueIntactOverlap = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(AppStrings.intactOppositeSexTitle),
            content: Text('$lines\n\n${AppStrings.intactOppositeSexContinue}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(AppStrings.continueAction),
              ),
            ],
          ),
        );
        if (continueIntactOverlap != true) return;
      }
    }

    final meetingTimeStr = _meetingTime != null
        ? '${_meetingTime!.hour.toString().padLeft(2, '0')}:${_meetingTime!.minute.toString().padLeft(2, '0')}'
        : null;

    if (_selectedType == BookingType.introMeeting && _hasSoftHold) {
      if (_softHoldKennelId == null || _softHoldKennelId!.isEmpty) {
        if (mounted) showErrorSnackbar(context, AppStrings.softHoldRequired);
        return;
      }
      if (_softHoldEndDate.isBefore(_softHoldStartDate)) {
        if (mounted) showErrorSnackbar(context, AppStrings.softHoldRequired);
        return;
      }
    }

    final now = DateTime.now();
    final totalPrice = _selectedType == BookingType.boarding
        ? double.tryParse(_priceController.text)
        : null;

    final existingPayments = _editablePayments;
    final existingPaidAmount =
        existingPayments.fold<double>(0, (sum, p) => sum + p.amount);
    final totalForPayment = totalPrice ?? 0;
    final remainingBeforePayment = (totalForPayment - existingPaidAmount) < 0
        ? 0.0
        : (totalForPayment - existingPaidAmount);

    PaymentRecord? newPayment;
    if (_selectedType == BookingType.boarding && _isPaid) {
      final enteredAmount =
          double.tryParse(_paymentAmountController.text.replaceAll(',', '.'));
      final hasExplicitAmount = enteredAmount != null && enteredAmount > 0;
      final hasPriorPayments = existingPayments.isNotEmpty;

      var shouldAddPayment = false;
      var amountToAdd = 0.0;

      if (_splitPayment) {
        if (!hasExplicitAmount) {
          if (mounted) {
            showErrorSnackbar(context, 'יש להזין סכום לתשלום בפיצול');
          }
          return;
        }
        shouldAddPayment = true;
        amountToAdd = enteredAmount;
      } else if (hasPriorPayments) {
        // Never auto-create a payment for the remaining balance when payments
        // already exist — that would fake money received (e.g. after manual total edit).
        if (hasExplicitAmount) {
          shouldAddPayment = true;
          amountToAdd = enteredAmount;
        }
      } else {
        // First payment(s): allow one-shot full remainder without split.
        if (remainingBeforePayment <= 0.01 && !hasExplicitAmount) {
          shouldAddPayment = false;
        } else {
          shouldAddPayment = true;
          amountToAdd =
              hasExplicitAmount ? enteredAmount : remainingBeforePayment;
        }
      }

      if (shouldAddPayment) {
        if (_paymentMethod == null) {
          if (mounted) showErrorSnackbar(context, AppStrings.paymentMethod);
          return;
        }
        if (amountToAdd <= 0) {
          if (mounted) {
            showErrorSnackbar(context, 'יש להזין סכום תקין לתשלום');
          }
          return;
        }
        if (amountToAdd - remainingBeforePayment > 0.01 && remainingBeforePayment > 0) {
          if (mounted) {
            showErrorSnackbar(context, 'הסכום גדול מהיתרה לתשלום');
          }
          return;
        }

        newPayment = PaymentRecord(
          amount: amountToAdd,
          method: _paymentMethod!,
          paidAt: _paymentDate ?? DateTime.now(),
        );
      }
    }

    if (widget.mode == BookingFormMode.add) {
      final payments = <PaymentRecord>[
        if (newPayment != null) newPayment,
      ];
      final paidAmount = payments.fold<double>(0, (sum, p) => sum + p.amount);
      final fullyPaid = totalPrice != null && paidAmount >= totalPrice - 0.01;

      final booking = Booking(
        id: '',
        dogIds: _selectedDogIds,
        type: _selectedType,
        kennelId: _selectedType == BookingType.boarding ? _selectedKennelId : null,
        kennelChangeStartDate:
            _hasKennelChange ? _kennelChangeStartDate : null,
        kennelChangeKennelId:
            _hasKennelChange ? _kennelChangeKennelId : null,
        startDate: _startDate,
        endDate: _selectedType == BookingType.boarding ? _endDate : _startDate,
        meetingTime: _selectedType == BookingType.introMeeting ? meetingTimeStr : null,
        totalPrice: totalPrice,
        bookingDailyRate:
            double.tryParse(_dailyRateController.text.replaceAll(',', '.')),
        rateChangeStartDate: _hasRateChange ? _rateChangeStartDate : null,
        rateChangeDailyRate: _hasRateChange
            ? double.tryParse(_changedDailyRateController.text.replaceAll(',', '.'))
            : null,
        chargeCheckoutDay: _chargeCheckoutDay,
        isPaid: fullyPaid,
        paymentMethod: _paymentMethod,
        payments: payments,
        paidAt: newPayment?.paidAt,
        createdAt: now,
        softHoldStartDate: _selectedType == BookingType.introMeeting && _hasSoftHold
            ? _softHoldStartDate
            : null,
        softHoldEndDate: _selectedType == BookingType.introMeeting && _hasSoftHold
            ? _softHoldEndDate
            : null,
        softHoldKennelId: _selectedType == BookingType.introMeeting && _hasSoftHold
            ? _softHoldKennelId
            : null,
      );
      await provider.addBooking(booking);
      if (widget.clearSoftHoldIntroId != null) {
        final intros = provider.bookings
            .where((b) => b.id == widget.clearSoftHoldIntroId)
            .toList();
        if (intros.isNotEmpty && intros.first.hasSoftHold) {
          await provider.updateBooking(
            intros.first.copyWith(
              softHoldStartDate: null,
              softHoldEndDate: null,
              softHoldKennelId: null,
            ),
          );
        }
      }
    } else {
      final payments = <PaymentRecord>[
        ...existingPayments,
        if (newPayment != null) newPayment,
      ];
      final paidAmount = payments.fold<double>(0, (sum, p) => sum + p.amount);
      final fullyPaid = totalPrice != null && paidAmount >= totalPrice - 0.01;

      final updated = widget.booking!.copyWith(
        dogIds: _selectedDogIds,
        type: _selectedType,
        kennelId: _selectedType == BookingType.boarding ? _selectedKennelId : null,
        kennelChangeStartDate:
            _hasKennelChange ? _kennelChangeStartDate : null,
        kennelChangeKennelId:
            _hasKennelChange ? _kennelChangeKennelId : null,
        startDate: _startDate,
        endDate: _selectedType == BookingType.boarding ? _endDate : _startDate,
        meetingTime: _selectedType == BookingType.introMeeting ? meetingTimeStr : null,
        totalPrice: totalPrice,
        bookingDailyRate:
            double.tryParse(_dailyRateController.text.replaceAll(',', '.')),
        rateChangeStartDate: _hasRateChange ? _rateChangeStartDate : null,
        rateChangeDailyRate: _hasRateChange
            ? double.tryParse(_changedDailyRateController.text.replaceAll(',', '.'))
            : null,
        chargeCheckoutDay: _chargeCheckoutDay,
        isPaid: fullyPaid,
        paymentMethod: _paymentMethod,
        payments: payments,
        paidAt: payments.isNotEmpty ? payments.last.paidAt : null,
        softHoldStartDate: _selectedType == BookingType.introMeeting && _hasSoftHold
            ? _softHoldStartDate
            : null,
        softHoldEndDate: _selectedType == BookingType.introMeeting && _hasSoftHold
            ? _softHoldEndDate
            : null,
        softHoldKennelId: _selectedType == BookingType.introMeeting && _hasSoftHold
            ? _softHoldKennelId
            : null,
      );
      await provider.updateBooking(updated);
    }

    if (!mounted) return;

    final error = provider.errorMessage;
    if (error != null) {
      showErrorSnackbar(context, error);
      provider.clearError();
    } else {
      showSuccessSnackbar(
        context,
        widget.mode == BookingFormMode.add
            ? AppStrings.bookingAdded
            : AppStrings.bookingUpdated,
      );
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: const Text(AppStrings.confirmDeleteBooking),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<BookingProvider>();
    await provider.deleteBooking(widget.booking!.id);

    if (!mounted) return;

    if (provider.errorMessage != null) {
      showErrorSnackbar(context, provider.errorMessage!);
      provider.clearError();
    } else {
      showSuccessSnackbar(context, AppStrings.bookingDeleted);
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<BookingProvider>().isLoading;
    final isEdit = widget.mode == BookingFormMode.edit;
    final currentTotal = double.tryParse(_priceController.text) ?? 0;
    final existingPayments = _editablePayments;
    final existingPaidAmount =
        existingPayments.fold<double>(0, (sum, p) => sum + p.amount);
    final remainingAmount =
        (currentTotal - existingPaidAmount) < 0 ? 0.0 : (currentTotal - existingPaidAmount);

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? AppStrings.editBooking : AppStrings.addBooking),
          actions: [
            if (isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade200,
                onPressed: _confirmDelete,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Type toggle
              SegmentedButton<BookingType>(
                segments: const [
                  ButtonSegment(
                    value: BookingType.boarding,
                    label: Text(AppStrings.boarding),
                    icon: Icon(Icons.home_outlined),
                  ),
                  ButtonSegment(
                    value: BookingType.introMeeting,
                    label: Text(AppStrings.introMeeting),
                    icon: Icon(Icons.handshake_outlined),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) =>
                    setState(() => _selectedType = set.first),
              ),
              const SizedBox(height: 20),

              // Dog selector
              DogMultiSelector(
                selectedDogIds: _selectedDogIds,
                selectedKennelId: _selectedType == BookingType.boarding
                    ? _selectedKennelId
                    : null,
                onChanged: (ids) {
                  setState(() => _selectedDogIds = ids);
                  _recalcPrice();
                },
              ),
              const SizedBox(height: 16),

              // Boarding-only fields
              if (_selectedType == BookingType.boarding) ...[
                KennelSelector(
                  selectedKennelId: _selectedKennelId,
                  labelText: _hasKennelChange
                      ? AppStrings.initialKennel
                      : AppStrings.kennel,
                  onChanged: (id) => setState(() => _selectedKennelId = id),
                ),
                const SizedBox(height: 16),
                _DateTile(
                  label: AppStrings.startDate,
                  date: _startDate,
                  dateFormat: _dateFormat,
                  onTap: () => _pickDate(isStart: true),
                ),
                const SizedBox(height: 12),
                _DateTile(
                  label: AppStrings.endDate,
                  date: _endDate,
                  dateFormat: _dateFormat,
                  onTap: () => _pickDate(isStart: false),
                ),
                SwitchListTile.adaptive(
                  value: _hasKennelChange,
                  onChanged: (v) => setState(() {
                    _hasKennelChange = v;
                    if (!v) {
                      _kennelChangeStartDate = null;
                      _kennelChangeKennelId = null;
                    } else {
                      final firstChangeDay =
                          _startDate.add(const Duration(days: 1));
                      if (!firstChangeDay.isAfter(_endDate)) {
                        _kennelChangeStartDate ??= firstChangeDay;
                      }
                    }
                  }),
                  title: const Text(AppStrings.changeKennelMidStay),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_hasKennelChange) ...[
                  _DateTile(
                    label: AppStrings.kennelChangeStartDate,
                    date: _kennelChangeStartDate ??
                        _startDate.add(const Duration(days: 1)),
                    dateFormat: _dateFormat,
                    onTap: _pickKennelChangeDate,
                  ),
                  const SizedBox(height: 12),
                  KennelSelector(
                    selectedKennelId: _kennelChangeKennelId,
                    labelText: AppStrings.newKennel,
                    onChanged: (id) =>
                        setState(() => _kennelChangeKennelId = id),
                  ),
                  const SizedBox(height: 16),
                ],
                SwitchListTile.adaptive(
                  value: _chargeCheckoutDay,
                  onChanged: (v) => setState(() {
                    _chargeCheckoutDay = v;
                    _recalcPrice();
                  }),
                  title: const Text(AppStrings.chargeCheckoutDay),
                  contentPadding: EdgeInsets.zero,
                ),
                TextFormField(
                  controller: _dailyRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _recalcPrice(),
                  decoration: const InputDecoration(
                    labelText: AppStrings.bookingDailyRate,
                    prefixText: '₪',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _hasRateChange,
                  onChanged: (v) => setState(() {
                    _hasRateChange = v;
                    if (!v) {
                      _rateChangeStartDate = null;
                      _changedDailyRateController.clear();
                    } else {
                      _rateChangeStartDate ??= _startDate;
                    }
                    _recalcPrice();
                  }),
                  title: const Text(AppStrings.changeDailyRateMidStay),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_hasRateChange) ...[
                  _DateTile(
                    label: AppStrings.rateChangeStartDate,
                    date: _rateChangeStartDate ?? _startDate,
                    dateFormat: _dateFormat,
                    onTap: _pickRateChangeDate,
                  ),
                  TextFormField(
                    controller: _changedDailyRateController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _recalcPrice(),
                    decoration: const InputDecoration(
                      labelText: AppStrings.newDailyRate,
                      prefixText: '₪',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  focusNode: _priceFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: AppStrings.totalPrice,
                    prefixText: '₪',
                  ),
                ),
                if (widget.booking != null && currentTotal > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${AppStrings.paymentSummary}: ${existingPaidAmount.toStringAsFixed(0)}/${currentTotal.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
                if (isEdit && existingPayments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      AppStrings.paymentBreakdown,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...existingPayments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('₪${p.amount.toStringAsFixed(0)}'),
                        subtitle: Text(
                          '${p.method.hebrewLabel} • ${_dateFormat.format(p.paidAt)}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editPaymentAt(i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red,
                              onPressed: () => setState(
                                  () => _editablePayments.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: _isPaid,
                  onChanged: (v) => setState(() {
                    _isPaid = v;
                    if (v) {
                      _paymentDate ??= DateTime.now();
                    } else {
                      _paymentAmountController.clear();
                    }
                  }),
                  title: const Text(AppStrings.isPaid),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_isPaid) ...[
                  SwitchListTile.adaptive(
                    value: _splitPayment,
                    onChanged: (v) => setState(() => _splitPayment = v),
                    title: const Text(AppStrings.splitPayment),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_splitPayment) ...[
                    TextFormField(
                      controller: _paymentAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: AppStrings.amountPaidNow,
                        prefixText: '₪',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppStrings.amountRemaining}: ₪${remainingAmount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: _paymentMethod,
                    decoration:
                        const InputDecoration(labelText: AppStrings.paymentMethod),
                    items: PaymentMethod.values
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.hebrewLabel),
                            ))
                        .toList(),
                    onChanged: (m) => setState(() => _paymentMethod = m),
                  ),
                  const SizedBox(height: 12),
                  _DateTile(
                    label: AppStrings.paymentDate,
                    date: _paymentDate ?? DateTime.now(),
                    dateFormat: _dateFormat,
                    onTap: _pickPaymentDate,
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Intro-only fields
              if (_selectedType == BookingType.introMeeting) ...[
                _DateTile(
                  label: AppStrings.date,
                  date: _startDate,
                  dateFormat: _dateFormat,
                  onTap: () => _pickDate(isStart: true),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(AppStrings.meetingTime),
                  trailing: Text(
                    _meetingTime != null
                        ? _meetingTime!.format(context)
                        : '—',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  onTap: _pickTime,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(AppStrings.softHoldEnable),
                  subtitle: const Text(
                    'מציג בלוח השנה על הכלוב — לא חוסם הזמנה רגילה',
                  ),
                  value: _hasSoftHold,
                  onChanged: (v) => setState(() {
                    _hasSoftHold = v;
                    if (v) {
                      _softHoldStartDate = _startDate;
                      _softHoldEndDate = _startDate;
                    }
                  }),
                ),
                if (_hasSoftHold) ...[
                  const SizedBox(height: 8),
                  KennelSelector(
                    selectedKennelId: _softHoldKennelId,
                    labelText: AppStrings.softHoldKennel,
                    onChanged: (id) =>
                        setState(() => _softHoldKennelId = id),
                  ),
                  const SizedBox(height: 8),
                  _DateTile(
                    label: AppStrings.softHoldStartDate,
                    date: _softHoldStartDate,
                    dateFormat: _dateFormat,
                    onTap: () => _pickSoftHoldDate(isStart: true),
                  ),
                  const SizedBox(height: 8),
                  _DateTile(
                    label: AppStrings.softHoldEndDate,
                    date: _softHoldEndDate,
                    dateFormat: _dateFormat,
                    onTap: () => _pickSoftHoldDate(isStart: false),
                  ),
                ],
              ],

              const SizedBox(height: 28),
              AppButton(
                label: isEdit ? AppStrings.saveChanges : AppStrings.addBooking,
                onPressed: _submit,
                isLoading: isLoading,
              ),
              if (isEdit) ...[
                const SizedBox(height: 12),
                AppButton(
                  label: AppStrings.delete,
                  onPressed: _confirmDelete,
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.date,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        dateFormat.format(date),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      onTap: onTap,
    );
  }
}
