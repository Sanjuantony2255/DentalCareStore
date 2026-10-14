/**
 * Patient Registration & Revisit + Billing & Invoices + Appointments & Google Calendar
 * Google Apps Script Backend
 *
 * SPREADSHEET CONFIGURATION:
 * 1. Container-bound script: If this script was created from Google Sheets
 *    via (Extensions > Apps Script), it automatically connects to your sheet. Leave SPREADSHEET_ID empty.
 * 2. Standalone script: If created at script.google.com, copy your Google Sheet ID
 *    from its URL (https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID/edit) and paste below.
 */
var SPREADSHEET_ID = ""; // Optional: Paste your Spreadsheet ID if using standalone Apps Script

// CLINIC NOTIFICATION & GOOGLE CALENDAR EMAIL
var CLINIC_NOTIFICATION_EMAIL = "sanjuantony01@gmail.com";

function getSpreadsheet() {
  var ss = null;
  if (typeof SPREADSHEET_ID === 'string' && SPREADSHEET_ID.trim() !== "") {
    try {
      ss = SpreadsheetApp.openById(SPREADSHEET_ID.trim());
    } catch (e) {
      throw new Error("Could not open spreadsheet with ID: " + SPREADSHEET_ID + ". Details: " + e.message);
    }
  }

  if (!ss) {
    try {
      ss = SpreadsheetApp.getActiveSpreadsheet();
    } catch (e) {
      ss = null;
    }
  }

  if (!ss) {
    throw new Error("No connected Google Sheet found. If this is a standalone Apps Script project, please paste your Google Sheet ID into the SPREADSHEET_ID variable at the top of Code.gs.");
  }
  return ss;
}

/**
 * Retrieves the Google Calendar connected to the clinic doctor/admin (sanjuantony01@gmail.com).
 * First checks by ID, then falls back to default calendar.
 */
function getClinicCalendar() {
  var cal = null;
  if (CLINIC_NOTIFICATION_EMAIL) {
    try {
      cal = CalendarApp.getCalendarById(CLINIC_NOTIFICATION_EMAIL);
    } catch (e1) {
      Logger.log("getCalendarById error: " + e1.toString());
    }
  }
  if (!cal) {
    try {
      cal = CalendarApp.getDefaultCalendar();
    } catch (e2) {
      Logger.log("getDefaultCalendar error: " + e2.toString());
    }
  }
  return cal;
}

/**
 * Safely creates or invites a Google Calendar event without throwing "Cannot invite organizer"
 * when the calendar or Session effective user matches CLINIC_NOTIFICATION_EMAIL (sanjuantony01@gmail.com).
 */
function createCalendarEventSafe(cal, title, startTime, endTime, desc, patientEmail) {
  var clinicEmail = (CLINIC_NOTIFICATION_EMAIL || '').toLowerCase().trim();
  var effectiveUserEmail = '';
  try {
    effectiveUserEmail = Session.getEffectiveUser().getEmail().toLowerCase().trim();
  } catch (euErr) {}

  var calId = '';
  try {
    calId = cal.getId().toLowerCase().trim();
  } catch (cidErr) {}

  var guests = [];
  // Add patient email if valid and not organizer/clinic
  if (patientEmail) {
    var pEmailClean = patientEmail.toLowerCase().trim();
    if (pEmailClean !== clinicEmail && pEmailClean !== effectiveUserEmail && pEmailClean !== calId) {
      guests.push(patientEmail.trim());
    }
  }

  // Only invite clinic email as a guest IF the calendar being used is NOT owned by clinic email
  // (otherwise Google Calendar throws "Cannot invite organizer" and aborts event creation!)
  if (clinicEmail && calId !== clinicEmail && effectiveUserEmail !== clinicEmail) {
    guests.push(CLINIC_NOTIFICATION_EMAIL);
  }

  var options = {
    description: desc,
    location: "Dental Care Clinic & Hospital"
  };

  if (guests.length > 0) {
    options.guests = guests.join(',');
    options.sendInvites = true;
  }

  var event = cal.createEvent(title, startTime, endTime, options);
  try {
    event.removeAllReminders();
    event.addPopupReminder(15);   // 15 mins before popup
    event.addPopupReminder(60);   // 1 hour before popup
    event.addEmailReminder(1440); // 1 day before email notification
    event.addEmailReminder(120);  // 2 hours before email notification
  } catch (remErr) {
    Logger.log("addReminder warning: " + remErr.toString());
  }
  return event;
}

/**
 * Sends a rich email alert to sanjuantony01@gmail.com whenever an appointment is booked or rescheduled.
 */
function sendAppointmentNotificationEmail(apt, isReschedule) {
  try {
    if (!CLINIC_NOTIFICATION_EMAIL) return;

    var pName = apt.patientName || 'Patient';
    var pPhone = apt.phone || 'N/A';
    var pDate = apt.date || '';
    var pTime = apt.time || '';
    var doc = apt.doctor || 'Attending Doctor';
    var reason = apt.reason || 'General Consultation';
    var notes = apt.notes || 'None';
    var aptId = apt.appointmentId || '';

    var subject = isReschedule
      ? ("🔄 Rescheduled Appointment: " + pName + " (" + pDate + " at " + pTime + ")")
      : ("📅 New Appointment: " + pName + " (" + pDate + " at " + pTime + ")");

    var calDate = pDate.replace(/[^0-9]/g, '');
    var calTime = (pTime || '10:00').replace(/[^0-9]/g, '');
    if (calTime.length === 3) calTime = '0' + calTime;
    if (calTime.length < 4) calTime = '1000';
    var startDT = calDate + 'T' + calTime.slice(0, 4) + '00';
    var endH = (parseInt(calTime.slice(0, 2), 10) || 10);
    var endM = (parseInt(calTime.slice(2, 4), 10) || 0) + 30;
    if (endM >= 60) { endH = (endH + 1) % 24; endM -= 60; }
    var pad = function(n) { return ('0' + n).slice(-2); };
    var endDT = calDate + 'T' + pad(endH) + pad(endM) + '00';

    var calLink = "https://calendar.google.com/calendar/render?action=TEMPLATE&text=" +
      encodeURIComponent("Dental Appointment: " + pName + (doc ? " (" + doc + ")" : "")) +
      "&dates=" + startDT + "/" + endDT +
      "&details=" + encodeURIComponent("Patient: " + pName + "\nPhone: " + pPhone + "\nDoctor: " + doc + "\nReason: " + reason + "\nNotes: " + notes + "\nAppointment ID: " + aptId) +
      "&location=" + encodeURIComponent("Dental Care Clinic") +
      "&add=" + encodeURIComponent(CLINIC_NOTIFICATION_EMAIL);

    var htmlBody = '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;">' +
      '<div style="background: #0d9488; color: white; padding: 18px 24px; text-align: center;">' +
        '<h2 style="margin: 0; font-size: 20px;">' + (isReschedule ? '🔄 Appointment Rescheduled' : '📅 New Appointment Scheduled') + '</h2>' +
        '<p style="margin: 4px 0 0 0; opacity: 0.9; font-size: 13px;">Dental Care Clinic System Notification</p>' +
      '</div>' +
      '<div style="padding: 20px; background: #ffffff;">' +
        '<table style="width: 100%; border-collapse: collapse; font-size: 14px;">' +
          '<tr><td style="padding: 6px 0; color: #64748b; width: 130px;"><strong>Patient:</strong></td><td style="padding: 6px 0; color: #1e293b; font-weight: bold;">' + pName + '</td></tr>' +
          '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Phone:</strong></td><td style="padding: 6px 0; color: #0d9488; font-weight: bold;"><a href="tel:' + pPhone + '">' + pPhone + '</a></td></tr>' +
          '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Date:</strong></td><td style="padding: 6px 0; color: #1e293b; font-weight: bold;">' + pDate + '</td></tr>' +
          '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Time:</strong></td><td style="padding: 6px 0; color: #1e293b; font-weight: bold;">' + pTime + '</td></tr>' +
          '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Doctor:</strong></td><td style="padding: 6px 0; color: #1e293b;">' + doc + '</td></tr>' +
          '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Treatment:</strong></td><td style="padding: 6px 0; color: #1e293b;">' + reason + '</td></tr>' +
          (notes ? ('<tr><td style="padding: 6px 0; color: #64748b;"><strong>Notes:</strong></td><td style="padding: 6px 0; color: #1e293b;">' + notes + '</td></tr>') : '') +
          '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Appointment ID:</strong></td><td style="padding: 6px 0; color: #64748b;">' + aptId + '</td></tr>' +
        '</table>' +
        '<div style="text-align: center; margin-top: 20px; padding-top: 16px; border-top: 1px solid #f1f5f9;">' +
          '<a href="' + calLink + '" style="background: #0d9488; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">📅 Open / Add to Google Calendar</a>' +
        '</div>' +
      '</div>' +
      '<div style="background: #f8fafc; padding: 10px; text-align: center; font-size: 11px; color: #94a3b8;">' +
        'Connected Google Calendar: ' + CLINIC_NOTIFICATION_EMAIL + ' • Automatic Reminders Active' +
      '</div>' +
    '</div>';

    MailApp.sendEmail({
      to: CLINIC_NOTIFICATION_EMAIL,
      subject: subject,
      htmlBody: htmlBody
    });
  } catch (mErr) {
    Logger.log("sendAppointmentNotificationEmail notice: " + mErr.toString());
  }
}

/**
 * Intelligent non-colliding column matcher
 */
function getHeaderColumnIndex(headersLower, primaryKeywords, excludeKeywords, defaultIndex) {
  for (var c = 0; c < headersLower.length; c++) {
    var h = headersLower[c];
    var excluded = false;
    if (excludeKeywords && excludeKeywords.length > 0) {
      for (var e = 0; e < excludeKeywords.length; e++) {
        if (h.indexOf(excludeKeywords[e]) !== -1) {
          excluded = true;
          break;
        }
      }
    }
    if (excluded) continue;
    for (var k = 0; k < primaryKeywords.length; k++) {
      if (h.indexOf(primaryKeywords[k]) !== -1) return c;
    }
  }
  return defaultIndex;
}

/**
 * Robust non-overlapping sheet getters
 * NEVER use getActiveSheet() because insertSheet() changes the active sheet!
 */
function getVisitsSheet(ss) {
  var sheet = ss.getSheetByName("Patients") || ss.getSheetByName("Visits") || ss.getSheetByName("Patient_Visits");
  if (!sheet) {
    // If neither exists, pick the first sheet that is NOT "Invoices" and NOT "Appointments"
    var allSheets = ss.getSheets();
    for (var i = 0; i < allSheets.length; i++) {
      var sName = allSheets[i].getName();
      if (sName !== "Invoices" && sName !== "Appointments") {
        sheet = allSheets[i];
        break;
      }
    }
    if (!sheet) {
      sheet = ss.insertSheet("Patients");
    }
  }

  var headers = [
    'Timestamp', 
    'Full Name', 
    'Phone', 
    'Email', 
    'DOB', 
    'Gender', 
    'Medical History', 
    'Disease History', 
    'Last Visit Date', 
    'Doctor Consulted',
    'Consultation Charge',
    'X-Ray Charge',
    'Pharmacy Charge',
    'Total Amount',
    'Payment Mode',
    'Invoice No',
    'Google Drive Invoice URL'
  ];

  if (sheet.getLastRow() === 0) {
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#0d9488').setFontColor('#ffffff');
    sheet.setFrozenRows(1);
  } else {
    // Check existing headers and make sure all required headers exist
    var lastCol = Math.max(sheet.getLastColumn(), 1);
    var existingHeaders = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
    var existingHeadersLower = existingHeaders.map(function(h) { return (h || '').toString().toLowerCase().trim(); });
    
    var missingHeaders = [];
    for (var hIdx = 0; hIdx < headers.length; hIdx++) {
      var hName = headers[hIdx];
      var hLower = hName.toLowerCase().trim();
      var found = false;
      for (var eIdx = 0; eIdx < existingHeadersLower.length; eIdx++) {
        if (existingHeadersLower[eIdx] === hLower || existingHeadersLower[eIdx].indexOf(hLower) !== -1) {
          found = true;
          break;
        }
      }
      if (!found) {
        missingHeaders.push(hName);
      }
    }
    
    if (missingHeaders.length > 0) {
      for (var m = 0; m < missingHeaders.length; m++) {
        var newCol = lastCol + 1 + m;
        sheet.getRange(1, newCol).setValue(missingHeaders[m]).setFontWeight('bold').setBackground('#0d9488').setFontColor('#ffffff');
      }
    }
  }
  return sheet;
}

