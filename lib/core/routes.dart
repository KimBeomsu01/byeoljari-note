// 화면 사이 이동 (통합 명세 4-3). 다른 기능의 화면은 꼭 이 함수로 연다.
// 각 기능 담당은 자기 화면 파일만 고치고, 이 파일의 함수 이름은 바꾸지 않는다.
import 'package:flutter/material.dart';

import '../features/alert_case/case_detail_screen.dart';
import '../features/archive/archive_screen.dart';
import '../features/resident_card/resident_card_screen.dart';
import '../features/schedule/day_schedule_screen.dart';

/// AR 별님 아카이브.
Future<void> openArchive(BuildContext context, String residentId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArchiveScreen(residentId: residentId)));

/// S3 이상 건 상세.
Future<void> openCaseDetail(BuildContext context, String caseId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: caseId)));

/// SC-2 별님 하루 일정.
Future<void> openDaySchedule(BuildContext context, String residentId, DateTime date) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => DayScheduleScreen(residentId: residentId, date: date)));

/// PF 별님카드.
Future<void> openResidentCard(BuildContext context, String residentId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResidentCardScreen(residentId: residentId)));
