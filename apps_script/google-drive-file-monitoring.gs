/**
 * ============================================
 * Google Drive 파일 모니터링 시스템 - 메서드 (Methods)
 * ============================================
 *
 * 설정값은 google-drive-file-monitoring-config.gs 에 정의되어 있습니다.
 */

/**
 * ============================================
 * 초기화 (최초 1회 수동 실행)
 * ============================================
 * 현재 드라이브 폴더의 모든 파일 상태를 스프레드시트에 최초 등록합니다.
 * (알림은 발송되지 않으며, 현재 상태가 향후 변경 감지의 기준점이 됩니다.)
 */
function initialize() {
  validateDriveMonitorConfig_();

  const folder = DriveApp.getFolderById(DRIVE_MONITOR_CONFIG.folderId);
  const sheet = getOrCreateMonitoringSheet_();
  const timezone = getDriveMonitorTimeZone_();

  // 시트 초기화 (기존 데이터 삭제 후 헤더 작성)
  sheet.clear();
  sheet.getRange(1, 1, 1, DRIVE_MONITOR_SHEET_HEADERS.length).setValues([DRIVE_MONITOR_SHEET_HEADERS]);
  sheet.getRange(1, 1, 1, DRIVE_MONITOR_SHEET_HEADERS.length).setFontWeight('bold');

  const filesMap = {};
  scanFolderRecursively_(folder, '', filesMap, timezone);

  const rows = Object.values(filesMap).map(f => [
    f.id,
    f.name,
    f.folderPath,
    f.lastModifiedStr,
    f.mimeType,
    f.owner,
    f.url,
    '정상 (초기 등록)'
  ]);

  if (rows.length > 0) {
    sheet.getRange(2, 1, rows.length, DRIVE_MONITOR_SHEET_HEADERS.length).setValues(rows);
  }

  Logger.log('====================================');
  Logger.log('초기화 완료!');
  Logger.log(`총 ${rows.length}개 파일이 스프레드시트에 등록되었습니다.`);
  Logger.log('====================================');
}

/**
 * ============================================
 * 변경사항 감시 실행 함수 (트리거로 주기적 실행)
 * ============================================
 */
function checkDriveChanges() {
  validateDriveMonitorConfig_();

  // 동시 실행 방지 락
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) {
    Logger.log('이전 작업이 아직 진행 중입니다.');
    return;
  }

  try {
    const folder = DriveApp.getFolderById(DRIVE_MONITOR_CONFIG.folderId);
    const sheet = getOrCreateMonitoringSheet_();
    const timezone = getDriveMonitorTimeZone_();

    // 1. 스프레드시트에 저장된 이전 상태 읽기 (타임존 보정 및 초 단위 변환)
    const knownFiles = loadKnownFilesFromSheet_(sheet, timezone);

    // 2. 현재 드라이브 상태 재귀 스캔 (초 단위 정수 타임스탬프 저장)
    const currentFiles = {};
    scanFolderRecursively_(folder, '', currentFiles, timezone);

    let newCount = 0;
    let updateCount = 0;
    const rowsToAppend = [];

    // 3. 파일 비교 및 변경사항 감지
    for (const fileId in currentFiles) {
      const current = currentFiles[fileId];
      const previous = knownFiles[fileId];

      if (!previous) {
        // [신규 파일 추가] (시트가 비어있으면 전체 발송)
        newCount++;
        sendDriveNoticeChat_({
          type: 'NEW',
          title: '📁 새 파일이 추가되었습니다.',
          file: current,
        });

        rowsToAppend.push([
          current.id,
          current.name,
          current.folderPath,
          current.lastModifiedStr,
          current.mimeType,
          current.owner,
          current.url,
          '신규 추가'
        ]);

        Utilities.sleep(150); // 웹훅 연속 호출 속도 조절
      } else {
        // [기존 파일 비교: 초 단위 정수 비교로 밀리초 오차 제거]
        const isTimeUpdated = current.lastModifiedSeconds > previous.lastModifiedSeconds;
        const isRenamed = previous.name !== current.name;
        const isMoved = previous.folderPath !== current.folderPath;

        // 시간 갱신, 이름 변경, 위치 이동 중 하나라도 실제로 일어났을 때만 알림
        if (isTimeUpdated || isRenamed || isMoved) {
          let changeType = 'UPDATED';
          let title = '📝 파일이 수정되었습니다.';

          if (isRenamed) {
            changeType = 'RENAMED';
            title = '✏️ 파일명이 변경되었습니다.';
          } else if (isMoved) {
            changeType = 'MOVED';
            title = '📂 파일 위치(폴더)가 변경되었습니다.';
          }

          updateCount++;
          sendDriveNoticeChat_({
            type: changeType,
            title: title,
            file: current,
            previous: previous,
          });

          // 시트 행 업데이트 (수정일, 파일명, 폴더경로, 상태)
          sheet.getRange(previous.rowNumber, 2).setValue(current.name);
          sheet.getRange(previous.rowNumber, 3).setValue(current.folderPath);
          sheet.getRange(previous.rowNumber, 4).setValue(current.lastModifiedStr);
          sheet.getRange(previous.rowNumber, 8).setValue(title.replace(/[^\w가-힣\s]/g, '').trim());

          Utilities.sleep(150);
        }
      }
    }

    // 신규 파일들 시트 하단에 일괄 추가
    if (rowsToAppend.length > 0) {
      const startRow = sheet.getLastRow() + 1;
      sheet.getRange(startRow, 1, rowsToAppend.length, DRIVE_MONITOR_SHEET_HEADERS.length).setValues(rowsToAppend);
    }

    Logger.log('====================================');
    Logger.log(`모니터링 완료 - 신규: ${newCount}건, 수정/변경: ${updateCount}건`);
    Logger.log('====================================');
  } finally {
    lock.releaseLock();
  }
}