/**
 * Appends a patient visit row aligning with the header columns dynamically
 */
function appendVisitRowMapped(sheet, data, headers) {
  var headerValues = sheet.getRange(1, 1, 1, Math.max(sheet.getLastColumn(), headers.length)).getValues()[0];
  var row = [];
  
  for (var c = 0; c < headerValues.length; c++) {
    var h = (headerValues[c] || '').toString().toLowerCase().trim();
    var val = '';
    
    if (h.indexOf('time') !== -1) val = data.timestamp || '';
    else if (h.indexOf('op') !== -1) val = data.opNumber || '';
    else if (h.indexOf('full') !== -1 || (h.indexOf('name') !== -1 && h.indexOf('doctor') === -1)) val = data.fullName || '';
    else if (h.indexOf('phone') !== -1 || h.indexOf('mobile') !== -1) val = data.phone ? "'" + data.phone.toString().trim() : '';
    else if (h.indexOf('address') !== -1) val = data.address || data.email || '';
    else if (h.indexOf('email') !== -1) val = data.email || data.address || '';
    else if (h.indexOf('age') !== -1) val = data.age || data.dob || '';
    else if (h.indexOf('dob') !== -1 || h.indexOf('birth') !== -1) val = data.dob || data.age || '';
    else if (h.indexOf('gender') !== -1 || h.indexOf('sex') !== -1) val = data.gender || '';
    else if (h.indexOf('medical') !== -1) val = data.medicalHistory || '';
    else if (h.indexOf('allerg') !== -1 || h.indexOf('drug') !== -1 || h.indexOf('disease') !== -1) val = data.drugAllergies || data.diseaseHistory || '';
    else if (h.indexOf('last') !== -1 && h.indexOf('visit') !== -1) val = data.lastVisitDate || '';
    else if (h.indexOf('doctor') !== -1) val = data.doctorConsulted || '';
    else if (h.indexOf('consult') !== -1) val = (parseFloat(data.consultationCharge) || 0).toFixed(2);
    else if (h.indexOf('xray') !== -1 || h.indexOf('x-ray') !== -1) val = (parseFloat(data.xrayCharge) || 0).toFixed(2);
    else if (h.indexOf('pharm') !== -1 || h.indexOf('medicin') !== -1) val = (parseFloat(data.pharmacyCharge) || 0).toFixed(2);
    else if (h.indexOf('total') !== -1 || h.indexOf('amount') !== -1) val = (parseFloat(data.totalAmount) || 0).toFixed(2);
    else if (h.indexOf('payment') !== -1 || h.indexOf('mode') !== -1) val = data.paymentMode || 'Cash';
    else if (h.indexOf('invoice') !== -1 && h.indexOf('drive') === -1 && h.indexOf('url') === -1) val = data.invoiceNo || '';
    else if (h.indexOf('drive') !== -1 || h.indexOf('url') !== -1 || h.indexOf('file') !== -1) val = data.driveFileUrl || '';
    
    row.push(val);
  }
  
  sheet.appendRow(row);
}

function getInvoicesSheet(ss) {
  var sheet = ss.getSheetByName("Invoices");
  if (!sheet) {
    sheet = ss.insertSheet("Invoices");
    var headers = [
      'Invoice No',
      'Date & Time',
      'Patient Name',
      'Phone',
      'Doctor Consulted',
      'Consultation Charge',
      'X-Ray Charge',
      'Pharmacy Charge',
      'Total Amount',
      'Payment Mode',
      'Google Drive URL'
    ];
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#1e3a8a').setFontColor('#ffffff');
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function getAppointmentsSheet(ss) {
  var sheet = ss.getSheetByName("Appointments");
  if (!sheet) {
    sheet = ss.insertSheet("Appointments");
    var headers = [
      'Appointment ID',
      'Patient Name',
      'Phone',
      'Email',
      'Date',
      'Time',
      'Doctor',
      'Reason / Treatment',
      'Status',
      'Google Calendar Event ID',
      'Created At',
      'Notes'
    ];
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#0d9488').setFontColor('#ffffff');
    sheet.setFrozenRows(1);
  }
  return sheet;
}

/**
 * Handle POST requests
 */
function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    lock.waitLock(30000);
  } catch (err) {
    return createJsonResponse({ 'status': 'error', 'message': 'Server busy, please retry.' });
  }

  try {
    var ss = getSpreadsheet();
    var contents = e && e.postData && e.postData.contents ? e.postData.contents : "{}";
    var data = {};
    try {
      data = JSON.parse(contents);
    } catch (parseErr) {
      data = {};
    }

    if (e && e.parameter) {
      for (var paramKey in e.parameter) {
        if (!data.hasOwnProperty(paramKey)) {
          data[paramKey] = e.parameter[paramKey];
        }
      }
    }

    var action = (e && e.parameter && e.parameter.action) || data.action || '';

    // 1. Add Appointment with Google Calendar sync
    if (action === 'addAppointment') {
      return handleAddAppointment(ss, data);
    }

    // 2. Reschedule Appointment with Google Calendar sync
    if (action === 'rescheduleAppointment') {
      return handleRescheduleAppointment(ss, data);
    }

    // 3. Update Appointment Status (Completed, Cancelled)
    if (action === 'updateAppointmentStatus') {
      return handleUpdateAppointmentStatus(ss, data);
    }

    // 4. Generate / Save Invoice on demand
    if (action === 'generateInvoice') {
      return handleGenerateInvoice(ss, data);
    }

    // 5. Sync All Appointments with Google Calendar
    if (action === 'syncCalendar') {
      return handleSyncCalendar(ss);
    }

    // 6. Get All Registered Patients Directory
    if (action === 'getPatients' || action === 'getAllPatients') {
      return handleGetPatients(ss);
    }

    // 7. Pharmacy Inventory & Stock Actions
    if (action === 'getPharmacyStock') {
      return handleGetPharmacyStock(ss);
    }
    if (action === 'addPharmacyItem') {
      return handleAddPharmacyItem(ss, data);
    }
    if (action === 'updatePharmacyStock') {
      return handleUpdatePharmacyStock(ss, data);
    }

    // 8. Accounts & Revenue Analytics
    if (action === 'getAccounts') {
      return handleGetAccounts(ss, data);
    }

    // 9. Default: Patient Registration / Revisit & Billing
    return handlePatientRegistration(ss, data);

  } catch (error) {
    return createJsonResponse({ status: 'error', message: error.toString() });
  } finally {
    lock.releaseLock();
  }
}

/**
 * Handle Patient Registration and Revisit
 */
function handlePatientRegistration(ss, data) {
  var visitsSheet = getVisitsSheet(ss);
  var timestamp = data.timestamp || Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm:ss");
  var phoneStr = data.phone ? "'" + data.phone.toString().trim() : '';

  var consultation = parseFloat(data.consultationCharge) || 0;
  var xray = parseFloat(data.xrayCharge) || 0;
  var pharmacy = parseFloat(data.pharmacyCharge) || 0;
  var total = parseFloat(data.totalAmount) || (consultation + xray + pharmacy);
  var paymentMode = data.paymentMode || 'Cash';

  var randomSuffix = Math.floor(1000 + Math.random() * 9000);
  var datePrefix = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyyMMdd");
  var invoiceNo = data.invoiceNo || ('INV-' + datePrefix + '-' + randomSuffix);

  var docName = (data.doctorConsulted || '').toString().trim();
  if (docName.toLowerCase().indexOf('consulting specialist') !== -1) docName = '';

  // Store Invoice in Google Drive
  var driveResult = { fileUrl: '', downloadUrl: '', fileId: '' };
  try {
    var invoiceData = {
      invoiceNo: invoiceNo,
      timestamp: timestamp,
      fullName: data.fullName || 'Valued Patient',
      phone: data.phone || '',
      address: data.address || data.email || '',
      email: data.address || data.email || '',
      age: data.age || data.dob || '',
      dob: data.dob || data.age || '',
      opNumber: data.opNumber || '',
      gender: data.gender || '',
      doctorConsulted: docName || 'Attending Doctor',
      medicalHistory: data.medicalHistory || '',
      diseaseHistory: data.drugAllergies || data.diseaseHistory || '',
      drugAllergies: data.drugAllergies || data.diseaseHistory || '',
      consultationCharge: consultation,
      xrayCharge: xray,
      pharmacyCharge: pharmacy,
      totalAmount: total,
      paymentMode: paymentMode
    };
    driveResult = saveInvoiceToGoogleDrive(invoiceData);
  } catch (driveErr) {
    Logger.log("Google Drive storage notice: " + driveErr.toString());
  }

  // 1. Append to Visits Sheet dynamically aligned with headers
  var visitRecord = {
    timestamp: timestamp,
    fullName: data.fullName || '',
    phone: data.phone || '',
    address: data.address || data.email || '',
    email: data.address || data.email || '',
    age: data.age || data.dob || '',
    dob: data.dob || data.age || '',
    opNumber: data.opNumber || '',
    gender: data.gender || '',
    medicalHistory: data.medicalHistory || '',
    diseaseHistory: data.drugAllergies || data.diseaseHistory || '',
    drugAllergies: data.drugAllergies || data.diseaseHistory || '',
    lastVisitDate: data.lastVisitDate || '',
    doctorConsulted: docName,
    consultationCharge: consultation,
    xrayCharge: xray,
    pharmacyCharge: pharmacy,
    totalAmount: total,
    paymentMode: paymentMode,
    invoiceNo: invoiceNo,
    driveFileUrl: driveResult.fileUrl || ''
  };
  appendVisitRowMapped(visitsSheet, visitRecord, [
    'Timestamp', 'Full Name', 'Phone', 'Email', 'DOB', 'Gender', 
    'Medical History', 'Disease History', 'Last Visit Date', 'Doctor Consulted',
    'Consultation Charge', 'X-Ray Charge', 'Pharmacy Charge', 'Total Amount', 
    'Payment Mode', 'Invoice No', 'Google Drive Invoice URL'
  ]);

  // 2. ALWAYS record in dedicated "Invoices" tab if any charges or invoice generated
  try {
    var invoicesSheet = getInvoicesSheet(ss);
    invoicesSheet.appendRow([
      invoiceNo,
      timestamp,
      data.fullName || '',
      phoneStr,
      data.doctorConsulted || '',
      consultation.toFixed(2),
      xray.toFixed(2),
      pharmacy.toFixed(2),
      total.toFixed(2),
      paymentMode,
      driveResult.fileUrl || ''
    ]);
  } catch (invErr) {
    Logger.log("Invoices sheet logging notice: " + invErr.toString());
  }

  return createJsonResponse({
    status: 'success',
    message: 'Record saved successfully!',
    invoice: {
      invoiceNo: invoiceNo,
      timestamp: timestamp,
      fullName: data.fullName || '',
      phone: data.phone || '',
      address: data.address || data.email || '',
      email: data.address || data.email || '',
      age: data.age || '',
      dob: data.dob || (data.age ? (data.age + ' yrs') : ''),
      opNumber: data.opNumber || '',
      gender: data.gender || '',
      doctorConsulted: data.doctorConsulted || '',
      consultationCharge: consultation,
      xrayCharge: xray,
      pharmacyCharge: pharmacy,
      totalAmount: total,
      paymentMode: paymentMode,
      driveFileUrl: driveResult.fileUrl || '',
      driveDownloadUrl: driveResult.downloadUrl || ''
    }
  });
}

