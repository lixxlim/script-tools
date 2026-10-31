/**
 * Google Chat notification scheduler - Methods
 *
 * Settings are defined in google-chat-notification-scheduler-config.gs.
 */

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

      // 발송 예정 시점 도달 여부 판별 (날짜만 / 시간만 / 둘 다 있는 경우 모두 처리)
      if (isNoticeDue_(noticeDate, noticeTime, now, timezone)) {
        sendSchedulerChatMessage_(String(noticeText), spreadsheet, sheet);
        // 발송 성공 후 완료(true) 처리
        sheet.getRange(rowNumber, CHAT_SCHEDULER_COLUMN.DONE).setValue(true);
        // 연속 발송 시 웹훅 안정성을 위한 딜레이
        Utilities.sleep(150);
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

/** Google Chat 웹훅으로 단일 일반 텍스트 메시지 전송 */
function sendSchedulerChatMessage_(rawText, spreadsheet, currentSheet) {
  const formattedText = formatSchedulerMessageText_(rawText, spreadsheet, currentSheet);

  const response = UrlFetchApp.fetch(CHAT_SCHEDULER_CONFIG.chatWebhookUrl, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({ text: formattedText }),
    muteHttpExceptions: true,
  });
  const status = response.getResponseCode();
  if (status < 200 || status >= 300) {
    throw new Error(`Google Chat webhook failed (${status}): ${response.getContentText()}`);
  }
}

/**
 * 일반 텍스트 모드 포맷팅 함수
 * - @전원, @all, @全員 -> <users/all> 변환
 * - {{시트명!A1:C5}} 또는 {{A1:B2}} -> 스프레드시트 영역 실시간 데이터 치환
 * - <link>URL</link> -> <URL> 링크 변환
 * - [텍스트](URL) -> <URL|텍스트> 구글 챗 링크 변환
 * - **문구** -> *문구* (구글 챗 굵게 문법)
 * - [red]문구[/red] -> 🔴 *문구* (일반 텍스트 강조 이모지)
 * - [blue]문구[/blue] -> 🔵 *문구*
 * - [green]문구[/green] -> 🟢 *문구*
 * - __문구__ -> _문구_ (기울임 강조)
 */
function formatSchedulerMessageText_(rawText, spreadsheet, currentSheet) {
  // 1. 스프레드시트 셀/범위 참조 치환 (예: {{당번표!A1:C5}}, {{B2}})
  let text = replaceSheetRangePlaceholders_(rawText, spreadsheet, currentSheet);

  return text
    // 2. 전원 멘션 치환 (한국어, 영어, 일본어 모두 지원)
    .replace(/@전원|@all|@全員/g, '<users/all>')
    // 3. 링크 치환 (구글 챗 일반 텍스트 링크 규격: <URL|텍스트>)
    .replace(/<link>(.*?)<\/link>/gi, '<$1>')
    .replace(/\[(.*?)\]\((https?:\/\/.*?)\)/g, '<$2|$1>')
    // 4. 색상 태그 -> 이모지 및 볼드로 자연스럽게 대체
    .replace(/\[red\](.*?)\[\/red\]/gi, '🔴 *$1*')
    .replace(/\[blue\](.*?)\[\/blue\]/gi, '🔵 *$1*')
    .replace(/\[green\](.*?)\[\/green\]/gi, '🟢 *$1*')
    // 5. 볼드 및 강조 처리 (** -> * 변환)
    .replace(/\*\*(.*?)\*\*/g, '*$1*')
    .replace(/__(.*?)__/g, '_$1_');
}

/**
 * {{시트명!A1:C5}} 형태의 태그를 실제 스프레드시트 데이터로 치환
 */
