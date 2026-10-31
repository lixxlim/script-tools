/**
 * Google Chat notification scheduler - Configuration
 *
 * In CHAT_SCHEDULER_CONFIG, set the spreadsheet ID, sheet name, and Google Chat incoming-webhook URL.
 * If sheetName is null or empty, the first sheet (tab) in the spreadsheet is used.
 */
const CHAT_SCHEDULER_CONFIG = {
  // Spreadsheet URL의 /d/와 /edit 사이의 ID를 입력하세요.
  spreadsheetId: 'REPLACE_WITH_SPREADSHEET_ID',
  // 알림 목록이 있는 시트 탭 이름 (null 또는 비워두면 맨 앞 첫 번째 탭 사용)
  sheetName: null,
  // 알림을 수신할 Google Chat 웹훅 URL
  chatWebhookUrl: 'REPLACE_WITH_GOOGLE_CHAT_WEBHOOK_URL',
  // null로 설정 시 스프레드시트의 타임존을 따르며, 필요 시 'Asia/Seoul'처럼 명시할 수 있습니다.
  timeZone: null,
  // 실행을 허용할 시간 범위 (24시간제 기준, 9시부터 18시까지)
  activeHours: {
    start: 9,  // 시작 시간 (09:00)
    end: 18,   // 종료 시간 (18:00)
  },
};

const CHAT_SCHEDULER_COLUMN = {
  DONE: 1,         // A열 (완료 여부 체크박스)
  NOTICE_DATE: 2,  // B열 (예약 날짜: YYYY-MM-DD 또는 Date 형식)
  NOTICE_TIME: 3,  // C열 (예약 시간: HH:mm 또는 Time 형식)
  NOTICE_TEXT: 4,  // D열 (메시지 내용)
};