/**
 * Handle On-Demand Invoice Generation (e.g. from search page)
 */
function handleGenerateInvoice(ss, data) {
  var timestamp = data.timestamp || Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm:ss");
  var phoneStr = data.phone ? "'" + data.phone.toString().trim() : '';
  var consultation = parseFloat(data.consultationCharge) || 0;
  var xray = parseFloat(data.xrayCharge) || 0;
  var pharmacy = parseFloat(data.pharmacyCharge) || 0;
  var total = parseFloat(data.totalAmount) || (consultation + xray + pharmacy);
  var paymentMode = data.paymentMode || 'Cash';

  var randomSuffix = Math.floor(1000 + Math.random() * 9000);
  var datePrefix = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyyMMdd");
  var invoiceNo = data.invoiceNo || ('INV-' + datePrefix + '-' + randomSuffix);

  var doc = (data.doctorConsulted || '').toString().trim();
  if (doc.toLowerCase().indexOf('consulting specialist') !== -1) doc = '';

  var invoiceData = {
    invoiceNo: invoiceNo,
    timestamp: timestamp,
    fullName: data.fullName || data.patientName || 'Valued Patient',
    phone: data.phone || '',
    email: data.email || '',
    dob: data.dob || '',
    gender: data.gender || '',
    doctorConsulted: doc || 'Attending Doctor',
    consultationCharge: consultation,
    xrayCharge: xray,
    pharmacyCharge: pharmacy,
    totalAmount: total,
    paymentMode: paymentMode
  };

  var driveResult = saveInvoiceToGoogleDrive(invoiceData);

  var invoicesSheet = getInvoicesSheet(ss);
  invoicesSheet.appendRow([
    invoiceNo,
    timestamp,
    invoiceData.fullName,
    phoneStr,
    invoiceData.doctorConsulted,
    consultation.toFixed(2),
    xray.toFixed(2),
    pharmacy.toFixed(2),
    total.toFixed(2),
    paymentMode,
    driveResult.fileUrl || ''
  ]);

  return createJsonResponse({
    status: 'success',
    message: 'Invoice generated and stored successfully!',
    invoice: {
      invoiceNo: invoiceNo,
      timestamp: timestamp,
      fullName: invoiceData.fullName,
      phone: data.phone || '',
      email: data.email || '',
      doctorConsulted: invoiceData.doctorConsulted,
      consultationCharge: consultation,
      xrayCharge: xray,
      pharmacyCharge: pharmacy,
      totalAmount: total,
      paymentMode: paymentMode,
      driveFileUrl: driveResult.fileUrl || '',
      driveDownloadUrl: driveResult.downloadUrl || ''
    }
  });
}

/**
 * Handle Appointment Booking with Google Calendar sync
 */
function handleAddAppointment(ss, data) {
  var aptSheet = getAppointmentsSheet(ss);
  var createdAt = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm:ss");

  var dateStr = (data.date || '').toString().trim(); // YYYY-MM-DD
  var timeStr = (data.time || '10:00').toString().trim(); // HH:mm
  if (timeStr.indexOf('1899') !== -1 || !timeStr) timeStr = '10:00';
  var patientName = (data.patientName || data.fullName || '').toString().trim();
  var phone = (data.phone || '').toString().trim();
  var email = (data.email || '').toString().trim();
  var doctor = (data.doctor || data.doctorConsulted || '').toString().trim();
  if (doctor.toLowerCase().indexOf('consulting specialist') !== -1) doctor = '';
  var reason = (data.reason || data.treatment || 'Consultation & Checkup').toString().trim();
  var notes = (data.notes || '').toString().trim();
  var status = data.status || 'Scheduled';

  var aptId = 'APT-' + dateStr.replace(/[^0-9]/g, '') + '-' + Math.floor(1000 + Math.random() * 9000);

  // Sync with Google Calendar
  var calEventId = '';
  var calErrorMsg = '';
  try {
    var cal = getClinicCalendar();
    if (cal && dateStr) {
      var dateParts = dateStr.split('-');
      var timeParts = timeStr.split(':');
      var year = parseInt(dateParts[0], 10);
      var month = parseInt(dateParts[1], 10) - 1;
      var day = parseInt(dateParts[2], 10);
      var hour = timeParts.length > 0 ? parseInt(timeParts[0], 10) : 10;
      var minute = timeParts.length > 1 ? parseInt(timeParts[1], 10) : 0;

      var startTime = new Date(year, month, day, hour, minute);
      var endTime = new Date(startTime.getTime() + 30 * 60 * 1000); // 30 minutes duration

      var title = 'Dental Appointment: ' + patientName + (doctor ? ' (' + doctor + ')' : '');
      var desc = 'Patient Name: ' + patientName + '\n' +
                 'Phone: ' + phone + '\n' +
                 (doctor ? 'Doctor: ' + doctor + '\n' : '') +
                 'Reason: ' + reason + '\n' +
                 (notes ? 'Notes: ' + notes + '\n' : '') +
                 'Appointment ID: ' + aptId;

      var event = createCalendarEventSafe(cal, title, startTime, endTime, desc, email);
      calEventId = event.getId();
    }
  } catch (calErr) {
    calErrorMsg = calErr.toString();
    Logger.log("Google Calendar error: " + calErr.toString());
  }

  // Prepend apostrophe to date & time so Google Sheets NEVER scrambles them with timezone auto-detection!
  aptSheet.appendRow([
    aptId,
    patientName,
    phone ? "'" + phone : '',
    email,
    dateStr ? "'" + dateStr : '',
    timeStr ? "'" + timeStr : '',
    doctor,
    reason,
    status,
    calEventId,
    createdAt,
    notes
  ]);

  var appointmentObj = {
    appointmentId: aptId,
    patientName: patientName,
    phone: phone,
    email: email,
    date: dateStr,
    time: timeStr,
    doctor: doctor,
    reason: reason,
    status: status,
    calEventId: calEventId,
    calError: calErrorMsg,
    createdAt: createdAt,
    notes: notes
  };

  // Instant notification email delivered to sanjuantony01@gmail.com
  sendAppointmentNotificationEmail(appointmentObj, false);

  var msg = calEventId 
    ? ('Appointment booked successfully and synchronized with Google Calendar (' + CLINIC_NOTIFICATION_EMAIL + ')!')
    : ('Appointment booked in sheet.' + (calErrorMsg ? (' Note: Calendar sync error: ' + calErrorMsg) : ''));

  return createJsonResponse({
    status: 'success',
    message: msg,
    appointment: appointmentObj
  });
}

/**
 * Handle Appointment Rescheduling with Google Calendar update
 */
function handleRescheduleAppointment(ss, data) {
  var aptSheet = getAppointmentsSheet(ss);
  var aptId = (data.appointmentId || '').toString().trim();
  var newDate = (data.newDate || data.date || '').toString().trim();
  var newTime = (data.newTime || data.time || '10:00').toString().trim();
  if (newTime.indexOf('1899') !== -1 || !newTime) newTime = '10:00';
  var newDoctor = (data.doctor || '').toString().trim();
  if (newDoctor.toLowerCase().indexOf('consulting specialist') !== -1) newDoctor = '';
  var notes = (data.notes || '').toString().trim();

  if (!aptId || !newDate) {
    return createJsonResponse({ status: 'error', message: 'Missing appointment ID or new date' });
  }

  var rangeData = aptSheet.getDataRange().getValues();
  if (!rangeData || rangeData.length <= 1) {
    return createJsonResponse({ status: 'error', message: 'No appointments in sheet' });
  }

  var headers = rangeData[0];
  var colId = 1, colName = 2, colPhone = 3, colDate = 5, colTime = 6, colDoctor = 7, colStatus = 9, colCal = 10, colNotes = 12;
  for (var c = 0; c < headers.length; c++) {
    var h = (headers[c] || '').toString().toLowerCase();
    if (h.indexOf('appointment id') !== -1 || (h.indexOf('id') !== -1 && h.indexOf('cal') === -1)) colId = c + 1;
    else if (h.indexOf('patient') !== -1 || (h.indexOf('name') !== -1 && h.indexOf('doctor') === -1)) colName = c + 1;
    else if (h.indexOf('phone') !== -1 || h.indexOf('contact') !== -1 || h.indexOf('mobile') !== -1) colPhone = c + 1;
    else if (h.indexOf('date') !== -1 && h.indexOf('created') === -1) colDate = c + 1;
    else if (h.indexOf('time') !== -1) colTime = c + 1;
    else if (h.indexOf('doctor') !== -1 || h.indexOf('dentist') !== -1) colDoctor = c + 1;
    else if (h.indexOf('status') !== -1) colStatus = c + 1;
    else if (h.indexOf('cal') !== -1 || h.indexOf('event') !== -1) colCal = c + 1;
    else if (h.indexOf('note') !== -1) colNotes = c + 1;
  }

  var foundRow = -1;
  var patientName = '';
  var patientPhone = (data.phone || data.patientPhone || '').toString().trim();
  var calEventId = '';

  for (var i = 1; i < rangeData.length; i++) {
    var rowId = formatCellValue(rangeData[i][colId - 1]);
    if (rowId === aptId || (aptId && rowId && (rowId.indexOf(aptId) !== -1 || aptId.indexOf(rowId) !== -1))) {
      foundRow = i + 1;
      patientName = formatCellValue(rangeData[i][colName - 1]);
      if (!patientPhone && colPhone - 1 < rangeData[i].length) {
        patientPhone = formatCellValue(rangeData[i][colPhone - 1]);
      }
      calEventId = (colCal - 1 < rangeData[i].length) ? formatCellValue(rangeData[i][colCal - 1]) : '';
      break;
    }
  }

  if (foundRow === -1) {
    return createJsonResponse({ status: 'error', message: 'Appointment ' + aptId + ' not found in sheet' });
  }

  // Update date, time, doctor, status, notes
  aptSheet.getRange(foundRow, colDate).setValue("'" + newDate);
  if (newTime) aptSheet.getRange(foundRow, colTime).setValue("'" + newTime);
  aptSheet.getRange(foundRow, colDoctor).setValue(newDoctor);
  aptSheet.getRange(foundRow, colStatus).setValue("Rescheduled");
  if (notes) aptSheet.getRange(foundRow, colNotes).setValue(notes);

  // Update Google Calendar Event Time safely
  try {
    var cal = getClinicCalendar();
    if (cal) {
      var dateParts = newDate.split('-');
      var timeParts = newTime.split(':');
      var hour = timeParts.length > 0 ? parseInt(timeParts[0], 10) : 10;
      var min = timeParts.length > 1 ? parseInt(timeParts[1], 10) : 0;
      var startDateTime = new Date(parseInt(dateParts[0], 10), parseInt(dateParts[1], 10) - 1, parseInt(dateParts[2], 10), hour, min);
      var endDateTime = new Date(startDateTime.getTime() + 30 * 60 * 1000);
      var eventTitle = "Dental Appointment (Rescheduled): " + patientName + (newDoctor ? " (" + newDoctor + ")" : "");
      var eventDesc = "Patient: " + patientName + "\n" +
                      (patientPhone ? "Phone: " + patientPhone + "\n" : "") +
                      (newDoctor ? "Doctor: " + newDoctor + "\n" : "") +
                      (notes ? "Notes: " + notes + "\n" : "") +
                      "Appointment ID: " + aptId;

      var event = null;
      if (calEventId) {
        try {
          event = cal.getEventById(calEventId);
        } catch (getEvErr) {}
      }

      if (event) {
        event.setTime(startDateTime, endDateTime);
        event.setTitle(eventTitle);
        event.setDescription(eventDesc);
        try {
          event.removeAllReminders();
          event.addPopupReminder(15);
          event.addPopupReminder(60);
          event.addEmailReminder(1440);
          event.addEmailReminder(120);
        } catch (remErr) {}
      } else {
        var newEvent = createCalendarEventSafe(cal, eventTitle, startDateTime, endDateTime, eventDesc, '');
        aptSheet.getRange(foundRow, colCal).setValue(newEvent.getId());
      }
    }
  } catch (calErr) {
    Logger.log("Calendar reschedule notice: " + calErr.toString());
  }

  // Send reschedule notification email safely
  try {
    sendAppointmentNotificationEmail({
      appointmentId: aptId,
      patientName: patientName,
      phone: patientPhone,
      date: newDate,
      time: newTime,
      doctor: newDoctor,
      reason: 'Rescheduled Appointment',
      notes: notes
    }, true);
  } catch (mailErr) {
    Logger.log("Reschedule email notice: " + mailErr.toString());
  }

  return createJsonResponse({
    status: 'success',
    message: 'Appointment successfully rescheduled to ' + newDate + ' at ' + newTime + ' and synced with Google Calendar (' + CLINIC_NOTIFICATION_EMAIL + ')!'
  });
}

