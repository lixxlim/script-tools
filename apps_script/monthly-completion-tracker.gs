/**
 * ============================================
 * Monthly Completion Tracker - Methods
 * ============================================
 *
 * 설정값은 monthly-completion-tracker-config.gs 에 정의되어 있습니다.
 */

/**
 * [기능 1] 매월 10일 실행:
 * 지정된 셀(dateCell)의 날짜를 새 연월로 갱신하고,
 * 상태 셀(statusCell)의 값을 지워(초기화) 새 회차 감시를 준비합니다.
 */
function updateMonthlyDateAndReset() {
  validateMonthlyCompletionConfig_();

  const spreadsheet = SpreadsheetApp.openById(MONTHLY_COMPLETION_CONFIG.spreadsheetId);
  if (!spreadsheet) {
    throw new Error(`스프레드시트를 찾을 수 없습니다: ${MONTHLY_COMPLETION_CONFIG.spreadsheetId}`);
  }

  const sheet = MONTHLY_COMPLETION_CONFIG.sheetName
    ? spreadsheet.getSheetByName(MONTHLY_COMPLETION_CONFIG.sheetName)
    : spreadsheet.getSheets()[0];

  if (!sheet) {
    throw new Error(`시트('${MONTHLY_COMPLETION_CONFIG.sheetName}')를 찾을 수 없습니다.`);
  }

  const timezone = MONTHLY_COMPLETION_CONFIG.timeZone || spreadsheet.getSpreadsheetTimeZone();
  const now = new Date();

  // 1. 날짜 셀 갱신
  if (MONTHLY_COMPLETION_CONFIG.dateCell && MONTHLY_COMPLETION_CONFIG.dateFormat) {
    const formattedDate = formatCustomDate_(now, MONTHLY_COMPLETION_CONFIG.dateFormat, timezone);
    sheet.getRange(MONTHLY_COMPLETION_CONFIG.dateCell).setValue(formattedDate);

    Logger.log('====================================');
    Logger.log(`[날짜 갱신 완료] 셀: ${MONTHLY_COMPLETION_CONFIG.dateCell}, 값: ${formattedDate}`);
  }

  // 2. 상태 셀 초기화 (클리어)
  if (MONTHLY_COMPLETION_CONFIG.statusCell) {
    sheet.getRange(MONTHLY_COMPLETION_CONFIG.statusCell).clearContent();
    Logger.log(`[상태 셀 초기화 완료] 셀: ${MONTHLY_COMPLETION_CONFIG.statusCell}의 값을 지웠습니다. 새 회차 감시 준비 완료.`);
  }
  Logger.log('====================================');
}

/**
 * [기능 2] 매 1시간마다 실행:
 * 상태 셀이 true이면 건너뛰고, 비어있거나 false인 경우 감시 범위를 확인하여
 * targetString('미제출')이 0건이면 Google Chat으로 메시지 발송 후 상태 셀을 true로 기록합니다.
 */
