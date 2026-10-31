/**
 * Google Chat notification scheduler.
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

/**
 * Checks all data rows and sends notifications due up to the current time.
 * Only executes between activeHours (09:00 - 18:00).
 */
function checkScheduledNotices() {
  validateSchedulerConfig_();

  // Avoid duplicate sends when a trigger invocation overlaps another one.
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) {
    return;
  }

  try {
    const spreadsheet = SpreadsheetApp.openById(CHAT_SCHEDULER_CONFIG.spreadsheetId);
    if (!spreadsheet) {
      throw new Error(`Spreadsheet not found for ID: ${CHAT_SCHEDULER_CONFIG.spreadsheetId}`);
    }

    const timezone = CHAT_SCHEDULER_CONFIG.timeZone || spreadsheet.getSpreadsheetTimeZone();
    const now = new Date();

    // 지정된 동작 시간대(예: 09:00 ~ 18:00)가 아니면 즉시 종료
    const currentHour = Number(Utilities.formatDate(now, timezone, 'H'));
    if (currentHour < CHAT_SCHEDULER_CONFIG.activeHours.start || currentHour > CHAT_SCHEDULER_CONFIG.activeHours.end) {
      return;
    }

    // 지정된 시트 탭을 가져오고, 없거나 null이면 맨 앞(첫 번째) 탭 사용
    const sheet = CHAT_SCHEDULER_CONFIG.sheetName
      ? (spreadsheet.getSheetByName(CHAT_SCHEDULER_CONFIG.sheetName) || spreadsheet.getSheets()[0])
      : spreadsheet.getSheets()[0];

    const lastRow = sheet.getLastRow();
    if (lastRow <= 1) {
      return; // 헤더만 있거나 데이터가 없는 경우
    }

    // 2행부터 마지막 행까지 읽어옵니다 (1행은 헤더)
    const range = sheet.getRange(2, CHAT_SCHEDULER_COLUMN.DONE, lastRow - 1, CHAT_SCHEDULER_COLUMN.NOTICE_TEXT);
    const values = range.getValues();

    values.forEach((row, index) => {
      const [done, noticeDate, noticeTime, noticeText] = row;
      const rowNumber = index + 2; // 실제 시트 행 번호

      // 이미 발송 완료되었거나 메시지가 비어있는 경우 스킵
      if (done === true || !noticeText) {
        return;
      }

      // 예약 일시 파싱 (타임존을 정확히 반영)
      const scheduledDateTime = parseScheduledDateTime_(noticeDate, noticeTime, timezone);
      if (!scheduledDateTime) {
        return;
      }

      // 예약 시간이 현재 시각 이전이거나 같으면 발송
      if (scheduledDateTime <= now) {
        sendSchedulerChatMessage_(String(noticeText));
        // 발송 성공 후 완료(true) 처리
        sheet.getRange(rowNumber, CHAT_SCHEDULER_COLUMN.DONE).setValue(true);
      }
    });
  } finally {
    lock.releaseLock();
  }
}

/** 1시간 주기 시간 기반 트리거 설정 (최초 1회 수동 실행) */
function createHourlyTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(trigger => trigger.getHandlerFunction() === 'checkScheduledNotices')
    .forEach(trigger => ScriptApp.deleteTrigger(trigger));

  ScriptApp.newTrigger('checkScheduledNotices')
    .timeBased()
    .everyHours(1)
    .create();
}

/** Google Chat 웹훅으로 카드(Card v2) 포맷 메시지 전송 */
function sendSchedulerChatMessage_(rawText) {
  const payload = buildSchedulerChatMessagePayload_(rawText);

  const response = UrlFetchApp.fetch(CHAT_SCHEDULER_CONFIG.chatWebhookUrl, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });
  const status = response.getResponseCode();
  if (status < 200 || status >= 300) {
    throw new Error(`Google Chat webhook failed (${status}): ${response.getContentText()}`);
  }
}