/**
 * Handle Appointment Status Update (Completed / Cancelled)
 */
function handleUpdateAppointmentStatus(ss, data) {
  var aptSheet = getAppointmentsSheet(ss);
  var aptId = (data.appointmentId || '').toString().trim();
  var newStatus = (data.status || 'Completed').toString().trim();

  if (!aptId) {
    return createJsonResponse({ status: 'error', message: 'Missing appointment ID' });
  }

  var rangeData = aptSheet.getDataRange().getValues();
  if (!rangeData || rangeData.length <= 1) {
    return createJsonResponse({ status: 'error', message: 'No appointments in sheet' });
  }

  var headers = rangeData[0];
  var colId = 1, colStatus = 9;
  for (var c = 0; c < headers.length; c++) {
    var h = (headers[c] || '').toString().toLowerCase();
    if (h.indexOf('appointment id') !== -1 || (h.indexOf('id') !== -1 && h.indexOf('cal') === -1)) colId = c + 1;
    else if (h.indexOf('status') !== -1) colStatus = c + 1;
  }

  var found = false;
  for (var i = 1; i < rangeData.length; i++) {
    var rowId = formatCellValue(rangeData[i][colId - 1]);
    if (rowId === aptId || (aptId && rowId && (rowId.indexOf(aptId) !== -1 || aptId.indexOf(rowId) !== -1))) {
      aptSheet.getRange(i + 1, colStatus).setValue(newStatus);
      found = true;
      break;
    }
  }

  if (found) {
    return createJsonResponse({ status: 'success', message: 'Appointment status updated to ' + newStatus });
  }
  return createJsonResponse({ status: 'error', message: 'Appointment not found' });
}

/**
 * Saves HTML invoice file to "Patient Invoices" folder in Google Drive
 */
function saveInvoiceToGoogleDrive(inv) {
  try {
    var folderName = "Patient Invoices";
    var folders = DriveApp.getFoldersByName(folderName);
    var folder;
    if (folders.hasNext()) {
      folder = folders.next();
    } else {
      folder = DriveApp.createFolder(folderName);
    }

    var cleanName = (inv.fullName || "Patient").replace(/[^a-zA-Z0-9]/g, "_");
    var fileName = "Invoice_" + inv.invoiceNo + "_" + cleanName + ".html";

    var htmlContent = buildInvoiceHtml(inv);
    var file = folder.createFile(fileName, htmlContent, MimeType.HTML);

    try {
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    } catch (permErr) {}

    return {
      fileId: file.getId(),
      fileUrl: file.getUrl(),
      downloadUrl: "https://drive.google.com/uc?export=download&id=" + file.getId()
    };
  } catch (err) {
    Logger.log("Drive error: " + err.toString());
    return { fileId: "", fileUrl: "", downloadUrl: "" };
  }
}

/**
 * Builds printable standalone HTML invoice template
 */
function buildInvoiceHtml(inv) {
  var ageStr = inv.age ? (inv.age + ' yrs') : (inv.dob || 'N/A');
  var addrStr = inv.address || inv.email || 'N/A';
  var opStr = inv.opNumber || 'N/A';

  return '<!DOCTYPE html>' +
    '<html><head><meta charset="UTF-8"><title>Invoice ' + inv.invoiceNo + '</title>' +
    '<style>' +
    'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; padding: 25px; color: #1e293b; background: #fff; margin: 0; }' +
    '.invoice-box { max-width: 720px; margin: auto; border: 2px solid #000; padding: 24px; border-radius: 8px; }' +
    '.hospital-header { text-align: center; border-bottom: 2px solid #000; padding-bottom: 12px; margin-bottom: 16px; }' +
    '.hospital-name { font-size: 20px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; margin: 0; color: #000; }' +
    '.hospital-sub { font-size: 12px; font-weight: 600; color: #222; margin-top: 4px; }' +
    '.hospital-contact { font-size: 11px; color: #444; margin-top: 3px; }' +
    '.header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 1.5px solid #000; padding-bottom: 10px; margin-bottom: 18px; }' +
    '.title { font-size: 17px; font-weight: 700; color: #000; }' +
    '.subtitle { font-size: 12px; color: #555; margin-top: 3px; }' +
    '.inv-meta { text-align: right; }' +
    '.inv-meta h2 { margin: 0; font-size: 16px; color: #000; font-weight: bold; }' +
    '.inv-meta p { margin: 3px 0 0; font-size: 12px; color: #333; }' +
    '.patient-info { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 20px; background: #fff; border: 1.5px solid #000; padding: 12px; border-radius: 4px; }' +
    '.info-item { font-size: 12px; color: #000; }' +
    '.info-label { font-weight: bold; }' +
    'table { width: 100%; border-collapse: collapse; margin-bottom: 20px; border: 1px solid #000; }' +
    'th { background: #f2f2f2; color: #000; text-align: left; padding: 8px 10px; font-size: 12px; font-weight: bold; border: 1px solid #000; }' +
    'td { padding: 8px 10px; border: 1px solid #000; font-size: 12px; color: #000; }' +
    'td.amount { text-align: right; font-weight: 600; }' +
    'th.amount { text-align: right; }' +
    '.total-row td { font-size: 14px; font-weight: 800; color: #000; border-top: 2px solid #000; border-bottom: 3px double #000; background: #fafafa; }' +
    '.signatures { display: flex; justify-content: space-between; margin-top: 35px; margin-bottom: 15px; padding: 0 10px; }' +
    '.sign-col { text-align: center; width: 220px; font-size: 11px; font-weight: bold; text-transform: uppercase; }' +
    '.sign-line { height: 40px; border-bottom: 1.5px solid #000; margin-bottom: 4px; }' +
    '.footer { text-align: center; margin-top: 15px; font-size: 11px; color: #444; border-top: 1px solid #000; padding-top: 8px; font-style: italic; }' +
    '.no-print-bar { text-align: right; margin-bottom: 12px; }' +
    '.btn-print { background: #0d9488; color: #fff; border: none; padding: 7px 15px; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; }' +
    '@media print { .no-print-bar { display: none; } body { padding: 0; } .invoice-box { border: none; } }' +
    '</style></head><body>' +
    '<div class="invoice-box">' +
    '<div class="no-print-bar"><button class="btn-print" onclick="window.print()">🖨️ Print Invoice</button></div>' +
    '<div class="hospital-header">' +
    '  <h1 class="hospital-name">MANJALY MULTI SPECIALITY DENTAL CARE</h1>' +
    '  <div class="hospital-sub">Valakkavu, above MJ supermarket, Thrissur, Kerala 680751</div>' +
    '  <div class="hospital-contact">Phone: +91 6238497517 • Email: manjalymdc@gmail.com</div>' +
    '</div>' +
    '<div class="header">' +
    '  <div><div class="title">Clinical Patient Invoice</div><div class="subtitle">Official Medical Consultation & Services Receipt</div></div>' +
    '  <div class="inv-meta"><h2>' + inv.invoiceNo + '</h2><p>Date: ' + inv.timestamp + '</p><p><strong>PAID (' + (inv.paymentMode || 'Cash') + ')</strong></p></div>' +
    '</div>' +
    '<div class="patient-info">' +
    '  <div class="info-item"><span class="info-label">Patient Name: </span>' + inv.fullName + '</div>' +
    '  <div class="info-item"><span class="info-label">Phone: </span>' + inv.phone + '</div>' +
    '  <div class="info-item"><span class="info-label">Age: </span>' + ageStr + '</div>' +
    '  <div class="info-item"><span class="info-label">OP Number: </span>' + opStr + '</div>' +
    '  <div class="info-item"><span class="info-label">Doctor Consulted: </span>' + (inv.doctorConsulted || 'Attending Doctor') + '</div>' +
    '  <div class="info-item"><span class="info-label">Payment Mode: </span>' + (inv.paymentMode || 'Cash') + '</div>' +
    '  <div class="info-item" style="grid-column: span 2;"><span class="info-label">Address of Patient: </span>' + addrStr + '</div>' +
    '</div>' +
    '<table>' +
    '  <thead><tr><th>#</th><th>Description</th><th class="amount">Amount</th></tr></thead>' +
    '  <tbody>' +
    '    <tr><td>1</td><td>Doctor Consultation Charge</td><td class="amount">' + parseFloat(inv.consultationCharge).toFixed(2) + '</td></tr>' +
    '    <tr><td>2</td><td>X-Ray Examination Charge</td><td class="amount">' + parseFloat(inv.xrayCharge).toFixed(2) + '</td></tr>' +
    '    <tr><td>3</td><td>Pharmacy / Medicines Charge</td><td class="amount">' + parseFloat(inv.pharmacyCharge).toFixed(2) + '</td></tr>' +
    '    <tr class="total-row"><td colspan="2" style="text-align:right;">Total Amount Due:</td><td class="amount">' + parseFloat(inv.totalAmount).toFixed(2) + '</td></tr>' +
    '  </tbody>' +
    '</table>' +
    '<div class="signatures">' +
    '  <div class="sign-col"><div class="sign-line" style="height: 20px;"></div>Doctor\'s Sign & Seal</div>' +
    '  <div class="sign-col"><div class="sign-line" style="height: 20px;"></div>Hospital Seal</div>' +
    '</div>' +
    '<div class="footer"><p>* Computer generated clinical invoice issued by Manjaly Multi Speciality Dental Care. Valid for all official and claim purposes.</p></div>' +
    '</div></body></html>';
}

function formatCellValue(val) {
  if (val === null || val === undefined) return '';
  if (val instanceof Date) {
    if (val.getFullYear() <= 1900) {
      var h = ('0' + val.getHours()).slice(-2);
      var min = ('0' + val.getMinutes()).slice(-2);
      return h + ':' + min;
    }
    var y = val.getFullYear();
    var m = ('0' + (val.getMonth() + 1)).slice(-2);
    var d = ('0' + val.getDate()).slice(-2);
    return y + '-' + m + '-' + d;
  }
  var s = val.toString().trim();
  if (s.charAt(0) === "'") s = s.substring(1).trim();
  return s;
}

