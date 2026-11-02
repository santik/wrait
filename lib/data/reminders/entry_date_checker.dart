import '../entries/local_entry_database.dart';

abstract interface class EntryDateChecker {
  Future<bool> hasEntryOnDate(int startOfDayMs, int endOfDayMs);
}

class DaoEntryDateChecker implements EntryDateChecker {
  DaoEntryDateChecker(this._dao);

  final EntryDao _dao;

  @override
  Future<bool> hasEntryOnDate(int startOfDayMs, int endOfDayMs) {
    return _dao.hasEntryOnDate(startOfDayMs, endOfDayMs);
  }
}