function checkCompletionAndNotify() {
  validateMonthlyCompletionConfig_();

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) {
    return;
  }

  try {
    const spreadsheet = SpreadsheetApp.openById(MONTHLY_COMPLETION_CONFIG.spreadsheetId);
    if (!spreadsheet) {
      throw new Error(`스프레드시트를 찾을 수 없습니다: ${MONTHLY_COMPLETION_CONFIG.spreadsheetId}`);
    }

    const sheet = MONTHLY_COMPLETION_CONFIG.sheetName
      ? (spreadsheet.getSheetByName(MONTHLY_COMPLETION_CONFIG.sheetName) || spreadsheet.getSheets()[0])
      : spreadsheet.getSheets()[0];

    // 1. 상태 셀 값 검사
    const statusRange = sheet.getRange(MONTHLY_COMPLETION_CONFIG.statusCell);
    const statusVal = statusRange.getValue();

    // true(불리언) 또는 'TRUE'(문자열)이면 이미 완료 발송된 상태로 판단하여 스킵
    const isAlreadySent = (statusVal === true || String(statusVal).trim().toUpperCase() === 'TRUE');
    if (isAlreadySent) {
      Logger.log(`상태 셀(${MONTHLY_COMPLETION_CONFIG.statusCell})이 이미 TRUE(발송완료)이므로 검사를 건너뜁니다.`);
      return;
    }

    // 2. 감시 범위 데이터 확인
    const range = sheet.getRange(MONTHLY_COMPLETION_CONFIG.checkRange);
    const displayValues = range.getDisplayValues();

    const targetStr = MONTHLY_COMPLETION_CONFIG.targetString.trim();
    const isExact = (MONTHLY_COMPLETION_CONFIG.matchMode || 'EXACT').toUpperCase() === 'EXACT';

    let foundCount = 0;
    displayValues.forEach(row => {
      row.forEach(cell => {
        const cellText = String(cell).trim();
        if (!cellText) return;

        if (isExact) {
          if (cellText === targetStr) foundCount++;
        } else {
          if (cellText.includes(targetStr)) foundCount++;
        }
      });
    });

    // 3. 체크 문자열이 0건인 경우 (전원 완료)
    if (foundCount === 0) {
      sendCompletionChatMessage_(MONTHLY_COMPLETION_CONFIG.messageTemplate, spreadsheet, sheet);

      // 상태 셀을 true로 기록하여 중복 발송 방지
      statusRange.setValue(true);

      Logger.log('====================================');
      Logger.log('[전원 완료 감지] 완료 메시지를 발송했습니다.');
      Logger.log(`상태 셀(${MONTHLY_COMPLETION_CONFIG.statusCell})을 TRUE로 기록했습니다.`);
      Logger.log('====================================');
    } else {
      Logger.log(`아직 체크 문자열('${targetStr}')이 ${foundCount}건 남아있습니다.`);
    }
  } finally {
    lock.releaseLock();
  }
}

/**
 * [트리거 설정] 2개의 트리거(매월 10일 날짜 갱신 + 매시간 감시)를 한 번에 자동 등록
 */
function setupAllTriggers() {
  createMonthlyTrigger();
  createHourlyCheckTrigger();
  Logger.log('====================================');
  Logger.log('두 개의 필수 트리거가 모두 성공적으로 등록되었습니다!');
  Logger.log('1. 매월 날짜 갱신 및 상태 초기화 트리거');
  Logger.log('2. 매 1시간 주기 완료 감시 트리거');
  Logger.log('====================================');
}

/** 매월 10일 자동 실행 트리거 등록 */
function createMonthlyTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(trigger => trigger.getHandlerFunction() === 'updateMonthlyDateAndReset')
    .forEach(trigger => ScriptApp.deleteTrigger(trigger));

  const runDay = MONTHLY_COMPLETION_CONFIG.monthlyRunDay || 10;
  const runHour = (MONTHLY_COMPLETION_CONFIG.monthlyRunHour !== undefined) ? MONTHLY_COMPLETION_CONFIG.monthlyRunHour : 9;

  ScriptApp.newTrigger('updateMonthlyDateAndReset')
    .timeBased()
    .onMonthDay(runDay)
    .atHour(runHour)
    .create();

  Logger.log(`매월 ${runDay}일 오전 ${runHour}시 날짜 갱신 트리거 등록 완료`);
}

/** 매 1시간 자동 감시 트리거 등록 */
function createHourlyCheckTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(trigger => trigger.getHandlerFunction() === 'checkCompletionAndNotify')
    .forEach(trigger => ScriptApp.deleteTrigger(trigger));

  ScriptApp.newTrigger('checkCompletionAndNotify')
    .timeBased()
    .everyHours(1)
    .create();

  Logger.log('매 1시간 주기 완료 감시 트리거 등록 완료');
}

