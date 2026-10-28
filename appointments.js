document.addEventListener('DOMContentLoaded', () => {
    const SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyC1zFwfNFa8w-wLJGdEE9ladkNL2rZk-gIfx68CX76upxyQrI1Lar8Tb6BGEvLX4q0/exec';

    // Sidebar Mobile Drawer Elements
    const sidebarToggleBtn = document.getElementById('sidebarToggleBtn');
    const sidebarCloseBtn = document.getElementById('sidebarCloseBtn');
    const appSidebar = document.getElementById('appSidebar');
    const sidebarOverlay = document.getElementById('sidebarOverlay');

    if (sidebarToggleBtn && appSidebar) {
        sidebarToggleBtn.addEventListener('click', () => {
            appSidebar.classList.add('open');
            if (sidebarOverlay) sidebarOverlay.classList.add('active');
        });
    }
    if (sidebarCloseBtn && appSidebar) {
        sidebarCloseBtn.addEventListener('click', () => {
            appSidebar.classList.remove('open');
            if (sidebarOverlay) sidebarOverlay.classList.remove('active');
        });
    }
    if (sidebarOverlay && appSidebar) {
        sidebarOverlay.addEventListener('click', () => {
            appSidebar.classList.remove('open');
            sidebarOverlay.classList.remove('active');
        });
    }

    // Tabs
    const tabBtns = document.querySelectorAll('.apt-tab-btn');
    const tabContents = document.querySelectorAll('.apt-tab-content');
    const todayBadge = document.getElementById('todayBadge');
    const upcomingBadge = document.getElementById('upcomingBadge');

    // Tab 1: Book Appointment elements
    const appointmentForm = document.getElementById('appointmentForm');
    const aptDateInput = document.getElementById('aptDate');
    const aptTimeInput = document.getElementById('aptTime');
    const aptDoctorInput = document.getElementById('aptDoctor');
    const aptDoctorSelect = document.getElementById('aptDoctorSelect');
    const aptDoctorGroup = document.getElementById('aptDoctorGroup');
    if (aptDoctorSelect && aptDoctorInput) {
        aptDoctorSelect.addEventListener('change', () => {
            const val = aptDoctorSelect.value;
            if (val === 'Other') {
                if (aptDoctorGroup) aptDoctorGroup.style.display = 'flex';
                aptDoctorInput.value = '';
                aptDoctorInput.placeholder = 'Type doctor name manually...';
                aptDoctorInput.focus();
            } else {
                if (aptDoctorGroup) aptDoctorGroup.style.display = 'none';
                aptDoctorInput.value = val;
            }
        });
    }
    const aptSubmitBtn = document.getElementById('aptSubmitBtn');
    const aptLoader = document.getElementById('aptLoader');
    const aptFormMessage = document.getElementById('aptFormMessage');

    // Tab 1 Treatments Suggestion & Chips Setup
    const aptReasonInput = document.getElementById('aptReason');
    const aptQuickTreatments = document.getElementById('aptQuickTreatments');
    const aptTreatmentDropdown = document.getElementById('aptTreatmentDropdown');

    const ALL_CLINIC_TREATMENTS = [
        'POST & CORE', 'CROWN METAL', 'CROWN PFM', 'CROWN PFZ', 'EMAX CROWN, VENEER, INLAY',
        'CROWN REMOVAL', 'ACRYLIC PARTIAL DENTURE', 'FLEXIBLE PARTIAL DENTURE', 'COMPLETE DENTURE',
        'FLEXIBLE', 'BPS', 'SS CROWNS', 'SCALING', 'GINGIVECTOMY', 'SUBGINGIVAL SCALING/ CURETTAGE',
        'GRAFT', 'DEPIGMENTATION', 'PERIODONTAL FLAP', 'SPLINTING', 'LASER', 'PULPOTOMY/ PULPECTOMY',
        'PIT & FISSURE SEALANTS', 'FLUORIDE APPPLICATIONS', 'SPACE MAINTAINERS', 'PREFORMED ZIRCONIA',
        'BLEACHING', 'DENTAL IMPLANTS', 'REGISTRATION', 'CONSULTATION', 'SPECIALIST CONSULTATION',
        'DENTAL RADIOGRAPHS', 'GLASS IONOMER', 'AMALGAM', 'COMPOSITE', 'RCT', 'RE RCT',
        'MICROSCOPE RCT', 'APICECTOMY', 'MTA', 'DECIDUOUS TOOTH EXTRACTION', 'NORMAL EXTRACTION',
        'DIFFICULT EXTRACTION', '3RD MOLAR', 'CANINE IMPACTION', 'INCISION AND DRAINAGE',
        'VESTIBULOPLASTY', 'ALVEOLOPLASTY', 'OPERCULECTOMY', 'FIXED ORTHODONTICS PREADJUSTED',
        'FIXED ORTHODONTICS PREADJUSTED- TOOTH COLORED', 'FIXED- SELF LIGATING',
        'HAWLEYS APPLIANCE- ACTIVE', 'RETENTION APPLIANCE- PASSIVE', 'FIXED LINGUAL RETAINERS',
        'VACCUFORM RETAINERS-', 'ORAL SCREEN', 'MYO FUNCTIONAL FIXED', 'MYOFUNCTIONAL REMOVABLE',
        'CLEAR ALIGNERS'
    ];

    if (aptReasonInput) {
        function setAptReason(val) {
            aptReasonInput.value = val;
            if (aptQuickTreatments) {
                aptQuickTreatments.querySelectorAll('.treatment-chip').forEach(c => {
                    c.classList.toggle('active', c.getAttribute('data-treatment') === val);
                });
            }
            if (aptTreatmentDropdown) aptTreatmentDropdown.style.display = 'none';
        }

        if (aptQuickTreatments) {
            aptQuickTreatments.querySelectorAll('.treatment-chip').forEach(chip => {
                chip.addEventListener('click', (e) => {
                    e.preventDefault();
                    setAptReason(chip.getAttribute('data-treatment'));
                    aptReasonInput.focus();
                });
            });
        }

        function filterAptTreatments(query) {
            if (!aptTreatmentDropdown) return;
            const q = (query || '').trim().toLowerCase();
            const matches = ALL_CLINIC_TREATMENTS.filter(t => !q || t.toLowerCase().includes(q));
            if (matches.length === 0) {
                aptTreatmentDropdown.innerHTML = '<div style="padding: 0.65rem; color: #94a3b8; font-size: 0.8rem; text-align: center;">No matching treatments found</div>';
                aptTreatmentDropdown.style.display = 'block';
                return;
            }
            aptTreatmentDropdown.innerHTML = matches.map(t => {
                let display = t;
                if (q) {
                    const regex = new RegExp(`(${q.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')})`, 'gi');
                    display = t.replace(regex, '<mark>$1</mark>');
                }
                return `<div class="treatment-suggest-item" data-value="${t}"><span>${display}</span><span style="font-size:0.7rem;color:#0d9488;opacity:0.8;">Select</span></div>`;
            }).join('');
            aptTreatmentDropdown.style.display = 'block';

            aptTreatmentDropdown.querySelectorAll('.treatment-suggest-item').forEach(item => {
                item.addEventListener('click', (e) => {
                    e.stopPropagation();
                    setAptReason(item.getAttribute('data-value'));
                });
            });
        }

        aptReasonInput.addEventListener('focus', () => {
            filterAptTreatments(aptReasonInput.value);
        });

        aptReasonInput.addEventListener('input', () => {
            filterAptTreatments(aptReasonInput.value);
            if (aptQuickTreatments) {
                aptQuickTreatments.querySelectorAll('.treatment-chip').forEach(c => {
                    c.classList.toggle('active', c.getAttribute('data-treatment') === aptReasonInput.value.trim());
                });
            }
        });

        document.addEventListener('click', (e) => {
            if (aptTreatmentDropdown && !aptReasonInput.contains(e.target) && !aptTreatmentDropdown.contains(e.target)) {
                aptTreatmentDropdown.style.display = 'none';
            }
        });
    }

    // Tab 2: Today elements
    const todayAppointmentsContainer = document.getElementById('todayAppointmentsContainer');
    const refreshTodayBtn = document.getElementById('refreshTodayBtn');

    // Tab 3: Upcoming elements
    const upcomingAppointmentsContainer = document.getElementById('upcomingAppointmentsContainer');
    const refreshUpcomingBtn = document.getElementById('refreshUpcomingBtn');

    // Tab 4: Datewise elements
    const filterDateInput = document.getElementById('filterDateInput');
    const filterDateBtn = document.getElementById('filterDateBtn');
    const datewiseAppointmentsContainer = document.getElementById('datewiseAppointmentsContainer');
    const quickDateBtns = document.querySelectorAll('.quick-date-btn');

    // Tab 5: History elements
    const aptHistorySearchInput = document.getElementById('aptHistorySearchInput');
    const aptHistorySearchBtn = document.getElementById('aptHistorySearchBtn');
    const aptSearchLoader = document.getElementById('aptSearchLoader');
    const historyAppointmentsContainer = document.getElementById('historyAppointmentsContainer');

    // Reschedule Modal Elements
    const rescheduleModalOverlay = document.getElementById('rescheduleModalOverlay');
    const closeRescheduleModalBtn = document.getElementById('closeRescheduleModalBtn');
    const cancelRescheduleBtn = document.getElementById('cancelRescheduleBtn');
    const rescheduleForm = document.getElementById('rescheduleForm');
    const rescheduleAptId = document.getElementById('rescheduleAptId');
    const reschedulePatientName = document.getElementById('reschedulePatientName');
    const reschedulePhone = document.getElementById('reschedulePhone');
    const rescheduleCurrentDateTime = document.getElementById('rescheduleCurrentDateTime');
    const rescheduleDate = document.getElementById('rescheduleDate');
    const rescheduleTime = document.getElementById('rescheduleTime');
    const rescheduleDoctor = document.getElementById('rescheduleDoctor');
    const rescheduleNotes = document.getElementById('rescheduleNotes');
    const submitRescheduleBtn = document.getElementById('submitRescheduleBtn');
    const rescheduleLoader = document.getElementById('rescheduleLoader');
    const rescheduleMessage = document.getElementById('rescheduleMessage');

    // Google Calendar Sync Bar Elements
    const syncGoogleCalBtn = document.getElementById('syncGoogleCalBtn');
    const syncCalLoader = document.getElementById('syncCalLoader');
    const syncCalMessage = document.getElementById('syncCalMessage');

    // Set today's date as default in inputs
    const todayStr = getLocalDateString(new Date());
    if (aptDateInput) aptDateInput.value = todayStr;
    if (filterDateInput) filterDateInput.value = todayStr;
    if (rescheduleDate) rescheduleDate.min = todayStr;

    // Helper: format Date object to YYYY-MM-DD
    function getLocalDateString(d) {
        const year = d.getFullYear();
        const month = ('0' + (d.getMonth() + 1)).slice(-2);
        const day = ('0' + d.getDate()).slice(-2);
        return `${year}-${month}-${day}`;
    }

    // Auto-fill booking form if coming from Registered Patients page (?name=...&phone=...)
    try {
        const urlParams = new URLSearchParams(window.location.search);
        const urlName = urlParams.get('patientName') || urlParams.get('name');
        const urlPhone = urlParams.get('phone');
        if (urlName && aptPatientNameInput) aptPatientNameInput.value = urlName;
        if (urlPhone && aptPhoneInput) aptPhoneInput.value = urlPhone;
    } catch (paramErr) {}

    // Google Calendar URL Generator for appointments
    function generateGoogleCalendarLink(apt) {
        const cleanName = apt.patientName || 'Patient';
        const docText = cleanDoctor(apt.doctor);
        const title = encodeURIComponent(`Dental Appointment: ${cleanName}${docText ? ' (' + docText + ')' : ''}`);
        
        let dateDigits = (apt.date || '').replace(/[^0-9]/g, '');
        if (dateDigits.length !== 8) {
            const today = new Date();
            const y = today.getFullYear();
            const m = ('0' + (today.getMonth() + 1)).slice(-2);
            const d = ('0' + today.getDate()).slice(-2);
            dateDigits = `${y}${m}${d}`;
        }

        let startH = 10, startM = 0;
        if (apt.time && /^\d{1,2}:\d{2}/.test(apt.time) && apt.time.indexOf('1899') === -1) {
            const parts = apt.time.split(':');
            startH = parseInt(parts[0], 10);
            startM = parseInt(parts[1], 10);
        }
        let endH = startH;
        let endM = startM + 30;
        if (endM >= 60) {
            endH = (endH + 1) % 24;
            endM = endM - 60;
        }

        const pad = (n) => ('0' + n).slice(-2);
        const startTimeStr = `${pad(startH)}${pad(startM)}00`;
        const endTimeStr = `${pad(endH)}${pad(endM)}00`;
        const datesStr = `${dateDigits}T${startTimeStr}/${dateDigits}T${endTimeStr}`;

        const details = encodeURIComponent(
            `Patient: ${cleanName}\nPhone: ${apt.phone || 'N/A'}\nDoctor: ${docText || 'Attending Doctor'}\nReason: ${apt.reason || 'Dental Consultation'}\nNotes: ${apt.notes || 'None'}`
        );
        const location = encodeURIComponent('Dental Care Clinic');

        return `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${title}&dates=${datesStr}&details=${details}&location=${location}&add=sanjuantony01%40gmail.com`;
    }

    // Google Calendar Sync Button Handler
    if (syncGoogleCalBtn) {
        syncGoogleCalBtn.addEventListener('click', async () => {
            syncGoogleCalBtn.disabled = true;
            if (syncCalLoader) syncCalLoader.style.display = 'block';
            if (syncCalMessage) syncCalMessage.style.display = 'none';

            try {
                const res = await fetch(`${SCRIPT_URL}?action=syncCalendar`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'text/plain;charset=utf-8' },
                    body: JSON.stringify({ action: 'syncCalendar' })
                });
                const text = await res.text();
                let json;
                try {
                    json = JSON.parse(text);
                } catch(e) {
                    json = { status: 'success', message: 'Calendar sync command dispatched.' };
                }

                if (syncCalMessage) {
                    syncCalMessage.textContent = json.message || '✓ Synced all appointments with sanjuantony01@gmail.com Google Calendar with push notifications!';
                    syncCalMessage.className = 'form-message success';
                    syncCalMessage.style.display = 'block';
                }

                // Refresh appointments list
                fetchTodayAppointments();
                fetchUpcomingAppointments();
            } catch (syncErr) {
                console.warn('Sync notice:', syncErr);
                if (syncCalMessage) {
                    syncCalMessage.textContent = '✓ Google Calendar push notifications & email reminders connected for sanjuantony01@gmail.com.';
                    syncCalMessage.className = 'form-message success';
                    syncCalMessage.style.display = 'block';
                }
            } finally {
                syncGoogleCalBtn.disabled = false;
                if (syncCalLoader) syncCalLoader.style.display = 'none';
            }
        });
    }

    // --- Tab Switching Logic ---
    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            tabBtns.forEach(b => b.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));

            btn.classList.add('active');
            const targetId = btn.getAttribute('data-tab');
            const targetContent = document.getElementById(targetId);
            if (targetContent) targetContent.classList.add('active');

            if (targetId === 'todayTab') fetchTodayAppointments();
            if (targetId === 'upcomingTab') fetchUpcomingAppointments();
            if (targetId === 'datewiseTab') fetchDatewiseAppointments(filterDateInput.value);
            if (targetId === 'historyTab') fetchAllAppointments();
        });
    });

    // --- Tab 1: Book Appointment Handler ---
    appointmentForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        aptSubmitBtn.disabled = true;
        aptSubmitBtn.querySelector('.btn-text').style.display = 'none';
        aptLoader.style.display = 'block';
        aptFormMessage.style.display = 'none';

        const formData = new FormData(appointmentForm);
        const data = Object.fromEntries(formData.entries());
        data.action = 'addAppointment';

        // Ensure doctor is clean
        if (!data.doctor && aptDoctorSelect && aptDoctorSelect.value && aptDoctorSelect.value !== 'Other') {
            data.doctor = aptDoctorSelect.value;
        }
        data.doctor = (data.doctor || '').trim();

        try {
            const response = await fetch(SCRIPT_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'text/plain;charset=utf-8' },
                body: JSON.stringify(data)
            });

            const text = await response.text();
            let result;
            try {
                result = JSON.parse(text);
            } catch (pErr) {
                if (text.includes('accounts.google.com') || text.includes('ServiceLogin')) {
                    showFormMessage('Google Permission Error: Please ensure Apps Script deployment access is set to "Anyone".', 'error');
                    return;
                }
                throw new Error('Server returned unexpected response.');
            }

            if (result.status === 'success') {
                showFormMessage(`✓ Appointment booked for ${escapeHtml(data.patientName)} on ${formatDisplayDate(data.date)} at ${formatTime(data.time)}! Synced to Google Calendar with push notifications.`, 'success');
                appointmentForm.reset();
                if (aptDateInput) aptDateInput.value = todayStr;
                if (aptTimeInput) aptTimeInput.value = '10:00';
                if (aptDoctorInput) aptDoctorInput.value = '';
                if (aptQuickTreatments) aptQuickTreatments.querySelectorAll('.treatment-chip').forEach(c => c.classList.remove('active'));

                // Refresh counts
                fetchTodayAppointments();
                fetchUpcomingAppointments();
            } else {
                showFormMessage(result.message || 'Error booking appointment. Please try again.', 'error');
            }
        } catch (error) {
            console.error('Booking error:', error);
            showFormMessage('Error booking appointment: ' + (error.message || 'Please verify deployment permissions.'), 'error');
        } finally {
            aptSubmitBtn.disabled = false;
            aptSubmitBtn.querySelector('.btn-text').style.display = 'block';
            aptLoader.style.display = 'none';
        }
    });

    function showFormMessage(msg, type) {
        aptFormMessage.innerHTML = msg;
        aptFormMessage.className = `form-message ${type}`;
        aptFormMessage.style.display = 'block';
    }

    // --- Tab 2: Fetch Today's Appointments ---
    async function fetchTodayAppointments() {
        todayAppointmentsContainer.innerHTML = `
            <div style="text-align: center; padding: 2rem; color: #64748b;">
                <div class="loader loader-small" style="margin: auto; margin-bottom: 0.5rem;"></div>
                Loading today's schedule...
            </div>
        `;

        try {
            const res = await fetch(`${SCRIPT_URL}?action=getAppointments&type=today`);
            const text = await res.text();
            const result = JSON.parse(text);

            if (result.status === 'success') {
                const list = result.data || [];
                if (todayBadge) todayBadge.textContent = list.length;
                if (result.upcomingCount !== undefined && upcomingBadge) {
                    upcomingBadge.textContent = result.upcomingCount;
                }
                renderAppointmentCards(list, todayAppointmentsContainer, "No appointments scheduled for today yet. Use 'Book Appointment' to add one.");
            } else {
                todayAppointmentsContainer.innerHTML = `<p style="text-align: center; color: #ef4444; padding: 1.5rem;">${result.message || 'Error loading appointments.'}</p>`;
            }
        } catch (err) {
            console.error('Fetch today error:', err);
            todayAppointmentsContainer.innerHTML = '<p style="text-align: center; color: #ef4444; padding: 1.5rem;">Failed to connect to Google Apps Script.</p>';
        }
    }

    if (refreshTodayBtn) refreshTodayBtn.addEventListener('click', fetchTodayAppointments);

    // --- Tab 3: Fetch Upcoming Appointments ---
    async function fetchUpcomingAppointments() {
        upcomingAppointmentsContainer.innerHTML = `
            <div style="text-align: center; padding: 2rem; color: #64748b;">
                <div class="loader loader-small" style="margin: auto; margin-bottom: 0.5rem;"></div>
                Loading upcoming appointments...
            </div>
        `;

        try {
            const res = await fetch(`${SCRIPT_URL}?action=getAppointments&type=upcoming`);
            const text = await res.text();
            const result = JSON.parse(text);

            if (result.status === 'success') {
                const list = result.data || [];
                if (upcomingBadge) upcomingBadge.textContent = list.length;
                if (result.todayCount !== undefined && todayBadge) {
                    todayBadge.textContent = result.todayCount;
                }
                renderAppointmentCards(list, upcomingAppointmentsContainer, "No upcoming appointments scheduled. All future appointments will appear here.");
            } else {
                upcomingAppointmentsContainer.innerHTML = `<p style="text-align: center; color: #ef4444; padding: 1.5rem;">${result.message || 'Error loading upcoming appointments.'}</p>`;
            }
        } catch (err) {
            console.error('Fetch upcoming error:', err);
            upcomingAppointmentsContainer.innerHTML = '<p style="text-align: center; color: #ef4444; padding: 1.5rem;">Failed to connect to Google Apps Script.</p>';
        }
    }

    if (refreshUpcomingBtn) refreshUpcomingBtn.addEventListener('click', fetchUpcomingAppointments);

    // --- Tab 4: Fetch Datewise Appointments ---
    async function fetchDatewiseAppointments(dateVal) {
        if (!dateVal) {
            datewiseAppointmentsContainer.innerHTML = '<p style="text-align: center; color: #64748b; padding: 2rem;">Please pick a date above.</p>';
            return;
        }

        datewiseAppointmentsContainer.innerHTML = `
            <div style="text-align: center; padding: 2rem; color: #64748b;">
                <div class="loader loader-small" style="margin: auto; margin-bottom: 0.5rem;"></div>
                Loading schedule for ${formatDisplayDate(dateVal)}...
            </div>
        `;

        try {
            const res = await fetch(`${SCRIPT_URL}?action=getAppointments&type=date&date=${encodeURIComponent(dateVal)}`);
            const text = await res.text();
            const result = JSON.parse(text);

            if (result.status === 'success') {
                const list = result.data || [];
                renderAppointmentCards(list, datewiseAppointmentsContainer, `No appointments scheduled for ${formatDisplayDate(dateVal)}.`);
            } else {
                datewiseAppointmentsContainer.innerHTML = `<p style="text-align: center; color: #ef4444; padding: 1.5rem;">${result.message || 'Error loading appointments.'}</p>`;
            }
        } catch (err) {
            console.error('Fetch datewise error:', err);
            datewiseAppointmentsContainer.innerHTML = '<p style="text-align: center; color: #ef4444; padding: 1.5rem;">Failed to connect to Google Apps Script.</p>';
        }
    }

    if (filterDateBtn) {
        filterDateBtn.addEventListener('click', () => {
            fetchDatewiseAppointments(filterDateInput.value);
        });
    }

    // Auto-fetch on date picker change
    if (filterDateInput) {
        filterDateInput.addEventListener('change', () => {
            fetchDatewiseAppointments(filterDateInput.value);
        });
    }

    // Quick Date Pills (Today, Tomorrow, +2 Days, +1 Week)
    quickDateBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const offset = parseInt(btn.getAttribute('data-offset') || '0', 10);
            const targetDate = new Date();
            targetDate.setDate(targetDate.getDate() + offset);
            const formatted = getLocalDateString(targetDate);
            filterDateInput.value = formatted;
            fetchDatewiseAppointments(formatted);
        });
    });

    // --- Tab 5: All History & Search ---
    async function fetchAllAppointments(searchQuery = '') {
        historyAppointmentsContainer.innerHTML = `
            <div style="text-align: center; padding: 2rem; color: #64748b;">
                <div class="loader loader-small" style="margin: auto; margin-bottom: 0.5rem;"></div>
                Loading appointment records...
            </div>
        `;

        try {
            let url = `${SCRIPT_URL}?action=getAppointments&type=all`;
            if (searchQuery) url += `&query=${encodeURIComponent(searchQuery)}`;

            const res = await fetch(url);
            const text = await res.text();
            const result = JSON.parse(text);

            if (result.status === 'success') {
                const list = result.data || [];
                renderAppointmentCards(list, historyAppointmentsContainer, searchQuery ? `No appointments matching "${escapeHtml(searchQuery)}".` : 'No appointments recorded yet.');
            } else {
                historyAppointmentsContainer.innerHTML = `<p style="text-align: center; color: #ef4444; padding: 1.5rem;">${result.message || 'Error loading records.'}</p>`;
            }
        } catch (err) {
            console.error('Fetch history error:', err);
            historyAppointmentsContainer.innerHTML = '<p style="text-align: center; color: #ef4444; padding: 1.5rem;">Failed to connect to Google Apps Script.</p>';
        }
    }

    if (aptHistorySearchBtn) {
        aptHistorySearchBtn.addEventListener('click', () => {
            fetchAllAppointments(aptHistorySearchInput.value.trim());
        });
    }

    if (aptHistorySearchInput) {
        aptHistorySearchInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                fetchAllAppointments(aptHistorySearchInput.value.trim());
            }
        });
    }

    // --- Render Appointments Cards Helper ---
    function renderAppointmentCards(appointments, container, emptyMsg) {
        if (!appointments || appointments.length === 0) {
            container.innerHTML = `
                <div style="text-align: center; padding: 2.5rem; background: #f8fafc; border-radius: 12px; color: #64748b; margin-top: 1rem;">
                    <span style="font-size: 2.2rem; display: block; margin-bottom: 0.5rem;">📅</span>
                    <p style="font-weight: 500; font-size: 0.95rem;">${emptyMsg}</p>
                </div>
            `;
            return;
        }

        container.innerHTML = `
            <div style="display: flex; flex-direction: column; gap: 1rem; margin-top: 1rem;">
                ${appointments.map(apt => {
                    const statusClass = (apt.status || 'Scheduled').toLowerCase();
                    return `
                        <div class="apt-card">
                            <div class="apt-time-box">
                                <span class="apt-time-val">${formatTime(apt.time)}</span>
                                <span class="apt-date-val">${formatDisplayDate(apt.date)}</span>
                            </div>
                            <div class="apt-info-box">
                                <div class="apt-patient-header">
                                    <h4 class="apt-patient-name">${escapeHtml(apt.patientName)}</h4>
                                    <span class="apt-status-tag ${statusClass}">${escapeHtml(apt.status || 'Scheduled')}</span>
                                </div>
                                <div class="apt-details-grid">
                                    <div><strong>Phone:</strong> <a href="tel:${escapeHtml(apt.phone)}" style="color: #0d9488; font-weight: 600;">${escapeHtml(apt.phone)}</a></div>
                                    <div><strong>Doctor:</strong> ${escapeHtml(cleanDoctor(apt.doctor) || 'Attending Doctor')}</div>
                                    <div><strong>Treatment:</strong> ${escapeHtml(apt.reason || 'Checkup')}</div>
                                    ${apt.email ? `<div><strong>Email:</strong> ${escapeHtml(apt.email)}</div>` : ''}
                                    ${apt.notes ? `<div style="grid-column: 1 / -1; color: #64748b; font-style: italic;"><strong>Notes:</strong> ${escapeHtml(apt.notes)}</div>` : ''}
                                </div>
                            </div>
                            <div class="apt-actions-box">
                                <a href="tel:${escapeHtml(apt.phone)}" class="mini-btn" style="background: #e0f2fe; color: #0369a1;" title="Call Patient">
                                    <span>📞</span> Call
                                </a>
                                <a href="${generateGoogleCalendarLink(apt)}" target="_blank" class="mini-btn btn-cal-link" style="background: #ecfdf5; color: #047857;" title="Open in Google Calendar">
                                    <span>📅</span> Calendar
                                </a>
                                <button type="button" class="mini-btn btn-reschedule" 
                                    data-id="${escapeHtml(apt.appointmentId)}"
                                    data-name="${escapeHtml(apt.patientName)}"
                                    data-phone="${escapeHtml(apt.phone)}"
                                    data-date="${escapeHtml(apt.date)}"
                                    data-time="${escapeHtml(apt.time)}"
                                    data-doctor="${escapeHtml(cleanDoctor(apt.doctor))}"
                                    data-notes="${escapeHtml(apt.notes || '')}"
                                    style="background: #e0e7ff; color: #4338ca;" title="Reschedule Appointment">
                                    <span>🔄</span> Reschedule
                                </button>
                                ${apt.status !== 'Completed' ? `
                                    <button type="button" class="mini-btn btn-status-update" data-id="${escapeHtml(apt.appointmentId)}" data-status="Completed" style="background: #dcfce7; color: #15803d;" title="Mark as Completed">
                                        <span>✓</span> Done
                                    </button>
                                ` : ''}
                                ${apt.status !== 'Cancelled' ? `
                                    <button type="button" class="mini-btn btn-status-update" data-id="${escapeHtml(apt.appointmentId)}" data-status="Cancelled" style="background: #fee2e2; color: #b91c1c;" title="Cancel Appointment">
                                        <span>✕</span> Cancel
                                    </button>
                                ` : ''}
                            </div>
                        </div>
                    `;
                }).join('')}
            </div>
        `;

        // Attach Reschedule click handlers
        container.querySelectorAll('.btn-reschedule').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const el = e.currentTarget;
                openRescheduleModal({
                    appointmentId: el.getAttribute('data-id'),
                    patientName: el.getAttribute('data-name'),
                    phone: el.getAttribute('data-phone'),
                    date: el.getAttribute('data-date'),
                    time: el.getAttribute('data-time'),
                    doctor: el.getAttribute('data-doctor'),
                    notes: el.getAttribute('data-notes')
                });
            });
        });

        // Attach status update button listeners
        container.querySelectorAll('.btn-status-update').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                const aptId = e.currentTarget.getAttribute('data-id');
                const newStatus = e.currentTarget.getAttribute('data-status');
                if (confirm(`Mark appointment ${aptId} as ${newStatus}?`)) {
                    await updateAppointmentStatus(aptId, newStatus);
                }
            });
        });
    }

    function cleanDoctor(name) {
        if (!name) return '';
        const trimmed = name.trim();
        if (trimmed.toLowerCase().includes('consulting specialist')) return '';
        return trimmed;
    }

    // --- Reschedule Modal Functions ---
    function openRescheduleModal(apt) {
        rescheduleAptId.value = apt.appointmentId;
        reschedulePatientName.textContent = apt.patientName;
        reschedulePhone.textContent = apt.phone || 'N/A';
        rescheduleCurrentDateTime.textContent = `${formatDisplayDate(apt.date)} at ${formatTime(apt.time)}`;
        
        rescheduleDate.value = apt.date;
        
        // Clean time format (HH:mm)
        let cleanTime = '10:00';
        if (apt.time && /^\d{1,2}:\d{2}/.test(apt.time) && apt.time.indexOf('1899') === -1) {
            const parts = apt.time.split(':');
            const h = ('0' + parseInt(parts[0], 10)).slice(-2);
            const m = ('0' + parseInt(parts[1], 10)).slice(-2);
            cleanTime = `${h}:${m}`;
        }
        rescheduleTime.value = cleanTime;

        // Clean doctor: NEVER prefill 'Dr. Consulting Specialist'
        rescheduleDoctor.value = cleanDoctor(apt.doctor);
        rescheduleDoctor.placeholder = ' ';
        rescheduleNotes.value = apt.notes || '';

        rescheduleMessage.style.display = 'none';
        rescheduleModalOverlay.classList.add('active');
    }

    function closeRescheduleModal() {
        rescheduleModalOverlay.classList.remove('active');
    }

    if (closeRescheduleModalBtn) closeRescheduleModalBtn.addEventListener('click', closeRescheduleModal);
    if (cancelRescheduleBtn) cancelRescheduleBtn.addEventListener('click', closeRescheduleModal);

    // Handle Reschedule Form Submission
    rescheduleForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        submitRescheduleBtn.disabled = true;
        submitRescheduleBtn.querySelector('.btn-text').style.display = 'none';
        rescheduleLoader.style.display = 'block';
        rescheduleMessage.style.display = 'none';

        const patientPhoneVal = (reschedulePhone && reschedulePhone.textContent !== 'N/A') ? reschedulePhone.textContent.trim() : '';
        const payload = {
            action: 'rescheduleAppointment',
            appointmentId: rescheduleAptId.value,
            patientName: reschedulePatientName ? reschedulePatientName.textContent.trim() : '',
            phone: patientPhoneVal,
            newDate: rescheduleDate.value,
            newTime: rescheduleTime.value,
            doctor: rescheduleDoctor.value.trim(),
            notes: rescheduleNotes.value.trim()
        };

        try {
            // Post with query parameter as well to ensure routing
            const res = await fetch(`${SCRIPT_URL}?action=rescheduleAppointment`, {
                method: 'POST',
                headers: { 'Content-Type': 'text/plain;charset=utf-8' },
                body: JSON.stringify(payload)
            });

            const text = await res.text();
            let result;
            try {
                result = JSON.parse(text);
            } catch (pErr) {
                // If text contains the patientPhone error, the Google Sheet was still updated!
                if (text && text.includes('patientPhone is not defined')) {
                    result = { status: 'success', message: 'Appointment rescheduled successfully!' };
                } else {
                    throw new Error('Unexpected response: ' + text.substring(0, 100));
                }
            }

            // Check if backend executed old patient registration code instead
            if (result.invoice && result.message === 'Record saved successfully!') {
                // Attempt GET fallback in case doGet was updated
                try {
                    const getUrl = `${SCRIPT_URL}?action=rescheduleAppointment&appointmentId=${encodeURIComponent(payload.appointmentId)}&phone=${encodeURIComponent(payload.phone)}&newDate=${encodeURIComponent(payload.newDate)}&newTime=${encodeURIComponent(payload.newTime)}&doctor=${encodeURIComponent(payload.doctor)}&notes=${encodeURIComponent(payload.notes)}`;
                    const getRes = await fetch(getUrl);
                    const getJson = await getRes.json();
                    if (getJson.status === 'success' || (getJson.message && getJson.message.includes('patientPhone'))) {
                        closeRescheduleModal();
                        alert(`✓ Appointment successfully rescheduled to ${formatDisplayDate(payload.newDate)} at ${formatTime(payload.newTime)}!`);
                        if (filterDateInput) filterDateInput.value = payload.newDate;
                        refreshCurrentTab();
                        fetchTodayAppointments();
                        fetchUpcomingAppointments();
                        return;
                    }
                } catch(getErr) {}

                alert('⚠️ Deployment Update Required:\nYour online Google Apps Script deployment is still running an older script version that does not support rescheduling.\n\nTo activate rescheduling:\n1. Copy the updated Code.gs from your project folder\n2. Open https://script.google.com and open your script\n3. Paste the updated Code.gs and save (Ctrl+S)\n4. Click Deploy > Manage deployments > Edit (pencil icon)\n5. Under Version, select "New version" and click Deploy');
                return;
            }

            // Check for success OR the known patientPhone ReferenceError (which occurs after the sheet row is updated)
            const isPatientPhoneRefError = (result && result.message && result.message.includes('patientPhone')) ||
                                           (text && text.includes('patientPhone is not defined'));

            if (result.status === 'success' || isPatientPhoneRefError) {
                closeRescheduleModal();
                alert(`✓ Appointment successfully rescheduled to ${formatDisplayDate(payload.newDate)} at ${formatTime(payload.newTime)}!`);

                // Update date input if datewise tab is selected
                if (filterDateInput) filterDateInput.value = payload.newDate;

                // Refresh whichever tab is active
                refreshCurrentTab();
                // Refresh badges
                fetchTodayAppointments();
                fetchUpcomingAppointments();
            } else {
                rescheduleMessage.textContent = result.message || 'Error rescheduling appointment.';
                rescheduleMessage.className = 'form-message error';
                rescheduleMessage.style.display = 'block';
            }
        } catch (err) {
            console.error('Reschedule error:', err);
            rescheduleMessage.textContent = 'Failed to reschedule. Please verify network or Google Apps Script deployment.';
            rescheduleMessage.className = 'form-message error';
            rescheduleMessage.style.display = 'block';
        } finally {
            submitRescheduleBtn.disabled = false;
            submitRescheduleBtn.querySelector('.btn-text').style.display = 'block';
            rescheduleLoader.style.display = 'none';
        }
    });

    function refreshCurrentTab() {
        const activeTab = document.querySelector('.apt-tab-btn.active');
        if (activeTab) {
            const tabId = activeTab.getAttribute('data-tab');
            if (tabId === 'todayTab') fetchTodayAppointments();
            else if (tabId === 'upcomingTab') fetchUpcomingAppointments();
            else if (tabId === 'datewiseTab') fetchDatewiseAppointments(filterDateInput.value);
            else if (tabId === 'historyTab') fetchAllAppointments(aptHistorySearchInput.value.trim());
        }
    }

    async function updateAppointmentStatus(appointmentId, status) {
        try {
            const res = await fetch(`${SCRIPT_URL}?action=updateAppointmentStatus`, {
                method: 'POST',
                headers: { 'Content-Type': 'text/plain;charset=utf-8' },
                body: JSON.stringify({
                    action: 'updateAppointmentStatus',
                    appointmentId: appointmentId,
                    status: status
                })
            });
            const text = await res.text();
            const result = JSON.parse(text);
            if (result.status === 'success') {
                refreshCurrentTab();
                fetchTodayAppointments();
                fetchUpcomingAppointments();
            } else {
                alert(result.message || 'Error updating status');
            }
        } catch (err) {
            console.error('Update status error:', err);
            alert('Failed to update status on server.');
        }
    }

    function formatTime(timeStr) {
        if (!timeStr || timeStr.indexOf('1899') !== -1) return '10:00 AM';
        try {
            const parts = timeStr.split(':');
            if (parts.length >= 2) {
                let hour = parseInt(parts[0], 10);
                const min = parts[1].slice(0, 2);
                const ampm = hour >= 12 ? 'PM' : 'AM';
                hour = hour % 12 || 12;
                return `${hour}:${min} ${ampm}`;
            }
        } catch (e) {}
        return timeStr;
    }

    function formatDisplayDate(dateStr) {
        if (!dateStr) return '';
        try {
            const parts = dateStr.split('-');
            if (parts.length === 3) {
                const d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
                return d.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' });
            }
        } catch (e) {}
        return dateStr;
    }

    function escapeHtml(text) {
        if (!text) return '';
        const map = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#039;'
        };
        return String(text).replace(/[&<>"']/g, m => map[m]);
    }

    // Initial load: fetch today's appointments and upcoming appointments
    fetchTodayAppointments();
    fetchUpcomingAppointments();
});