/**
 * 텍스트 가공 및 Google Chat Card v2 페이로드 빌드
 * - @전원, @all -> <users/all> 변환
 * - [red]문구[/red] -> <font color="#d93025">문구</font> 변환
 * - [blue]문구[/blue] -> <font color="#1a73e8">문구</font> 변환
 * - [green]문구[/green] -> <font color="#1e8e3e">문구</font> 변환
 * - **문구** -> <b>문구</b> 변환
 * - __문구__ -> <u>문구</u> 변환
 * - 줄바꿈(\n) -> <br> 변환
 */
function buildSchedulerChatMessagePayload_(rawText) {
  let processed = rawText
    // 1. 전원 멘션 치환
    .replace(/@전원|@all/g, '<users/all>')
    // 2. 색상 태그 단축 문법 지원
    .replace(/\[red\](.*?)\[\/red\]/gi, '<font color="#d93025">$1</font>')
    .replace(/\[blue\](.*?)\[\/blue\]/gi, '<font color="#1a73e8">$1</font>')
    .replace(/\[green\](.*?)\[\/green\]/gi, '<font color="#1e8e3e">$1</font>')
    // 3. 마크다운 스타일 단축 문법 지원
    .replace(/\*\*(.*?)\*\*/g, '<b>$1</b>')
    .replace(/__(.*?)__/g, '<u>$1</u>')
    // 4. 줄바꿈 지원
    .replace(/\n/g, '<br>');

  const hasAllMention = /<users\/all>/.test(processed);

  return {
    // 멘션 노티가 팝업/뱃지로 정상 울리도록 최상위 text에도 포함
    text: hasAllMention ? '<users/all>' : '',
    cardsV2: [
      {
        cardId: 'notice-' + Date.now(),
        card: {
          sections: [
            {
              widgets: [
                {
                  textParagraph: {
                    text: processed,
                  },
                },
              ],
            },
          ],
        },
      },
    ],
  };
}

/** 날짜와 시간을 조합하여 지정된 타임존 기준 Date 객체로 변환 */
function parseScheduledDateTime_(dateVal, timeVal, timezone) {
  if (!dateVal || !timeVal) {
    return null;
  }

  const dateStr = (dateVal instanceof Date && !isNaN(dateVal))
    ? Utilities.formatDate(dateVal, timezone, 'yyyy-MM-dd')
    : String(dateVal).trim();

  let timeStr = '';
  if (timeVal instanceof Date && !isNaN(timeVal)) {
    timeStr = Utilities.formatDate(timeVal, timezone, 'HH:mm');
  } else {
    timeStr = String(timeVal).trim();
  }

  // 1자리 시간(예: 9:05) 지원을 위한 0 패딩 처리
  const parts = timeStr.split(':');
  if (parts.length === 2) {
    timeStr = `${parts[0].padStart(2, '0')}:${parts[1].padStart(2, '0')}`;
  }

  try {
    // 지정된 타임존 기준으로 안전하게 파싱
    return Utilities.parseDate(`${dateStr} ${timeStr}`, timezone, 'yyyy-MM-dd HH:mm');
  } catch (e) {
    return null;
  }
}

function validateSchedulerConfig_() {
  if (!CHAT_SCHEDULER_CONFIG.spreadsheetId ||
      CHAT_SCHEDULER_CONFIG.spreadsheetId === 'REPLACE_WITH_SPREADSHEET_ID' ||
      !CHAT_SCHEDULER_CONFIG.chatWebhookUrl ||
      CHAT_SCHEDULER_CONFIG.chatWebhookUrl === 'REPLACE_WITH_GOOGLE_CHAT_WEBHOOK_URL') {
    throw new Error('CHAT_SCHEDULER_CONFIG.spreadsheetId와 CHAT_SCHEDULER_CONFIG.chatWebhookUrl을 먼저 설정해주세요.');
  }
}