function formatTimeCellValue(val) {
  if (val === null || val === undefined) return '10:00';
  if (val instanceof Date) {
    var h = ('0' + val.getHours()).slice(-2);
    var min = ('0' + val.getMinutes()).slice(-2);
    return h + ':' + min;
  }
  var str = val.toString().trim();
  if (str.charAt(0) === "'") str = str.substring(1).trim();
  if (str.indexOf('1899') !== -1 || str === '') return '10:00';
  return str;
}

/**
 * Universal date normalizer: handles Date objects, YYYY-MM-DD, DD-MM-YYYY, etc.
 * Avoids any timezone backward shift!
 */
function normalizeDate(val) {
  if (!val) return '';
  if (val instanceof Date) {
    var y = val.getFullYear();
    var m = ('0' + (val.getMonth() + 1)).slice(-2);
    var d = ('0' + val.getDate()).slice(-2);
    return y + '-' + m + '-' + d;
  }
  var str = val.toString().trim();
  if (str.charAt(0) === "'") str = str.substring(1).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) return str;
  if (/^\d{2}-\d{2}-\d{4}$/.test(str)) {
    var p = str.split('-');
    return p[2] + '-' + p[1] + '-' + p[0];
  }
  if (/^\d{2}\/\d{2}\/\d{4}$/.test(str)) {
    var p2 = str.split('/');
    return p2[2] + '-' + p2[1] + '-' + p2[0];
  }
  if (/^\d{4}\/\d{2}\/\d{2}$/.test(str)) {
    var p3 = str.split('/');
    return p3[0] + '-' + p3[1] + '-' + p3[2];
  }
  var dt = new Date(str);
  if (!isNaN(dt.getTime())) {
    var dy = dt.getFullYear();
    var dm = ('0' + (dt.getMonth() + 1)).slice(-2);
    var dd = ('0' + dt.getDate()).slice(-2);
    return dy + '-' + dm + '-' + dd;
  }
  return str;
}

function extractDigits(str) {
  return (str || '').toString().replace(/\D/g, '');
}

/**
 * Handle GET requests
 */
function doGet(e) {
  try {
    var action = e && e.parameter ? e.parameter.action : '';
    var ss = getSpreadsheet();

    // 1. Get Appointments (Today, Upcoming, Datewise, or History)
    if (action === 'getAppointments') {
      return handleGetAppointments(ss, e.parameter);
    }

    // 2. Search Patient Records & All Past Invoices
    if (action === 'search') {
      return handleSearchPatient(ss, e.parameter);
    }

    // 3. Reschedule Appointment (GET fallback)
    if (action === 'rescheduleAppointment') {
      return handleRescheduleAppointment(ss, e.parameter);
    }

    // 4. Update Appointment Status (GET fallback)
    if (action === 'updateAppointmentStatus') {
      return handleUpdateAppointmentStatus(ss, e.parameter);
    }

    // 5. Sync Google Calendar (GET fallback)
    if (action === 'syncCalendar') {
      return handleSyncCalendar(ss);
    }

    // 6. Get Registered Patients Directory
    if (action === 'getPatients' || action === 'getAllPatients') {
      return handleGetPatients(ss);
    }

    // 7. Get Pharmacy Inventory Stock
    if (action === 'getPharmacyStock') {
      return handleGetPharmacyStock(ss);
    }

    // 8. Get Accounts & Financial Revenue
    if (action === 'getAccounts') {
      return handleGetAccounts(ss, e.parameter);
    }

    return createJsonResponse({ status: 'error', message: 'Invalid action parameter' });

  } catch (error) {
    return createJsonResponse({ status: 'error', message: error.toString() });
  }
}

/**
 * Fetch Appointments (Today, Upcoming, by Date, or All/Search)
 */
function handleGetAppointments(ss, params) {
  var aptSheet = getAppointmentsSheet(ss);
  var data = aptSheet.getDataRange().getValues();

  if (!data || data.length <= 1) {
    return createJsonResponse({ status: 'success', data: [] });
  }

  var filterType = (params.type || 'all').toString().toLowerCase();
  var filterDate = normalizeDate(params.date || '');
  var query = (params.query || '').toString().toLowerCase().trim();
  var queryDigits = extractDigits(query);

  var now = new Date();
  var todayStr = now.getFullYear() + '-' + ('0' + (now.getMonth() + 1)).slice(-2) + '-' + ('0' + now.getDate()).slice(-2);

  var results = [];
  var todayCount = 0;
  var upcomingCount = 0;

  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    if (!row || row.length === 0) continue;

    var aptId = formatCellValue(row[0]);
    var patientName = formatCellValue(row[1]);
    var rawPhone = formatCellValue(row[2]);
    var phoneDigits = extractDigits(rawPhone);
    var email = formatCellValue(row[3]);
    var aptDate = normalizeDate(row[4]);
    var aptTime = formatTimeCellValue(row[5]);
    var doctor = formatCellValue(row[6]);
    if (doctor.toLowerCase().indexOf('consulting specialist') !== -1) doctor = '';
    var reason = formatCellValue(row[7]);
    var status = formatCellValue(row[8]);
    var calEventId = formatCellValue(row[9]);
    var createdAt = formatCellValue(row[10]);
    var notes = formatCellValue(row[11]);

    if (aptDate === todayStr) todayCount++;
    if (aptDate >= todayStr) upcomingCount++;

    var matches = false;

    if (filterType === 'today') {
      if (aptDate === todayStr) matches = true;
    } else if (filterType === 'upcoming') {
      // Upcoming includes today and all future dates!
      if (aptDate >= todayStr) matches = true;
    } else if (filterType === 'date' && filterDate) {
      if (aptDate === filterDate) matches = true;
    } else if (query) {
      if (patientName.toLowerCase().indexOf(query) !== -1) matches = true;
      else if (rawPhone.toLowerCase().indexOf(query) !== -1) matches = true;
      else if (queryDigits.length >= 4 && phoneDigits && phoneDigits.indexOf(queryDigits) !== -1) matches = true;
      else if (doctor.toLowerCase().indexOf(query) !== -1) matches = true;
      else if (aptId.toLowerCase().indexOf(query) !== -1) matches = true;
    } else {
      matches = true; // All
    }

    if (matches) {
      results.push({
        appointmentId: aptId,
        patientName: patientName,
        phone: rawPhone,
        email: email,
        date: aptDate,
        time: aptTime,
        doctor: doctor,
        reason: reason,
        status: status || 'Scheduled',
        calEventId: calEventId,
        createdAt: createdAt,
        notes: notes
      });
    }
  }

  // Sort: upcoming & today by date ascending, history by date descending
  results.sort(function(a, b) {
    var dtA = (a.date + ' ' + a.time);
    var dtB = (b.date + ' ' + b.time);
    if (filterType === 'all' && !query) {
      return dtB.localeCompare(dtA);
    }
    return dtA.localeCompare(dtB);
  });

  return createJsonResponse({ 
    status: 'success', 
    data: results, 
    todayDate: todayStr,
    todayCount: todayCount,
    upcomingCount: upcomingCount 
  });
}

/**
 * Handle Patient Search with both Visit History & All Recorded Invoices
 */