/** 1시간 주기 시간 기반 트리거 생성 */
function createMonitoringTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(trigger => trigger.getHandlerFunction() === 'checkDriveChanges')
    .forEach(trigger => ScriptApp.deleteTrigger(trigger));

  ScriptApp.newTrigger('checkDriveChanges')
    .timeBased()
    .everyHours(1)
    .create();
}

/** 폴더 및 하위 폴더 재귀 검색 헬퍼 */
function scanFolderRecursively_(folder, parentPath, filesMap, timezone) {
  const currentPath = parentPath ? `${parentPath} / ${folder.getName()}` : folder.getName();

  // 1. 현재 폴더 파일 목록 추출
  const files = folder.getFiles();
  while (files.hasNext()) {
    const file = files.next();
    const fileId = file.getId();
    const lastUpdated = file.getLastUpdated();

    let ownerStr = '-';
    try {
      const owner = file.getOwner();
      if (owner) {
        ownerStr = owner.getName() ? `${owner.getName()} (${owner.getEmail()})` : owner.getEmail();
      }
    } catch (e) {
      // 공유 드라이브인 경우 getOwner 접근 제한이 있을 수 있음
      ownerStr = '공유 드라이브';
    }

    filesMap[fileId] = {
      id: fileId,
      name: file.getName(),
      folderPath: currentPath,
      // 밀리초 오차를 없애기 위해 초(Seconds) 단위 정수로 저장
      lastModifiedSeconds: Math.floor(lastUpdated.getTime() / 1000),
      lastModifiedStr: Utilities.formatDate(lastUpdated, timezone, 'yyyy-MM-dd HH:mm:ss'),
      mimeType: simplifyMimeType_(file.getMimeType()),
      owner: ownerStr,
      url: file.getUrl(),
    };
  }

  // 2. 하위 폴더 재귀 순회
  const subFolders = folder.getFolders();
  while (subFolders.hasNext()) {
    scanFolderRecursively_(subFolders.next(), currentPath, filesMap, timezone);
  }
}

/** 시트에 기록된 기존 파일 목록 로드 (Date 객체/문자열 및 타임존 완벽 보정) */
function loadKnownFilesFromSheet_(sheet, timezone) {
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) {
    return {};
  }

  const values = sheet.getRange(2, 1, lastRow - 1, DRIVE_MONITOR_SHEET_HEADERS.length).getValues();
  const known = {};

  values.forEach((row, index) => {
    const [id, name, folderPath, lastModifiedVal, mimeType, owner, url, status] = row;
    if (!id) return;

    let lastModifiedStr = '';
    let lastModifiedSeconds = 0;

    // 시트 셀 값이 Date 객체인 경우
    if (lastModifiedVal instanceof Date && !isNaN(lastModifiedVal.getTime())) {
      lastModifiedStr = Utilities.formatDate(lastModifiedVal, timezone, 'yyyy-MM-dd HH:mm:ss');
      lastModifiedSeconds = Math.floor(lastModifiedVal.getTime() / 1000);
    } else if (lastModifiedVal) {
      // 시트 셀 값이 문자열인 경우 타임존 기준 파싱
      lastModifiedStr = String(lastModifiedVal).trim();
      const parsed = Utilities.parseDate(lastModifiedStr, timezone, 'yyyy-MM-dd HH:mm:ss');
      if (parsed && !isNaN(parsed.getTime())) {
        lastModifiedSeconds = Math.floor(parsed.getTime() / 1000);
      } else {
        const fallback = new Date(lastModifiedStr);
        if (!isNaN(fallback.getTime())) {
          lastModifiedSeconds = Math.floor(fallback.getTime() / 1000);
        }
      }
    }

    known[String(id)] = {
      rowNumber: index + 2, // 실제 시트 행 번호
      id: String(id),
      name: String(name),
      folderPath: String(folderPath),
      lastModifiedSeconds: lastModifiedSeconds,
      lastModifiedStr: lastModifiedStr,
      mimeType: String(mimeType),
      owner: String(owner),
      url: String(url),
    };
  });

  return known;
}

