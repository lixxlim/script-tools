/**
 * ============================================
 * Google Drive 파일 모니터링 - 설정 (Configuration)
 * ============================================
 */

const DRIVE_MONITOR_CONFIG = {
  // 감시할 Google Drive 폴더 ID
  folderId: 'YOUR_FOLDER_ID',
  // 파일 상태를 저장할 Google 스프레드시트 ID
  spreadsheetId: 'YOUR_SPREADSHEET_ID',
  // 상태를 기록할 시트 탭 이름 (null이면 첫 번째 탭 사용)
  sheetName: '드라이브_모니터링',
  // 알림을 수신할 Google Chat 웹훅 URL
  chatWebhookUrl: 'YOUR_CHAT_WEBHOOK_URL',
  // 타임존 (null이면 스프레드시트 타임존 자동 적용)
  timeZone: null,
};

const DRIVE_MONITOR_SHEET_HEADERS = [
  '파일 ID',
  '파일명',
  '폴더 경로',
  '최종 수정일시',
  '파일 형식',
  '소유자',
  '파일 링크',
  '최근 상태'
];