function handleSearchPatient(ss, params) {
  var query = (params.query || '').toString().trim();
  var isWildcard = (!query || query === '*' || query === 'all');

  var visitsSheet = getVisitsSheet(ss);
  var visitData = visitsSheet.getDataRange().getValues();

  var queryLower = query.toLowerCase();
  var queryDigits = extractDigits(query);
  var queryDigits10 = (queryDigits.length === 12 && queryDigits.indexOf('91') === 0) ? queryDigits.slice(2) : queryDigits;
  var visits = [];
  var matchedPhones = {};
  var matchedNames = {};

  if (visitData && visitData.length > 1) {
    // Dynamic header column map
    var headers = visitData[0];
    var headersLower = [];
    for (var c = 0; c < headers.length; c++) {
      headersLower.push((headers[c] || '').toString().toLowerCase().trim());
    }

    var colTimestamp = getHeaderColumnIndex(headersLower, ['time'], [], 0);
    var colName = getHeaderColumnIndex(headersLower, ['full name', 'patient name', 'name'], ['doctor', 'dentist'], 1);
    var colPhone = getHeaderColumnIndex(headersLower, ['phone', 'mobile', 'contact'], [], 2);
    var colEmail = getHeaderColumnIndex(headersLower, ['email', 'mail'], [], 3);
    var colDob = getHeaderColumnIndex(headersLower, ['dob', 'birth', 'age'], [], 4);
    var colGender = getHeaderColumnIndex(headersLower, ['gender', 'sex'], [], 5);
    var colMedical = getHeaderColumnIndex(headersLower, ['medical'], [], 6);
    var colDisease = getHeaderColumnIndex(headersLower, ['disease'], [], 7);
    var colLastVisit = getHeaderColumnIndex(headersLower, ['last visit', 'lastvisit'], [], 8);
    var colDoctor = getHeaderColumnIndex(headersLower, ['doctor', 'consulted', 'dentist'], ['charge', 'fee', 'amount'], 9);
    var colConsult = getHeaderColumnIndex(headersLower, ['consultation charge', 'consult charge', 'consultation fee', 'consult fee', 'consultation', 'consult'], ['doctor', 'dentist', 'specialist'], 10);
    var colXray = getHeaderColumnIndex(headersLower, ['xray', 'x-ray'], [], 11);
    var colPharm = getHeaderColumnIndex(headersLower, ['pharm', 'medicin'], [], 12);
    var colTotal = getHeaderColumnIndex(headersLower, ['total amount', 'total', 'amount'], [], 13);
    var colPayment = getHeaderColumnIndex(headersLower, ['payment', 'mode'], [], 14);
    var colInvoice = getHeaderColumnIndex(headersLower, ['invoice no', 'invoice number', 'invoice'], ['drive', 'url', 'file'], 15);
    var colDrive = getHeaderColumnIndex(headersLower, ['drive', 'url', 'link', 'file'], [], 16);
    var colOp = getHeaderColumnIndex(headersLower, ['op number', 'op no', 'opnum', 'op'], [], -1);

    var getRowVal = function(row, colIdx) {
      if (colIdx >= 0 && colIdx < row.length) {
        return formatCellValue(row[colIdx]);
      }
      return '';
    };

    for (var i = 1; i < visitData.length; i++) {
      var row = visitData[i];
      if (!row || row.length === 0) continue;

      var name = getRowVal(row, colName).toLowerCase();
      var rawPhone = getRowVal(row, colPhone);
      var phoneLower = rawPhone.toLowerCase();
      var phoneDigits = extractDigits(rawPhone);
      var email = getRowVal(row, colEmail).toLowerCase();
      var invNo = getRowVal(row, colInvoice).toLowerCase();
      var docName = getRowVal(row, colDoctor).toLowerCase();
      var opVal = colOp !== -1 ? getRowVal(row, colOp).toLowerCase().trim() : '';

      var matched = isWildcard;
      if (!matched) {
        if (name && name.indexOf(queryLower) !== -1) matched = true;
        else if (phoneLower && phoneLower.indexOf(queryLower) !== -1) matched = true;
        else if (queryDigits.length >= 4 && phoneDigits && (phoneDigits.indexOf(queryDigits) !== -1 || queryDigits.indexOf(phoneDigits) !== -1)) matched = true;
        else if (queryDigits10.length >= 4 && phoneDigits && (phoneDigits.indexOf(queryDigits10) !== -1 || queryDigits10.indexOf(phoneDigits) !== -1)) matched = true;
        else if (opVal && (opVal.indexOf(queryLower) !== -1 || queryLower.indexOf(opVal) !== -1)) matched = true;
        else if (invNo && (invNo.indexOf(queryLower) !== -1 || queryLower.indexOf(invNo) !== -1)) matched = true;
        else if (email && email.indexOf(queryLower) !== -1) matched = true;
        else if (docName && docName.indexOf(queryLower) !== -1) matched = true;
      }

      if (matched) {
        matchedPhones[phoneDigits] = true;
        matchedNames[name] = true;

        var docVal = getRowVal(row, colDoctor);
        if (docVal.toLowerCase().indexOf('consulting specialist') !== -1) docVal = '';

        var consultRaw = getRowVal(row, colConsult);
        var consult = consultRaw;
        if (consultRaw && docVal && consultRaw.toLowerCase().trim() === docVal.toLowerCase().trim()) {
          consult = '0';
        }

        var xray = getRowVal(row, colXray);
        var pharm = getRowVal(row, colPharm);
        var tot = getRowVal(row, colTotal);
        var pMode = getRowVal(row, colPayment) || 'Cash';
        var invNoVal = getRowVal(row, colInvoice);
        var dUrl = getRowVal(row, colDrive);

        visits.push({
          timestamp: getRowVal(row, colTimestamp),
          fullName: getRowVal(row, colName),
          phone: rawPhone,
          email: getRowVal(row, colEmail),
          address: getRowVal(row, colEmail),
          dob: getRowVal(row, colDob),
          age: getRowVal(row, colDob),
          opNumber: colOp !== -1 ? getRowVal(row, colOp) : '',
          gender: getRowVal(row, colGender),
          medicalHistory: getRowVal(row, colMedical),
          diseaseHistory: getRowVal(row, colDisease),
          lastVisitDate: getRowVal(row, colLastVisit),
          doctorConsulted: docVal,
          consultationCharge: consult,
          xrayCharge: xray,
          pharmacyCharge: pharm,
          totalAmount: tot,
          paymentMode: pMode,
          invoiceNo: invNoVal,
          driveFileUrl: dUrl
        });
      }
    }
  }

  // Also query the dedicated "Invoices" sheet to retrieve any invoices previously generated for this patient!
  var invoices = [];
  try {
    var invSheet = ss.getSheetByName("Invoices");
    if (invSheet) {
      var invData = invSheet.getDataRange().getValues();
      if (invData && invData.length > 1) {
        for (var j = 1; j < invData.length; j++) {
          var iRow = invData[j];
          var iNoVal = formatCellValue(iRow[0]);
          var iNoLower = iNoVal.toLowerCase();
          var invPatName = formatCellValue(iRow[2]).toLowerCase();
          var invRawPhone = formatCellValue(iRow[3]);
          var invPhoneDigits = extractDigits(invRawPhone);

          var invMatch = false;
          if (matchedPhones[invPhoneDigits] || matchedNames[invPatName]) {
            invMatch = true;
          } else if (invPatName.indexOf(queryLower) !== -1 || (queryDigits.length >= 4 && (invPhoneDigits.indexOf(queryDigits) !== -1 || queryDigits.indexOf(invPhoneDigits) !== -1)) || (queryDigits10.length >= 4 && (invPhoneDigits.indexOf(queryDigits10) !== -1 || queryDigits10.indexOf(invPhoneDigits) !== -1)) || (iNoLower && (iNoLower.indexOf(queryLower) !== -1 || queryLower.indexOf(iNoLower) !== -1))) {
            invMatch = true;
          }

          if (invMatch) {
            var invDocVal = formatCellValue(iRow[4]);
            if (invDocVal.toLowerCase().indexOf('consulting specialist') !== -1) invDocVal = '';

            invoices.push({
              invoiceNo: iNoVal,
              timestamp: formatCellValue(iRow[1]),
              patientName: formatCellValue(iRow[2]),
              phone: invRawPhone,
              doctorConsulted: invDocVal,
              consultationCharge: formatCellValue(iRow[5]),
              xrayCharge: formatCellValue(iRow[6]),
              pharmacyCharge: formatCellValue(iRow[7]),
              totalAmount: formatCellValue(iRow[8]),
              paymentMode: formatCellValue(iRow[9]),
              driveFileUrl: formatCellValue(iRow[10])
            });
          }
        }
      }
    }
  } catch (invReadErr) {
    Logger.log("Invoices sheet read notice: " + invReadErr.toString());
  }

  visits.reverse();
  invoices.reverse();

  return createJsonResponse({
    status: 'success',
    data: visits,
    invoices: invoices
  });
}

function doOptions(e) {
  return ContentService.createTextOutput("").setMimeType(ContentService.MimeType.TEXT);
}

function createJsonResponse(data) {
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON);
}

/**
 * Synchronize all scheduled appointments with Google Calendar
 * Adds events and sets push reminder notifications (24h, 1h, 15m)
 */
function handleSyncCalendar(ss) {
  var aptSheet = getAppointmentsSheet(ss);
  var data = aptSheet.getDataRange().getValues();
  if (!data || data.length <= 1) {
    return createJsonResponse({ status: 'success', message: 'No appointments to sync.', count: 0 });
  }

  var cal = getClinicCalendar();
  if (!cal) {
    return createJsonResponse({ status: 'error', message: 'Could not access Google Calendar. Please check Calendar permissions for ' + CLINIC_NOTIFICATION_EMAIL });
  }

  var headers = data[0];
  var colId = 1, colName = 2, colPhone = 3, colDate = 5, colTime = 6, colDoctor = 7, colReason = 8, colStatus = 9, colCal = 10, colNotes = 12;
  for (var c = 0; c < headers.length; c++) {
    var h = (headers[c] || '').toString().toLowerCase();
    if (h.indexOf('appointment id') !== -1 || (h.indexOf('id') !== -1 && h.indexOf('cal') === -1)) colId = c + 1;
    else if (h.indexOf('patient') !== -1 || (h.indexOf('name') !== -1 && h.indexOf('doctor') === -1)) colName = c + 1;
    else if (h.indexOf('phone') !== -1) colPhone = c + 1;
    else if (h.indexOf('date') !== -1 && h.indexOf('created') === -1) colDate = c + 1;
    else if (h.indexOf('time') !== -1) colTime = c + 1;
    else if (h.indexOf('doctor') !== -1 || h.indexOf('dentist') !== -1) colDoctor = c + 1;
    else if (h.indexOf('reason') !== -1) colReason = c + 1;
    else if (h.indexOf('status') !== -1) colStatus = c + 1;
    else if (h.indexOf('cal') !== -1 || h.indexOf('event') !== -1) colCal = c + 1;
    else if (h.indexOf('note') !== -1) colNotes = c + 1;
  }

  var syncedCount = 0;
  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    var aptId = formatCellValue(row[colId - 1]);
    var patientName = formatCellValue(row[colName - 1]);
    var phone = formatCellValue(row[colPhone - 1]);
    var dateStr = normalizeDate(row[colDate - 1]);
    var timeStr = formatTimeCellValue(row[colTime - 1]);
    var doctor = formatCellValue(row[colDoctor - 1]);
    if (doctor.toLowerCase().indexOf('consulting specialist') !== -1) doctor = '';
    var reason = formatCellValue(row[colReason - 1]);
    var status = formatCellValue(row[colStatus - 1]);
    var calEventId = (colCal - 1 < row.length) ? formatCellValue(row[colCal - 1]) : '';
    var notes = (colNotes - 1 < row.length) ? formatCellValue(row[colNotes - 1]) : '';

    if (!dateStr || status === 'Cancelled') continue;

    try {
      var dateParts = dateStr.split('-');
      var timeParts = timeStr.split(':');
      var hour = timeParts.length > 0 ? parseInt(timeParts[0], 10) : 10;
      var minute = timeParts.length > 1 ? parseInt(timeParts[1], 10) : 0;
      var startTime = new Date(parseInt(dateParts[0], 10), parseInt(dateParts[1], 10) - 1, parseInt(dateParts[2], 10), hour, minute);
      var endTime = new Date(startTime.getTime() + 30 * 60 * 1000);

      var event = null;
      if (calEventId) {
        try {
          event = cal.getEventById(calEventId);
        } catch (e) {}
      }

      var eventTitle = "Dental Appointment: " + patientName + (doctor ? " (" + doctor + ")" : "");
      var desc = "Patient Name: " + patientName + "\n" +
                 "Phone: " + phone + "\n" +
                 "Doctor: " + (doctor || "Attending Doctor") + "\n" +
                 "Treatment: " + reason + "\n" +
                 (notes ? "Notes: " + notes + "\n" : "") +
                 "Appointment ID: " + aptId;

      if (event) {
        event.setTime(startTime, endTime);
        event.setTitle(eventTitle);
        event.setDescription(desc);
        try {
          event.removeAllReminders();
          event.addPopupReminder(15);
          event.addPopupReminder(60);
          event.addEmailReminder(1440);
          event.addEmailReminder(120);
        } catch (remErr) {}
      } else {
        event = createCalendarEventSafe(cal, eventTitle, startTime, endTime, desc, '');
        aptSheet.getRange(i + 1, colCal).setValue(event.getId());
      }
      syncedCount++;
    } catch (rowCalErr) {
      Logger.log("Row cal error: " + rowCalErr.toString());
    }
  }

  return createJsonResponse({
    status: 'success',
    message: 'Google Calendar (' + CLINIC_NOTIFICATION_EMAIL + ') synchronized successfully! (' + syncedCount + ' appointments verified & active with push notifications)',
    syncedCount: syncedCount
  });
}

/**
 * Retrieve All Registered Patients Directory
 * Groups visits by unique patient phone/name, summarizes visits & invoices
 */
