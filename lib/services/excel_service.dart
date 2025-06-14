import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../models/pee_entry.dart';
import '../models/poop_entry.dart';
import '../models/milk_entry.dart';

class ExcelService {
  static Future<File> generateSessionsExcel(List<Session> sessions) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sessions'];

    // Add headers
    final headers = [
      'Date',
      'Wake Up Time',
      'Sleep Time',
      'Sleep Duration',
      'Next Session Start',
      'Time Until Next Session',
      'Pee Events',
      'Pee Times',
      'Pee Amounts',
      'Pee Remarks',
      'Poop Events',
      'Poop Times',
      'Poop Amounts',
      'Poop Consistencies',
      'Poop Colors',
      'Poop Photos',
      'Milk Events',
      'Milk Times',
      'Milk Amounts (ml)',
      'Total Milk (ml)',
      'Vitamin AD',
      'Has Session Photo'
    ];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Sort sessions by wake up time ascending (oldest first)
    sessions.sort((a, b) => a.wakeUpTime.compareTo(b.wakeUpTime));

    // Add data
    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      final rowIndex = i + 1;
      final dateFormat = DateFormat('MMM dd, yyyy');
      final timeFormat = DateFormat('HH:mm');

      // Calculate sleep duration for current session
      final sleepDuration = session.sleepTime != null
          ? session.sleepTime!.difference(session.wakeUpTime)
          : null;
      final sleepDurationStr = sleepDuration != null
          ? '${sleepDuration.inHours}h ${sleepDuration.inMinutes % 60}m'
          : 'N/A';

      // Calculate time until next session
      final nextSession = i < sessions.length - 1 ? sessions[i + 1] : null;
      final timeUntilNext = nextSession != null && session.sleepTime != null
          ? nextSession.wakeUpTime.difference(session.sleepTime!)
          : null;
      final timeUntilNextStr = timeUntilNext != null
          ? '${timeUntilNext.inHours}h ${timeUntilNext.inMinutes % 60}m'
          : 'N/A';

      // Process pee entries
      final peeEvents = session.peeEntries.length.toString();
      final peeTimes = session.peeEntries
          .map((e) => timeFormat.format(e.time))
          .join(', ');
      final peeAmounts = session.peeEntries
          .map((e) => e.amount.name)
          .join(', ');
      final peeRemarks = session.peeEntries
          .map((e) => e.remarks ?? '')
          .where((r) => r.isNotEmpty)
          .join('; ');

      // Process poop entries
      final poopEvents = session.poopEntries.length.toString();
      final poopTimes = session.poopEntries
          .map((e) => timeFormat.format(e.time))
          .join(', ');
      final poopAmounts = session.poopEntries
          .map((e) => e.amount.name)
          .join(', ');
      final poopConsistencies = session.poopEntries
          .map((e) => e.consistency.name)
          .join(', ');
      final poopColors = session.poopEntries
          .map((e) => e.color.name)
          .join(', ');
      final poopPhotos = session.poopEntries
          .map((e) => e.hasPhoto ? 'Yes' : 'No')
          .join(', ');

      // Process milk entries
      final milkEvents = session.milkEntries.length.toString();
      final milkTimes = session.milkEntries
          .map((e) => timeFormat.format(e.time))
          .join(', ');
      final milkAmounts = session.milkEntries
          .map((e) => e.amount.toString())
          .join(', ');
      final totalMilk = session.milkEntries
          .fold(0, (sum, entry) => sum + entry.amount)
          .toString();

      final row = [
        dateFormat.format(session.wakeUpTime),
        timeFormat.format(session.wakeUpTime),
        session.sleepTime != null ? timeFormat.format(session.sleepTime!) : 'Not set',
        sleepDurationStr,
        nextSession != null ? timeFormat.format(nextSession.wakeUpTime) : 'N/A',
        timeUntilNextStr,
        peeEvents,
        peeTimes,
        peeAmounts,
        peeRemarks,
        poopEvents,
        poopTimes,
        poopAmounts,
        poopConsistencies,
        poopColors,
        poopPhotos,
        milkEvents,
        milkTimes,
        milkAmounts,
        totalMilk,
        session.vitaminAD ? 'Yes' : 'No',
        session.hasSessionPhoto ? 'Yes' : 'No',
      ];

      for (var j = 0; j < row.length; j++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex));
        cell.value = TextCellValue(row[j]);
        cell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
        );
      }
    }

    // Auto-size columns
    for (var i = 0; i < headers.length; i++) {
      var maxLength = headers[i].length;
      for (var j = 1; j <= sessions.length; j++) {
        final cellValue = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: j))
            .value
            ?.toString() ?? '';
        maxLength = maxLength > cellValue.length ? maxLength : cellValue.length;
      }
      sheet.setColumnWidth(i, maxLength + 2); // Add padding
    }

    // Save file
    final directory = await getTemporaryDirectory();
    final fileName = 'baby_daily_sessions_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);
    
    return file;
  }
}