function replaceSheetRangePlaceholders_(rawText, spreadsheet, currentSheet) {
  if (!spreadsheet) {
    return rawText;
  }

  return rawText.replace(/\{\{(.*?)\}\}/g, (match, expr) => {
    const expression = expr.trim();
    if (!expression) return match;

    let targetSheet = currentSheet;
    let rangeA1 = expression;

    // "시트명!범위" 파싱
    if (expression.includes('!')) {
      const parts = expression.split('!');
      const sheetName = parts[0].trim().replace(/^['"]|['"]$/g, '');
      rangeA1 = parts[1].trim();
      targetSheet = spreadsheet.getSheetByName(sheetName);
      if (!targetSheet) {
        return `[시트 '${sheetName}'을(를) 찾을 수 없음]`;
      }
    }

    try {
      const range = targetSheet.getRange(rangeA1);
      // 화면에 표시된 서식 그대로 가져옴 (날짜 포맷, 통화, 숫자 등 유지)
      const displayValues = range.getDisplayValues();

      // 단일 셀인 경우: 해당 값 문자열만 그대로 삽입
      if (displayValues.length === 1 && displayValues[0].length === 1) {
        return displayValues[0][0];
      }

      // 다중 셀(표)인 경우: 코드 블록으로 감싸 정렬된 표 형태로 출력
      const lines = displayValues.map(row => row.join(' | '));
      return '```\n' + lines.join('\n') + '\n```';
    } catch (e) {
      return `[범위 '${rangeA1}' 오류]`;
    }
  });
}

/**
 * 예약 일시 도달 여부 판정
 * 1. 날짜 + 시간 모두 있음: 예약 일시 <= 현재 일시 이면 발송
 * 2. 날짜만 있음: 시간 무시, 예약 날짜 <= 오늘 날짜 이면 발송
 * 3. 시간만 있음: 날짜 무시, 예약 시간 <= 현재 시각 이면 발송
 */
function isNoticeDue_(dateVal, timeVal, now, timezone) {
  const dateStr = formatDateString_(dateVal, timezone);
  const timeStr = formatTimeString_(timeVal, timezone);

  const hasDate = Boolean(dateStr);
  const hasTime = Boolean(timeStr);

  // 둘 다 비어있는 경우 스킵
  if (!hasDate && !hasTime) {
    return false;
  }

  const todayStr = Utilities.formatDate(now, timezone, 'yyyy-MM-dd');
  const currentTimeStr = Utilities.formatDate(now, timezone, 'HH:mm');

  // 1. 날짜 + 시간 모두 입력된 경우
  if (hasDate && hasTime) {
    try {
      const scheduledDateTime = Utilities.parseDate(`${dateStr} ${timeStr}`, timezone, 'yyyy-MM-dd HH:mm');
      return scheduledDateTime && scheduledDateTime <= now;
    } catch (e) {
      return false;
    }
  }

  // 2. 날짜만 입력된 경우: 오늘 또는 과거일이면 발송
  if (hasDate && !hasTime) {
    return dateStr <= todayStr;
  }

  // 3. 시간만 입력된 경우: 현재 시각 또는 이미 지난 시각이면 발송
  if (!hasDate && hasTime) {
    return timeStr <= currentTimeStr;
  }

  return false;
}

/** 날짜 값을 'yyyy-MM-dd' 문자열로 정규화 */
function formatDateString_(value, timezone) {
  if (!value) return '';
  if (value instanceof Date && !isNaN(value.getTime())) {
    return Utilities.formatDate(value, timezone, 'yyyy-MM-dd');
  }
  const str = String(value).trim();
  const match = str.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$/);
  if (match) {
    const [_, y, m, d] = match;
    return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
  }
  return '';
}

/** 시간 값을 'HH:mm' 문자열로 정규화 */
function formatTimeString_(value, timezone) {
  if (!value) return '';
  if (value instanceof Date && !isNaN(value.getTime())) {
    return Utilities.formatDate(value, timezone, 'HH:mm');
  }
  const str = String(value).trim();
  const match = str.match(/^(\d{1,2}):(\d{2})(?::\d{2})?$/);
  if (match) {
    const [_, h, m] = match;
    return `${h.padStart(2, '0')}:${m}`;
  }
  return '';
}

function validateSchedulerConfig_() {
  if (!CHAT_SCHEDULER_CONFIG.spreadsheetId ||
      CHAT_SCHEDULER_CONFIG.spreadsheetId === 'REPLACE_WITH_SPREADSHEET_ID' ||
      !CHAT_SCHEDULER_CONFIG.chatWebhookUrl ||
      CHAT_SCHEDULER_CONFIG.chatWebhookUrl === 'REPLACE_WITH_GOOGLE_CHAT_WEBHOOK_URL') {
    throw new Error('CHAT_SCHEDULER_CONFIG.spreadsheetId와 CHAT_SCHEDULER_CONFIG.chatWebhookUrl을 먼저 설정해주세요.');
  }
}