function handleGetPatients(ss) {
  var visitsSheet = getVisitsSheet(ss);
  var visitData = visitsSheet.getDataRange().getValues();

  var patientsMap = {};
  var totalVisits = 0;

  if (visitData && visitData.length > 1) {
    var headers = visitData[0];
    var headersLower = [];
    for (var c = 0; c < headers.length; c++) {
      headersLower.push((headers[c] || '').toString().toLowerCase().trim());
    }

    var colTimestamp = getHeaderColumnIndex(headersLower, ['time'], [], 0);
    var colName = getHeaderColumnIndex(headersLower, ['full name', 'patient name', 'name'], ['doctor', 'dentist'], 1);
    var colPhone = getHeaderColumnIndex(headersLower, ['phone', 'mobile', 'contact'], [], 2);
    var colEmail = getHeaderColumnIndex(headersLower, ['email', 'mail'], [], 3);
    var colDob = getHeaderColumnIndex(headersLower, ['dob', 'birth', 'age'], [], 4);
    var colGender = getHeaderColumnIndex(headersLower, ['gender', 'sex'], [], 5);
    var colMedical = getHeaderColumnIndex(headersLower, ['medical'], [], 6);
    var colDisease = getHeaderColumnIndex(headersLower, ['disease'], [], 7);
    var colLastVisit = getHeaderColumnIndex(headersLower, ['last visit', 'lastvisit'], [], 8);
    var colDoctor = getHeaderColumnIndex(headersLower, ['doctor', 'consulted', 'dentist'], ['charge', 'fee', 'amount'], 9);
    var colConsult = getHeaderColumnIndex(headersLower, ['consultation charge', 'consult charge', 'consultation fee', 'consult fee', 'consultation', 'consult'], ['doctor', 'dentist', 'specialist'], 10);
    var colXray = getHeaderColumnIndex(headersLower, ['xray', 'x-ray'], [], 11);
    var colPharm = getHeaderColumnIndex(headersLower, ['pharm', 'medicin'], [], 12);
    var colTotal = getHeaderColumnIndex(headersLower, ['total amount', 'total', 'amount'], [], 13);
    var colPayment = getHeaderColumnIndex(headersLower, ['payment', 'mode'], [], 14);
    var colInvoice = getHeaderColumnIndex(headersLower, ['invoice no', 'invoice number', 'invoice'], ['drive', 'url', 'file'], 15);
    var colDrive = getHeaderColumnIndex(headersLower, ['drive', 'url', 'link', 'file'], [], 16);
    var colOp = getHeaderColumnIndex(headersLower, ['op number', 'op no', 'opnum', 'op'], [], -1);

    var getRowVal = function(row, colIdx) {
      if (colIdx >= 0 && colIdx < row.length) return formatCellValue(row[colIdx]);
      return '';
    };

    for (var i = 1; i < visitData.length; i++) {
      var row = visitData[i];
      if (!row || row.length === 0) continue;

      var rawName = getRowVal(row, colName).trim();
      var rawPhone = getRowVal(row, colPhone).trim();
      var rawDob = getRowVal(row, colDob).trim();
      if (!rawName && !rawPhone) continue;

      totalVisits++;
      var phoneDigits = extractDigits(rawPhone);
      var cleanName = rawName.toLowerCase().replace(/\s+/g, ' ');
      var normDob = normalizeDate(rawDob);

      // Identity Rule: Same phone number, name, and date of birth is the SAME PERSON
      var existingKey = null;
      for (var k in patientsMap) {
        var p = patientsMap[k];
        var pName = (p.fullName || '').toLowerCase().replace(/\s+/g, ' ').trim();
        var pDigits = extractDigits(p.phone);
        var pDob = normalizeDate(p.dob);

        var nameMatch = cleanName === pName;
        var phoneMatch = phoneDigits === pDigits;

        if (nameMatch && phoneMatch) {
          if (normDob && pDob) {
            if (normDob === pDob) {
              existingKey = k;
              break;
            }
          } else {
            // One or both DOBs empty: treat as same person and backfill DOB
            existingKey = k;
            if (!p.dob && rawDob) p.dob = rawDob;
            break;
          }
        }
      }

      var patientKey = existingKey || (cleanName ? (cleanName + (phoneDigits ? ('_' + phoneDigits) : '') + (normDob ? ('_' + normDob) : '')) : (phoneDigits ? ('phone_' + phoneDigits) : ('pt_' + i)));

      var doc = getRowVal(row, colDoctor);
      if (doc.toLowerCase().indexOf('consulting specialist') !== -1) doc = '';

      var consultRaw = getRowVal(row, colConsult);
      var consult = parseFloat(consultRaw) || 0;
      if (consultRaw && doc && consultRaw.toLowerCase().trim() === doc.toLowerCase().trim()) {
        consult = 0;
      }
      var xray = parseFloat(getRowVal(row, colXray)) || 0;
      var pharm = parseFloat(getRowVal(row, colPharm)) || 0;
      var tot = parseFloat(getRowVal(row, colTotal)) || (consult + xray + pharm);

      var visitObj = {
        timestamp: getRowVal(row, colTimestamp),
        doctorConsulted: doc,
        medicalHistory: getRowVal(row, colMedical),
        diseaseHistory: getRowVal(row, colDisease),
        lastVisitDate: getRowVal(row, colLastVisit),
        consultationCharge: consult,
        xrayCharge: xray,
        pharmacyCharge: pharm,
        totalAmount: tot,
        paymentMode: getRowVal(row, colPayment) || 'Cash',
        invoiceNo: getRowVal(row, colInvoice),
        opNumber: colOp !== -1 ? getRowVal(row, colOp) : '',
        driveFileUrl: getRowVal(row, colDrive)
      };

      if (!patientsMap[patientKey]) {
        patientsMap[patientKey] = {
          fullName: rawName,
          phone: rawPhone,
          email: getRowVal(row, colEmail),
          address: getRowVal(row, colEmail),
          dob: getRowVal(row, colDob),
          age: getRowVal(row, colDob),
          opNumber: colOp !== -1 ? getRowVal(row, colOp) : '',
          gender: getRowVal(row, colGender) || 'Not Specified',
          doctorConsulted: doc,
          medicalHistory: getRowVal(row, colMedical),
          diseaseHistory: getRowVal(row, colDisease),
          latestVisit: visitObj.timestamp || getRowVal(row, colLastVisit),
          firstVisit: visitObj.timestamp,
          visitsCount: 1,
          totalBilled: tot,
          visits: [visitObj],
          invoices: []
        };
      } else {
        var p = patientsMap[patientKey];
        p.visitsCount++;
        p.totalBilled += tot;
        if (!p.email && getRowVal(row, colEmail)) p.email = getRowVal(row, colEmail);
        if (!p.dob && getRowVal(row, colDob)) p.dob = getRowVal(row, colDob);
        if (doc) p.doctorConsulted = doc;
        p.visits.push(visitObj);
      }
    }
  }

  // Cross-reference Invoices sheet
  var totalInvoices = 0;
  try {
    var invSheet = ss.getSheetByName("Invoices");
    if (invSheet) {
      var invData = invSheet.getDataRange().getValues();
      if (invData && invData.length > 1) {
        for (var j = 1; j < invData.length; j++) {
          var iRow = invData[j];
          var iNo = formatCellValue(iRow[0]);
          var iTime = formatCellValue(iRow[1]);
          var iName = formatCellValue(iRow[2]);
          var iPhone = formatCellValue(iRow[3]);
          var iDoc = formatCellValue(iRow[4]);
          if (iDoc.toLowerCase().indexOf('consulting specialist') !== -1) iDoc = '';
          var iTot = parseFloat(formatCellValue(iRow[8])) || 0;
          var iDrive = formatCellValue(iRow[10]);

          totalInvoices++;
          var iDigits = extractDigits(iPhone);
          var invCleanName = iName.toLowerCase().replace(/\s+/g, ' ').trim();
          var invKey = invCleanName ? (invCleanName + (iDigits ? ('_' + iDigits) : '')) : (iDigits ? ('phone_' + iDigits) : '');

          var invObj = {
            invoiceNo: iNo,
            timestamp: iTime,
            doctorConsulted: iDoc,
            totalAmount: iTot,
            driveFileUrl: iDrive
          };

          if (invKey && patientsMap[invKey]) {
            patientsMap[invKey].invoices.push(invObj);
          } else {
            for (var pK in patientsMap) {
              if ((iDigits && extractDigits(patientsMap[pK].phone) === iDigits) || (invCleanName && patientsMap[pK].fullName.toLowerCase().trim() === invCleanName)) {
                patientsMap[pK].invoices.push(invObj);
                break;
              }
            }
          }
        }
      }
    }
  } catch (invErr) {
    Logger.log("Invoices read error: " + invErr.toString());
  }

  var list = [];
  for (var k in patientsMap) {
    list.push(patientsMap[k]);
  }

  // Sort by latest visit date descending
  list.sort(function(a, b) {
    return (b.latestVisit || '').localeCompare(a.latestVisit || '');
  });

  return createJsonResponse({
    status: 'success',
    data: list,
    totalPatients: list.length,
    totalVisits: totalVisits,
    totalInvoices: totalInvoices
  });
}

/**
 * =========================================================================
 * PHARMACY & INVENTORY STOCK MANAGEMENT
 * =========================================================================
 */

function getPharmacySheet(ss) {
  var sheet = ss.getSheetByName("Pharmacy_Stock");
  var headers = [
    'Item ID', 
    'Item Name', 
    'Category', 
    'Batch No', 
    'Expiry Date', 
    'Unit Price', 
    'Quantity', 
    'Min Threshold', 
    'Supplier', 
    'Last Updated'
  ];

  if (!sheet) {
    sheet = ss.insertSheet("Pharmacy_Stock");
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#0f766e').setFontColor('#ffffff');
    sheet.setFrozenRows(1);

    // Initial default stock items for a dental clinic
    var defaultItems = [
      ['MED-1001', 'Amoxicillin 500mg (Cap)', 'Antibiotics', 'AMX-2026-A1', '2027-06-30', 8.50, 250, 50, 'Apex Pharma', 'Initial Stock'],
      ['MED-1002', 'Aceclofenac + Paracetamol (Tab)', 'Analgesics', 'ACP-2026-B4', '2027-10-15', 6.00, 320, 60, 'Sun Health', 'Initial Stock'],
      ['MED-1003', 'Metronidazole 400mg (Tab)', 'Antibiotics', 'MTZ-2026-09', '2026-12-31', 4.50, 180, 40, 'Cipla Med', 'Initial Stock'],
      ['MED-1004', 'Lidocaine 2% + Adrenaline (Vial)', 'Anesthesia', 'LID-2025-C8', '2027-04-20', 45.00, 75, 20, 'Neon Labs', 'Initial Stock'],
      ['MED-1005', 'Chlorhexidine 0.2% Mouthwash 150ml', 'Antiseptic Oral', 'CHX-2026-D1', '2027-08-30', 110.00, 45, 15, 'ICPA Health', 'Initial Stock'],
      ['MED-1006', 'Dental Composite Resin Shade A2', 'Filling Material', 'RES-2025-X2', '2027-11-20', 850.00, 18, 5, '3M Dental', 'Initial Stock'],
      ['MED-1007', 'Eugenol Liquid 15ml', 'Sedative Dressing', 'EUG-2025-E4', '2028-02-15', 120.00, 22, 5, 'Prevest DenPro', 'Initial Stock'],
      ['MED-1008', 'Cotton Rolls Pack 500s', 'Consumables', 'COT-2026-01', '2029-01-01', 160.00, 35, 10, 'HealthCare Supplies', 'Initial Stock'],
      ['MED-1009', 'Dental Disposable Needles 30G', 'Surgical Consumables', 'NDL-2026-N9', '2028-06-30', 5.00, 400, 100, 'Unolok Med', 'Initial Stock'],
      ['MED-1010', 'Orthodontic Relief Wax Pack', 'Oral Hygiene', 'WAX-2026-W3', '2028-12-31', 40.00, 60, 15, 'Ortho Care', 'Initial Stock']
    ];

    for (var r = 0; r < defaultItems.length; r++) {
      sheet.appendRow(defaultItems[r]);
    }
  }

  return sheet;
}

function handleGetPharmacyStock(ss) {
  var sheet = getPharmacySheet(ss);
  var data = sheet.getDataRange().getValues();
  var items = [];

  var totalStockValue = 0;
  var lowStockCount = 0;
  var expiringCount = 0;

  var now = new Date();
  var ninetyDaysLater = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);

  if (data && data.length > 1) {
    for (var i = 1; i < data.length; i++) {
      var row = data[i];
      if (!row || row.length === 0 || !row[1]) continue;

      var itemId = formatCellValue(row[0]) || ('MED-' + (1000 + i));
      var itemName = formatCellValue(row[1]);
      var category = formatCellValue(row[2]) || 'General Dental';
      var batchNo = formatCellValue(row[3]) || 'N/A';
      var expiryDate = normalizeDate(row[4]);
      var unitPrice = parseFloat(row[5]) || 0;
      var quantity = parseInt(row[6], 10) || 0;
      var minThreshold = parseInt(row[7], 10) || 10;
      var supplier = formatCellValue(row[8]) || 'General';
      var lastUpdated = formatCellValue(row[9]);

      var itemVal = unitPrice * quantity;
      totalStockValue += itemVal;

      if (quantity <= minThreshold) {
        lowStockCount++;
      }

      if (expiryDate) {
        var expObj = new Date(expiryDate);
        if (!isNaN(expObj.getTime()) && expObj <= ninetyDaysLater) {
          expiringCount++;
        }
      }

      items.push({
        rowIndex: i + 1,
        itemId: itemId,
        itemName: itemName,
        category: category,
        batchNo: batchNo,
        expiryDate: expiryDate,
        unitPrice: unitPrice,
        quantity: quantity,
        minThreshold: minThreshold,
        supplier: supplier,
        lastUpdated: lastUpdated,
        totalValue: itemVal,
        isLowStock: quantity <= minThreshold,
        isExpired: expiryDate ? (new Date(expiryDate) < now) : false
      });
    }
  }

  return createJsonResponse({
    status: 'success',
    data: items,
    totalItems: items.length,
    lowStockCount: lowStockCount,
    expiringCount: expiringCount,
    totalStockValue: totalStockValue
  });
}

