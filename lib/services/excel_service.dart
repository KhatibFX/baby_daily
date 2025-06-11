import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../models/session.dart';

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
      'Pee Amount',
      'Pee Remarks',
      'Poop Amount',
      'Poop Consistency',
      'Poop Color',
      'Milk Intake (ml)',
      'Vitamin AD',
      'Has Session Photo',
      'Has Abnormal Poop Photo'
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

      final sleepDuration = session.sleepTime != null
          ? session.sleepTime!.difference(session.wakeUpTime)
          : null;
      final sleepDurationStr = sleepDuration != null
          ? '${sleepDuration.inHours}h ${sleepDuration.inMinutes % 60}m'
          : 'N/A';

      final row = [
        dateFormat.format(session.wakeUpTime),
        timeFormat.format(session.wakeUpTime),
        session.sleepTime != null ? timeFormat.format(session.sleepTime!) : 'Not set',
        sleepDurationStr,
        session.pee.name,
        session.peeRemarks ?? '',
        session.poopAmount.name,
        session.poopConsistency.name,
        session.poopColor.name,
        session.milkIntake.toString(),
        session.vitaminAD ? 'Yes' : 'No',
        session.hasSessionPhoto ? 'Yes' : 'No',
        session.hasAbnormalPoopPhoto ? 'Yes' : 'No',
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
