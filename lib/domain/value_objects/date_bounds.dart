/// Whether [moment] falls inside inclusive date-only bounds.
///
/// Rally dates and stamp-window validity are calendar days stored as midnight,
/// so the whole of the final day counts as inside the range.
bool withinDateBounds(DateTime moment, {DateTime? from, DateTime? to}) {
  final day = _dayOf(moment);
  if (from != null && day.isBefore(_dayOf(from))) return false;
  if (to != null && day.isAfter(_dayOf(to))) return false;
  return true;
}

DateTime _dayOf(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