/** Google Chat 카드(Card v2) 알림 전송 */
function sendDriveNoticeChat_(info) {
  const { type, title, file, previous } = info;

  let body = `<b>${title}</b><br><br>`;
  body += `<b>파일명:</b> ${file.name}<br>`;
  body += `<b>위치:</b> ${file.folderPath}<br>`;

  if (type === 'RENAMED' && previous) {
    body += `<b>이전 파일명:</b> ${previous.name}<br>`;
  } else if (type === 'MOVED' && previous) {
    body += `<b>이전 위치:</b> ${previous.folderPath}<br>`;
  }

  body += `<b>파일 형식:</b> ${file.mimeType}<br>`;
  body += `<b>소유자:</b> ${file.owner}<br>`;
  body += `<b>수정 시간:</b> ${file.lastModifiedStr}<br><br>`;
  body += `👉 <a href="${file.url}">Google Drive에서 파일 열기</a>`;

  const payload = {
    cardsV2: [
      {
        cardId: 'drive-notice-' + Date.now(),
        card: {
          sections: [
            {
              widgets: [
                {
                  textParagraph: {
                    text: body,
                  },
                },
              ],
            },
          ],
        },
      },
    ],
  };

  const response = UrlFetchApp.fetch(DRIVE_MONITOR_CONFIG.chatWebhookUrl, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });

  const status = response.getResponseCode();
  if (status < 200 || status >= 300) {
    Logger.log(`Google Chat 웹훅 발송 실패 (${status}): ${response.getContentText()}`);
  }
}

/** MIME Type 단순화 (가독성 향상) */
function simplifyMimeType_(mime) {
  if (mime.includes('spreadsheet')) return 'Google 스프레드시트';
  if (mime.includes('document')) return 'Google 문서';
  if (mime.includes('presentation')) return 'Google 프레젠테이션';
  if (mime.includes('pdf')) return 'PDF 문서';
  if (mime.includes('image')) return '이미지 파일';
  if (mime.includes('zip') || mime.includes('compressed')) return '압축 파일';
  return mime;
}

/** 모니터링용 시트 가져오기 (없으면 자동 생성) */
function getOrCreateMonitoringSheet_() {
  const spreadsheet = SpreadsheetApp.openById(DRIVE_MONITOR_CONFIG.spreadsheetId);
  let sheet = DRIVE_MONITOR_CONFIG.sheetName
    ? spreadsheet.getSheetByName(DRIVE_MONITOR_CONFIG.sheetName)
    : spreadsheet.getSheets()[0];

  if (!sheet && DRIVE_MONITOR_CONFIG.sheetName) {
    sheet = spreadsheet.insertSheet(DRIVE_MONITOR_CONFIG.sheetName);
  }
  return sheet;
}

/** 유효 타임존 반환 */
function getDriveMonitorTimeZone_() {
  if (DRIVE_MONITOR_CONFIG.timeZone) {
    return DRIVE_MONITOR_CONFIG.timeZone;
  }
  const spreadsheet = SpreadsheetApp.openById(DRIVE_MONITOR_CONFIG.spreadsheetId);
  return spreadsheet.getSpreadsheetTimeZone() || Session.getScriptTimeZone();
}

function validateDriveMonitorConfig_() {
  if (!DRIVE_MONITOR_CONFIG.folderId || DRIVE_MONITOR_CONFIG.folderId === 'YOUR_FOLDER_ID' ||
      !DRIVE_MONITOR_CONFIG.spreadsheetId || DRIVE_MONITOR_CONFIG.spreadsheetId === 'YOUR_SPREADSHEET_ID' ||
      !DRIVE_MONITOR_CONFIG.chatWebhookUrl || DRIVE_MONITOR_CONFIG.chatWebhookUrl === 'YOUR_CHAT_WEBHOOK_URL') {
    throw new Error('DRIVE_MONITOR_CONFIG의 folderId, spreadsheetId, chatWebhookUrl을 모두 올바르게 입력해주세요.');
  }
}
