import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/date_filter_header.dart';

class DateFilterState {
  final DateView view;
  final DateTime? selectedDate;
  final DateTimeRange? selectedRange;

  DateFilterState({required this.view, this.selectedDate, this.selectedRange});

  DateFilterState copyWith({
    DateView? view,
    DateTime? Function()? selectedDate,
    DateTimeRange? Function()? selectedRange,
  }) {
    return DateFilterState(
      view: view ?? this.view,
      selectedDate: selectedDate != null ? selectedDate() : this.selectedDate,
      selectedRange: selectedRange != null
          ? selectedRange()
          : this.selectedRange,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateFilterState &&
          runtimeType == other.runtimeType &&
          view == other.view &&
          selectedDate == other.selectedDate &&
          selectedRange == other.selectedRange;

  @override
  int get hashCode =>
      view.hashCode ^ selectedDate.hashCode ^ selectedRange.hashCode;
}

class DateFilterNotifier extends Notifier<DateFilterState> {
  @override
  DateFilterState build() {
    return DateFilterState(view: DateView.day, selectedDate: DateTime.now());
  }

  /// Updates only the view type.
  void updateView(DateView view) {
    state = state.copyWith(view: view);
  }

  /// Updates only the date, preserving current view and range.
  void updateDate(DateTime? date) {
    state = state.copyWith(selectedDate: () => date);
  }

  /// Updates both date and view.
  void selectDate(DateTime date, DateView view) {
    state = state.copyWith(
      view: view,
      selectedDate: () => date,
      selectedRange: () => null,
    );
  }

  /// Atomically updates the range.
  void updateRange(DateTimeRange? range) {
    if (range == null) {
      state = state.copyWith(
        view: DateView.day,
        selectedRange: () => null,
        selectedDate: () => DateTime.now(),
      );
    } else {
      state = state.copyWith(
        view: DateView.customRange,
        selectedRange: () => range,
        selectedDate: () => range.start,
      );
    }
  }

  /// Resets everything to defaults.
  void clearFilters() {
    state = DateFilterState(view: DateView.day, selectedDate: DateTime.now());
  }
}

final dateFilterProvider =
    NotifierProvider<DateFilterNotifier, DateFilterState>(() {
      return DateFilterNotifier();
    });