/** Google Chat 웹훅으로 메시지 전송 */
function sendCompletionChatMessage_(rawText, spreadsheet, currentSheet) {
  const formattedText = formatCompletionMessageText_(rawText, spreadsheet, currentSheet);

  const response = UrlFetchApp.fetch(MONTHLY_COMPLETION_CONFIG.chatWebhookUrl, {
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

/** 메시지 템플릿 서식 변환 ({{target}}, 멘션, 링크, 색상 이모지, 셀 참조 지원) */
function formatCompletionMessageText_(rawText, spreadsheet, currentSheet) {
  let text = rawText;

  // 1. {{target}} 태그를 dateCell(날짜 셀)의 값으로 자동 치환
  if (MONTHLY_COMPLETION_CONFIG.dateCell && currentSheet) {
    try {
      const dateVal = currentSheet.getRange(MONTHLY_COMPLETION_CONFIG.dateCell).getDisplayValue();
      text = text.replace(/\{\{target\}\}/gi, dateVal);
    } catch (e) {
      Logger.log(`dateCell('${MONTHLY_COMPLETION_CONFIG.dateCell}') 값을 읽어오지 못했습니다: ${e.message}`);
    }
  }

  // 2. {{시트명!A1}} 등 일반 셀 참조 치환
  if (spreadsheet && currentSheet) {
    text = text.replace(/\{\{(.*?)\}\}/g, (match, expr) => {
      const expression = expr.trim();
      if (!expression) return match;

      let targetSheet = currentSheet;
      let rangeA1 = expression;

      if (expression.includes('!')) {
        const parts = expression.split('!');
        const sheetName = parts[0].trim().replace(/^['"]|['"]$/g, '');
        rangeA1 = parts[1].trim();
        targetSheet = spreadsheet.getSheetByName(sheetName);
        if (!targetSheet) return match;
      }

      try {
        const range = targetSheet.getRange(rangeA1);
        const displayValues = range.getDisplayValues();
        if (displayValues.length === 1 && displayValues[0].length === 1) {
          return displayValues[0][0];
        }
        const lines = displayValues.map(row => row.join(' | '));
        return '```\n' + lines.join('\n') + '\n```';
      } catch (e) {
        return match;
      }
    });
  }

  return text
    .replace(/@전원|@all|@全員/g, '<users/all>')
    .replace(/<link>(.*?)<\/link>/gi, '<$1>')
    .replace(/\[(.*?)\]\((https?:\/\/.*?)\)/g, '<$2|$1>')
    .replace(/\[red\](.*?)\[\/red\]/gi, '🔴 *$1*')
    .replace(/\[blue\](.*?)\[\/blue\]/gi, '🔵 *$1*')
    .replace(/\[green\](.*?)\[\/green\]/gi, '🟢 *$1*')
    .replace(/\*\*(.*?)\*\*/g, '*$1*')
    .replace(/__(.*?)__/g, '_$1_');
}

/** 커스텀 날짜 포맷 치환 함수 */
function formatCustomDate_(date, format, timezone) {
  const yearStr = Utilities.formatDate(date, timezone, 'yyyy');
  const monthNum = Number(Utilities.formatDate(date, timezone, 'M'));
  const dayNum = Number(Utilities.formatDate(date, timezone, 'd'));

  const yyyy = yearStr;
  const mm = String(monthNum).padStart(2, '0');
  const m = String(monthNum);
  const dd = String(dayNum).padStart(2, '0');
  const d = String(dayNum);

  return format
    .replace(/yyyy/gi, yyyy)
    .replace(/mm/gi, mm)
    .replace(/m/gi, m)
    .replace(/dd/gi, dd)
    .replace(/d/gi, d);
}

function validateMonthlyCompletionConfig_() {
  if (!MONTHLY_COMPLETION_CONFIG.spreadsheetId ||
      MONTHLY_COMPLETION_CONFIG.spreadsheetId === 'REPLACE_WITH_SPREADSHEET_ID' ||
      !MONTHLY_COMPLETION_CONFIG.chatWebhookUrl ||
      MONTHLY_COMPLETION_CONFIG.chatWebhookUrl === 'REPLACE_WITH_GOOGLE_CHAT_WEBHOOK_URL') {
    throw new Error('MONTHLY_COMPLETION_CONFIG의 spreadsheetId와 chatWebhookUrl을 먼저 설정해주세요.');
  }

  if (!MONTHLY_COMPLETION_CONFIG.checkRange || !MONTHLY_COMPLETION_CONFIG.targetString) {
    throw new Error('MONTHLY_COMPLETION_CONFIG의 checkRange와 targetString을 지정해주세요.');
  }

  if (!MONTHLY_COMPLETION_CONFIG.statusCell) {
    throw new Error('MONTHLY_COMPLETION_CONFIG의 statusCell(상태 셀 주소)을 지정해주세요. (예: "D1")');
  }
}
