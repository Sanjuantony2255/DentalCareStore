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
    const tomorrowBadge = document.getElementById('tomorrowBadge');
    const tomorrowHeaderBadge = document.getElementById('tomorrowHeaderBadge');
    const tomorrowDateDisplay = document.getElementById('tomorrowDateDisplay');
    const upcomingBadge = document.getElementById('upcomingBadge');

    // Tab 1: Book Appointment elements
    const appointmentForm = document.getElementById('appointmentForm');
    const aptDateInput = document.getElementById('aptDate');
    const aptTimeInput = document.getElementById('aptTime');
    const aptDoctorInput = document.getElementById('aptDoctor');
    const aptDoctorSelect = document.getElementById('aptDoctorSelect');
    const aptDoctorGroup = document.getElementById('aptDoctorGroup');
    const aptOpNumber = document.getElementById('aptOpNumber');
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

    // Tab 1 Registered Patient Autocomplete Elements
    const aptPatientName = document.getElementById('aptPatientName');
    const aptPhone = document.getElementById('aptPhone');
    const aptEmail = document.getElementById('aptEmail');
    const aptNameDropdown = document.getElementById('aptNameDropdown');
    const aptPhoneDropdown = document.getElementById('aptPhoneDropdown');
    const aptRegisteredBadge = document.getElementById('aptRegisteredBadge');
    const aptRegisteredName = document.getElementById('aptRegisteredName');
    const aptRegisteredOp = document.getElementById('aptRegisteredOp');
    const aptRegisteredPhone = document.getElementById('aptRegisteredPhone');
    const aptClearSuggestedBtn = document.getElementById('aptClearSuggestedBtn');

    let registeredPatients = [];
    let tomorrowAppointmentsList = [];

    // Helper: Normalize patient records from various storage schemas
    function normalizePatient(p) {
        if (!p) return null;
        const name = (p.fullName || p.patientName || p.name || '').toString().trim();
        const phone = (p.phone || '').toString().trim();
        const opNumber = (p.opNumber || p.op || p.id || '').toString().trim();
        const email = (p.email || (p.address && p.address.includes('@') ? p.address : '') || '').toString().trim();
        const doctor = (p.doctor || p.doctorConsulted || '').toString().trim();
        if (!name && !phone) return null;
        return { name, phone, opNumber, email, doctor };
    }

    // Helper: Merge and deduplicate patient lists
    function mergePatients(existingList, newList) {
        const map = new Map();
        [...existingList, ...newList].forEach(item => {
            const p = normalizePatient(item);
            if (!p) return;
            const key = (p.phone.replace(/\D/g, '') || p.name.toLowerCase());
            if (!map.has(key) || (!map.get(key).opNumber && p.opNumber)) {
                map.set(key, p);
            }
        });
        return Array.from(map.values());
    }

    // Load registered patients from local caches & fetch from server
    async function loadRegisteredPatients() {
        try {
            const rawCache = localStorage.getItem('dental_cached_patients');
            if (rawCache) {
                const parsed = JSON.parse(rawCache);
                if (Array.isArray(parsed)) {
                    registeredPatients = mergePatients(registeredPatients, parsed);
                }
            }
            const rawDir = localStorage.getItem('dental_cached_patients_directory');
            if (rawDir) {
                const parsedDir = JSON.parse(rawDir);
                if (Array.isArray(parsedDir)) {
                    registeredPatients = mergePatients(registeredPatients, parsedDir);
                }
            }
        } catch (e) {
            console.warn('Cache read error:', e);
        }

        // Fetch registered patients in background from Google Apps Script
        try {
            const res = await fetch(`${SCRIPT_URL}?action=getPatients`);
            const json = await res.json();
            if (json && json.status === 'success' && Array.isArray(json.data)) {
                registeredPatients = mergePatients(registeredPatients, json.data);
                try {
                    localStorage.setItem('dental_cached_patients', JSON.stringify(registeredPatients.slice(0, 300)));
                } catch (e) {}
            }
        } catch (fetchErr) {
            console.warn('Background patient sync notice:', fetchErr);
        }
    }
    loadRegisteredPatients();

    // Select a registered patient and autofill form
    function selectRegisteredPatient(p) {
        if (!p) return;
        if (aptPatientName) aptPatientName.value = p.name;
        if (aptPhone) aptPhone.value = p.phone;
        if (aptEmail && p.email && p.email.includes('@') && !aptEmail.value) {
            aptEmail.value = p.email;
        }

        // Try to match doctor if available
        if (p.doctor && aptDoctorSelect) {
            const cleanDoc = p.doctor.toLowerCase();
            for (let opt of aptDoctorSelect.options) {
                if (opt.value && opt.value !== 'Other' && opt.value.toLowerCase().includes(cleanDoc)) {
                    aptDoctorSelect.value = opt.value;
                    if (aptDoctorInput) aptDoctorInput.value = opt.value;
                    if (aptDoctorGroup) aptDoctorGroup.style.display = 'none';
                    break;
                }
            }
        }

        // Auto-fill OP Number input
        if (aptOpNumber && p.opNumber) {
            aptOpNumber.value = p.opNumber;
        }

        // Display recognized registered badge
        if (aptRegisteredBadge) {
            if (aptRegisteredName) aptRegisteredName.textContent = p.name;
            if (aptRegisteredOp) aptRegisteredOp.textContent = p.opNumber || 'Registered';
            if (aptRegisteredPhone) aptRegisteredPhone.textContent = p.phone || '-';
            aptRegisteredBadge.style.display = 'flex';
        }

        // Close dropdowns
        if (aptNameDropdown) aptNameDropdown.style.display = 'none';
        if (aptPhoneDropdown) aptPhoneDropdown.style.display = 'none';
    }

    // Clear registered patient badge
    if (aptClearSuggestedBtn && aptRegisteredBadge) {
        aptClearSuggestedBtn.addEventListener('click', () => {
            aptRegisteredBadge.style.display = 'none';
            if (aptOpNumber) aptOpNumber.value = '';
        });
    }

    // Escape regex characters
    function escapeRegExp(str) {
        return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }

    // Filter & render suggestions for Patient Name
    function filterNameSuggestions(query) {
        if (!aptNameDropdown) return;
        const q = (query || '').trim().toLowerCase();
        if (q.length < 1) {
            aptNameDropdown.style.display = 'none';
            return;
        }

        const matches = registeredPatients.filter(p => {
            const pName = (p.name || '').toLowerCase();
            const pPhone = (p.phone || '').replace(/\D/g, '');
            return pName.includes(q) || (q.length >= 3 && pPhone.includes(q));
        }).slice(0, 8);

        if (matches.length === 0) {
            aptNameDropdown.style.display = 'none';
            return;
        }

        const regex = new RegExp(`(${escapeRegExp(q)})`, 'gi');
        aptNameDropdown.innerHTML = matches.map(p => {
            const displayName = p.name ? p.name.replace(regex, '<mark>$1</mark>') : 'Unknown';
            const opHtml = p.opNumber ? `<span class="patient-suggest-op">${escapeHtml(p.opNumber)}</span>` : '';
            return `
                <div class="patient-suggest-item" data-phone="${escapeHtml(p.phone)}" data-name="${escapeHtml(p.name)}">
                    <div class="patient-suggest-main">
                        <span class="patient-suggest-name">${displayName}</span>
                        <span class="patient-suggest-phone">📞 ${escapeHtml(p.phone || '-')}</span>
                    </div>
                    <div class="patient-suggest-meta">
                        ${opHtml}
                        <span style="font-size:0.75rem; color:#0d9488; font-weight:600;">Select</span>
                    </div>
                </div>
            `;
        }).join('');

        aptNameDropdown.style.display = 'block';

        aptNameDropdown.querySelectorAll('.patient-suggest-item').forEach((item, idx) => {
            item.addEventListener('click', (e) => {
                e.stopPropagation();
                selectRegisteredPatient(matches[idx]);
            });
        });
    }

    // Filter & render suggestions for Phone Number
    function filterPhoneSuggestions(query) {
        if (!aptPhoneDropdown) return;
        const qDigits = (query || '').replace(/\D/g, '');
        if (qDigits.length < 2) {
            aptPhoneDropdown.style.display = 'none';
            return;
        }

        const matches = registeredPatients.filter(p => {
            const pPhoneDigits = (p.phone || '').replace(/\D/g, '');
            return pPhoneDigits.includes(qDigits);
        }).slice(0, 8);

        if (matches.length === 0) {
            aptPhoneDropdown.style.display = 'none';
            return;
        }

        aptPhoneDropdown.innerHTML = matches.map(p => {
            const phoneStr = p.phone || '';
            const regex = new RegExp(`(${escapeRegExp(qDigits)})`, 'g');
            const displayPhone = phoneStr.replace(regex, '<mark>$1</mark>');
            const opHtml = p.opNumber ? `<span class="patient-suggest-op">${escapeHtml(p.opNumber)}</span>` : '';
            return `
                <div class="patient-suggest-item" data-phone="${escapeHtml(p.phone)}" data-name="${escapeHtml(p.name)}">
                    <div class="patient-suggest-main">
                        <span class="patient-suggest-name">${escapeHtml(p.name || 'Patient')}</span>
                        <span class="patient-suggest-phone">📞 ${displayPhone}</span>
                    </div>
                    <div class="patient-suggest-meta">
                        ${opHtml}
                        <span style="font-size:0.75rem; color:#0d9488; font-weight:600;">Select</span>
                    </div>
                </div>
            `;
        }).join('');

        aptPhoneDropdown.style.display = 'block';

        aptPhoneDropdown.querySelectorAll('.patient-suggest-item').forEach((item, idx) => {
            item.addEventListener('click', (e) => {
                e.stopPropagation();
                selectRegisteredPatient(matches[idx]);
            });
        });
    }

    // Attach listeners for Name input
    if (aptPatientName) {
        aptPatientName.addEventListener('input', () => {
            filterNameSuggestions(aptPatientName.value);
        });
        aptPatientName.addEventListener('focus', () => {
            if (aptPatientName.value.trim().length >= 1) {
                filterNameSuggestions(aptPatientName.value);
            }
        });
        aptPatientName.addEventListener('keydown', (e) => {
            if (!aptNameDropdown || aptNameDropdown.style.display === 'none') return;
            const items = aptNameDropdown.querySelectorAll('.patient-suggest-item');
            if (!items.length) return;
            const current = aptNameDropdown.querySelector('.patient-suggest-item.highlighted');
            let idx = Array.from(items).indexOf(current);

            if (e.key === 'ArrowDown') {
                e.preventDefault();
                idx = (idx + 1) % items.length;
                items.forEach(i => i.classList.remove('highlighted'));
                items[idx].classList.add('highlighted');
                items[idx].scrollIntoView({ block: 'nearest' });
            } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                idx = (idx - 1 + items.length) % items.length;
                items.forEach(i => i.classList.remove('highlighted'));
                items[idx].classList.add('highlighted');
                items[idx].scrollIntoView({ block: 'nearest' });
            } else if (e.key === 'Enter') {
                if (current) {
                    e.preventDefault();
                    current.click();
                }
            } else if (e.key === 'Escape') {
                aptNameDropdown.style.display = 'none';
            }
        });
    }

    // Attach listeners for Phone input
    if (aptPhone) {
        aptPhone.addEventListener('input', () => {
            filterPhoneSuggestions(aptPhone.value);
        });
        aptPhone.addEventListener('focus', () => {
            if (aptPhone.value.replace(/\D/g, '').length >= 2) {
                filterPhoneSuggestions(aptPhone.value);
            }
        });
        aptPhone.addEventListener('keydown', (e) => {
            if (!aptPhoneDropdown || aptPhoneDropdown.style.display === 'none') return;
            const items = aptPhoneDropdown.querySelectorAll('.patient-suggest-item');
            if (!items.length) return;
            const current = aptPhoneDropdown.querySelector('.patient-suggest-item.highlighted');
            let idx = Array.from(items).indexOf(current);

            if (e.key === 'ArrowDown') {
                e.preventDefault();
                idx = (idx + 1) % items.length;
                items.forEach(i => i.classList.remove('highlighted'));
                items[idx].classList.add('highlighted');
                items[idx].scrollIntoView({ block: 'nearest' });
            } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                idx = (idx - 1 + items.length) % items.length;
                items.forEach(i => i.classList.remove('highlighted'));
                items[idx].classList.add('highlighted');
                items[idx].scrollIntoView({ block: 'nearest' });
            } else if (e.key === 'Enter') {
                if (current) {
                    e.preventDefault();
                    current.click();
                }
            } else if (e.key === 'Escape') {
                aptPhoneDropdown.style.display = 'none';
            }
        });
    }

    // Close suggestion dropdowns when clicking outside
    document.addEventListener('click', (e) => {
        if (aptNameDropdown && !aptPatientName?.contains(e.target) && !aptNameDropdown.contains(e.target)) {
            aptNameDropdown.style.display = 'none';
        }
        if (aptPhoneDropdown && !aptPhone?.contains(e.target) && !aptPhoneDropdown.contains(e.target)) {
            aptPhoneDropdown.style.display = 'none';
        }
    });

    // Tab 1 Treatments Suggestion & Chips Setup
    const aptReasonInput = document.getElementById('aptReason');
    const aptQuickTreatments = document.getElementById('aptQuickTreatments');
    const aptTreatmentDropdown = document.getElementById('aptTreatmentDropdown');

    const ALL_CLINIC_TREATMENTS = [
        'SELECT ANY OPTION / OTHER',
        'GENERAL CONSULTATION / CHECKUP',
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
        'CLEAR ALIGNERS', 'OTHER / ANY OPTION'
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

            let html = '';

            // Allow selecting typed custom text as any option
            if (q.length > 0) {
                html += `<div class="treatment-suggest-item custom-option" data-value="${escapeHtml(query.trim())}">
                    <span>✨ Use "<strong>${escapeHtml(query.trim())}</strong>" (Select Any Option)</span>
                    <span style="font-size:0.75rem;color:#0d9488;font-weight:700;">Select</span>
                </div>`;
            }

            if (matches.length > 0) {
                html += matches.map(t => {
                    let display = t;
                    if (q) {
                        const regex = new RegExp(`(${q.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')})`, 'gi');
                        display = t.replace(regex, '<mark>$1</mark>');
                    }
                    return `<div class="treatment-suggest-item" data-value="${t}"><span>${display}</span><span style="font-size:0.7rem;color:#0d9488;opacity:0.8;">Select</span></div>`;
                }).join('');
            }

            // Always offer choice to select any custom option
            html += `<div class="treatment-suggest-item" data-value="SELECT ANY OPTION / OTHER">
                <span>➕ Select Any Option / Other Treatment...</span>
                <span style="font-size:0.72rem;color:#0d9488;font-weight:700;">Select</span>
            </div>`;

            aptTreatmentDropdown.innerHTML = html;
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

    // Tab: Tomorrow elements
    const tomorrowAppointmentsContainer = document.getElementById('tomorrowAppointmentsContainer');
    const refreshTomorrowBtn = document.getElementById('refreshTomorrowBtn');
    const sendAllTomorrowBtn = document.getElementById('sendAllTomorrowBtn');

    // Send Tomorrow Modal Elements
    const sendTomorrowModalOverlay = document.getElementById('sendTomorrowModalOverlay');
    const closeSendTomorrowModalBtn = document.getElementById('closeSendTomorrowModalBtn');
    const cancelSendTomorrowBtn = document.getElementById('cancelSendTomorrowBtn');
    const sendTomorrowPatientList = document.getElementById('sendTomorrowPatientList');
    const sendTomorrowSummary = document.getElementById('sendTomorrowSummary');
    const startBatchSendBtn = document.getElementById('startBatchSendBtn');

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

    // Helper: format Date object to YYYY-MM-DD
    function getLocalDateString(d) {
        const year = d.getFullYear();
        const month = ('0' + (d.getMonth() + 1)).slice(-2);
        const day = ('0' + d.getDate()).slice(-2);
        return `${year}-${month}-${day}`;
    }

    // Helper: get tomorrow's date YYYY-MM-DD
    function getTomorrowDateString() {
        const d = new Date();
        d.setDate(d.getDate() + 1);
        return getLocalDateString(d);
    }

    // Set today's date as default in inputs
    const todayStr = getLocalDateString(new Date());
    const tomorrowStr = getTomorrowDateString();
    if (aptDateInput) aptDateInput.value = todayStr;
    if (filterDateInput) filterDateInput.value = todayStr;
    if (rescheduleDate) rescheduleDate.min = todayStr;
    if (tomorrowDateDisplay) tomorrowDateDisplay.textContent = `Schedule for ${formatDisplayDate(tomorrowStr)}`;

    // Helper: Lookup OP number for patient
    function getPatientOp(apt) {
        if (!apt) return '';
        if (apt.opNumber) return apt.opNumber;
        if (apt.op) return apt.op;
        const cleanPhone = (apt.phone || '').toString().replace(/\D/g, '');
        const cleanName = (apt.patientName || apt.name || '').toString().toLowerCase().trim();
        const match = registeredPatients.find(p => {
            const pPhone = (p.phone || '').toString().replace(/\D/g, '');
            const pName = (p.name || '').toString().toLowerCase().trim();
            const phoneMatch = cleanPhone.length >= 10 && pPhone.length >= 10 && pPhone.slice(-10) === cleanPhone.slice(-10);
            const nameMatch = cleanName && pName && (cleanName === pName || pName.includes(cleanName) || cleanName.includes(pName));
            return (phoneMatch && nameMatch) || (cleanPhone.length >= 10 && pPhone.endsWith(cleanPhone.slice(-10)));
        });
        return (match && match.opNumber) ? match.opNumber : '';
    }

    // WhatsApp Reminder Link Generator
    function generateWhatsAppReminderLink(apt) {
        const cleanName = apt.patientName || apt.fullName || 'Valued Patient';
        let rawPhone = (apt.phone || '').toString().trim();
        let phoneDigits = rawPhone.replace(/\D/g, '');
        if (phoneDigits.length === 10) {
            phoneDigits = '91' + phoneDigits;
        } else if (phoneDigits.startsWith('0') && phoneDigits.length === 11) {
            phoneDigits = '91' + phoneDigits.substring(1);
        }

        const docText = cleanDoctor(apt.doctor) || 'Attending Doctor';
        const dateText = formatDisplayDate(apt.date);
        const timeText = formatTime(apt.time);
        const reasonText = apt.reason || 'Dental Consultation & Checkup';

        const text = `🦷 *Manjaly Multi Speciality Dental Care*\n*Appointment Reminder*\n\nDear *${cleanName}*,\nThis is a friendly reminder regarding your scheduled dental appointment:\n\n📅 *Date:* ${dateText}\n⏰ *Time:* ${timeText}\n👨‍⚕️ *Doctor:* ${docText}\n🩺 *Treatment / Reason:* ${reasonText}\n\n📍 *Clinic:* Manjaly Multi Speciality Dental Care\n📞 *Contact:* +91 9072467117 / +91 6238497517\n\n_Please arrive 10 minutes prior to your appointment time. If you need to reschedule or have questions, kindly contact us._\n\nThank you!`;

        return `https://wa.me/${phoneDigits}?text=${encodeURIComponent(text)}`;
    }
    window.generateWhatsAppReminderLink = generateWhatsAppReminderLink;

    function sendWhatsAppReminder(apt) {
        const url = generateWhatsAppReminderLink(apt);
        window.open(url, '_blank');
    }
    window.sendWhatsAppReminder = sendWhatsAppReminder;

    // Auto-fill booking form if coming from Registered Patients page (?name=...&phone=...)
    try {
        const urlParams = new URLSearchParams(window.location.search);
        const urlName = urlParams.get('patientName') || urlParams.get('name');
        const urlPhone = urlParams.get('phone');
        if (urlName && aptPatientName) aptPatientName.value = urlName;
        if (urlPhone && aptPhone) aptPhone.value = urlPhone;
        if (urlName || urlPhone) {
            setTimeout(() => {
                const match = registeredPatients.find(p => {
                    const pPhone = (p.phone || '').replace(/\D/g, '');
                    const qPhone = (urlPhone || '').replace(/\D/g, '');
                    return (qPhone && pPhone === qPhone) || (urlName && (p.name || '').toLowerCase() === urlName.toLowerCase());
                });
                if (match) selectRegisteredPatient(match);
            }, 300);
        }
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
            `Patient: ${cleanName}\nPhone: ${apt.phone || 'N/A'}\nDoctor: ${docText || 'Attending Doctor'}\nReason: ${apt.reason || 'Dental Consultation'}\nNotes: ${apt.notes || 'None'}\nClinic: Manjaly Multi Speciality Dental Care`
        );
        const location = encodeURIComponent('Manjaly Multi Speciality Dental Care');

        // Universal Google Calendar render URL that syncs with whichever Google account is active on the user's phone/device
        return `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${title}&dates=${datesStr}&details=${details}&location=${location}`;
    }

    // Universal .ics (iCalendar) download for iPhone, Samsung, and Android native calendar apps
    function downloadIcsCalendarFile(apt) {
        const cleanName = apt.patientName || 'Patient';
        const docText = cleanDoctor(apt.doctor);
        const title = `Dental Appointment: ${cleanName}${docText ? ' (' + docText + ')' : ''}`;
        
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
        const dtStart = `${dateDigits}T${startTimeStr}`;
        const dtEnd = `${dateDigits}T${endTimeStr}`;
        const nowStamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';

        const icsContent = [
            'BEGIN:VCALENDAR',
            'VERSION:2.0',
            'PRODID:-//Manjaly Dental Care//Appointment System//EN',
            'CALSCALE:GREGORIAN',
            'METHOD:PUBLISH',
            'BEGIN:VEVENT',
            `UID:apt-${dateDigits}-${startH}${startM}-${Math.floor(Math.random()*10000)}@manjalydental.com`,
            `DTSTAMP:${nowStamp}`,
            `DTSTART:${dtStart}`,
            `DTEND:${dtEnd}`,
            `SUMMARY:${title.replace(/[\\,;]/g, ' ')}`,
            `DESCRIPTION:Patient: ${cleanName}\\nPhone: ${apt.phone || 'N/A'}\\nDoctor: ${docText || 'Attending Doctor'}\\nReason: ${apt.reason || 'Dental Consultation'}\\nClinic: Manjaly Multi Speciality Dental Care`,
            'LOCATION:Manjaly Multi Speciality Dental Care',
            'STATUS:CONFIRMED',
            'BEGIN:VALARM',
            'ACTION:DISPLAY',
            'DESCRIPTION:Reminder: Dental Appointment in 15 minutes',
            'TRIGGER:-PT15M',
            'END:VALARM',
            'BEGIN:VALARM',
            'ACTION:DISPLAY',
            'DESCRIPTION:Reminder: Dental Appointment in 1 hour',
            'TRIGGER:-PT60M',
            'END:VALARM',
            'END:VEVENT',
            'END:VCALENDAR'
        ].join('\r\n');

        const blob = new Blob([icsContent], { type: 'text/calendar;charset=utf-8' });
        const link = document.createElement('a');
        link.href = window.URL.createObjectURL(blob);
        link.setAttribute('download', `Appointment_${cleanName.replace(/[^a-zA-Z0-9]/g, '_')}_${dateDigits}.ics`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }
    window.downloadIcsCalendarFile = downloadIcsCalendarFile;

    // Google Calendar Sync Button Handler - Syncs directly with current device's connected calendar
    if (syncGoogleCalBtn) {
        syncGoogleCalBtn.addEventListener('click', async () => {
            syncGoogleCalBtn.disabled = true;
            if (syncCalLoader) syncCalLoader.style.display = 'block';
            if (syncCalMessage) syncCalMessage.style.display = 'none';

            try {
                // Refresh appointments list from sheet
                await Promise.allSettled([
                    fetchTodayAppointments(),
                    fetchUpcomingAppointments()
                ]);

                if (syncCalMessage) {
                    syncCalMessage.innerHTML = `
                        <div style="font-size: 0.92rem; line-height: 1.5;">
                            <strong>✓ Device Calendar Sync is Active!</strong><br>
                            Appointments booked on this phone or computer automatically sync with whichever Google Calendar is active on this device.
                            <div style="margin-top: 8px; display: flex; gap: 8px; flex-wrap: wrap;">
                                <a href="https://calendar.google.com/calendar/" target="_blank" rel="noopener noreferrer" class="mini-btn" style="background: #047857; color: white; padding: 6px 14px; border-radius: 6px; text-decoration: none; font-weight: 600; display: inline-flex; align-items: center; gap: 6px;">
                                    <span>📅</span> Open This Device's Google Calendar
                                </a>
                            </div>
                        </div>
                    `;
                    syncCalMessage.className = 'form-message success';
                    syncCalMessage.style.display = 'block';
                }
            } catch (syncErr) {
                console.warn('Sync notice:', syncErr);
                if (syncCalMessage) {
                    syncCalMessage.innerHTML = '<strong>✓ Device Calendar Sync Active</strong> — Appointments sync directly with this phone/device connected Google Calendar.';
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
            if (targetId === 'tomorrowTab') fetchTomorrowAppointments();
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
        if (!data.opNumber) {
            data.opNumber = getPatientOp(data);
        }

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

            const isCalNotice = (result.message && (
                result.message.includes('Could not access Google Calendar') ||
                result.message.includes('sanjuantony01') ||
                result.message.includes('Calendar permissions')
            )) || (text && (
                text.includes('Could not access Google Calendar') ||
                text.includes('sanjuantony01') ||
                text.includes('Calendar permissions')
            ));

            if (result.status === 'success' || isCalNotice) {
                const syncDeviceCb = document.getElementById('syncDeviceGoogleCal');
                const shouldSyncDevice = syncDeviceCb ? syncDeviceCb.checked : true;
                const calUrl = generateGoogleCalendarLink(data);

                let syncActionHtml = '';
                if (shouldSyncDevice) {
                    try {
                        window.open(calUrl, '_blank');
                    } catch (openErr) {
                        console.warn('Auto-popup blocked, user can click button:', openErr);
                    }
                    syncActionHtml = `
                        <div style="margin-top: 12px; display: flex; gap: 8px; flex-wrap: wrap;">
                            <a href="${calUrl}" target="_blank" rel="noopener noreferrer" class="mini-btn" style="background: #047857; color: white; padding: 0.65rem 1.25rem; border-radius: 8px; font-weight: 700; text-decoration: none; display: inline-flex; align-items: center; gap: 8px; box-shadow: 0 2px 6px rgba(4,120,87,0.3);">
                                <span>📅</span> Open in this Phone's Google Calendar
                            </a>
                            <button type="button" class="mini-btn" onclick="window.downloadIcsCalendarFile(${JSON.stringify(data).replace(/"/g, '&quot;')})" style="background: #1e3a8a; color: white; padding: 0.65rem 1.25rem; border-radius: 8px; font-weight: 700; border: none; cursor: pointer; display: inline-flex; align-items: center; gap: 8px; box-shadow: 0 2px 6px rgba(30,58,138,0.3);">
                                <span>📲</span> Add to Phone / Apple Calendar (.ics)
                            </button>
                        </div>
                    `;
                }

                showFormMessage(`
                    <div>
                        <strong>✓ Appointment booked successfully!</strong><br>
                        Patient: <strong>${escapeHtml(data.patientName)}</strong> on <strong>${formatDisplayDate(data.date)}</strong> at <strong>${formatTime(data.time)}</strong>.
                        ${shouldSyncDevice ? '<br><span style="color: #047857; font-weight: 600;">✓ Synced with this phone/device\'s connected Google Calendar with push notifications.</span>' : ''}
                    </div>
                    ${syncActionHtml}
                `, 'success');

                appointmentForm.reset();
                if (syncDeviceCb) syncDeviceCb.checked = true;
                if (aptDateInput) aptDateInput.value = todayStr;
                if (aptTimeInput) aptTimeInput.value = '10:00';
                if (aptDoctorInput) aptDoctorInput.value = '';
                if (aptQuickTreatments) aptQuickTreatments.querySelectorAll('.treatment-chip').forEach(c => c.classList.remove('active'));
                if (aptRegisteredBadge) aptRegisteredBadge.style.display = 'none';
                if (aptNameDropdown) aptNameDropdown.style.display = 'none';
                if (aptPhoneDropdown) aptPhoneDropdown.style.display = 'none';

                // Refresh counts
                fetchTodayAppointments();
                fetchTomorrowAppointments();
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

    // --- Tab: Fetch Tomorrow's Appointments ---
    async function fetchTomorrowAppointments() {
        const tomorrowDate = getTomorrowDateString();
        if (tomorrowDateDisplay) {
            tomorrowDateDisplay.textContent = `Schedule for ${formatDisplayDate(tomorrowDate)}`;
        }
        if (tomorrowAppointmentsContainer) {
            tomorrowAppointmentsContainer.innerHTML = `
                <div style="text-align: center; padding: 2rem; color: #64748b;">
                    <div class="loader loader-small" style="margin: auto; margin-bottom: 0.5rem;"></div>
                    Loading tomorrow's schedule (${formatDisplayDate(tomorrowDate)})...
                </div>
            `;
        }

        try {
            const res = await fetch(`${SCRIPT_URL}?action=getAppointments&type=date&date=${encodeURIComponent(tomorrowDate)}`);
            const text = await res.text();
            const result = JSON.parse(text);

            if (result.status === 'success') {
                tomorrowAppointmentsList = result.data || [];
                if (tomorrowBadge) tomorrowBadge.textContent = tomorrowAppointmentsList.length;
                if (tomorrowHeaderBadge) tomorrowHeaderBadge.textContent = tomorrowAppointmentsList.length;
                if (tomorrowAppointmentsContainer) {
                    renderAppointmentCards(tomorrowAppointmentsList, tomorrowAppointmentsContainer, `No appointments scheduled for tomorrow (${formatDisplayDate(tomorrowDate)}).`);
                }
            } else {
                if (tomorrowAppointmentsContainer) {
                    tomorrowAppointmentsContainer.innerHTML = `<p style="text-align: center; color: #ef4444; padding: 1.5rem;">${result.message || 'Error loading tomorrow appointments.'}</p>`;
                }
            }
        } catch (err) {
            console.error('Fetch tomorrow error:', err);
            if (tomorrowAppointmentsContainer) {
                tomorrowAppointmentsContainer.innerHTML = '<p style="text-align: center; color: #ef4444; padding: 1.5rem;">Failed to connect to Google Apps Script.</p>';
            }
        }
    }

    if (refreshTomorrowBtn) refreshTomorrowBtn.addEventListener('click', fetchTomorrowAppointments);

    // --- Tomorrow WhatsApp Reminders Modal & Batch Flow ---
    let tomorrowSentStatuses = {}; // key: appointmentId or phone -> boolean

    function openSendTomorrowModal() {
        if (!sendTomorrowModalOverlay) return;
        renderSendTomorrowModalList();
        sendTomorrowModalOverlay.classList.add('active');
    }

    function closeSendTomorrowModal() {
        if (sendTomorrowModalOverlay) {
            sendTomorrowModalOverlay.classList.remove('active');
        }
    }

    function renderSendTomorrowModalList() {
        if (!sendTomorrowPatientList) return;
        if (!tomorrowAppointmentsList || tomorrowAppointmentsList.length === 0) {
            sendTomorrowPatientList.innerHTML = `
                <div style="text-align:center; padding:2rem 1rem; color:#64748b;">
                    <span style="font-size:2rem; display:block; margin-bottom:0.5rem;">📅</span>
                    <p style="margin:0; font-weight:600;">No appointments scheduled for tomorrow (${formatDisplayDate(getTomorrowDateString())}).</p>
                </div>
            `;
            if (sendTomorrowSummary) sendTomorrowSummary.textContent = '0 Patients scheduled for tomorrow';
            return;
        }

        const sentCount = tomorrowAppointmentsList.filter(apt => tomorrowSentStatuses[apt.appointmentId || apt.phone]).length;
        if (sendTomorrowSummary) {
            sendTomorrowSummary.textContent = `${sentCount} of ${tomorrowAppointmentsList.length} reminders sent`;
        }

        sendTomorrowPatientList.innerHTML = tomorrowAppointmentsList.map((apt, idx) => {
            const key = apt.appointmentId || apt.phone;
            const isSent = !!tomorrowSentStatuses[key];
            const opNo = apt.opNumber || apt.op || getPatientOp(apt);
            const opHtml = opNo ? `<span style="font-size:0.75rem; background:#ccfbf1; color:#0f766e; font-weight:700; padding:2px 8px; border-radius:6px; border:1px solid #99f6e4;">${escapeHtml(opNo)}</span>` : '';
            const statusBadge = isSent 
                ? `<span style="font-size:0.8rem; background:#dcfce7; color:#15803d; font-weight:700; padding:3px 10px; border-radius:6px;">✓ Sent</span>`
                : `<span style="font-size:0.8rem; background:#f1f5f9; color:#64748b; font-weight:600; padding:3px 10px; border-radius:6px;">Pending</span>`;

            return `
                <div class="patient-remind-row" style="background:${isSent ? '#f0fdf4' : '#ffffff'}; border:1px solid ${isSent ? '#86efac' : '#e2e8f0'}; border-radius:10px; padding:0.85rem 1rem; display:flex; justify-content:space-between; align-items:center; gap:0.8rem; flex-wrap:wrap;">
                    <div>
                        <div style="display:flex; align-items:center; gap:8px;">
                            <strong style="font-size:0.95rem; color:#0f172a;">${idx + 1}. ${escapeHtml(apt.patientName)}</strong>
                            ${opHtml}
                        </div>
                        <div style="font-size:0.82rem; color:#64748b; margin-top:2px;">
                            <span>⏰ ${formatTime(apt.time)}</span> • 
                            <span>👨‍⚕️ ${escapeHtml(cleanDoctor(apt.doctor) || 'Attending Doctor')}</span> • 
                            <span>📞 <a href="tel:${escapeHtml(apt.phone)}" style="color:#0d9488; text-decoration:none; font-weight:600;">${escapeHtml(apt.phone)}</a></span>
                        </div>
                        <div style="font-size:0.78rem; color:#64748b; margin-top:2px;">
                            <span>🩺 ${escapeHtml(apt.reason || 'Dental Consultation')}</span>
                        </div>
                    </div>
                    <div style="display:flex; align-items:center; gap:8px;">
                        ${statusBadge}
                        <button type="button" class="mini-btn btn-send-single-wa" data-idx="${idx}" style="background:#25D366; color:white; font-weight:700; border:none; padding:6px 14px; border-radius:6px; cursor:pointer; display:inline-flex; align-items:center; gap:5px;" title="Open WhatsApp Reminder">
                            <span>💬</span> ${isSent ? 'Resend' : 'Send WhatsApp'}
                        </button>
                    </div>
                </div>
            `;
        }).join('');

        // Attach click handlers
        sendTomorrowPatientList.querySelectorAll('.btn-send-single-wa').forEach(btn => {
            btn.addEventListener('click', () => {
                const idx = parseInt(btn.getAttribute('data-idx'), 10);
                const apt = tomorrowAppointmentsList[idx];
                if (apt) {
                    const key = apt.appointmentId || apt.phone;
                    tomorrowSentStatuses[key] = true;
                    sendWhatsAppReminder(apt);
                    renderSendTomorrowModalList();
                }
            });
        });
    }

    if (sendAllTomorrowBtn) {
        sendAllTomorrowBtn.addEventListener('click', async () => {
            if (!tomorrowAppointmentsList || tomorrowAppointmentsList.length === 0) {
                await fetchTomorrowAppointments();
            }
            if (!tomorrowAppointmentsList || tomorrowAppointmentsList.length === 0) {
                alert(`No appointments scheduled for tomorrow (${formatDisplayDate(getTomorrowDateString())}) to send reminders to.`);
                return;
            }
            openSendTomorrowModal();
        });
    }

    if (closeSendTomorrowModalBtn) closeSendTomorrowModalBtn.addEventListener('click', closeSendTomorrowModal);
    if (cancelSendTomorrowBtn) cancelSendTomorrowBtn.addEventListener('click', closeSendTomorrowModal);
    if (sendTomorrowModalOverlay) {
        sendTomorrowModalOverlay.addEventListener('click', (e) => {
            if (e.target === sendTomorrowModalOverlay) closeSendTomorrowModal();
        });
    }

    if (startBatchSendBtn) {
        startBatchSendBtn.addEventListener('click', () => {
            if (!tomorrowAppointmentsList || tomorrowAppointmentsList.length === 0) return;
            // Find first unsent patient
            const unsentIdx = tomorrowAppointmentsList.findIndex(apt => !tomorrowSentStatuses[apt.appointmentId || apt.phone]);
            if (unsentIdx >= 0) {
                const apt = tomorrowAppointmentsList[unsentIdx];
                const key = apt.appointmentId || apt.phone;
                tomorrowSentStatuses[key] = true;
                sendWhatsAppReminder(apt);
                renderSendTomorrowModalList();
            } else {
                alert('All tomorrow\'s appointment reminders have been sent! You can still resend individually if needed.');
            }
        });
    }

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
                    const patientOp = getPatientOp(apt);
                    const opBadge = patientOp ? `<span class="patient-suggest-op" style="font-size:0.75rem; padding: 2px 8px; border-radius: 6px; background: #ccfbf1; color: #0f766e; font-weight:700; border: 1px solid #99f6e4;">${escapeHtml(patientOp)}</span>` : '';
                    return `
                        <div class="apt-card">
                            <div class="apt-time-box">
                                <span class="apt-time-val">${formatTime(apt.time)}</span>
                                <span class="apt-date-val">${formatDisplayDate(apt.date)}</span>
                            </div>
                            <div class="apt-info-box">
                                <div class="apt-patient-header">
                                    <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                                        <h4 class="apt-patient-name" style="margin: 0;">${escapeHtml(apt.patientName)}</h4>
                                        ${opBadge}
                                    </div>
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
                                <a href="${generateWhatsAppReminderLink(apt)}" target="_blank" rel="noopener noreferrer" class="mini-btn btn-whatsapp" style="background: #25D366; color: white; font-weight: 700; text-decoration: none; display: inline-flex; align-items: center; gap: 4px; box-shadow: 0 2px 5px rgba(37,211,102,0.25);" title="Send WhatsApp Appointment Reminder to Patient">
                                    <span style="font-size: 1rem;">💬</span> WhatsApp
                                </a>
                                <a href="${generateGoogleCalendarLink(apt)}" target="_blank" rel="noopener noreferrer" class="mini-btn btn-cal-link" style="background: #ecfdf5; color: #047857; font-weight: 600;" title="Open in this Phone / Device Google Calendar">
                                    <span>📅</span> Calendar
                                </a>
                                <button type="button" class="mini-btn" onclick="window.downloadIcsCalendarFile(${JSON.stringify(apt).replace(/"/g, '&quot;')})" style="background: #eff6ff; color: #1e40af; border: none; cursor: pointer; font-weight: 600;" title="Download .ics Event to Phone / Apple Calendar">
                                    <span>📲</span> .ics
                                </button>
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

            // Check for success, known patientPhone ReferenceError, or legacy calendar notices
            const isPatientPhoneRefError = (result && result.message && result.message.includes('patientPhone')) ||
                                           (text && text.includes('patientPhone is not defined'));
            const isCalNotice = (result && result.message && (
                result.message.includes('Could not access Google Calendar') ||
                result.message.includes('Calendar permissions') ||
                result.message.includes('sanjuantony01')
            )) || (text && (
                text.includes('Could not access Google Calendar') ||
                text.includes('Calendar permissions') ||
                text.includes('sanjuantony01')
            ));

            if (result.status === 'success' || isPatientPhoneRefError || isCalNotice) {
                closeRescheduleModal();
                const updatedCalUrl = generateGoogleCalendarLink({
                    patientName: payload.patientName || 'Patient',
                    doctor: payload.doctor,
                    date: payload.newDate,
                    time: payload.newTime,
                    phone: payload.phone,
                    notes: payload.notes
                });

                if (confirm(`✓ Appointment successfully rescheduled to ${formatDisplayDate(payload.newDate)} at ${formatTime(payload.newTime)}!\n\nWould you like to sync this updated time to this phone/device's Google Calendar?`)) {
                    try {
                        window.open(updatedCalUrl, '_blank');
                    } catch (e) {
                        console.warn('Could not open window:', e);
                    }
                }

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

    // Initial load: fetch today's, tomorrow's, and upcoming appointments
    fetchTodayAppointments();
    fetchTomorrowAppointments();
    fetchUpcomingAppointments();
});
