/**
 * ============================================
 * Monthly Completion Tracker - Configuration
 * ============================================
 *
 * 1. 매월 10일: 날짜 갱신(dateCell) 및 상태 셀(statusCell) 초기화
 * 2. 매 1시간마다: 범위(checkRange) 감시 중 targetString('미제출')이 0건이 되면 웹훅 알림 발송 및 상태 셀을 true로 변경
 */

const MONTHLY_COMPLETION_CONFIG = {
  // 스프레드시트 ID
  spreadsheetId: 'REPLACE_WITH_SPREADSHEET_ID',
  // 시트 탭 이름 (null이면 첫 번째 탭)
  sheetName: '시트1',

  // --------------------------------------------
  // [공통] 발송 상태 관리 셀
  // --------------------------------------------
  // 발송 완료 시 true가 기록되고, 매월 10일 날짜 갱신 시 값이 지워집니다 (A1 표기법)
  statusCell: 'D1',

  // --------------------------------------------
  // [월간 날짜 갱신] 설정 (매월 10일)
  // --------------------------------------------
  // 연월을 갱신할 셀 위치 (A1 표기법, 예: 'B2')
  dateCell: 'B2',
  // 날짜 포맷 (yyyy: 연도, m: 1자리 월, mm: 2자리 월, d: 1자리 일, dd: 2자리 일)
  dateFormat: 'yyyy년m월',
  // 실행 일자 (기본값: 10일)
  monthlyRunDay: 10,
  // 실행 시간 (24시간제 기준, 기본값: 오전 09시)
  monthlyRunHour: 9,

  // --------------------------------------------
  // [완료 감시 및 알림] 설정 (매 1시간마다)
  // --------------------------------------------
  // 감시할 범위 (A1 표기법, 예: 'C2:C20')
  checkRange: 'C2:C20',
  // 감시 대상 문자열 (이 단어가 0개여야 발송됨, 예: '미제출')
  targetString: '미제출',
  // 매칭 방식: 'EXACT'(정확히 일치), 'CONTAINS'(문자열 포함)
  matchMode: 'EXACT',
  // 알림을 수신할 Google Chat 웹훅 URL
  chatWebhookUrl: 'REPLACE_WITH_GOOGLE_CHAT_WEBHOOK_URL',
  // 전송할 메시지 템플릿
  // 팁: {{target}} 을 넣으면 dateCell에 적힌 연월(예: 2026년10월)로 자동 치환됩니다!
  messageTemplate: '@all [green]**[{{target}} 전원 제출 완료 안내]**[/green]\n{{target}} 대상자 전원의 제출이 확인되었습니다.\n바쁘신 와중에 협조해 주셔서 진심으로 감사드립니다! 🎉',

  // 타임존 (null이면 스프레드시트 타임존 자동 적용)
  timeZone: null,
};