function handleAddPharmacyItem(ss, data) {
  var sheet = getPharmacySheet(ss);
  var itemName = (data.itemName || '').toString().trim();
  if (!itemName) {
    return createJsonResponse({ status: 'error', message: 'Item / Medicine name is required.' });
  }

  var lastRow = sheet.getLastRow();
  var itemId = (data.itemId || ('MED-' + (1000 + lastRow))).toString().trim();
  var category = (data.category || 'General').toString().trim();
  var batchNo = (data.batchNo || 'BT-' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd')).toString().trim();
  var expiryDate = normalizeDate(data.expiryDate || '');
  var unitPrice = parseFloat(data.unitPrice) || 0;
  var quantity = parseInt(data.quantity, 10) || 0;
  var minThreshold = parseInt(data.minThreshold, 10) || 10;
  var supplier = (data.supplier || '').toString().trim();
  var lastUpdated = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm');

  sheet.appendRow([
    itemId,
    itemName,
    category,
    batchNo,
    expiryDate,
    unitPrice.toFixed(2),
    quantity,
    minThreshold,
    supplier,
    lastUpdated
  ]);

  return createJsonResponse({
    status: 'success',
    message: 'Medicine / stock item "' + itemName + '" added successfully!',
    item: {
      itemId: itemId,
      itemName: itemName,
      category: category,
      batchNo: batchNo,
      expiryDate: expiryDate,
      unitPrice: unitPrice,
      quantity: quantity,
      minThreshold: minThreshold,
      supplier: supplier,
      lastUpdated: lastUpdated
    }
  });
}

function handleUpdatePharmacyStock(ss, data) {
  var sheet = getPharmacySheet(ss);
  var rows = sheet.getDataRange().getValues();
  var targetId = (data.itemId || '').toString().trim();
  var targetName = (data.itemName || '').toString().toLowerCase().trim();

  var foundRowIndex = -1;
  for (var i = 1; i < rows.length; i++) {
    var rowId = formatCellValue(rows[i][0]).trim();
    var rowName = formatCellValue(rows[i][1]).toLowerCase().trim();
    if ((targetId && rowId === targetId) || (targetName && rowName === targetName)) {
      foundRowIndex = i + 1;
      break;
    }
  }

  if (foundRowIndex === -1) {
    return createJsonResponse({ status: 'error', message: 'Medicine item not found in stock.' });
  }

  var currentQty = parseInt(sheet.getRange(foundRowIndex, 7).getValue(), 10) || 0;
  var newQty = currentQty;

  if (data.hasOwnProperty('changeQty')) {
    var delta = parseInt(data.changeQty, 10) || 0;
    newQty = Math.max(0, currentQty + delta);
    sheet.getRange(foundRowIndex, 7).setValue(newQty);
  } else if (data.hasOwnProperty('quantity')) {
    newQty = Math.max(0, parseInt(data.quantity, 10) || 0);
    sheet.getRange(foundRowIndex, 7).setValue(newQty);
  }

  if (data.unitPrice !== undefined && data.unitPrice !== '') {
    sheet.getRange(foundRowIndex, 6).setValue((parseFloat(data.unitPrice) || 0).toFixed(2));
  }
  if (data.batchNo) {
    sheet.getRange(foundRowIndex, 4).setValue(data.batchNo.toString().trim());
  }
  if (data.expiryDate) {
    sheet.getRange(foundRowIndex, 5).setValue(normalizeDate(data.expiryDate));
  }
  if (data.category) {
    sheet.getRange(foundRowIndex, 3).setValue(data.category.toString().trim());
  }
  if (data.minThreshold !== undefined && data.minThreshold !== '') {
    sheet.getRange(foundRowIndex, 8).setValue(parseInt(data.minThreshold, 10) || 10);
  }

  var updatedTime = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm');
  sheet.getRange(foundRowIndex, 10).setValue(updatedTime);

  return createJsonResponse({
    status: 'success',
    message: 'Stock updated successfully. Current quantity: ' + newQty,
    newQuantity: newQty
  });
}

/**
 * =========================================================================
 * ACCOUNTS & REVENUE ANALYTICS (DAILY, WEEKLY, MONTHLY BY CATEGORY)
 * =========================================================================
 */

function handleGetAccounts(ss, params) {
  var visitsSheet = getVisitsSheet(ss);
  var visitData = visitsSheet.getDataRange().getValues();

  var now = new Date();
  var todayStr = Utilities.formatDate(now, Session.getScriptTimeZone(), "yyyy-MM-dd");

  // Determine current week range (Monday through Sunday)
  var dayOfWeek = now.getDay(); // 0 is Sun, 1 is Mon...
  var diffToMonday = (dayOfWeek === 0 ? -6 : 1) - dayOfWeek;
  var monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() + diffToMonday);
  var mondayStr = Utilities.formatDate(monday, Session.getScriptTimeZone(), "yyyy-MM-dd");

  // Current month (YYYY-MM-01)
  var monthPrefix = Utilities.formatDate(now, Session.getScriptTimeZone(), "yyyy-MM");

  var daily = { total: 0, consultation: 0, xray: 0, pharmacy: 0, count: 0 };
  var weekly = { total: 0, consultation: 0, xray: 0, pharmacy: 0, count: 0 };
  var monthly = { total: 0, consultation: 0, xray: 0, pharmacy: 0, count: 0 };
  var allTime = { total: 0, consultation: 0, xray: 0, pharmacy: 0, count: 0 };

  var paymentModes = {
    Cash: 0,
    UPI: 0,
    Card: 0,
    Pending: 0,
    Other: 0
  };

  var transactions = [];

  if (visitData && visitData.length > 1) {
    var headers = visitData[0];
    var headersLower = [];
    for (var c = 0; c < headers.length; c++) {
      headersLower.push((headers[c] || '').toString().toLowerCase().trim());
    }

    var colTimestamp = getHeaderColumnIndex(headersLower, ['time'], [], 0);
    var colName = getHeaderColumnIndex(headersLower, ['full name', 'patient name', 'name'], ['doctor', 'dentist'], 1);
    var colPhone = getHeaderColumnIndex(headersLower, ['phone', 'mobile'], [], 2);
    var colDoctor = getHeaderColumnIndex(headersLower, ['doctor', 'consulted'], [], 9);
    var colConsult = getHeaderColumnIndex(headersLower, ['consultation charge', 'consult charge', 'consult fee'], ['doctor'], 10);
    var colXray = getHeaderColumnIndex(headersLower, ['xray', 'x-ray'], [], 11);
    var colPharm = getHeaderColumnIndex(headersLower, ['pharm', 'medicin'], [], 12);
    var colTotal = getHeaderColumnIndex(headersLower, ['total amount', 'total'], [], 13);
    var colPayment = getHeaderColumnIndex(headersLower, ['payment', 'mode'], [], 14);
    var colInvoice = getHeaderColumnIndex(headersLower, ['invoice no', 'invoice'], ['drive', 'url'], 15);

    var getRowVal = function(row, colIdx) {
      if (colIdx >= 0 && colIdx < row.length) return formatCellValue(row[colIdx]);
      return '';
    };

    for (var i = 1; i < visitData.length; i++) {
      var row = visitData[i];
      if (!row || row.length === 0) continue;

      var ts = getRowVal(row, colTimestamp);
      var rowDateStr = normalizeDate(ts);
      var pName = getRowVal(row, colName) || 'Patient';
      var phone = getRowVal(row, colPhone);
      var doc = getRowVal(row, colDoctor);
      if (doc.toLowerCase().indexOf('consulting specialist') !== -1) doc = '';

      var consultRaw = getRowVal(row, colConsult);
      var consult = parseFloat(consultRaw) || 0;
      if (consultRaw && doc && consultRaw.toLowerCase().trim() === doc.toLowerCase().trim()) {
        consult = 0;
      }
      var xray = parseFloat(getRowVal(row, colXray)) || 0;
      var pharm = parseFloat(getRowVal(row, colPharm)) || 0;
      var tot = parseFloat(getRowVal(row, colTotal)) || (consult + xray + pharm);
      var pMode = (getRowVal(row, colPayment) || 'Cash').trim();
      var invNo = getRowVal(row, colInvoice) || ('INV-' + (ts ? ts.replace(/\D/g, '').slice(0, 8) : i));

      if (tot <= 0 && consult <= 0 && xray <= 0 && pharm <= 0) continue;

      // Accumulate All-Time
      allTime.total += tot;
      allTime.consultation += consult;
      allTime.xray += xray;
      allTime.pharmacy += pharm;
      allTime.count++;

      // Payment modes
      var pModeLower = pMode.toLowerCase();
      if (pModeLower.indexOf('upi') !== -1 || pModeLower.indexOf('online') !== -1 || pModeLower.indexOf('gpay') !== -1) {
        paymentModes.UPI += tot;
      } else if (pModeLower.indexOf('card') !== -1) {
        paymentModes.Card += tot;
      } else if (pModeLower.indexOf('pending') !== -1) {
        paymentModes.Pending += tot;
      } else if (pModeLower.indexOf('cash') !== -1) {
        paymentModes.Cash += tot;
      } else {
        paymentModes.Other += tot;
      }

      // Daily
      if (rowDateStr === todayStr) {
        daily.total += tot;
        daily.consultation += consult;
        daily.xray += xray;
        daily.pharmacy += pharm;
        daily.count++;
      }

      // Weekly
      if (rowDateStr >= mondayStr && rowDateStr <= todayStr) {
        weekly.total += tot;
        weekly.consultation += consult;
        weekly.xray += xray;
        weekly.pharmacy += pharm;
        weekly.count++;
      }

      // Monthly
      if (rowDateStr && rowDateStr.indexOf(monthPrefix) === 0) {
        monthly.total += tot;
        monthly.consultation += consult;
        monthly.xray += xray;
        monthly.pharmacy += pharm;
        monthly.count++;
      }

      transactions.push({
        invoiceNo: invNo,
        date: ts || rowDateStr,
        dateStr: rowDateStr,
        patientName: pName,
        phone: phone,
        doctorConsulted: doc || 'Doctor',
        consultationCharge: consult,
        xrayCharge: xray,
        pharmacyCharge: pharm,
        totalAmount: tot,
        paymentMode: pMode
      });
    }
  }

  // Sort transactions reverse chronological
  transactions.sort(function(a, b) {
    return (b.date || '').localeCompare(a.date || '');
  });

  return createJsonResponse({
    status: 'success',
    daily: daily,
    weekly: weekly,
    monthly: monthly,
    allTime: allTime,
    paymentModes: paymentModes,
    transactions: transactions,
    todayDate: todayStr,
    currentMonth: monthPrefix
  });
}

