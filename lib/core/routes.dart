// 화면 사이 이동. 다른 기능의 화면은 꼭 이 함수로 연다.
import 'package:flutter/material.dart';

import '../features/alert_case/case_detail_screen.dart';
import '../features/resident_card/resident_card_screen.dart';

/// 별님 기록 모아보기 = 별님카드.
Future<void> openArchive(BuildContext context, String residentId) => openResidentCard(context, residentId);

/// 이상 건 상세.
Future<void> openCaseDetail(BuildContext context, String caseId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: caseId)));

/// 별님카드 (별도 화면으로).
Future<void> openResidentCard(BuildContext context, String residentId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResidentCardScreen(residentId: residentId)));